package cn.com.omnimind.bot.webchat

import android.content.Context
import cn.com.omnimind.bot.agent.AgentConversationHistoryRepository
import cn.com.omnimind.bot.agent.AgentTextSanitizer
import cn.com.omnimind.bot.codex.CodexAppServerManager
import com.google.gson.Gson
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

internal data class WebCodexToolUpdate(
    val entryId: String?,
    val parentTaskId: String?,
    val itemType: String,
    val status: String,
    val raw: Map<String, Any?>
)

internal data class WebCodexEventUpdate(
    val assistantEntryId: String? = null,
    val assistantDelta: String? = null,
    val assistantSnapshot: String? = null,
    val assistantFinal: Boolean = false,
    val reasoningEntryId: String? = null,
    val reasoningDelta: String? = null,
    val reasoningSnapshot: String? = null,
    val reasoningFinal: Boolean = false,
    val parentTaskId: String? = null,
    val tool: WebCodexToolUpdate? = null,
    val terminalKind: String? = null,
    val errorMessage: String? = null
)

private data class WebCodexTextEntryState(
    val entryId: String,
    val parentTaskId: String,
    val createdAt: Long,
    val sequence: Long,
    var text: String = "",
    var isFinal: Boolean = false
)

private data class WebCodexToolEntryState(
    val entryId: String,
    val parentTaskId: String,
    val createdAt: Long,
    val sequence: Long,
    var update: WebCodexToolUpdate
)

private data class WebCodexRunState(
    val taskId: String,
    val conversationId: Long,
    val createdAt: Long,
    val finished: AtomicBoolean = AtomicBoolean(false),
    var threadId: String? = null,
    var turnId: String? = null,
    var sequence: Long = 0,
    val assistantEntries: LinkedHashMap<String, WebCodexTextEntryState> = linkedMapOf(),
    val reasoningEntries: LinkedHashMap<String, WebCodexTextEntryState> = linkedMapOf(),
    val toolEntries: LinkedHashMap<String, WebCodexToolEntryState> = linkedMapOf()
)

