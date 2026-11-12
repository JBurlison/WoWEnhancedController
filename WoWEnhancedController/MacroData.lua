local _, W = ...
local D = {}
W.MacroData = D
local function message(text) return W.L[text] end
function D.Init()
    local db=W.db
    if type(db.macros)~="table" then db.macros={schema=1,account={},characters={}} end
    db.macros.account=db.macros.account or {};db.macros.characters=db.macros.characters or {}
end
function D.Limits()
    local c=Constants and Constants.MacroConsts
    return c and c.MAX_ACCOUNT_MACROS,c and c.MAX_CHARACTER_MACROS
end
local function fingerprint(entry)
    return #entry.name..":"..entry.name..#entry.body..":"..entry.body..":"..tostring(entry.icon)
end
local function bucket(scope)
    D.Init()
    if scope=="account" then return W.db.macros.account end
    local guid=UnitGUID and UnitGUID("player")
    if not guid or W.Secret(guid) then return end
    local all=W.db.macros.characters
    all[guid]=all[guid] or {};return all[guid]
end
function D.Read(index,scope)
    if not GetMacroInfo then return end
    local ok,name,texture,body=pcall(GetMacroInfo,index)
    if not ok or W.Secret(name) or W.Secret(texture) or W.Secret(body) or type(name)~="string" or type(body)~="string" then return end
    local icon=texture
    if C_Macro and C_Macro.GetSelectedMacroIcon then
        local good,selected=pcall(C_Macro.GetSelectedMacroIcon,index)
        if good and not W.Secret(selected) and (type(selected)=="number" and selected>0 or type(selected)=="string" and selected~="") then icon=selected end
    end
    return {index=index,scope=scope,name=name,body=body,icon=icon or 134400,displayIcon=texture or 134400}
