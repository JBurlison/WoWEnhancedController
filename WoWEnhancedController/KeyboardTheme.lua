local _, W = ...
local T = W.Theme
T.buttonSkins = { { "controller", "Controller" }, { "gold", "Gold" }, { "classic", "Classic" }, { "minimal", "Minimal" } }

function T.NormalizeAppearance()
    if type(W.db.keyboardAppearance) ~= "table" then W.db.keyboardAppearance = {} end
    local config = W.db.keyboardAppearance
    -- Replace the old default once. Explicit Gold/Classic choices survive;
    -- Minimal remains selectable after this migration.
    if config.version ~= 2 then
        if config.buttons == "minimal" then config.buttons = "controller" end
        config.version = 2
    end
    local valid = false
    for _, skin in ipairs(T.buttonSkins) do if config.buttons == skin[1] then valid = true end end
    if not valid then config.buttons = "controller" end
    config.background = config.background == true
    config.border = config.border == true
    return config
end

function T.KeyboardShell(frame)
    local config = W.db.keyboardAppearance
    if config.background and not frame.keyboardBackground then
        local fill = frame:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints(frame)
        fill:SetColorTexture(.055, .045, .035, .88)
        frame.keyboardBackground = fill
    end
    if config.border and not frame.keyboardEdge then
        local edge = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        edge:SetAllPoints(frame)
        edge:SetFrameLevel(frame:GetFrameLevel())
        edge:EnableMouse(false)
        edge:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
        edge:SetBackdropBorderColor(.76, .57, .32, 1)
        frame.keyboardEdge = edge
    end
    if frame.keyboardBackground then frame.keyboardBackground:SetShown(config.background) end
    if frame.keyboardEdge then frame.keyboardEdge:SetShown(config.border) end
end

local rimPrefix = "gamepad-actionbar-squareslot-border-"
local function sliceRim(parent, atlas, layer, additive)
    local info = C_Texture.GetAtlasInfo(atlas)
    local textures = {}
    if not info then return textures end
    -- Resolve the client's own atlas UVs. Fixed 8-unit corners surround
    -- stretchable edge strips; no full button/highlight image is stretched.
    local edge, cut = 8, 11 / 64
    local cuts = { 0, cut, 1 - cut, 1 }
    for y = 1, 3 do for x = 1, 3 do
        if x ~= 2 or y ~= 2 then
            local texture = parent:CreateTexture(nil, layer or "ARTWORK")
            texture:SetTexture(info.file or info.filename)
            local function u(t) return info.leftTexCoord + (info.rightTexCoord - info.leftTexCoord) * t end
            local function v(t) return info.topTexCoord + (info.bottomTexCoord - info.topTexCoord) * t end
            texture:SetTexCoord(u(cuts[x]), u(cuts[x + 1]), v(cuts[y]), v(cuts[y + 1]))
            if x == 2 then
                texture:SetPoint(y == 1 and "TOPLEFT" or "BOTTOMLEFT", parent, y == 1 and "TOPLEFT" or "BOTTOMLEFT", edge, 0)
                texture:SetPoint(y == 1 and "TOPRIGHT" or "BOTTOMRIGHT", parent, y == 1 and "TOPRIGHT" or "BOTTOMRIGHT", -edge, 0)
                texture:SetHeight(edge)
            elseif y == 2 then
                texture:SetPoint(x == 1 and "TOPLEFT" or "TOPRIGHT", parent, x == 1 and "TOPLEFT" or "TOPRIGHT", 0, -edge)
                texture:SetPoint(x == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT", parent, x == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, edge)
                texture:SetWidth(edge)
            else
                local point = (y == 1 and "TOP" or "BOTTOM") .. (x == 1 and "LEFT" or "RIGHT")
                texture:SetPoint(point, parent, point); texture:SetSize(edge, edge)
            end
            if additive then texture:SetBlendMode("ADD"); texture:SetAlpha(additive) end
            textures[#textures + 1] = texture
        end
    end end
    return textures
end

function T.KeyboardRim(parent, state, bright)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(); frame:EnableMouse(false)
    frame.parts = sliceRim(frame, rimPrefix .. (state or "hover"))
    if bright then frame.light = sliceRim(frame, rimPrefix .. "hover", "OVERLAY", .65) end
    frame:Hide()
    return frame
end

local faceBottom, faceTop = CreateColor(.07, .065, .05, 1), CreateColor(.18, .16, .125, 1)
local pressedBottom = CreateColor(.07 * .65, .065 * .65, .05 * .65, 1)
local pressedTop = CreateColor(.18 * .65, .16 * .65, .125 * .65, 1)
local function paintFace(art, pressed)
    -- Gradient and flat vertex color share the client's vertex colors.
    -- SetVertexColor after SetGradient erases the gradient, exposing WHITE.
    art.face:SetGradient("VERTICAL", pressed and pressedBottom or faceBottom, pressed and pressedTop or faceTop)
end

local function keyboardArt(button)
    if button.keyboardArt then return button.keyboardArt end
    local art = {}
    button.keyboardArt = art
    art.face = button:CreateTexture(nil, "BACKGROUND")
    art.face:SetPoint("TOPLEFT", 4, -4); art.face:SetPoint("BOTTOMRIGHT", -4, 4)
    art.face:SetColorTexture(1, 1, 1, 1)
    paintFace(art)
    art.normal = T.KeyboardRim(button, "normal")
    art.pressed = T.KeyboardRim(button, "pressed")
    art.hover = T.KeyboardRim(button, "hover")
    art.selected = T.KeyboardRim(button, "hover")
    button.focus:Hide()
    button.focus = T.KeyboardRim(button, "hover", true)
    button:HookScript("OnEnter", function(b) if b.keyboardSkin and b:IsEnabled() then art.hover:Show() end end)
    local function release() art.pressed:Hide(); paintFace(art) end
    button:HookScript("OnLeave", function() art.hover:Hide(); release() end)
    button:HookScript("OnMouseDown", function(b)
        if b.keyboardSkin and b:IsEnabled() then
            art.hover:Hide(); art.pressed:Show(); paintFace(art, true)
        end
    end)
    button:HookScript("OnMouseUp", release)
    button:HookScript("OnHide", function() art.hover:Hide(); release() end)
    return art
end

function T.KeyboardButton(button, skin, selected)
    skin = skin or T.NormalizeAppearance().buttons
    local art = keyboardArt(button)
    button.keyboardSkin, button.tabSelected = skin, nil
    if button.tabArt then for _, texture in ipairs(button.tabArt) do texture:Hide() end end
    button:ClearNormalTexture(); button:ClearPushedTexture(); button:ClearHighlightTexture()
    art.face:SetShown(skin == "controller")
    art.normal:SetShown(skin == "controller")
    art.selected:SetShown(selected == true)
    art.pressed:Hide(); art.hover:Hide(); paintFace(art)
    if skin ~= "controller" then
        local normal = skin == "classic" and "Interface\\Buttons\\UI-Panel-Button-Up"
            or skin == "minimal" and "Interface\\Buttons\\WHITE8X8" or "Interface\\Common\\dark-goldframe-button"
        local pushed = skin == "classic" and "Interface\\Buttons\\UI-Panel-Button-Down"
            or skin == "minimal" and "Interface\\Buttons\\WHITE8X8" or "Interface\\Common\\dark-goldframe-button-pressed"
        button:SetNormalTexture(normal); button:SetPushedTexture(pushed)
        for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture() }) do
            texture:SetTexCoord(0, skin == "classic" and .625 or 1, 0, skin == "classic" and .6875 or 1)
            texture:SetVertexColor(1, 1, 1, 1)
        end
        if skin == "minimal" then
            button:GetNormalTexture():SetVertexColor(.13, .11, .08, 1)
            button:GetPushedTexture():SetVertexColor(.23, .20, .14, 1)
        end
    end
    T.ButtonFonts(button, selected and "GameFontHighlight" or "GameFontNormal")