internal class WebCodexRunBridge(
    context: Context,
    private val manager: CodexAppServerManager
) {
    private val appContext = context.applicationContext
    private val historyRepository = AgentConversationHistoryRepository(appContext)
    private val conversationService = ConversationDomainService(appContext)
    private val gson = Gson()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val events = Channel<Map<String, Any?>>(Channel.UNLIMITED)
    private val runsByTaskId = ConcurrentHashMap<String, WebCodexRunState>()
    private val runsByConversationId = ConcurrentHashMap<Long, WebCodexRunState>()
    private val runsByThreadId = ConcurrentHashMap<String, WebCodexRunState>()
    private val runsByTurnId = ConcurrentHashMap<String, WebCodexRunState>()

    init {
        manager.setSupplementalEventListener(
            key = "webchat"
        ) { event -> events.trySend(event) }
        scope.launch {
            for (event in events) {
                handleEvent(event)
            }
        }
    }

    fun hasActiveRun(conversationId: Long): Boolean {
        return runsByConversationId[conversationId]?.finished?.get() == false
    }

    suspend fun startRun(
        taskId: String,
        conversationId: Long,
        userMessage: String,
        attachments: List<Map<String, Any?>>,
        cwd: String?,
        userMessageCreatedAt: Long? = null
    ): Map<String, Any?> {
        val state = WebCodexRunState(
            taskId = taskId,
            conversationId = conversationId,
            createdAt = userMessageCreatedAt?.takeIf { it > 0L }
                ?: System.currentTimeMillis()
        )
        val existing = runsByConversationId.putIfAbsent(conversationId, state)
        check(existing == null || existing.finished.get()) {
            "该 Codex 会话已有运行中的任务"
        }
        if (existing != null) {
            runsByConversationId[conversationId] = state
        }
        runsByTaskId[taskId] = state

        // Reuse the external-message path so Flutter and WebChat receive the
        // same stable user entry before any Codex stream event can overtake it.
        conversationService.appendUserMessage(
            conversationId = conversationId,
            conversationMode = CODEX_MODE,
            entryId = "$taskId-user",
            text = userMessage,
            attachments = attachments,
            createdAt = state.createdAt
        )

        return try {
            val arguments = linkedMapOf<String, Any?>(
                "conversationId" to conversationId,
                "text" to userMessage,
                "attachments" to attachments
            )
            cwd?.trim()?.takeIf { it.isNotEmpty() }?.let {
                arguments["cwd"] = it
            }
            val response = normalizeMap(
                manager.handleMethod("turn/start", arguments)
            )
            bindServerIds(
                state = state,
                threadId = response["threadId"]?.toString(),
                turnId = response["turnId"]?.toString()
            )
            response
        } catch (error: Throwable) {
            finishWithError(
                state,
                error.message?.trim().takeUnless { it.isNullOrEmpty() }
                    ?: "Codex 启动失败"
            )
            throw error
        }
    }

    suspend fun cancelRun(taskId: String): Boolean {
        val state = runsByTaskId[taskId] ?: return false
        val arguments = linkedMapOf<String, Any?>(
            "conversationId" to state.conversationId
        )
        state.threadId?.let { arguments["threadId"] = it }
        state.turnId?.let { arguments["turnId"] = it }
        manager.handleMethod("turn/interrupt", arguments)
        return true
    }

    private suspend fun handleEvent(event: Map<String, Any?>) {
        val conversationId = event.readLong("conversationId")
        val threadId = event.readString("threadId")
        val turnId = event.readString("turnId")
        val state = conversationId?.let(runsByConversationId::get)
            ?: threadId?.let(runsByThreadId::get)
            ?: turnId?.let(runsByTurnId::get)
            ?: return
        if (state.finished.get()) return
        if (turnId != null && state.turnId != null && turnId != state.turnId) {
            return
        }
        bindServerIds(state, threadId, turnId)

        val update = parseWebCodexEvent(event)
        var changed = false
        val parentTaskId = update.parentTaskId
            ?.takeIf(String::isNotBlank)
            ?: state.turnId
            ?: state.taskId

        if (
            update.assistantSnapshot != null ||
            !update.assistantDelta.isNullOrEmpty()
        ) {
            val entryId = update.assistantEntryId
                ?.takeIf(String::isNotBlank)
                ?: "$parentTaskId-codex-agent"
            val entry = state.assistantEntries.getOrPut(entryId) {
                newTextEntry(state, entryId, parentTaskId)
            }
            entry.text = if (update.assistantSnapshot != null) {
                mergeSnapshot(entry.text, update.assistantSnapshot)
            } else {
                entry.text + update.assistantDelta.orEmpty()
            }
            entry.isFinal = entry.isFinal || update.assistantFinal
            persistAssistantEntry(state, entry, isError = false)
            changed = true
        }

        if (
            update.reasoningSnapshot != null ||
            !update.reasoningDelta.isNullOrEmpty()
        ) {
            val entryId = update.reasoningEntryId
                ?.takeIf(String::isNotBlank)
                ?: "$parentTaskId-codex-thinking"
            val entry = state.reasoningEntries.getOrPut(entryId) {
                newTextEntry(state, entryId, parentTaskId)
            }
            entry.text = if (update.reasoningSnapshot != null) {
                mergeSnapshot(entry.text, update.reasoningSnapshot)
            } else {
                entry.text + update.reasoningDelta.orEmpty()
            }
            entry.isFinal = entry.isFinal || update.reasoningFinal
            persistReasoningEntry(state, entry)
            changed = true
        }

        update.tool?.let { toolUpdate ->
            val entryId = toolUpdate.entryId
                ?.takeIf(String::isNotBlank)
                ?: "${toolUpdate.parentTaskId ?: parentTaskId}-codex-tool"
            val toolParentTaskId = toolUpdate.parentTaskId
                ?.takeIf(String::isNotBlank)
                ?: parentTaskId
            val entry = state.toolEntries.getOrPut(entryId) {
                state.sequence += 1
                WebCodexToolEntryState(
                    entryId = entryId,
                    parentTaskId = toolParentTaskId,
                    createdAt = state.createdAt + state.sequence,
                    sequence = state.sequence,
                    update = toolUpdate
                )
            }
            entry.update = mergeToolUpdate(entry.update, toolUpdate)
            persistToolEntry(state, entry)
            changed = true
        }

        if (changed) {
            publishMessages(state, finalizeInterruptedEntries = false)
        }

        when (update.terminalKind) {
            "completed" -> finishSuccessfully(state)
            "error" -> finishWithError(
                state,
                update.errorMessage ?: "Codex 任务执行失败"
            )
        }
    }

    private fun newTextEntry(
        state: WebCodexRunState,
        entryId: String,
        parentTaskId: String
    ): WebCodexTextEntryState {
        state.sequence += 1
        return WebCodexTextEntryState(
            entryId = entryId,
            parentTaskId = parentTaskId,
            createdAt = state.createdAt + state.sequence,
            sequence = state.sequence
        )
    }

    private fun bindServerIds(
        state: WebCodexRunState,
        threadId: String?,
        turnId: String?
    ) {
        threadId?.trim()?.takeIf { it.isNotEmpty() }?.let { normalized ->
            state.threadId = normalized
            if (!state.finished.get()) {
                runsByThreadId[normalized] = state
            }
        }
        turnId?.trim()?.takeIf { it.isNotEmpty() }?.let { normalized ->
            state.turnId = normalized
            if (!state.finished.get()) {
                runsByTurnId[normalized] = state
            }
        }
    }

    private suspend fun finishSuccessfully(state: WebCodexRunState) {
        if (!state.finished.compareAndSet(false, true)) return
        state.assistantEntries.values.forEach { entry ->
            entry.isFinal = true
            persistAssistantEntry(state, entry, isError = false)
        }
        state.reasoningEntries.values.forEach { entry ->
            entry.isFinal = true
            persistReasoningEntry(state, entry)
        }
        state.toolEntries.values.forEach { entry ->
            if (entry.update.status == "running") {
                entry.update = entry.update.copy(status = "success")
                persistToolEntry(state, entry)
            }
        }
        publishMessages(state, finalizeInterruptedEntries = true)
        publishTerminalEvent(state, "completed")
        removeState(state)
    }

    private suspend fun finishWithError(
        state: WebCodexRunState,
        message: String
    ) {
        if (!state.finished.compareAndSet(false, true)) return
        val entry = state.assistantEntries.values.lastOrNull() ?: run {
            val parentTaskId = state.turnId ?: state.taskId
            val entryId = "$parentTaskId-codex-agent"
            newTextEntry(state, entryId, parentTaskId).also {
                state.assistantEntries[entryId] = it
            }
        }
        if (entry.text.isBlank()) {
            entry.text = AgentTextSanitizer.sanitizeUtf16(message)
        }
        entry.isFinal = true
        persistAssistantEntry(state, entry, isError = true)
        state.reasoningEntries.values.forEach { reasoning ->
            reasoning.isFinal = true
            persistReasoningEntry(state, reasoning)
        }
        state.toolEntries.values.forEach { tool ->
            if (tool.update.status == "running") {
                tool.update = tool.update.copy(status = "error")
                persistToolEntry(state, tool)
            }
        }
        publishMessages(state, finalizeInterruptedEntries = true)
        publishTerminalEvent(state, "error", message)
        removeState(state)
    }

    private suspend fun persistAssistantEntry(
        state: WebCodexRunState,
        entry: WebCodexTextEntryState,
        isError: Boolean
    ) {
        historyRepository.upsertAssistantMessage(
            conversationId = state.conversationId,
            conversationMode = CODEX_MODE,
            entryId = entry.entryId,
            text = AgentTextSanitizer.sanitizeUtf16(entry.text),
            isError = isError,
            streamMeta = streamMeta(
                entryId = entry.entryId,
                parentTaskId = entry.parentTaskId,
                sequence = entry.sequence,
                kind = "text_snapshot",
                isFinal = entry.isFinal
            ),
            createdAt = entry.createdAt
        )
    }

    private suspend fun persistReasoningEntry(
        state: WebCodexRunState,
        entry: WebCodexTextEntryState
    ) {
        historyRepository.upsertUiCard(
            conversationId = state.conversationId,
            conversationMode = CODEX_MODE,
            entryId = entry.entryId,
            cardData = linkedMapOf(
                "type" to "deep_thinking",
                "taskID" to entry.parentTaskId,
                "cardId" to entry.entryId,
                "thinkingContent" to AgentTextSanitizer.sanitizeUtf16(entry.text),
                "stage" to if (entry.isFinal) 4 else 1,
                "isLoading" to !entry.isFinal,
                "startTime" to entry.createdAt,
                "endTime" to if (entry.isFinal) System.currentTimeMillis() else null,
                "isCollapsible" to true
            ).filterValues { it != null },
            streamMeta = streamMeta(
                entryId = entry.entryId,
                parentTaskId = entry.parentTaskId,
                sequence = entry.sequence,
                kind = "thinking_snapshot",
                isFinal = entry.isFinal
            ),
            createdAt = entry.createdAt
        )
    }

    private suspend fun persistToolEntry(
        state: WebCodexRunState,
        entry: WebCodexToolEntryState
    ) {
        val update = entry.update
        val raw = update.raw
        val toolName = firstNonBlank(
            raw["toolName"],
            raw["tool_name"],
            raw["name"],
            raw["command"],
            update.itemType
        ) ?: "codex_tool"
        val toolType = inferToolType(update.itemType, toolName)
        val title = firstNonBlank(
            raw["toolTitle"],
            raw["title"],
            raw["displayName"],
            raw["name"],
            raw["command"]
        ) ?: defaultToolTitle(toolType)
        val summary = firstNonBlank(
            raw["summary"],
            raw["message"],
            raw["description"],
            raw["progress"]
        ).orEmpty()
        val terminalOutput = firstNonBlank(
            raw["terminalOutput"],
            raw["aggregatedOutput"],
            raw["aggregated_output"],
            raw["output"],
            raw["stdout"]
        ).orEmpty()
        val arguments = normalizeMap(raw["arguments"]).ifEmpty {
            normalizeMap(raw["args"])
        }
        historyRepository.upsertToolEvent(
            conversationId = state.conversationId,
            conversationMode = CODEX_MODE,
            entryId = entry.entryId,
            payload = linkedMapOf<String, Any?>(
                "taskId" to entry.parentTaskId,
                "cardId" to entry.entryId,
                "toolName" to toolName,
                "displayName" to title,
                "toolTitle" to title,
                "toolType" to toolType,
                "serverName" to firstNonBlank(raw["serverName"], raw["server"]),
                "status" to update.status,
                "summary" to summary,
                "progress" to firstNonBlank(raw["progress"], raw["message"]).orEmpty(),
                "argsJson" to arguments.takeIf { it.isNotEmpty() }?.let(gson::toJson),
                "resultPreviewJson" to raw["result"]?.let(gson::toJson),
                "rawResultJson" to gson.toJson(raw),
                "terminalOutput" to terminalOutput,
                "streamMeta" to streamMeta(
                    entryId = entry.entryId,
                    parentTaskId = entry.parentTaskId,
                    sequence = entry.sequence,
                    kind = if (update.status == "running") "tool_progress" else "tool_completed",
                    isFinal = update.status != "running"
                )
            ).filterValues { it != null },
            fallbackStatus = update.status,
            fallbackSummary = summary.ifBlank { title }
        )
    }

    private fun streamMeta(
        entryId: String,
        parentTaskId: String,
        sequence: Long,
        kind: String,
        isFinal: Boolean
    ): Map<String, Any?> {
        return linkedMapOf(
            "seq" to sequence,
            "entrySeq" to sequence,
            "roundIndex" to sequence,
            "kind" to kind,
            "parentTaskId" to parentTaskId,
            "entryId" to entryId,
            "isFinal" to isFinal
        )
    }

    private suspend fun publishMessages(
        state: WebCodexRunState,
        finalizeInterruptedEntries: Boolean
    ) {
        val messages = historyRepository.listConversationMessages(
            conversationId = state.conversationId,
            conversationMode = CODEX_MODE,
            finalizeInterruptedEntries = finalizeInterruptedEntries
        )
        RealtimeHub.publish(
            "messages_replaced",
            mapOf(
                "conversationId" to state.conversationId,
                "mode" to CODEX_MODE,
                "messages" to messages
            )
        )
    }

    private fun publishTerminalEvent(
        state: WebCodexRunState,
        kind: String,
        error: String? = null
    ) {
        RealtimeHub.publish(
            "agent_stream_event",
            linkedMapOf<String, Any?>(
                "taskId" to state.taskId,
                "conversationId" to state.conversationId,
                "conversationMode" to CODEX_MODE,
                "kind" to kind,
                "error" to error
            ).filterValues { it != null }
        )
    }

    private fun removeState(state: WebCodexRunState) {
        runsByTaskId.remove(state.taskId, state)
        runsByConversationId.remove(state.conversationId, state)
        state.threadId?.let { runsByThreadId.remove(it, state) }
        state.turnId?.let { runsByTurnId.remove(it, state) }
    }

    private fun mergeSnapshot(existing: String, incoming: String): String {
        val safeIncoming = AgentTextSanitizer.sanitizeUtf16(incoming)
        if (safeIncoming.isEmpty()) return existing
        if (safeIncoming.startsWith(existing)) return safeIncoming
        if (existing.startsWith(safeIncoming)) return existing
        return safeIncoming
    }

    private companion object {
        const val CODEX_MODE = "codex"
    }
}

