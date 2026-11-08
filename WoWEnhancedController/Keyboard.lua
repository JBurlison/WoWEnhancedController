local _, W = ...
local K = { rows = {}, pool = {}, generation = 0, view = "keys", selectedRow = 1, selectedCol = 1, slot = 1, scopeIndex = 1 }
W.Keyboard = K
local function spec(text, action, hint, weight) return { text = text, action = action, hint = hint, weight = weight or 1 } end
local scopes = { "context", "chat", "global" }

function K:Status(message) if self.status then self.status:SetText(W.Escape(message)) end end
function K:Context() return self.session and self.session.context or { key = "global", label = "Keyboard", maxBytes = 1024 } end
function K:Numeric() return self.session and self.session.context.numeric and not self.composing end
function K:Scope()
    local selected = scopes[self.scopeIndex]
    return selected == "context" and self:Context().key or selected
end
function K:Init()
    local frame = CreateFrame("Frame", "WoWEnhancedControllerKeyboard", UIParent)
    self.frame = frame; frame:SetSize(660, 440); frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Hide(); frame:EnableMouse(true); W.Theme.Shell(frame)
    self.title = W.Theme.Label(frame, "Enhanced Controller", "GameFontHighlightLarge")
    self.title:SetPoint("TOP", 0, -15)
    self.destination = W.Theme.Label(frame, ""); self.destination:SetPoint("TOPLEFT", 18, -40)
    self.destination:SetWidth(610); self.destination:SetJustifyH("LEFT")
    self.input, self.inputBorder = W.Theme.Input(frame)
    self.inputBorder:SetPoint("TOPLEFT", 16, -60); self.inputBorder:SetSize(628, 54)
    self.input:SetMaxBytes(8192)
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
    self.input:SetScript("OnCursorChanged", function(box)
        if self.editor and not self.syncing then
            local cursor = box:GetCursorPosition()
            self.editor:Select(cursor, cursor)
        end
    end)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 3); close:SetSize(28, 28)
    close:SetScript("OnClick", function() self:Action("back") end)
    self.status = W.Theme.Label(frame, "", "GameFontHighlightSmall")
    self.status:SetPoint("BOTTOMLEFT", 18, 12); self.status:SetWidth(624); self.status:SetJustifyH("LEFT")
    self.status:SetHeight(30)
    frame:SetScript("OnHide", function() if W.Input then W.Input:Release() end end)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if W.Placement.editing and not W.Combat() then frame:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function() W.Placement.DragStop("keyboard") end)
    frame:SetScript("OnMouseDown", function() if W.Input then W.Input:Acquire(true) end end)
    W.Placement.Register("keyboard", frame, "Controller keyboard")
end
function K:Sync()
    if not self.editor then return end
    self.syncing = true
    self.input:SetText(self.editor.text)
    self.input:SetCursorPosition(self.editor.cursor)
    if self.editor.anchor ~= self.editor.cursor then
        self.input:HighlightText(math.min(self.editor.anchor, self.editor.cursor), math.max(self.editor.anchor, self.editor.cursor))
    end
    self.syncing = false
