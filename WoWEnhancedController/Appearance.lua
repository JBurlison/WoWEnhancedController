local _, W = ...
local O, T = W.Options, W.Theme
local function controlTokens()
    local reverse = W.Input:Style() == "Nintendo" and W.db.swapNintendo
    return reverse and "PAD2" or "PAD1", reverse and "PAD1" or "PAD2"
end

function O.OpenAppearance()
    if W.Combat() then W.Print(W.L["Change settings outside combat."]); return end
    if W.Keyboard.session or W.Keyboard.frame:IsShown() then W.Keyboard:Close() end
    if O.appearanceCategory then Settings.OpenToCategory(O.appearanceCategory:GetID()) else O.Open() end
end
function O.SetButtonSkin(skin)
    if W.Combat() then return end
    local valid = false
    for _, choice in ipairs(T.buttonSkins) do if choice[1] == skin then valid = true end end
    if not valid then return end
    T.NormalizeAppearance().buttons = skin
    if W.Keyboard.frame:IsShown() then W.Keyboard:Draw() end
    O.PaintAppearance()
end
function O.PaintAppearance()
    local f = O.appearanceFrame
    if not f then return end
    local config, primary = T.NormalizeAppearance(), controlTokens()
    local cursor = O.NativeNavigation() and SmartNavigation:GetCurrentButton()
    for i, b in ipairs(f.controls) do
        local selected = i == f.selected and (not cursor or cursor == b)
        T.ButtonFonts(b); b.focus:SetShown(selected); b:SetEnabled(not W.Combat())
        T.Prompt(b, selected and { "primary" } or {}, "corner", { primary })
        if b.skin then
            b.chosen:SetShown(config.buttons == b.skin)
            b.chosen:SetFontObject(T.Font("GameFontHighlight"))
            local name = b:GetFontString()
            name:ClearAllPoints(); name:SetPoint("LEFT", 12, 12); name:SetWidth(156); name:SetHeight(28)
            name:SetJustifyH("LEFT")
            for _, sample in ipairs(b.samples) do
                T.KeyboardButton(sample, b.skin)
                T.Prompt(sample, sample.previewAction and { sample.previewAction } or {}, "inline")
            end
            b.samples[1].focus:SetShown(selected)
        end
    end
    for _, label in ipairs(f.labels) do label:SetFontObject(T.Font("GameFontNormal")) end
    f.status:SetText(W.Combat() and W.L["Change settings outside combat."] or W.L["D-pad: select · Confirm: use · Back: close"])
end
function O.MoveAppearance(dx, dy)
    local f, count = O.appearanceFrame, #T.buttonSkins
    local index = f.selected
    if dy ~= 0 then
        if index <= count then f.selected = W.Clamp(index + dy, 1, count + 1)
        elseif dy < 0 then f.selected = count end
    elseif index > count then
        f.selected = W.Clamp(index + dx, count + 1, count + 2)
    end
    O.PaintAppearance()
