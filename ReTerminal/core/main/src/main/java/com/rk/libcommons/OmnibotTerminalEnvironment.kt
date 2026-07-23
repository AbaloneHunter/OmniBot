package com.rk.libcommons

import android.content.Context
import com.rk.terminal.runtime.TerminalDistribution
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

object OmnibotTerminalEnvironment {
    private const val PREFS_NAME = "omnibot_terminal_environment"
    private const val KEY_VARIABLES_JSON = "variables_json"
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val FLUTTER_ENV_KEY = "flutter.chat_terminal_environment_variables"
    private const val CODEX_PREFS_NAME = "codex_local_config"
    private const val CODEX_AUTH_MODE_KEY = "auth_mode"
    private const val CODEX_BASE_URL_KEY = "base_url"
    private const val CODEX_API_MODEL_KEY = "api_model"
    private const val CODEX_API_KEY = "api_key"
    private const val CODEX_OFFICIAL_MODEL_KEY = "official_model"
    private const val CODEX_API_AUTH_MODE = "api"
    private const val CODEX_CHATGPT_AUTH_MODE = "chatgpt"
    const val CODEX_API_ENV_KEY = "OMNIBOT_CODEX_API_KEY"
    private const val ENV_FILE_NAME = "omnibot-user-env.sh"
    private const val MT_PACKAGE_NAME = "bin.mt.plus"
    private const val MT_LOCAL_STORAGE_PATH = "/sdcard"
    private const val MT_EMULATED_STORAGE_PATH = "/storage/emulated/0"
    private const val MT_APP_SPECIFIC_STORAGE_PATH =
        "$MT_EMULATED_STORAGE_PATH/Android/data/$MT_PACKAGE_NAME/files"
    private const val MT_STORAGE_MOUNT_PATH = "/mnt/mt"
    private const val MT_STORAGE_SHORTCUT_PATH = "/mt"
    private val envKeyPattern = Regex("^[A-Za-z_][A-Za-z0-9_]*$")

    fun buildTerminalEnvironment(context: Context): Map<String, String> {
        val appContext = context.applicationContext
        val userVariables = loadUserVariables(appContext)
        ensureManagedCodexConfig(appContext)
        return linkedMapOf<String, String>().apply {
            putAll(buildDefaultStorageEnvironment())
            putAll(userVariables)
            putAll(loadManagedCodexEnvironment(appContext))
            val envFile = ensureUserEnvFile(appContext, userVariables)
            put("OMNIBOT_USER_ENV_FILE", envFile.absolutePath)
        }
    }

    fun buildManagedCodexEnvironment(
        authMode: String?,
        apiKey: String?
    ): Map<String, String> {
        val normalizedApiKey = apiKey?.trim().orEmpty()
        if (
            !authMode.equals(CODEX_API_AUTH_MODE, ignoreCase = true) ||
            normalizedApiKey.isEmpty()
        ) {
            return emptyMap()
        }
        return mapOf(CODEX_API_ENV_KEY to normalizedApiKey)
    }

    fun buildManagedCodexConfigToml(
        authMode: String,
        baseUrl: String,
        model: String
    ): String {
        val normalizedAuthMode = authMode.trim().lowercase()
        require(
            normalizedAuthMode == CODEX_API_AUTH_MODE ||
                normalizedAuthMode == CODEX_CHATGPT_AUTH_MODE
        ) {
            "Unsupported Codex auth mode: $authMode"
        }
        val provider = if (normalizedAuthMode == CODEX_CHATGPT_AUTH_MODE) {
            "openai"
        } else {
            "omnimind"
        }
        val lines = mutableListOf("model_provider = ${tomlString(provider)}")
        model.trim().takeIf { it.isNotEmpty() }?.let {
            lines += "model = ${tomlString(it)}"
        }
        lines += "model_reasoning_effort = \"xhigh\""
        lines += "disable_response_storage = true"
        if (normalizedAuthMode == CODEX_CHATGPT_AUTH_MODE) {
            lines += "cli_auth_credentials_store = \"file\""
        } else {
            lines += ""
            lines += "[model_providers.omnimind]"
            lines += "name = \"omnimind\""
            lines += "base_url = ${tomlString(baseUrl.trim())}"
            lines += "wire_api = \"responses\""
            lines += "env_key = ${tomlString(CODEX_API_ENV_KEY)}"
            lines += "requires_openai_auth = false"
        }
        return lines.joinToString(separator = "\n", postfix = "\n")
    }

