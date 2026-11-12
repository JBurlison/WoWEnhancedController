local _, W = ...
local B = { active = false }
W.KeyboardBindings = B
local prefixes = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
local exact = { "" }

-- Raw gamepad callbacks do not replace gameplay bindings. Route keyboard
-- buttons through our own temporary binding owner, as native function bindings
-- do, without borrowing UIParent's overrides or the native focus manager.
function W.CreateControllerInput(window, onCombat, onClick)
    if W.Combat() or not SetOverrideBindingClick or not ClearOverrideBindings or not RegisterStateDriver then return end
    local prefix = "WoWEnhancedController" .. window
    local owner = CreateFrame("Frame", prefix .. "BindingOwner", UIParent, "SecureHandlerStateTemplate")
    local state = window:lower() .. "-combat"
    owner.CaptureLost = onCombat
    owner:SetAttribute("_onstate-" .. state, [[
        if newstate == "blocked" then
            self:ClearBindings()
            self:CallMethod("CaptureLost")
        end
    ]])
    RegisterStateDriver(owner, state, "[combat] blocked; ready")
    local button = CreateFrame("Button", prefix .. "Input", UIParent)
    button:SetSize(1, 1); button:SetPoint("TOPLEFT"); button:EnableMouse(false)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetScript("OnClick", onClick)
    return owner, button
end

function W.UIFocusBindings()
    local action = "TOGGLEUIFOCUS"
    local context
    if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
        local ok, value = pcall(C_KeyBindings.GetBindingContextForAction, action)
        if ok and not W.Secret(value) then context = value end
    end
    context = context or (Enum and Enum.BindingContext and Enum.BindingContext.GamepadModeInGameCore)
    local ok, first, second = pcall(GetBindingKey, action, nil, context)
    if not ok then
        local known, bound = pcall(GetBindingAction, "PADBACK", false, context)
        if known and bound == action then first = "PADBACK" else first = nil end
    end
    local keys = {}
    for index = 1, 2 do
        local key = select(index, first, second)
        if not W.Secret(key) and type(key) == "string" and key:match("PAD[%w]+$") then
            keys[#keys + 1] = key
        end
    end
    return keys
end

function W.ReleaseMenuControls(self)
    self.held, self.focusRequested, self.boundSignature = nil, nil, nil
    self.menuKeys, self.waitForUp, self.focusKey = nil, nil, nil
    if self.inputOwner and not W.Combat() then ClearOverrideBindings(self.inputOwner) end
end
function W.BindMenuControls(self, window, controls, focus, signature)
    if self.boundSignature == signature then return true end
    if not self.inputOwner then
        self.inputOwner, self.inputButton = W.CreateControllerInput(window, function()
            W.ReleaseMenuControls(self)
        end, function(_, key, down)
            if down then self:Down(key) else self:Up(key) end
        end)
        if not self.inputOwner then return false end
    end
    W.ReleaseMenuControls(self)
    -- A remapped Focus chord takes precedence over a menu shortcut on that key.
    for _, key in ipairs(focus) do controls[key] = "focus" end
    local waitForUp = {}
    for key in pairs(controls) do
        local ok, installed = pcall(SetOverrideBindingClick, self.inputOwner, true, key, self.inputButton:GetName(), key)
        if not ok or installed == false then W.ReleaseMenuControls(self); return false end
        local button = key:match("(PAD[%w]+)$")
        if IsKeyDown and IsKeyDown(button) then waitForUp[button] = true end
    end
    self.focusKey, self.menuKeys, self.waitForUp = focus[1], controls, waitForUp
    self.boundSignature = signature
    return true
end

function B:Create()
    if self.owner then return true end
    self.owner, self.button = W.CreateControllerInput("Keyboard", function()
        self.active, self.draining = false, nil
        W.Input:Release()
    end, function(_, token, down)
        if self.draining then
            if not down then self.draining[token] = nil; self:FinishDrain() end
            return
        end
        if not self.active or not W.Input.active or not W.Input:Eligible() then return end
        if down then W.Input:Down(token) else W.Input:Up(token) end
    end)
    return self.owner ~= nil
end
function B:Tokens()
    local tokens = {}
    local function add(token)
        if not W.Secret(token) and type(token) == "string" and token:match("^PAD[%w]+$") then tokens[token] = true end
    end
    for _, token in pairs(W.Input.defaults) do add(token) end
    for token in pairs(W.Input.reverse or {}) do tokens[token] = true end
    for _, token in ipairs({ "PADBACK", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" }) do add(token) end
    local state = W.Input:Device()
    local count = state and state.buttonCount
    if not W.Secret(count) and type(count) == "number" and count >= 0 and count <= 64
        and C_GamePad and C_GamePad.ButtonIndexToBinding then
        for index = 0, count - 1 do
            local ok, token = pcall(C_GamePad.ButtonIndexToBinding, index)
            if ok then add(token) end
        end
    end
    local sorted = {}; for token in pairs(tokens) do sorted[#sorted + 1] = token end
    table.sort(sorted)
    return sorted
end
function B:FinishDrain()
    if self.draining and not next(self.draining) and not W.Combat() then
        ClearOverrideBindings(self.owner); self.draining = nil
    end
end
function B:Update()
    if not self.draining or W.Combat() or not IsKeyDown then return end
    for token in pairs(self.draining) do if IsKeyDown(token:match("[^-]+$")) == false then self.draining[token] = nil end end
    self:FinishDrain() -- Lost releases cancel; they never invoke an action.
end
function B:Release(drain)
    if drain ~= false and not self.active then return end
    local held = drain ~= false and self.active and W.Input.held or {}
    self.active, self.signature = false, nil
    self.draining = nil
    if self.owner and not W.Combat() then ClearOverrideBindings(self.owner) end
    if self.owner and not W.Combat() and next(held) then
        self.draining = {}
        for token in pairs(held) do
            self.draining[token] = true
            for _, prefix in ipairs(W.ControlBindings.IsPad(token) and prefixes or exact) do
                local ok, result = pcall(SetOverrideBindingClick, self.owner, true, prefix .. token, self.button:GetName(), token)
                if not ok or result == false then self:Release(false); return end
            end
        end
    end
    -- During lockdown the restricted state handler removes these bindings.
    -- Ordinary dispatch rejects input immediately, before that state update.
end
function B:Acquire()
    if W.Combat() or not self:Create() then return false end
    local tokens = self:Tokens()
    local signature = table.concat(tokens, ";")
    if self.active and self.signature == signature then return true end
    self:Release(false)
    for _, token in ipairs(tokens) do
        for _, prefix in ipairs(W.ControlBindings.IsPad(token) and prefixes or exact) do
            local ok, result = pcall(SetOverrideBindingClick, self.owner, true, prefix .. token, self.button:GetName(), token)
            if not ok or result == false then self:Release(false); return false end
        end
    end
    self.active, self.signature = true, signature
    return true
end
