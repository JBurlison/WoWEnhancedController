local _, W = ...
local T = {}
W.Theme = T
function T.Label(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetText(text or "")
    return label
end
function T.Shell(frame)
    local border = CreateFrame("Frame", nil, frame, "DialogBorderTranslucentTemplate")
    border:SetAllPoints()
    frame.border = border
    return border
end
function T.Button(parent, text, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetNormalTexture("Interface\\Common\\dark-goldframe-button")
    button:SetPushedTexture("Interface\\Common\\dark-goldframe-button-pressed")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Silver-Button-Highlight", "ADD")
    button:SetNormalFontObject(GameFontNormal)
    button:SetHighlightFontObject(GameFontHighlight)
    button:SetDisabledFontObject(GameFontDisable)
    button:SetText(text or "")
    button:SetScript("OnClick", function(self)
        if W.Input and GetTime and GetTime() - (W.Input.padAt or -1) < 0.15 then return end
        if callback then callback(self) end
    end)
    button.action = callback
    button.hint = T.Label(button, "", "GameFontNormalSmall")
    button.hint:SetPoint("BOTTOMRIGHT", -3, 2)
    button.focus = button:CreateTexture(nil, "OVERLAY")
    button.focus:SetAllPoints()
    button.focus:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    button.focus:SetBlendMode("ADD")
    button.focus:Hide()
    button:SetScript("OnEnter", function(self)
        if W.Keyboard and self.row then W.Keyboard:Select(self.row, self.col) end
    end)
    button:SetScript("OnDisable", function(self) self:SetAlpha(0.45) end)
    button:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    return button
end
function T.Input(parent)
    local wrapper = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    wrapper:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    local input = CreateFrame("EditBox", nil, wrapper)
    input:SetPoint("TOPLEFT", 10, -7); input:SetPoint("BOTTOMRIGHT", -10, 7)
    input:SetFontObject(GameFontHighlight)
    input:SetAutoFocus(false); input:SetMultiLine(true)
    input.wecOwned = true
    return input, wrapper
end
