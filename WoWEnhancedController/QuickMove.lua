local _, W = ...
local Q = { revision = 0 }
W.QuickMove = Q

local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if not ok or W.Secret(a) or W.Secret(b) or W.Secret(c) or W.Secret(d) or W.Secret(e) or W.Secret(f) then return end
    return a, b, c, d, e, f
end
local function visible(frame) return W.Call(frame, "IsVisible") == true end
local function within(frame, owner)
    if not owner then return false end
    for _ = 1, 12 do
        if not frame then return false end
        if frame == owner then return true end
        frame = W.Call(frame, "GetParent")
    end
    return false
end
local function same(a, b)
    if not a or not b then return false end
    for _, key in ipairs({ "button", "owner", "kind", "bag", "slot", "guid", "link", "count", "mail", "cod", "bankType", "revision" }) do
        if a[key] ~= b[key] then return false end
    end
    return true
end

function Q:Owner()
    local bank = self.bankOpen and visible(BankFrame)
    local mail = self.mailOpen and visible(MailFrame)
    -- Never let another service change the meaning of UseContainerItem.
    if bank and mail then return end
    return bank and BankFrame or mail and MailFrame or nil
end
function Q:Available()
    return W.db and W.db.enabled and W.db.quickMove and not W.Combat() and self:Owner()
        and not (W.Blocker and W.Blocker()) and not W.Focus()
        and not (W.Keyboard.frame and W.Keyboard.frame:IsShown())
        and not (W.Radial.frame and W.Radial.frame:IsShown())
        and not call(GetCursorInfo) and call(SpellIsTargeting) ~= true
        and not visible(MerchantFrame) and not visible(TradeFrame)
        and not visible(AuctionHouseFrame) and not visible(AuctionFrame)
        and not (self:Owner() == MailFrame and self.mailLocked)
end

function Q:Describe(button)
    if not self:Available() or not visible(button) or W.Call(button, "IsForbidden") == true
        or W.Call(button, "IsEnabled") == false then return end
    local owner = self:Owner()
    local entry = { button = button, owner = owner, revision = self.revision }
    local slot = W.Call(button, "GetID")
    if owner == MailFrame then
        for _, candidate in ipairs(OpenMailFrame and OpenMailFrame.OpenMailAttachments or {}) do
            if candidate == button and visible(OpenMailFrame) then
                entry.kind, entry.mail, entry.slot = "inbox", InboxFrame and InboxFrame.openMailID, slot
                if W.Secret(entry.mail) or type(entry.mail) ~= "number" or entry.mail < 1 then return end
                entry.link = call(GetInboxItemLink, entry.mail, slot)
                local _, _, icon, count = call(GetInboxItem, entry.mail, slot)
                local _, _, _, _, _, cod = call(GetInboxHeaderInfo, entry.mail)
                entry.icon, entry.count, entry.cod = icon, count, cod
                entry.label = "Move to bags"
                if type(entry.link) == "string" and type(count) == "number" and type(OpenMailAttachment_OnClick) == "function" then return entry end
                return
            end
        end
        for _, candidate in ipairs(SendMailFrame and SendMailFrame.SendMailAttachments or {}) do
            if candidate == button and visible(SendMailFrame) then
                entry.kind, entry.slot = "outgoing", slot
                entry.link = call(GetSendMailItemLink, slot)
                local _, _, icon, count = call(GetSendMailItem, slot)
                entry.icon, entry.count, entry.label = icon, count, "Move to bags"
                if type(entry.link) == "string" and type(count) == "number" and type(ClickSendMailItemButton) == "function" then return entry end
                return
            end
        end
    end
    if not C_Container or type(C_Container.UseContainerItem) ~= "function" then return end
    local bankItem = owner == BankFrame and within(button, BankFrame)
        and type(button.GetBankTabID) == "function" and type(button.GetContainerSlotID) == "function"
    if bankItem then
        entry.bag, entry.slot = W.Call(button, "GetBankTabID"), W.Call(button, "GetContainerSlotID")
    elseif not W.Secret(button.buttonContext) and button.buttonContext == "ButtonContext_ContainerFrameItemButton" then
        entry.bag, entry.slot = W.Call(button, "GetBagID"), slot
        local constants = Constants and Constants.InventoryConstants
        local maxBag = constants and constants.NumBagSlots
        if type(maxBag) ~= "number" or type(entry.bag) ~= "number" or entry.bag < 0
            or entry.bag > maxBag + (constants.NumReagentBagSlots or 0) then return end
    else return end
    if type(entry.bag) ~= "number" or type(entry.slot) ~= "number" or entry.slot < 1 then return end
    local info = call(C_Container.GetContainerItemInfo, entry.bag, entry.slot)
    if not info or W.Secret(info.isLocked) or info.isLocked or W.Secret(info.hyperlink)
        or W.Secret(info.stackCount) or W.Secret(info.iconFileID) then return end
    entry.link, entry.count, entry.icon = info.hyperlink, info.stackCount, info.iconFileID
    local location = ItemLocation and call(ItemLocation.CreateFromBagAndSlot, ItemLocation, entry.bag, entry.slot)
    entry.guid = location and C_Item and call(C_Item.GetItemGUID, location)
    if type(entry.guid) ~= "string" or type(entry.link) ~= "string" or type(entry.count) ~= "number" then return end
    entry.kind = bankItem and "withdraw" or owner == BankFrame and "deposit" or "attach"
    entry.label = bankItem and "Move to bags" or owner == BankFrame and "Move to bank" or "Attach to mail"
    if owner == BankFrame then
        entry.bankType = W.Call(BankFrame, "GetActiveBankType")
        if entry.bankType == nil or not C_Bank or call(C_Bank.CanUseBank, entry.bankType) ~= true then return end
    elseif type(MailFrameTab_OnClick) ~= "function" then return end
    return entry
