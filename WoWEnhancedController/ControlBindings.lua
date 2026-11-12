local _, W = ...
local B = {}
W.ControlBindings = B

local wheelInput = "CLICK WoWEnhancedControllerWheelInput:"
B.general = {
    {wheelInput.."Toggle","Toggle party / raid spell wheel"}, {wheelInput.."Sweep","Open hold & sweep healing wheel"},
    {wheelInput.."Classic","Open classic healing wheel"}, {"WEC_OPEN","Open controller keyboard / options"},
    {"WEC_FOCUS","Focus controller keyboard"}, {"WEC_MENU","Open Enhanced Controller launcher"},
    {"WEC_MINIMAP","Navigate minimap buttons"}, {"WEC_QUICK_MOVE","Bank / mail quick move"},
}
-- The final field restricts conflicts and active bindings to one roster context.
B.wheel = {
    {"ConfirmTrigger","Hold ally / release to cast","PADLTRIGGER"}, {"Confirm","Confirm selection","primary"},
    {"ConfirmDpad","Alternate confirm","PADDUP"}, {"Back","Go back","back"}, {"BackDpad","Alternate back","PADDDOWN"},
    {"PagePrevious","Previous spell page","PADLSHOULDER"}, {"PageNext","Next spell page","PADRSHOULDER"},
    {"Previous","Previous party wedge","PADDLEFT","party"}, {"Next","Next party wedge","PADDRIGHT","party"},
    {"RaidGroups","Raid groups","PADDLEFT","raid"}, {"RaidMembers","Group members","PADDRIGHT","raid"},
    {"RaidPrevious","Previous raid wedge","","raid"}, {"RaidNext","Next raid wedge","","raid"},
    {"Cancel","Close wheel",""},
}
local wheelKeys = {ConfirmTrigger="SPACE",Confirm="ENTER",Back="BACKSPACE",Cancel="ESCAPE",
    PagePrevious="PAGEUP",PageNext="PAGEDOWN",Previous="LEFT",Next="RIGHT",
    RaidGroups="HOME",RaidMembers="END",RaidPrevious="LEFT",RaidNext="RIGHT"}
function B.IsPad(token)
    local key=type(token)=="string" and token:match("[^-]+$")
    return key and key:match("^PAD[%w]+$")~=nil or false
end
local function context(action)
    if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
        local ok,value=pcall(C_KeyBindings.GetBindingContextForAction,action)
        if ok and not W.Secret(value) then return value end
    end
end
local function nativeKeys(action)
    if not GetBindingKey then return {} end
    local ok,first,second=pcall(GetBindingKey,action,nil,context(action))
    if not ok or W.Secret(first) or W.Secret(second) then return {} end
    return {first,second}
end
function B.DefaultR3()
    if not W.db.radial.defaultR3 then return false end
    for _,key in ipairs(nativeKeys(wheelInput.."Toggle")) do if B.IsPad(key) then return false end end
    local action = GetBindingAction and GetBindingAction("PADRSTICK", false)
    return not action or action==""
end
function B.Get(scope, row, device)
    local id=row[1]
    if scope=="general" then
        for _,token in ipairs(nativeKeys(id)) do if B.IsPad(token)==(device=="pad") then return token end end
        if id==wheelInput.."Toggle" and device=="pad" and B.DefaultR3() then return "PADRSTICK" end
        return ""
    end
    if scope=="text" then
        if device=="pad" then return W.Input.keys[id] or "" end
        return W.db.textKeys and W.db.textKeys[id] or ""
    end
    local prefs=W.db.radial.controls
    local value=prefs and prefs[id] and prefs[id][device]
    if value~=nil then return value end
    if device=="key" then return wheelKeys[id] or "" end
    if row[3]=="primary" or row[3]=="back" then
        local swap=W.Input:Style()=="Nintendo" and W.db.swapNintendo
        return (row[3]=="primary")~=swap and "PAD1" or "PAD2"
    end
    return row[3]
