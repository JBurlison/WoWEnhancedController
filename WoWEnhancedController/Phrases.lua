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
function P.Storage(bank, create)
    if not bank or bank == "phrases" then return W.db end
    if bank ~= "phrasesLeft" and bank ~= "phrasesRight" then return end
    local store = W.db.phraseBanks[bank]
    if not store and create then
        store = { phrases = {}, bindings = {} }; W.db.phraseBanks[bank] = store
    end
    return store
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
    if type(text) ~= "string" or text == "" then return false, W.L["Enter a phrase first."] end
    local store = P.Storage(bank, true)
    if not store then return false, W.L["Invalid action."] end
    store.phrases[scope] = store.phrases[scope] or {}
    store.phrases[scope][slot] = { text = W.Text.Limit(text, 1024, 255), link = W.Copy(link), destination = W.Copy(destination) }
    return true
end
function P.Reset(scope, slot, bank)
    local store = P.Storage(bank)
    if store and store.phrases[scope] then store.phrases[scope][slot] = nil end
end
function P.Bindings(context, bank)
    local store = P.Storage(bank)
    for _, scope in ipairs(W.Contexts.Scopes(context)) do
        if store and store.bindings[scope] then return store.bindings[scope], scope end
    end
    return { "primary", "back", "delete", "shift" }, "default"
end
function P.BindingsForScope(scope, context, bank)
    local store = P.Storage(bank)
    if store and store.bindings[scope] then return store.bindings[scope] end
    if scope == "global" then return { "primary", "back", "delete", "shift" } end
    if scope == "chat" then return store and store.bindings.global or { "primary", "back", "delete", "shift" } end
    return P.Bindings(context, bank)
end
function P.CheckBinding(scope, slot, action, context, bank)
    local bindings = P.BindingsForScope(scope, context, bank)
    for i, existing in ipairs(bindings) do
        if i ~= slot and existing == action and action ~= "unbound" then
            return false, W.L.Format("Already assigned to phrase %d. Choose Unbound there first.", i)
        end
    end
    return true
end
function P.Bind(scope, slot, action, context, bank)
    local ok, reason = P.CheckBinding(scope, slot, action, context, bank)
    if not ok then return false, reason end
    local store = P.Storage(bank, true)
    if not store then return false, W.L["Invalid action."] end
    local bindings = W.Copy(P.BindingsForScope(scope, context, bank))
    bindings[slot] = action
    store.bindings[scope] = bindings
    return true
end
