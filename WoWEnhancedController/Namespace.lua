local addonName, W = ...
_G.WoWEnhancedController = W
W.name, W.version = addonName, "0.19.0"
W.frames, W.adapters, W.drafts = {}, {}, {}

function W.Secret(value)
    return issecretvalue and issecretvalue(value) or false
end

-- Return ordinary values only. Never stringify/compare secret values.
function W.Call(object, method, ...)
    if not object or type(object[method]) ~= "function" then return nil end
    local ok, a, b, c = pcall(object[method], object, ...)
    if not ok or W.Secret(a) or W.Secret(b) or W.Secret(c) then return nil end
    return a, b, c
end

function W.Combat() return InCombatLockdown and InCombatLockdown() or false end
function W.Print(message) print("|cffffcf61Enhanced Controller:|r " .. message) end
function W.Escape(text) return (tostring(text or ""):gsub("|", "||")) end
function W.Clamp(n, low, high) return math.max(low or -math.huge, math.min(high or math.huge, n)) end
function W.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = W.Copy(v) end
    return result
end
function W.InitDB()
    if type(WoWEnhancedControllerDB) ~= "table" then WoWEnhancedControllerDB = {} end
    W.db = WoWEnhancedControllerDB
    local defaults = { enabled = true, activation = "controller", style = "Xbox", swapNintendo = true,
        scale = 1, fontSize = 14, largeKeys = false, quickMove = true, phrases = {}, bindings = {}, phraseBanks = {}, placements = {}, schema = 1 }
    for key, value in pairs(defaults) do if W.db[key] == nil then W.db[key] = W.Copy(value) end end
    if type(W.db.quickMove) ~= "boolean" then W.db.quickMove = true end
    if type(W.db.textKeys)~="table" then W.db.textKeys=nil end
    if type(W.db.minimapVisible) ~= "boolean" then W.db.minimapVisible = true end
    W.db.minimapAngle = tonumber(W.db.minimapAngle) or 225
    W.db.fontSize = math.floor(W.Clamp(tonumber(W.db.fontSize) or 14, 12, 20))
    if (W.db.schema or 1) < 2 then
        local bindings = W.db.actionBindings
        if bindings then
            if bindings.confirm == "PADFORWARD" then bindings.confirm = nil end
            if bindings.space == "PADRTRIGGER" then bindings.space = nil end
        end
        W.db.schema = 2
    end
    if W.db.schema < 3 then
        if W.db.style == "Auto" then W.db.style = "Xbox" end
        W.db.schema = 3
    end
    if W.db.schema < 4 then
        local bindings = W.db.actionBindings
        if bindings and bindings.library == "PADBACK" then bindings.library = nil end
        W.db.schema = 4
    end
    if W.db.schema < 5 then
        local bindings = W.db.actionBindings
        if bindings and bindings.symbols == "PADRSTICK" then bindings.symbols = nil end
        W.db.schema = 5
    end
    if W.db.schema < 6 then
        local bindings = W.db.actionBindings
        if bindings then
            if bindings.left == "PADLSHOULDER" then bindings.left = nil end
            if bindings.right == "PADRSHOULDER" then bindings.right = nil end
            if bindings.clear == "PADLSTICK" then bindings.clear = nil end
            if bindings.symbols == "" then bindings.symbols = nil end
        end
        W.db.schema = 6
    end
    W.Theme.NormalizeAppearance()
end

function W.ControllerMode()
    if InputUtil and type(InputUtil.GetCurrentInterfaceStyle) == "function" and Enum and Enum.InputDeviceInterfaceType then
        local ok, mode = pcall(InputUtil.GetCurrentInterfaceStyle)
        if ok and not W.Secret(mode) then return mode == Enum.InputDeviceInterfaceType.Gamepad end
    end
    -- Last-device state, not merely whether the subsystem is enabled.
    return W.lastPad == true
end

function W.OtherKeyboard()
    -- Do not disable or manipulate another addon. Avoid two simultaneous keyboards.
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("CompactKeyboard") then
        return W.L["CompactKeyboard is loaded. Disable one keyboard in the AddOns list, then reload."]
    end
end

function W.RegisterField(predicate, describe)
    assert(type(predicate) == "function" and type(describe) == "function")
    W.adapters[#W.adapters + 1] = { predicate = predicate, describe = describe }
end
