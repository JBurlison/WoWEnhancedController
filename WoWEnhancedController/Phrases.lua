local _, W = ...
local P = {}
W.Phrases = P
local auctionItems = { 2589, 2770, 929, 2318 }
local itemRequested = {}
P.defaults = {
    global = { W.L["Hello!"], W.L["Thank you!"], W.L["Group?"], W.L["On my way."] },
    chat = { W.L["Hello!"], W.L["Thanks!"], W.L["Group?"], W.L["Good luck!"] },
    ["chat:PARTY"] = { W.L["Ready!"], W.L["Group?"], W.L["Thanks for the group!"], W.L["Need a break."] },
    ["chat:RAID"] = { W.L["Ready!"], W.L["Need a break."], W.L["Summon, please."], W.L["Thank you!"] },
    ["chat:GUILD"] = { W.L["Hello, guild!"], W.L["Anyone up for a dungeon?"], W.L["Congratulations!"], W.L["Good night!"] },
    ["chat:WHISPER"] = { W.L["On my way."], W.L["Invite, please."], W.L["Group?"], W.L["Thanks!"] },
    ["auction:search"] = { W.L["Linen Cloth"], W.L["Copper Ore"], W.L["Healing Potion"], W.L["Light Leather"] },
}
function P.InitPages()
    if type(W.db.quickPages) == "table" and #W.db.quickPages > 0 then return end
    local pages = { "phrases" }
    for _, bank in ipairs({ "phrasesLeft", "phrasesRight" }) do
        if W.db.phraseBanks[bank] then pages[#pages + 1] = bank end
    end
    W.db.quickPages = pages
end
function P.AddPage()
    local pages = W.db.quickPages
    W.db.quickPageSerial = (W.db.quickPageSerial or 0) + 1
    local key = "page" .. W.db.quickPageSerial
    pages[#pages + 1] = key
    W.db.phraseBanks[key] = { phrases = {} }
    return #pages
end
function P.RemovePage(index)
    local pages = W.db.quickPages
    if index == 1 or not pages[index] then return false end
    W.db.phraseBanks[table.remove(pages, index)] = nil
    return true
end
function P.Storage(bank)
    if not bank or bank == "phrases" then return W.db end
    return W.db.phraseBanks[bank]
end
function P.Resolve(context, slot, bank)
    local store = P.Storage(bank)
    for _, scope in ipairs(W.Contexts.Scopes(context)) do
        local record = store and store.phrases[scope] and store.phrases[scope][slot]
        if record and (not record.link or context.chat or context.key=="global") and (not context.numeric or tonumber(record.text)) then
            local text=record.link and record.link.kind=="tracked" and W.L["Current tracked quest"] or record.text
            return text or "",scope,record.link,record.destination
        end
    end
    if context.numeric then return ({ "1", "5", "10", "20" })[slot], context.key end
    if bank and bank ~= "phrases" then return "", context.key end
    if context.key == "auction:search" and C_Item then
        local id = auctionItems[slot]
        if id and C_Item.GetItemNameByID then
            local ok, name = pcall(C_Item.GetItemNameByID, id)
            if ok and type(name) == "string" and not W.Secret(name) then return name, context.key end
            if not itemRequested[id] and C_Item.RequestLoadItemDataByID then
                itemRequested[id] = true; C_Item.RequestLoadItemDataByID(id)
            end
        end
    end
    for _, scope in ipairs(W.Contexts.Scopes(context)) do
        if P.defaults[scope] and P.defaults[scope][slot] then return P.defaults[scope][slot], scope end
    end
    return "", context.key
end
function P.Save(scope, slot, text, bank, link, destination)
    if type(slot) ~= "number" or slot < 1 or slot > 8 or slot % 1 ~= 0 then return false, W.L["Invalid action."] end
    if type(text) ~= "string" or text == "" then return false, W.L["Enter a phrase first."] end
    local store = P.Storage(bank)
    if not store then return false, W.L["Invalid action."] end
    store.phrases[scope] = store.phrases[scope] or {}
    store.phrases[scope][slot] = { text = W.Text.Limit(text, 1024, 255), link = W.Copy(link), destination = W.Copy(destination) }
    return true
end
function P.Reset(scope, slot, bank)
    local store = P.Storage(bank)
    if store and store.phrases[scope] then store.phrases[scope][slot] = nil end
end
