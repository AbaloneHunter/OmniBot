package com.rk.libcommons

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OmnibotTerminalEnvironmentTest {
    @Test
    fun `managed Codex API key is available to terminal processes`() {
        assertEquals(
            mapOf(OmnibotTerminalEnvironment.CODEX_API_ENV_KEY to "secret"),
            OmnibotTerminalEnvironment.buildManagedCodexEnvironment(
                authMode = "api",
                apiKey = " secret "
            )
        )
        assertTrue(
            OmnibotTerminalEnvironment.buildManagedCodexEnvironment(
                authMode = "chatgpt",
                apiKey = "secret"
            ).isEmpty()
        )
    }

    @Test
    fun `user variables cannot override managed Codex API key`() {
        val normalized = OmnibotTerminalEnvironment.normalizeVariables(
            linkedMapOf(
                "EXAMPLE" to "value",
                OmnibotTerminalEnvironment.CODEX_API_ENV_KEY to "override"
            )
        )

        assertEquals("value", normalized["EXAMPLE"])
        assertFalse(normalized.containsKey(OmnibotTerminalEnvironment.CODEX_API_ENV_KEY))
    }
}
