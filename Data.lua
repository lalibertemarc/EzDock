-- Static tables. The dock takes in our launcher icons by their global names (no change needed in those addons);
-- any other addon can hand it a button with EzDockAPI.Add (see Core.lua).
local _, ns = ...

ns.TITLE = "EzDock"

-- Launcher icons the dock takes in by itself, in the dock's default order (the old row above the chat box,
-- right to left). `addon` is checked with IsAddOnLoaded; `name` is the button's global name. A new launcher
-- of ours goes at the end of this list (or calls EzDockAPI.Add itself).
ns.KNOWN = {
    { key = "EzEmote", addon = "EzEmote", name = "EzEmoteIcon", label = "EzEmote" },
    { key = "EzOutfitter", addon = "EzOutfitter", name = "EzOutfitterIcon", label = "EzOutfitter" },
    { key = "EzAcquaintances", addon = "EzAcquaintances", name = "EzAcquaintancesIcon", label = "EzAcquaintances" },
    { key = "EzChronicle", addon = "EzChronicle", name = "EzChronicleIcon", label = "Chronicle" },
    { key = "WanderersAtlas", addon = "WanderersAtlas", name = "WanderersAtlasIcon", label = "Wanderer's Atlas" },
    { key = "EzLines", addon = "EzLines", name = "EzLinesIcon", label = "EzLines" },
    { key = "EzLevelBuddies", addon = "EzLevelBuddies", name = "EzLevelBuddiesIcon", label = "Level Buddies" },
    { key = "EzRecruit", addon = "EzRecruit", name = "EzRecruitWelcomeButton", label = "EzRecruit welcomes" },
    { key = "EzNotebook", addon = "EzNotebook", name = "EzNotebookIcon", label = "EzNotebook" },
}

-- Account-wide look (EzDockDB). fade is a percent: the dock's alpha while the mouse is elsewhere.
ns.DEFAULTS = {
    enabled = true,
    dir = "LEFT",
    perRow = 0, -- 0 = one line
    size = 24,
    gap = 4,
    fade = 100,
    background = true,
    locked = false,
}

ns.DIRS = {
    { key = "LEFT", label = "Leftward", desc = "Icons line up to the left of the handle." },
    { key = "RIGHT", label = "Rightward", desc = "Icons line up to the right of the handle." },
    { key = "UP", label = "Upward", desc = "Icons stack above the handle." },
    { key = "DOWN", label = "Downward", desc = "Icons stack below the handle." },
}

ns.HANDLE = 12       -- the handle's thickness along the line
ns.PAD = 3           -- background margin around the icons
ns.SIZE_MIN, ns.SIZE_MAX = 16, 40
ns.GAP_MAX = 12
ns.PER_ROW_MAX = 12
ns.FADE_MIN = 10
ns.SCAN_EVERY = 2    -- seconds between looks for a known icon whose addon builds it late
ns.SCAN_FOR = 60     -- stop looking after this long
ns.FADE_TICK = 0.15
