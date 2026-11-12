local _, W = ...
local K = { rows = {}, pool = {}, labels = {}, generation = 0, view = "keys", selectedRow = 1, selectedCol = 1, slot = 1, scopeIndex = 1 }
W.Keyboard = K
local function spec(text, action, hint, weight) return { text = text, action = action, hint = hint, weight = weight or 1 } end
local function label(text, weight) return { text = text, label = true, weight = weight or 1 } end
local scopes = { "context", "chat", "global" }
-- Keep the borderless overlay and its navigation geometry in one coordinate space.
local CONTENT_WIDTH, WINDOW_GUTTER = 660, 24
local KEY_GAP = 6
local QUICK_X, QUICK_WIDTH = 676, 324
local ASSIGN_WIDTH = 480
local WINDOW_WIDTH = CONTENT_WIDTH + WINDOW_GUTTER * 2

function K:Status(message)
    self.lastStatus = message
    -- Allocate a caption only for actual feedback, never for a repeated native
    -- field/channel name. Skip text synchronization when reporting a write error.
    if self.frame and self.frame:IsShown() then self:Draw(message, true) end
end
function K:Context() return self.session and self.session.context or self.quickContext or { key = "global", label = W.L["All text fields"], maxBytes = 1024 } end
function K:Numeric() return self.session and self.session.context.numeric and not self.composing end
function K:Scope()
    if self.scopeIndex == 2 and not self:Context().chat then self.scopeIndex = 1 end
    local selected = scopes[self.scopeIndex]
    return selected == "context" and self:Context().key or selected
end
function K:Init()
    local frame = CreateFrame("Frame", "WoWEnhancedControllerKeyboard", UIParent)
    self.frame = frame; frame:SetSize(WINDOW_WIDTH, 440 + WINDOW_GUTTER * 2); frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Hide(); frame:EnableMouse(true); W.Theme.KeyboardShell(frame)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", WINDOW_GUTTER, -WINDOW_GUTTER)
    content:SetSize(CONTENT_WIDTH, 440)
    self.content = content
    self.destination = W.Theme.Label(content, ""); self.destination:SetPoint("TOPLEFT", 18, -2)
    self.destination:SetSize(610, 24); self.destination:SetJustifyH("LEFT"); self.destination:SetWordWrap(false)
    self.focusButton = W.Theme.Button(frame, "", function() W.FocusBinding() end)
    self.focusButton:SetPoint("CENTER", frame, "BOTTOM", 0, 4); self.focusButton:SetSize(32, 32)
    frame:SetScript("OnHide", function()
        self:ReleaseUI()
        -- A raw Hide (Escape/parent/native dismissal) is a close. Only our
        -- explicit suspension path may retain a session for later resumption.
        if not self.hiding then
            if W.Placement.editing then W.Placement.Leave() end
            self:Close()
        end
    end)
    frame:EnableKeyboard(true); frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", function(_, key)
        if W.Combat() then return end
        -- A focused native field owns Escape; its focus-lost hook closes us.
        local handled = key == "ESCAPE" and not W.Focus() and not W.Blocker()
        frame:SetPropagateKeyboardInput(not handled)
        if handled then self:Action("back") end
    end)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if W.Placement.editing and self.positionId == "keyboard" and not W.Combat() then frame:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function() W.Placement.DragStop("keyboard") end)
    frame:SetScript("OnMouseDown", function() if W.Input then W.Input:Acquire() end end)
    W.Placement.Register("keyboard", frame, W.L["Controller keyboard"])