end

function Q:Current()
    local button
    if W.ControllerMode() then
        button = W.Call(SmartNavigation, "GetCurrentButton")
        if button == self.button then return self.selected and self:Describe(self.selected.button) end
        return self:Describe(button)
    end
    local foci = call(GetMouseFoci)
    if type(foci) == "table" then
        for _, focus in ipairs(foci) do
            local entry = self:Describe(focus)
            if entry then return entry end
        end
    else
        local entry = self:Describe(W.Call(GameTooltip, "GetOwner"))
        if entry then return entry end
    end
    -- Retain the explicitly highlighted mouse item while moving to the button.
    -- The button's icon/tooltip identifies it; every activation revalidates it.
    if self.selected then
        local entry = self:Describe(self.selected.button)
        if same(entry, self.selected) then return entry end
    end
end

function Q:Clear()
    self.selected, self.held = nil, nil
    if self.button and W.Call(GameTooltip, "IsOwned", self.button) then GameTooltip:Hide() end
    if self.button then self.button:Hide() end
end
function Q:Activate(entry)
    if not same(entry, self:Describe(entry and entry.button)) then return false end
    if entry.kind == "inbox" then
        -- This native helper keeps the client's COD alert/confirmation flow.
        OpenMailAttachment_OnClick(entry.button, entry.slot)
    elseif entry.kind == "outgoing" then
        ClickSendMailItemButton(entry.slot, true)
    elseif entry.kind == "attach" then
        if not visible(SendMailFrame) then
            MailFrameTab_OnClick(nil, 2)
            -- Native OnShow focuses the recipient. This action began with no
            -- text focus; release only that automatic focus before rechecking.
            if W.Focus() == SendMailNameEditBox then W.Call(SendMailNameEditBox, "ClearFocus") end
        end
        if not visible(SendMailFrame) or not same(entry, self:Describe(entry.button)) then return false end
        C_Container.UseContainerItem(entry.bag, entry.slot)
    elseif entry.kind == "deposit" then
        local location = ItemLocation:CreateFromBagAndSlot(entry.bag, entry.slot)
        if call(BankUtil_IsAccountBankDepositRefundable, location) then
            if not StaticPopup_Show or not Item then return false end
            StaticPopup_Show("ACCOUNT_BANK_DEPOSIT_NO_REFUND_CONFIRM", nil, nil,
                { itemToDeposit = Item:CreateFromItemGUID(entry.guid), targetItemLocation = nil })
        else
            C_Container.UseContainerItem(entry.bag, entry.slot, nil, entry.bankType, false)
        end
    else
        C_Container.UseContainerItem(entry.bag, entry.slot)
    end
    self.revision = self.revision + 1
    self:Clear()
    return true
end
function Q:Press(down, origin)
    if down then
        if self.held then return end -- Ignore key repeat and overlapping presses.
        local entry = self:Current()
        if entry then self.held = { entry = entry, origin = origin, controller = W.ControllerMode() } end
        return
    end
    local held = self.held
    self.held = nil
    if not held or held.origin ~= origin or held.controller ~= W.ControllerMode()
        or not same(held.entry, self:Current()) then return false end
    return self:Activate(held.entry)
end
function Q:Binding(state)
    return self:Press(state == "down", "binding")
end