internal fun parseWebCodexEvent(event: Map<String, Any?>): WebCodexEventUpdate {
    val method = event.readString("method").orEmpty()
    val normalizedMethod = normalizeCodexEventToken(method)
    val params = normalizeMap(event["params"])
    val item = normalizeMap(params["item"])
    val turnId = firstNonBlank(
        event["turnId"],
        params["turnId"],
        params["turn_id"]
    )
    val threadId = firstNonBlank(
        event["threadId"],
        params["threadId"],
        params["thread_id"]
    )
    val directItemId = resolveCodexItemId(params, item)
    val parentTaskId = turnId ?: directItemId ?: threadId

    if (normalizedMethod == "turn_completed" || normalizedMethod == "thread_closed") {
        return WebCodexEventUpdate(
            parentTaskId = parentTaskId,
            terminalKind = "completed"
        )
    }
    if (
        normalizedMethod == "turn_failed" ||
        (normalizedMethod == "error" && params["willRetry"] != true)
    ) {
        return WebCodexEventUpdate(
            parentTaskId = parentTaskId,
            terminalKind = "error",
            errorMessage = extractCodexText(params["error"])
                .ifEmpty { extractCodexText(params["message"]) }
                .ifEmpty { "Codex 任务执行失败" }
        )
    }

    if (normalizedMethod == "codex_event") {
        val protocol = findCodexProtocolMessage(params)
        val protocolType = normalizeCodexEventToken(
            protocol["type"]?.toString().orEmpty()
        )
        val protocolItemId = resolveCodexItemId(protocol, protocol)
        val protocolParent = firstNonBlank(
            protocol["turnId"],
            protocol["turn_id"],
            turnId,
            protocolItemId,
            threadId
        )
        val assistantEntryId = codexEntryId(
            protocolItemId ?: protocolParent,
            "agent"
        )
        val reasoningEntryId = codexEntryId(
            protocolItemId ?: protocolParent,
            "thinking"
        )
        return when {
            protocolType in setOf(
                "agent_message_delta",
                "assistant_message_delta",
                "output_text_delta"
            ) -> WebCodexEventUpdate(
                assistantEntryId = assistantEntryId,
                assistantDelta = extractCodexDelta(protocol),
                parentTaskId = protocolParent
            )
            protocolType in setOf(
                "agent_message",
                "assistant_message",
                "output_text"
            ) -> WebCodexEventUpdate(
                assistantEntryId = assistantEntryId,
                assistantSnapshot = extractCodexText(protocol).takeIf(String::isNotEmpty),
                parentTaskId = protocolParent
            )
            protocolType in setOf(
                "reasoning_delta",
                "reasoning_content_delta",
                "reasoning_text_delta",
                "agent_reasoning_delta"
            ) -> WebCodexEventUpdate(
                reasoningEntryId = reasoningEntryId,
                reasoningDelta = extractCodexDelta(protocol),
                parentTaskId = protocolParent
            )
            protocolType in setOf(
                "reasoning",
                "reasoning_content",
                "reasoning_summary"
            ) -> WebCodexEventUpdate(
                reasoningEntryId = reasoningEntryId,
                reasoningSnapshot = extractCodexText(protocol).takeIf(String::isNotEmpty),
                parentTaskId = protocolParent
            )
            protocolType in setOf(
                "task_complete",
                "turn_complete",
                "turn_completed"
            ) -> WebCodexEventUpdate(
                parentTaskId = protocolParent,
                terminalKind = "completed"
            )
            protocolType in setOf(
                "turn_aborted",
                "task_failed",
                "turn_failed",
                "error"
            ) -> WebCodexEventUpdate(
                parentTaskId = protocolParent,
                terminalKind = "error",
                errorMessage = extractCodexText(protocol).ifEmpty {
                    "Codex 任务执行失败"
                }
            )
            isCodexToolEventType(protocolType) -> WebCodexEventUpdate(
                parentTaskId = protocolParent,
                tool = buildToolUpdate(
                    raw = protocol,
                    itemType = protocolType,
                    itemId = protocolItemId ?: protocolParent,
                    parentTaskId = protocolParent,
                    fallbackStatus = codexProtocolToolStatus(protocolType)
                )
            )
            else -> WebCodexEventUpdate(parentTaskId = protocolParent)
        }
    }

    val assistantEntryId = codexEntryId(directItemId ?: parentTaskId, "agent")
    val reasoningEntryId = codexEntryId(directItemId ?: parentTaskId, "thinking")
    if (
        normalizedMethod == "item_agentmessage_delta" ||
        normalizedMethod == "item_agent_message_delta"
    ) {
        return WebCodexEventUpdate(
            assistantEntryId = assistantEntryId,
            assistantDelta = extractCodexDelta(params),
            parentTaskId = parentTaskId
        )
    }
    if (
        normalizedMethod.contains("reasoning") &&
        normalizedMethod.contains("delta")
    ) {
        return WebCodexEventUpdate(
            reasoningEntryId = reasoningEntryId,
            reasoningDelta = extractCodexDelta(params),
            parentTaskId = parentTaskId
        )
    }
    if (
        normalizedMethod == "item_completed" ||
        normalizedMethod == "item_updated" ||
        normalizedMethod == "item_started" ||
        normalizedMethod == "rawresponseitem_completed" ||
        normalizedMethod == "raw_response_item_completed"
    ) {
        val canonicalItemType = canonicalCodexItemType(item["type"]?.toString())
        val text = extractCodexText(item)
        val completed = normalizedMethod.contains("completed")
        return when {
            canonicalItemType == "agentMessage" ||
                (
                    canonicalItemType == "message" &&
                        item["role"]?.toString() == "assistant"
                    ) -> WebCodexEventUpdate(
                assistantEntryId = assistantEntryId,
                assistantSnapshot = text.takeIf(String::isNotEmpty),
                assistantFinal = completed,
                parentTaskId = parentTaskId
            )
            canonicalItemType == "reasoning" ||
                canonicalItemType.startsWith("reasoning") -> WebCodexEventUpdate(
                reasoningEntryId = reasoningEntryId,
                reasoningSnapshot = text.takeIf(String::isNotEmpty),
                reasoningFinal = completed,
                parentTaskId = parentTaskId
            )
            isCodexToolItemType(canonicalItemType) -> WebCodexEventUpdate(
                parentTaskId = parentTaskId,
                tool = buildToolUpdate(
                    raw = item,
                    itemType = canonicalItemType,
                    itemId = directItemId ?: parentTaskId,
                    parentTaskId = parentTaskId,
                    fallbackStatus = if (completed) "success" else "running"
                )
            )
            else -> WebCodexEventUpdate(parentTaskId = parentTaskId)
        }
    }
    return WebCodexEventUpdate(parentTaskId = parentTaskId)
}

