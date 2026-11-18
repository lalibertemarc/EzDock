std = "lua51"
max_line_length = false
self = false
exclude_files = { "tests/" }

globals = {
    "EzDockDB",
    "EzDockCharDB",
    "EzDockAPI",
    "SLASH_EZDOCK1",
    "SLASH_EZDOCK2",
    "SlashCmdList",
    "_G",
}

read_globals = {
    -- Lua / WoW utility
    "strtrim", "hooksecurefunc", "SecureHandlerSetFrameRef",
    -- Frames & UI
    "CreateFrame", "UIParent", "ChatFrame1", "GameTooltip", "DEFAULT_CHAT_FRAME",
    -- Settings
    "Settings", "CreateSettingsListSectionHeaderInitializer", "CreateSettingsButtonInitializer",
    "MinimalSliderWithSteppersMixin",
    -- Namespaced APIs
    "C_AddOns", "C_Timer",
    -- Global APIs
    "IsAddOnLoaded", "InCombatLockdown",
}