end
function O.CreateAppearance(canvas)
    local f = CreateFrame("Frame", nil, canvas); f:SetPoint("TOP"); f:SetSize(640, 570)
    f.controls, f.labels, f.selected = {}, {}, 1
    O.appearanceFrame = f
    local function label(text, x, y, width, height)
        local value = T.Label(f, W.L[text]); value:SetPoint("TOPLEFT", x, -y); value:SetSize(width, height)
        value:SetJustifyH("LEFT"); f.labels[#f.labels + 1] = value
        return value
    end
    local function register(b, run)
        b.run = run; f.controls[#f.controls + 1] = b
        local index = #f.controls
        b.OnSmartNavSelect=function() f.selected=index; O.PaintAppearance() end
        b.OnSmartNavDeselect=function()
            b.focus:Hide(); T.Prompt(b, {}, "corner")
            if b.samples then b.samples[1].focus:Hide() end
        end
        b:HookScript("OnEnter", function() f.selected = index; O.PaintAppearance() end)
        return b
    end
    label("Keyboard appearance", 24, 16, 592, 30)
    label("Button skin", 24, 48, 592, 26)
    for i, skin in ipairs(T.buttonSkins) do
        local id = skin[1]
        local run = function() O.SetButtonSkin(id) end
        local row = register(T.Button(f, W.L[skin[2]], run), run)
        row.skin, row.samples = id, {}
        row:SetPoint("TOPLEFT", 24, -(82 + (i - 1) * 88)); row:SetSize(592, 78)
        row:ClearNormalTexture(); row:ClearPushedTexture(); row:ClearHighlightTexture()
        row.focus:Hide(); row.focus = T.KeyboardRim(row, "hover", true)
        row.chosen = T.Label(row, W.L["Selected"], "GameFontHighlight")
        row.chosen:SetPoint("LEFT", 12, -14); row.chosen:SetSize(156, 26); row.chosen:SetJustifyH("LEFT")
        for j, sample in ipairs({ { "q", 188, 48 }, { "Space", 244, 146, "space" }, { "Send", 398, 146, "confirm" } }) do
            local b = T.Button(row, W.L[sample[1]])
            b:SetPoint("LEFT", sample[2], 0); b:SetSize(sample[3], 42); b:EnableMouse(false)
            b.previewAction = sample[4]; row.samples[j] = b
        end
    end
    local function action(text, x, run)
        local b = T.SettingsButton(f, W.L[text], function() if not W.Combat() then run() end end)
        b:SetPoint("TOPLEFT", x, -454); b:SetSize(284, 38); register(b, run)
    end
    action("Reset appearance", 24, function() O.SetButtonSkin("controller") end)
    action("Back", 332, O.Open)
    f.status = label("D-pad: select · Confirm: use · Back: close", 24, 508, 592, 48)
    f:SetScript("OnGamePadButtonDown", function(_, token)
        if not f:IsVisible() or W.Blocker() or W.Combat() or W.Input.active then return true end
        if f.held then return false end
        W.Input.padAt = GetTime(); f.held = { token = token, index = f.selected }
        if token == "PADDUP" then O.MoveAppearance(0, -1)
        elseif token == "PADDDOWN" then O.MoveAppearance(0, 1)
        elseif token == "PADDLEFT" then O.MoveAppearance(-1, 0)
        elseif token == "PADDRIGHT" then O.MoveAppearance(1, 0) end
        return false
    end)
    f:SetScript("OnGamePadButtonUp", function(_, token)
        local held = f.held; f.held = nil
        if not f:IsVisible() or W.Blocker() or W.Combat() or W.Input.active or not held or held.token ~= token then return true end
        W.Input.padAt = GetTime()
        if held.index ~= f.selected then return false end
        local primary, back = controlTokens()
        if token == primary then f.controls[f.selected].run()
        elseif token == back then O.Open() end
        return false
    end)
    W.Input:TrackWindow(f, function() f.held = nil end, false, function() return not O.NativeNavigation() end)
end
function O.RegisterAppearanceCanvas(category)
    local canvas = CreateFrame("Frame", "WoWEnhancedControllerAppearanceSettings", UIParent); canvas:Hide()
    local message = T.Label(canvas, W.L["Change settings outside combat."]); message:SetPoint("TOPLEFT", 24, -24); message:Hide()
    local function refresh()
        if W.Combat() and not O.appearanceFrame then message:Show(); return end
        message:Hide()
        if not O.appearanceFrame then O.CreateAppearance(canvas) end
        O.appearanceFrame.held = nil; O.PaintAppearance()
    end
    canvas:SetScript("OnShow", refresh)
    canvas:RegisterEvent("PLAYER_REGEN_DISABLED"); canvas:RegisterEvent("PLAYER_REGEN_ENABLED")
    canvas:SetScript("OnEvent", function() if canvas:IsShown() then refresh() end end)
    O.appearanceCategory = Settings.RegisterCanvasLayoutSubcategory(category, canvas, W.L["Keyboard appearance"])
end
