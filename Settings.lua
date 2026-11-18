-- Options page: Esc > Options > AddOns > EzDock, with an "Icons" subpage (which icons, in what order).
-- Built at login, once the saved variables exist.
local _, ns = ...

local ROW_H = 26
local LIST_WIDTH = 520

local function BuildButtonsPage(parent)
    local panel = CreateFrame("Frame")
    local category = Settings.RegisterCanvasLayoutSubcategory(parent, panel, "Icons")

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Icons")
    local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    help:SetWidth(LIST_WIDTH)
    help:SetJustifyH("LEFT")
    help:SetText("Ticked icons sit in the dock, in this order (you can also drag them in the dock). "
        .. "An icon its addon hides keeps its place and shows up when its addon shows it, "
        .. "like EzRecruit's when someone joins your guild. Addons added later show up here by themselves.")

    local rows = {}

    local function Arrow(row, text, delta, x)
        local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        b:SetSize(26, 20)
        b:SetPoint("LEFT", row, "LEFT", x, 0)
        b:SetText(text)
        b:SetScript("OnClick", function()
            if ns.Move(ns.db.order, row.key, delta) then
                ns.Layout()
                ns.RefreshButtonsPage()
            end
        end)
        return b
    end

    local function Row(i)
        local row = CreateFrame("Frame", nil, panel)
        row:SetSize(LIST_WIDTH, ROW_H)
        row:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -12 - (i - 1) * ROW_H)
        row.up = Arrow(row, "^", -1, 0)
        row.down = Arrow(row, "v", 1, 28)
        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(24, 24)
        row.check:SetPoint("LEFT", row, "LEFT", 60, 0)
        row.check:SetScript("OnClick", function(self)
            ns.SetDocked(row.key, self:GetChecked())
            ns.RefreshButtonsPage()
        end)
        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
        row.label:SetWidth(200)
        row.label:SetJustifyH("LEFT")
        row.state = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.state:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
        row.state:SetJustifyH("LEFT")
        rows[i] = row
        return row
    end

    local STATE_COLOR = {
        docked = { 0.5, 0.9, 0.5 }, hidden = { 0.8, 0.8, 0.8 }, out = { 0.6, 0.6, 0.6 },
        absent = { 0.5, 0.5, 0.5 }, waiting = { 1, 0.82, 0 }, off = { 0.6, 0.6, 0.6 },
    }

    function ns.RefreshButtonsPage()
        if not panel:IsVisible() then return end
        local order = ns.db.order
        for i, key in ipairs(order) do
            local row = rows[i] or Row(i)
            row.key = key
            local state, text = ns.State(key)
            row.label:SetText(ns.Label(key))
            row.state:SetText(text)
            local c = STATE_COLOR[state] or STATE_COLOR.hidden
            row.state:SetTextColor(c[1], c[2], c[3])
            row.check:SetChecked(not ns.db.skip[key])
            row.check:SetEnabled(state ~= "absent")
            row.up:SetEnabled(i > 1)
            row.down:SetEnabled(i < #order)
            row:Show()
        end
        for i = #order + 1, #rows do rows[i]:Hide() end
    end

    panel:SetScript("OnShow", ns.RefreshButtonsPage)
    return category
end

function ns.BuildSettings()
    local db = ns.db
    local category, layout = Settings.RegisterVerticalLayoutCategory("EzDock")
    ns.settingsCategory = category

    local function Header(text)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end

    local function Button(name, text, onClick, tooltip)
        layout:AddInitializer(CreateSettingsButtonInitializer(name, text, onClick, tooltip, false))
    end

    local function Checkbox(variable, key, label, tooltip, onChange)
        local setting = Settings.RegisterAddOnSetting(category, variable, key, db, Settings.VarType.Boolean,
            label, ns.DEFAULTS[key])
        Settings.CreateCheckbox(category, setting, tooltip)
        if onChange then setting:SetValueChangedCallback(onChange) end
        return setting
    end

    local function Slider(variable, key, label, lo, hi, step, format, tooltip)
        local options = Settings.CreateSliderOptions(lo, hi, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format)
        local setting = Settings.RegisterAddOnSetting(category, variable, key, db, Settings.VarType.Number,
            label, ns.DEFAULTS[key])
        Settings.CreateSlider(category, setting, options, tooltip)
        setting:SetValueChangedCallback(function() ns.Apply() end)
    end

    local icons = BuildButtonsPage(category)

    Header("The dock")
    Checkbox("EZDOCK_ENABLED", "enabled", "Use the dock",
        "Off: every icon goes back where its own addon puts it. Also /dock on|off.", function() ns.Apply() end)
    Checkbox("EZDOCK_LOCKED", "locked", "Lock the dock",
        "Locked: dragging the handle or an icon does nothing. Unlocked: drag the handle to move the dock, an icon to change the order.")
    Button("Icons", "Choose", function() Settings.OpenToCategory(icons:GetID()) end,
        "Which icons go in the dock and in what order.")
    Button("Fold", "Fold / unfold", function() ns.SetCollapsed(not ns.char.collapsed) end,
        "Folds the icons into the handle, or brings them back. Clicking the handle does the same, in combat too. Remembered per character.")
    Button("Position", "Reset", function() ns.ResetPosition() end, "Puts the dock back above the chat box.")

    Header("Look")
    local dir = Settings.RegisterAddOnSetting(category, "EZDOCK_DIR", "dir", db, Settings.VarType.String,
        "Icons go", ns.DEFAULTS.dir)
    Settings.CreateDropdown(category, dir, function()
        local container = Settings.CreateControlTextContainer()
        for _, d in ipairs(ns.DIRS) do container:Add(d.key, d.label, d.desc) end
        return container:GetData()
    end, "Which way the icons line up from the handle. Extra rows grow toward the middle of the screen.")
    dir:SetValueChangedCallback(function() ns.Apply() end)

    Slider("EZDOCK_PER_ROW", "perRow", "Icons per row", 0, ns.PER_ROW_MAX, 1,
        function(v) return v == 0 and "One line" or tostring(v) end,
        "How many icons before a new row (or column) starts. One line: never.")
    Slider("EZDOCK_SIZE", "size", "Icon size", ns.SIZE_MIN, ns.SIZE_MAX, 1,
        function(v) return ("%d"):format(v) end, "Every docked icon is this many pixels wide.")
    Slider("EZDOCK_GAP", "gap", "Spacing", 0, ns.GAP_MAX, 1,
        function(v) return ("%d"):format(v) end, "Pixels between icons.")
    Slider("EZDOCK_FADE", "fade", "Faded opacity", ns.FADE_MIN, 100, 5,
        function(v) return v >= 100 and "Never fade" or ("%d%%"):format(v) end,
        "How see-through the dock is while the mouse is elsewhere. It shows fully while an icon waits for you (a gold border).")
    Checkbox("EZDOCK_BACKGROUND", "background", "Background", "A dark panel behind the icons.",
        function() ns.Apply() end)

    Settings.RegisterAddOnCategory(category)
end

function ns.OpenSettings()
    if InCombatLockdown() then return ns.Print("Options open after combat.") end
    if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()) end
end
