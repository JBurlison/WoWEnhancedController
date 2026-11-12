local _, W = ...
local F = {}
W.NativeField = F

-- The native EditBox owns text, parsing, selection and focus. The text model
-- only retains controller undo/history; it is never a second visible draft.
function F.Read(k, remember, adoptContext)
    local s, e = k.session, k.editor
    if not s or not e or k.composing then return false end
    local text = W.Call(s.target, "GetText")
    if type(text) ~= "string" then return false end
    if remember and text ~= e.text then e:Remember() end
    e.text = text
    local cursor = W.Call(s.target, "GetCursorPosition") or #text
    e:Select(cursor, cursor)
    s.sourceText, s.appliedCursor, s.appliedAnchor = text, e.cursor, e.anchor
    if adoptContext then
        local context = W.Contexts.Describe(s.target)
        local changed = not W.Contexts.Same(s.context, context)
        if changed and s.context.chat then W.drafts[s.context.key] = "" end
        s.context, s.ownerContext, e.options = context, W.Copy(context), context
        return true, changed
    end
    return true, false
end

function F.Write(k)
    local s, e = k.session, k.editor
    if not s or not e or k.composing or not W.Contexts.Valid(s) or W.Call(s.target, "HasFocus") ~= true then return false end
    local box, requested = s.target, e.text
    k.syncing = true
    local ok = true
    if requested ~= s.sourceText then
        ok = pcall(box.SetText, box, requested)
        local actual = W.Call(box, "GetText")
        if ok and type(actual) == "string" then
            if actual ~= requested then F.Read(k, false, true)
            else
                s.sourceText = actual
                local context = W.Contexts.Describe(box)
                s.context, s.ownerContext, e.options = context, W.Copy(context), context
            end
        else ok = false end
    end
    if ok and (e.cursor ~= s.appliedCursor or e.anchor ~= s.appliedAnchor) then
        W.Call(box, "SetCursorPosition", e.cursor)
        if e.anchor ~= e.cursor then
            W.Call(box, "HighlightText", math.min(e.anchor, e.cursor), math.max(e.anchor, e.cursor))
        else W.Call(box, "ClearHighlightText") end
        s.appliedCursor, s.appliedAnchor = e.cursor, e.anchor
    end
    k.syncing = false
    if not ok then k:Status("The native field rejected this edit.") end
    return ok
end

function F.Insert(k, value)
    local s = k.session
    if not s or not W.Contexts.Valid(s) or W.Call(s.target, "HasFocus") ~= true or type(s.target.Insert) ~= "function" then return false end
    k.syncing = true
    local ok = pcall(s.target.Insert, s.target, value)
    k.syncing = false
    if not ok then k:Status("The native field rejected this text."); return false end
    local changed = W.Call(s.target, "GetText") ~= k.editor.text
    if changed then k.editor:Remember() end
    F.Read(k, false, true)
    return true, changed
end

function F.Attach(k, box)
    k.fieldHooks = k.fieldHooks or setmetatable({}, { __mode = "k" })
    if k.fieldHooks[box] or type(box.HookScript) ~= "function" then return end
    k.fieldHooks[box] = true
    box:HookScript("OnEditFocusGained", function(field)
        if W.dismissed == field then W.dismissed = nil end
    end)
    box:HookScript("OnTextChanged", function(field, userInput)
        local s = k.session
        if not s or s.target ~= field or k.syncing or k.submitting or k.composing then return end
        -- Generic programmatic changes may mean the owner was recycled.
        if not userInput and not s.context.chat then return end
        local ok, changed = F.Read(k, true, userInput == true)
        if ok and changed then k:Draw() end
    end)
    box:HookScript("OnCursorChanged", function(field)
        local s = k.session
        if not s or s.target ~= field or k.syncing or k.submitting or k.composing then return end
        local cursor = W.Call(field, "GetCursorPosition")
        if cursor then
            k.editor:Select(cursor, cursor)
            s.appliedCursor, s.appliedAnchor = cursor, cursor
        end
    end)
end