    fun loadUserVariables(context: Context): Map<String, String> {
        val appContext = context.applicationContext
        val nativeJson = prefs(appContext).getString(KEY_VARIABLES_JSON, null)
        val nativeVariables = parseVariablesJson(nativeJson)
        if (nativeVariables.isNotEmpty() || nativeJson != null) {
            return nativeVariables
        }

        val flutterJson = appContext
            .getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            .getString(FLUTTER_ENV_KEY, null)
        val flutterVariables = parseVariablesJson(flutterJson)
        if (flutterVariables.isNotEmpty()) {
            saveUserVariables(appContext, flutterVariables)
        }
        return flutterVariables
    }

    fun saveUserVariables(context: Context, variables: Map<String, String>): Map<String, String> {
        val normalized = normalizeVariables(variables)
        val payload = JSONArray()
        normalized.forEach { (key, value) ->
            payload.put(JSONObject().apply {
                put("key", key)
                put("value", value)
            })
        }
        prefs(context.applicationContext)
            .edit()
            .putString(KEY_VARIABLES_JSON, payload.toString())
            .apply()
        ensureUserEnvFile(context.applicationContext, normalized)
        return normalized
    }

    fun normalizeVariables(variables: Map<String, String>): Map<String, String> {
        val normalized = linkedMapOf<String, String>()
        variables.forEach { (rawKey, value) ->
            val key = rawKey.trim()
            if (
                key.isEmpty() ||
                !envKeyPattern.matches(key) ||
                key == CODEX_API_ENV_KEY
            ) {
                return@forEach
            }
            normalized.remove(key)
            normalized[key] = value
        }
        return normalized
    }

    fun mtStorageHostPath(): String {
        return resolveMtStorageHostPath()
    }

    fun mtAppSpecificStorageHostPath(): String {
        return MT_APP_SPECIFIC_STORAGE_PATH
    }

    fun mtStorageMountPath(): String = MT_STORAGE_MOUNT_PATH

    fun mtStorageShortcutPath(): String = MT_STORAGE_SHORTCUT_PATH

    internal fun buildShellExportScript(variables: Map<String, String>): String {
        return buildString {
            appendLine("# Generated by Omnibot. Manual edits may be overwritten.")
            variables.forEach { (key, value) ->
                append("export ")
                append(key)
                append("=")
                append(quoteForShell(value))
                append('\n')
            }
        }
    }

    private fun buildDefaultStorageEnvironment(): Map<String, String> {
        val mtHostPath = mtStorageHostPath()
        return linkedMapOf(
            "OMNIBOT_MT_STORAGE_HOST" to mtHostPath,
            "OMNIBOT_MT_STORAGE_LEGACY_HOST" to MT_APP_SPECIFIC_STORAGE_PATH,
            "OMNIBOT_MT_STORAGE" to MT_STORAGE_MOUNT_PATH,
            "MT_STORAGE" to MT_STORAGE_MOUNT_PATH
        )
    }

    private fun loadManagedCodexEnvironment(context: Context): Map<String, String> {
        val codexPrefs = context.getSharedPreferences(
            CODEX_PREFS_NAME,
            Context.MODE_PRIVATE
        )
        return buildManagedCodexEnvironment(
            authMode = codexPrefs.getString(CODEX_AUTH_MODE_KEY, null),
            apiKey = codexPrefs.getString(CODEX_API_KEY, null)
        )
    }

