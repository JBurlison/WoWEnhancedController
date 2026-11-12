local _, W = ...
local D = { pageSize = 8, maxPages = 9, maxActions = 72 }
W.RadialData = D

local presets = {
    {value="target",label="Target",icon=132212}, {value="trade",label="Trade",icon=133784},
    {value="duel",label="Duel",icon=132147}, {value="whisper",label="Whisper",icon=134332},
    {value="focus",label="Focus",icon=136190},
}
function D.Presets()
    local result={}
    for _,item in ipairs(presets) do result[#result+1]={kind="friendly",value=item.value,label=W.L[item.label],icon=item.icon,detail=""} end
    return result
end
function D.PageID(ordinal)
    if ordinal==1 then return 0 end
    local distance=math.floor(ordinal/2)
    return ordinal%2==0 and -distance or distance
end
function D.PageName(id)
    return id==0 and W.L["Main (default)"] or W.L.Format(id<0 and "Left %d" or "Right %d",math.abs(id))
end
function D.Migrate(profile)
    if type(profile.pages)~="table" then profile.pages={0} end
    local pages,occupied={},{}
    for _,id in ipairs(profile.pages) do pages[id]=true end
    pages[0]=true
    for _,action in ipairs(profile.actions) do
        local page,slot=tonumber(action.page),tonumber(action.slot)
        if not page or not slot or slot<1 or slot>8 or slot~=math.floor(slot) or occupied[page..":"..slot] then
            page,slot=nil,nil
            for ordinal=1,math.max(D.maxPages,math.ceil(#profile.actions/8)) do
                local id=D.PageID(ordinal)
                for n=1,8 do if not occupied[id..":"..n] then page,slot=id,n;break end end
                if slot then break end
            end
        end
        action.page,action.slot=page,slot;pages[page]=true;occupied[page..":"..slot]=true
    end
    profile.pages={}
    for id in pairs(pages) do profile.pages[#profile.pages+1]=id end
    table.sort(profile.pages)
    return profile
end
function D.PageSlots(page,profile)
    local slots={}
    for index,action in ipairs((profile or D.Profile()).actions) do if action.page==page then slots[action.slot]=index end end
    return slots
end
function D.AddPage(profile)
    if W.Combat() then return end
    local p=profile or D.Profile();if #p.pages>=D.maxPages then return end
    for ordinal=2,D.maxPages do
        local id=D.PageID(ordinal);local exists=false
        for _,page in ipairs(p.pages) do if page==id then exists=true end end
        if not exists then p.pages[#p.pages+1]=id;table.sort(p.pages);if not profile and W.Radial then W.Radial:Rebuild() end;return id end
    end
end
function D.RemovePage(id,profile)
    if W.Combat() or id==0 then return false end
    local p=profile or D.Profile()
    -- Keep configured actions intact. The user empties a page before removing it.
    if next(D.PageSlots(id,p)) then return false end
    for i,page in ipairs(p.pages) do if page==id then table.remove(p.pages,i);if not profile and W.Radial then W.Radial:Rebuild() end;return true end end
    return false
end

-- Spell IDs resolve to localized names. Only learned spells are seeded; other
-- classes and custom builds start with an empty, editable wheel.
local starters = {
    PRIEST = { 2061, 139, 17, 2050, 527, 2006 },
    DRUID = { 5185, 774, 8936, 18562, 50769 },
    PALADIN = { 19750, 635, 633, 4987, 7328 },
    SHAMAN = { 8004, 331, 974, 1064, 2008 },
    MONK = { 116670, 115175, 115151, 115178 },
    EVOKER = { 361469, 355936, 364343, 360823 },
}
function D.Info(value)
    if not C_Spell or not C_Spell.GetSpellInfo then return end
    local ok, info = pcall(C_Spell.GetSpellInfo, tonumber(value) or value)
    if ok and not W.Secret(info) and type(info) == "table"
        and not W.Secret(info.name) and not W.Secret(info.iconID) and not W.Secret(info.spellID) then return info end
end
-- Settings sources are rebuilt when opened, never cached across spec/macro edits.
function D.Spells()
    local list, seen = {}, {}
    if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines then return list end
    local bank = Enum.SpellBookSpellBank.Player
    local function add(id, subName)
        local info = id and D.Info(id)
        if not info or seen[info.spellID] then return end
        if C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(info.spellID) then return end
        seen[info.spellID] = true
        list[#list + 1] = { kind = "spell", value = tostring(info.spellID), label = info.name,
            detail = subName or (C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(info.spellID)) or "", icon = info.iconID }
    end
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skill = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if skill and (not skill.offSpecID or skill.offSpecID == 0) and not skill.shouldHide then
            for slot = skill.itemIndexOffset + 1, skill.itemIndexOffset + skill.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                if item and not item.isOffSpec and not item.isPassive then
                    if item.itemType == Enum.SpellBookItemType.Spell then add(item.spellID or item.actionID, item.subName)
                    elseif item.itemType == Enum.SpellBookItemType.Flyout and GetFlyoutInfo and GetFlyoutSlotInfo then
                        local _, _, count, known = GetFlyoutInfo(item.actionID)
                        if known then
                            for i = 1, count do
                                local id, override, learned = GetFlyoutSlotInfo(item.actionID, i)
                                if learned then add(override and override > 0 and override or id) end
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.label == b.label and tonumber(a.value) < tonumber(b.value) or a.label < b.label end)
    return list
end
function D.Macros()
    local list = {}
    if not GetNumMacros or not GetMacroInfo then return list end
    local account, character = GetNumMacros()
    local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    for scope, count in ipairs({ account, character }) do
        for i = 1, count do
            local index = i + (scope == 2 and base or 0)
            local name, icon = GetMacroInfo(index)
            if name then list[#list + 1] = { kind = "saved", value = name, label = name, icon = icon,
                macroScope = scope == 1 and "account" or "character", index = index,
                detail = scope == 1 and W.L["Account"] or W.L["Character"] } end
        end
    end
    return list
end
function D.MacroIndex(action)
    if not action.macroScope then return action.value end -- Existing name-based assignments.
    for _, item in ipairs(D.Macros()) do
        if item.value == action.value and item.macroScope == action.macroScope then return item.index end
    end
end
function D.Key()
    local _, class = UnitClass("player")
    local spec = GetSpecialization and GetSpecialization() or 0
    return (UnitGUID("player") or "character") .. ":" .. (class or "UNKNOWN") .. ":" .. (spec or 0)
end
function D.Init()
    local db = W.db
    if type(db.radial) ~= "table" then db.radial = {} end
    local r = db.radial
    if type(r.profiles) ~= "table" then r.profiles = {} end
    if r.enabled == nil then r.enabled = true end
    if r.defaultR3 == nil then r.defaultR3 = true end
    if r.behavior ~= "classic" and r.behavior ~= "target" then r.behavior = "sweep" end
    if type(r.controls)~="table" then r.controls=nil end
    if r.afterAction ~= "members" and r.afterAction ~= "target" and r.afterAction ~= "close" then r.afterAction = "members" end
    r.size = W.Clamp(tonumber(r.size) or 480, 380, 520)
    if r.health == nil then r.health = true end
    if r.debuffs == nil then r.debuffs = true end
end
function D.Profile()
    local key = D.Key()
    local profile = W.db.radial.profiles[key]
    if type(profile) ~= "table" or type(profile.actions) ~= "table" then
        profile = { actions = {} }; W.db.radial.profiles[key] = profile
        local _, class = UnitClass("player")
        for _, id in ipairs(starters[class] or {}) do
            if IsPlayerSpell and IsPlayerSpell(id) then
                local info = D.Info(id)
                if info then profile.actions[#profile.actions + 1] = { kind = "spell", value = tostring(id), label = info.name, autoLabel = true } end
            end
        end
    end
    for _, action in ipairs(profile.actions) do
        if action.autoLabel and action.kind == "spell" then
            local info = D.Info(action.value)
            if info then action.label = info.name end
        end
    end
    return D.Migrate(profile)
end
function D.Validate(action)
    if type(action) ~= "table" then return nil, W.L["Invalid action."] end
    local label = tostring(action.label or ""):match("^%s*(.-)%s*$")
    local value = tostring(action.value or ""):match("^%s*(.-)%s*$")
    -- Native localized spell names can exceed 48 UTF-8 bytes.
    if #label == 0 or #label > 128 then return nil, W.L["Use a label of 1–128 bytes."] end
    local icon=action.icon
    if icon~=nil and (type(icon)~="number" and type(icon)~="string"
        or type(icon)=="number" and (icon<1 or icon~=math.floor(icon))
        or type(icon)=="string" and (#icon==0 or #icon>260 or icon:find("[|\r\n]"))) then return nil,W.L["Invalid icon."] end
    local function metadata(clean) clean.icon=icon or clean.icon;clean.page=action.page;clean.slot=action.slot;return clean end
    if action.kind=="friendly" then
        for _,preset in ipairs(presets) do if value==preset.value then return metadata({kind="friendly",label=label,value=value,icon=icon or preset.icon}) end end
        return nil,W.L["Invalid action."]
    elseif action.kind == "spell" then
        local info = D.Info(value)
        if not info then return nil, W.L["Enter a valid spell name or ID."] end
        return metadata({ kind = "spell", label = label, value = tostring(info.spellID or value), highestRank=action.highestRank==true or nil, autoLabel = action.autoLabel and label == info.name or nil })
    elseif action.kind == "macro" or action.kind == "custom" then
        if #value == 0 or #value > 255 then return nil, W.L["Recipient macros allow 1–255 bytes."] end
        if action.kind == "macro" and not value:find("{unit}", 1, true) then return nil, W.L["Recipient macros must contain {unit}."] end
        -- Do not run arbitrary Lua or nested UI clicks through a healing entry.
        for line in value:gmatch("[^\r\n]+") do
            local command = line:match("^%s*/([^%s]+)")
            if command and ({ run=true, script=true, click=true, dump=true, console=true })[command:lower()] then
                return nil, W.L["Use spell/item macro commands; Lua and /click are not supported here."]
            end
        end
        return metadata({ kind = action.kind, label = label, value = value })
    elseif action.kind == "saved" then
        local index = D.MacroIndex(action)
        if not index or not GetMacroInfo or not GetMacroInfo(index) then return nil, W.L["Enter the exact name of an existing macro."] end
        return metadata({ kind = "saved", label = label, value = value, macroScope = action.macroScope })
    end
    return nil, W.L["Unknown action type."]
end
function D.Save(index, action, profile)
    if W.Combat() then return false, W.L["Change wheel actions outside combat."] end
    local clean, err = D.Validate(action)
    if not clean then return false, err end
    local p=profile or D.Profile()
    local actions = p.actions
    if index < 1 or index > math.min(#actions + 1, D.maxActions) then return false, W.L["The wheel is full."] end
    local old=actions[index]
    clean.page=clean.page or old and old.page or 0
    clean.slot=clean.slot or old and old.slot
    local slots=D.PageSlots(clean.page,p)
    if not clean.slot then for i=1,8 do if not slots[i] then clean.slot=i;break end end end
    local pageExists=false;for _,id in ipairs(p.pages) do if id==clean.page then pageExists=true end end
    if not pageExists or type(clean.slot)~="number" or clean.slot<1 or clean.slot>8 or clean.slot~=math.floor(clean.slot)
        or slots[clean.slot] and slots[clean.slot]~=index then return false,W.L["Choose an empty slot on this page."] end
    actions[index] = clean
    if not profile and W.Radial then W.Radial:Rebuild() end
    return true
end
-- Validate into a detached copy; one invalid assignment must not save any other
-- pending edit or replace the current secure action snapshot.
function D.SaveProfile(profile)
    if W.Combat() then return false,W.L["Change wheel actions outside combat."] end
    if type(profile)~="table" or type(profile.pages)~="table" or type(profile.actions)~="table"
        or #profile.pages>D.maxPages or #profile.actions>D.maxActions then return false,W.L["Invalid action."] end
    local clean={pages={},actions={}};local pages={}
    for _,id in ipairs(profile.pages)do
        if type(id)~="number" or id~=math.floor(id) or math.abs(id)>4 or pages[id] then return false,W.L["Invalid action."] end
        pages[id]=true;clean.pages[#clean.pages+1]=id
    end
    if not pages[0] then return false,W.L["Invalid action."] end
    table.sort(clean.pages)
    for i,action in ipairs(profile.actions)do
        local ok,err=D.Save(i,action,clean)
        if not ok then return false,W.L.Format("Action %d: %s",i,err) end
    end
    local saved=D.Profile();saved.actions=clean.actions;saved.pages=clean.pages
    if W.Radial then W.Radial:Rebuild() end
    return true
end
function D.SpellInfo(action)
    local info=action and D.Info(action.value)
    if info and action.highestRank then return D.Info(info.name) or info end
    return info
end
function D.Compile(action, unit)
    local clean = D.Validate(action)
    if not clean then return end
    if clean.kind == "spell" then
        local info = D.SpellInfo(clean)
        -- A numeric attribute pins a rank; the native secure handler dispatches
        -- a localized name through CastSpellByName for automatic rank selection.
        return "spell", clean.highestRank and info.name or info.spellID, clean.icon or info.iconID
    elseif clean.kind == "macro" or clean.kind == "custom" then
        local body = clean.value:gsub("{unit}", unit)
        if #body > 255 then return end
        return "macro", body, clean.icon or 134400
    elseif clean.kind=="friendly" then
        local texture=clean.icon
        for _,preset in ipairs(presets) do if preset.value==clean.value then texture=texture or preset.icon end end
        if clean.value=="target" or clean.value=="focus" then return clean.value,unit,texture end
        if clean.value=="trade" then return "macro","/target [@"..unit.."]\n/trade",texture end
        if clean.value=="duel" then return "macro","/duel "..unit,texture end
        return "whisper",unit,texture
    else
        local index = D.MacroIndex(clean)
        local _, icon = GetMacroInfo(index)
        return "saved", index, clean.icon or icon or 134400
    end
end
function D.Snapshot()
    local list, raid, groups = {}, IsInRaid(), {}
    for i = 1, 8 do groups[i] = {} end
    local function add(unit, group)
        if not UnitExists(unit) then return end
        local name = UnitName(unit)
        local className, class = UnitClass(unit)
        if W.Secret(name) or W.Secret(class) or W.Secret(className) then return end
        local member = { unit = unit, name = name or unit, class = class, className = className, group = group }
        list[#list + 1] = member; groups[group][#groups[group] + 1] = #list
    end
    if raid then
        for i = 1, math.min(GetNumGroupMembers(), 40) do
            local _, _, subgroup = GetRaidRosterInfo(i)
            if not W.Secret(subgroup) and subgroup and subgroup >= 1 and subgroup <= 8 then add("raid" .. i, subgroup) end
        end
    else
        add("player", 1)
        for i = 1, 4 do add("party" .. i, 1) end
    end
    return { members = list, raid = raid, groups = groups }
end
