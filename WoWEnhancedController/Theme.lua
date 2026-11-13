local _, W = ...
local T = {}
W.Theme = T
function T.Font(role)
    local size = W.db and W.db.fontSize or 14
    local key = role .. size
    T.fonts = T.fonts or {}
    if not T.fonts[key] then
        local source = _G[role]
        local font = CreateFont("WoWEnhancedController" .. key)
        font:CopyFontObject(source)
        local path, _, flags = source:GetFont()
        font:SetFont(path, size, flags)
        T.fonts[key] = font
    end
    return T.fonts[key]
end
function T.ButtonFonts(button, normal)
    button:SetNormalFontObject(T.Font(normal or "GameFontNormal"))
    button:SetHighlightFontObject(T.Font("GameFontHighlight"))
    button:SetDisabledFontObject(T.Font("GameFontDisable"))
end
function T.Label(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(T.Font(font or "GameFontNormal"))
    label:SetText(text or "")
    return label
end
function T.Shell(frame)
    local border = CreateFrame("Frame", nil, frame, "DialogBorderTranslucentTemplate")
    border:SetAllPoints()
    -- Keep the native black region, but prevent controller HUD legends and
    -- action bars from showing through the text-entry surface.
    if border.Bg then border.Bg:SetColorTexture(0, 0, 0, 1) end
    frame.border = border
    return border
end
function T.Button(parent, text, callback, native)
    local button = CreateFrame("Button", nil, parent, native and "UIPanelButtonTemplate" or nil)
    if not native then
        button:SetNormalTexture("Interface\\Common\\dark-goldframe-button")
        button:SetPushedTexture("Interface\\Common\\dark-goldframe-button-pressed")
        button:SetHighlightTexture("Interface\\Buttons\\UI-Silver-Button-Highlight", "ADD")
    end
    if not button:GetFontString() then button:SetFontString(T.Label(button, text)) end
    T.ButtonFonts(button)
    button:SetText(text or "")
    button:SetScript("OnClick", function(self)
        if W.Input and GetTime and GetTime() - (W.Input.padAt or -1) < 0.15 then return end
        if callback then callback(self) end
    end)
    button.action = callback
    button.prompt = CreateFrame("Frame", nil, button)
    button.prompt.icons = {}
    button.prompt.plus = button.prompt:CreateTexture(nil, "OVERLAY")
    button.prompt.plus:SetAtlas("gamepad-symbols-plus")
    button.prompt.plus:SetSize(10, 10)
    button.prompt.plus:Hide()
    button.focus = button:CreateTexture(nil, "OVERLAY")
    button.focus:SetAllPoints()
    button.focus:SetColorTexture(1, 0.75, 0.15, 0.25)
    button.focus:SetBlendMode("ADD")
    button.focus:Hide()
    local addScript = native and button.HookScript or button.SetScript
    addScript(button, "OnEnter", function(self)
        if W.Keyboard and self.row then W.Keyboard:Select(self.row, self.col) end
    end)
    addScript(button, "OnDisable", function(self) self:SetAlpha(0.45) end)
    addScript(button, "OnEnable", function(self) self:SetAlpha(1) end)
    return button
end
function T.SettingsButton(parent, text, callback)
    return T.Button(parent, text, callback, true)
end
function T.Tab(button, selected, keyboard)
    if keyboard then
        T.KeyboardButton(button, nil, selected); button.tabSelected = selected; return
    end
    -- Compose the three native atlases used by PanelTopTabButtonTemplate.
    -- Flip the full art upward; keep its whole center strip for a continuous
    -- gold edge. Fixed dimensions also keep labels and prompts inside each tab.
    -- Own the fixed-width layout here rather than inheriting its parent-driven
    -- auto-resize and disabled-selected-tab behavior (tabs remain navigable).
    if not button.tabArt then
        button.tabArt = {}
        for i = 1, 3 do button.tabArt[i] = button:CreateTexture(nil, "ARTWORK") end
    end
    button:ClearNormalTexture(); button:ClearPushedTexture()
    button:ClearHighlightTexture()
    local prefix = selected and "uiframe-activetab-" or "uiframe-tab-"
    local height = selected and 34 or 28
    for i, part in ipairs({ "left", "center", "right" }) do
        local texture = button.tabArt[i]
        texture:SetAtlas((i == 2 and "_" or "") .. prefix .. part)
        -- Atlas metadata enables tiling again on SetAtlas; this fixed-width
        -- composition stretches the one-pixel center instead, on every redraw.
        if i == 2 then texture:SetHorizTile(false) end
        texture:SetTexCoord(0, 1, 1, 0)
        texture:ClearAllPoints(); texture:SetHeight(height); texture:Show()
        if i == 2 then
            texture:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 16, 0)
            texture:SetWidth(button:GetWidth() - 32)
        else
            texture:SetWidth(16)
            texture:SetPoint(i == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT", button, i == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT")
        end
    end
    button.tabSelected = selected
    T.ButtonFonts(button, selected and "GameFontHighlight" or "GameFontNormal")
