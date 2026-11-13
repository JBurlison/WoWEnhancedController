local _, W = ...
local I = { held = {}, active = false, counters = { down = 0, up = 0, stick = 0 } }
W.Input = I
I.defaults = { primary = "PAD1", back = "PAD2", delete = "PAD3", shift = "PAD4", left = "",
    right = "", space = "PADRSTICK", symbols = "PADLSTICK", clear = "",
    confirm = "PADRTRIGGER", library = "PADFORWARD", phrases = "PADLTRIGGER",
    phrasesLeft = "PADLSHOULDER", phrasesRight = "PADRSHOULDER" }
I.actionOrder = { "primary", "back", "delete", "shift", "left", "right", "space", "symbols", "clear", "confirm", "library", "phrases", "phrasesLeft", "phrasesRight" }
local styles = {
    Generic = { PAD1="P1", PAD2="P2", PAD3="P3", PAD4="P4", PADLSHOULDER="L1", PADRSHOULDER="R1", PADLTRIGGER="L2", PADRTRIGGER="R2", PADLSTICK="L3", PADRSTICK="R3", PADFORWARD=W.L["Menu"], PADBACK=W.L["View"] },
    Xbox = { PAD1="A", PAD2="B", PAD3="X", PAD4="Y", PADLSHOULDER="LB", PADRSHOULDER="RB", PADLTRIGGER="LT", PADRTRIGGER="RT", PADLSTICK="L3", PADRSTICK="R3", PADFORWARD=W.L["Menu"], PADBACK=W.L["View"] },
    PlayStation = { PAD1=W.L["Cross"], PAD2=W.L["Circle"], PAD3=W.L["Square"], PAD4=W.L["Triangle"], PADLSHOULDER="L1", PADRSHOULDER="R1", PADLTRIGGER="L2", PADRTRIGGER="R2", PADLSTICK="L3", PADRSTICK="R3", PADFORWARD=W.L["Options"], PADBACK=W.L["Create"] },
    Nintendo = { PAD1="B", PAD2="A", PAD3="Y", PAD4="X", PADLSHOULDER="L", PADRSHOULDER="R", PADLTRIGGER="ZL", PADRTRIGGER="ZR", PADLSTICK="LS", PADRSTICK="RS", PADFORWARD="+", PADBACK="−" },
}
function I:Style()
    if W.db.style ~= "Auto" then return W.db.style end
    local state = self:Device()
    local label = state and state.labelStyle and state.labelStyle:lower() or ""
    if label == "shapes" or label:find("playstation") or label:find("sony") then return "PlayStation" end
    if label == "reverse" or label:find("nintendo") or label:find("switch") then return "Nintendo" end
    if label == "letters" or label:find("xbox") then return "Xbox" end
    return "Generic"
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
    -- The left menu button (Xbox View) is reserved for focus.
    self.keys.focus = "PADBACK"
    self.reverse = { PADBACK = "focus" }
    for _, action in ipairs(self.actionOrder) do
        local token = self.keys[action]
        if token and token ~= "" then
            if self.reverse[token] then self.keys[action] = "" else self.reverse[token] = action end
        end
    end
    for action, key in pairs(W.db.textKeys or {}) do
        if type(key)=="string" and key~="" and not self.reverse[key] then self.reverse[key]=action end
    end
    self:ResetHeld()
    if self.active and W.KeyboardBindings and not W.KeyboardBindings:Acquire() then self:Release() end
end
function I:Hint(action)
    local token = self.keys and self.keys[action]
    if not token or token == "" then return W.L["Unbound"] end
    return "[" .. ((styles[self:Style()] or {})[token] or token) .. "]"
end
local padDirections={PADDUP="Up",PADDDOWN="Down",PADDLEFT="Left",PADDRIGHT="Right"}
function I:TokenLabel(token)
    local dir=padDirections[token]
    if dir then return W.L["D-pad"].." "..W.L[dir] end
    return (styles[self:Style()] or {})[token] or token
