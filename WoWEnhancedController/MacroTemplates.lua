local _, W = ...
local T = { list = {} }
W.MacroTemplates=T
T.categories={{"class","Class specific"},{"targeting","Targeting / healing"},{"modifiers","Modifiers / ranks"},
    {"sequence","Cast sequences"},{"gear","Items / equipment"},{"pets","Pets / forms"},{"utility","Utility"}}
T.classes={"PRIEST","WARRIOR","PALADIN","HUNTER","ROGUE","SHAMAN","MAGE","WARLOCK","DRUID"}
local function rule(id,extra)
    local r={spellID=id,target="target",relation="harm",alive=true,modifier="any",combat="any"}
    for k,v in pairs(extra or {}) do r[k]=v end;return r
end
local function cast(...) return {kind="cast",rules={...}} end
local function seq(ids,target)
    local steps={};for _,id in ipairs(ids) do steps[#steps+1]={spellID=id>0 and id or nil} end
    return {kind="sequence",steps=steps,target=target or "player",resetTarget=true,resetSeconds=10,resetModifier="none"}
end
local function cmd(verb,arg,modifier) return {kind="command",verb=verb,arg=arg or "",modifier=modifier or "any"} end
local function add(id,title,category,class,description,blocks)
    T.list[#T.list+1]={id=id,title=title,category=category,class=class,description=description,blocks=blocks,
        target="forever",sourceVersion="1.60.1.70862"}
end
add("priest-buffs","Priest buffs","sequence","PRIEST","Apply two buffs with successive presses.",{seq({1243,976})})
add("priest-dual","Friendly / hostile","targeting","PRIEST","Choose a heal or damage spell by target.",{cast(rule(139,{relation="help"}),rule(585))})
add("warrior-attack","Melee opener","utility","WARRIOR","Start attacking and attempt your chosen ability.",{cmd("startattack"),cast(rule(7386))})
add("warrior-combat","Charge / taunt","modifiers","WARRIOR","Separate out-of-combat and combat actions.",{cast(rule(100,{combat="nocombat"}),rule(355,{combat="combat"}))})
add("paladin-heal","Target / self heal","targeting","PALADIN","Heal a friendly target, otherwise yourself.",{cast(rule(635,{relation="help"}),rule(635,{target="player",relation="any",alive=false}))})
add("paladin-cleanse","Focus cleanse","targeting","PALADIN","Choose a friendly focus before your target.",{cast(rule(4987,{target="focus",relation="help"}),rule(4987,{relation="help"}))})
add("hunter-pet","Pet and shot","pets","HUNTER","Send your pet and attempt a shot on one press.",{cmd("petattack"),cast(rule(3044))})
add("hunter-sequence","Mark / sting","sequence","HUNTER","A two-step opener with a target reset.",{seq({1130,1978},"target")})
add("rogue-focus","Focus kick","targeting","ROGUE","Shift selects focus; otherwise use your target.",{cast(rule(1766,{modifier="shift",target="focus"}),rule(1766,{modifier="nomod"}))})
add("rogue-attack","Start melee","utility","ROGUE","Begin attacking and attempt your melee ability.",{cmd("startattack"),cast(rule(1752))})
add("shaman-rank","Shock rank choice","modifiers","SHAMAN","Shift chooses rank 1; otherwise highest rank.",{cast(rule(8042,{modifier="shift",ranked=true}),rule(8042,{modifier="nomod"}))})
add("shaman-heal","Two healing choices","modifiers","SHAMAN","Shift chooses a different healing spell.",{cast(rule(8004,{modifier="shift",relation="help"}),rule(331,{modifier="nomod",relation="help"}))})
add("mage-interrupt","Focus interrupt","targeting","MAGE","Interrupt focus with Shift, or current target.",{cast(rule(2139,{modifier="shift",target="focus"}),rule(2139,{modifier="nomod"}))})
add("mage-ground","Ground cursor cast","targeting","MAGE","Place a ground spell at the current cursor.",{cast(rule(10,{target="cursor",relation="any",alive=false}))})
add("warlock-fear","Focus control","targeting","WARLOCK","Use an enemy focus, otherwise an enemy target.",{cast(rule(5782,{target="focus"}),rule(5782))})
add("warlock-pet","Pet and bolt","pets","WARLOCK","Send your pet and attempt a spell.",{cmd("petattack"),cast(rule(686))})
add("druid-buffs","Druid buffs","sequence","DRUID","Apply your buffs on successive presses.",{seq({1126,467})})
add("druid-heal","Three target heal","targeting","DRUID","Mouseover, then friendly target, then yourself.",{cast(rule(5185,{target="mouseover",relation="help"}),rule(5185,{relation="help"}),rule(5185,{target="player",relation="any",alive=false}))})
add("generic-sequence","Build a sequence","sequence",nil,"Pick spells, reorder steps and choose resets.",{seq({0,0})})
add("generic-alternate","Modifier alternatives","modifiers",nil,"Put two choices on the same button.",{cast(rule(nil,{modifier="shift"}),rule(nil,{modifier="nomod"}))})
add("trinket","Equipped trinket","gear",nil,"Use the item in your upper trinket slot.",{{kind="item",slot=13}})
add("trinket-spell","Trinket plus spell","gear",nil,"Attempt a trinket before a spell; cooldown rules apply.",{{kind="item",slot=13},cast(rule())})
add("weapon","Weapon slot","gear",nil,"Choose a main-hand or off-hand item.",{cmd("equipslot")})
add("pet-return","Recall pet","pets",nil,"Stop pet aggression and call it back.",{cmd("petpassive"),cmd("petfollow")})
add("leave-form","Leave form","pets",nil,"Exit your current shapeshift form.",{cmd("cancelform")})
add("cancel-buff","Cancel a buff","utility",nil,"Choose the buff to remove when Shift is held.",{cmd("cancelaura","","shift")})
add("assist","Assist focus","utility",nil,"Switch to your focus's target.",{{kind="raw",text="/assist [@focus,exists]"}})
add("wheel","Open party wheel","utility",nil,"Toggle the Enhanced Controller party wheel.",{{kind="raw",text="/click WoWEnhancedControllerWheelToggle"}})
function T.Filter(category,class)
    local result={}
    for _,entry in ipairs(T.list) do
        if category=="class" and entry.class==class or category~="class" and entry.category==category then result[#result+1]=entry end
    end
    return result
end
function T.Model(entry,scope)
    local name=W.L[entry.title]
    local chars=W.Locale.Characters(name);while #chars>16 do table.remove(chars) end
    return {name=table.concat(chars),scope=scope or "account",icon=134400,tooltip=entry.id~="assist" and entry.id~="wheel",
        blocks=W.Copy(entry.blocks),templateID=entry.id}
end
function T.Action(kind)
    if kind=="cast" then return cast(rule()) end
    if kind=="sequence" then return seq({0}) end
    if kind=="item" then return {kind="item",slot=13} end
    if kind=="command" then return cmd("startattack") end
    return {kind="raw",text=""}
end
