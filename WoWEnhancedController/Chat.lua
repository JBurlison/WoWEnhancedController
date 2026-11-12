local _, W = ...
local function sendLines(context, language, lines)
    if not context.chat or context.unavailable then return false,context.unavailable end
    for _, message in ipairs(lines) do
        if not message:find("%S") then return false,W.L["Enter a phrase first."] end
        if #message>255 then return false,W.L["This message exceeds the chat length limit."] end
    end
    local send
    if context.chatType=="BN_WHISPER" then
        local id=context.recipient and BNet_GetBNetIDAccount and BNet_GetBNetIDAccount(context.recipient)
        if not W.Secret(id) and id and C_BattleNet and C_BattleNet.SendWhisper then
            send = function(text) C_BattleNet.SendWhisper(id,text) end
        end
    elseif C_ChatInfo and C_ChatInfo.SendChatMessage then
        local target
        if context.chatType=="WHISPER" then
            target=context.recipient
            if not target or target=="" then return false,W.L["Choose a whisper recipient first."] end
        elseif context.chatType=="CHANNEL" then target=tostring(context.channel) end
        send = function(text) C_ChatInfo.SendChatMessage(text,context.chatType,language,target) end
    end
    for _, line in ipairs(lines) do
        if not send or not pcall(send,line) then return false,W.L["Could not send the quick message."] end
    end
    return true
end

function W.SendQuickMessage(session, message, progress, destination)
    if W.Combat() or W.Blocker() or not W.Contexts.Valid(session) or W.Focus()~=session.target then return end
    local context = session.context
    if not context.chat then return end
    if message:lower():match("^%s*/reload%s*$") then
        return pcall(ReloadUI)
    end
    if destination then
        context = W.Contexts.Destination(destination)
        if not context then return false,W.L["This chat channel is no longer joined."] end
    end
    local lines = {message}
    for _, line in ipairs(progress or {}) do lines[#lines+1] = line end
    return sendLines(context, session.target.languageID, lines)
end

-- Forever calls SendText only after accepting Enter/autocomplete. Its post-hook
-- still sees the sent text and channel before SendMessage clears the edit box.
local hooked = setmetatable({}, {__mode="k"})
function W.AttachQuestProgress(session, link, ref)
    local box = session.target
    if not hooked[box] and hooksecurefunc and type(box.SendText) == "function" then
        hooksecurefunc(box, "SendText", function(field)
            local current = W.Keyboard.session
            if current and current.target == field then W.SendAttachedProgress(current, W.Call(field,"GetText"), W.Contexts.Chat(field)) end
        end)
        hooked[box] = true
    end
    session.questProgress = session.questProgress or {}
    for _, item in ipairs(session.questProgress) do
        if item.link == link and item.ref.objective == ref.objective then return end
    end
    table.insert(session.questProgress, {link=link,ref=ref})
end

function W.SendAttachedProgress(session, text, context)
    local pending = session.questProgress
    if not pending or not context or not text or text:match("^%s*/") or W.Combat() or W.Blocker() then return end
    session.questProgress = nil
    local lines, seen = {}, {}
    for _, item in ipairs(pending) do
        if text:find(item.link, 1, true) then
            local _, progress = W.Links:Message(item.ref)
            seen[item.link] = seen[item.link] or {}
            for _, line in ipairs(progress or {}) do
                if not seen[item.link][line] then
                    lines[#lines+1] = line
                    seen[item.link][line] = true
                end
            end
        end
    end
    local _, err = sendLines(context,session.target.languageID,lines)
    if err then W.Print(err) end
end
function W.SendChat(box)
    if not W.Usable(box) or not W.Contexts.Chat(box) then return false, W.L["The chat field is no longer available."] end
    local text = W.Call(box, "GetText")
    if type(text) ~= "string" or not text:find("%S") then return false, W.L["Enter a message or command first."] end
    -- The real Enter script owns slash parsing, autocomplete, history, sticky
    -- channels and secure restrictions. No direct-message or registry fallback.
    local handler = W.Call(box, "GetScript", "OnEnterPressed") or box.OnEnterPressed
    if type(handler) ~= "function" then return false, W.L["Native chat Enter is unavailable; text remains in the field."] end
    local session, context = W.Keyboard.session, W.Contexts.Chat(box)
    local ok = pcall(handler, box)
    if not ok then return false, W.L["Native chat could not finish Enter; check the chat field."] end
    if not hooked[box] and session and session.target == box and W.Call(box,"GetText") == "" then
        W.SendAttachedProgress(session, text, context)
    end
    return true
end