end
local function setNative(id, device, token)
    if not (SetBinding and SaveBindings and GetCurrentBindingSet and GetBindingAction and GetBindingKey) then
        return false,W.L["Native keybindings are unavailable."]
    end
    local ctx=context(id)
    local keys,old=nativeKeys(id)
    for _,key in ipairs(keys) do if B.IsPad(key)==(device=="pad") then old=key; break end end
    if token~="" then
        local occupied=GetBindingAction(token,false,ctx)
        if occupied and occupied~="" and occupied~=id then
            return false,W.L.Format("Used by %s. Unbind that action first.",_G["BINDING_NAME_"..occupied] or occupied)
        end
        if not old and #keys>=2 then return false,W.L["Both native binding slots are occupied."] end
    end
    if old~=token then
        if old and not SetBinding(old,nil,ctx) then return false,W.L["Could not change binding."] end
        if token~="" and not SetBinding(token,id,ctx) then
            if old then SetBinding(old,id,ctx) end
            return false,W.L["Could not change binding."]
        end
        if old or token~="" then
            local saved=pcall(SaveBindings,GetCurrentBindingSet())
            if not saved then
                if token~="" then SetBinding(token,nil,ctx) end
                if old then SetBinding(old,id,ctx) end
                return false,W.L["Could not change binding."]
            end
        end
    end
    if id==wheelInput.."Toggle" and device=="pad" then W.db.radial.defaultR3=false end
    return true
end
function B.ResetGeneral()
    if W.Combat() then return false,W.L["Change settings outside combat."] end
    if not (SetBinding and GetBindingKey and SaveBindings and GetCurrentBindingSet) then return false,W.L["Native keybindings are unavailable."] end
    local removed={}
    local function restore()
        for _,record in ipairs(removed) do SetBinding(record.key,record.action,record.context) end
        return false,W.L["Could not change binding."]
    end
    for _,row in ipairs(B.general) do
        local id=row[1]; local ctx=context(id)
        for _,key in ipairs(nativeKeys(id)) do
            if not SetBinding(key,nil,ctx) then return restore() end
            removed[#removed+1]={key=key,action=id,context=ctx}
        end
    end
    if #removed>0 and not pcall(SaveBindings,GetCurrentBindingSet()) then return restore() end
    W.db.radial.defaultR3=true
    return true
end
function B.Assign(scope,row,device,token)
    if W.Combat() then return false,W.L["Change settings outside combat."] end
    if token~="" and B.IsPad(token)~=(device=="pad") then return false,W.L["Use the selected input device."] end
    local id=row[1]
    if scope=="general" then
        local ok,err=setNative(id,device,token)
        if not ok then return false,err end
    elseif scope=="text" then
        if device=="pad" then return W.Options.AssignAction(id,token) end
        for other,key in pairs(W.db.textKeys or {}) do
            if other~=id and key==token and key~="" then return false,W.L.Format("Used by %s. Unbind that action first.",W.L[other]) end
        end
        W.db.textKeys=W.db.textKeys or {}; W.db.textKeys[id]=token~="" and token or nil
    else
        if token~="" then
            if token:match("PADRSTICK[UDLR]") or token=="PADRSTICK" and B.DefaultR3() then return false,W.L["Reserved by the wheel."] end
            for _,other in ipairs(B.wheel) do
                if other[1]~=id and (not row[4] or not other[4] or row[4]==other[4]) and B.Get(scope,other,device)==token then
                    return false,W.L.Format("Used by %s. Unbind that action first.",W.L[other[2]])
                end
            end
        end
        local r=W.db.radial; r.controls=r.controls or {}; r.controls[id]=r.controls[id] or {};r.controls[id][device]=token
    end
    W.Options.Apply()
    return true
end
function B.ConfigureWheel(frame, raid)
    for i,row in ipairs(B.wheel) do
        local active=not row[4] or row[4]==(raid and "raid" or "party")
        frame:SetAttribute("control-id-"..i,row[1])
        local command=row[1]=="RaidPrevious" and "Previous" or row[1]=="RaidNext" and "Next" or row[1]
        frame:SetAttribute("command-Key"..row[1],command)
        if row[1]~=command then frame:SetAttribute("command-"..row[1],command) end
        for _,device in ipairs({"pad","key"}) do
            local key=B.Get("wheel",row,device)
            frame:SetAttribute("control-"..device.."-"..i,active and key~="" and key or nil)
            frame:SetAttribute("hint-"..device.."-"..row[1],key)
            if device=="pad" and key~="" then frame:SetAttribute("expand-"..key,true) end
        end
    end
    frame:SetAttribute("control-count",#B.wheel)
    for _,key in ipairs({"PADRSTICK","PADRSTICKUP","PADRSTICKRIGHT","PADRSTICKDOWN","PADRSTICKLEFT"}) do
        frame:SetAttribute("expand-"..key,true)
    end
end