end

-- Shared ordinary-UI geometry, independent of row construction order. Aligned
-- neighbors win; nearest facing edges win within that band. The remembered
-- horizontal position prevents wide actions from dragging vertical navigation
-- into the center of the keyboard. No edge wraps or disabled destinations.
function T.DirectionalNeighbor(current, controls, dx, dy, column)
    local best, bestAligned, bestScore
    for _, b in ipairs(controls) do
        if b ~= current and b.navX and b:IsShown() and b:IsEnabled() then
            local x, y = b.navX - current.navX, b.navY - current.navY
            local forward, cross = x * dx + y * dy, math.abs(x * dy - y * dx)
            local sameGroup = b.navGroup == current.navGroup
            local allowed = dy ~= 0 and sameGroup or dx ~= 0
            if dx ~= 0 and sameGroup and current.navGroup == "keys" and math.abs(y) > 1 then allowed = false end
            if dy ~= 0 and forward <= math.min(current:GetHeight(), b:GetHeight()) / 2 then allowed = false end
            if allowed and forward > 1 then
                local span = dx ~= 0 and (current:GetHeight() + b:GetHeight()) / 2 or (current:GetWidth() + b:GetWidth()) / 2
                local gap = math.max(0, cross - span)
                local along = dx ~= 0 and (current:GetWidth() + b:GetWidth()) / 2 or (current:GetHeight() + b:GetHeight()) / 2
                local aligned = gap == 0
                local center = dy ~= 0 and math.abs(b.navX - (column or current.navX)) or cross
                local score = math.max(0, forward - along) + gap * 3 + center * .001
                if dy ~= 0 and current.navGroup == "keys" then
                    -- Staggered edge keys still advance exactly one visible
                    -- row, even if the next row begins farther to the right.
                    aligned, score = true, forward + center * .001
                end
                local tied = best and aligned == bestAligned and math.abs(score - bestScore) < .0000001
                if not best or aligned and not bestAligned or aligned == bestAligned and score < bestScore - .0000001
                    or tied and dy ~= 0 and b.navX * dy > best.navX * dy then
                    best, bestAligned, bestScore = b, aligned, score
                end
            end
        end
    end
    return best
end
