local _, W = ...
local M = { view = "launcher", selected = 1, offset = 0, rows = {}, revision = 0 }
W.Launcher = M
local T, L = W.Theme, W.L
local visibleRows, rowHeight, rowSpacing = 9, 38, 5
local iconPath = "Interface\\AddOns\\WoWEnhancedController\\Media\\Icon.tga"
local function maskIcon(parent, texture)
    local mask = parent:CreateMaskTexture(nil, "OVERLAY")
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture); texture:AddMaskTexture(mask)
    return mask
end
local function tokens()
    local reverse = W.Input:Style() == "Nintendo" and W.db.swapNintendo
    return reverse and "PAD2" or "PAD1", reverse and "PAD1" or "PAD2", reverse and "PAD4" or "PAD3"
end
function M:IsShown() return self.frame and self.frame:IsShown() end
function M:Eligible()
    return self.frame and self.frame:IsVisible() and not W.Combat() and not W.Blocker() and not W.Focus()
        and not W.Input.active and not W.Placement.editing
        and not (SettingsPanel and SettingsPanel:IsShown())
        and not (W.IconPicker and W.IconPicker.request)
        and not W.Keyboard.frame:IsShown()
        and not (W.MacroEditor.frame and W.MacroEditor.frame:IsShown())
end
M.ReleaseControls = W.ReleaseMenuControls
function M:BindControls()
    local primary, back, secondary = tokens()
    local focus = W.UIFocusBindings()
    local signature = table.concat({ primary, back, secondary, unpack(focus) }, "|")
    local controls = {
        [primary] = "select", [back] = "close", [secondary] = "secondary",
        PADDUP = "up", PADDDOWN = "down", PADDLEFT = "launcher", PADDRIGHT = "minimap",
        PADLSHOULDER = "launcher", PADRSHOULDER = "minimap",
    }
    return W.BindMenuControls(self, "Launcher", controls, focus, signature)
end
function M:Close()
    self.held = nil
    if self.frame then self.frame:Hide() end
end
function M:RequestFocus()
    if not self:Eligible() then return false end
    if not self:BindControls() then
        W.Print(L["Controller capture unavailable in this client state."]); return false
    end
    self.held = nil; self.focusRequested = true
    self:Draw()
    return true
end
function M:Open(view)
    if W.Combat() then W.Print(L["Change settings outside combat."]); return false end
    if W.Blocker() or W.Focus() or W.Input.active or W.Placement.editing
        or (W.IconPicker and W.IconPicker.request)
        or (W.MacroEditor.frame and W.MacroEditor.frame:IsShown()) then
        W.Print(L["Close the current editor before opening the launcher."]); return false
    end
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    if W.Keyboard.frame:IsShown() then W.Keyboard:Close() end
    W.Radial:Close()
    if not self.frame then self:Create() end
    self.frame:SetScale(math.min(W.db.scale, (UIParent:GetHeight() - 40) / 660))
    self:SetView(view or "launcher")
    if self.frame:IsShown() then self:RequestFocus() else self.frame:Show() end
    W.Radial:SyncOwnership()
    return true
end
function M:Toggle(view)
    if self:IsShown() and self.view == (view or "launcher") then self:Close() else self:Open(view) end
end
function M:Entries()
    local function entry(label, run, group) return { label = L[label], run = run, group = group } end
    return {
        entry("Keyboard / chat", function()
            if ChatFrame_OpenChat then ChatFrame_OpenChat("") end
            local box = W.Focus(); if W.Usable(box) then W.Keyboard:Open(box) else W.Keyboard:Options() end
        end, L["Open"]),
        entry("Quick messages", function() W.Keyboard:ShowQuickMessages() end),
        entry("Party / raid wheel", function() W.Radial:Open() end),
        entry("Macro creator", function() W.MacroEditor:Open() end),
        entry("Wheel spells / macros", function() W.Radial:Edit() end, L["Configure"]),
        entry("Keyboard appearance", W.Options.OpenAppearance),
        entry("Controller bindings", W.Options.OpenBindings),
        entry("Position controls", function() W.Placement.Enter(); W.Input:Acquire(true) end),
        entry("Settings", W.Options.Open),
    }
end
function M:SetView(view)
    self.view, self.selected, self.offset, self.held = view, 1, 0, nil
    self.revision = self.revision + 1
    self.entries = view == "minimap" and W.MinimapTargets:Collect(true) or self:Entries()
    self:Draw()