end
function T.Regular(button, keyboard)
    if keyboard then T.KeyboardButton(button); return end
    if button.tabArt then for _, texture in ipairs(button.tabArt) do texture:Hide() end end
    button.tabSelected = nil
    local skin = "gold"
    button:SetNormalTexture(skin == "classic" and "Interface\\Buttons\\UI-Panel-Button-Up"
        or skin == "minimal" and "Interface\\Buttons\\WHITE8X8" or "Interface\\Common\\dark-goldframe-button")
    button:SetPushedTexture(skin == "classic" and "Interface\\Buttons\\UI-Panel-Button-Down"
        or skin == "minimal" and "Interface\\Buttons\\WHITE8X8" or "Interface\\Common\\dark-goldframe-button-pressed")
    local normal, pushed = button:GetNormalTexture(), button:GetPushedTexture()
    for _, texture in ipairs({ normal, pushed }) do
        if skin == "classic" then texture:SetTexCoord(0, .625, 0, .6875) else texture:SetTexCoord(0, 1, 0, 1) end
        texture:SetVertexColor(1, 1, 1, 1)
    end
    if skin == "minimal" then normal:SetVertexColor(.13, .11, .08, 1); pushed:SetVertexColor(.3, .24, .12, 1) end
    button:SetHighlightTexture("Interface\\Buttons\\UI-Silver-Button-Highlight", "ADD")
    T.ButtonFonts(button)