end
-- Native Forever atlases from InputIconTexture.lua at the task's source pin.
-- Tokens describe physical positions; Nintendo A-confirm changes the binding,
-- then this lookup draws the artwork for that actual position.
local iconParts = {
    Xbox = { PAD1="buttona", PAD2="buttonb", PAD3="buttonx", PAD4="buttony", PADLSHOULDER="trigger-lb", PADRSHOULDER="trigger-rb", PADLTRIGGER="trigger-lt", PADRTRIGGER="trigger-rt", PADLSTICK="stick-l3", PADRSTICK="stick-r3", PADFORWARD="menu", PADBACK="view" },
    PlayStation = { PAD1="buttoncrox", PAD2="buttoncircle", PAD3="buttonsquare", PAD4="buttontriangle", PADLSHOULDER="triggerl1", PADRSHOULDER="triggerr1", PADLTRIGGER="triggerl2", PADRTRIGGER="triggerr2", PADLSTICK="stickl3", PADRSTICK="stickr3", PADFORWARD="menu", PADBACK="touchpad" },
    Nintendo = { PAD1="face-b", PAD2="face-a", PAD3="face-y", PAD4="face-x", PADLSHOULDER="shoulder-l", PADRSHOULDER="shoulder-r", PADLTRIGGER="zl", PADRTRIGGER="zr", PADLSTICK="stick-l3", PADRSTICK="stick-r3", PADFORWARD="plus", PADBACK="minus" },
}
function I:Icon(action)
    local token = self.keys and self.keys[action]
    return self:TokenIcon(token)
end
function I:TokenIcon(token)
    if not token or token == "" then return end
    local style = self:Style()
    if style == "Generic" then style = "Xbox" end -- Native Generic uses the Xbox set.
    local part = iconParts[style] and iconParts[style][token]
    local direction=token=="PADDUP" and "up" or token=="PADDDOWN" and "down"
        or token=="PADDLEFT" and "left" or token=="PADDRIGHT" and "right"
    if direction then part="dpad"..(style=="Nintendo" and "-" or "")..direction end
    if part then
        local prefix = style == "Nintendo" and "gamepad-switch-128x-" or style == "PlayStation" and "gamepad-ps-" or "gamepad-xbox1-"
        return prefix .. part .. "-normal"
    end
    -- Remaps may use another native key (paddles/d-pad) outside our defaults.
    if W.db.style == "Auto" and InputIconTextureSetUtility then
        local ok, atlas = pcall(InputIconTextureSetUtility.GetNormalActiveInputIconButtonTexture, token)
        if ok and type(atlas) == "string" then return atlas end
    end
end
function I:EndQuickAim()
    self.quickHold = nil
    if self.quickCapture then self.quickCapture:Hide() end
    if W.Keyboard then W.Keyboard.quickAim = nil; W.Keyboard:PaintQuickAim() end
end
function I:ResetHeld()
    self.held, self.stickDirection, self.stickNext = {}, nil, nil
    self.placementAt = nil
    self:EndQuickAim()
    self.waitNeutral = true
end
-- Capture belongs to a visible addon window, not to its close button. Keep
-- deferred combat changes here so a hidden window cannot retain capture after
-- lockdown ends. Never register addon windows with Blizzard's focus manager.
function I:SetCapture(frame, buttons, sticks)
    self.pendingCapture = self.pendingCapture or {}
    if W.Combat() then
        self.pendingCapture[frame] = { buttons = buttons, sticks = sticks }
        return false
    end
    self.pendingCapture[frame] = nil
    local ok = true
    for _, item in ipairs({ { "Button", buttons }, { "Stick", sticks } }) do
        if item[2] ~= nil then
            local enabled = item[2] and frame:IsVisible() or false
            if W.Call(frame, "IsGamePad" .. item[1] .. "Enabled") ~= enabled then
                self.releaseStage = "EnableGamePad" .. item[1] .. "(" .. tostring(enabled) .. ")"
                local success = pcall(frame["EnableGamePad" .. item[1]], frame, enabled)
                self.releaseStage = nil
                if not success then ok = false end
            end
        end
    end
    return ok
end
function I:FlushCapture()
    if W.Combat() then return end
    local pending = self.pendingCapture or {}
    self.pendingCapture = {}
    for frame, state in pairs(pending) do self:SetCapture(frame, state.buttons, state.sticks) end
end
function I:RefreshWindowCapture(frame)
    local state = self.windows and self.windows[frame]
    if not state then return end
    local enabled = frame:IsVisible() and not (W.Blocker and W.Blocker())
    self:SetCapture(frame, enabled and (not state.buttons or state.buttons()), enabled and state.sticks)
end
function I:TrackWindow(frame, reset, sticks, buttons)
    self.windows = self.windows or {}
    self.windows[frame] = { reset = reset, sticks = sticks == true, buttons = buttons }
    local function refresh()
        reset()
        self:RefreshWindowCapture(frame)
    end
    frame:HookScript("OnShow", refresh)
    frame:HookScript("OnHide", refresh)
    refresh() -- Setting gamepad scripts can itself enable capture.
