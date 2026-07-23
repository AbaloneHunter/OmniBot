package cn.com.omnimind.bot.codex

/**
 * Internal launch configuration used only to materialize Codex ACP's generated
 * runtime file from a unified Model Provider binding. It is not user settings
 * and is never persisted independently.
 */
internal data class CodexAcpLaunchConfig(
    val baseUrl: String = "",
    val model: String = "",
    val apiKey: String = ""
)

internal fun CodexAcpLaunchConfig.normalized(): CodexAcpLaunchConfig {
    return copy(
        baseUrl = baseUrl.trim(),
        model = model.trim(),
        apiKey = apiKey.trim()
    )
}

internal const val CODEX_CUSTOM_API_KEY_ENV = "OMNIBOT_CODEX_API_KEY"