end
function D.List(scope)
    local list={}
    local base=D.Limits()
    if not base or not GetNumMacros then return list,message("Native macros are unavailable.") end
    local ok,account,character=pcall(GetNumMacros)
    if not ok or W.Secret(account) or W.Secret(character) or type(account)~="number" or type(character)~="number" then return list,message("Native macros are unavailable.") end
    for _,kind in ipairs({"account","character"}) do
        if not scope or scope==kind then
            local offset=kind=="account" and 0 or base
            for i=1,(kind=="account" and account or character) do
                local entry=D.Read(offset+i,kind);if entry then list[#list+1]=entry end
            end
        end
    end
    return list
end
function D.Resolve(snapshot)
    if not snapshot then return nil,message("Choose a macro first.") end
    local matches={}
    for _,entry in ipairs(D.List(snapshot.scope)) do
        if entry.name==snapshot.name and entry.body==snapshot.body and entry.icon==snapshot.icon then matches[#matches+1]=entry end
    end
    if #matches~=1 then return nil,message("This macro changed elsewhere or is ambiguous. Reopen it before saving.") end
    return matches[1]
end
function D.New(scope)
    return {name="",scope=scope or "account",icon=134400,tooltip=true,blocks={}},nil
end
function D.Load(entry)
    local current,err=D.Resolve(entry);if not current then return nil,err end
    local saved=bucket(current.scope);saved=saved and saved[fingerprint(current)]
    local model
    if type(saved)=="table" and saved.schema==1 and type(saved.model)=="table" then
        model=W.Copy(saved.model)
        local body,errors=W.MacroCompiler.Compile(model)
        -- Rank learning/localization/native edits must never regenerate an
        -- existing macro into a different body behind the user's back.
        if body~=current.body or errors and #errors>0 then model=nil end
    end
    model=model or {tooltip=false,blocks={{kind="raw",text=current.body}}}
    model.name,model.icon,model.scope=current.name,current.icon,current.scope
    return model,W.Copy(current)
end
function D.Validate(model,snapshot,catalog)
    if W.Combat() then return nil,message("Edit macros outside combat.") end
    if type(model)~="table" or type(model.name)~="string" or W.Secret(model.name) then return nil,message("Give this macro a name.") end
    local name=model.name
    if name:match("^%s*$") or name:find('[\r\n|"%z]') or W.MacroCompiler.Characters(name)>16 then
        return nil,message("Use a macro name of 1–16 characters without quotes or line breaks.")
    end
    if model.scope~="account" and model.scope~="character" then return nil,message("Invalid macro scope.") end
    if snapshot and snapshot.scope~=model.scope then return nil,message("Duplicate this macro to change its scope.") end
    local body,errors,warnings=W.MacroCompiler.Compile(model,catalog)
    if errors and #errors>0 then return nil,errors[1].message end
    if not body or body:match("^%s*$") or body:find("%z") then return nil,message("Add an action before saving.") end
    if W.MacroCompiler.Characters(body)>255 then return nil,message("This macro exceeds 255 characters.") end
    local icon=model.icon or 134400
    if type(icon)~="number" and type(icon)~="string" or type(icon)=="number" and (icon<1 or icon~=math.floor(icon))
        or type(icon)=="string" and (icon=="" or #icon>260 or icon:find("[|\r\n]")) then return nil,message("Invalid icon.") end
    local existing
    if snapshot then existing,errors=D.Resolve(snapshot);if not existing then return nil,errors end end
    local list,err=D.List(model.scope);if err then return nil,err end
    for _,entry in ipairs(list) do
        if entry.name==name and (not existing or entry.index~=existing.index) then return nil,message("A macro with this name already exists in this scope.") end
    end
    local accountLimit,characterLimit=D.Limits()
    local limit=model.scope=="account" and accountLimit or characterLimit
    if not limit then return nil,message("Native macros are unavailable.") end
    if not existing and #list>=limit then return nil,message("This macro scope is full. Delete a macro or choose another scope.") end
    return {name=name,icon=icon,body=body,scope=model.scope,index=existing and existing.index},nil,warnings
end
function D.Save(model,snapshot,catalog)
    local value,err=D.Validate(model,snapshot,catalog);if not value then return nil,err end
    if not CreateMacro or not EditMacro then return nil,message("Native macro saving is unavailable.") end
    -- No frame hide/tab switch calls this; only explicit Save or Save & bind.
    local ok,index
    if value.index then ok,index=pcall(EditMacro,value.index,value.name,value.icon,value.body)
    else ok,index=pcall(CreateMacro,value.name,value.icon,value.body,value.scope=="character") end
    if not ok then return nil,message("WoW could not save this macro. Your draft is still available.") end
    local read=type(index)=="number" and D.Read(index,value.scope)
    if not read then
        for _,entry in ipairs(D.List(value.scope)) do if entry.name==value.name and entry.body==value.body then read=entry;break end end
    end
    if not read or read.name~=value.name or read.body~=value.body or read.icon~=value.icon then
        -- Detect native limits/normalization rather than silently accepting a
        -- truncated macro. Restore the old entry or remove only our new entry.
        -- Renaming can sort native slots. Only touch the returned entry after
        -- verifying its new name, never the old numeric slot.
        local restored=false
        if read and read.name==value.name then
            if snapshot then
                pcall(EditMacro,read.index,snapshot.name,snapshot.icon,snapshot.body)
                restored=D.Resolve(snapshot)~=nil
            elseif DeleteMacro then
                pcall(DeleteMacro,read.index)
                restored=true
                for _,entry in ipairs(D.List(value.scope)) do if entry.name==value.name then restored=false end end
            end
        end
        return nil,message(restored and "WoW changed or shortened the saved text. The save was rolled back; keep editing the draft."
            or "WoW did not confirm the save. Your draft is retained; reopen the native macro list before trying again.")
    end
    local models=bucket(value.scope)
    if models then
        if snapshot then models[fingerprint(snapshot)]=nil end
        local clean=W.Copy(model);clean.raw=nil
        if type(model.raw)=="string" then clean.tooltip=false;clean.blocks={{kind="raw",text=model.raw}} end
        models[fingerprint(read)]={schema=1,model=clean}
    end
    return W.Copy(read)
end
function D.Delete(snapshot)
    if W.Combat() then return nil,message("Edit macros outside combat.") end
    local entry,err=D.Resolve(snapshot);if not entry then return nil,err end
    if not DeleteMacro then return nil,message("Native macro saving is unavailable.") end
    local ok=pcall(DeleteMacro,entry.index)
    if not ok then return nil,message("WoW could not delete this macro.") end
    for _,current in ipairs(D.List(entry.scope)) do
        if current.name==entry.name and current.body==entry.body and current.icon==entry.icon then return nil,message("WoW could not delete this macro.") end
    end
    local models=bucket(entry.scope);if models then models[fingerprint(entry)]=nil end
    return true
end
function D.Spells() return W.RadialData.Spells() end
function D.Forms()
    local result={{value=false,label=W.L["Any form"]},{value=0,label=W.L["No form"]}}
    if GetNumShapeshiftForms and GetShapeshiftFormInfo then
        for i=1,GetNumShapeshiftForms() do
            local _,_,_,spellID=GetShapeshiftFormInfo(i)
            local info=spellID and W.RadialData.Info(spellID)
            if info then result[#result+1]={value=i,label=info.name} end
        end
    end
    return result
end
