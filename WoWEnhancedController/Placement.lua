local _, W = ...
local P = { registry = {}, editing = false }
W.Placement = P
function P.LayoutKey()
    if C_EditMode and C_EditMode.GetLayouts then
        local ok, info = pcall(C_EditMode.GetLayouts)
        if ok and not W.Secret(info) and type(info) == "table" then
            local layout = info.layouts and info.layouts[info.activeLayout]
            if layout and not W.Secret(layout.layoutName) then return tostring(layout.layoutType or "") .. ":" .. (layout.layoutName or tostring(info.activeLayout)) end
        end
    end
    return "default"
end
function P.Register(id, frame, label)
    P.registry[id] = { frame = frame, label = label or id }
    frame:SetMovable(true); frame:SetClampedToScreen(true)
end
function P.Settings(id)
    local layout = W.db.placements[P.LayoutKey()]
    return layout and layout[id] or { anchor = "chat", x = 0, y = 8 }
end
function P.Apply(id)
    local entry = P.registry[id]
    if not entry or W.Combat() then return end
    local f, s = entry.frame, (P.editing and P.draft and P.draft[id]) or P.Settings(id)
    f:ClearAllPoints()
    if s.anchor == "chat" and ChatFrame1 and ChatFrame1:IsShown() then
        -- Convert chat coordinates to this frame's scale, and grow up from chat.
        local ratio = ChatFrame1:GetEffectiveScale() / f:GetEffectiveScale()
        local left = (ChatFrame1:GetLeft() or 24) * ratio
        local top = (ChatFrame1:GetTop() or 180) * ratio
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left + s.x, top + s.y)
    elseif s.anchor == "screen" then
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", s.x, s.y)
    else
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 24, 200)
    end
end
function P.ApplyAll() for id in pairs(P.registry) do P.Apply(id) end end
function P.Enter()
    if W.Combat() then return end
    if W.Keyboard.session then W.Keyboard:Close("Edit Mode opened; draft retained.") end
    P.editing, P.draft = true, {}
    for id in pairs(P.registry) do P.draft[id] = W.Copy(P.Settings(id)) end
    W.Keyboard:ShowPosition()
end
function P.Leave()
    if not P.editing then return end
    P.editing, P.draft = false, nil
    W.Keyboard:Hide(); P.ApplyAll()
end
function P.Nudge(id, dx, dy)
    if not P.editing or W.Combat() then return end
    local s = P.draft[id]
    s.x, s.y = s.x + dx, s.y + dy
    P.Apply(id)
    W.Keyboard:Status("Position offset: " .. math.floor(s.x) .. ", " .. math.floor(s.y) .. " · Save or Cancel")
end
function P.DragStop(id)
    local frame = P.registry[id].frame
    frame:StopMovingOrSizing()
    if not P.editing then return end
    P.draft[id] = { anchor = "screen", x = frame:GetLeft() or 24, y = frame:GetBottom() or 200 }
end
function P.Save()
    local key = P.LayoutKey()
    W.db.placements[key] = W.Copy(P.draft)
    P.Leave()
end
function P.Reset(id)
    if not P.editing then return end
    P.draft[id] = { anchor = "chat", x = 0, y = 8 }; P.Apply(id)
end
function P.Init()
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Enter", P.Enter, P)
        EventRegistry:RegisterCallback("EditMode.Exit", P.Leave, P)
    end
end
