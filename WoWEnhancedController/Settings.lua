local _, W = ...
local O = {}
W.Options = O
-- Forever owns the Settings focus groups and the Back action that leaves the
-- content pane. Only use our raw navigation in clients without that cursor.
function O.NativeNavigation()
    return SmartNavigation and SmartNavigation.GetCurrentButton and SMART_NAV_INPUT_DIRECTION
        and type(SmartNavigation_AddJumpNavigationOverride) == "function"
end
local function canvasEntry()
    local f=O.bindingEditor
    if f and f:IsVisible() then
        local row=f.selected
        return f.footer[f.footerIndex] or row.button or row.cells[f.column]
    end
    f=O.appearanceFrame
    if f and f:IsVisible() then return f.controls[f.selected] end
    if W.Radial.editorInSettings and W.Radial.editor:IsVisible() then
        local control=W.Radial.editorControls[W.Radial.editorSelected or 1]
        return control and (control.input or control)
    end
end
function O.FocusCanvasControl(target)
    if target and target:IsVisible() and not W.Combat() and O.NativeNavigation()
        and SmartNavigation.GetActiveFrame and SmartNavigation:GetActiveFrame()==SettingsPanel and SmartNavigation:IsInFocusGroup() then
        O.canvasTarget=target
        SmartNavigation:SetTargetButtonForFrame(SettingsPanel,target)
    end
end
local function syncContentFocus(panel)
    local nav=SmartNavigation
    if W.Combat() or not O.NativeNavigation() or nav:GetActiveFrame()~=panel then return end
    local current=nav:GetCurrentButton()
    if nav:IsInFocusGroup() then
        -- Forever's FocusContainer can select a hidden SettingsList checkbox
        -- when the newly opened category uses a canvas instead of a list.
        if current and current:IsVisible() then return end
        O.FocusCanvasControl(canvasEntry())
    elseif O.canvasTarget then
        -- The native Back/left-edge handler has already chosen its destination.
        local info=nav:GetPanelInfo(panel,true)
        if info and info.targetButton==O.canvasTarget then nav:SetTargetButtonForFrame(panel,current) end
        O.canvasTarget=nil
    end
end
function O.Apply()
    W.Input:Refresh()
    W.QuickMove:Clear()
    if W.Launcher then W.Launcher:PositionIcon(); W.Launcher:Close() end
    if not W.Combat() then
        if not W.db.enabled then W.Keyboard:Close(); W.Radial:CloseEditor() end
        W.Radial:Rebuild()
        if W.Keyboard.frame:IsShown() then W.Keyboard:Draw() end
        if O.appearanceFrame then O.PaintAppearance() end
    else W.Radial.pending = true end