private fun buildToolUpdate(
    raw: Map<String, Any?>,
    itemType: String,
    itemId: String?,
    parentTaskId: String?,
    fallbackStatus: String
): WebCodexToolUpdate {
    val canonicalType = canonicalCodexItemType(itemType)
    val toolName = firstNonBlank(
        raw["toolName"],
        raw["tool_name"],
        raw["name"],
        raw["command"],
        canonicalType
    ).orEmpty()
    val suffix = codexToolCardSuffix(canonicalType, inferToolType(canonicalType, toolName))
    return WebCodexToolUpdate(
        entryId = codexEntryId(itemId, suffix),
        parentTaskId = parentTaskId,
        itemType = canonicalType,
        status = normalizeCodexToolStatus(raw, fallbackStatus),
        raw = raw
    )
}

private fun mergeToolUpdate(
    existing: WebCodexToolUpdate,
    incoming: WebCodexToolUpdate
): WebCodexToolUpdate {
    val status = if (codexToolStatusRank(incoming.status) >=
        codexToolStatusRank(existing.status)
    ) {
        incoming.status
    } else {
        existing.status
    }
    return incoming.copy(
        entryId = incoming.entryId ?: existing.entryId,
        parentTaskId = incoming.parentTaskId ?: existing.parentTaskId,
        status = status,
        raw = existing.raw + incoming.raw
    )
}

