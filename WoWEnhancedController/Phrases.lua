local _, W = ...
local P = {}
W.Phrases = P
P.defaults = {
    global = { "Hello!", "Thank you!", "One moment, please.", "On my way." },
    chat = { "Hello!", "Thanks!", "One moment, please.", "Good luck!" },
    ["chat:PARTY"] = { "Ready!", "One moment, please.", "Thanks for the group!", "Need a break." },
    ["chat:RAID"] = { "Ready!", "Need a break.", "Summon, please.", "Thank you!" },
    ["chat:GUILD"] = { "Hello, guild!", "Anyone up for a dungeon?", "Congratulations!", "Good night!" },
    ["chat:WHISPER"] = { "On my way.", "Invite, please.", "One moment!", "Thanks!" },
    ["auction:search"] = { "Linen Cloth", "Copper Ore", "Healing Potion", "Light Leather" },
}
function P.Resolve(context, slot)
    for _, scope in ipairs(W.Contexts.Scopes(context)) do
        local record = W.db.phrases[scope] and W.db.phrases[scope][slot]
        if record then return record.text or "", scope end
    end
    if context.numeric then return ({ "1", "5", "10", "20" })[slot], context.key end
    for _, scope in ipairs(W.Contexts.Scopes(context)) do
        if P.defaults[scope] and P.defaults[scope][slot] then return P.defaults[scope][slot], scope end
    end
    return "", context.key
end
function P.Save(scope, slot, text)
    if type(text) ~= "string" or text == "" then return false, "Enter a phrase first." end
    W.db.phrases[scope] = W.db.phrases[scope] or {}
    W.db.phrases[scope][slot] = { text = W.Text.Limit(text, 1024, 255) }
    return true
end
function P.Reset(scope, slot)
    if W.db.phrases[scope] then W.db.phrases[scope][slot] = nil end
end
function P.Bindings(context)
    for _, scope in ipairs(W.Contexts.Scopes(context)) do
        if W.db.bindings[scope] then return W.db.bindings[scope], scope end
    end
    return { "primary", "back", "delete", "shift" }, "default"
end
function P.Bind(scope, slot, action, context)
    local bindings = W.Copy(W.db.bindings[scope] or P.Bindings(context))
    for i, existing in ipairs(bindings) do
        if i ~= slot and existing == action and action ~= "unbound" then
            return false, "Already assigned to phrase " .. i .. ". Choose Unbound there first."
        end
    end
    bindings[slot] = action
    W.db.bindings[scope] = bindings
    return true
end
