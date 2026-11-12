local _, W = ...
local K = { rows = {}, pool = {}, labels = {}, generation = 0, view = "keys", selectedRow = 1, selectedCol = 1, slot = 1, scopeIndex = 1 }
W.Keyboard = K
local function spec(text, action, hint, weight) return { text = text, action = action, hint = hint, weight = weight or 1 } end
local function label(text, weight) return { text = text, label = true, weight = weight or 1 } end
local scopes = { "context", "chat", "global" }
-- Keep the existing control widths, with a shared gutter between the native
-- NineSlice artwork and every view's content.
local CONTENT_WIDTH, WINDOW_GUTTER = 660, 24
local WINDOW_WIDTH = CONTENT_WIDTH + WINDOW_GUTTER * 2

function K:Status(message)
    self.lastStatus = message
    -- Allocate a caption only for actual feedback, never for a repeated native
    -- field/channel name. Skip text synchronization when reporting a write error.
    if self.frame and self.frame:IsShown() then self:Draw(message, true) end
end
function K:Context() return self.session and self.session.context or { key = "global", label = "Keyboard", maxBytes = 1024 } end
function K:Numeric() return self.session and self.session.context.numeric and not self.composing end
function K:Scope()
    local selected = scopes[self.scopeIndex]
    return selected == "context" and self:Context().key or selected