private fun resolveCodexItemId(
    container: Map<String, Any?>,
    item: Map<String, Any?>
): String? {
    return firstNonBlank(
        container["itemId"],
        container["item_id"],
        container["callId"],
        container["call_id"],
        item["id"],
        item["callId"],
        item["call_id"],
        container["processId"],
        container["processHandle"],
        container["id"]
    )
}

private fun codexEntryId(base: String?, suffix: String): String? {
    return base?.trim()?.takeIf(String::isNotEmpty)?.let { "$it-codex-$suffix" }
}

private fun canonicalCodexItemType(raw: String?): String {
    val normalized = raw?.trim().orEmpty()
    return when (normalized) {
        "agent_message" -> "agentMessage"
        "user_message" -> "userMessage"
        "command_execution" -> "commandExecution"
        "file_change" -> "fileChange"
        "mcp_tool_call" -> "mcpToolCall"
        "dynamic_tool_call" -> "dynamicToolCall"
        "web_search" -> "webSearch"
        "image_view" -> "imageView"
        "image_generation" -> "imageGeneration"
        "collab_agent_tool_call" -> "collabAgentToolCall"
        "collab_tool_call" -> "collabToolCall"
        "todo_list" -> "plan"
        else -> normalized
    }
}

private fun isCodexToolItemType(itemType: String): Boolean {
    return canonicalCodexItemType(itemType) in setOf(
        "commandExecution",
        "local_shell_call",
        "commandExec",
        "processExecution",
        "fileChange",
        "tool",
        "mcpToolCall",
        "dynamicToolCall",
        "function_call",
        "function_call_output",
        "custom_tool_call",
        "custom_tool_call_output",
        "tool_search_call",
        "tool_search_output",
        "webSearch",
        "web_search_call",
        "imageView",
        "imageGeneration",
        "image_generation_call",
        "collabAgentToolCall",
        "collabToolCall",
        "plan"
    )
}

