local _, W = ...
local D = { ids = setmetatable({}, { __mode = "k" }), serial = 0, cached = {} }
W.MinimapTargets = D

local function safe(frame)
    return frame and not W.Secret(frame) and W.Call(frame, "IsForbidden") == false
end
local function text(value)
    return not W.Secret(value) and type(value) == "string" and value ~= "" and value or nil
end
local function plain(value)
    return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
        :gsub("|H.-|h(.-)|h", "%1"):gsub("^%s+", ""):gsub("%s+$", "")
end
local function root(frame)
    return frame and (frame == Minimap or frame == MinimapCluster or frame == MinimapBackdrop)
end
function D:Related(frame)
    local current = frame
    for _ = 1, 20 do
        if not safe(current) then break end
        if root(current) then return true end
        current = W.Call(current, "GetParent")
    end
    -- LibDBIcon buttons may be reparented by minimap collectors. Their stable
    -- name is retained; ordinary buttons anchored to the minimap also qualify.
    local name = text(W.Call(frame, "GetName"))
    if name and name:match("^LibDBIcon10_") then return true end
    for i = 1, W.Call(frame, "GetNumPoints") or 0 do
        local _, relative = W.Call(frame, "GetPoint", i)
        if root(relative) then return true end
    end
    return false
end
function D:Visible(frame)
    if not safe(frame) or root(frame) or frame.wecLauncherPart then return false end
    if W.Call(frame, "IsVisible") ~= true or W.Call(frame, "IsEnabled") == false then return false end
    if W.Call(frame, "GetEffectiveAlpha") == 0 then return false end
    local button = W.Call(frame, "IsObjectType", "Button") or W.Call(frame, "IsObjectType", "CheckButton")
    local action = W.Call(frame, "GetScript", "OnClick") or W.Call(frame, "GetScript", "OnMouseDown")
        or W.Call(frame, "GetScript", "OnMouseUp")
    return (button or action) and (action or type(frame.OpenMenu) == "function") and self:Related(frame) or false
end
function D:Describe(frame)
    local name = text(W.Call(frame, "GetName"))
    local data = not W.Secret(frame.dataObject) and type(frame.dataObject) == "table" and frame.dataObject
    local label = data and (text(data.label) or text(data.text)) or text(frame.tooltipText) or text(W.Call(frame, "GetText"))
    if frame == (W.Launcher and W.Launcher.icon) then label = "Enhanced Controller"
    elseif frame == AddonCompartmentFrame then label = W.L["Addon menu"]
    elseif frame == GameTimeFrame then label = CALENDAR or W.L["Calendar"]
    elseif frame == TimeManagerClockButton then label = TIMEMANAGER_TITLE or W.L["Clock"]
    elseif MinimapCluster and MinimapCluster.Tracking and frame == MinimapCluster.Tracking.Button then label = MINIMAP_TRACKING or W.L["Tracking"] end
    if not self.ids[frame] then self.serial = self.serial + 1; self.ids[frame] = self.serial end
    label = label or (name and name:gsub("^LibDBIcon10_", ""):gsub("(%l)(%u)", "%1 %2"))
        or W.L.Format("Minimap button %d", self.ids[frame])
    label = plain(label)
    local region = frame.icon or frame.Icon or frame.StateTexture or W.Call(frame, "GetNormalTexture")
    if W.Secret(region) then region = nil end
    local texture = data and not W.Secret(data.icon) and data.icon or nil
    local atlas
    if type(region) == "table" or type(region) == "userdata" then
        texture = texture or W.Call(region, "GetTexture"); atlas = W.Call(region, "GetAtlas")
    end
    if not texture and not atlas and type(frame.GetRegions) == "function" then
        local regions = { pcall(frame.GetRegions, frame) }
        if regions[1] then for i = 2, #regions do
            local r = regions[i]
            if not W.Secret(r) and W.Call(r, "IsObjectType", "Texture") and W.Call(r, "IsShown") then
                atlas, texture = W.Call(r, "GetAtlas"), W.Call(r, "GetTexture")
                if atlas or texture then break end
            end
        end end
    end
    if not texture and not atlas and frame == TimeManagerClockButton then texture = "Interface\\TimeManager\\ClockBackground" end
    if type(texture) ~= "number" and type(texture) ~= "string" then texture = nil end
    return { frame = frame, id = self.ids[frame], label = label, texture = texture, atlas = text(atlas) }
end
function D:Collect(full)
    local seen, frames, result = {}, {}, {}
    local function visit(frame, descend)
        if not safe(frame) or seen[frame] then return end
        seen[frame] = true
        if self:Visible(frame) then frames[#frames + 1] = frame; result[#result + 1] = self:Describe(frame) end
        if descend then
            local values = { pcall(frame.GetChildren, frame) }
            if values[1] then for i = 2, #values do visit(values[i], true) end end
        end
    end
    visit(MinimapCluster, true); visit(MinimapBackdrop, true); visit(Minimap, true)
    for _, frame in ipairs(self.cached) do visit(frame) end
    if full and EnumerateFrames then
        local current
        repeat
            local ok, nextFrame = pcall(EnumerateFrames, current)
            if not ok or W.Secret(nextFrame) then break end
            current = nextFrame
            if current then visit(current) end
        until not current
    end
    self.cached = frames
    table.sort(result, function(a, b)
        if a.frame == W.Launcher.icon then return true elseif b.frame == W.Launcher.icon then return false end
        if a.label == b.label then return a.id < b.id end
        return a.label < b.label
    end)
    return result
end
function D:Activate(entry, mouseButton)
    local frame = entry and entry.frame
    if W.Combat() or not self:Visible(frame) then return false, W.L["This minimap button is no longer available."] end
    if W.Call(frame, "IsProtected") == true then return false, W.L["Use the cursor for this protected minimap button."] end
    local ok
    -- DropdownButton's intrinsic action is OnMouseDown, not OnClick. Use its
    -- public menu entry, retaining its native menu/controller lifecycle.
    if type(frame.OpenMenu) == "function" then ok = pcall(frame.OpenMenu, frame)
    elseif W.Call(frame, "GetScript", "OnClick") and type(frame.Click) == "function" then
        ok = pcall(frame.Click, frame, mouseButton, false)
    else
        local down, up = W.Call(frame, "GetScript", "OnMouseDown"), W.Call(frame, "GetScript", "OnMouseUp")
        ok = true
        if down then ok = pcall(down, frame, mouseButton) end
        if ok and up and safe(frame) then ok = pcall(up, frame, mouseButton) end
    end
    return ok, not ok and W.L["This minimap button could not be opened. Use the cursor."] or nil
end
