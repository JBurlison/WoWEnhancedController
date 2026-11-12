local _, W = ...
local P = { registry = {}, editing = false }
W.Placement = P
function P.LayoutKey()
    local manager = EditModeManagerFrame
    local active = manager and W.Call(manager, "GetActiveLayoutInfo")
    if active and not W.Secret(active) and active.layoutName then
        return tostring(active.layoutType or "") .. ":" .. active.layoutName
    end
    if C_EditMode and C_EditMode.GetLayouts then
        local ok, info = pcall(C_EditMode.GetLayouts)
        if ok and not W.Secret(info) and type(info) == "table" then
            local layout = info.layouts and info.layouts[info.activeLayout]
            if layout and not W.Secret(layout.layoutName) then return tostring(layout.layoutType or "") .. ":" .. (layout.layoutName or tostring(info.activeLayout)) end
        end
    end
    return "default"
end
function P.Register(id, frame, label, defaults)
    P.registry[id] = { frame = frame, label = label or id, defaults = defaults or { anchor = "chat", x = 0, y = 8 } }
    frame:SetMovable(true); frame:SetClampedToScreen(true)
end
function P.Settings(id)
    local layout = W.db.placements[P.LayoutKey()]
    local previous = W.db.placements.default
    return layout and layout[id] or previous and previous[id] or P.registry[id].defaults
end
local function placementFrame(id)
    if id == "radial" and P.editing then return P.wheelPreview end
    return P.registry[id].frame
end
function P.Apply(id)
    local entry = P.registry[id]
    if not entry or W.Combat() then return end
    local f = placementFrame(id)
    if not f then return end
    local s = P.editing and P.draft[id] or P.Settings(id)
    f:ClearAllPoints()
    if s.anchor == "chat" and ChatFrame1 and ChatFrame1:IsShown() then
        -- Convert chat coordinates to this frame's scale, and grow up from chat.
        local ratio = ChatFrame1:GetEffectiveScale() / f:GetEffectiveScale()
        local left = (ChatFrame1:GetLeft() or 24) * ratio
        local top = (ChatFrame1:GetTop() or 180) * ratio
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left + s.x, top + s.y)
    elseif s.anchor == "center" then
        f:SetPoint("CENTER", UIParent, "CENTER", s.x, s.y)
    elseif s.anchor == "screen" then
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", s.x, s.y)
    else
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 24, 200)
    end
end
function P.ApplyAll() for id in pairs(P.registry) do P.Apply(id) end end
function P.Enter(id, explicitFocus)
    if W.Combat() then return end
    if not P.editing then
        if W.Keyboard.session then W.Keyboard:Close(W.L["Edit Mode opened; draft retained."]) end
        P.editing, P.draft, P.layout = true, {}, P.LayoutKey()
        for key in pairs(P.registry) do P.draft[key] = W.Copy(P.Settings(key)) end
        W.Radial:SyncOwnership()
    end
    id = id and P.registry[id] and id or "keyboard"
    W.Keyboard:ShowPosition(id)
    P.Preview(id)
    W.Input:Acquire(explicitFocus)
