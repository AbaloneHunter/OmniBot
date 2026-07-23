package cn.com.omnimind.bot.webchat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WebConversationCreationTest {
    @Test
    fun `stored conversation mode wins over a stale Agent request fallback`() {
        assertEquals(
            "codex",
            resolveWebConversationMode(
                storedMode = "codex",
                requestedMode = "normal"
            )
        )
        assertEquals(
            "chat_only",
            resolveWebConversationMode(
                storedMode = "chat_only",
                requestedMode = null
            )
        )
    }

    @Test
    fun `each stored mode selects its own runtime`() {
        assertEquals(
            WebConversationRunKind.AGENT,
            resolveWebConversationRunKind("normal")
        )
        assertEquals(
            WebConversationRunKind.CODEX,
            resolveWebConversationRunKind("codex")
        )
        assertEquals(
            WebConversationRunKind.CHAT_ONLY,
            resolveWebConversationRunKind("chat_only")
        )
    }

    @Test
    fun `pure chat content keeps history and current image input`() {
        val content = buildWebPureChatContent(
            existingMessages = listOf(
                mapOf(
                    "id" to "assistant-1",
                    "type" to 1,
                    "user" to 2,
                    "content" to mapOf("text" to "上一条回复")
                ),
                mapOf(
                    "id" to "user-1",
                    "type" to 1,
                    "user" to 1,
                    "content" to mapOf("text" to "上一条问题")
                )
            ),
            userMessage = "继续",
            attachments = listOf(
                mapOf(
                    "fileName" to "photo.png",
                    "mimeType" to "image/png",
                    "isImage" to true,
                    "dataUrl" to "data:image/png;base64,AA=="
                )
            )
        )

        assertEquals(listOf("user", "assistant", "user"), content.map { it["role"] })
        val currentBlocks = content.last()["content"] as List<*>
        assertEquals("text", (currentBlocks[0] as Map<*, *>)["type"])
        assertEquals("image_url", (currentBlocks[1] as Map<*, *>)["type"])
    }

    @Test
    fun `codex stream events are mapped to web updates`() {
        val assistantUpdate = parseWebCodexEvent(
            mapOf(
                "method" to "item/agentMessage/delta",
                "turnId" to "turn-1",
                "params" to mapOf(
                    "itemId" to "item-1",
                    "delta" to "hello"
                )
            )
        )
        assertEquals("hello", assistantUpdate.assistantDelta)
        assertEquals("item-1-codex-agent", assistantUpdate.assistantEntryId)
        assertEquals("turn-1", assistantUpdate.parentTaskId)

        assertEquals(
            "thinking",
            parseWebCodexEvent(
                mapOf(
                    "method" to "item/reasoning/textDelta",
                    "turnId" to "turn-1",
                    "params" to mapOf(
                        "itemId" to "reasoning-1",
                        "delta" to "thinking"
                    )
                )
            ).reasoningDelta
        )
        assertEquals(
            "completed",
            parseWebCodexEvent(
                mapOf("method" to "turn/completed")
            ).terminalKind
        )
    }

    @Test
    fun `codex tool lifecycle keeps a stable card id and terminal status`() {
        val started = parseWebCodexEvent(
            mapOf(
                "method" to "item/started",
                "turnId" to "turn-2",
                "params" to mapOf(
                    "item" to mapOf(
                        "id" to "command-1",
                        "type" to "commandExecution",
                        "command" to "pwd",
                        "status" to "running"
                    )
                )
            )
        ).tool
        val completed = parseWebCodexEvent(
            mapOf(
                "method" to "item/completed",
                "turnId" to "turn-2",
                "params" to mapOf(
                    "item" to mapOf(
                        "id" to "command-1",
                        "type" to "commandExecution",
                        "command" to "pwd",
                        "status" to "completed"
                    )
                )
            )
        ).tool

        assertEquals("command-1-codex-command", started?.entryId)
        assertEquals("running", started?.status)
        assertEquals(started?.entryId, completed?.entryId)
        assertEquals("success", completed?.status)
        assertEquals("turn-2", completed?.parentTaskId)
    }

    @Test
    fun `first user message becomes the conversation title like Flutter`() {
        assertEquals("帮我分析这个项目", deriveWebConversationTitle("  帮我分析这个项目  "))
        assertEquals(
            "12345678901234567890...",
            deriveWebConversationTitle("123456789012345678901234")
        )
        assertNull(deriveWebConversationTitle("   "))
    }
}
