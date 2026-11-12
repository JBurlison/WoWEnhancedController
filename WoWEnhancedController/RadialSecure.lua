local _, W = ...
local S = {}
W.RadialSecure = S

-- These strings execute only in Blizzard's restricted environment, from real
-- clicks/state drivers. Ordinary gamepad callbacks paint UI; they never cast.
S.close = [[
    self:ClearBindings()
    self:RunAttribute("op-clearAim")
    self:SetAttribute("open", false)
    self:SetAttribute("stage", "root")
    self:SetAttribute("selected", 0)
    self:SetAttribute("pressed", nil)
    self:SetAttribute("finish-member", nil)
    self:SetAttribute("sweep-button", nil)
    self:Hide()
]]
S.invalidate = [[
    self:SetAttribute("roster-valid", false)
    self:RunAttribute("op-close")
]]
S.stage = [[
    local stage, group, member, page = ...
    self:RunAttribute("op-clearAim", true)
    self:SetAttribute("stage", stage)
    self:SetAttribute("group", group or 1)
    self:SetAttribute("member", member)
    self:SetAttribute("page", page or 0)
    self:SetAttribute("selected", 0)
    self:SetAttribute("pressed", nil)
    self:SetAttribute("sweep-button", nil)
    local dual = self:GetAttribute("mode") == "sweep" and (stage ~= "root" or not self:GetAttribute("raid"))
    self:SetAttribute("dual", dual)
    local surface = self:GetFrameRef("surface")
    if dual then surface:Show() else surface:Hide() end
    local count = 0
    if stage == "root" then count = self:GetAttribute("raid") and 8 or self:GetAttribute("member-count")
    elseif stage == "members" then count = self:GetAttribute("group-count-" .. group) or 0
    else count = 8 end
    self:SetAttribute("count", count)
    for i = 1, 9 do
        local cell = self:GetFrameRef("cell" .. i)
        cell:ClearAllPoints()
        if i <= count and not dual then
            local angle = (i - 1) * 45
            local radius = self:GetAttribute("radius")
            cell:SetPoint("CENTER", self, "CENTER", sin(angle) * radius, cos(angle) * radius)
            cell:Show()
        else cell:Hide() end
    end
    for i=1,2 do
        local paging=self:GetFrameRef("page-button-"..i)
        if stage=="spells" and (self:GetAttribute("page-count") or 1)>1 then paging:Show() else paging:Hide() end
    end
    self:CallMethod("StageChanged")
]]
-- A genuine action click has already run. Only change the visible tier here;
-- never retry a spell or infer cast success from cooldowns/events.
S.finish = [[
    local member = self:GetAttribute("finish-member")
    local group = self:GetAttribute("finish-group") or 1
    local page = self:GetAttribute("finish-page") or 0
    self:SetAttribute("finish-member", nil)
    if not self:GetAttribute("open") then return end
    if not self:GetAttribute("enabled") or not self:GetAttribute("roster-valid")
        or self:GetAttribute("state-availability") == "blocked" or self:GetAttribute("after-action") == "close" then
        self:RunAttribute("op-close"); return
    end
    local unit = member and self:GetAttribute("unit-" .. member)
    if not unit or not UnitExists(unit) or not PlayerCanAssist(unit) then self:RunAttribute("op-stage", "root"); return end
    if self:GetAttribute("after-action") == "target" then
        self:RunAttribute("op-stage", "spells", group, member, page)
    elseif self:GetAttribute("raid") and (self:GetAttribute("group-count-" .. group) or 0) > 0 then
        self:RunAttribute("op-stage", "members", group)
    else self:RunAttribute("op-stage", "root") end
]]
S.bind = [[
    local key, command = ...
    local name = self:GetFrameRef("dispatch"):GetName()
    self:SetBindingClick(true, key, name, command)
    if not self:GetAttribute("expand-" .. key) then return end
    -- Native trigger-to-modifier mappings must not leak face-button actions
    -- to the underlying action bar while the wheel owns input.
    for prefix in gmatch("SHIFT- CTRL- ALT- CTRL-SHIFT- ALT-SHIFT- ALT-CTRL- ALT-CTRL-SHIFT-", "%S+") do
        self:SetBindingClick(true, prefix .. key, name, command)
    end
]]
S.open = [[
    local request = ...
    local mode = request or self:GetAttribute("default-mode")
    if not self:GetAttribute("enabled") or not self:GetAttribute("roster-valid") then return end
    if self:GetAttribute("state-availability") == "blocked" then return end
    if self:GetAttribute("open") then
        local toggle = not request or self:GetAttribute("mode") == mode
        self:RunAttribute("op-close")
        if toggle then return end
    end
    self:SetAttribute("mode", mode)
    self:SetAttribute("open", true)
    self:Show()
    self:RunAttribute("op-stage", "root")
    for i=1,self:GetAttribute("control-count") do
        local id = self:GetAttribute("control-id-"..i)
        local pad,key = self:GetAttribute("control-pad-"..i),self:GetAttribute("control-key-"..i)
        if pad then self:RunAttribute("op-bind",pad,id) end
        if key then self:RunAttribute("op-bind",key,"Key"..id) end
    end
    if self:GetAttribute("default-r3") then self:RunAttribute("op-bind", "PADRSTICK", "Toggle") end
    for key in gmatch("PADRSTICKUP PADRSTICKRIGHT PADRSTICKDOWN PADRSTICKLEFT", "%S+") do
        self:RunAttribute("op-bind", key, key)
    end
]]
S.point = [[
    local state = GetGamePadState()
    local stick = state and state.sticks and state.sticks[self:GetAttribute("camera-index") or 2]
    if not stick or (stick.len or 0) < 0.45 then return 0 end
    local count = self:GetAttribute("count") or 0
    if count == 0 then return 0 end
    local angle = (atan2(stick.x, stick.y) + 360) % 360
    local slices = self:GetAttribute("dual") and self:GetAttribute("stage") ~= "spells" and count or 8
    local index=(floor(angle * slices / 360 + 0.5) % slices) + 1
    return index<=count and index or 0
]]
-- These are native directional key edges emitted with GamePadStickAxisButtons.
-- Keep all cast decisions in the same restricted click as the last key-up.
S.clearAim = [[
    for key in gmatch("PADRSTICKUP PADRSTICKRIGHT PADRSTICKDOWN PADRSTICKLEFT", "%S+") do
        self:SetAttribute("held-" .. key, nil)
    end
    self:SetAttribute("aim-count", 0)
    self:SetAttribute("aim-index", nil)
    local checkStick = ...
    local state = checkStick and GetGamePadState()
    local stick = state and state.sticks and state.sticks[self:GetAttribute("camera-index") or 2]
    self:SetAttribute("aim-wait", stick and stick.x and stick.y and max(abs(stick.x), abs(stick.y)) > 0.55 or nil)
]]
S.aim = [[
    local key, down = ...
    local state = GetGamePadState()
    local stick = state and state.sticks and state.sticks[self:GetAttribute("camera-index") or 2]
    if not stick or not stick.x or not stick.y then self:RunAttribute("op-clearAim"); return 0 end
    local magnitude = max(abs(stick.x), abs(stick.y))
    if self:GetAttribute("aim-wait") then
        if not down and magnitude <= 0.55 then self:SetAttribute("aim-wait", nil) end
        return 0
    end
    local held = "held-" .. key
    local count = self:GetAttribute("aim-count") or 0
    if down then
        if self:GetAttribute(held) then return 0 end
        self:SetAttribute(held, true)
        self:SetAttribute("aim-count", count + 1)
        self:SetAttribute("aim-index", self:RunAttribute("op-point"))
        return 0
    end
    if not self:GetAttribute(held) then return 0 end
    self:SetAttribute(held, nil)
    self:SetAttribute("aim-count", count - 1)
    if count > 1 then
        -- Rolling from a diagonal onto an extended axis changes the pick.
        -- On a snap to center, the two up events can arrive separately.
        if magnitude > 0.55 then self:SetAttribute("aim-index", self:RunAttribute("op-point")) end
        return 0
    end
    local index = self:GetAttribute("aim-index") or 0
    self:SetAttribute("aim-index", nil)
    if magnitude > 0.55 then return 0 end
    return index
]]
-- Mouse coordinates come from the restricted frame handle. Both the painted
-- wheel and this hit test use the visible wheel diameter as their unit.
S.mousePoint = [[
    local x, y = self:GetFrameRef("surface"):GetMousePosition()
    if not x then return 0, 0 end
    x, y = x - 0.5, y - 0.5
    local distance = x*x + y*y
    if distance < 0.0121 or distance > 0.25 then return 0, 0 end
    local angle = (atan2(x, y) + 360) % 360
    if distance >= 0.09 then return 0, floor(angle / 45 + 0.5) % 8 + 1 end
    local n = self:GetAttribute("raid") and self:GetAttribute("group-count-" .. self:GetAttribute("group")) or self:GetAttribute("member-count")
    if n > 0 then return floor(angle*n/360 + 0.5) % n + 1, 0 end
    return 0, 0
]]
S.cancelSweep = [[
    local group = self:GetAttribute("group")
    self:RunAttribute("op-stage", self:GetAttribute("raid") and "members" or "root", group)
]]
S.sweepClick = [[
    local ref, button, down = ...
    local mouse = button == "SweepMouse"
    local stage = self:GetAttribute("stage")
    local active = self:GetAttribute("sweep-button")
    if down then
        -- A fresh physical mouse press can follow a release outside the window.
        if mouse and active == button then
            self:RunAttribute("op-cancelSweep")
            stage = self:GetAttribute("stage")
            active = nil
        end
        if active or self:GetAttribute("pressed") then return false end
        local ally, spell
        if mouse then ally, spell = self:RunAttribute("op-mousePoint")
        else ally = self:RunAttribute("op-point") end
        if stage == "spells" then
            if mouse and spell == 0 then return false end
            self:SetAttribute("sweep-click-slot", mouse and spell or nil)
        else
            if not mouse and ally == 0 then ally = self:GetAttribute("selected") or 0 end
            if ally == 0 then return false end
            self:RunAttribute("op-choose", ref, button, ally)
            if self:GetAttribute("stage") ~= "spells" then return false end
            self:SetAttribute("sweep-click-slot", nil)
        end
        self:SetAttribute("sweep-epoch", self:GetFrameRef("input-epoch"):GetAttribute("revision"))
        self:SetAttribute("sweep-button", button)
        return false
    end
    if active ~= button then return false end
    local slot = self:RunAttribute("op-point")
    if mouse then
        local _, outer = self:RunAttribute("op-mousePoint")
        slot = outer
        local original = self:GetAttribute("sweep-click-slot")
        if original and slot ~= original then slot = 0 end
    elseif (self:GetAttribute("selected") or 0) > 0 then
        slot = self:GetAttribute("selected")
    end
    self:SetAttribute("sweep-button", nil)
    if slot == 0 or not self:GetAttribute("page-slot-" .. self:GetAttribute("page") .. "-" .. slot) then
        self:RunAttribute("op-cancelSweep")
        return false
    end
    return self:RunAttribute("op-choose", ref, button, slot)
]]
S.click = [[
    local clickedRef, button, down = ...
    local input = button
    button = self:GetAttribute("command-" .. button) or button
    local clicked = clickedRef and self:GetFrameRef(clickedRef)
    if not clicked then return false end
    clicked:SetAttribute("type", nil)
    clicked:SetAttribute("spell", nil)
    clicked:SetAttribute("macro", nil)
    clicked:SetAttribute("macrotext", nil)
    clicked:SetAttribute("unit", nil)
    local index = clicked:GetAttribute("index")
    -- A native /click macro delivers one secure click, not a binding pair.
    -- This dedicated entry can only toggle the menu, never select an action.
    if button == "ToggleMacro" or button == "ClassicMacro" or button == "SweepMacro" then
        if not down then self:RunAttribute("op-open", button=="ClassicMacro" and "classic" or button=="SweepMacro" and "sweep" or nil) end
        return false
    end
    local dual = self:GetAttribute("open") and self:GetAttribute("dual")
    local sweep = self:GetAttribute("sweep-button")
    if sweep and self:GetAttribute("sweep-epoch") ~= self:GetFrameRef("input-epoch"):GetAttribute("revision") then
        self:RunAttribute("op-cancelSweep")
        sweep = nil
        if not down then return false end
    end
    if dual and (button == "SweepMouse" or button == "ConfirmTrigger") then
        return self:RunAttribute("op-sweepClick", clickedRef, input, down)
    end
    if button == "SweepMouse" then return false end
    if sweep and down and (button == "Back" or button == "BackDpad" or button == "Cancel") then
        if button=="Cancel" then self:RunAttribute("op-close") else self:RunAttribute("op-cancelSweep") end
        return false
    end
    if sweep and (index or button=="Confirm" or button=="ConfirmDpad") then return false end
    if button == "StickRelease" then return false end
    if button == "PADRSTICKUP" or button == "PADRSTICKRIGHT" or button == "PADRSTICKDOWN" or button == "PADRSTICKLEFT" then
        if dual or index or not self:GetAttribute("open") or self:GetAttribute("pressed") then return false end
        local aimed = self:RunAttribute("op-aim", button, down)
        if aimed == 0 then return false end
        return self:RunAttribute("op-choose", clickedRef, button, aimed)
    end
    if down then
        if self:GetAttribute("pressed") then return false end
        self:RunAttribute("op-clearAim", true)
        self:SetAttribute("pressed", (index and "Cell" .. index) or input)
        self:SetAttribute("press-stage", self:GetAttribute("stage"))
        self:SetAttribute("press-member", self:GetAttribute("member"))
        self:SetAttribute("press-page", self:GetAttribute("page"))
        local pointed = self:RunAttribute("op-point")
        self:SetAttribute("press-index", pointed > 0 and pointed or self:GetAttribute("selected") or 0)
        return false
    end
    local pressed = self:GetAttribute("pressed")
    -- Separate command names prevent LT and D-pad releases from pairing.
    if pressed ~= ((index and "Cell" .. index) or input) then return false end
    self:SetAttribute("pressed", nil)
    if button == "Toggle" or button == "Classic" or button == "Sweep" then
        self:RunAttribute("op-open", button=="Classic" and "classic" or button=="Sweep" and "sweep" or nil)
        return false
    end
    if not self:GetAttribute("open") then return false end
    if button == "Cancel" then self:RunAttribute("op-close"); return false end
    local stage = self:GetAttribute("stage")
    local group = self:GetAttribute("group")
    local member = self:GetAttribute("member")
    local page = self:GetAttribute("page") or 0
    if stage ~= self:GetAttribute("press-stage") or member ~= self:GetAttribute("press-member")
        or page ~= self:GetAttribute("press-page") then return false end
    if button == "Back" or button == "BackDpad" then
        if stage == "spells" then self:RunAttribute("op-stage", self:GetAttribute("raid") and "members" or "root", group)
        elseif stage == "members" then self:RunAttribute("op-stage", "root", group)
        else self:RunAttribute("op-close") end
        return false
    end
    if self:GetAttribute("raid") and (button == "RaidGroups" or button == "RaidMembers") then
        if button == "RaidGroups" then self:RunAttribute("op-stage", "root", group)
        elseif (self:GetAttribute("group-count-" .. group) or 0) > 0 then self:RunAttribute("op-stage", "members", group) end
        return false
    end
    local count = self:GetAttribute("count") or 0
    if button == "Next" or button == "Previous" then
        if count > 0 then
            local selected = self:GetAttribute("selected") or 0
            self:SetAttribute("selected", selected == 0 and (button == "Next" and 1 or count)
                or ((selected - 1 + (button == "Next" and 1 or -1)) % count) + 1)
            self:CallMethod("Paint")
        end
        return false
    end
    if button == "PageNext" or button == "PagePrevious" then
        if stage == "spells" then
            local nextPage=self:GetAttribute((button=="PageNext" and "page-next-" or "page-previous-")..page)
            if nextPage then
                self:RunAttribute("op-stage", "spells", group, member, nextPage)
                if sweep then self:SetAttribute("sweep-button", sweep) end
            end
        end
        return false
    end
    if not index then
        if button ~= "Confirm" and button ~= "ConfirmDpad" and button ~= "ConfirmTrigger" then return false end
        -- Sample only inside the genuine button-down handler. Recentring before
        -- button-up is safe; insecure hover/axis state never chooses an action.
        index = self:GetAttribute("press-index") or 0
    end
    return self:RunAttribute("op-choose", clickedRef, button, index)
]]
S.choose = [[
    local clickedRef, button, index = ...
    local clicked = self:GetFrameRef(clickedRef)
    if not self:GetAttribute("open") or not self:GetAttribute("enabled")
        or self:GetAttribute("state-availability") == "blocked" then return false end
    if index < 1 or index > (self:GetAttribute("count") or 0) then return false end
    if not self:GetAttribute("roster-valid") then self:RunAttribute("op-close"); return false end
    local stage = self:GetAttribute("stage")
    local group = self:GetAttribute("group")
    local member = self:GetAttribute("member")
    local page = self:GetAttribute("page") or 0
    if stage == "root" then
        if self:GetAttribute("raid") then
            if (self:GetAttribute("group-count-" .. index) or 0) == 0 then return false end
            self:RunAttribute("op-stage", "members", index)
        else self:RunAttribute("op-stage", "spells", 1, index) end
        return false
    elseif stage == "members" then
        member = self:GetAttribute("group-" .. group .. "-" .. index)
        if member then self:RunAttribute("op-stage", "spells", group, member) end
        return false
    end
    local unit = member and self:GetAttribute("unit-" .. member)
    if not unit or not UnitExists(unit) or not PlayerCanAssist(unit) then return false end
    local action = self:GetAttribute("page-slot-"..page.."-"..index)
    if not action then return false end
    local kind = self:GetAttribute("kind-" .. member .. "-" .. action)
    local value = self:GetAttribute("value-" .. member .. "-" .. action)
    if not kind or not value then return false end
    if kind=="whisper" then
        self:RunAttribute("op-close")
        self:CallMethod("Whisper",unit)
        return false
    end
    clicked:SetAttribute("unit", unit)
    clicked:SetAttribute("type", kind == "saved" and "macro" or kind)
    if kind~="target" and kind~="focus" then
        clicked:SetAttribute(kind == "spell" and "spell" or kind == "saved" and "macro" or "macrotext", value)
    end
    self:SetAttribute("finish-member", member)
    self:SetAttribute("finish-group", group)
    self:SetAttribute("finish-page", page)
    return button, "finished"
]]
function S.Attach(button, hub)
    -- Restricted closure varargs are scrubbed: a frame handle passed there
    -- becomes nil. Pass a primitive ref key and resolve it inside the snippet.
    local id = (hub:GetAttribute("click-ref-count") or 0) + 1
    local ref = "click-" .. id
    hub:SetAttribute("click-ref-count", id)
    hub:SetFrameRef(ref, button)
    button:SetAttribute("wheel-click-ref", ref)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", false)
    -- One real hardware down/up pair per tier. No synthetic Click calls.
    SecureHandlerWrapScript(button, "OnClick", hub,
        'return control:RunAttribute("op-click", self:GetAttribute("wheel-click-ref"), self:GetAttribute("command") or button, down)',
        'if message == "finished" then control:RunAttribute("op-finish") end')
end
