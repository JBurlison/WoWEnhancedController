local _, W = ...
local C = {}
W.Contexts = C

local labels = { SAY = W.L["Say"], YELL = W.L["Yell"], PARTY = W.L["Party"], RAID = W.L["Raid"], RAID_WARNING = W.L["Raid warning"],
    INSTANCE_CHAT = W.L["Instance"], GUILD = W.L["Guild"], OFFICER = W.L["Officer"], WHISPER = W.L["Whisper"], BN_WHISPER = W.L["Battle.net whisper"], EMOTE = W.L["Emote"] }
-- Leave Auction House count controls to the native UI. QuantityInput wrappers
-- commonly have only a parentKey, so inspecting global EditBox names is not enough.
function C.NativeAuctionQuantity(box)
    local node, auction, quantity = box, false, false
    for _ = 1, 20 do
        if not node then break end
        local name, parent = W.Call(node, "GetName"), W.Call(node, "GetParent")
        if type(name) == "string" then
            name = name:lower()
            if name:find("auctionhouse", 1, true) or name:find("auctionframe", 1, true) then auction = true end
            if name:find("quantity", 1, true) or name:find("count", 1, true) then quantity = true end
        end
        if parent and not W.Secret(parent.QuantityInput) and parent.QuantityInput == node then quantity = true end
        if auction and quantity then return true end
        node = parent
    end
    return false
end
function C.Chat(box)
    local kind = W.Call(box, "GetChatType") or W.Call(box, "GetAttribute", "chatType")
    if not kind then return end
    local result = { chat = true, chatType = kind, key = "chat:" .. kind, label = labels[kind] or kind, maxBytes = 255 }
    if kind == "CHANNEL" then
        local target = W.Call(box, "GetChannelTarget") or W.Call(box, "GetAttribute", "channelTarget")
        if GetChannelName and target then
            local ok, id, name = pcall(GetChannelName, target)
            if ok and not W.Secret(id) and not W.Secret(name) and id and id > 0 and type(name) == "string" then
                result.channel, result.channelName = id, name
                result.key, result.label = "chat:channel:" .. name:lower(), name
            end
        end
        if not result.channel then result.unavailable = W.L["This chat channel is no longer joined."] end
    elseif kind == "WHISPER" or kind == "BN_WHISPER" then
        result.recipient = W.Call(box, "GetTellTarget") or W.Call(box, "GetAttribute", "tellTarget")
        result.label = W.L.Format("%s to %s", result.label, result.recipient or W.L["no recipient"])
    end
    return result
end

-- Persist a channel's name. The same number can belong to a different
-- channel after leaving, rejoining, or moving to another zone.
function C.Destination(pin)
    if type(pin) ~= "table" or (not labels[pin.chatType] and pin.chatType ~= "CHANNEL") then return end
    if pin.chatType == "CHANNEL" and type(pin.channelName) ~= "string" then return end
    local context = C.Chat({
        GetChatType = function() return pin.chatType end,
        GetChannelTarget = function() return pin.channelName end,
        GetTellTarget = function() return pin.recipient end,
    })
    if pin.chatType == "CHANNEL" and (not context.channelName or context.channelName:lower() ~= pin.channelName:lower()) then return end
    return context
end

function C.DraftKey(context)
    return context.recipient and context.key.." "..context.recipient or context.key
end