end
function K:EnsureComposer()
    if self.input then return end
    local content = self.content
    self.input, self.inputBorder = W.Theme.Input(content)
    self.inputBorder:SetPoint("TOPLEFT", 16, -28); self.inputBorder:SetSize(628, 52)
    self.input:SetMaxBytes(0)
    self.input:SetScript("OnTextChanged", function(box, userInput)
        if self.syncing or not userInput or not self.editor then return end
        local text = box:GetText()
        self.editor:Select(0, #self.editor.text); self.editor:Replace(text)
        self.editor:Select(box:GetCursorPosition(), box:GetCursorPosition())
        self:Sync()
    end)
    self.input:SetScript("OnEscapePressed", function() self:Action("back") end)
    self.input:SetScript("OnEnterPressed", function() self:Action("confirm") end)
    self.input:SetScript("OnEditFocusGained", function() if W.Input then W.Input:Acquire() end end)
    self.input:SetScript("OnCursorChanged", function(box, x, y, width, height)
        if self.editor and not self.syncing then
            local cursor = box:GetCursorPosition()
            self.editor:Select(cursor, cursor)
        end
        if y and box.wecScroll then
            local scroll = box.wecScroll
            local offset, top = scroll:GetVerticalScroll(), -y
            if top < offset then scroll:SetVerticalScroll(math.max(0, top))
            elseif top + (height or 16) > offset + scroll:GetHeight() then
                scroll:SetVerticalScroll(math.max(0, top + (height or 16) - scroll:GetHeight()))
            end
        end
    end)
end
function K:SyncComposer()
    if not self.editor or not self.input or not self.composing.typing then return end
    self.syncing = true
    self.input:SetText(self.editor.text)
    local _, fontHeight = W.Call(self.input, "GetFont")
    self.input:SetHeight(math.max(34, (self.input:GetNumLines() or 1) * ((fontHeight or 14) + 2) + 10))
    self.input:SetCursorPosition(self.editor.cursor)
    if self.editor.anchor ~= self.editor.cursor then
        self.input:HighlightText(math.min(self.editor.anchor, self.editor.cursor), math.max(self.editor.anchor, self.editor.cursor))
    end
    self.syncing = false
end
function K:InputOwner()
    return self.composing and self.composing.typing and self.input or self.session and self.session.target or self.quickOwner
end
function K:FocusField()
    local box = self:InputOwner()
    if not box then return end
    if not W.Call(box, "HasFocus") then
        local syncing = self.syncing
        self.syncing = true
        W.Call(box, "SetFocus")
        if self.editor then
            local e = self.composing and not self.composing.typing and self.composing.editor or self.editor
            W.Call(box, "SetCursorPosition", e.cursor)
            if e.anchor ~= e.cursor then W.Call(box, "HighlightText", math.min(e.anchor, e.cursor), math.max(e.anchor, e.cursor))
            else W.Call(box, "ClearHighlightText") end
        end
        self.syncing = syncing
    end
end
function K:Sync()
    if not self.editor then return end
    if self.composing then self:SyncComposer()
    elseif self.session then W.NativeField.Write(self) end
end
function K:Insert(value)
    if self.composing then self.editor:Replace(value); self:Sync()
    elseif self.session then
        local oldContext = self.session.context
        if W.NativeField.Insert(self, value) and not W.Contexts.Same(oldContext, self.session.context) then self:Draw() end
    end
end
function K:Select(row, col)
    self.navColumn = nil
    if self.focused then
        self.focused.focus:Hide()
        W.Theme.Prompt(self.focused, self.focused.basePrompt, self.focused.promptMode)
        if self.focused.linkEntry then W.Links:RowPrompt(self.focused, false) end
    end
    self.selectedRow = W.Clamp(row, 1, #self.rows)
    local controls = self.rows[self.selectedRow]
    if not controls or #controls == 0 then return end
    self.selectedCol = W.Clamp(col, 1, #controls)
    local b = controls[self.selectedCol]
    if not b:IsEnabled() then
        for r, candidates in ipairs(self.rows) do
            for c, candidate in ipairs(candidates) do
                if candidate:IsEnabled() then self:Select(r, c); return end
            end
        end
        self.focused = nil; return
    end
    self.focused = b; b.focus:Show()
    if W.Input and #b.basePrompt == 0 then W.Theme.Prompt(b, { "primary" }, b.promptMode == "combo" and "combo" or "corner") end
    if self.linking then
        if b.linkIndex then self.linking.index = b.linkIndex end
        if b.linkEntry then W.Links:RowPrompt(b, true) end
        W.Links:Tooltip(self, b)
    end
    if b.messageSlot and self.quickHint then
        local text = W.Phrases.Resolve(self:Context(), b.messageSlot, self.quickBank)
        self.quickHint:SetText(W.Escape(text ~= "" and text or W.L["Choose a message in Assign mode first."]))
    elseif b.bankAction and self.quickHint then self.quickHint:SetText(W.L[b.bankAction])
    end
end
function K:Move(dx, dy)
    if self.linking then W.Links:Move(self, dx, dy); return end
    if W.Placement.editing and self.nudging then W.Placement.Nudge(self.positionId or "keyboard", dx * 4, -dy * 4); return end
    if self:Numeric() and not self.digits and self.view == "keys" then
        self.editor:Adjust(dy == -1 and 1 or dy == 1 and -1 or dx * 10); self:Sync(); return
    end
    if not self.focused then return end
    local controls = {}
    for _, row in ipairs(self.rows) do for _, button in ipairs(row) do controls[#controls + 1] = button end end
    local column = dy ~= 0 and (self.navColumn or self.focused.navX) or nil
    local nextButton = W.Theme.DirectionalNeighbor(self.focused, controls, dx, dy, column)
    if nextButton then
        self:Select(nextButton.row, nextButton.col)
        self.navColumn = column
    end
end
function K:AddRow(items, y, height, left, span)
    local row, total = {}, 0
    for _, item in ipairs(items) do total = total + item.weight end
    local available, x = (span or 624) - (#items - 1) * KEY_GAP, left or 18
    for _, item in ipairs(items) do
        local width = available * item.weight / total
        if item.label then
            self.labelsUsed = self.labelsUsed + 1
            local text = self.labels[self.labelsUsed]
            if not text then text = W.Theme.Label(self.content); self.labels[self.labelsUsed] = text end
            text:ClearAllPoints(); text:SetPoint("TOPLEFT", x + 8, -y)
            text:SetSize(width - 16, height); text:SetJustifyH("LEFT")
            text:SetFontObject(W.Theme.Font("GameFontNormal"))
            text:SetText(W.Escape(item.text)); text:Show()
        else
            self.used = self.used + 1
            local button = self.pool[self.used]
            if not button then
                button = W.Theme.Button(self.content, "", function(b)
                    if b.skipClick then b.skipClick = nil; return end
                    if self.session and not W.Contexts.Valid(self.session) then self:Close(W.L["Field changed; draft not applied."]); return end
                    local owned = self:InputOwner()
                    if owned and W.Call(owned, "HasFocus") ~= true then
                        local focus = W.Focus()
                        if focus and focus ~= owned and not (self.composing and self.session and focus == self.session.target) then self.suspended = true; self:Hide(); return end
                        if owned.chatFrame and not W.ControllerMode() then return end
                        self:FocusField(); W.Input:Acquire()
                    end
                    if b.generation == self.generation and b.run then b.run() end
                end)
                button:SetScript("OnMouseDown", function(b)
                    if W.Input and GetTime and GetTime() - (W.Input.padAt or -1) < 0.15 then return end
                    if self.session and not W.Contexts.Valid(self.session) then return end
                    local owned = self:InputOwner()
                    if not owned then return end
                    local focus = W.Focus()
                    if focus and focus ~= owned and not (self.composing and self.session and focus == self.session.target) then b.skipClick = true; W.WatchFocus(); return end
                    if owned.chatFrame and not W.ControllerMode() and not W.Call(owned,"HasFocus") then b.skipClick = true; return end
                    self.mouseEditing = b; self:FocusField(); W.Input:Acquire()
                end)
                button:SetScript("OnMouseUp", function() self.mouseEditing = nil end)
                self.pool[self.used] = button
            end
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", x, -y); button:SetSize(width, height)
            if item.tab then W.Theme.Tab(button, item.selected, true) else W.Theme.KeyboardButton(button,nil,item.selected) end
            button:SetText(W.Escape(item.text)); button:Show()
            button.row, button.col, button.generation = #self.rows + 1, #row + 1, self.generation
            button.basePrompt = type(item.hint) == "table" and item.hint
                or item.hint and W.Input:Icon(item.hint) and { item.hint } or {}
            button.promptMode = item.bank and "bank" or item.combo and "combo" or item.phrase and "phrase" or (#button.basePrompt == 0 and "corner" or "inline")
            W.Theme.Prompt(button, button.basePrompt, button.promptMode)
            button.run = item.action
            button.messageSlot = item.messageSlot
            button.bankAction = item.bank
            if item.bank and not button.bankHighlight then
                button.bankHighlight = W.Theme.KeyboardRim(button, "hover")
                button.heldHighlight = W.Theme.KeyboardRim(button, "hover", true)
            end
            if button.bankHighlight then button.bankHighlight:SetShown(item.bank == self.quickBank) end
            if button.heldHighlight then button.heldHighlight:Hide() end
            button.navX, button.navY = x + width / 2, y + height / 2
            button.navGroup = (x >= QUICK_X or self.assigning and not self.composing) and "quick" or "keys"
            button:SetEnabled(not item.disabled); row[#row + 1] = button
        end
        x = x + width + KEY_GAP
    end
    if #row > 0 then self.rows[#self.rows + 1] = row end
    return y + height + KEY_GAP
end
function K:Draw(message, skipSync)
    W.Theme.KeyboardShell(self.frame)
    self.quickBank = self.quickBank or "phrases"
    self.generation = self.generation + 1
    for _, button in ipairs(self.pool) do
        button:Hide(); button.focus:Hide(); button.linkEntry, button.linkIndex = nil, nil
        if button.linkIcon then button:EnableMouseWheel(false) end
        if button.linkIcon then button.linkIcon:Hide(); button.linkCount:Hide() end
    end
    for _, text in ipairs(self.labels) do text:Hide() end
    self.rows, self.used, self.labelsUsed, self.focused = {}, 0, 0, nil
    if self.linking then W.Links:Draw(self, message); return end
    W.Links:HideControls()
    if self.channels then self:DrawChannels(); return end
    local c = self:Context()
    self.destination:SetFontObject(W.Theme.Font("GameFontNormal"))
    if self.composing and self.composing.typing then
        self:EnsureComposer(); self.inputBorder:Show()
        self.input:SetFontObject(W.Theme.Font("GameFontHighlight"))
    elseif self.inputBorder then self.inputBorder:Hide() end
    W.Theme.FocusBadge(self.focusButton)
    local caption = message or (W.Placement.editing and (self.positionId == "radial" and W.L["Wheel position"] or W.L["Keyboard position"]))
        or (self:Numeric() and W.L.Format("Range: %s to %s", c.min or "?", c.max or W.L["field maximum"]))
    self.destination:SetText(W.Escape(caption or ""))
    if caption then self.destination:Show() else self.destination:Hide() end
    local y = caption and 32 or 0
    self.quickVisible = not W.Placement.editing and not self:Numeric()
    if self.view ~= "keys" and self.view ~= "tools" then self.view = "keys" end
    if self.quickDecoration then self.quickDecoration:Hide() end
    if self.assigning then
        self.quickVisible = false
        if self.composing and self.composing.typing then
            self.inputBorder:ClearAllPoints(); self.inputBorder:SetPoint("TOPLEFT", 18, -y)
            self.inputBorder:SetSize(624, 54); self.input:SetWidth(608)
            self.input:SetMaxBytes(1024); self.input:SetMaxLetters(255)
            y = self:DrawKeys(y + 62)
            y = self:AddRow({spec(W.L["Back"], function() self:Action("back") end, "back"),
                spec(W.L["Delete"], function() self:Action("delete") end, "delete"),
                spec(W.L["Shift"], function() self:Action("shift") end, "shift"),
                spec(W.L["Done"], function() self:Action("confirm") end, "confirm")}, y, 40)
        else
            y = self:DrawQuickMessages(y)
        end
        self:SizeToRows(y); self:Select(self.selectedRow,self.selectedCol)
        if not skipSync then self:Sync() end
        return
    end
    if not W.Placement.editing then
        local tabs = {}
        for _, tab in ipairs({ { "keys", W.L["Keyboard"] }, { "tools", W.L["Edit tools"] } }) do
            local view = tab[1]
            local item = spec(tab[2], function() self.view = view; self:Draw() end)
            item.tab, item.selected = true, self.view == view
            tabs[#tabs + 1] = item
        end
        y = self:AddRow(tabs, y, 34) + 6
    end
    if W.Placement.editing then y = self:DrawPosition(y)
    elseif self.view == "keys" then y = self:DrawKeys(y)
    else y = self:DrawTools(y) end
    if not W.Placement.editing then
        y = y + 8
        local send = spec(self.composing and W.L["Save"] or c.chat and W.L["Send"] or W.L["Done"], function() self:Action("confirm") end, "confirm")
        send.disabled = self.assigning and not self.composing
        y = self:AddRow({ spec(W.L["Close"], function() self:Action("back") end, "back"),
            spec(W.L["Delete"], function() self:Action("delete") end, self:Numeric() and "shift" or "delete"),
            spec(self:Numeric() and (self.digits and W.L["Amount"] or W.L["Digits"]) or W.L["Shift"], function() self:Action(self:Numeric() and "digits" or "shift") end, self:Numeric() and "delete" or "shift"),
            send }, y, 42)
    end
    if self.quickVisible then y = math.max(y, self:DrawQuickMessages()) end
    if message then self.destination:SetText(W.Escape(message)) end
    self:SizeToRows(y)
    self:Select(self.selectedRow, self.selectedCol)
    if not skipSync then self:Sync() end
end
function K:SizeToRows(y)
    self.content:SetHeight(y + 8)
    local windowHeight = y + 8 + WINDOW_GUTTER * 2
    local windowWidth = self.quickVisible and QUICK_X + QUICK_WIDTH + WINDOW_GUTTER * 2 or WINDOW_WIDTH
    if self.assigning and not self.linking and not self.channels and not (self.composing and self.composing.typing) then
        windowWidth = ASSIGN_WIDTH + 36 + WINDOW_GUTTER * 2
    end
    self.frame:SetSize(windowWidth, windowHeight); self.content:SetWidth(windowWidth - WINDOW_GUTTER * 2)
    local desired = W.db.scale * (W.db.largeKeys and 1.15 or 1)
    local fit = math.min((UIParent:GetWidth() - 32) / windowWidth, (UIParent:GetHeight() - 32) / windowHeight)
    self.frame:SetScale(math.min(desired, fit))
    W.Placement.Apply("keyboard")
end
function K:DrawKeys(y)
    local c, phrases = self:Context(), {}
    local bindings = W.Phrases.Bindings(c, self.quickBank)
    for i = 1, self:Numeric() and 4 or 0 do
        local slot, text = i, W.Phrases.Resolve(c, i, self.quickBank)
        local item = spec(text, function() self:InsertPhrase(slot) end,
            bindings[i] ~= "unbound" and { self.quickBank or "phrases", bindings[i] } or {})
        item.phrase = true
        phrases[#phrases + 1] = item
    end
    if #phrases > 0 then y = self:AddRow(phrases, y, 54) end
    if self:Numeric() and not self.digits then
        y = self:AddRow({ spec(W.L["Left: -10"], function() self.editor:Adjust(-10); self:Sync() end),
            spec(W.L["Down: -1"], function() self.editor:Adjust(-1); self:Sync() end),
            spec(W.L["Up: +1"], function() self.editor:Adjust(1); self:Sync() end),
            spec(W.L["Right: +10"], function() self.editor:Adjust(10); self:Sync() end) }, y, 42)
        y = self:AddRow({ spec(W.L["Minimum"], function() self:SetAmount(c.min or 0) end),
            spec(W.L["Maximum"], function() if c.max then self:SetAmount(c.max) else self:Status(W.L["The native field does not expose a maximum."]) end end),
            spec(W.L["Type digits"], function() self.digits = true; self:Draw() end) }, y, 32)
        return y
    end
    local rows = self:Numeric() and { "789", "456", "123", "0" } or self.symbols
        and { "1234567890", "!@#$%^&*()", "-_=+/:;?.,", "[]{}'\"\\~`" } or W.Locale.rows
    if self.symbols and not self:Numeric() and W.Locale.extras then rows[#rows + 1] = W.Locale.extras end
    local columns = 0
    for _, letters in ipairs(rows) do columns = math.max(columns, #W.Locale.Characters(letters)) end
    local keyWidth = (624 - (columns - 1) * KEY_GAP) / columns
    for _, letters in ipairs(rows) do
        local keys = {}
        for _, ch in ipairs(W.Locale.Characters(letters)) do
            local char = self.shift and W.Locale.Upper(ch) or ch
            keys[#keys + 1] = spec(char, function() self:Insert(char); self.shift = false; self:Draw() end)
        end
        local span = #keys * keyWidth + (#keys - 1) * KEY_GAP
        y = self:AddRow(keys, y, 42, 18 + (624 - span) / 2, span)
    end
    if self:Numeric() then
        return self:AddRow({ spec(W.L["Move left"], function() self:Action("left") end, "left"),
            spec(W.L["Move right"], function() self:Action("right") end, "right"),
            spec(W.L["Clear all"], function() self:Action("clear") end, "clear"),
            spec(W.L["Undo"], function() self:Action("undo") end) }, y, 38)
    end
    y = self:AddRow({ spec(W.L["Left"], function() self:Action("left") end, "left"),
        spec(W.L["Space"], function() self:Action("space") end, "space", 1.5),
        spec(W.L["Right"], function() self:Action("right") end, "right") }, y, 42)
    local utilities = { spec(W.L["Symbols"], function() self:Action("symbols") end, "symbols") }
    if c.chat and not self.composing and not self.assigning then
        utilities[#utilities + 1] = spec(W.L["Link in chat"], function() W.Links:Open(self) end)
        utilities[#utilities + 1] = spec(W.L.Format("Channel: %s", c.label), function() self:Action("channels") end)
    end
    utilities[#utilities + 1] = spec(W.L["Clear all"], function() self:Action("clear") end, "clear")
    utilities[#utilities + 1] = spec(W.L["Undo"], function() self:Action("undo") end)
    y = self:AddRow(utilities, y, 42)
    return y
end
function K:SetAmount(n)
    if self.session and not self.composing and W.Call(self.session.target, "HasFocus") ~= true then return end
    local o = self.editor.options
    n = W.Clamp(n, o.min, o.max)
    if not o.decimal and n % 1 ~= 0 then self:Status(W.L["This field accepts whole numbers only."]); return end
    local value = tostring(n)
    if W.Text.Limit(value, o.maxBytes, o.maxLetters) ~= value then self:Status(W.L["This amount exceeds the field's digit limit."]); return end
    self.editor:Select(0, #self.editor.text); self.editor:Replace(value); self:Sync()
end
function K:InsertPhrase(slot, bank)
    if self.composing or self.assigning or self.linking or not self.session then return end
    local context=self:Context()
    local text,_,link,destination = W.Phrases.Resolve(context, slot, bank or self.quickBank)
    if text == "" then self:Status(W.L["Choose a message in Assign mode first."]); return end
    if self:Numeric() then
        local number = tonumber(text)
        if number then self:SetAmount(number) else self:Status(W.L["Choose a numeric phrase for this field."]) end
        return
    end
    if context.chat then
        local progress
        if link then
            text,progress=W.Links:Message(link)
            if not text then
                self:Status(link.kind=="tracked" and W.L["No quest is actively tracked."] or W.L["That objective is no longer available."])
                return
            end
        end
        local _,err=W.SendQuickMessage(self.session,text,progress,destination)
        if err then self:Status(err) end
    else self:Insert(text); self:Sync() end
end
function K:QuickLabel(text, x, y, width, height)
    self.labelsUsed = self.labelsUsed + 1
    local font = self.labels[self.labelsUsed]
    if not font then font = W.Theme.Label(self.content); self.labels[self.labelsUsed] = font end
    font:ClearAllPoints(); font:SetPoint("TOPLEFT", x, -y); font:SetSize(width, height)
    font:SetJustifyH("LEFT"); font:SetWordWrap(true); font:SetFontObject(W.Theme.Font("GameFontNormal"))
    font:SetText(W.Escape(text)); font:Show()
    return font
end
function K:ToggleAssign()
    if self:Numeric() then return end
    if self.composing then self:FinishQuickMessage(false) end
    if self.assigning and not self.session then self:Close(); return end
    self.assigning = not self.assigning; self.view = "keys"; self:Draw()
    if self.assigning then self:Select(self.quickButtons[self.slot].row,1) end
end
function K:UsePhrase(slot, bank)
    if bank and bank ~= self.quickBank and not self.composing then self:SetQuickBank(bank) end
    if self.assigning then self:BeginQuickMessage(slot)
    elseif not self.composing then self:InsertPhrase(slot, bank) end
end
function K:SetQuickBank(bank)
    if self.composing or not W.Input:IsModifier(bank) then return end
    if self.quickBank ~= bank then self.quickBank = bank; if self.frame:IsShown() then self:Draw() end end
end
function K:PaintQuickBank()
    if not self.quickBankButtons then return end
    for _, b in ipairs(self.quickBankButtons) do
        b.bankHighlight:SetShown(b.bankAction == self.quickBank)
        b.heldHighlight:SetShown(b.bankAction == W.Input.layer)
    end
end
function K:BeginQuickMessage(slot)
    if self.composing or self:Numeric() then return end
    local scope = self:Scope()
    self.composing = { editor = self.editor, scope = scope, slot = slot, bank = self.quickBank or "phrases",
        binding = W.Phrases.BindingsForScope(scope, self:Context(), self.quickBank)[slot] or "unbound" }
    self.composing.bindingOriginal = self.composing.binding
    local text,_,link,destination=W.Phrases.Resolve(self:Context(),slot,self.composing.bank)
    self.slot,self.composing.destination = slot,destination
    self.composing.link,self.composing.linkLabel=link,link and text
    self.editor = W.Text.New(text, { maxBytes = 1024, maxLetters = 255 })
    self.view = "keys"; self.selectedRow,self.selectedCol=2,1; self:Draw()
end
function K:CustomMessage(typing, cancel)
    local draft = self.composing
    if typing then
        draft.originalText = self.editor.text
    elseif cancel then
        self.editor = W.Text.New(draft.originalText, self.editor.options)
    end
    draft.typing = typing
    if not typing and self.input:HasFocus() then self.input:ClearFocus() end
    self.selectedRow,self.selectedCol = typing and 1 or draft.customRow,1
    self:Draw(); self:FocusField()
end
function K:SetQuickLink(link)
    local draft=self.composing
    if not draft then return end
    local name=link.kind=="tracked" and W.L["Current tracked quest"] or link.name
    self.editor:Select(0,#self.editor.text); self.editor:Replace(name)
    draft.link,draft.linkLabel=link,self.editor.text
    self.editor:Select(0,#self.editor.text); self:Draw(); self:FocusField()
end
function K:FinishQuickMessage(save)
    local draft = self.composing
    if not draft then return end
    if save then
        local ok, err = true
        if draft.bindingChanged then ok, err = W.Phrases.CheckBinding(draft.scope, draft.slot, draft.binding, self:Context(), draft.bank) end
        if ok then
            local link=self.editor.text==draft.linkLabel and draft.link or nil
            ok, err = W.Phrases.Save(draft.scope, draft.slot, self.editor.text, draft.bank, link, draft.destination)
        end
        if not ok then self:Status(err); return false end
        if draft.bindingChanged then W.Phrases.Bind(draft.scope, draft.slot, draft.binding, self:Context(), draft.bank) end
    end
    self.editor, self.composing = draft.editor, nil
    if self.input and self.input:HasFocus() then self.input:ClearFocus() end
    self:Draw(); self:FocusField()
    self:Select(self.quickButtons[draft.slot].row,1)
    return true
end
function K:CycleQuickScope()
    repeat self.scopeIndex = self.scopeIndex % #scopes + 1
    until self:Context().chat or self.scopeIndex ~= 2
    if self.composing then
        self.composing.scope = self:Scope()
        self.composing.binding = W.Phrases.BindingsForScope(self:Scope(), self:Context(), self.composing.bank)[self.composing.slot] or "unbound"
        self.composing.bindingOriginal, self.composing.bindingChanged = self.composing.binding, false
    end
    self:Draw()
end
function K:CycleQuickBinding()
    local choices, draft = { "primary", "back", "delete", "shift", "unbound" }, self.composing
    local at = 5
    for i, action in ipairs(choices) do if action == draft.binding then at = i end end
    for i = 1, #choices do
        local candidate = choices[(at + i - 1) % #choices + 1]
        if W.Phrases.CheckBinding(draft.scope, draft.slot, candidate, self:Context(), draft.bank) then
            draft.binding, draft.bindingChanged = candidate, candidate ~= draft.bindingOriginal; self:Draw(); return
        end
    end
end
function K:QuickContexts()
    local choices = { { key = "global", label = W.L["All text fields"], maxBytes = 1024 } }
    for _, name in ipairs({ "SAY", "YELL", "PARTY", "RAID", "RAID_WARNING", "INSTANCE_CHAT", "GUILD", "OFFICER", "WHISPER", "BN_WHISPER", "EMOTE" }) do
        -- Use the same native channel labels/context classification as real fields.
        local context = W.Contexts.Chat({ GetChatType = function() return name end })
        if name == "WHISPER" then context.label = W.L["Whisper"]
        elseif name == "BN_WHISPER" then context.label = W.L["Battle.net whisper"] end
        choices[#choices + 1] = context
    end
    choices[#choices + 1] = { key = "auction:search", label = W.L["Auction House search"], maxBytes = 255 }
    if GetChannelList then
        local list = { GetChannelList() }
        for i = 1, #list, 3 do
            if type(list[i]) == "number" and type(list[i + 1]) == "string" then
                choices[#choices + 1] = { key = "chat:channel:" .. list[i + 1]:lower(), label = list[i + 1], chat = true,
                    chatType = "CHANNEL", channel = list[i], channelName = list[i + 1], maxBytes = 255 }
            end
        end
    end
    return choices
end
function K:ShowQuickMessages()
    if W.Combat() then return end
    local context = self.session and W.Copy(self.session.context)
    self:Close()
    local owner = W.Focus()
    self.quickOwner = W.Usable(owner) and owner or nil
    self.quickContext = context or self.quickContext
    self.editor = W.Text.New("", {}); self.view, self.assigning = "keys", true
    self.frame:Show(); self:Draw(); W.Input:Acquire(true)
    self:Select(self.quickButtons[self.slot].row,1)
end
function K:DrawQuickMessages(top)
    top = top or 0
    local x, width = self.assigning and 18 or QUICK_X, self.assigning and ASSIGN_WIDTH or QUICK_WIDTH
    local fontSize = W.db.fontSize
    self.quickBankButtons = {}
    local headerHeight = math.max(34, fontSize * 2 + 6)
    local contextY, start = top + headerHeight + 8, top + headerHeight + 48
    self:QuickLabel(W.L["Quick messages"], x, top + 2, width - 138, headerHeight)
    self:AddRow({ spec(self.assigning and W.L["Done"] or W.L["Assign"], function() self:ToggleAssign() end, "library") }, top, 34, x + width - 134, 134)
    local context = self:Context()
    if self.session or self.composing then
        self:QuickLabel(context.label or context.key, x, contextY, width, 28)
    else
        self:AddRow({ spec(context.label or context.key, function()
            if self.composing then return end
            local choices, index = self:QuickContexts(), 1
            for i, c in ipairs(choices) do if c.key == context.key then index = i end end
            self.quickContext = choices[index % #choices + 1]; self:Draw()
        end) }, contextY, 32, x, width)
    end
    local y
    self.quickButtons = {}
    if not self.composing then
        local height, cell = math.max(64, fontSize * 2 + 30), (width - 12) / 3
        local bindings = W.Phrases.Bindings(context, self.quickBank)
        local positions = { PAD1 = { 2, 3 }, PAD2 = { 3, 2 }, PAD3 = { 1, 2 }, PAD4 = { 2, 1 } }
        local available, used = {}, {}
        for slot = 1, 4 do
            local token = W.Input.keys[bindings[slot]]
            if positions[token] and not used[token] then available[slot] = positions[token]; used[token] = true end
        end
        for slot = 1, 4 do
            if not available[slot] then
                for _, token in ipairs({ "PAD1", "PAD2", "PAD3", "PAD4" }) do
                    if not used[token] then available[slot] = positions[token]; used[token] = true; break end
                end
            end
            local index, position = slot, available[slot]
            local text = W.Phrases.Resolve(context, slot, self.quickBank)
            local item = spec(text ~= "" and text or W.L["Unassigned"], function() self:UsePhrase(index) end,
                bindings[slot] ~= "unbound" and bindings[slot] or nil)
            item.combo, item.messageSlot = true, slot
            self:AddRow({ item }, start + (position[2] - 1) * (height + 4), height, x + (position[1] - 1) * (cell + 6), cell)
            self.quickButtons[slot] = self.rows[#self.rows][1]
        end
        local banks = {}
        for _, action in ipairs(W.Input.modifiers) do
            local bank = action
            local item = spec(W.Input:Icon(bank) and "" or "-", function() self:SetQuickBank(bank) end, bank)
            item.bank = bank; banks[#banks + 1] = item
        end
        self:AddRow(banks, start + height + 10, 32, x + cell + 6, cell)
        for _, b in ipairs(self.rows[#self.rows]) do
            self.quickBankButtons[#self.quickBankButtons + 1] = b
        end
        self:PaintQuickBank()
        self:QuickLabel(W.L["Hold"], x + width / 2 - 42, start + height + 44, 84, 24)
        y = start + 3 * (height + 4)
        self.quickHint = self:QuickLabel(self.assigning and W.L["Choose a combination to assign."] or context.chat and W.L["Hold a modifier and a button to send."] or W.L["Hold a modifier and a button to insert."], x, y + 2, width, fontSize * 2 + 4)
        y = y + fontSize * 2 + 12
    else
        local draft = self.composing
        self:QuickLabel(W.L["Assign message"], x, start, width, 26)
        local presets = { W.L["Hello!"], W.L["Group?"], W.L["Ready!"], W.L["On my way."], W.L["Need a break."], W.L["Thank you!"] }
        y = start + 30
        for i = 1, #presets, 2 do
            local items = {}
            for j = i, i + 1 do
                local text = presets[j]
                local item = spec(text, function()
                    self.editor:Select(0, #self.editor.text); self.editor:Replace(text)
                    draft.link,draft.linkLabel=nil,nil; self:Draw()
                end)
                item.selected = not draft.link and self.editor.text == text
                items[#items+1] = item
            end
            y = self:AddRow(items, y, math.max(36, fontSize * 2 + 16), x, width)
        end
        if context.chat or context.key=="global" then
            y=self:AddRow({spec(W.L["Link in chat"],function() W.Links:Open(self,true) end),
                spec(W.L["Current tracked quest"],function() self:SetQuickLink({kind="tracked"}) end)},y,math.max(42,fontSize*3),x,width)
        end
        y = self:AddRow({spec(W.L["Custom message"],function() self:CustomMessage(true) end)},y,38,x,width)
        draft.customRow = #self.rows
        self:QuickLabel(self.editor.text, x, y, width, fontSize * 2 + 8); y = y + fontSize * 2 + 14
        if context.chat or context.key == "global" then
            local pin = draft.destination
            local destination = pin and W.Contexts.Destination(pin)
            local name = destination and destination.label or pin and pin.channelName or W.L["Current chat"]
            y = self:AddRow({spec(W.L.Format("Send to: %s", name),function() self:Action("channels") end)},y,38,x,width)
        end
        y = self:AddRow({ spec(W.L.Format("Scope: %s", W.L[scopes[self.scopeIndex]]), function() self:CycleQuickScope() end) }, y, 38, x, width)
        y = self:AddRow({ spec(draft.binding == "unbound" and W.L["Shortcut: Unbound"] or W.L["Shortcut:"], function() self:CycleQuickBinding() end,
            draft.binding ~= "unbound" and { draft.bank, draft.binding } or {}) }, y, 38, x, width)
        y = self:AddRow({ spec(W.L["Save"], function() self:Action("confirm") end, "confirm"),
            spec(W.L["Back"], function() self:Action("back") end, "back") }, y, 40, x, width)
        y = self:AddRow({ spec(W.L["Use inherited"], function()
            W.Phrases.Reset(draft.scope, draft.slot, draft.bank); self:FinishQuickMessage(false)
        end) }, y, 34, x, width)
        self.quickHint = nil
    end
    return y
end
function K:DrawTools(y)
    local rows = { { { W.L["Undo"], "undo" }, { W.L["Redo"], "redo" }, { W.L["Select all"], "all" } },
        { { W.L["Copy"], "copy" }, { W.L["Paste"], "paste" }, { W.L["Clear all"], "clear" } },
        { { W.L["Start"], "home" }, { W.L["End"], "end" }, { W.L["New line"], "newline" } },
        { { W.L["Previous field"], "previousField" }, { W.L["Next field"], "nextField" }, { W.L["Channels"], "channels" } } }
    for _, row in ipairs(rows) do
        local items = {}
        for _, a in ipairs(row) do local action = a[2]; items[#items + 1] = spec(a[1], function() self:Action(action) end) end
        y = self:AddRow(items, y, 32)
    end
    return y
end
function K:DrawPosition(y)
    local id = self.positionId or "keyboard"
    local tabs = {}
    for _, component in ipairs({ "keyboard", "radial" }) do
        local entry = W.Placement.registry[component]
        if entry then
            local item = spec(entry.label, function()
                self.positionId, self.nudging = component, false
                W.Placement.Preview(component); self:Draw()
            end)
            item.tab, item.selected = true, component == id
            tabs[#tabs + 1] = item
        end
    end
    y = self:AddRow(tabs, y, 36)
    y = self:AddRow({ spec(self.nudging and W.L["Stop nudging"] or W.L["Move with D-pad"], function() self.nudging = not self.nudging; self:Draw() end),
        spec(W.L["Reset position"], function() W.Placement.Reset(id); self:Draw() end),
        spec(W.L["Screen anchor"], function() W.Placement.DragStop(id); self:Draw() end) }, y, 36)
    y = self:AddRow({ spec(W.L["Left"], function() W.Placement.Nudge(id, -4, 0) end),
        spec(W.L["Down"], function() W.Placement.Nudge(id, 0, -4) end),
        spec(W.L["Up"], function() W.Placement.Nudge(id, 0, 4) end),
        spec(W.L["Right"], function() W.Placement.Nudge(id, 4, 0) end) }, y, 36)
    y = self:AddRow({ spec(W.L["Save position"], W.Placement.Save, "confirm"), spec(W.L["Cancel"], W.Placement.Leave, "back") }, y, 36)
    return y
end
function K:ShowPosition(id)
    self:Close()
    self.editor = W.Text.New("", {}); self.view = "position"; self.nudging = false; self.positionId = id
    self.selectedRow, self.selectedCol = id == "radial" and 4 or 1, 1
    self.frame:Show(); self:Draw()
end
function K:ReleaseUI()
    if W.Input then W.Input:Release() end
    if W.Links then W.Links:HideTooltip(); W.Links:HideControls() end
    self.linking, self.channels = nil, nil
    self.mouseEditing = nil
    self.frame:StopMovingOrSizing()
    if self.input and self.input:HasFocus() then self.input:ClearFocus() end
end
function K:Hide()
    self.hiding = true
    self.frame:Hide()
    self.hiding = nil
    self:ReleaseUI() -- Also clean up an already-hidden/suspended window.
end
function K:Open(box)
    if W.Combat() or W.OtherKeyboard() then return false end
    if not W.Usable(box) then return false end
    local context, source = W.Contexts.Describe(box), W.Call(box, "GetText")
    if type(source) ~= "string" then return false end
    W.Links:HideTooltip(); self.linking,self.channels,self.quickOwner = nil,nil,nil
    local cursor = W.Call(box, "GetCursorPosition") or #source
    self.session = { target = box, ownerParent = W.Call(box, "GetParent"), context = context,
        ownerContext = W.Copy(context), sourceText = source, appliedCursor = cursor, appliedAnchor = cursor }
    self.editor = W.Text.New(source, context); self.editor:Select(cursor, cursor)
    W.NativeField.Attach(self, box)
    self.view, self.digits, self.shift, self.symbols, self.composing, self.assigning = "keys", false, false, false, nil, false
    self.quickBank = "phrases"
    self.selectedRow, self.selectedCol = self:Numeric() and 3 or 2, 1
    self.frame:Show(); self:Draw(); self:FocusField()
    W.Input:Acquire()
    return true
end
function K:Close(reason)
    if self.session and self.editor and self.session.context.chat then
        W.drafts[W.Contexts.DraftKey(self.session.context)] = (self.composing and self.composing.editor or self.editor).text
    end
    local target = self.session and self.session.target
    self.session, self.composing, self.remapping, self.assigning = nil, nil, nil, false
    self.suspended, self.nudging, self.quickContext, self.quickOwner = nil, nil, nil, nil
    self.editor = nil; self:Hide()
    W.dismissed = target
    if reason then W.Print(reason) end
end
function K:Options()
    if W.Combat() then return end
    W.Options.Open()
end
function K:Action(action)
    if W.Combat() then return end
    if self.session and not W.Contexts.Valid(self.session) then self:Close(W.L["Field changed; draft was not applied."]); return end
    local owner = self:InputOwner()
    if owner and W.Focus() ~= owner then self.suspended = true; self:Hide(); return end
    local e = self.editor
    if not e then return end
    if action == "primary" then if self.focused and self.focused:IsEnabled() and self.focused.run then self.focused.run() end; return end
    if self.linking then if action == "back" then W.Links:Close(self) end; return end
    if self.channels then
        if action == "back" then self:CloseChannels() end
        return
    end
    if action == "back" then
        if self.composing and self.composing.typing then self:CustomMessage(false,true)
        elseif self.composing then self:FinishQuickMessage(false)
        elseif self.assigning then self:ToggleAssign()
        elseif W.Placement.editing then W.Placement.Leave() else self:Close() end
        return
    elseif action == "confirm" then
        if self.composing then
            if self.composing.typing then self:CustomMessage(false); return end
            self:FinishQuickMessage(true); return
        end
        if self.assigning then return end
        if W.Placement.editing then W.Placement.Save(); return end
        if not self.session then self:Close(); return end
        self:Sync()
        local valid, errorText = e:Validate()
        if not valid then self:Status(errorText); return end
        if self.session.context.chat then
            local session = self.session
            self.submitting = true
            local ok, err = W.SendChat(session.target)
            self.submitting = false
            if self.session ~= session then return end -- a command opened another UI
            if not W.Usable(session.target) or (ok and W.Call(session.target, "GetText") == "") then
                self:Close()
                if ok then W.drafts[W.Contexts.DraftKey(session.context)] = "" end
                -- Gamepad/IM chat can clear text without relinquishing focus.
                -- Let native focus-lost handling return control to the game;
                -- never clear another field opened by a command or addon.
                if W.Focus() == session.target and not session.target.chatFrame then W.Call(session.target, "ClearFocus") end
                if not ok then W.Print(err) end
            else
                W.NativeField.Read(self, false, true); self:Draw()
                self:Status(err or W.L["Review native autocomplete, then press Send."])
            end
        else
            local box = self.session.target
            self:Close(); W.Call(box, "ClearFocus")
        end
        return
    elseif action == "delete" then
        local changed = false
        if self.session and not self.composing then local _, didChange = W.NativeField.Insert(self, ""); changed = didChange end
        if not changed then e:Delete() end
    elseif action == "clear" then e:Clear(); self:Status(W.L["Draft cleared · Undo restores it."])
    elseif action == "undo" then e:Undo()
    elseif action == "redo" then e:Undo(true)
    elseif action == "left" then e:Move(-1)
    elseif action == "right" then e:Move(1)
    elseif action == "home" then e:Select(0, 0)
    elseif action == "end" then e:Select(#e.text, #e.text)
    elseif action == "all" then e:Select(0, #e.text)
    elseif action == "copy" then W.clipboard = e.text:sub(math.min(e.anchor, e.cursor) + 1, math.max(e.anchor, e.cursor)); if W.clipboard == "" then W.clipboard = e.text end
    elseif action == "paste" then self:Insert(W.clipboard or "")
    elseif action == "space" then if not self:Numeric() then self:Insert(" ") end
    elseif action == "newline" then if self:Context().multiline or self.composing then self:Insert("\n") else self:Status(W.L["This field is a single line."]) end
    elseif action == "shift" then self.shift = not self.shift; self:Draw()
    elseif action == "symbols" then if not self:Numeric() then self.symbols = not self.symbols; self:Draw() end
    elseif action == "digits" then self.digits = not self.digits; self:Draw()
    elseif action == "library" then self:ToggleAssign()
    elseif action == "previousField" or action == "nextField" then
        if self.session and not self.session.context.chat then
            local nextBox = W.Contexts.Adjacent(self.session.target, action == "nextField" and 1 or -1)
            if nextBox and nextBox ~= self.session.target then
                self:Action("confirm"); W.Call(nextBox, "SetFocus")
            end
        end
    elseif action == "channels" then
        if not self.composing and not self:Context().chat then self:Status(W.L["Channels are available while editing chat."]); return end
        self.channels = {row=self.selectedRow,col=self.selectedCol}
        self:Draw(); return
    end
    self:Sync()
end
function K:CloseChannels()
    local state = self.channels
    self.channels = nil
    self.selectedRow,self.selectedCol = state.row,state.col
    self:Draw()
end
function K:DrawChannels()
    local draft = self.composing
    self.destination:SetText(draft and W.L["Assign message"] or W.L["Channels"]); self.destination:Show()
    self.quickVisible, self.quickBankButtons, self.quickHint = false,nil,nil
    if self.quickDecoration then self.quickDecoration:Hide() end
    local items, y = {},32
    local selected = self:Context()
    if draft then selected = draft.destination end
    local currentRow,currentCol = 1,1
    local function add(label,pin)
        local item = spec(label, function()
            local c = pin and W.Contexts.Destination(pin)
            if pin and not c then self:CloseChannels(); self:Status(W.L["This chat channel is no longer joined."]); return end
            if draft then draft.destination = pin
            else
                local session,box = self.session,self.session.target
                local previous,original = session.context,self.editor.text
                if not W.Contexts.Same(previous,c) then
                    local oldKey,newKey = W.Contexts.DraftKey(previous),W.Contexts.DraftKey(c)
                    session.questDrafts = session.questDrafts or {}
                    session.questDrafts[oldKey] = session.questProgress
                    session.questProgress = session.questDrafts[newKey]
                    session.questDrafts[newKey] = nil
                    self.syncing = true
                    if box.SetChatType then box:SetChatType(c.chatType) else box:SetAttribute("chatType",c.chatType) end
                    if c.channel then
                        if box.SetChannelTarget then box:SetChannelTarget(c.channel) else box:SetAttribute("channelTarget",c.channel) end
                    elseif c.chatType == "WHISPER" or c.chatType == "BN_WHISPER" then
                        if box.SetTellTarget then box:SetTellTarget(c.recipient) else box:SetAttribute("tellTarget",c.recipient) end
                    end
                    W.Call(box,"UpdateHeader")
                    box:SetText(W.drafts[newKey] or "")
                    self.syncing = false
                    W.NativeField.Read(self,false,true)
                    W.drafts[oldKey] = original
                    self.editor.undo,self.editor.redo = {},{}
                end
            end
            self:CloseChannels()
        end)
        item.selected = pin == nil and selected == nil or pin and selected and pin.chatType == selected.chatType
            and pin.recipient == selected.recipient and pin.channelName == selected.channelName
        if item.selected then currentRow,currentCol = #self.rows+1,#items+1 end
        items[#items+1] = item
        if #items == 3 then y = self:AddRow(items, y, 32); items = {} end
    end
    if draft then add(W.L["Current chat"]) end
    for _, c in ipairs(self:QuickContexts()) do
        if c.chat then
            if c.chatType == "WHISPER" or c.chatType == "BN_WHISPER" then
                local current = self:Context()
                if current.chatType == c.chatType and current.recipient and current.recipient ~= "" then
                    add(current.label, {chatType=c.chatType,recipient=current.recipient})
                elseif not draft and c.chatType == "WHISPER" then add(c.label,{chatType=c.chatType}) end
            else add(c.label, {chatType=c.chatType,channelName=c.channelName}) end
        end
    end
    if #items > 0 then y = self:AddRow(items, y, 32) end
    y = self:AddRow({ spec(W.L["Back"], function() self:CloseChannels() end, "back") }, y, 38)
    self:SizeToRows(y); self:Select(currentRow,currentCol)
end
