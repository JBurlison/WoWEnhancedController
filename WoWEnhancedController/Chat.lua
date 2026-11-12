local _, W = ...
function W.SendChat(box)
    if not W.Usable(box) or not W.Contexts.Chat(box) then return false, "The chat field is no longer available." end
    local text = W.Call(box, "GetText")
    if type(text) ~= "string" or not text:find("%S") then return false, "Enter a message or command first." end
    -- The real Enter script owns slash parsing, autocomplete, history, sticky
    -- channels and secure restrictions. No direct-message or registry fallback.
    local handler = W.Call(box, "GetScript", "OnEnterPressed") or box.OnEnterPressed
    if type(handler) ~= "function" then return false, "Native chat Enter is unavailable; text remains in the field." end
    local ok = pcall(handler, box)
    if not ok then return false, "Native chat could not finish Enter; check the chat field." end
    return true
end
