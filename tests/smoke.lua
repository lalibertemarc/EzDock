-- Loads EzDock against a stubbed game API and drives it: login, taking icons in, an icon that pops up,
-- addons placing their own icons, folding, reordering, late icons, combat, giving icons back.
-- lua tests/smoke.lua (inside the addon folder). Catches nil calls and wrong state, not looks.
local checks, failed = 0, 0
local function check(ok, what)
    checks = checks + 1
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

---------------------------------------------------------------------------
-- Stubs
---------------------------------------------------------------------------
local combat = false
local loaded = { EzLines = true, EzRecruit = true, EzNotebook = true, EzChronicle = true }
local printed = {}

-- Anything: every field is a function returning anything (Settings API and friends).
local anything
anything = setmetatable({}, {
    __index = function() return anything end,
    __call = function() return anything end,
})

local function Widget(kind, name, parent)
    local w = {
        kind = kind, name = name, parent = parent, scripts = {}, shown = true, points = {}, scale = 1,
        width = 24, height = 24, alpha = 1, attrs = {}, movable = false, level = 1,
    }
    local methods = {
        SetScript = function(self, s, fn) self.scripts[s] = fn end,
        GetScript = function(self, s) return self.scripts[s] end,
        HookScript = function(self, s, fn)
            local old = self.scripts[s]
            self.scripts[s] = function(...)
                if old then old(...) end
                fn(...)
            end
        end,
        Show = function(self)
            local was = self.shown
            self.shown = true
            if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
        end,
        Hide = function(self)
            local was = self.shown
            self.shown = false
            if was and self.scripts.OnHide then self.scripts.OnHide(self) end
        end,
        SetShown = function(self, on) if on then self:Show() else self:Hide() end end,
        IsShown = function(self) return self.shown end,
        IsProtected = function() return false end,
        SetParent = function(self, p) self.parent = p end,
        GetParent = function(self) return self.parent end,
        SetScale = function(self, s) self.scale = s end,
        GetScale = function(self) return self.scale end,
        GetEffectiveScale = function(self) return self.scale end,
        SetSize = function(self, w2, h) self.width, self.height = w2, h end,
        GetWidth = function(self) return self.width end,
        GetHeight = function(self) return self.height end,
        ClearAllPoints = function(self) self.points = {} end,
        SetPoint = function(self, ...) self.points[#self.points + 1] = { n = select("#", ...), ... } end,
        SetAllPoints = function() end,
        GetNumPoints = function(self) return #self.points end,
        GetPoint = function(self, i)
            local p = self.points[i]
            return p[1], p[2], p[3], p[4], p[5]
        end,
        GetCenter = function(self) if self.center then return self.center[1], self.center[2] end end,
        SetMovable = function(self, on) self.movable = on end,
        IsMovable = function(self) return self.movable end,
        StartMoving = function(self) self.moving = true end,
        StopMovingOrSizing = function(self) self.moving = false end,
        SetAlpha = function(self, a) self.alpha = a end,
        GetAlpha = function(self) return self.alpha end,
        SetFrameLevel = function(self, l) self.level = l end,
        GetFrameLevel = function(self) return self.level end,
        SetAttribute = function(self, k, v) self.attrs[k] = v end,
        SetBackdropBorderColor = function(self, r, g, b, a) self.border = { r, g, b, a } end,
        GetBackdropBorderColor = function(self)
            if self.border then return self.border[1], self.border[2], self.border[3], self.border[4] end
            return 0, 0, 0, 1
        end,
        SetText = function(self, t) self.text = t end,
        IsMouseOver = function() return false end,
        CreateTexture = function(self) return Widget("Texture", nil, self) end,
        CreateFontString = function(self) return Widget("FontString", nil, self) end,
    }
    -- Capitalized names are methods (unknown ones do nothing); lowercase ones are plain fields.
    return setmetatable(w, { __index = function(_, k)
        if methods[k] then return methods[k] end
        if k:match("^[A-Z]") then return function() end end
    end })
end

local events
_G.CreateFrame = function(kind, name, parent)
    local f = Widget(kind, name, parent)
    f.RegisterEvent = function(self) events = self end
    if name then _G[name] = f end
    return f
end
_G.UIParent = Widget("Frame", "UIParent")
UIParent.width, UIParent.height = 1920, 1080
_G.ChatFrame1 = Widget("Frame", "ChatFrame1")
_G.GameTooltip = Widget("GameTooltip")
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) printed[#printed + 1] = msg end }
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.InCombatLockdown = function() return combat end
_G.C_AddOns = { IsAddOnLoaded = function(a) return loaded[a] == true, loaded[a] == true end }
local timers = {}
_G.C_Timer = { After = function(s, fn) timers[#timers + 1] = { s = s, fn = fn } end }
local function runTimers()
    local due = timers
    timers = {}
    for _, t in ipairs(due) do t.fn() end
end
_G.hooksecurefunc = function(t, name, fn)
    local orig = t[name]
    t[name] = function(...)
        orig(...)
        fn(...)
    end
end
_G.SlashCmdList = {}
_G.SecureHandlerSetFrameRef = function(frame, label, ref) frame.attrs["frameref-" .. label] = ref end
_G.Settings = setmetatable({ RegisterVerticalLayoutCategory = function() return anything, anything end },
    { __index = function() return anything end })
_G.CreateSettingsListSectionHeaderInitializer = anything
_G.CreateSettingsButtonInitializer = anything
_G.MinimalSliderWithSteppersMixin = anything

-- Launcher icons as our addons build them: on UIParent, above the chat box, draggable.
local function Launcher(name, x)
    local b = CreateFrame("Button", name, UIParent)
    b:SetMovable(true)
    local drag = function(self) self:StartMoving() end
    b:SetScript("OnDragStart", drag)
    b.ownDrag = drag
    b:SetPoint("BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", x, 28)
    return b
end

local lines = Launcher("EzLinesIcon", -112)
local recruit = Launcher("EzRecruitWelcomeButton", -168)
recruit:Hide() -- nobody waits for a welcome
local notebook = Launcher("EzNotebookIcon", -196)

---------------------------------------------------------------------------
-- Load
---------------------------------------------------------------------------
local ns = {}
for _, file in ipairs({ "Data.lua", "Layout.lua", "Core.lua", "Settings.lua" }) do
    local chunk = assert(loadfile(file))
    chunk("EzDock", ns)
end
local bar = _G.EzDockBar
local handle = _G.EzDockHandle
bar.center = { 500, 300 }
_G.EzDockFrame.center = { 500, 300 }

local function fire(event, ...) events.scripts.OnEvent(events, event, ...) end
local function slash(msg) SlashCmdList.EZDOCK(msg) end
local function slotOf(b)
    for i, e in ipairs(ns.shown) do
        if e.button == b then return i end
    end
end
local function onBar(b)
    return b.parent == bar and #b.points == 1 and b.points[1][2] == bar
end

---------------------------------------------------------------------------
-- Pure rules
---------------------------------------------------------------------------
do
    local slots, box = ns.Slots(3, { dir = "LEFT", perRow = 0, size = 24, gap = 4, handle = 12, wrap = 1 })
    check(#slots == 3 and slots[1].x == -(6 + 4 + 12) and slots[1].y == 0, "first slot left of the handle")
    check(slots[2].x == slots[1].x - 28, "slots one step apart")
    check(box.right == 6 and box.left == slots[3].x - 12 and box.top == 12, "box covers handle and icons")
    slots = ns.Slots(5, { dir = "UP", perRow = 2, size = 20, gap = 0, handle = 10, wrap = -1 })
    check(slots[1].x == 0 and slots[1].y == 15 and slots[3].x == -20 and slots[3].y == 15, "columns wrap left")
    check(ns.Nearest(slots, -19, 34) == 4, "nearest slot")

    local order = { "A", "B", "C", "D" }
    check(ns.Reorder(order, { "A", "B", "D" }, "A", 3) and table.concat(order) == "BCDA", "dragged forward lands after")
    order = { "A", "B", "C", "D" }
    check(ns.Reorder(order, { "A", "C", "D" }, "D", 1) and table.concat(order) == "DABC", "dragged back lands before")
    check(not ns.Reorder(order, { "D" }, "D", 1), "dropped on itself")
    check(ns.Move(order, "D", 1) and table.concat(order) == "ADBC", "move down")
    check(not ns.Move(order, "A", -1), "first can't go up")
    check(ns.IsGold(1, 0.82, 0) and not ns.IsGold(0, 0, 0) and not ns.IsGold(nil), "gold border")
end

---------------------------------------------------------------------------
-- Login
---------------------------------------------------------------------------
fire("ADDON_LOADED", "EzDock")
fire("PLAYER_LOGIN")
check(onBar(lines) == false, "nothing taken before the frame after login")
runTimers()

check(onBar(lines) and onBar(notebook), "known icons taken into the dock")
check(recruit.parent == bar, "hidden icon taken in too")
check(#ns.shown == 2 and slotOf(lines) == 1 and slotOf(notebook) == 2, "hidden icon leaves no gap")
check(lines.scripts.OnDragStart ~= lines.ownDrag, "dock drags while docked")
check(handle.count.text == "", "no count while unfolded")

-- EzRecruit's button pops up when someone joins: it takes its place in the order.
recruit:Show()
check(#ns.shown == 3 and slotOf(recruit) == 2 and onBar(recruit), "popped-up icon slots in by order")
local recruitX = recruit.points[1][4]
check(recruitX == ns.slots[2].x, "popped-up icon at its slot")
recruit:Hide()
check(#ns.shown == 2 and slotOf(notebook) == 2, "gap closes when it hides")
recruit:Show()

-- An addon placing its own icon (a reset, a login Place) doesn't pull it out.
lines:ClearAllPoints()
lines:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 10, 500)
check(onBar(lines), "own SetPoint caught, icon stays docked")

-- Folding: the secure snippet hides the bar; our hook saves it and marks the handle.
recruit:SetBackdropBorderColor(1, 0.82, 0, 1)
bar:Hide()
handle.scripts.OnClick(handle, "LeftButton")
check(ns.char.collapsed == true, "folded state saved")
check(handle.pip.shown and handle.count.text == 3, "gold mark and count while folded")
recruit:SetBackdropBorderColor(0, 0, 0, 1)
check(not handle.pip.shown, "mark gone once nothing waits")
bar:Show()
handle.scripts.OnClick(handle, "LeftButton")
check(ns.char.collapsed == false and handle.count.text == "", "unfolded")

-- An addon that builds its icon late (here, after login) is found by the scan.
local chronicle = Launcher("EzChronicleIcon", -56)
runTimers()
check(onBar(chronicle) and slotOf(chronicle) == 1, "late icon docked at its default place")

-- Drag to reorder: drop EzLines on the last slot.
local last = #ns.shown
lines.scripts.OnDragStart(lines)
check(lines.moving, "drag starts")
lines.center = { 500 + ns.slots[last].x, 300 + ns.slots[last].y }
lines.scripts.OnDragStop(lines)
check(slotOf(lines) == last and onBar(lines), "dropped icon takes the slot")
slash("lock")
lines.scripts.OnDragStart(lines)
check(not lines.moving, "locked: no drag")
slash("unlock")

-- Giving one back: where its addon last put it, with its own drag.
slash("remove ezlines")
check(lines.parent == UIParent and lines.points[1][2] == UIParent and lines.points[1][5] == 500,
    "given back where its addon last put it")
check(lines.scripts.OnDragStart == lines.ownDrag, "its own drag back")
lines:SetPoint("CENTER", UIParent, "CENTER", 1, 2)
check(lines.parent == UIParent, "hooks quiet once given back")
slash("add EzLines")
check(onBar(lines), "added back")

-- Combat: taking in waits for the end of the fight; icons popping up still slot in.
combat = true
local other = CreateFrame("Button", "SomeAddonIcon", UIParent)
check(EzDockAPI.Add(other, { key = "SomeAddon", label = "Some Addon" }), "API add accepted")
check(other.parent == UIParent and not EzDockAPI.Owns(other), "not taken in combat")
recruit:Hide()
check(slotOf(recruit) == nil and #ns.shown == 3, "hide in combat reflows")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(EzDockAPI.Owns(other) and onBar(other), "taken after combat")
check(ns.db.order[#ns.db.order] == "SomeAddon", "new addon added at the end of the order")

-- Off gives everything back, on takes it again.
slash("off")
check(notebook.parent == UIParent and chronicle.parent == UIParent and other.parent == UIParent, "off gives all back")
check(not _G.EzDockFrame.shown, "dock hidden while off")
slash("on")
check(onBar(notebook) and onBar(other), "on takes them again")

EzDockAPI.Remove("SomeAddon")
check(other.parent == UIParent and not EzDockAPI.Owns(other), "API remove gives it back")

-- Slash odds and ends.
slash("list")
slash("up")
check(ns.db.dir == "UP" and ns.slots[1].x == 0, "direction change lays out again")
slash("fold")
check(not bar.shown and ns.char.collapsed, "slash fold")
slash("unfold")
slash("remove zzz")
check(printed[#printed]:find("No icon called"), "unknown name")
slash("bogus")
check(printed[#printed]:find("Unknown command"), "unknown command")

print(("%d checks, %d failed"):format(checks, failed))
if failed > 0 then os.exit(1) end
