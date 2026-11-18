-- The dock: one handle, our launcher icons lined up beside it.
--
-- Icons are taken in, not copied: the dock re-parents the real button into its bar, so its gold border,
-- glow and count keep working. While docked, the button's drag scripts are the dock's (drag = reorder) and any
-- SetPoint its addon makes is caught (hooksecurefunc) and the button put back in its slot; on release the
-- scripts, parent, scale and the last place its addon gave it come back.
--
-- Collapsing is a secure click (SecureHandlerClickTemplate on the handle, the bar is a SecureFrameTemplate),
-- so it works in combat even if a secure button is docked one day. Taking in, releasing, moving or resizing
-- the dock waits for the end of combat; a non-secure icon that shows or hides in combat still gets its slot.
local _, ns = ...

local entries, keys, byButton = {}, {}, {}
ns.entries, ns.keys = entries, keys
ns.shown, ns.slots = {}, {}

local db, char
local ready = false
local pending = false -- something waits for the end of combat
local placing = false -- our own SetPoint calls, which the hooks skip
local dragging

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffEzDock|r: " .. msg)
end
ns.Print = Print

local function Loaded(addon)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return (C_AddOns.IsAddOnLoaded(addon)) end
    return IsAddOnLoaded and IsAddOnLoaded(addon)
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local dock = CreateFrame("Frame", "EzDockFrame", UIParent)
dock:SetFrameStrata("MEDIUM")
dock:SetSize(ns.HANDLE, ns.DEFAULTS.size)
dock:SetMovable(true)
dock:SetClampedToScreen(true)

local bar = CreateFrame("Frame", "EzDockBar", dock, "SecureFrameTemplate")
bar:SetSize(1, 1)
bar:SetPoint("CENTER")

local FLAT = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

local bg = CreateFrame("Frame", nil, bar, "BackdropTemplate")
bg:SetBackdrop(FLAT)
bg:SetFrameLevel(bar:GetFrameLevel())

local handle = CreateFrame("Button", "EzDockHandle", dock, "SecureHandlerClickTemplate,BackdropTemplate")
handle:SetAllPoints(dock)
handle:SetBackdrop(FLAT)
handle:SetBackdropColor(0.05, 0.05, 0.06, 0.7)
handle:SetBackdropBorderColor(0, 0, 0, 1)
handle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
handle:RegisterForDrag("LeftButton")
-- The global, not a :SetFrameRef method: the handler templates add no methods (Forever, BugSack 2026-11-18).
SecureHandlerSetFrameRef(handle, "bar", bar)
handle:SetAttribute("_onclick", [=[
    if button ~= "LeftButton" then return end
    local bar = self:GetFrameRef("bar")
    if bar:IsShown() then bar:Hide() else bar:Show() end
]=])

handle.arrow = handle:CreateTexture(nil, "ARTWORK")
handle.arrow:SetSize(10, 10)
handle.arrow:SetPoint("CENTER")
handle.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")

handle.count = handle:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
handle.count:SetPoint("BOTTOM", 0, 1)