end
function T.FocusBadge(button, binding)
    button:ClearNormalTexture(); button:ClearPushedTexture(); button:ClearHighlightTexture()
    button.prompt:Hide()
    if not button.badgeIcon then
        button.badgeIcon = button:CreateTexture(nil, "OVERLAY")
        button:HookScript("OnEnter", function() button.badgeIcon:SetAlpha(0.8) end)
        button:HookScript("OnLeave", function() button.badgeIcon:SetAlpha(1) end)
    end
    local atlas
    if binding == nil then
        atlas = W.Input:Icon("focus")
    elseif binding then
        atlas = W.Input:TokenIcon(binding)
    end
    button.badgeIcon:SetShown(atlas ~= nil and atlas ~= false)
    if not atlas then
        local text = binding and (GetBindingText and GetBindingText(binding, "KEY_") or binding) or W.L["Focus"]
        button:SetText(text)
        button:SetWidth(math.max(32, (W.Call(button:GetFontString(), "GetStringWidth") or #text * 8) + 10))
        return
    end
    if binding ~= nil then button:SetText(""); button:SetWidth(32) end
    button.badgeIcon:SetAtlas(atlas)
    local info = C_Texture and C_Texture.GetAtlasInfo(atlas)
    local padding = info and info.width == 76 and info.height == 75 and 5 or 0
    button.badgeIcon:ClearAllPoints(); button.badgeIcon:SetPoint("CENTER")
    button.badgeIcon:SetSize(32 + padding * 2, 32 + padding * 2)
end
function T.Prompt(button, actions, mode, tokens)
    local prompt = button.prompt
    for _, icon in ipairs(prompt.icons) do icon:Hide() end
    prompt.plus:Hide(); prompt:ClearAllPoints()
    local count, size = 0, (mode == "corner" or mode == "combo") and 18 or mode == "phrase" and 20 or 22
    for i, action in ipairs(actions or {}) do
        local atlas = tokens and W.Input:TokenIcon(tokens[i]) or W.Input:Icon(action)
        if atlas then
            count = count + 1
            local icon = prompt.icons[count]
            if not icon then icon = prompt:CreateTexture(nil, "OVERLAY"); prompt.icons[count] = icon end
            icon:SetAtlas(atlas)
            local info = C_Texture and C_Texture.GetAtlasInfo(atlas)
            -- Match native InputIconTextureMixin's 5-unit compensation for
            -- the new 76x75 canvases' transparent border/shadow padding.
            local padding = info and info.width == 76 and info.height == 75 and 5 or 0
            icon:SetSize(size + padding * 2, size + padding * 2)
            icon:ClearAllPoints(); icon:SetPoint("LEFT", (count - 1) * (size + 12) - padding, 0); icon:Show()
        end
    end
    local width = count * size + math.max(0, count - 1) * 12
    prompt:SetSize(math.max(width, 1), size)
    local label = button:GetFontString()
    -- Empty/icon-only Buttons may not have an engine-created FontString.
    -- Attach one explicitly so later pooled text/layout updates use it too.
    if not label then
        label = T.Label(button, button:GetText())
        button:SetFontString(label)
    end
    label:ClearAllPoints(); label:SetJustifyH("CENTER")
    if button.tabSelected ~= nil and not button.keyboardSkin then
        -- Account for the visible lettering and native strip's padding, not
        -- just their rectangular bounds. Inactive art needs a deeper inset.
        local y = ((button.tabSelected and 34 or 28) - button:GetHeight()) / 2
            - (button.tabSelected and 3 or 6)
        prompt:SetPoint("LEFT", 8, y)
        label:SetPoint("LEFT", count > 0 and width + 16 or 8, y)
        label:SetPoint("RIGHT", -8, y)
    elseif mode == "wedge" then
        label:SetPoint("TOPLEFT", 1, 0); label:SetPoint("BOTTOMRIGHT", -1, 0)
    elseif mode == "bank" then
        prompt:SetPoint("CENTER")
        label:SetPoint("CENTER"); label:SetWidth(button:GetWidth() - 4)
    elseif mode == "combo" then
        prompt:SetPoint("TOP", 0, 0)
        label:SetPoint("LEFT", 5, -4); label:SetPoint("RIGHT", -5, -4)
        label:SetJustifyH("CENTER"); label:SetWordWrap(true); label:SetHeight((W.db.fontSize or 14) * 2 + 2)
    elseif mode == "phrase" then
        prompt:SetPoint("TOPLEFT", 8, -5)
        label:SetPoint("BOTTOMLEFT", 8, 6); label:SetPoint("BOTTOMRIGHT", -8, 6)
        label:SetJustifyH("LEFT"); label:SetHeight((W.db.fontSize or 14) + 2)
    elseif mode == "corner" then
        prompt:SetPoint("BOTTOMRIGHT", -3, 3)
        label:SetPoint("CENTER", count > 0 and -8 or 0, 0)
        label:SetWidth(button:GetWidth() - (count > 0 and 32 or 12))
    else
        prompt:SetPoint("LEFT", 4, 0)
        label:SetPoint("LEFT", count > 0 and width + 8 or 4, 0)
        label:SetPoint("RIGHT", -4, 0)
    end
    if count == 2 then
        prompt.plus:ClearAllPoints(); prompt.plus:SetPoint("LEFT", size + 1, 0); prompt.plus:Show()
    end
end
function T.Input(parent)
    local wrapper = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    wrapper:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    wrapper:SetBackdropBorderColor(0.76, 0.57, 0.24, 1)
    local scroll = CreateFrame("ScrollFrame", nil, wrapper)
    scroll:SetPoint("TOPLEFT", 4, -8); scroll:SetPoint("BOTTOMRIGHT", -4, 8)
    scroll:SetClipsChildren(true)
    local input = CreateFrame("EditBox", nil, scroll)
    input:SetPoint("TOPLEFT"); input:SetWidth(620); input:SetHeight(34)
    -- Insets belong on the EditBox itself: ScrollFrame clipping alone does not
    -- keep the native caret/selection away from the border.
    input:SetTextInsets(12, 12, 5, 5)
    input:SetFontObject(T.Font("GameFontHighlight"))
    input:SetAutoFocus(false); input:SetMultiLine(true)
    input.wecOwned = true
    input.wecScroll = scroll
    scroll:SetScrollChild(input)
    return input, wrapper
end
