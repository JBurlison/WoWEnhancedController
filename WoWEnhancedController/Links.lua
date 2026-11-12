local _, W = ...
local L = { sources = { "Bags", "Equipped", "Professions", "Recipes", "Quests" }, visibleRows = 4 }
W.Links = L
local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if not ok or W.Secret(a) or W.Secret(b) or W.Secret(c) or W.Secret(d) or W.Secret(e) or W.Secret(f) then return end
    return a, b, c, d, e, f
end
local function bank() return Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player end
local function itemName(link) return link:match("%[(.-)%]") or W.L["Item"] end
local function guid(kind, bag, slot)
    if not ItemLocation or not C_Item then return end
    local location = kind == "bag" and call(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, slot)
        or kind == "equipped" and call(ItemLocation.CreateFromEquipmentSlot, ItemLocation, slot)
    return location and call(C_Item.GetItemGUID, location)
end
local function profession(index)
    local name, icon, _, _, _, offset = call(GetProfessionInfo, index)
    if type(name) ~= "string" or type(offset) ~= "number" or not bank() then return end
    local slot = offset + 1
    local link = C_SpellBook and (call(C_SpellBook.GetSpellBookItemTradeSkillLink, slot, bank()) or call(C_SpellBook.GetSpellBookItemLink, slot, bank()))
    if type(link) == "string" and link ~= "" then return { kind = "profession", index = index, slot = slot, name = name, icon = icon, link = link } end
end
local function recipeProfession()
    if not ProfessionsFrame or W.Call(ProfessionsFrame, "IsShown") ~= true then return end
    local info = C_TradeSkillUI and call(C_TradeSkillUI.GetBaseProfessionInfo)
    if type(info) ~= "table" or W.Secret(info.professionID) or type(info.professionID) ~= "number" or info.professionID <= 0 then return end
    return info.professionID
end
local function questIndex(id)
    return call(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, id) or call(GetQuestLogIndexByID, id)