function Q:Refresh()
    if not self.button then return end
    if not self:Available() then self:Clear(); return end
    local entry = self:Current()
    self.selected = entry
    if not entry then self.button:Hide(); return end
    local button = self.button
    if button:GetParent() ~= entry.owner then button:SetParent(entry.owner) end
    button:ClearAllPoints()
    button:SetPoint("TOP", entry.owner, "BOTTOM", 0, -52)
    W.Theme.ButtonFonts(button)
    button:SetText(W.L[entry.label])
    local label = button:GetFontString()
    local width = W.Call(label, "GetStringWidth") or 180
    button:SetSize(math.max(210, width + 60), math.max(30, W.db.fontSize + 14))
    button.itemIcon:SetTexture(entry.icon)
    local key, secondary = call(GetBindingKey, "WEC_QUICK_MOVE")
    if W.ControllerMode() and type(secondary) == "string" and secondary:find("PAD", 1, true)
        and (type(key) ~= "string" or not key:find("PAD", 1, true)) then key = secondary end
    local atlas = W.ControllerMode() and W.Input:TokenIcon(key)
    button.hint:SetShown(atlas ~= nil and atlas ~= false)
    if atlas then button.hint:SetAtlas(atlas) end
    button.keyLabel:SetText(key and not atlas and (call(GetBindingText, key, "KEY_") or key) or "")
    button:Show()
end
function Q:OnEvent(event)
    if event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        -- Keep the displayed item when the user reaches for its mouse button.
        -- A press started in another input mode must still be cancelled.
        self.held = nil
        self:Refresh()
        return
    end
    self.revision = self.revision + 1
    self:Clear()
    if event == "BANKFRAME_OPENED" then self.bankOpen = true
    elseif event == "BANKFRAME_CLOSED" then self.bankOpen = false
    elseif event == "MAIL_SHOW" then self.mailOpen, self.mailLocked = true, false
    elseif event == "MAIL_CLOSED" then self.mailOpen, self.mailLocked = false, false
    elseif event == "MAIL_LOCK_SEND_ITEMS" then self.mailLocked = true
    elseif event == "MAIL_UNLOCK_SEND_ITEMS" then self.mailLocked = false
    elseif event == "PLAYER_LEAVING_WORLD" then self.bankOpen, self.mailOpen = false, false end
    self.driver:SetShown(self.bankOpen or self.mailOpen or false)
end
function Q:Init()
    self.bankOpen, self.mailOpen = visible(BankFrame), visible(MailFrame)
    local button = CreateFrame("Button", "WoWEnhancedControllerQuickMove", UIParent, "UIPanelButtonTemplate")
    self.button = button
    button:Hide(); button:SetClampedToScreen(true)
    button.itemIcon = button:CreateTexture(nil, "ARTWORK")
    button.itemIcon:SetSize(22, 22); button.itemIcon:SetPoint("LEFT", button, "LEFT", 6, 0)
    button.hint = button:CreateTexture(nil, "OVERLAY")
    button.hint:SetSize(26, 26); button.hint:SetPoint("RIGHT", button, "LEFT", -4, 0)
    button.keyLabel = W.Theme.Label(button, "", "GameFontHighlightSmall")
    button.keyLabel:SetPoint("RIGHT", button, "LEFT", -6, 0)
    button:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    button:SetScript("OnClick", function(_, _, down) self:Press(down, "button") end)
    button:SetScript("OnHide", function() self.held = nil end)
    button:HookScript("OnEnter", function()
        local entry = self.selected
        if not entry or not same(entry, self:Describe(entry.button)) or not GameTooltip then return end
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        if entry.kind == "inbox" then GameTooltip:SetInboxItem(entry.mail, entry.slot)
        elseif entry.kind == "outgoing" then GameTooltip:SetSendMailItem(entry.slot)
        else GameTooltip:SetBagItem(entry.bag, entry.slot) end
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function()
        if W.Call(GameTooltip, "IsOwned", button) then GameTooltip:Hide() end
    end)
    local driver = CreateFrame("Frame")
    self.driver = driver
    driver:SetScript("OnEvent", function(_, event) self:OnEvent(event) end)
    local elapsed = 0
    driver:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.1 then elapsed = 0; self:Refresh() end
    end)
    for _, event in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE",
        "MAIL_SEND_INFO_UPDATE", "MAIL_LOCK_SEND_ITEMS", "MAIL_UNLOCK_SEND_ITEMS", "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED",
        "PLAYERBANKSLOTS_CHANGED", "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PLAYER_LEAVING_WORLD", "GAME_PAD_DISCONNECTED", "INPUT_DEVICE_INTERFACE_TRANSITION", "UPDATE_BINDINGS" }) do
        pcall(driver.RegisterEvent, driver, event)
    end
    driver:SetShown(self.bankOpen or self.mailOpen)
end

BINDING_NAME_WEC_QUICK_MOVE = W.L["Quick move bank / mail item"]