private fun isCodexToolEventType(type: String): Boolean {
    return isCodexToolItemType(type) ||
        type.contains("tool") ||
        type.contains("command") ||
        type.contains("exec") ||
        type.contains("search") ||
        type.contains("file_change")
}

private fun codexProtocolToolStatus(type: String): String {
    return when {
        type.contains("fail") || type.contains("error") -> "error"
        type.contains("abort") || type.contains("cancel") -> "interrupted"
        type.contains("complete") || type.contains("end") || type.contains("output") ->
            "success"
        else -> "running"
    }
}

private fun normalizeCodexToolStatus(
    raw: Map<String, Any?>,
    fallback: String
): String {
    if (raw["error"] != null || raw["success"] == false) return "error"
    val exitCode = (raw["exitCode"] as? Number)?.toInt()
        ?: (raw["exit_code"] as? Number)?.toInt()
    if (exitCode != null && exitCode != 0) return "error"
    return when (firstNonBlank(raw["status"], raw["state"])?.lowercase()) {
        "running", "pending", "progress", "inprogress", "in_progress",
        "executing", "started" -> "running"
        "success", "succeeded", "completed", "complete", "applied", "done" -> "success"
        "error", "failed", "failure", "rejected" -> "error"
        "cancelled", "canceled", "incomplete", "interrupted", "aborted" -> "interrupted"
        "timeout", "timedout" -> "timeout"
        else -> if (raw["success"] == true) "success" else fallback
    }
}