end
function P.Preview(id)
    if not P.editing or W.Combat() then return end
    if id ~= "radial" or not P.registry.radial then
        if P.wheelPreview then P.wheelPreview:Hide() end
        return
    end
    local wheel = P.registry.radial.frame
    local preview = P.wheelPreview
    if not preview then
        preview = CreateFrame("Frame", "WoWEnhancedControllerWheelPlacement", UIParent)
        P.wheelPreview = preview
        preview:SetFrameStrata("DIALOG")
        preview:SetMovable(true); preview:SetClampedToScreen(true)
        preview:EnableMouse(true); preview:RegisterForDrag("LeftButton")
        preview.ring = preview:CreateTexture(nil, "ARTWORK")
        preview.ring:SetAtlas("gamepad-radial-menu-wheelbg"); preview.ring:SetPoint("CENTER")
        W.Theme.Label(preview, P.registry.radial.label):SetPoint("CENTER", 0, 26)
        W.Theme.Label(preview, W.L["Move with left stick"], "GameFontHighlightSmall"):SetPoint("CENTER", 0, 3)
        preview.save = W.Theme.SettingsButton(preview, W.L["Save position"], P.Save)
        preview.save:SetPoint("CENTER", 0, -30)
        preview:SetScript("OnDragStart", function()
            if P.editing and not W.Combat() then preview:StartMoving() end
        end)
        preview:SetScript("OnDragStop", function() P.DragStop("radial") end)
        preview:SetScript("OnHide", function() preview:StopMovingOrSizing() end)
    end
    preview:SetSize(wheel:GetWidth(), wheel:GetHeight()); preview:SetScale(wheel:GetScale())
    preview.ring:SetSize(wheel:GetWidth(), wheel:GetWidth())
    local hint = W.Input.keys.confirm and W.Input.keys.confirm ~= "" and W.Input:Hint("confirm") .. " " or ""
    preview.save:SetText(hint .. W.L["Save position"])
    preview.save:SetSize(wheel:GetWidth() * .55, 32)
    P.Apply("radial"); preview:Show()
end
function P.Leave()
    if not P.editing then return end
    if P.wheelPreview then P.wheelPreview:Hide() end
    P.editing, P.draft, P.layout, P.dirty = false, nil, nil, nil
    W.Keyboard:Hide(); P.ApplyAll()
    if W.Radial then W.Radial:Close(); W.Radial:SyncOwnership() end
end
function P.Nudge(id, dx, dy)
    if not P.editing or W.Combat() then return end
    local s = P.draft[id]
    s.x, s.y = s.x + dx, s.y + dy
    if id == "radial" and P.wheelPreview and (s.anchor == "center" or s.anchor == "screen") then
        local f = P.wheelPreview
        local scale = UIParent:GetEffectiveScale() / f:GetEffectiveScale()
        local width = math.max(0, UIParent:GetWidth() * scale - f:GetWidth())
        local height = math.max(0, UIParent:GetHeight() * scale - f:GetHeight())
        local left = s.anchor == "center" and -width / 2 or 0
        local bottom = s.anchor == "center" and -height / 2 or 0
        s.x = W.Clamp(s.x, left, left + width)
        s.y = W.Clamp(s.y, bottom, bottom + height)
    end
    P.dirty = true
    P.Apply(id)
    -- Keep the focused button and any in-flight Save/Cancel press while moving.
    local message = W.L.Format("%s: %d, %d · Save or Cancel", P.registry[id].label, math.floor(s.x), math.floor(s.y))
    W.Keyboard.destination:SetText(W.Escape(message))
end
function P.DragStop(id)
    if not P.editing or W.Combat() or W.Keyboard.positionId ~= id then return end
    local frame = placementFrame(id)
    frame:StopMovingOrSizing()
    local x, y = frame:GetLeft(), frame:GetBottom()
    if x and y then P.draft[id] = { anchor = "screen", x = x, y = y }; P.dirty = true; P.Apply(id) end
end
function P.Save()
    if not P.editing or W.Combat() then return end
    W.db.placements[P.layout] = W.Copy(P.draft)
    P.Leave()
end
function P.Reset(id)
    if not P.editing then return end
    P.draft[id] = W.Copy(P.registry[id].defaults); P.dirty = true; P.Apply(id)
end
function P.Init()
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Enter", function() P.Enter("radial") end, P)
        EventRegistry:RegisterCallback("EditMode.Exit", P.Leave, P)
        EventRegistry:RegisterCallback("EditMode.SavedLayouts", function()
            if P.dirty and P.editing and not W.Combat() and P.layout == P.LayoutKey() then
                W.db.placements[P.layout] = W.Copy(P.draft)
                P.dirty = nil
            end
        end, P)
    end
end
