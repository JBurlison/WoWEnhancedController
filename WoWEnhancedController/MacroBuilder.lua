local _, W = ...
local E,C,T,D,L,S=W.MacroEditor,W.MacroCompiler,W.MacroTemplates,W.MacroData,W.L,W.MacroStyle
local kinds={cast="Conditional spell",sequence="Cast sequence",item="Trinket",command="Utility action",raw="Custom commands"}
local targets={{"target","Current target"},{"player","Yourself"},{"focus","Focus"},{"mouseover","Mouseover"},{"pet","Pet"},{"cursor","Ground cursor"},
    {"party1","Party member 1"},{"party2","Party member 2"},{"party3","Party member 3"},{"party4","Party member 4"}}
local modifiers={{"any","Any modifier"},{"nomod","No modifier"},{"shift","Shift"},{"ctrl","Control"},{"alt","Alt"}}
local commands={{"startattack","Start attack"},{"stopattack","Stop attack"},{"stopcasting","Stop casting"},{"petattack","Pet attack"},{"petpassive","Pet passive"},
    {"petfollow","Pet follow"},{"cancelform","Leave form"},{"cancelaura","Cancel buff"},{"equipslot","Equip weapon"},{"dismount","Dismount"},{"assist","Assist target"},{"focus","Set focus"},{"clearfocus","Clear focus"}}
local starters={{"cast","Cast a spell","Pick a spell, then add targets and conditions.","Interface\\Icons\\Spell_Holy_Renew"},
    {"sequence","Cast sequence","A different spell on each press.","Interface\\Icons\\INV_Misc_PocketWatch_01"},
    {"templates","Browse templates","Start from a ready-made macro for your class.","Interface\\Icons\\INV_Misc_Book_09"},
    {"raw","Custom commands","Type the macro text yourself.","Interface\\Icons\\INV_Misc_Note_01"}}
local function title(options,value)
    for _,v in ipairs(options) do if v[1]==value then return L[v[2]] end end
    return tostring(value or "")