private fun codexToolStatusRank(status: String): Int {
    return when (status) {
        "running" -> 0
        "interrupted" -> 1
        "timeout" -> 2
        "error" -> 3
        "success" -> 4
        else -> 0
    }
}

private fun inferToolType(itemType: String, toolName: String): String {
    val raw = "$itemType $toolName".lowercase()
    return when {
        raw.contains("command") || raw.contains("shell") || raw.contains("exec") ||
            raw.contains("process") -> "terminal"
        raw.contains("file") || raw.contains("read") || raw.contains("write") ||
            raw.contains("edit") -> "file"
        raw.contains("search") -> "search"
        raw.contains("browser") || raw.contains("web") || raw.contains("navigate") ->
            "browser"
        raw.contains("image") -> "image"
        raw.contains("mcp") -> "mcp"
        raw.contains("collab") || raw.contains("agent") -> "subagent"
        raw.contains("plan") -> "plan"
        else -> "builtin"
    }
}

private fun codexToolCardSuffix(itemType: String, toolType: String): String {
    return when {
        itemType == "fileChange" || toolType == "file" -> "file"
        itemType == "plan" || toolType == "plan" -> "plan"
        toolType == "search" -> "search"
        toolType == "browser" -> "browser"
        toolType == "image" -> "image"
        toolType == "terminal" -> "command"
        else -> "tool"
    }
}

