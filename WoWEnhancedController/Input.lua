local _, W = ...
local I = { held = {}, active = false, counters = { down = 0, up = 0, stick = 0 } }
W.Input = I
I.defaults = { primary = "PAD1", back = "PAD2", delete = "PAD3", shift = "PAD4", left = "PADLSHOULDER",
    right = "PADRSHOULDER", space = "PADRTRIGGER", symbols = "PADRSTICK", clear = "PADLSTICK",
    confirm = "PADFORWARD", library = "PADBACK", phrases = "PADLTRIGGER" }
I.actionOrder = { "primary", "back", "delete", "shift", "left", "right", "space", "symbols", "clear", "confirm", "library", "phrases" }
local styles = {
    Xbox = { PAD1="A", PAD2="B", PAD3="X", PAD4="Y", PADLSHOULDER="LB", PADRSHOULDER="RB", PADLTRIGGER="LT", PADRTRIGGER="RT", PADLSTICK="L3", PADRSTICK="R3", PADFORWARD="Menu", PADBACK="View" },
    PlayStation = { PAD1="Cross", PAD2="Circle", PAD3="Square", PAD4="Triangle", PADLSHOULDER="L1", PADRSHOULDER="R1", PADLTRIGGER="L2", PADRTRIGGER="R2", PADLSTICK="L3", PADRSTICK="R3", PADFORWARD="Options", PADBACK="Create" },
    Nintendo = { PAD1="B", PAD2="A", PAD3="Y", PAD4="X", PADLSHOULDER="L", PADRSHOULDER="R", PADLTRIGGER="ZL", PADRTRIGGER="ZR", PADLSTICK="LS", PADRSTICK="RS", PADFORWARD="+", PADBACK="−" },
}
function I:Style()
    if W.db.style ~= "Auto" then return W.db.style end
    local state = self:Device()
    local label = state and state.labelStyle and state.labelStyle:lower() or ""
    if label:find("playstation") or label:find("sony") then return "PlayStation" end
    if label:find("nintendo") or label:find("switch") then return "Nintendo" end
    return "Xbox"
end
function I:Device()
    if not C_GamePad or not C_GamePad.GetDeviceMappedState then return end
    local ok, state = pcall(C_GamePad.GetDeviceMappedState)
    if ok and not W.Secret(state) then return state end
end
function I:Neutral()
    local state = self:Device()
    if not state then return false end
    for _, down in ipairs(state.buttons or {}) do if W.Secret(down) or down then return false end end
    for _, stick in ipairs(state.sticks or {}) do
        if W.Secret(stick.len) or (stick.len or 0) > 0.25 then return false end
    end
    return true
end
function I:Refresh()
    self.keys = W.Copy(self.defaults)
    if self:Style() == "Nintendo" and W.db.swapNintendo then self.keys.primary, self.keys.back = "PAD2", "PAD1" end
    for action, token in pairs(W.db.actionBindings or {}) do self.keys[action] = token end
    self.reverse = {}
    for _, action in ipairs(self.actionOrder) do
        local token = self.keys[action]
        if token and token ~= "" then
            if self.reverse[token] then self.keys[action] = "" else self.reverse[token] = action end
        end
    end
    self:ResetHeld()
end
function I:Hint(action)
    local token = self.keys and self.keys[action]
    if not token or token == "" then return "Unbound" end
    return "[" .. ((styles[self:Style()] or styles.Xbox)[token] or token) .. "]"
end
function I:PhraseHint(action)
    if not action or action == "unbound" then return "" end
    if not self.keys[action] or self.keys[action] == "" or self.keys.phrases == "" then return "" end
    return self:Hint("phrases") .. "+" .. self:Hint(action)
end
function I:ResetHeld()
    self.held, self.layer, self.stickDirection, self.stickNext = {}, false, nil, nil
    self.waitNeutral = true
end
function I:Eligible()
    return W.db and W.db.enabled and W.Keyboard.frame:IsShown() and not W.Combat() and not W.OtherKeyboard()
        and not (W.Blocker and W.Blocker())
end
function I:Acquire(explicit)
    if not self:Eligible() or (not explicit and not W.ControllerMode()) then return false end
    local f = W.Keyboard.frame
    local buttons = pcall(f.EnableGamePadButton, f, true)
    local sticks = pcall(f.EnableGamePadStick, f, true)
    if not buttons or not sticks or W.Call(f, "IsGamePadButtonEnabled") == false then
        self.active = false; self.failure = "Controller capture unavailable in this client state."
        W.Keyboard:Status(self.failure); return false
    end
    self.active = true; self:ResetHeld()
    return true
end
function I:Release()
    self.active = false; self:ResetHeld()
    if W.Keyboard.frame and not W.Combat() then
        pcall(W.Keyboard.frame.EnableGamePadButton, W.Keyboard.frame, false)
        pcall(W.Keyboard.frame.EnableGamePadStick, W.Keyboard.frame, false)
    end