end
function K:Select(row, col)
    if self.focused then self.focused.focus:Hide(); self.focused.hint:SetText(self.focused.baseHint or "") end
    self.selectedRow = W.Clamp(row, 1, #self.rows)
    local controls = self.rows[self.selectedRow]
    if not controls or #controls == 0 then return end
    self.selectedCol = W.Clamp(col, 1, #controls)
    local b = controls[self.selectedCol]
    self.focused = b; b.focus:Show()
    if W.Input then b.hint:SetText(b.baseHint ~= "" and b.baseHint or W.Input:Hint("primary")) end
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
    for index, item in ipairs(items) do
        self.used = self.used + 1
        local button = self.pool[self.used]
        if not button then
            button = W.Theme.Button(self.frame, "", function(b)
                if self.session and not W.Contexts.Valid(self.session) then self:Close("Field changed; draft not applied."); return end
                if b.generation == self.generation and b.run then b.run() end
            end)
            self.pool[self.used] = button
        end
        local width = available * item.weight / total
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", x, -y); button:SetSize(width, height)
        button:SetText(W.Escape(item.text)); button:Show()
        button.row, button.col, button.generation = #self.rows + 1, index, self.generation
        button.baseHint = item.hint and W.Input and W.Input:Hint(item.hint) or ""
        button.hint:SetText(button.baseHint)
        button.run = item.action
        button:Enable(); row[#row + 1] = button; x = x + width + 4
    end
    self.rows[#self.rows + 1] = row
    return y + height + 6
end
function K:Draw()
    self.generation = self.generation + 1
    for _, button in ipairs(self.pool) do button:Hide(); button.focus:Hide() end
    self.rows, self.used, self.focused = {}, 0, nil
    local c = self:Context()
    self.title:SetText(self.composing and "Compose phrase" or W.Placement.editing and "Keyboard · Edit Mode" or "Enhanced Controller")
    self.destination:SetText(W.Escape(c.label .. (self:Numeric() and (" · " .. (c.min or "?") .. " to " .. (c.max or "field maximum")) or "")))
    self.frame:SetScale(W.db.scale * (W.db.largeKeys and 1.15 or 1))
    local y = 122
    if not W.Placement.editing then
        local tabs = {}
        for _, tab in ipairs({ { "keys", "Keyboard" }, { "phrases", "Phrases & bindings" }, { "tools", "Edit tools" }, { "options", "Options" } }) do
            local view = tab[1]
            tabs[#tabs + 1] = spec((self.view == view and "• " or "") .. tab[2], function() self.view = view; self:Draw() end)
        end
        y = self:AddRow(tabs, y, 28)
    end
    if W.Placement.editing then y = self:DrawPosition(y)
    elseif self.view == "keys" then y = self:DrawKeys(y)
    elseif self.view == "phrases" then y = self:DrawPhrases(y)
    elseif self.view == "tools" then y = self:DrawTools(y)
    else y = self:DrawOptions(y) end
    if not W.Placement.editing then
        y = self:AddRow({ spec("Close", function() self:Action("back") end, "back"),
            spec("Delete", function() self:Action("delete") end, self:Numeric() and "shift" or "delete"),
            spec(self:Numeric() and "Digits / amount" or "Shift", function() self:Action(self:Numeric() and "digits" or "shift") end, self:Numeric() and "delete" or "shift"),
            spec(self.composing and "Use phrase" or c.chat and "Send" or "Done", function() self:Action("confirm") end, "confirm") }, y, 34)
    end
    self.frame:SetHeight(y + 43)
    W.Placement.Apply("keyboard")
    self:Select(self.selectedRow, self.selectedCol)
    self:Sync()
end
function K:DrawKeys(y)
    local c, phrases = self:Context(), {}
    local bindings = W.Phrases.Bindings(c)
    for i = 1, 4 do
        local slot, text = i, W.Phrases.Resolve(c, i)
        local hint = W.Input and W.Input:PhraseHint(bindings[i]) or ""
        phrases[#phrases + 1] = spec((hint ~= "" and hint .. "\n" or "") .. text, function() self:InsertPhrase(slot) end)
    end
    y = self:AddRow(phrases, y, 52)
    if self:Numeric() and not self.digits then
        y = self:AddRow({ spec("← −10", function() self.editor:Adjust(-10); self:Sync() end),
            spec("↓ −1", function() self.editor:Adjust(-1); self:Sync() end),
            spec("↑ +1", function() self.editor:Adjust(1); self:Sync() end),
            spec("→ +10", function() self.editor:Adjust(10); self:Sync() end) }, y, 42)
        y = self:AddRow({ spec("Minimum", function() self:SetAmount(c.min or 0) end),
            spec("Maximum", function() if c.max then self:SetAmount(c.max) else self:Status("The native field does not expose a maximum.") end end),
            spec("Type digits", function() self.digits = true; self:Draw() end) }, y, 32)
        self:Status("D-pad: adjust amount · " .. (W.Input and W.Input:Hint("delete") or "") .. " digits · Done fills the field")
        return y
    end
    local rows = self:Numeric() and { "789", "456", "123", "0" } or self.symbols
        and { "1234567890", "!@#$%^&*()", "-_=+/:;?.,", "[]{}'\"\\~`" } or { "qwertyuiop", "asdfghjkl", "zxcvbnm" }
    for _, letters in ipairs(rows) do
        local keys = {}
        for ch in letters:gmatch(".") do
            local char = self.shift and ch:upper() or ch
            keys[#keys + 1] = spec(char, function() self.editor:Replace(char); self.shift = false; self:Draw() end)
        end
        y = self:AddRow(keys, y, 32)
    end
    y = self:AddRow({ spec("Caret ←", function() self:Action("left") end, "left"),
        spec("Space", function() self:Action("space") end, "space"),
        spec("Caret →", function() self:Action("right") end, "right"),
        spec("Symbols", function() self:Action("symbols") end, "symbols"),
        spec("Clear all", function() self:Action("clear") end, "clear"),
        spec("Undo", function() self:Action("undo") end) }, y, 32)
    return y
end
function K:SetAmount(n)
    self.editor:Select(0, #self.editor.text); self.editor:Replace(tostring(n)); self:Sync()
end
function K:InsertPhrase(slot)
    local text = W.Phrases.Resolve(self:Context(), slot)
    self.editor:Replace(text); self:Sync(); self:Status("Phrase inserted. Review before sending.")
end
function K:DrawPhrases(y)
    local scope = self:Scope()
    local text, origin = W.Phrases.Resolve(self:Context(), self.slot)
    self.destination:SetText(W.Escape("Phrase " .. self.slot .. " · " .. origin .. " · " .. text))
    y = self:AddRow({ spec("Previous slot", function() self.slot = (self.slot + 2) % 4 + 1; self:Draw() end),
        spec("Slot " .. self.slot, function() self:InsertPhrase(self.slot) end),
        spec("Next slot", function() self.slot = self.slot % 4 + 1; self:Draw() end) }, y, 32)
    local bindings = W.Phrases.Bindings(self:Context())
    y = self:AddRow({ spec("Scope: " .. scopes[self.scopeIndex], function()
        self.scopeIndex = self.scopeIndex % #scopes + 1
        if not self:Context().chat and self.scopeIndex == 2 then self.scopeIndex = 3 end
        self:Draw()
    end), spec("Shortcut: " .. (bindings[self.slot] or "unbound"), function()
        local choices, nextIndex = { "primary", "back", "delete", "shift", "unbound" }, 1
        for i, a in ipairs(choices) do if a == bindings[self.slot] then nextIndex = i % #choices + 1 end end
        local ok, reason = W.Phrases.Bind(scope, self.slot, choices[nextIndex], self:Context())
        if not ok then self:Status(reason) else self:Draw() end
    end) }, y, 32)
    y = self:AddRow({ spec("Edit phrase", function()
        self.composing = { editor = self.editor, scope = scope, slot = self.slot }
        self.editor = W.Text.New(text, { maxBytes = 1024, maxLetters = 255 })
        self.view = "keys"; self:Draw()
    end), spec("Delete custom", function() W.Phrases.Reset(scope, self.slot); self:Draw(); self:Status("Custom phrase removed; inherited phrase restored.") end),
        spec("Reset shortcuts", function() W.db.bindings[scope] = nil; self:Draw() end) }, y, 34)
    self:Status("Hold phrase modifier + assigned face button to insert. Conflicting shortcuts must be unbound first.")
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
    y = self:AddRow({ spec("Prompts: " .. W.db.style, function() cycle("style", { "Auto", "Xbox", "PlayStation", "Nintendo" }) end),
        spec("Nintendo A confirm: " .. (W.db.swapNintendo and "On" or "Off"), function() W.db.swapNintendo = not W.db.swapNintendo; W.Input:Refresh(); self:Draw() end) }, y, 34)
    y = self:AddRow({ spec("Activation: " .. W.db.activation, function() cycle("activation", { "controller", "always" }) end),
        spec("Large keys: " .. (W.db.largeKeys and "On" or "Off"), function() W.db.largeKeys = not W.db.largeKeys; self:Draw() end) }, y, 34)
    y = self:AddRow({ spec("Smaller", function() W.db.scale = W.Clamp(W.db.scale - 0.05, 0.6, 1.5); self:Draw() end),
        spec("Scale: " .. math.floor(W.db.scale * 100) .. "%", function() W.db.scale = 1; self:Draw() end),
        spec("Larger", function() W.db.scale = W.Clamp(W.db.scale + 0.05, 0.6, 1.5); self:Draw() end) }, y, 34)
    y = self:AddRow({ spec("Position controls", function() W.Placement.Enter(); W.Input:Acquire(true) end),
        spec("Reset action binds", function() W.db.actionBindings = nil; W.Input:Refresh(); self:Draw() end),
        spec("Remap buttons", function() self.remapping = true; self.remapIndex = 1; self:Status("Select an action with shoulders; press a button to assign. Menu finishes.") end) }, y, 34)
    return y
end
function K:DrawPosition(y)
    y = self:AddRow({ spec(self.nudging and "Stop nudging" or "Move with D-pad", function() self.nudging = not self.nudging end),
        spec("Follow chat", function() W.Placement.Reset("keyboard"); self:Draw() end),
        spec("Screen anchor", function() W.Placement.DragStop("keyboard"); self:Draw() end) }, y, 36)
    y = self:AddRow({ spec("←", function() W.Placement.Nudge("keyboard", -4, 0) end),
        spec("↓", function() W.Placement.Nudge("keyboard", 0, -4) end),
        spec("↑", function() W.Placement.Nudge("keyboard", 0, 4) end),
        spec("→", function() W.Placement.Nudge("keyboard", 4, 0) end) }, y, 36)
    y = self:AddRow({ spec("Save position", W.Placement.Save), spec("Cancel", W.Placement.Leave),
        spec("Reset above chat", function() W.Placement.Reset("keyboard") end) }, y, 36)
    self:Status("Drag this panel or select Move with D-pad. Save applies only this addon's current layout position.")
    return y
end
function K:ShowPosition()
    self.editor = W.Text.New("", {}); self.view = "position"; self.nudging = false
    self.frame:Show(); self:Draw()
    -- Native Edit Mode retains focus until this panel is selected/clicked.
    W.Input:Release()
end
function K:Hide()
    self.input:ClearFocus(); self.frame:Hide()
end
function K:Open(box)
    if W.Combat() or W.OtherKeyboard() then return false end
    local context = W.Contexts.Describe(box)
    local source = context.chat and "" or W.Call(box, "GetText")
    if source == nil then return false end
    self.session = { target = box, context = context, ownerContext = W.Copy(context), sourceText = source }
    local initial = context.chat and (W.drafts[context.key] or W.Call(box, "GetText") or "") or source
    self.editor = W.Text.New(initial, context)
    self.view, self.digits, self.shift, self.symbols, self.composing = "keys", false, false, false, nil
    self.selectedRow, self.selectedCol = 3, 1
    -- Ordinary field draft is buffered; native OnTextChanged fires once on Done.
    W.Call(box, "ClearFocus")
    self.frame:Show(); self:Draw(); self.input:SetFocus()
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
    self.editor = self.editor or W.Text.New("", {})
    self.view = "options"; self.frame:Show(); self:Draw(); W.Input:Acquire(true)
end
function K:Action(action)
    if W.Combat() then return end
    if self.session and not W.Contexts.Valid(self.session) then self:Close("Field changed; draft was not applied."); return end
    local e = self.editor
    if not e then return end
    if action == "primary" then if self.focused and self.focused.run then self.focused.run() end; return end
    if action == "back" then
        if self.composing then self.editor = self.composing.editor; self.composing = nil; self.view = "phrases"; self:Draw()
        elseif W.Placement.editing then W.Placement.Leave() else self:Close() end
        return
    elseif action == "confirm" then
        if self.composing then
            local ok, err = W.Phrases.Save(self.composing.scope, self.composing.slot, e.text)
            if not ok then self:Status(err); return end
            self.editor = self.composing.editor; self.composing = nil; self.view = "phrases"; self:Draw(); return
        end
        if W.Placement.editing then W.Placement.Save(); return end
        if not self.session then self:Close(); return end
        local valid, errorText = e:Validate()
        if not valid then self:Status(errorText); return end
        if self.session.context.chat then
            local ok, err = W.SendChat(e.text, self.session.context)
            if ok then e:Clear(); W.drafts[self.session.context.key] = ""; self:Sync(); self:Status("Message submitted to " .. self.session.context.label)
            else self:Status(err) end
        else
            local box = self.session.target
            local ok = pcall(box.SetText, box, e.text)
            if not ok then self:Status("The native field rejected this change."); return end
            self:Close(); W.Call(box, "ClearFocus")
        end
        return
    elseif action == "delete" then e:Delete()
    elseif action == "clear" then e:Clear(); self:Status("Draft cleared · Undo restores it.")
    elseif action == "undo" then e:Undo()
    elseif action == "redo" then e:Undo(true)
    elseif action == "left" then e:Move(-1)
    elseif action == "right" then e:Move(1)
    elseif action == "home" then e:Select(0, 0)
    elseif action == "end" then e:Select(#e.text, #e.text)
    elseif action == "all" then e:Select(0, #e.text)
    elseif action == "copy" then W.clipboard = e.text:sub(math.min(e.anchor, e.cursor) + 1, math.max(e.anchor, e.cursor)); if W.clipboard == "" then W.clipboard = e.text end
    elseif action == "paste" then e:Replace(W.clipboard or "")
    elseif action == "space" then if not self:Numeric() then e:Replace(" ") end
    elseif action == "newline" then if self:Context().multiline or self.composing then e:Replace("\n") else self:Status("This field is a single line.") end
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
    self.rows, self.used = {}, 0
    local items, y = {}, 122
    local function add(kind, label, id, channelName)
        items[#items + 1] = spec(label, function()
            W.drafts[self.session.context.key] = self.editor.text
            local c = { chat = true, chatType = kind, key = "chat:" .. kind, label = label, maxBytes = 255,
                channel = id, channelName = channelName, recipient = self.session.context.recipient, manualChannel = true }
            if id then c.key = "chat:channel:" .. channelName:lower() end
            self.session.context = c; self.session.manualChannel = true
            self.editor = W.Text.New(W.drafts[c.key] or "", c); self:Draw()
        end)
        if #items == 3 then y = self:AddRow(items, y, 32); items = {} end
    end
    for _, pair in ipairs({ {"SAY","Say"}, {"PARTY","Party"}, {"RAID","Raid"}, {"INSTANCE_CHAT","Instance"}, {"GUILD","Guild"}, {"OFFICER","Officer"}, {"YELL","Yell"}, {"RAID_WARNING","Raid warning"}, {"WHISPER","Whisper"}, {"EMOTE","Emote"} }) do add(pair[1], pair[2]) end
    if GetChannelList then
        local list = { GetChannelList() }
        for i = 1, #list, 3 do if type(list[i]) == "number" and type(list[i + 1]) == "string" then add("CHANNEL", list[i + 1], list[i], list[i + 1]) end end
    end
    if #items > 0 then y = self:AddRow(items, y, 32) end
    y = self:AddRow({spec("Back", function() self:Draw() end)}, y, 32)
    self.frame:SetHeight(y + 43); self:Select(1, 1)
end