end
function I:RefreshWindows()
    if W.MacroEditor and W.MacroEditor.frame then W.MacroEditor:SyncControls() end
    for frame, state in pairs(self.windows or {}) do
        state.reset()
        self:RefreshWindowCapture(frame)
    end
end
function I:Eligible()
    local k = W.Keyboard
    local owner = k:InputOwner()
    if owner and W.Call(owner, "HasFocus") ~= true then return false end
    if k.assigning and not owner and W.Usable(W.Focus()) then return false end
    return W.db and W.db.enabled and W.Keyboard.frame:IsShown() and not W.Combat() and not W.OtherKeyboard()
        and not (W.Blocker and W.Blocker())
end
function I:Acquire(explicit)
    if not self:Eligible() or (not explicit and not W.ControllerMode()) then return false end
    local f = W.Keyboard.frame
    if W.Radial then W.Radial:SyncOwnership() end
    -- Buttons use the binding dispatcher exclusively. A raw event plus a
    -- gameplay binding must never perform two actions for the same press.
    local captured = self:SetCapture(f, false, true)
    if not captured or W.Call(f, "IsGamePadButtonEnabled") ~= false or not W.KeyboardBindings:Acquire() then
        self:Release(); self.failure = W.L["Controller capture unavailable in this client state."]
        W.Keyboard:Status(self.failure); return false
    end
    self.active = true; self:ResetHeld()
    return true
end
function I:Release()
    self.active = false
    if W.KeyboardBindings then W.KeyboardBindings:Release() end
    self:ResetHeld()
    if W.Keyboard.frame then self:SetCapture(W.Keyboard.frame, false, false) end