end
function I:Remap(token)
    local k = W.Keyboard
    if token == "PADFORWARD" then k.remapping = nil; self:Refresh(); k:Draw(); return end
    if token == "PADLSHOULDER" or token == "PADRSHOULDER" then
        k.remapIndex = ((k.remapIndex - 1 + (token == "PADLSHOULDER" and -1 or 1)) % #self.actionOrder) + 1
        k:Status("Remap " .. self.actionOrder[k.remapIndex] .. ": press a button · stick click unbinds · Menu finishes")
        return
    end
    local action = self.actionOrder[k.remapIndex]
    local chosen = token == "PADLSTICK" and "" or token
    if chosen ~= "" and self.reverse[chosen] and self.reverse[chosen] ~= action then
        k:Status("Used by " .. self.reverse[chosen] .. ". Unbind that action first."); return
    end
    W.db.actionBindings = W.db.actionBindings or {}; W.db.actionBindings[action] = chosen
    self:Refresh(); k:Status("Assigned " .. action .. ". Shoulders choose action; Menu finishes.")
end
function I:Down(token)
    self.counters.down = self.counters.down + 1
    W.lastPad = true
    if not self.active or not self:Eligible() or self.waitNeutral or self.held[token] then return false end
    self.padAt = GetTime()
    local k = W.Keyboard
    if k.remapping then self:Remap(token); return false end
    local action = self.reverse[token]
    local record = { action = action, session = k.session, generation = k.generation, at = GetTime() + 0.4 }
    self.held[token] = record
    if token == self.keys.phrases then self.layer = true; return false end
    if self.layer then
        local bindings = W.Phrases.Bindings(k:Context())
        for slot, assigned in ipairs(bindings) do if assigned == action then record.phrase = slot; break end end
        return false
    end
    local directions = { PADDUP={0,-1}, PADDDOWN={0,1}, PADDLEFT={-1,0}, PADDRIGHT={1,0} }
    if directions[token] then record.direction = directions[token]; k:Move(unpack(record.direction)) end
    return false
end
function I:Up(token)
    self.counters.up = self.counters.up + 1
    local record = self.held[token]; self.held[token] = nil
    if token == (self.keys and self.keys.phrases) then self.layer = false end
    if not record or not self.active or not self:Eligible() or self.waitNeutral then return false end
    local k = W.Keyboard
    if record.session ~= k.session or record.generation ~= k.generation then return false end
    if record.phrase then k:InsertPhrase(record.phrase)
    elseif not record.direction and record.action then
        local action = record.action
        if k:Numeric() and k.view == "keys" then
            if action == "delete" then action = "digits" elseif action == "shift" then action = "delete" end
        end
        k:Action(action)
    end
    return false
end
function I:Stick(stick, x, y)
    self.counters.stick = self.counters.stick + 1
    if not self.active or not self:Eligible() then return true end
    if stick ~= "Movement" then return true end
    if self.waitNeutral then return false end
    local direction
    if math.max(math.abs(x), math.abs(y)) > 0.45 then
        direction = math.abs(x) > math.abs(y) and (x > 0 and "right" or "left") or (y > 0 and "up" or "down")
    end
    if direction ~= self.stickDirection then
        self.stickDirection = direction; self.stickNext = GetTime() + 0.4
        if direction then self:MoveStick(direction) end
    end
    return false
end
function I:MoveStick(direction)
    local d = { up={0,-1}, down={0,1}, left={-1,0}, right={1,0} }
    W.Keyboard:Move(unpack(d[direction]))
end
function I:Update()
    if not self.active then return end
    if not self:Eligible() then self:Release(); return end
    if self.waitNeutral then if self:Neutral() then self.waitNeutral = false end; return end
    local now = GetTime()
    for token, record in pairs(self.held) do
        if IsKeyDown and not IsKeyDown(token) then
            -- Lost release can cancel a latch, never execute it.
            self.held[token] = nil; if token == self.keys.phrases then self.layer = false end
        elseif record.direction and now >= record.at then
            W.Keyboard:Move(unpack(record.direction)); record.at = now + 0.09
        end
    end
    if self.stickDirection and now >= self.stickNext then self:MoveStick(self.stickDirection); self.stickNext = now + 0.10 end
end
function I:Init()
    self:Refresh()
    local frame = W.Keyboard.frame
    frame:SetScript("OnGamePadButtonDown", function(_, token) return self:Down(token) end)
    frame:SetScript("OnGamePadButtonUp", function(_, token) return self:Up(token) end)
    frame:SetScript("OnGamepadStick", function(_, stick, x, y) return self:Stick(stick, x, y) end)
    self:Release()
end