end
local function objectives(id, index)
    local result = {}
    local details = call(C_QuestLog and C_QuestLog.GetQuestObjectives, id)
    local count = math.max(call(GetNumQuestLeaderBoards, index) or 0, details and #details or 0)
    for i=1,count do
        local text, _, finished = call(GetQuestLogLeaderBoard, i, index)
        local info = details and details[i]
        if info and not W.Secret(info) and not W.Secret(info.text) and not W.Secret(info.finished) then
            if not text or text == "" then text, finished = info.text, info.finished end
            local have,need=info.numFulfilled,info.numRequired
            if type(text)=="string" and not W.Secret(have) and not W.Secret(need) and type(have)=="number"
                and type(need)=="number" and need>1 and not text:find("%d+%s*/%s*%d+") then
                text=have.."/"..need.." "..text
            end
        end
        if type(text)=="string" and text~="" then
            text = text:gsub("^(.-):%s*(%d+%s*/%s*%d+)%s*$", "%2 %1")
            result[#result+1]={ index=i, text=text, finished=finished }
        end
    end
    return result
end
local function questRows()
    local rows, seen = {}, {}
    local function add(id,index)
        if type(id)~="number" or id<=0 or seen[id] or not index or index<=0 then return end
        local link=call(GetQuestLink,id)
        if type(link)~="string" or link=="" then return end
        seen[id]=true
        local title=itemName(link)
        rows[#rows+1]={kind="quest",id=id,name=title,link=link}
        for _,obj in ipairs(objectives(id,index)) do
            rows[#rows+1]={kind="objective",id=id,objective=obj.index,name=obj.text,title=title,link=link}
        end
    end
    local tracked=call(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID)
    if tracked and tracked>0 then add(tracked,questIndex(tracked)) end
    local log=C_QuestLog
    for i=1,call(log and log.GetNumQuestLogEntries) or 0 do
        local info=call(log.GetInfo,i)
        if info and not W.Secret(info.isHeader) and not info.isHeader and not W.Secret(info.isHidden) and not info.isHidden and not W.Secret(info.questID) then
            add(info.questID,i)
        end
    end
    return rows
end
-- Inventory and trade links already identify the chosen item/recipe. Quest
-- objectives and the tracked shortcut must resolve against the live log.
function L:Message(ref)
    -- Older saved quest titles contain only their native hyperlink.
    local id = ref.id
    if ref.kind ~= "tracked" and ref.kind ~= "objective" and ref.kind ~= "quest" then
        id = ref.kind == "link" and ref.link and tonumber(ref.link:match("|Hquest:(%d+)"))
        if not id then return ref.link end
    end
    if ref.kind=="tracked" then id=call(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID) end
    local index=type(id)=="number" and id>0 and questIndex(id)
    local link=index and index>0 and call(GetQuestLink,id)
    if type(link)~="string" or link=="" then
        if ref.kind == "link" or ref.kind == "quest" then return ref.link end
        return
    end
    local lines = {}
    for _,obj in ipairs(objectives(id,index)) do
        if ref.kind == "objective" and ref.objective == obj.index then return link, { obj.text } end
        if ref.kind ~= "objective" and not obj.finished then lines[#lines + 1] = obj.text end
    end
    if ref.kind ~= "objective" then return link, lines end
end
function L:Assignment(entry)
    if entry.kind=="objective" then
        return {kind="objective",id=entry.id,objective=entry.objective,name=entry.title.." — "..entry.name}
    end
    if entry.kind=="quest" then return {kind="quest",id=entry.id,name=entry.name,link=entry.link} end
    return {kind="link",link=entry.link,name=entry.name}
end
function L:Collect(source)
    local rows = {}
    if source == "Quests" then return questRows()
    elseif source == "Bags" and C_Container then
        local constants = Constants and Constants.InventoryConstants
        local count = constants and constants.NumBagSlots
        if type(count) ~= "number" then return rows end
        count = count + (constants.NumReagentBagSlots or 0)
        for bag = 0, count do
            local slots = call(C_Container.GetContainerNumSlots, bag)
            for slot = 1, type(slots) == "number" and slots or 0 do
                local link = call(C_Container.GetContainerItemLink, bag, slot)
                if type(link) == "string" and link ~= "" then
                    local info = call(C_Container.GetContainerItemInfo, bag, slot)
                    rows[#rows + 1] = { kind = "bag", bag = bag, slot = slot, link = link, name = itemName(link),
                        icon = info and not W.Secret(info.iconFileID) and info.iconFileID or nil,
                        count = info and not W.Secret(info.stackCount) and info.stackCount or nil, guid = guid("bag", bag, slot) }
                end
            end
        end
    elseif source == "Equipped" and type(INVSLOT_FIRST_EQUIPPED) == "number" and type(INVSLOT_LAST_EQUIPPED) == "number" then
        for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
            local link = call(GetInventoryItemLink, "player", slot)
            if type(link) == "string" and link ~= "" then
                rows[#rows + 1] = { kind = "equipped", slot = slot, link = link, name = itemName(link),
                    icon = call(GetInventoryItemTexture, "player", slot), guid = guid("equipped", nil, slot) }
            end
        end
    elseif source == "Professions" and type(GetProfessions) == "function" then
        -- GetProfessions has seven nullable return positions; ipairs would skip
        -- a secondary profession after an empty primary position.
        local ok, p1, p2, p3, p4, p5, p6, p7 = pcall(GetProfessions)
        if ok then
            local indices = { p1, p2, p3, p4, p5, p6, p7 }
            for i = 1, 7 do
                local index = indices[i]
                if not W.Secret(index) and type(index) == "number" then local entry = profession(index); if entry then rows[#rows + 1] = entry end end
            end
        end
    elseif source == "Recipes" and C_TradeSkillUI then
        local owner = recipeProfession()
        local ids = owner and call(C_TradeSkillUI.GetAllRecipeIDs)
        if type(ids) == "table" then for _, id in ipairs(ids) do
            if not W.Secret(id) then
                local info = call(C_TradeSkillUI.GetRecipeInfo, id)
                local link = call(C_TradeSkillUI.GetRecipeLink, id)
                if type(info) == "table" and not W.Secret(info.learned) and info.learned and not W.Secret(info.name)
                    and type(info.name) == "string" and type(link) == "string" and link ~= "" then
                    rows[#rows + 1] = { kind = "recipe", id = id, profession = owner, name = info.name, link = link,
                        icon = not W.Secret(info.icon) and info.icon or nil }
                end
            end
        end end
    end
    return rows
end
function L:Current(entry)
    if entry.kind=="objective" then return self:Message(entry)~=nil end
    if entry.kind=="quest" then
        local index=questIndex(entry.id)
        return index and index>0 and call(GetQuestLink,entry.id)==entry.link
    elseif entry.kind == "bag" then
        if call(C_Container.GetContainerItemLink, entry.bag, entry.slot) ~= entry.link then return false end
        return not entry.guid or guid("bag", entry.bag, entry.slot) == entry.guid
    elseif entry.kind == "equipped" then
        if call(GetInventoryItemLink, "player", entry.slot) ~= entry.link then return false end
        return not entry.guid or guid("equipped", nil, entry.slot) == entry.guid
    elseif entry.kind == "profession" then
        local current = profession(entry.index)
        return current and current.slot == entry.slot and current.link == entry.link
    elseif entry.kind == "recipe" and C_TradeSkillUI and recipeProfession() == entry.profession then
        local info = call(C_TradeSkillUI.GetRecipeInfo, entry.id)
        return info and not W.Secret(info.learned) and info.learned and call(C_TradeSkillUI.GetRecipeLink, entry.id) == entry.link
    end
    return false
end
function L:HideTooltip()
    if self.tooltipOwner and GameTooltip and W.Call(GameTooltip, "GetOwner") == self.tooltipOwner then GameTooltip:Hide() end
    self.tooltipOwner = nil
end
function L:Eligible(k)
    if k.linking and k.linking.draft then
        return k.composing==k.linking.draft and k.session==k.linking.session and (not k.session or W.Contexts.Valid(k.session))
            and W.Focus()==k:InputOwner() and k.frame:IsShown() and not W.Combat()
    end
    return k.linking and k.session == k.linking.session and W.Contexts.Valid(k.session) and k.session.context.chat
        and W.Call(k.session.target, "HasFocus") == true and not W.Combat() and k.frame:IsShown()
end
function L:Tooltip(k, button)
    self:HideTooltip()
    local entry = button and button.linkEntry
    if not self:Eligible(k) or not entry or not self:Current(entry) or not GameTooltip then return end
    GameTooltip:SetOwner(button, "ANCHOR_NONE")
    self.tooltipOwner = button
    GameTooltip:ClearAllPoints(); GameTooltip:SetPoint("TOPLEFT", k.content, "TOPLEFT", 372, -48)
    local ok
    if entry.kind == "bag" then ok = pcall(GameTooltip.SetBagItem, GameTooltip, entry.bag, entry.slot)
    elseif entry.kind == "equipped" then ok = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", entry.slot)
    elseif entry.kind == "profession" then ok = pcall(GameTooltip.SetSpellBookItem, GameTooltip, entry.slot, bank())
    else ok = pcall(GameTooltip.SetHyperlink, GameTooltip, entry.link) end
    if ok then GameTooltip:Show() else self:HideTooltip() end
end
function L:Open(k, forAssignment)
    if W.Combat() then return end
    if forAssignment then
        if not k.composing or W.Focus()~=k:InputOwner() or (k.session and not W.Contexts.Valid(k.session)) then return end
    elseif not k.session or not k.session.context.chat or k.composing or k.assigning or not W.Contexts.Valid(k.session)
        or W.Call(k.session.target, "HasFocus") ~= true then return end
    k:Sync()
    k.linking = { session = k.session, draft = forAssignment and k.composing, text = k.editor.text, cursor = k.editor.cursor, anchor = k.editor.anchor,
        source = 1, offset = 0, index = 1, row = k.selectedRow, col = k.selectedCol, view = k.view }
    k.selectedRow, k.selectedCol = 2, 1
    W.Input:ResetHeld(); k:Draw()
end
function L:Close(k)
    local state = k.linking
    self:HideTooltip(); self:HideControls(); k.linking = nil
    if state then k.view, k.selectedRow, k.selectedCol = state.view, state.row, state.col end
    W.Input:ResetHeld(); k:Draw(); k:FocusField()
end
function L:Insert(k, entry)
    if not self:Eligible(k) then self:HideTooltip(); return end
    local state = k.linking
    if state.mouseGeneration and (state.mouseGeneration ~= k.generation or state.mouseEntry ~= entry) then
        state.mouseGeneration, state.mouseEntry = nil, nil
        k:Status(W.L["That link changed. Choose it again."]); return
    end
    state.mouseGeneration, state.mouseEntry = nil, nil
    if not self:Current(entry) then state.dirty = true; k:Status(W.L["That link changed. Choose it again."]); return end
    if state.draft then
        self:Close(k); k:SetQuickLink(self:Assignment(entry)); return
    end
    if k.editor.text ~= state.text or k.editor.cursor ~= state.cursor or k.editor.anchor ~= state.anchor then
        self:Close(k); k:Status(W.L["Chat changed. Open the link list again."]); return
    end
    local message=self:Message(entry)
    if not message then k:Status(W.L["That link changed. Choose it again."]); return end
    local ok, changed = W.NativeField.Insert(k, message)
    if not ok or not changed then k:Status(W.L["The chat field could not insert this link."]); return end
    if entry.kind == "quest" or entry.kind == "objective" then
        W.AttachQuestProgress(k.session, message, self:Assignment(entry))
    end
    self:Close(k)
end
function L:Draw(k, message)
    local state = k.linking
    local function button(text, action, hint, weight) return { text = text, action = action, hint = hint, weight = weight or 1 } end
    self:HideTooltip(); k.quickVisible = false; k.quickBankButtons = nil
    if k.quickDecoration then k.quickDecoration:Hide() end
    if k.inputBorder then k.inputBorder:Hide() end
    k.destination:Hide(); W.Theme.FocusBadge(k.focusButton)
    local entries = self:Collect(self.sources[state.source]); state.entries, state.dirty = entries, nil
    state.offset = W.Clamp(state.offset or 0, 0, math.max(0, #entries - self.visibleRows))
    state.index = W.Clamp(state.index or 1, 1, math.max(1, #entries))
    local y = k:AddRow({ { text = W.L["Link in chat"], label = true, weight = 1 },
        button(W.L.Format("Show: %s", W.L[self.sources[state.source]]), function()
            state.source = state.source % #self.sources + 1; state.offset, state.index = 0, 1
            k.selectedRow, k.selectedCol = 1, 1; k:Draw()
        end) }, 0, 38, 0, 660)
    local height = math.max(44, W.db.fontSize * 2 + 10)
    for index = state.offset + 1, math.min(#entries, state.offset + self.visibleRows) do
        local entry = entries[index]
        y = k:AddRow({ button(entry.name, function() self:Insert(k, entry) end) }, y, height, 0, 346)
        local b = k.rows[#k.rows][1]; b.linkEntry, b.linkIndex = entry, index
        b:ClearNormalTexture(); b:ClearPushedTexture()
        W.Theme.ButtonFonts(b, "GameFontHighlight")
        if not b.linkIcon then
            b.linkIcon = b:CreateTexture(nil, "OVERLAY"); b.linkIcon:SetPoint("LEFT", 8, 0); b.linkIcon:SetSize(32, 32)
            b.linkCount = W.Theme.Label(b); b.linkCount:SetPoint("RIGHT", -8, 0); b.linkCount:SetSize(42, 32); b.linkCount:SetJustifyH("RIGHT")
            b:HookScript("OnLeave", function() if self.tooltipOwner == b then self:HideTooltip() end end)
            b:HookScript("OnHide", function() if self.tooltipOwner == b then self:HideTooltip() end end)
            b:HookScript("OnMouseDown", function()
                if k.linking and b.linkEntry then k.linking.mouseGeneration, k.linking.mouseEntry = k.generation, b.linkEntry end
            end)
        end
        if entry.kind=="quest" then b.linkIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon"); b.linkIcon:Show()
        elseif entry.icon then b.linkIcon:SetTexture(entry.icon); b.linkIcon:Show() else b.linkIcon:Hide() end
        b.linkCount:SetFontObject(W.Theme.Font("GameFontNormal")); b.linkCount:SetText(type(entry.count) == "number" and entry.count > 1 and tostring(entry.count) or ""); b.linkCount:Show()
        self:RowPrompt(b, false)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(_, delta) self:Scroll(k, state.offset - delta) end)
    end
    if #entries == 0 then
        local text = self.sources[state.source] == "Recipes" and W.L["Open a profession to list its learned recipes."] or W.L["No linkable entries available."]
        y = k:AddRow({ { text = text, label = true, weight = 1 } }, y, height * 2, 0, 660)
    end
    y = math.max(y, 42 + (height + 4) * self.visibleRows)
    self:SyncScrollBar(k, height, #entries)
    y = k:AddRow({ button(W.L["Back"], function() self:Close(k) end, "back"),
        { text = message or (state.draft and W.L["Select a link for this shortcut."] or W.L["Highlight to inspect · Select to insert"]), label = true, weight = 3 } }, y + 8, math.max(38, W.db.fontSize * 2 + 8), 0, 660)
    k:SizeToRows(y); k:Select(k.selectedRow, k.selectedCol)
end
function L:RowPrompt(b, selected)
    b.linkCount:ClearAllPoints()
    if selected then
        b.linkCount:SetPoint("TOPRIGHT", -8, -1); b.linkCount:SetHeight(math.max(20, W.db.fontSize + 4))
    else b.linkCount:SetPoint("RIGHT", -8, 0); b.linkCount:SetHeight(32) end
    local text = b:GetFontString()
    text:ClearAllPoints(); text:SetPoint("LEFT", 48, 0); text:SetPoint("RIGHT", -54, 0); text:SetJustifyH("LEFT")
    text:SetHeight(math.max(30, W.db.fontSize * 2 + 2)); text:SetWordWrap(true)
    if selected then W.Theme.Prompt(b, { "primary" }, "corner"); text:ClearAllPoints(); text:SetPoint("LEFT", 48, 0); text:SetPoint("RIGHT", -54, 0); text:SetJustifyH("LEFT") end
end
function L:Move(k, dx, dy)
    local state, focused = k.linking, k.focused
    if focused and focused.linkIndex then
        local index = focused.linkIndex + (dx + dy > 0 and 1 or -1)
        if index >= 1 and index <= #state.entries then
            state.index = index
            if index <= state.offset then state.offset = index - 1; k.selectedRow = 2; k:Draw()
            elseif index > state.offset + self.visibleRows then state.offset = index - self.visibleRows; k.selectedRow = self.visibleRows + 1; k:Draw()
            else k:Select(index - state.offset + 1, 1) end
            return
        end
    end
    local controls, at = {}, 1
    for r, row in ipairs(k.rows) do for c, b in ipairs(row) do
        if b:IsEnabled() then
            controls[#controls + 1] = { r, c }
            if b == k.focused then at = #controls end
        end
    end end
    if #controls > 0 then k:Select(unpack(controls[(at - 1 + (dx + dy > 0 and 1 or -1)) % #controls + 1])) end
end
function L:PointerFocus(k, surface, held)
    if not k.linking or (k.session and not W.Contexts.Valid(k.session)) or W.Combat() then return end
    local focus = W.Focus()
    local owner=k:InputOwner()
    if not owner or (focus and focus~=owner) then return end
    if held then k.mouseEditing = surface end
    k:FocusField()
end
function L:Scroll(k, offset)
    if not self:Eligible(k) then return end
    local state = k.linking
    offset = math.floor(W.Clamp(offset, 0, math.max(0, #state.entries - self.visibleRows)) + .5)
    if offset == state.offset then return end
    state.offset = offset
    state.index = W.Clamp(state.index, offset + 1, math.min(#state.entries, offset + self.visibleRows))
    k.selectedRow, k.selectedCol = state.index - offset + 1, 1
    k:Draw()
end
function L:SyncScrollBar(k, height, count)
    if not self.scrollBar then
        local bar = CreateFrame("EventFrame", nil, k.content, "MinimalScrollBar")
        self.scrollBar = bar
        bar:Init(1, 1)
        bar:RegisterCallback(ScrollBarMixin.Event.OnScroll, function(_, percentage)
            if self.scrollSync or not k.linking then return end
            self:PointerFocus(k, bar)
            if not self:Eligible(k) then return end
            self.nativeScrolling = true
            self:Scroll(k, percentage * math.max(0, #k.linking.entries - self.visibleRows))
            self.nativeScrolling = nil
        end, self)
        for _, part in ipairs({ bar.Back, bar.Forward, bar.Track, bar.Track.Thumb }) do
            part:HookScript("OnMouseDown", function() self:PointerFocus(k, part, true) end)
            part:HookScript("OnMouseUp", function() k.mouseEditing = nil end)
        end
        k.content:EnableMouseWheel(true)
        k.content:SetScript("OnMouseWheel", function(_, delta)
            if self:Eligible(k) then self:Scroll(k, k.linking.offset - delta) end
        end)
    end
    local bar, maximum = self.scrollBar, math.max(0, count - self.visibleRows)
    bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", k.content, "TOPLEFT", 354, -42)
    bar:SetHeight((height + 4) * self.visibleRows - 4)
    self.scrollSync = true
    bar:SetVisibleExtentPercentage(count > 0 and math.min(1, self.visibleRows / count) or 1)
    bar:SetPanExtentPercentage(maximum > 0 and 1 / maximum or 1)
    if not self.nativeScrolling then bar:SetScrollPercentage(maximum > 0 and k.linking.offset / maximum or 0, true) end
    self.scrollSync = nil
    bar:SetShown(maximum > 0)
end
function L:HideControls()
    if self.scrollBar then self.scrollBar:UnregisterUpdate(); self.scrollBar:Hide() end
end
function L:Tick(k)
    if not k.linking then return end
    if not self:Eligible(k) then self:HideTooltip(); return end
    if k.linking.dirty then k:Draw()
    elseif self.tooltipOwner and self.tooltipOwner == k.focused and W.Call(GameTooltip, "GetOwner") == self.tooltipOwner then self:Tooltip(k, k.focused) end
end
function L:OnEvent(event)
    local k = W.Keyboard
    if k.linking and self.sources[k.linking.source]=="Quests" and
        (event=="QUEST_LOG_UPDATE" or event=="QUEST_WATCH_UPDATE" or event=="SUPER_TRACKING_CHANGED") then
        k.linking.dirty=true; self:HideTooltip()
    end
    if k.linking and (event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "SPELLS_CHANGED"
        or event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_CLOSE") then
        k.linking.dirty = true; self:HideTooltip()
    end
end