end
function E:SelectValue(caption,options,value,set,help,viewOnly)
    local entries={};for _,v in ipairs(options) do entries[#entries+1]={label=(value==v[1] and "• " or "")..L[v[2]],run=function()set(v[1]);if not viewOnly then self:Changed()end;self:Draw()end} end
    self:Choose(caption,entries,help)
end
function E:Spell(entry)
    local choices={}
    for _,spell in ipairs(self.catalog or {}) do
        local name=spell.label;local detail=spell.detail or ""
        choices[#choices+1]={label=W.Escape(name..(detail~="" and " · "..detail or "")),search=name.." "..detail.." "..spell.value,run=function()
            entry.spellID=tonumber(spell.value);self:Changed();self:Draw()
        end}
    end
    self:Choose(L["Choose a learned spell"],choices,L["Select a spell, then choose highest rank or the selected rank."],nil,true)
end
function E:SpellLabel(entry)
    local name=C.Spell(entry,self.catalog)
    return name and W.Escape(name) or L["Choose a learned spell"]
end
function E:DrawTemplates()
    self.category=self.category or "class"
    if not self.class then local _,class=UnitClass("player");self.class=class or "PRIEST" end
    self:Dropdown("template-category",title(T.categories,self.category),252,202,260,function()
        self:SelectValue(L["Template category"],T.categories,self.category,function(value)self.category=value end,nil,true)
    end)
    local classes={};for _,class in ipairs(T.classes) do classes[#classes+1]={class,(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class} end
    self:Dropdown("template-class",title(classes,self.class),528,202,260,function()
        self:SelectValue(L["Class"],classes,self.class,function(value)self.class=value end,nil,true)
    end):SetEnabled(self.category=="class")
    local list=T.Filter(self.category,self.class)
    self:List("templates",list,252,254,536,348,84,76,function(entry,i,parent,width,y)
        local b=self:Button("template-"..entry.id,L[entry.title],0,y,width,function()
            self:Choose(L[entry.title],{{label=L["Use template"],run=function()
                self:Guard(function()
                    self.model=T.Model(entry,self.scope);self.snapshot=nil;self.dirty=true;self.detail=nil;self.rule=nil;self.tab="build";self:Draw()
                end)
            end}},L[entry.description].." "..L["Replace unavailable spells before saving."])
        end,76,parent)
        local first=entry.blocks[1];local spell=first and ((first.rules or first.steps or {})[1]);local info=spell and spell.spellID and W.RadialData.Info(spell.spellID)
        return S.Card(b,L[entry.description],info and info.iconID or 134400)
    end,self.category..":"..self.class)
end
function E:AddBlock(kind)
    local block=T.Action(kind)
    self.model.blocks[#self.model.blocks+1]=block;self.detail=#self.model.blocks;self.rule=nil;self:Changed();self:Draw()
    return block
end
function E:AddAction()
    local entries={};for _,kind in ipairs({"cast","sequence","item","command","raw"}) do entries[#entries+1]={label=L[kinds[kind]],run=function()self:AddBlock(kind)end} end
    self:Choose(L["Add action"],entries,L["Separate action lines run on the same press. A cast sequence advances on successive presses."])
end
function E:BlockTitle(block)
    if block.kind=="cast" then
        local rules=block.rules or {};local text=L["Cast"]..": "..self:SpellLabel(rules[1])
        return #rules>1 and text.."  +"..(#rules-1) or text
    elseif block.kind=="sequence" then
        local names={}
        for i,step in ipairs(block.steps or {}) do
            if i>3 then names[#names+1]="…";break end
            names[#names+1]=self:SpellLabel(step)
        end
        return L["Sequence"]..": "..table.concat(names," > ")
    elseif block.kind=="item" then return L[block.slot==13 and "Upper trinket (13)" or "Lower trinket (14)"]
    elseif block.kind=="command" then return title(commands,block.verb) end
    return L["Custom commands"]
end
function E:DrawBuilder()
    if self.detail and self.model.blocks[self.detail] then self:DrawAction();return end
    self:Button("tooltip",self.model.tooltip and L["Tooltip: automatic"] or L["Tooltip: off"],252,202,260,function()self.model.tooltip=not self.model.tooltip;self:Changed();self:Draw()end)
    self:Dropdown("add-action",L["Add action"],528,202,260,function()self:AddAction()end)
    if #self.model.blocks==0 then
        -- An empty draft offers starting points instead of an instruction.
        self:Label(L["What should this macro do?"],252,262,536,30):SetFontObject(S.Font("GameFontNormal",2))
        for i,starter in ipairs(starters) do
            local kind=starter[1]
            local b=self:Button("starter-"..kind,L[starter[2]],252+((i-1)%2)*276,304+math.floor((i-1)/2)*96,260,function()
                if kind=="templates" then self:Tab("templates");return end
                local block=self:AddBlock(kind)
                if kind=="cast" and block.rules and block.rules[1] then self:Spell(block.rules[1]) end
            end,84)
            S.Card(b,L[starter[3]],starter[4])
        end
        return
    end
    self:List("actions",self.model.blocks,252,254,536,348,66,58,function(block,index,parent,width,y)
        local text=C.Block(block,self.catalog)
        local b=self:Button("action"..index,index..". "..self:BlockTitle(block),0,y,width,function()self.detail=index;self.rule=nil;self:Draw()end,58,parent)
        local spell=(block.rules or block.steps or {})[1];local info=spell and spell.spellID and W.RadialData.Info(spell.spellID)
        return S.Card(b,text and S.Code(text) or "|cffff9040"..L["Choose a spell or configure this action."].."|r",info and info.iconID or 134400)
    end,self.model.blocks)
end
function E:DrawAction()
    local index=self.detail;local block=self.model.blocks[index]
    if self.rule and block.kind=="cast" and block.rules[self.rule] then self:DrawRule(block.rules[self.rule]);return end
    self:Button("action-back",L["Back to actions"],252,202,260,function()self.detail=nil;self:Draw()end)
    self:Button("simulate",L["Try a scenario"],528,202,260,function()self:Simulation(block)end)
    self:Label(index..". "..L[kinds[block.kind] or "Custom commands"],252,248,536,30)
    if block.kind=="cast" or block.kind=="sequence" then
        local entries=block.kind=="cast" and block.rules or block.steps
        if block.kind=="sequence" then
            self:Label(L["One step per successful press. Failed casts stay on the current step."],252,282,536,54)
            self:Dropdown("sequence-settings",L["Target and reset rules"],252,340,260,function()self:SequenceSettings(block)end)
        else
            self:Label(L["First matching condition wins; a failed cast does not try the next alternative."],252,280,536,55)
        end
        self:Button("add-step",L[block.kind=="cast" and "Add alternative" or "Add step"],528,340,260,function()
            entries[#entries+1]=block.kind=="cast" and {target="target",relation="harm",alive=true} or {}
            self:Changed();self:Spell(entries[#entries])
        end)
        self:List("steps",entries,252,388,536,200,52,44,function(entry,n,parent,width,y)
            local b=self:Button("step"..n,n..". "..self:SpellLabel(entry),0,y,width,function()
                if block.kind=="cast" then self.rule=n;self:Draw() else self:StepOptions(block,n) end
            end,44,parent)
            local info=entry.spellID and W.RadialData.Info(entry.spellID)
            return S.Card(b,nil,info and info.iconID or 134400)
        end,entries)
    elseif block.kind=="raw" then
        self:Field("raw-action",block.text,252,290,536,244,true,function(value)block.text=value;self:Changed()end)
        self:Label(L["Custom commands are preserved exactly. No automatic parsing or rewriting."],252,544,536,54)
    elseif block.kind=="item" then
        self:Button("item-slot",L[block.slot==13 and "Upper trinket (13)" or "Lower trinket (14)"],252,298,536,function()block.slot=block.slot==13 and 14 or 13;self:Changed();self:Draw()end)
        self:Label(L["Uses the currently equipped item. Combining it with a spell depends on cooldown rules."],252,352,536,100)
    elseif block.kind=="command" then
        self:Dropdown("command-kind",title(commands,block.verb),252,290,536,function()self:SelectValue(L["Utility action"],commands,block.verb,function(value)block.verb=value;block.arg=""end)end)
        self:Dropdown("command-mod",title(modifiers,block.modifier or "any"),252,340,536,function()self:SelectValue(L["Modifier"],modifiers,block.modifier,function(value)block.modifier=value end)end)
        self:Label(L["Argument (item, buff or unit name)"],252,396,536,30)
        self:Field("argument",block.arg,252,432,536,48,false,function(value)block.arg=value;self:Changed()end)
        self:Label(L["For equipment, enter slot 16 or 17 followed by the item name. Leave other arguments empty when unnecessary."],252,494,536,90)
    end
    self:Button("move-up",L["Move up"],252,608,172,function()
        if index>1 then self.model.blocks[index],self.model.blocks[index-1]=self.model.blocks[index-1],block;self.detail=index-1;self:Changed();self:Draw()end
    end):SetEnabled(index>1)
    self:Button("move-down",L["Move down"],434,608,172,function()
        if index<#self.model.blocks then self.model.blocks[index],self.model.blocks[index+1]=self.model.blocks[index+1],block;self.detail=index+1;self:Changed();self:Draw()end
    end):SetEnabled(index<#self.model.blocks)
    self:Button("remove-action",L["Remove action"],616,608,172,function()table.remove(self.model.blocks,index);self.detail=nil;self.rule=nil;self:Changed();self:Draw()end)
end
function E:StepOptions(block,index)
    local entry=block.steps[index]
    local entries={
        {label=L["Choose spell"],dropdown=true,run=function()self:Spell(entry)end},
        {label=L[entry.ranked and "Rank: selected" or "Rank: highest"],run=function()entry.ranked=not entry.ranked;self:Changed();self:Draw()end}}
    if index>1 then entries[#entries+1]={label=L["Move up"],run=function()block.steps[index],block.steps[index-1]=block.steps[index-1],entry;self:Changed();self:Draw()end} end
    if index<#block.steps then entries[#entries+1]={label=L["Move down"],run=function()block.steps[index],block.steps[index+1]=block.steps[index+1],entry;self:Changed();self:Draw()end} end
    entries[#entries+1]={label=L["Remove step"],run=function()table.remove(block.steps,index);self:Changed();self:Draw()end}
    self:Choose(self:SpellLabel(entry),entries,L["Highest rank uses the spell name. Selected rank includes the learned rank explicitly."])
end
function E:SequenceSettings(block)
    self:Choose(L["Sequence rules"],{
        {label=L["Target"]..": "..title(targets,block.target),dropdown=true,run=function()
            local options={};for _,v in ipairs(targets) do if v[1]~="cursor" then options[#options+1]=v end end
            self:SelectValue(L["Target"],options,block.target,function(v)block.target=v end)
        end},
        {label=L["Reset when target changes"]..": "..L[block.resetTarget and "On" or "Off"],run=function()block.resetTarget=not block.resetTarget;self:Changed();self:SequenceSettings(block)end},
        {label=L["Reset when combat ends"]..": "..L[block.resetCombat and "On" or "Off"],run=function()block.resetCombat=not block.resetCombat;self:Changed();self:SequenceSettings(block)end},
        {label=L.Format("Idle reset: %s seconds",tostring(block.resetSeconds or 0)),dropdown=true,run=function()
            self:Choose(L["Idle reset"],{{label=L["No timeout"],run=function()block.resetSeconds=0;self:Changed();self:Draw()end},
                {label=L["5 seconds"],run=function()block.resetSeconds=5;self:Changed();self:Draw()end},
                {label=L["10 seconds"],run=function()block.resetSeconds=10;self:Changed();self:Draw()end},
                {label=L["30 seconds"],run=function()block.resetSeconds=30;self:Changed();self:Draw()end}},L["The timer restarts on each attempted press. This is not a delay between spells."])
        end},
        {label=L["Reset modifier"]..": "..L[block.resetModifier or "none"],dropdown=true,run=function()
            self:SelectValue(L["Reset modifier"],{{"none","None"},{"shift","Shift"},{"ctrl","Control"},{"alt","Alt"}},block.resetModifier,function(v)block.resetModifier=v end)
        end}},L["Each successful press advances one step. A failed cast stays on that step. Sequences cannot wait or choose the next ready spell."])
end
function E:DrawRule(rule)
    self:Button("rule-back",L["Back to alternatives"],252,202,536,function()self.rule=nil;self:Draw()end)
    self:Dropdown("rule-spell",self:SpellLabel(rule),252,252,536,function()self:Spell(rule)end,44)
    self:Button("rule-rank",L[rule.ranked and "Rank: selected" or "Rank: highest"],252,314,260,function()rule.ranked=not rule.ranked;self:Changed();self:Draw()end)
    self:Dropdown("rule-target",title(targets,rule.target or "target"),528,314,260,function()self:SelectValue(L["Target"],targets,rule.target,function(v)rule.target=v end)end)
    self:Dropdown("rule-mod",title(modifiers,rule.modifier or "any"),252,368,260,function()
        self:SelectValue(L["Modifier"],modifiers,rule.modifier,function(v)rule.modifier=v end,L["Shift, Control and Alt use your game modifier bindings. Assign controller modifiers in WoW settings."])
    end)
    local relations={{"any","Any target"},{"help","Friendly target"},{"harm","Hostile target"},{"exists","Target exists"}}
    self:Dropdown("rule-relation",title(relations,rule.relation or "any"),528,368,260,function()self:SelectValue(L["Target condition"],relations,rule.relation,function(v)rule.relation=v end)end)
    self:Button("rule-alive",L[rule.alive and "Alive only" or "Alive or dead"],252,422,260,function()rule.alive=not rule.alive;self:Changed();self:Draw()end)
    local combats={{"any","Any combat state"},{"combat","In combat"},{"nocombat","Out of combat"}}
    self:Dropdown("rule-combat",title(combats,rule.combat or "any"),528,422,260,function()self:SelectValue(L["Combat condition"],combats,rule.combat,function(v)rule.combat=v end)end)
    local forms={};for _,v in ipairs(D.Forms()) do forms[#forms+1]={v.value,v.label} end
    self:Dropdown("rule-form",title(forms,rule.form or false),252,476,536,function()self:SelectValue(L["Form / stance"],forms,rule.form,function(v)rule.form=v or nil end)end)
    local rules=self.model.blocks[self.detail].rules;local index=self.rule
    self:Button("rule-up",L["Move up"],252,550,172,function()rules[index],rules[index-1]=rules[index-1],rule;self.rule=index-1;self:Changed();self:Draw()end):SetEnabled(index>1)
    self:Button("rule-down",L["Move down"],434,550,172,function()rules[index],rules[index+1]=rules[index+1],rule;self.rule=index+1;self:Changed();self:Draw()end):SetEnabled(index<#rules)
    self:Button("rule-remove",L["Remove alternative"],616,550,172,function()table.remove(rules,index);self.rule=nil;self:Changed();self:Draw()end)
end
function E:Simulation(block)
    local scenario={modifier="none",target="harm",focus="none",mouseover="none",pet="help",party1="help",party2="help",party3="help",party4="help",combat="nocombat",form=0}
    local state={index=1};local output=L["Educational preview. Set a scenario, then simulate a press. No commands are executed."]
    local show
    local function simulate(failed,event)scenario.failed=failed;scenario.event=event;output,state=C.Preview(block,scenario,state,self.catalog);show()end
    local function cycle(key,values)
        local index=1;for i,v in ipairs(values) do if v==scenario[key]then index=i end end
        scenario[key]=values[index%#values+1];show()
    end
    show=function()
        local entries={{label=L["Simulate successful cast"],run=function()simulate(false)end},{label=L["Simulate failed cast"],run=function()simulate(true)end}}
        if block.kind=="sequence" then
            entries[#entries+1]={label=L["Target changed"],run=function()simulate(false,"target")end}
            entries[#entries+1]={label=L["Combat ended"],run=function()simulate(false,"combat")end}
            entries[#entries+1]={label=L["Idle timeout elapsed"],run=function()simulate(false,"idle")end}
        end
        local states={none="No unit",help="Friendly",harm="Hostile",dead="Dead",combat="In combat",nocombat="Out of combat"}
        for _,key in ipairs({"target","focus","mouseover","pet","party1","party2","party3","party4"}) do
            entries[#entries+1]={label=title(targets,key)..": "..L[states[scenario[key]]],run=function()cycle(key,{"none","help","harm","dead"})end}
        end
        entries[#entries+1]={label=L["Modifier"]..": "..L[scenario.modifier],run=function()cycle("modifier",{"none","shift","ctrl","alt"})end}
        entries[#entries+1]={label=L["Combat condition"]..": "..L[states[scenario.combat]],run=function()cycle("combat",{"nocombat","combat"})end}
        entries[#entries+1]={label=L["Form / stance"]..": "..scenario.form,run=function()cycle("form",{0,1,2,3,4,5})end}
        self:Choose(L["Try a scenario"],entries,output)
    end
    show()
end