end
function K:Init()
    local frame = CreateFrame("Frame", "WoWEnhancedControllerKeyboard", UIParent)
    self.frame = frame; frame:SetSize(WINDOW_WIDTH, 440 + WINDOW_GUTTER * 2); frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Hide(); frame:EnableMouse(true); W.Theme.Shell(frame)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", WINDOW_GUTTER, -WINDOW_GUTTER)
    content:SetSize(CONTENT_WIDTH, 440)
    self.content = content
    self.destination = W.Theme.Label(content, ""); self.destination:SetPoint("TOPLEFT", 18, -2)
    self.destination:SetSize(610, 24); self.destination:SetJustifyH("LEFT"); self.destination:SetWordWrap(false)
    self.focusButton = W.Theme.Button(frame, "", function() W.FocusBinding() end)
    self.focusButton:SetPoint("CENTER", frame, "BOTTOM", 0, 4); self.focusButton:SetSize(32, 32)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 3); close:SetSize(28, 28)
    close:SetScript("OnClick", function() self:Action("back") end)
    frame:SetScript("OnHide", function() if W.Input then W.Input:Release() end end)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if W.Placement.editing and not W.Combat() then frame:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function() W.Placement.DragStop("keyboard") end)
    frame:SetScript("OnMouseDown", function() if W.Input then W.Input:Acquire(true) end end)
    W.Placement.Register("keyboard", frame, "Controller keyboard")
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
    if not self.editor then return end
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
function K:FocusField()
    local box = self.composing and self.input or self.session and self.session.target
    if not box then return end
    if not W.Call(box, "HasFocus") then
        local syncing = self.syncing
        self.syncing = true
        W.Call(box, "SetFocus")
        if self.editor then
            local e = self.editor
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
    if self.focused then
        self.focused.focus:Hide()
        W.Theme.Prompt(self.focused, self.focused.basePrompt, self.focused.promptMode)
    end
    self.selectedRow = W.Clamp(row, 1, #self.rows)
    local controls = self.rows[self.selectedRow]
    if not controls or #controls == 0 then return end
    self.selectedCol = W.Clamp(col, 1, #controls)
    local b = controls[self.selectedCol]
    self.focused = b; b.focus:Show()
    if W.Input and #b.basePrompt == 0 then W.Theme.Prompt(b, { "primary" }, "corner") end
end
function K:Move(dx, dy)
    if W.Placement.editing and self.nudging then W.Placement.Nudge("keyboard", dx * 4, -dy * 4); return end
    if self:Numeric() and not self.digits and self.view == "keys" then
        self.editor:Adjust(dy == -1 and 1 or dy == 1 and -1 or dx * 10); self:Sync(); return
    end
    local row = ((self.selectedRow - 1 + dy) % #self.rows) + 1
    local col = self.selectedCol + dx
    if dy ~= 0 then
        local oldCount = #(self.rows[self.selectedRow] or {})
        col = math.floor((self.selectedCol - 0.5) / math.max(oldCount, 1) * #self.rows[row]) + 1
    end
    self:Select(row, ((col - 1) % #self.rows[row]) + 1)
end
function K:AddRow(items, y, height)
    local row, total = {}, 0
    for _, item in ipairs(items) do total = total + item.weight end
    local available, x = 624 - (#items - 1) * 4, 18
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
                    if self.session and not W.Contexts.Valid(self.session) then self:Close("Field changed; draft not applied."); return end
                    if self.session and not self.composing and W.Call(self.session.target, "HasFocus") ~= true then
                        if W.Focus() then self.suspended = true; self:Hide(); return end
                        self:FocusField(); W.Input:Acquire(true)
                    end
                    if b.generation == self.generation and b.run then b.run() end
                end)
                button:SetScript("OnMouseDown", function(b)
                    if W.Input and GetTime and GetTime() - (W.Input.padAt or -1) < 0.15 then return end
                    if not self.session or self.composing or not W.Contexts.Valid(self.session) then return end
                    local focus = W.Focus()
                    if focus and focus ~= self.session.target then b.skipClick = true; W.WatchFocus(); return end
                    self.mouseEditing = b; self:FocusField(); W.Input:Acquire(true)
                end)
                button:SetScript("OnMouseUp", function() self.mouseEditing = nil end)
                self.pool[self.used] = button
            end
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", x, -y); button:SetSize(width, height)
            if item.tab then W.Theme.Tab(button, item.selected) else W.Theme.Regular(button) end
            button:SetText(W.Escape(item.text)); button:Show()
            button.row, button.col, button.generation = #self.rows + 1, #row + 1, self.generation
            button.basePrompt = type(item.hint) == "table" and item.hint
                or item.hint and W.Input:Icon(item.hint) and { item.hint } or {}
            button.promptMode = item.phrase and "phrase" or (#button.basePrompt == 0 and "corner" or "inline")
            W.Theme.Prompt(button, button.basePrompt, button.promptMode)
            button.run = item.action
            button:Enable(); row[#row + 1] = button
        end
        x = x + width + 4
    end
    if #row > 0 then self.rows[#self.rows + 1] = row end
    return y + height + 4
end
function K:Draw(message, skipSync)
    self.generation = self.generation + 1
    for _, button in ipairs(self.pool) do button:Hide(); button.focus:Hide() end
    for _, text in ipairs(self.labels) do text:Hide() end
    self.rows, self.used, self.labelsUsed, self.focused = {}, 0, 0, nil
    local c = self:Context()
    self.destination:SetFontObject(W.Theme.Font("GameFontNormal"))
    if self.composing then
        self:EnsureComposer(); self.inputBorder:Show()
        self.input:SetFontObject(W.Theme.Font("GameFontHighlight"))
    elseif self.inputBorder then self.inputBorder:Hide() end
    W.Theme.FocusBadge(self.focusButton)
    local caption = message or (self.composing and ("Edit phrase " .. self.composing.slot))
        or (W.Placement.editing and "Keyboard position")
        or (self.view == "phrases" and "")
        or (self:Numeric() and ((c.min or "?") .. " to " .. (c.max or "field maximum")))
    self.destination:SetText(W.Escape(caption or ""))
    if caption then self.destination:Show() else self.destination:Hide() end
    local y = self.composing and 92 or caption and 32 or 0
    if not W.Placement.editing then
        local tabs = {}
        for _, tab in ipairs({ { "keys", "Keyboard" }, { "phrases", "Phrases & bindings" }, { "tools", "Edit tools" }, { "options", "Options" } }) do
            local view = tab[1]
            local item = spec(tab[2], function() self.view = view; self:Draw() end,
                view == "phrases" and "library" or nil, view == "phrases" and 1.8 or view == "options" and 0.8 or 0.9)
            item.tab, item.selected = true, self.view == view
            tabs[#tabs + 1] = item
        end
        y = self:AddRow(tabs, y, 34)
    end
    if W.Placement.editing then y = self:DrawPosition(y)
    elseif self.view == "keys" then y = self:DrawKeys(y)
    elseif self.view == "phrases" then y = self:DrawPhrases(y)
    elseif self.view == "tools" then y = self:DrawTools(y)
    else y = self:DrawOptions(y) end
    if not W.Placement.editing then
        y = y + 8
        y = self:AddRow({ spec("Close", function() self:Action("back") end, "back"),
            spec("Delete", function() self:Action("delete") end, self:Numeric() and "shift" or "delete"),
            spec(self:Numeric() and (self.digits and "Amount" or "Digits") or "Shift", function() self:Action(self:Numeric() and "digits" or "shift") end, self:Numeric() and "delete" or "shift"),
            spec(self.composing and "Save" or c.chat and "Send" or "Done", function() self:Action("confirm") end, "confirm") }, y, 38)
    end
    if message then self.destination:SetText(W.Escape(message)) end
    self:SizeToRows(y)
    self:Select(self.selectedRow, self.selectedCol)
    if not skipSync then self:Sync() end
end
function K:SizeToRows(y)
    self.content:SetHeight(y + 8)
    local windowHeight = y + 8 + WINDOW_GUTTER * 2
    self.frame:SetHeight(windowHeight)
    local desired = W.db.scale * (W.db.largeKeys and 1.15 or 1)
    local fit = math.min((UIParent:GetWidth() - 32) / WINDOW_WIDTH, (UIParent:GetHeight() - 32) / windowHeight)
    self.frame:SetScale(math.min(desired, fit))
    W.Placement.Apply("keyboard")
end
function K:DrawKeys(y)
    local c, phrases = self:Context(), {}
    local bindings = W.Phrases.Bindings(c)
    for i = 1, 4 do
        local slot, text = i, W.Phrases.Resolve(c, i)
        local item = spec(text, function() self:InsertPhrase(slot) end,
            bindings[i] ~= "unbound" and { "phrases", bindings[i] } or {})
        item.phrase = true
        phrases[#phrases + 1] = item
    end
    y = self:AddRow(phrases, y, 54)
    if self:Numeric() and not self.digits then
        y = self:AddRow({ spec("Left: -10", function() self.editor:Adjust(-10); self:Sync() end),
            spec("Down: -1", function() self.editor:Adjust(-1); self:Sync() end),
            spec("Up: +1", function() self.editor:Adjust(1); self:Sync() end),
            spec("Right: +10", function() self.editor:Adjust(10); self:Sync() end) }, y, 42)
        y = self:AddRow({ spec("Minimum", function() self:SetAmount(c.min or 0) end),
            spec("Maximum", function() if c.max then self:SetAmount(c.max) else self:Status("The native field does not expose a maximum.") end end),
            spec("Type digits", function() self.digits = true; self:Draw() end) }, y, 32)
        return y
    end
    local rows = self:Numeric() and { "789", "456", "123", "0" } or self.symbols
        and { "1234567890", "!@#$%^&*()", "-_=+/:;?.,", "[]{}'\"\\~`" } or { "qwertyuiop", "asdfghjkl", "zxcvbnm" }
    for _, letters in ipairs(rows) do
        local keys = {}
        for ch in letters:gmatch(".") do
            local char = self.shift and ch:upper() or ch
            keys[#keys + 1] = spec(char, function() self:Insert(char); self.shift = false; self:Draw() end)
        end
        y = self:AddRow(keys, y, 36)
    end
    if self:Numeric() then
        return self:AddRow({ spec("Move left", function() self:Action("left") end, "left"),
            spec("Move right", function() self:Action("right") end, "right"),
            spec("Clear all", function() self:Action("clear") end, "clear"),
            spec("Undo", function() self:Action("undo") end) }, y, 38)
    end
    y = self:AddRow({ spec("Left", function() self:Action("left") end, "left", 0.8),
        spec("Space", function() self:Action("space") end, "space", 1.1),
        spec("Right", function() self:Action("right") end, "right"),
        spec("Symbols", function() self:Action("symbols") end, "symbols", 1.2),
        spec("Clear all", function() self:Action("clear") end, "clear", 1.3),
        spec("Undo", function() self:Action("undo") end, nil, 0.9) }, y, 38)
    return y
end
function K:SetAmount(n)
    if self.session and not self.composing and W.Call(self.session.target, "HasFocus") ~= true then return end
    local o = self.editor.options
    n = W.Clamp(n, o.min, o.max)
    if not o.decimal and n % 1 ~= 0 then self:Status("This field accepts whole numbers only."); return end
    local value = tostring(n)
    if W.Text.Limit(value, o.maxBytes, o.maxLetters) ~= value then self:Status("This amount exceeds the field's digit limit."); return end
    self.editor:Select(0, #self.editor.text); self.editor:Replace(value); self:Sync()
end
function K:InsertPhrase(slot)
    local text = W.Phrases.Resolve(self:Context(), slot)
    if self:Numeric() then
        local number = tonumber(text)
        if number then self:SetAmount(number) else self:Status("Choose a numeric phrase for this field.") end
        return
    end
    self:Insert(text); self:Sync(); self:Status("Phrase inserted. Review before sending.")
end
function K:DrawPhrases(y)
    local scope = self:Scope()
    local text, origin = W.Phrases.Resolve(self:Context(), self.slot)
    self.destination:SetText(W.Escape("Phrase " .. self.slot .. " · " .. origin .. " · " .. text))
    y = self:AddRow({ spec("Previous slot", function() self.slot = (self.slot + 2) % 4 + 1; self:Draw() end),
        label("Slot " .. self.slot, 0.6),
        spec("Next slot", function() self.slot = self.slot % 4 + 1; self:Draw() end),
        spec("Insert phrase", function() self:InsertPhrase(self.slot) end) }, y, 32)
    local bindings = W.Phrases.BindingsForScope(scope, self:Context())
    y = self:AddRow({ spec("Scope: " .. scopes[self.scopeIndex], function()
        self.scopeIndex = self.scopeIndex % #scopes + 1
        if not self:Context().chat and self.scopeIndex == 2 then self.scopeIndex = 3 end
        self:Draw()
    end), spec(bindings[self.slot] == "unbound" and "Shortcut: Unbound" or "Shortcut:", function()
        self.bindingPicking = not self.bindingPicking; self:Draw()
    end, bindings[self.slot] ~= "unbound" and { "phrases", bindings[self.slot] } or {}) }, y, 36)
    if self.bindingPicking then
        local choices = {}
        for _, choice in ipairs({ "primary", "back", "delete", "shift", "unbound" }) do
            local action = choice
            choices[#choices + 1] = spec(action == "unbound" and "Unbound" or "Bind", function()
                local ok, reason = W.Phrases.Bind(scope, self.slot, action, self:Context())
                if not ok then self:Status(reason)
                else self.bindingPicking = false; self:Draw() end
            end, action ~= "unbound" and { "phrases", action } or {})
        end
        y = self:AddRow(choices, y, 32)
    end
    y = self:AddRow({ spec("Edit phrase", function()
        self.composing = { editor = self.editor, scope = scope, slot = self.slot }
        self.editor = W.Text.New(text, { maxBytes = 1024, maxLetters = 255 })
        self.view = "keys"; self:Draw(); self:FocusField()
    end), spec("Delete custom", function() W.Phrases.Reset(scope, self.slot); self:Draw(); self:Status("Custom phrase removed; inherited phrase restored.") end),
        spec("Reset shortcuts", function() W.db.bindings[scope] = nil; self:Draw() end) }, y, 34)
    return y
end
function K:DrawTools(y)
    local rows = { { { "Undo", "undo" }, { "Redo", "redo" }, { "Select all", "all" } },
        { { "Copy", "copy" }, { "Paste", "paste" }, { "Clear all", "clear" } },
        { { "Start", "home" }, { "End", "end" }, { "New line", "newline" } },
        { { "Previous field", "previousField" }, { "Next field", "nextField" }, { "Channels", "channels" } } }
    for _, row in ipairs(rows) do
        local items = {}
        for _, a in ipairs(row) do local action = a[2]; items[#items + 1] = spec(a[1], function() self:Action(action) end) end
        y = self:AddRow(items, y, 32)
    end
    return y
end
function K:DrawOptions(y)
    local function cycle(key, values)
        for i, v in ipairs(values) do if W.db[key] == v then W.db[key] = values[i % #values + 1]; break end end
        W.Input:Refresh(); self:Draw()
    end
    y = self:AddRow({ label("Button icons"),
        spec(W.db.style, function() cycle("style", { "Auto", "Xbox", "PlayStation", "Nintendo" }) end),
        label("Nintendo A confirm", 1.4),
        spec(W.db.swapNintendo and "On" or "Off", function() W.db.swapNintendo = not W.db.swapNintendo; W.Input:Refresh(); self:Draw() end, nil, 0.6) }, y, 34)
    y = self:AddRow({ label("Activation"),
        spec(W.db.activation == "controller" and "Controller" or "Always", function() cycle("activation", { "controller", "always" }) end),
        label("Large keys", 1.4),
        spec(W.db.largeKeys and "On" or "Off", function() W.db.largeKeys = not W.db.largeKeys; self:Draw() end, nil, 0.6) }, y, 34)
    y = self:AddRow({ label("Scale: " .. math.floor(W.db.scale * 100) .. "%"),
        spec("Smaller", function() W.db.scale = W.Clamp(W.db.scale - 0.05, 0.6, 1.5); self:Draw() end),
        spec("Larger", function() W.db.scale = W.Clamp(W.db.scale + 0.05, 0.6, 1.5); self:Draw() end),
        spec("Reset scale", function() W.db.scale = 1; self:Draw() end) }, y, 34)
    y = self:AddRow({ label("Text: " .. W.db.fontSize .. " pt"),
        spec("Smaller text", function() W.db.fontSize = W.Clamp(W.db.fontSize - 2, 12, 20); self:Draw() end),
        spec("Larger text", function() W.db.fontSize = W.Clamp(W.db.fontSize + 2, 12, 20); self:Draw() end),
        spec("Reset text", function() W.db.fontSize = 14; self:Draw() end) }, y, 34)
    y = self:AddRow({ spec("Position controls", function() W.Placement.Enter(); W.Input:Acquire(true) end),
        spec("Reset action binds", function() W.db.actionBindings = nil; W.Input:Refresh(); self:Draw() end),
        spec("Remap buttons", function() self.remapping = true; self.remapIndex = 1; self:Status("Remap: LB/RB choose action; press button; View finishes.") end) }, y, 34)
    return y
end
function K:DrawPosition(y)
    y = self:AddRow({ spec(self.nudging and "Stop nudging" or "Move with D-pad", function() self.nudging = not self.nudging end),
        spec("Reset above chat", function() W.Placement.Reset("keyboard"); self:Draw() end),
        spec("Screen anchor", function() W.Placement.DragStop("keyboard"); self:Draw() end) }, y, 36)
    y = self:AddRow({ spec("Left", function() W.Placement.Nudge("keyboard", -4, 0) end),
        spec("Down", function() W.Placement.Nudge("keyboard", 0, -4) end),
        spec("Up", function() W.Placement.Nudge("keyboard", 0, 4) end),
        spec("Right", function() W.Placement.Nudge("keyboard", 4, 0) end) }, y, 36)
    y = self:AddRow({ spec("Save position", W.Placement.Save), spec("Cancel", W.Placement.Leave) }, y, 36)
    return y
end
function K:ShowPosition()
    self.editor = W.Text.New("", {}); self.view = "position"; self.nudging = false
    self.frame:Show(); self:Draw()
    -- Native Edit Mode retains focus until this panel is selected/clicked.
    W.Input:Release()
end
function K:Hide()
    self.mouseEditing = nil
    if self.input and self.input:HasFocus() then self.input:ClearFocus() end
    self.frame:Hide()
end
function K:Open(box)
    if W.Combat() or W.OtherKeyboard() then return false end
    if not W.Usable(box) then return false end
    local context, source = W.Contexts.Describe(box), W.Call(box, "GetText")
    if type(source) ~= "string" then return false end
    local cursor = W.Call(box, "GetCursorPosition") or #source
    self.session = { target = box, ownerParent = W.Call(box, "GetParent"), context = context,
        ownerContext = W.Copy(context), sourceText = source, appliedCursor = cursor, appliedAnchor = cursor }
    self.editor = W.Text.New(source, context); self.editor:Select(cursor, cursor)
    W.NativeField.Attach(self, box)
    self.view, self.digits, self.shift, self.symbols, self.composing = "keys", false, false, false, nil
    self.selectedRow, self.selectedCol = 3, 1
    self.frame:Show(); self:Draw(); self:FocusField()
    W.Input:Acquire()
    return true
end
function K:Close(reason)
    if self.session and self.editor and self.session.context.chat then
        W.drafts[self.session.context.key] = (self.composing and self.composing.editor or self.editor).text
    end
    local target = self.session and self.session.target
    self.session, self.composing, self.remapping = nil, nil, nil
    self.editor = nil; self:Hide()
    W.dismissed = target
    if reason then W.Print(reason) end
end
function K:Options()
    if W.Combat() then return end
    if self.submitting then self:Close() end
    self.editor = self.editor or W.Text.New("", {})
    self.view = "options"; self.frame:Show(); self:Draw(); W.Input:Acquire(true)
end
function K:Action(action)
    if W.Combat() then return end
    if self.session and not W.Contexts.Valid(self.session) then self:Close("Field changed; draft was not applied."); return end
    if self.session and not self.composing and W.Call(self.session.target, "HasFocus") ~= true then self.suspended = true; self:Hide(); return end
    local e = self.editor
    if not e then return end
    if action == "primary" then if self.focused and self.focused.run then self.focused.run() end; return end
    if action == "back" then
        if self.composing then self.editor = self.composing.editor; self.composing = nil; self.view = "phrases"; self:Draw(); self:FocusField()
        elseif W.Placement.editing then W.Placement.Leave() else self:Close() end
        return
    elseif action == "confirm" then
        if self.composing then
            local ok, err = W.Phrases.Save(self.composing.scope, self.composing.slot, e.text)
            if not ok then self:Status(err); return end
            self.editor = self.composing.editor; self.composing = nil; self.view = "phrases"; self:Draw(); self:FocusField(); return
        end
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
                if ok then W.drafts[session.context.key] = "" end
                -- Gamepad/IM chat can clear text without relinquishing focus.
                -- Let native focus-lost handling return control to the game;
                -- never clear another field opened by a command or addon.
                if W.Focus() == session.target then W.Call(session.target, "ClearFocus") end
                if not ok then W.Print(err) end
            else
                W.NativeField.Read(self, false, true); self:Draw()
                self:Status(err or "Review native autocomplete, then press Send.")
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
    elseif action == "clear" then e:Clear(); self:Status("Draft cleared · Undo restores it.")
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
    elseif action == "newline" then if self:Context().multiline or self.composing then self:Insert("\n") else self:Status("This field is a single line.") end
    elseif action == "shift" then self.shift = not self.shift; self:Draw()
    elseif action == "symbols" then if not self:Numeric() then self.symbols = not self.symbols; self:Draw() end
    elseif action == "digits" then self.digits = not self.digits; self:Draw()
    elseif action == "library" then self.view = self.view == "phrases" and "keys" or "phrases"; self:Draw()
    elseif action == "previousField" or action == "nextField" then
        if self.session and not self.session.context.chat then
            local nextBox = W.Contexts.Adjacent(self.session.target, action == "nextField" and 1 or -1)
            if nextBox and nextBox ~= self.session.target then
                self:Action("confirm"); W.Call(nextBox, "SetFocus")
            end
        end
    elseif action == "channels" then self:DrawChannels(); return end
    self:Sync()
end
function K:DrawChannels()
    if not self.session or not self.session.context.chat then self:Status("Channels are available while editing chat."); return end
    self.generation = self.generation + 1
    for _, b in ipairs(self.pool) do b:Hide() end
    for _, text in ipairs(self.labels) do text:Hide() end
    self.rows, self.used, self.labelsUsed = {}, 0, 0
    self.destination:Hide()
    local items, y = {}, 0
    local function add(kind, label, id, channelName)
        items[#items + 1] = spec(label, function()
            W.drafts[self.session.context.key] = self.editor.text
            local box = self.session.target
            self.syncing = true
            if type(box.SetChatType) == "function" then box:SetChatType(kind) else box:SetAttribute("chatType", kind) end
            if id then
                if type(box.SetChannelTarget) == "function" then box:SetChannelTarget(id) else box:SetAttribute("channelTarget", id) end
            end
            W.Call(box, "UpdateHeader")
            local c = W.Contexts.Describe(box)
            box:SetText(W.drafts[c.key] or "")
            self.syncing = false
            W.NativeField.Read(self, false, true)
            self.editor.undo, self.editor.redo = {}, {}
            self:Draw(); self:FocusField()
        end)
        if #items == 3 then y = self:AddRow(items, y, 32); items = {} end
    end
    for _, pair in ipairs({ {"SAY","Say"}, {"PARTY","Party"}, {"RAID","Raid"}, {"INSTANCE_CHAT","Instance"}, {"GUILD","Guild"}, {"OFFICER","Officer"}, {"YELL","Yell"}, {"RAID_WARNING","Raid warning"}, {"WHISPER","Whisper"}, {"EMOTE","Emote"} }) do add(pair[1], pair[2]) end
    if GetChannelList then
        local list = { GetChannelList() }
        for i = 1, #list, 3 do if type(list[i]) == "number" and type(list[i + 1]) == "string" then add("CHANNEL", list[i + 1], list[i], list[i + 1]) end end
    end
    if #items > 0 then y = self:AddRow(items, y, 32) end
    y = self:AddRow({ spec("Back", function() self:Draw() end),
        spec("Close", function() self:Action("back") end, "back") }, y, 38)
    self:SizeToRows(y); self:Select(1, 1)
end