private fun defaultToolTitle(toolType: String): String {
    return when (toolType) {
        "terminal" -> "运行命令"
        "file" -> "处理文件"
        "search" -> "搜索"
        "browser" -> "浏览网页"
        "image" -> "处理图片"
        "subagent" -> "运行子任务"
        else -> "工具调用"
    }
}

private fun extractCodexDelta(value: Any?): String {
    val map = normalizeMap(value)
    return sequenceOf("delta", "text", "outputText", "output_text", "content")
        .map { key -> extractCodexText(map[key]) }
        .firstOrNull { it.isNotEmpty() }
        .orEmpty()
}

private fun extractCodexText(value: Any?, depth: Int = 0): String {
    if (depth > 8 || value == null) return ""
    return when (value) {
        is String -> value
        is Number, is Boolean -> ""
        is List<*> -> value.joinToString("") { item ->
            extractCodexText(item, depth + 1)
        }
        is Map<*, *> -> {
            val map = normalizeMap(value)
            sequenceOf(
                "text",
                "delta",
                "output_text",
                "outputText",
                "content",
                "message",
                "summary"
            ).map { key -> extractCodexText(map[key], depth + 1) }
                .firstOrNull { it.isNotEmpty() }
                .orEmpty()
        }
        else -> ""
    }
}

private fun findCodexProtocolMessage(
    value: Any?,
    depth: Int = 0
): Map<String, Any?> {
    if (depth > 8) return emptyMap()
    val map = normalizeMap(value)
    val direct = normalizeMap(map["msg"])
    if (direct.isNotEmpty()) return direct
    val type = map["type"]?.toString()?.trim().orEmpty()
    if (type.isNotEmpty() && type != "codex/event") return map
    for (key in listOf("event", "message", "data", "payload", "params")) {
        val nested = findCodexProtocolMessage(map[key], depth + 1)
        if (nested.isNotEmpty()) return nested
    }
    return emptyMap()
}

private fun normalizeCodexEventToken(value: String): String {
    return value.trim()
        .lowercase()
        .replace('/', '_')
        .replace('.', '_')
        .replace('-', '_')
}

private fun normalizeMap(value: Any?): Map<String, Any?> {
    return (value as? Map<*, *>)?.entries?.associate { (key, rawValue) ->
        key.toString() to rawValue
    }.orEmpty()
}

private fun firstNonBlank(vararg values: Any?): String? {
    return values.asSequence()
        .mapNotNull { it?.toString()?.trim()?.takeIf(String::isNotEmpty) }
        .firstOrNull()
}

private fun Map<String, Any?>.readString(key: String): String? {
    return this[key]?.toString()?.trim()?.takeIf { it.isNotEmpty() }
}

private fun Map<String, Any?>.readLong(key: String): Long? {
    return when (val raw = this[key]) {
        is Number -> raw.toLong()
        is String -> raw.trim().toLongOrNull()
        else -> null
    }
}