end
function O.Init()
    if O.category or not Settings or not Settings.RegisterVerticalLayoutCategory then return end
    local category = Settings.RegisterVerticalLayoutCategory("Enhanced Controller")
    O.category = category
    if SettingsPanel and SettingsPanel.FocusContainer and SettingsPanel.UnfocusContainer and hooksecurefunc then
        hooksecurefunc(SettingsPanel,"FocusContainer",syncContentFocus)
        hooksecurefunc(SettingsPanel,"UnfocusContainer",syncContentFocus)
    end
    if Settings.RegisterCanvasLayoutSubcategory then
        local canvas = CreateFrame("Frame", "WoWEnhancedControllerSpellsSettings", UIParent)
        canvas:Hide()
        local combatMessage = W.Theme.Label(canvas, W.L["Change settings outside combat."])
        combatMessage:SetPoint("TOPLEFT", 24, -24); combatMessage:Hide()
        canvas:SetScript("OnShow", function()
            if W.Combat() then combatMessage:Show(); return end
            combatMessage:Hide()
            if not W.Radial.editor then W.Radial:CreateEditor(canvas) end
            W.Radial:PresentEditor()
        end)
        canvas:SetScript("OnHide", function()
            if not W.Radial.editor then return end
            W.Radial:ClearEditorFocus()
            W.Radial.editor:Hide()
        end)
        O.spellsCategory = Settings.RegisterCanvasLayoutSubcategory(category, canvas, W.L["Wheel spells / macros"])
        O.RegisterBindingCanvas(category)
        O.RegisterAppearanceCanvas(category)
    end
    local function setting(key, db, kind, text, default)
        local variable = (db == W.db.radial and "WEC_RADIAL_" or "WEC_") .. key
        local value = Settings.RegisterAddOnSetting(category, variable, key, db, kind, W.L[text], default)
        value:SetValueChangedCallback(O.Apply)
        return value
    end
    local function checkbox(key, db, text, default)
        Settings.CreateCheckbox(category, setting(key, db, Settings.VarType.Boolean, text, default))
    end
    checkbox("enabled", W.db, "Enable Enhanced Controller", true)
    checkbox("quickMove", W.db, "Enable bank / mail quick move", true)
    checkbox("minimapVisible", W.db, "Show minimap button", true)
    checkbox("enabled", W.db.radial, "Enable party / raid wheel", true)
    checkbox("defaultR3", W.db.radial, "Use R3 to open the wheel", true)
    checkbox("health", W.db.radial, "Show health bars", true)
    checkbox("largeKeys", W.db, "Large keys", false)
    checkbox("swapNintendo", W.db, "Nintendo A confirm", true)
    checkbox("debuffs", W.db.radial, "Show dispellable debuffs", true)
    local function slider(key, db, text, default, low, high, step)
        local options = Settings.CreateSliderOptions(low, high, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, key == "scale" and function(value)
            return string.format("%d%%", math.floor(value * 100 + 0.5))
        end or tostring)
        Settings.CreateSlider(category, setting(key, db, Settings.VarType.Number, text, default), options)
    end
    slider("fontSize", W.db, "Font size", 14, 12, 20, 1)
    slider("scale", W.db, "Window scale", 1, 0.6, 1.5, 0.05)
    slider("size", W.db.radial, "Wheel diameter", 480, 380, 520, 20)
    local function dropdown(key, db, text, default, values)
        Settings.CreateDropdown(category, setting(key, db, Settings.VarType.String, text, default), function()
            local container = Settings.CreateControlTextContainer()
            for _, entry in ipairs(values) do container:Add(entry[1], W.L[entry[2]]) end
            return container:GetData()
        end)
    end
    dropdown("style", W.db, "Button icons", "Xbox", { {"Xbox","Xbox"}, {"PlayStation","PlayStation"}, {"Nintendo","Nintendo"}, {"Auto","Auto"} })
    dropdown("activation", W.db, "Keyboard activation", "controller", { {"controller","Controller"}, {"always","Always"} })
    dropdown("behavior", W.db.radial, "Healing wheel behavior", "sweep", {
        {"sweep","Hold & sweep"}, {"classic","Classic"}, {"target","Target only"},
    })
    dropdown("afterAction", W.db.radial, "After wheel action", "members", {
        {"members","Return to member selection"}, {"target","Reopen on selected member"}, {"close","Close after selection"},
    })
    local function button(text, caption, run, leaveSettings)
        local initializer = CreateSettingsButtonInitializer(W.L[text], W.L[caption], function()
            if W.Combat() then W.Print(W.L["Change settings outside combat."]); return end
            if leaveSettings and SettingsPanel then SettingsPanel:Hide() end
            run()
        end, nil, true)
        Settings.RegisterInitializer(category, initializer)
    end
    button("Wheel spells / macros", "Edit spells", function() W.Radial:Edit() end)
    button("Wheel position", "Edit Mode", function() W.Placement.Enter("radial", true) end, true)
    button("Macro creator", "Create macros", function() W.MacroEditor:Open() end, true)
    button("Quick messages", "Assign messages", function() W.Keyboard:ShowQuickMessages() end, true)
    button("Position controls", "Edit Mode", function() W.Placement.Enter("keyboard", true) end, true)
    button("Controller bindings", "Remap buttons", O.OpenBindings)
    button("Keyboard appearance", "Customize", O.OpenAppearance)
    button("Launcher", "Open", function() W.Launcher:Open("launcher") end, true)
    button("Minimap buttons", "Open", function() W.Launcher:Open("minimap") end, true)
    button("Minimap button position", "Reset", function() W.db.minimapAngle = 225; W.Launcher:PositionIcon() end)
    button("Reset text / scale", "Reset", function() W.db.fontSize = 14; W.db.scale = 1; O.Apply(); O.Open() end)
    Settings.RegisterAddOnCategory(category)
end
function O.Open()
    if W.Combat() then W.Print(W.L["Change settings outside combat."]); return end
    if W.Keyboard.session or W.Keyboard.frame:IsShown() then W.Keyboard:Close() end
    if O.category then Settings.OpenToCategory(O.category:GetID()) else W.Print(W.L["Native Settings are unavailable."]) end
end
function O.OpenBindings()
    if W.Combat() then W.Print(W.L["Change settings outside combat."]); return end
    if W.Keyboard.session or W.Keyboard.frame:IsShown() then W.Keyboard:Close() end
    if O.bindingsCategory then Settings.OpenToCategory(O.bindingsCategory:GetID()) else O.Open() end
end
function O.AssignAction(action, token)
    if W.Combat() then return false, W.L["Change settings outside combat."] end
    if token == W.Input.keys.focus then return false, W.L["The focus button is reserved."] end
    if token:match("^PADD") then return false, W.L["D-pad directions are reserved for navigation."] end
    local other = W.Input.reverse[token]
    if token ~= "" and other and other ~= action then return false, W.L.Format("Used by %s. Unbind that action first.", W.L[other]) end
    W.db.actionBindings = W.db.actionBindings or {}; W.db.actionBindings[action] = token
    O.Apply(); return true
end
function O.RegisterBindingCanvas(category)
    local canvas = CreateFrame("Frame", "WoWEnhancedControllerBindingsSettings", UIParent); canvas:Hide()
    local blocked = W.Theme.Label(canvas, W.L["Change settings outside combat."]); blocked:SetPoint("TOPLEFT", 24, -24); blocked:Hide()
    canvas:SetScript("OnShow", function()
        if W.Combat() then blocked:Show(); return end
        blocked:Hide()
        if not O.bindingEditor then O.CreateBindingEditor(canvas) end
        O.bindingEditor:Show(); O.PaintBindings()
    end)
    canvas:SetScript("OnHide", function()
        O.bindingCapture, O.bindingHeld = false, nil
        if O.bindingEditor then O.bindingEditor:Hide() end
    end)
    O.bindingsCategory = Settings.RegisterCanvasLayoutSubcategory(category, canvas, W.L["Controller bindings"])
end