function C.Describe(box)
    local chat = C.Chat(box)
    if chat then return chat end
    for _, adapter in ipairs(W.adapters) do
        local ok, match = pcall(adapter.predicate, box)
        if ok and match then
            local success, description = pcall(adapter.describe, box)
            if success and description then return description end
        end
    end
    local names, node = {}, box
    for _ = 1, 10 do
        if not node then break end
        local nodeName, parent = W.Call(node, "GetName"), W.Call(node, "GetParent")
        -- Modern Blizzard XML often uses parentKey rather than globally named frames.
        if not nodeName and parent then
            for _, key in ipairs({ "SearchBox", "SearchBar", "InputBox", "QuantityInput", "GoldBox", "SilverBox", "CopperBox", "EditBox" }) do
                local child = parent[key]
                if not W.Secret(child) and child == node then nodeName = key; break end
            end
        end
        names[#names + 1] = nodeName or ""
        node = parent
    end
    local path, name = table.concat(names, "/"), W.Call(box, "GetName")
    local c = { key = "field:" .. (name or path), label = W.L["Text field"],
        numeric = W.Call(box, "IsNumeric") == true, maxBytes = W.Call(box, "GetMaxBytes"),
        maxLetters = W.Call(box, "GetMaxLetters"), multiline = W.Call(box, "IsMultiLine") == true }
    if path:find("AuctionHouse") and (path:find("Search") or path:find("search")) then
        c.key, c.label = "auction:search", W.L["Auction House search"]
    elseif path:find("SendMail") then
        c.key, c.label = "mail:" .. (name or "body"), W.L.Format("Mail · %s", name or W.L["Body"])
    elseif path:find("Professions") or path:find("TradeSkill") then
        c.key, c.label = c.numeric and "craft:quantity" or "craft:search", c.numeric and W.L["Crafting quantity"] or W.L["Profession search"]
    elseif c.numeric then c.label = W.L["Amount"] end
    if c.numeric then
        c.min, c.step = 0, 1
        -- Unknown bounds remain unknown. Known native spinner limits are supplied below.
        local parent = type(box.GetMinValue) == "function" and box or W.Call(box, "GetParent")
        if parent and type(parent.GetMinValue) == "function" and type(parent.GetMaxValue) == "function" then
            local low, high = W.Call(parent, "GetMinValue"), W.Call(parent, "GetMaxValue")
            if type(low) == "number" then c.min = low end
            if type(high) == "number" then c.max = high end
        end
    end
    return c
end

function C.Scopes(context)
    local scopes = { context.key }
    if context.chat then scopes[#scopes + 1] = "chat" end
    scopes[#scopes + 1] = "global"
    return scopes
end
function C.Same(a, b)
    return a and b and a.key == b.key and a.chatType == b.chatType and a.recipient == b.recipient
        and a.channel == b.channel and a.max == b.max and a.min == b.min
end
function C.Valid(session)
    if not session or not session.target then return false end
    if session.ownerParent and W.Call(session.target, "GetParent") ~= session.ownerParent then return false end
    if not W.Call(session.target, "IsVisible") then return false end
    if W.Call(session.target, "IsEnabled") == false then return false end
    if not C.Same(session.ownerContext or session.context, C.Describe(session.target)) then return false end
    if session.context.isCurrent and not session.context.isCurrent(session.target) then return false end
    local current = W.Call(session.target, "GetText")
    if current == nil or current ~= session.sourceText then return false end
    return true
end

-- Return adjacent fields inside the same native owner, never arbitrary screen fields.
function C.Adjacent(box, direction)
    local owner = W.Call(box, "GetParent")
    if not owner then return end
    local fields = {}
    local function walk(frame, depth)
        if depth > 4 or not W.Call(frame, "IsVisible") then return end
        if W.Call(frame, "IsObjectType", "EditBox") and W.Call(frame, "IsEnabled") ~= false then fields[#fields + 1] = frame end
        if type(frame.GetChildren) == "function" then for _, child in ipairs({ frame:GetChildren() }) do walk(child, depth + 1) end end
    end
    walk(owner, 0)
    table.sort(fields, function(a, b)
        local ay, by = W.Call(a, "GetTop") or 0, W.Call(b, "GetTop") or 0
        if math.abs(ay - by) > 2 then return ay > by end
        return (W.Call(a, "GetLeft") or 0) < (W.Call(b, "GetLeft") or 0)
    end)
    for i, field in ipairs(fields) do if field == box then return fields[((i - 1 + direction) % #fields) + 1] end end
end