end
function M:Refresh(full)
    if self.view ~= "minimap" then return end
    local old = self.entries[self.selected]
    local entries = W.MinimapTargets:Collect(full)
    local same = #entries == #self.entries
    for i, entry in ipairs(entries) do
        if not self.entries[i] or self.entries[i].frame ~= entry.frame or self.entries[i].label ~= entry.label then same = false end
    end
    if same then return end
    self.entries, self.held = entries, nil; self.revision = self.revision + 1
    self.selected = math.min(self.selected, math.max(1, #entries))
    for i, entry in ipairs(entries) do if old and entry.frame == old.frame then self.selected = i end end
    self:Draw()
end
function M:Select(index)
    if #self.entries == 0 then return end
    index = W.Clamp(index, 1, #self.entries)
    if index == self.selected then return end
    self.selected = index
    self:Draw()
end
function M:ScrollTo(offset, hoveredRow, fromScrollBar)
    if self.view ~= "minimap" or not self:Eligible() then return end
    offset = W.Clamp(math.floor(offset + .5), 0, math.max(0, #self.entries - visibleRows))
    if offset == self.offset then return end
    self.offset, self.held = offset, nil
    self.selected = hoveredRow and offset + hoveredRow or W.Clamp(self.selected, offset + 1, offset + visibleRows)
    self:Draw(fromScrollBar)
end
function M:Activate(mouseButton)
    local entry = self.entries[self.selected]
    if not entry then return end
    local minimap = self.view == "minimap"
    self:Close() -- Release before the target opens a native menu or input owner.
    if minimap then
        local ok, reason = W.MinimapTargets:Activate(entry, mouseButton or "LeftButton")
        if not ok then W.Print(reason) end
    elseif entry.run then entry.run() end
end
function M:Down(token)
    if not self:Eligible() then self.held = nil; return true end
    local action = self.menuKeys and self.menuKeys[token]
    if not action then return true end
    if self.waitForUp[token:match("(PAD[%w]+)$")] then return false end
    W.lastPad = true; W.Input.padAt = GetTime()
    if self.held then return self.held.token ~= token end
    self.held = { token = token, action = action, entry = self.entries[self.selected], revision = self.revision }
    if action == "up" then self:Select(self.selected - 1)
    elseif action == "down" then self:Select(self.selected + 1) end
    return false
end
function M:Up(token)
    if self.waitForUp then
        local button = token:match("(PAD[%w]+)$")
        if button then self.waitForUp[button] = nil end
    end
    local held = self.held
    if not held or held.token ~= token then return true end
    self.held = nil; W.Input.padAt = GetTime()
    if not self:Eligible() or held.revision ~= self.revision then return false end
    local action = held.action
    if action == "close" then self:Close()
    elseif action == "focus" then self:RequestFocus()
    elseif action == "launcher" or action == "minimap" then self:SetView(action)
    elseif held.entry == self.entries[self.selected] then
        if action == "select" then self:Activate("LeftButton")
        elseif action == "secondary" and self.view == "minimap" then self:Activate("RightButton") end
    end
    return false
end
function M:Draw(fromScrollBar)
    local primary, back, secondary = tokens()
    local minimap = self.view == "minimap"
    T.FocusBadge(self.focusButton, self.focusKey or false)
    for _, label in ipairs({ self.title, self.footer, self.command, self.empty }) do label:SetFontObject(T.Font("GameFontNormal")) end
    local maximum = math.max(0, #self.entries - visibleRows)
    local overflow = minimap and maximum > 0
    self.offset = W.Clamp(self.offset, math.max(0, self.selected - visibleRows), math.min(maximum, self.selected - 1))
    local bar = self.scrollBar
    bar:SetShown(overflow)
    if overflow then
        bar:SetVisibleExtentPercentage(visibleRows / #self.entries)
        bar:SetPanExtentPercentage(1 / maximum)
        if not fromScrollBar then bar:SetScrollPercentage(self.offset / maximum, true) end
    end
    local rowWidth = overflow and 312 or 332
    local tooltipOwner = GameTooltip and GameTooltip:GetOwner()
    local y = 110
    for i = 1, visibleRows do
        local b, index = self.rows[i], self.offset + i
        local entry = self.entries[index]
        b.group:Hide()
        b.group:SetFontObject(T.Font("GameFontHighlightSmall"))
        if entry then
            if entry.group then
                b.group:SetText(entry.group); b.group:ClearAllPoints(); b.group:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -y)
                b.group:Show(); y = y + 24
            end
            b.index = index; b:ClearAllPoints(); b:SetPoint("TOPLEFT", 14, -y); b:SetSize(rowWidth, rowHeight)
            T.KeyboardButton(b, "controller"); b:SetText(W.Escape(entry.label))
            local label = b:GetFontString(); label:ClearAllPoints(); label:SetPoint("LEFT", minimap and 42 or 12, 0)
            label:SetWidth(rowWidth - (minimap and 56 or 24)); label:SetJustifyH("LEFT"); label:SetWordWrap(false)
            if b == tooltipOwner then GameTooltip:SetText(W.Escape(entry.label)) end
            b.art:Hide()
            if b.artMasked then b.art:RemoveMaskTexture(b.artMask); b.artMasked = nil end
            if minimap then
                if entry.atlas then b.art:SetAtlas(entry.atlas) else b.art:SetTexture(entry.texture or 134400) end
                if entry.frame == self.icon then
                    if not b.artMask then b.artMask = maskIcon(b, b.art) else b.art:AddMaskTexture(b.artMask) end
                    b.artMasked = true
                end
                b.art:Show()
            end
            b.focus:SetShown(index == self.selected); b:Show(); y = y + rowHeight + rowSpacing
        else b:Hide() end
    end
    self.empty:SetShown(#self.entries == 0)
    if #self.entries == 0 then y = y + 44 end
    for _, b in ipairs(self.tabs) do
        T.KeyboardButton(b, "controller", b.view == self.view); T.Prompt(b, {}, "inline")
        b:GetFontString():SetWordWrap(true); b:GetFontString():SetHeight(42)
    end
    self.openButton:SetShown(minimap); self.rightButton:SetShown(minimap)
    if minimap then
        self.openButton:ClearAllPoints(); self.openButton:SetPoint("TOPLEFT", 14, -y - 8)
        self.rightButton:ClearAllPoints(); self.rightButton:SetPoint("TOPRIGHT", -14, -y - 8)
        T.ButtonFonts(self.openButton); T.ButtonFonts(self.rightButton)
        T.Prompt(self.openButton, { "primary" }, "inline", { primary })
        T.Prompt(self.rightButton, { "delete" }, "inline", { secondary })
        self.openButton:SetEnabled(#self.entries > 0); self.rightButton:SetEnabled(#self.entries > 0)
        y = y + 54
    end
    self.footer:SetText(L.Format("%s Close   D-pad: navigate", ""))
    self.footer:ClearAllPoints(); self.footer:SetPoint("TOPLEFT", 40, -y - 10)
    local backAtlas = W.Input:TokenIcon(back)
    self.footerGlyph:SetAtlas(backAtlas)
    local info = C_Texture.GetAtlasInfo(backAtlas)
    local padding = info and info.width == 76 and info.height == 75 and 5 or 0
    self.footerGlyph:ClearAllPoints(); self.footerGlyph:SetPoint("TOPLEFT", 16 - padding, -y - 10 + padding)
    self.footerGlyph:SetSize(20 + padding * 2, 20 + padding * 2)
    self.command:SetText((minimap and "/wec minimap" or "/wec menu")
        .. (overflow and "   " .. self.selected .. " / " .. #self.entries or ""))
    local footerHeight = W.db.fontSize * 2 + 8
    self.footer:SetHeight(footerHeight)
    self.command:ClearAllPoints(); self.command:SetPoint("TOPLEFT", 16, -y - footerHeight - 14)
    self.frame:SetHeight(y + footerHeight + 48)
    self.highlight:Hide(); self.highlight:ClearAllPoints()
    local selected = minimap and self.entries[self.selected]
    if selected and W.MinimapTargets:Visible(selected.frame) then
        self.highlight:SetPoint("TOPLEFT", selected.frame, "TOPLEFT", -4, 4)
        self.highlight:SetPoint("BOTTOMRIGHT", selected.frame, "BOTTOMRIGHT", 4, -4); self.highlight:Show()
    end
end
function M:Create()
    local f = CreateFrame("Frame", "WoWEnhancedControllerLauncher", UIParent, "BackdropTemplate")
    self.frame = f; f:Hide(); f:SetSize(360, 640); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
    f:SetPoint("TOPRIGHT", Minimap or UIParent, "BOTTOMLEFT", -12, 20)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(.065, .06, .045, .98); f:SetBackdropBorderColor(.57, .43, .23, 1)
    local logo = f:CreateTexture(nil, "ARTWORK"); logo:SetTexture(iconPath); logo:SetSize(32, 32); logo:SetPoint("TOPLEFT", 14, -14)
    self.logo, self.logoMask = logo, maskIcon(f, logo)
    local title = T.Label(f, "Enhanced Controller"); self.title = title
    title:SetPoint("TOPLEFT", 54, -23); title:SetWidth(260); title:SetWordWrap(false)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButtonNoScripts"); close:SetSize(26, 26); close:SetPoint("TOPRIGHT", -8, -14)
    close:SetScript("OnClick", function() self:Close() end)
    self.focusButton = T.Button(f, "", function() self:RequestFocus() end)
    self.focusButton:SetPoint("CENTER", f, "BOTTOM", 0, 4); self.focusButton:SetSize(32, 32)
    self.focusButton:SetFrameLevel(f:GetFrameLevel() + 2)
    self.focusButton:HookScript("OnEnter", function()
        if GameTooltip then GameTooltip:SetOwner(self.focusButton, "ANCHOR_TOP"); GameTooltip:SetText(L["Focus"]); GameTooltip:Show() end
    end)
    self.focusButton:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f:SetScript("OnMouseDown", function() self:RequestFocus() end)
    self.tabs = {}
    for i, name in ipairs({ "Launcher", "Minimap buttons" }) do
        local view = i == 1 and "launcher" or "minimap"
        local b = T.Button(f, L[name], function() self:SetView(view) end); b.view = view
        b:SetSize(163, 44); b:SetPoint("TOPLEFT", 14 + (i - 1) * 169, -58); self.tabs[i] = b
    end
    local function wheel(surface, delta)
        if self.view == "minimap" and #self.entries > visibleRows then
            self:ScrollTo(self.offset - delta, surface.rowSlot)
        else
            self:Select(self.selected - delta)
        end
    end
    f:EnableMouseWheel(true); f:SetScript("OnMouseWheel", wheel)
    for i = 1, visibleRows do
        local b = T.Button(f, "", function(button)
            local pressedEntry = button.pressedEntry
            button.pressedEntry = nil
            if pressedEntry and pressedEntry ~= self.entries[button.index] then return end
            self.selected = button.index; self:Activate("LeftButton")
        end)
        b.rowSlot = i
        b:EnableMouseWheel(true); b:SetScript("OnMouseWheel", wheel)
        b:SetScript("OnMouseDown", function() b.pressedEntry = self.entries[b.index] end)
        b:SetScript("OnEnter", function()
            self:Select(b.index)
            if GameTooltip and self.entries[b.index] then
                GameTooltip:SetOwner(b, "ANCHOR_LEFT"); GameTooltip:SetText(W.Escape(self.entries[b.index].label)); GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        b.group = T.Label(f, "", "GameFontHighlightSmall")
        b.art = b:CreateTexture(nil, "OVERLAY"); b.art:SetSize(24, 24); b.art:SetPoint("LEFT", 10, 0)
        self.rows[i] = b
    end
    local bar = CreateFrame("EventFrame", nil, f, "MinimalScrollBar")
    self.scrollBar = bar
    bar:SetPoint("TOPRIGHT", -16, -110)
    bar:SetHeight(visibleRows * (rowHeight + rowSpacing) - rowSpacing)
    bar:Init(1, 1)
    bar:RegisterCallback(ScrollBarMixin.Event.OnScroll, function(_, percentage)
        self:ScrollTo(percentage * math.max(0, #self.entries - visibleRows), nil, true)
    end, self)
    bar:HookScript("OnHide", function() bar:UnregisterUpdate() end)
    self.empty = T.Label(f, L["No visible minimap buttons."]); self.empty:SetPoint("TOPLEFT", 16, -108); self.empty:SetWidth(328)
    self.openButton = T.Button(f, L["Open"], function() self:Activate("LeftButton") end)
    self.rightButton = T.Button(f, L["Right-click"], function() self:Activate("RightButton") end)
    for _, b in ipairs({ self.openButton, self.rightButton }) do b:SetSize(162, 38); T.KeyboardButton(b, "controller") end
    self.footer = T.Label(f, ""); self.footer:SetWidth(304); self.footer:SetJustifyH("LEFT")
    self.footerGlyph = f:CreateTexture(nil, "OVERLAY")
    self.command = T.Label(f, "", "GameFontHighlightSmall")
    self.highlight = CreateFrame("Frame", nil, UIParent, "BackdropTemplate"); self.highlight:EnableMouse(false); self.highlight:SetFrameStrata("TOOLTIP")
    self.highlight:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 }); self.highlight:SetBackdropBorderColor(1, .94, .7, 1); self.highlight:Hide()
    f:SetScript("OnShow", function() self:RequestFocus() end)
    f:EnableKeyboard(true); f:SetPropagateKeyboardInput(true)
    f:SetScript("OnKeyDown", function(_, key)
        if W.Combat() then return end
        local consume = self:Eligible() and (key == "ESCAPE" or key == "UP" or key == "DOWN" or key == "ENTER")
        f:SetPropagateKeyboardInput(not consume)
        if not consume then return end
        if key == "ESCAPE" then self:Close() elseif key == "UP" then self:Select(self.selected - 1)
        elseif key == "DOWN" then self:Select(self.selected + 1) elseif key == "ENTER" then self:Activate("LeftButton") end
    end)
    f:SetScript("OnHide", function()
        self:ReleaseControls(); self.highlight:Hide(); self.highlight:ClearAllPoints()
        if GameTooltip then GameTooltip:Hide() end
        W.Radial:SyncOwnership()
    end)
    local elapsed, full = 0, 0
    f:SetScript("OnUpdate", function(_, dt)
        if not self:Eligible() then self:Close(); return end
        for button in pairs(self.waitForUp or {}) do
            if IsKeyDown and IsKeyDown(button) == false then self.waitForUp[button] = nil end
        end
        elapsed, full = elapsed + dt, full + dt
        if elapsed < .5 then return end; elapsed = 0
        self:Refresh(full >= 5); if full >= 5 then full = 0 end
    end)
    for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "GAME_PAD_DISCONNECTED", "UPDATE_BINDINGS", "GAME_PAD_ACTIVE_CHANGED", "INPUT_DEVICE_INTERFACE_TRANSITION" }) do f:RegisterEvent(event) end
    f:SetScript("OnEvent", function(_, event)
        self.held = nil
        if event == "PLAYER_REGEN_DISABLED" or event == "GAME_PAD_DISCONNECTED" then self:Close()
        elseif self:Eligible() then self:RequestFocus() end
    end)
end
function M:PositionIcon()
    if not self.icon then return end
    local angle = math.rad(W.db.minimapAngle)
    local rx, ry = (Minimap:GetWidth() / 2 + 10), (Minimap:GetHeight() / 2 + 10)
    self.icon:ClearAllPoints(); self.icon:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * rx, math.sin(angle) * ry)
    self.icon:SetShown(W.db.minimapVisible)
end
function M:Init()
    if not Minimap or self.icon then return end
    local b = CreateFrame("Button", "WoWEnhancedControllerMinimapButton", Minimap); self.icon = b
    b:SetSize(32, 32); b:SetFrameLevel(Minimap:GetFrameLevel() + 8); b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetTexture(iconPath); b.icon:SetSize(28, 28); b.icon:SetPoint("CENTER")
    -- The logo already includes a gold crest. Mask its opaque square canvas;
    -- a second legacy tracking rim overlapped that crest and was off-center.
    b.iconMask = maskIcon(b, b.icon)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    b:SetScript("OnClick", function(_, button)
        if GetTime() < (self.dragUntil or 0) then return end
        if button == "RightButton" then self:Close(); W.Options.Open() else self:Toggle("launcher") end
    end)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function()
        if W.Combat() then return end
        b:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition(); local cx, cy = Minimap:GetCenter(); local scale = Minimap:GetEffectiveScale()
            if cx and cy then W.db.minimapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx)); self:PositionIcon() end
        end)
    end)
    b:SetScript("OnDragStop", function() b:SetScript("OnUpdate", nil); self.dragUntil = GetTime() + .2 end)
    b:SetScript("OnHide", function() b:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(b, "ANCHOR_LEFT"); GameTooltip:SetText("Enhanced Controller")
        GameTooltip:AddLine(L["Left-click: launcher. Right-click: settings. Drag to move."], 1, .82, 0, true); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self:PositionIcon()
end