    private fun ensureManagedCodexConfig(context: Context) {
        val codexPrefs = context.getSharedPreferences(
            CODEX_PREFS_NAME,
            Context.MODE_PRIVATE
        )
        val authMode = codexPrefs.getString(CODEX_AUTH_MODE_KEY, null)
            ?.trim()
            ?.lowercase()
            ?: return
        if (authMode != CODEX_API_AUTH_MODE && authMode != CODEX_CHATGPT_AUTH_MODE) {
            return
        }
        val baseUrl = codexPrefs.getString(CODEX_BASE_URL_KEY, "").orEmpty().trim()
        val apiModel = codexPrefs.getString(CODEX_API_MODEL_KEY, "").orEmpty().trim()
        val apiKey = codexPrefs.getString(CODEX_API_KEY, "").orEmpty().trim()
        val officialModel = codexPrefs.getString(CODEX_OFFICIAL_MODEL_KEY, "").orEmpty().trim()
        if (
            authMode == CODEX_API_AUTH_MODE &&
            (baseUrl.isEmpty() || apiModel.isEmpty() || apiKey.isEmpty())
        ) {
            return
        }
        val configToml = buildManagedCodexConfigToml(
            authMode = authMode,
            baseUrl = baseUrl,
            model = if (authMode == CODEX_API_AUTH_MODE) apiModel else officialModel
        )
        val distribution = TerminalDistribution.selected()
        val appDataDir = context.filesDir.parentFile ?: context.filesDir
        val configDirectory = File(
            appDataDir,
            "local/${distribution.rootfsDirectoryName}/root/.codex"
        )
        check(configDirectory.isDirectory || configDirectory.mkdirs()) {
            "Failed to create Codex config directory for ${distribution.id}."
        }
        val configFile = File(configDirectory, "config.toml")
        if (!configFile.isFile || configFile.readText() != configToml) {
            configFile.writeText(configToml)
            configFile.setReadable(false, false)
            configFile.setWritable(false, false)
            configFile.setReadable(true, true)
            configFile.setWritable(true, true)
        }
    }

    private fun ensureUserEnvFile(context: Context, variables: Map<String, String>): File {
        val scriptFile = File(context.filesDir.parentFile, "local/bin/$ENV_FILE_NAME")
        scriptFile.parentFile?.mkdirs()
        val content = buildShellExportScript(normalizeVariables(variables))
        if (!scriptFile.exists() || scriptFile.readText() != content) {
            scriptFile.writeText(content)
        }
        scriptFile.setReadable(true, false)
        scriptFile.setExecutable(false, false)
        return scriptFile
    }

    private fun parseVariablesJson(jsonText: String?): Map<String, String> {
        val raw = jsonText?.trim().orEmpty()
        if (raw.isEmpty()) {
            return emptyMap()
        }
        return runCatching {
            val items = JSONArray(raw)
            val parsed = linkedMapOf<String, String>()
            for (index in 0 until items.length()) {
                val item = items.optJSONObject(index) ?: continue
                val key = item.optString("key", "").trim()
                if (key.isEmpty() || !envKeyPattern.matches(key)) {
                    continue
                }
                parsed.remove(key)
                parsed[key] = item.optString("value", "")
            }
            parsed
        }.getOrDefault(emptyMap())
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun resolveMtStorageHostPath(): String {
        val candidates = linkedSetOf<String>().apply {
            add(MT_LOCAL_STORAGE_PATH)
            add(MT_EMULATED_STORAGE_PATH)
            add(MT_APP_SPECIFIC_STORAGE_PATH)
        }
        return candidates.firstOrNull(::isUsableDirectory) ?: MT_LOCAL_STORAGE_PATH
    }

    private fun isUsableDirectory(path: String): Boolean {
        return runCatching {
            val dir = File(path)
            dir.isDirectory && dir.canRead()
        }.getOrDefault(false)
    }

    private fun quoteForShell(value: String): String {
        return "'" + value.replace("'", "'\"'\"'") + "'"
    }

    private fun tomlString(value: String): String {
        return buildString {
            append('"')
            value.forEach { char ->
                when (char) {
                    '\\' -> append("\\\\")
                    '"' -> append("\\\"")
                    '\b' -> append("\\b")
                    '\t' -> append("\\t")
                    '\n' -> append("\\n")
                    '\u000C' -> append("\\f")
                    '\r' -> append("\\r")
                    else -> {
                        if (char.code < 0x20) {
                            append("\\u")
                            append(char.code.toString(16).padStart(4, '0'))
                        } else {
                            append(char)
                        }
                    }
                }
            }
            append('"')
        }
    }
}