handle.pip = handle:CreateTexture(nil, "OVERLAY")
handle.pip:SetSize(6, 6)
handle.pip:SetPoint("TOPRIGHT", 2, 2)
handle.pip:SetColorTexture(1, 0.82, 0, 1)
handle.pip:Hide()

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
-- Docked icons with something waiting (a gold border, or the API's attention function).
function ns.Waiting()
    local list = {}
    for _, e in ipairs(ns.shown) do
        local ok = e.gold
        if not ok and e.attention then
            local fine, on = pcall(e.attention)
            ok = fine and on
        end
        if ok then list[#list + 1] = e end
    end
    return list
end

local ANGLE = { RIGHT = 0, UP = math.pi / 2, LEFT = math.pi, DOWN = -math.pi / 2 }

function ns.UpdateHandle()
    if not db then return end
    local collapsed = not bar:IsShown()
    local angle = ANGLE[db.dir] or 0
    if not collapsed then angle = angle + math.pi end -- points back: click folds the icons in
    if handle.arrow.SetRotation then handle.arrow:SetRotation(angle) end
    local waiting = collapsed and #ns.Waiting() > 0
    handle.count:SetText(collapsed and #ns.shown > 0 and #ns.shown or "")
    handle.pip:SetShown(waiting)
    if waiting then handle:SetBackdropBorderColor(1, 0.82, 0, 0.9) else handle:SetBackdropBorderColor(0, 0, 0, 1) end
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
local function PlaceButton(e, slot)
    local b = e.button
    local s = e.base * db.size / e.w0
    local was = placing
    placing = true
    b:SetScale(s)
    b:ClearAllPoints()
    -- Offsets are in the button's own scale.
    b:SetPoint("CENTER", bar, "CENTER", slot.x / s, slot.y / s)
    placing = was
end

-- Extra rows grow toward the middle of the screen.
local function WrapSign()
    local x, y = dock:GetCenter()
    if not x then return 1 end
    if ns.Horizontal(db.dir) then
        return y < (UIParent:GetHeight() or 0) / 2 and 1 or -1
    end
    return x < (UIParent:GetWidth() or 0) / 2 and 1 or -1
end

function ns.Layout()
    if not ready then return end
    local combat = InCombatLockdown()
    local horizontal = ns.Horizontal(db.dir)
    if not combat then
        local w, h = ns.HANDLE, db.size
        if not horizontal then w, h = h, w end
        dock:SetSize(w, h)
    end

    local shown = {}
    for _, key in ipairs(db.order) do
        local e = entries[key]
        if e and e.owned and e.button:IsShown() then shown[#shown + 1] = e end
    end
    ns.shown = shown

    local slots, box = ns.Slots(#shown, {
        dir = db.dir, perRow = db.perRow, size = db.size, gap = db.gap, handle = ns.HANDLE, wrap = WrapSign(),
    })
    ns.slots = slots
    for i, e in ipairs(shown) do
        if e ~= dragging then
            if combat and e.button:IsProtected() then
                pending = true
            else
                PlaceButton(e, slots[i])
            end
        end
    end

    bg:ClearAllPoints()
    bg:SetPoint("BOTTOMLEFT", bar, "CENTER", box.left - ns.PAD, box.bottom - ns.PAD)
    bg:SetSize(box.right - box.left + 2 * ns.PAD, box.top - box.bottom + 2 * ns.PAD)
    bg:SetShown(#shown > 0)
    if db.background then
        bg:SetBackdropColor(0.05, 0.05, 0.06, 0.5)
        bg:SetBackdropBorderColor(0, 0, 0, 0.8)
    else
        bg:SetBackdropColor(0, 0, 0, 0)
        bg:SetBackdropBorderColor(0, 0, 0, 0)
    end
    ns.UpdateHandle()
end

---------------------------------------------------------------------------
-- Taking icons in and giving them back
---------------------------------------------------------------------------
local function Reanchor(e)
    if InCombatLockdown() and e.button:IsProtected() then
        pending = true
        return
    end
    for i, s in ipairs(ns.shown) do
        if s == e then return PlaceButton(e, ns.slots[i]) end
    end
    ns.Layout() -- newly shown: everyone may move
end

local function Hook(e)
    if e.hooked then return end
    e.hooked = true
    local b = e.button
    -- Its addon placing it (a reset, a login Place): remember where, put it back in its slot.
    hooksecurefunc(b, "ClearAllPoints", function()
        if placing or not e.owned then return end
        e.foreign = {}
    end)
    hooksecurefunc(b, "SetPoint", function(_, ...)
        if placing or not e.owned then return end
        e.foreign = e.foreign or {}
        e.foreign[#e.foreign + 1] = { n = select("#", ...), ... }
        Reanchor(e)
    end)
    b:HookScript("OnShow", function() if e.owned then ns.Layout() end end)
    b:HookScript("OnHide", function() if e.owned then ns.Layout() end end)
    if b.SetBackdropBorderColor then
        hooksecurefunc(b, "SetBackdropBorderColor", function(_, r, g, bl)
            e.gold = ns.IsGold(r, g, bl)
            if e.owned then ns.UpdateHandle() end
        end)
    end
end

local function DragStart(self)
    local e = byButton[self]
    if not e or not e.owned or db.locked or InCombatLockdown() then return end
    dragging = e
    self:StartMoving()
end

local function DragStop(self)
    local e = byButton[self]
    if not e then return end
    self:StopMovingOrSizing()
    pcall(self.SetUserPlaced, self, false)
    if dragging ~= e then return end
    dragging = nil
    -- Where it was dropped, in the bar's units, from the dock's center.
    local x, y = self:GetCenter()
    local cx, cy = bar:GetCenter()
    if x and cx then
        local s = self:GetEffectiveScale() / bar:GetEffectiveScale()
        local t = ns.Nearest(ns.slots, x * s - cx, y * s - cy)
        local shownKeys = {}
        for i, s2 in ipairs(ns.shown) do shownKeys[i] = s2.key end
        if t then ns.Reorder(db.order, shownKeys, e.key, t) end
    end
    ns.Layout()
    if ns.RefreshButtonsPage then ns.RefreshButtonsPage() end
end

local function Take(e)
    local b = e.button
    local saved = {
        parent = b:GetParent(), scale = b:GetScale(), level = b:GetFrameLevel(), movable = b:IsMovable(),
        dragStart = b:GetScript("OnDragStart"), dragStop = b:GetScript("OnDragStop"), points = {},
    }
    for i = 1, b:GetNumPoints() do saved.points[i] = { n = 5, b:GetPoint(i) } end
    e.saved, e.foreign = saved, nil
    e.base = saved.scale or 1
    local w = b:GetWidth()
    e.w0 = (w and w > 0) and w or db.size
    Hook(e)
    if b.GetBackdropBorderColor then e.gold = ns.IsGold(b:GetBackdropBorderColor()) end
    e.owned = true
    placing = true
    b:SetParent(bar)
    b:SetFrameLevel(bar:GetFrameLevel() + 3)
    b:SetMovable(true)
    pcall(b.SetUserPlaced, b, false)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", DragStart)
    b:SetScript("OnDragStop", DragStop)
    placing = false
end

local function Release(e)
    local b, s = e.button, e.saved
    e.owned = false
    placing = true
    b:SetParent(s.parent)
    b:SetScale(s.scale)
    b:SetFrameLevel(s.level)
    b:SetScript("OnDragStart", s.dragStart)
    b:SetScript("OnDragStop", s.dragStop)
    b:SetMovable(s.movable)
    b:ClearAllPoints()
    local points = (e.foreign and #e.foreign > 0) and e.foreign or s.points
    for _, p in ipairs(points) do b:SetPoint(unpack(p, 1, p.n)) end
    if #points == 0 then b:SetPoint("CENTER", UIParent, "CENTER") end
    placing = false
end

local function Wanted(e)
    return ready and db.enabled and not db.skip[e.key]
end

-- Takes in / gives back every icon so it matches the settings. Waits for the end of combat.
function ns.Sync()
    if not ready then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    for _, key in ipairs(keys) do
        local e = entries[key]
        local want = Wanted(e)
        if want and not e.owned then
            Take(e)
        elseif not want and e.owned then
            Release(e)
        end
    end
    dock:SetShown(db.enabled)
    ns.Layout()
end

local function Register(button, info)
    local key = info.key
    local e = entries[key]
    if e then
        if e.button == button then return e end
        if e.owned then return nil end -- another button under that key is docked; keep it
        byButton[e.button] = nil
    else
        keys[#keys + 1] = key
    end
    e = e or { key = key }
    e.button, e.label, e.attention = button, info.label or key, info.attention
    entries[key] = e
    byButton[button] = e
    if db then ns.MergeOrder(db.order, key) end
    return e
end

-- Looks for known icons whose addons are loaded. True if one is loaded but has no icon yet.
local function Scan()
    local missing = false
    for _, k in ipairs(ns.KNOWN) do
        if not entries[k.key] and Loaded(k.addon) then
            local b = _G[k.name]
            if type(b) == "table" and b.GetObjectType then Register(b, k) else missing = true end
        end
    end
    return missing
end

---------------------------------------------------------------------------
-- Dock placement, collapse, fade
---------------------------------------------------------------------------
function ns.PlaceDock()
    if InCombatLockdown() then
        pending = true
        return
    end
    dock:ClearAllPoints()
    local p = db.pos
    if p then
        dock:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p[1], p[2])
    else
        dock:SetPoint("BOTTOMRIGHT", ChatFrame1 or UIParent, "TOPRIGHT", 0, 28)
    end
end

function ns.SetCollapsed(on)
    if InCombatLockdown() then
        Print("Use the handle in combat; the setting waits for the end of the fight.")
        char.collapsed = on
        pending = true
        return
    end
    char.collapsed = on and true or false
    bar:SetShown(not char.collapsed)
    ns.UpdateHandle()
end

handle:HookScript("OnClick", function(_, button)
    if button == "RightButton" then
        if ns.OpenSettings then ns.OpenSettings() end
        return
    end
    char.collapsed = not bar:IsShown()
    ns.UpdateHandle()
    GameTooltip:Hide()
end)

handle:SetScript("OnDragStart", function()
    if db.locked or InCombatLockdown() then return end
    dock:StartMoving()
end)
handle:SetScript("OnDragStop", function()
    dock:StopMovingOrSizing()
    pcall(dock.SetUserPlaced, dock, false)
    local x, y = dock:GetCenter()
    if x then db.pos = { x, y } end
    ns.PlaceDock()
    ns.Layout()
end)

handle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("EzDock")
    local collapsed = not bar:IsShown()
    GameTooltip:AddLine(("%d icon%s%s"):format(#ns.shown, #ns.shown == 1 and "" or "s", collapsed and ", folded" or ""),
        0.9, 0.9, 0.9)
    for _, e in ipairs(ns.Waiting()) do GameTooltip:AddLine(e.label .. " waits for you", 1, 0.82, 0) end
    GameTooltip:AddLine(collapsed and "Click: unfold" or "Click: fold", 0.8, 0.8, 0.8)
    if not db.locked then
        GameTooltip:AddLine("Drag: move the dock", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag an icon: reorder", 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("Right-click: options", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
handle:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Fade: the dock's alpha while the mouse is elsewhere, full while something waits.
local fadeWait = 0
local function Fade(_, elapsed)
    fadeWait = fadeWait + elapsed
    if fadeWait < ns.FADE_TICK then return end
    fadeWait = 0
    local over = dragging or handle:IsMouseOver() or (bar:IsShown() and bg:IsShown() and bg:IsMouseOver())
    local alpha = (over or #ns.Waiting() > 0) and 1 or db.fade / 100
    if dock:GetAlpha() ~= alpha then dock:SetAlpha(alpha) end
end

function ns.UpdateFade()
    if db.fade < 100 then
        dock:SetScript("OnUpdate", Fade)
    else
        dock:SetScript("OnUpdate", nil)
        dock:SetAlpha(1)
    end
end

---------------------------------------------------------------------------
-- API for other addons
---------------------------------------------------------------------------
-- EzDockAPI.Add(button, { key = "MyAddon", label = "My Addon", attention = function() return bool end })
--   Docks a launcher button (taken in at once, or at login / after combat). key is saved in the dock's order.
--   Nothing else is needed: the dock catches the addon's own SetPoint calls and drags while it holds the button.
-- EzDockAPI.Remove(key)  gives the button back where its addon last put it.
-- EzDockAPI.Owns(button) true while the dock holds it.
-- EzDockAPI.Refresh()    lays the dock out again (after an attention change, say).
EzDockAPI = {
    Add = function(button, info)
        if type(button) ~= "table" or type(info) ~= "table" or type(info.key) ~= "string" then return false end
        local e = Register(button, info)
        if e then ns.Sync() end
        return e ~= nil
    end,
    Remove = function(key)
        local e = entries[key]
        if not e then return end
        if e.owned then
            if InCombatLockdown() then
                e.removing = true
                pending = true
                return
            end
            Release(e)
        end
        byButton[e.button] = nil
        entries[key] = nil
        table.remove(keys, ns.IndexOf(keys, key))
        ns.Layout()
    end,
    Owns = function(button)
        local e = byButton[button]
        return e ~= nil and e.owned == true
    end,
    Refresh = function() ns.Layout() end,
}

---------------------------------------------------------------------------
-- Settings changes (slash and options page)
---------------------------------------------------------------------------
function ns.Apply()
    ns.Sync()
    ns.UpdateFade()
end

function ns.ResetPosition()
    db.pos = nil
    ns.PlaceDock()
    ns.Layout()
end

-- A registered or known key from what was typed: key or label, whole, else the only one starting with it.
function ns.FindKey(text)
    text = (text or ""):lower()
    if text == "" then return nil end
    local all = {}
    for _, key in ipairs(db.order) do
        local e = entries[key]
        all[#all + 1] = { key = key, label = e and e.label or key }
    end
    for _, a in ipairs(all) do
        if a.key:lower() == text or a.label:lower() == text then return a.key end
    end
    local found
    for _, a in ipairs(all) do
        if a.key:lower():find(text, 1, true) == 1 or a.label:lower():find(text, 1, true) == 1 then
            if found then return nil, "several" end
            found = a.key
        end
    end
    return found
end

function ns.Label(key)
    local e = entries[key]
    if e then return e.label end
    for _, k in ipairs(ns.KNOWN) do
        if k.key == key then return k.label end
    end
    return key
end

-- What a key's row says: docked, hidden by its addon, left out, not loaded.
function ns.State(key)
    local e = entries[key]
    if db.skip[key] then return "out", "left out of the dock" end
    if not e then return "absent", "not loaded" end
    if not db.enabled then return "off", "the dock is off" end
    if not e.owned then return "waiting", "joins after combat" end
    if not e.button:IsShown() then return "hidden", "hidden by its addon" end
    return "docked", "docked"
end

function ns.SetDocked(key, on)
    db.skip[key] = (not on) or nil
    ns.Sync()
end

---------------------------------------------------------------------------
-- Slash
---------------------------------------------------------------------------
local HELP = {
    "/dock - options",
    "/dock fold | unfold - fold the icons into the handle (the handle also does it, in combat too)",
    "/dock lock | unlock - stop or allow dragging the dock and its icons",
    "/dock left | right | up | down - which way the icons line up",
    "/dock list - every icon and where it is",
    "/dock add | remove <name> - put an icon in the dock or give it back",
    "/dock on | off - use the dock (off gives every icon back)",
    "/dock reset - the dock back above the chat box",
}

SLASH_EZDOCK1 = "/dock"
SLASH_EZDOCK2 = "/ezdock"
SlashCmdList.EZDOCK = function(msg)
    if not ready then return Print("Not ready yet.") end
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "" or cmd == "config" or cmd == "options" then
        if ns.OpenSettings then ns.OpenSettings() end
    elseif cmd == "help" then
        for _, line in ipairs(HELP) do Print(line) end
    elseif cmd == "fold" or cmd == "collapse" then
        ns.SetCollapsed(true)
    elseif cmd == "unfold" or cmd == "expand" then
        ns.SetCollapsed(false)
    elseif cmd == "toggle" then
        ns.SetCollapsed(bar:IsShown())
    elseif cmd == "lock" or cmd == "unlock" then
        db.locked = cmd == "lock"
        Print(db.locked and "Locked." or "Unlocked: drag the handle to move the dock, an icon to reorder.")
    elseif cmd == "left" or cmd == "right" or cmd == "up" or cmd == "down" then
        db.dir = cmd:upper()
        ns.Layout()
    elseif cmd == "list" then
        for i, key in ipairs(db.order) do
            local _, text = ns.State(key)
            Print(("%d. %s - %s"):format(i, ns.Label(key), text))
        end
    elseif cmd == "add" or cmd == "remove" then
        local key, why = ns.FindKey(rest)
        if not key then
            return Print(why and ("Several icons start with \"%s\"; type more of the name."):format(rest)
                or ("No icon called \"%s\". /dock list shows them."):format(rest))
        end
        ns.SetDocked(key, cmd == "add")
        Print(("%s %s."):format(ns.Label(key), cmd == "add" and "goes in the dock" or "is out of the dock"))
    elseif cmd == "on" or cmd == "off" then
        db.enabled = cmd == "on"
        ns.Apply()
        Print(db.enabled and "The dock is on." or "The dock is off; every icon is back where its addon puts it.")
    elseif cmd == "reset" then
        ns.ResetPosition()
        Print("The dock is back above the chat box.")
    else
        Print("Unknown command. /dock help lists them.")
    end
    if ns.RefreshButtonsPage then ns.RefreshButtonsPage() end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function Defaults()
    EzDockDB = EzDockDB or {}
    db = EzDockDB
    for k, v in pairs(ns.DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    db.skip = db.skip or {}
    if not db.order then
        db.order = {}
        for _, k in ipairs(ns.KNOWN) do db.order[#db.order + 1] = k.key end
    end
    for _, key in ipairs(keys) do ns.MergeOrder(db.order, key) end -- added before our saves loaded
    EzDockCharDB = EzDockCharDB or {}
    char = EzDockCharDB
    ns.db, ns.char = db, char
end

-- Known icons built late (after login) are looked for a while.
local function ScanLater(left)
    C_Timer.After(ns.SCAN_EVERY, function()
        if Scan() and left > ns.SCAN_EVERY then ScanLater(left - ns.SCAN_EVERY) end
        ns.Sync()
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg == "EzDock" then Defaults() end
    elseif event == "PLAYER_LOGIN" then
        if not db then Defaults() end
        if ns.BuildSettings then ns.BuildSettings() end
        -- A frame later: every addon's own PLAYER_LOGIN has built and placed its icon by then.
        C_Timer.After(0, function()
            ready = true
            ns.PlaceDock()
            if not InCombatLockdown() then bar:SetShown(not char.collapsed) end
            if Scan() then ScanLater(ns.SCAN_FOR) end
            ns.Apply()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        if ready then
            Scan()
            ns.Sync()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if dragging then
            local e = dragging
            dragging = nil
            e.button:StopMovingOrSizing()
            ns.Layout()
        end
        dock:StopMovingOrSizing()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending and ready then
            pending = false
            local removing = {}
            for _, key in ipairs(keys) do
                if entries[key].removing then removing[#removing + 1] = key end
            end
            for _, key in ipairs(removing) do
                entries[key].removing = nil
                EzDockAPI.Remove(key)
            end
            ns.PlaceDock()
            bar:SetShown(not char.collapsed)
            ns.Sync()
        end
    end
end)