end
function I:Remap(token)
    local k = W.Keyboard
    if token:match("^PADD") then k:Status(W.L["D-pad directions are reserved for navigation."]); return end
    if token == self.keys.focus then k.remapping = nil; self:Refresh(); k:Draw(); return end
    if token == "PADLSHOULDER" or token == "PADRSHOULDER" then
        k.remapIndex = ((k.remapIndex - 1 + (token == "PADLSHOULDER" and -1 or 1)) % #self.actionOrder) + 1
        k:Status(W.L.Format("Remap %s: press button; Focus finishes", W.L[self.actionOrder[k.remapIndex]]))
        return
    end
    local action = self.actionOrder[k.remapIndex]
    local chosen = token == "PADLSTICK" and "" or token
    if chosen ~= "" and self.reverse[chosen] and self.reverse[chosen] ~= action then
        k:Status(W.L.Format("Used by %s. Unbind that action first.", W.L[self.reverse[chosen]])); return
    end
    W.db.actionBindings = W.db.actionBindings or {}; W.db.actionBindings[action] = chosen
    self:Refresh(); k:Status(W.L.Format("Assigned %s. Shoulders choose action; Focus finishes.", W.L[action]))
end
function I:Down(token)
    self.counters.down = self.counters.down + 1
    if W.ControlBindings.IsPad(token) then W.lastPad = true end
    if not self.active or not self:Eligible() or self.waitNeutral or self.held[token] then return false end
    self.padAt = GetTime()
    local k = W.Keyboard
    if k.remapping then self:Remap(token); return false end
    local action = self.reverse[token]
    local record = { action = action, session = k.session, generation = k.generation, at = GetTime() + 0.4 }
    self.held[token] = record
    if (k.linking or k.channels) and action ~= "primary" and action ~= "back" and action ~= "focus" and not token:match("^PADD") then
        record.layer = true; return false
    end
    if action == "phrasesLeft" or action == "phrasesRight" then
        if self.quickHold then self.quickHold.cancelled = true; k.quickAim = nil; k:PaintQuickAim() end
        record.page = action == "phrasesLeft" and -1 or 1
        return false
    end
    if action == "phrases" then
        if k.quickButtons and not k.composing and not self.quickHold then
            for _, pending in pairs(self.held) do
                if pending.page then record.cancelled = true end
                pending.layer = true
                pending.direction = nil
            end
            self.stickDirection = nil
            self.quickHold = record
            self.quickCapture:Show()
            if not self:SetCapture(self.quickCapture, nil, true) then
                self:EndQuickAim(); k:Status(W.L["Controller capture unavailable in this client state."]); return false
            end
            record.bank = k.quickBank
            k.quickAim = nil
            self:SampleQuickAim()
            k:PaintQuickAim()
        end
        return false
    end
    if self.quickHold and action ~= "focus" then
        record.layer = true
        if action == "back" then self.quickHold.cancelled = true; k.quickAim = nil; k:PaintQuickAim() end
        return false
    end
    local directions = { PADDUP={0,-1}, PADDDOWN={0,1}, PADDLEFT={-1,0}, PADDRIGHT={1,0} }
    if directions[token] then record.direction = directions[token]; k:Move(unpack(record.direction)) end
    return false
end
function I:Up(token)
    self.counters.up = self.counters.up + 1
    local record = self.held[token]; self.held[token] = nil
    if not record then return false end
    local k = W.Keyboard
    local valid = self.active and self:Eligible() and not self.waitNeutral and record.session == k.session and record.generation == k.generation
    if record == self.quickHold then
        if valid then self:SampleQuickAim() end
        local slot = k.quickAim
        self:EndQuickAim()
        if valid and not record.cancelled and slot and k.quickButtons and k.quickBank == record.bank
            and (not k.session or W.Contexts.Valid(k.session)) then
            k:UsePhrase(slot, record.bank)
        end
        return false
    end
    if not valid then return false end
    if record.page then
        if self.quickHold then self.quickHold.cancelled = true end
        k:ChangeQuickPage(record.page)
    elseif record.action == "focus" then W.FocusBinding()
    elseif not record.layer and not self.quickHold and not record.direction and record.action then
        local action = record.action
        if k:Numeric() and k.view == "keys" then
            if action == "delete" then action = "digits" elseif action == "shift" then action = "delete" end
        end
        k:Action(action)
    end
    return false
end
function I:SampleQuickAim()
    if not self.quickHold or self.quickHold.cancelled then return end
    local index = W.Radial.frame and W.Radial.frame:GetAttribute("camera-index") or 2
    local state = self:Device()
    local stick = state and state.sticks and state.sticks[index]
    if stick and not W.Secret(stick) then W.Keyboard:AimQuickWheel(stick.x, stick.y) end
end
function I:Stick(stick, x, y)
    self.counters.stick = self.counters.stick + 1
    if not self.active or not self:Eligible() then return true end
    if self.quickHold then
        if stick == "Camera" and not self.quickHold.cancelled then W.Keyboard:AimQuickWheel(x, y) end
        return false
    end
    if stick ~= "Movement" then return true end
    if self.waitNeutral then return false end
    if W.Placement.editing and W.Keyboard.positionId == "radial" then
        self.stickDirection = nil
        if x*x + y*y < .04 then self.placementAt = nil; return false end
        self.placementX, self.placementY = x, y
        self.placementAt = self.placementAt or GetTime()
        return false
    end
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
    if W.KeyboardBindings then W.KeyboardBindings:Update() end
    if not self.active then return end
    if not self:Eligible() then self:Release(); return end
    if self.waitNeutral then if self:Neutral() then self.waitNeutral = false end; return end
    local now = GetTime()
    if self.quickHold then self:SampleQuickAim() end
    if self.placementAt then
        if W.Placement.editing and W.Keyboard.positionId == "radial" then
            local distance = math.min(now - self.placementAt, .1) * 360
            self.placementAt = now
            if distance > 0 then W.Placement.Nudge("radial", self.placementX * distance, self.placementY * distance) end
        else self.placementAt = nil end
    end
    for token, record in pairs(self.held) do
        if IsKeyDown and not IsKeyDown(token:match("[^-]+$")) then
            -- Lost release can cancel a latch, never execute it.
            self.held[token] = nil
            if record == self.quickHold then
                self:EndQuickAim()
            end
        elseif record.direction and now >= record.at then
            W.Keyboard:Move(unpack(record.direction)); record.at = now + 0.09
        end
    end
    if self.stickDirection and now >= self.stickNext then self:MoveStick(self.stickDirection); self.stickNext = now + 0.10 end
end
function I:Init()
    self:Refresh()
    local frame = W.Keyboard.frame
    -- The native stick receiver's propagation flag controls camera movement.
    -- Capture axes only during aim, leaving physical typing on the native field.
    self.quickCapture = CreateFrame("Frame", nil, frame)
    self.quickCapture:Hide()
    self.quickCapture:SetFrameStrata("TOOLTIP")
    self.quickCapture:SetPropagateKeyboardInput(false)
    self.quickCapture:SetScript("OnGamepadStick", function(_, stick, x, y) return self:Stick(stick, x, y) end)
    frame:SetScript("OnGamePadButtonDown", function(_, token) return self:Down(token) end)
    frame:SetScript("OnGamePadButtonUp", function(_, token) return self:Up(token) end)
    frame:SetScript("OnGamepadStick", function(_, stick, x, y) return self:Stick(stick, x, y) end)
    self:Release()
end
