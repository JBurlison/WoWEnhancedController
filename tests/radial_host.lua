-- Deterministic action/handler CONTRACT MODEL only. This does not emulate
-- Blizzard's taint, protection, native binding delivery, or macro execution.
local M = getmetatable(UIParent).__index
HOST.units = {
    player={name="You",class="PRIEST",group=1}, party1={name="Elowen",class="DRUID",group=1},
    party2={name="Thorne",class="WARRIOR",group=1}, party3={name="Mira",class="MAGE",group=1}, party4={name="Borin",class="PALADIN",group=1},
    target={name="Stoneguard",class="WARRIOR",group=1},
}
HOST.actions = {}; HOST.spec = 1
-- Blizzard's interact HUD reads this shared stack. Fail at the first addon
-- attempt to put a custom group on it, including during startup.
GAMEPAD_STICK_RIGHT="PADRSTICKAXIS"
local function sharedStack() error("addon touched Blizzard's HUD binding stack") end
GamepadSharedUtility={InputBindingManager=setmetatable({}, {__index=sharedStack,__newindex=sharedStack})}
GamepadMode={CreateBindingGroup=sharedStack, IsBindingGroupActive=sharedStack,
    ActivateBindingGroup=sharedStack, DeactivateBindingGroup=sharedStack}
function HOST.Axis(name,x,y)
    for _,child in ipairs(W.Radial.frame.children) do
        local handler=child:GetScript("OnGamepadStick")
        if child:IsVisible() and child:IsGamePadStickEnabled() and handler then
            return handler(child,name,x,y)
        end
    end
    return true
end
-- Model a client that uses the listening frame's propagation flag. Determine
-- the recipient before dispatch: showing/hiding a frame affects the next event.
function HOST.NativeAxis(name, x, y)
    local receiver
    for _, child in ipairs(W.Radial.frame.children) do
        if child:IsVisible() and child:IsGamePadStickEnabled() then
            if not receiver or child.strata == "TOOLTIP" then receiver = child end
        end
    end
    if not receiver then return true end
    local propagate = receiver.propagateKeyboard == true
    receiver:GetScript("OnGamepadStick")(receiver, name, x, y)
    return propagate
end
function UnitExists(unit) return unit and HOST.units[unit] ~= nil end
function UnitName(unit) return unit and HOST.units[unit] and HOST.units[unit].name end
function UnitGUID(unit) return UnitExists(unit) and "guid-"..UnitName(unit) end
function UnitClass(unit) local u=HOST.units[unit];return u and u.class,u and u.class end
function UnitHealth() return 62 end
function UnitHealthMax() return 100 end
function UnitIsConnected(unit) return UnitExists(unit) and not HOST.units[unit].offline end
function UnitIsDeadOrGhost() return false end
function UnitCanAssist(_,unit) return UnitExists(unit) and unit~="target" end
function IsInRaid() return HOST.raid or false end
function IsInGroup() return HOST.raid or HOST.grouped or UnitExists("party1") end
function GetNumGroupMembers() return HOST.raid and 40 or 5 end
function GetRaidRosterInfo(i) local u=HOST.units["raid"..i];return u and u.name,0,u and u.group end
function GetSpecialization() return HOST.spec end
function IsPlayerSpell(id) return id==2061 or id==139 or id==17 end
function GetMacroInfo(name) if name=="My heal" then return name,134400,"/cast [@focus] Renew" end end
C_Spell={GetSpellInfo=function(value)
    local spells={ [2061]="Flash Heal",[139]="Renew",[17]="Power Word: Shield" }
    for id,name in pairs(spells) do
        if value==id or value==name then return {spellID=id,name=name,iconID=135907} end
    end
end}
function M:SetShown(on) if on then self:Show() else self:Hide() end end
function M:SetRotation(value) self.rotation=value end
function M:SetStatusBarTexture(value)self.statusTexture=value end
function M:SetStatusBarColor(...)self.statusColor={...}end
function M:SetMinMaxValues(low,high)self.range={low,high}end
function M:SetValue(value)self.value=value end
function M:SetFormattedText(fmt,...)
    self.formatted={format=fmt,values={...}}
    for i=1,select("#",...)do
        if issecretvalue(select(i,...)) then self.text="<native secret text>";return end
    end
    self:SetText(string.format(fmt,...))
end
function M:Click(button,down)
    assert(not self.restrictedClick or issecure(),"Cannot call restricted closure from insecure code")
    self.clickCalls=(self.clickCalls or 0)+1
    self:GetScript("OnClick")(self,button or "LeftButton",down or false)
end
function issecure()return HOST.secureAxis==true end
C_RestrictedActions={CheckAllowProtectedFunctions=function()
    if HOST.axisAllowed~=nil then return HOST.axisAllowed end
    return not HOST.combat
end}
function M:SetFrameRef(key,value) self.refs=self.refs or {};self.refs[key]=value end
function M:GetFrameRef(key) return self.refs and self.refs[key] end
function M:SetBindingClick(_,key,name,button) self.binds=self.binds or {};self.binds[key]={name,button} end
function M:ClearBindings() self.binds={} end
function M:CallMethod(name,...) if self[name] then self[name](self,...) end end
local function environment(control)
    return {control=control,abs=math.abs,min=math.min,max=math.max,ceil=math.ceil,floor=math.floor,
        atan2=function(x,y)return math.deg(math.atan2(x,y))end,
        sin=function(a)return math.sin(math.rad(a))end,cos=function(a)return math.cos(math.rad(a))end,
        UnitExists=UnitExists,PlayerCanAssist=function(unit)return UnitCanAssist("player",unit)end,
        GetGamePadState=function()return HOST.pad end,tonumber=tonumber,tostring=tostring,type=type,
        math=math,string=string,gmatch=string.gmatch}
end
local function run(control, body, self, ...)
    -- Native BuildRestrictedClosure rejects these even inside comments.
    assert(not body:find("function",1,true),"The function keyword is not permitted")
    assert(not body:find("[{}]"),"Direct table creation is not permitted")
    local fn=assert(loadstring("return function(self,...) "..body.." end"))()
    -- RestrictedExecution.BuildRestrictedClosure preserves only its special
    -- self handle; scrub(...) removes handles/tables from ordinary arguments.
    local args,n={...},select("#",...)
    for i=1,n do
        local kind=type(args[i])
        if kind=="table" or kind=="userdata" or kind=="function" or kind=="thread" then args[i]=nil end
    end
    setfenv(fn,environment(control));return fn(self,unpack(args,1,n))
end
function M:RunAttribute(key,...) return run(self,self:GetAttribute(key),self,...) end
function SecureHandlerExecute(frame,body) return run(frame,body,frame) end
function SecureHandlerSetFrameRef(frame,key,value) frame:SetFrameRef(key,value) end
function M:RegisterForClicks(...) self.clicks={...} end
function SecureHandlerWrapScript(button,script,hub,pre,post)
    if script=="OnClick"then button.restrictedClick=true end
    local old=button:GetScript(script)
    button:SetScript(script,function(self,key,down)
        local fn=assert(loadstring("return function(self,button,down) "..pre.." end"))()
        setfenv(fn,environment(hub))
        local newkey,message=fn(self,key,down)
        if newkey==false then return end
        if old then old(self,newkey or key,down) end
        if post and message~=nil then
            local done=assert(loadstring("return function(self,message,button,down) "..post.." end"))()
            setfenv(done,environment(hub));done(self,message,newkey or key,down)
        end
    end)
end
function RegisterStateDriver(frame,key) frame:SetAttribute("state-"..key,"ready") end
function SetOverrideBindingClick(frame,priority,key,name,button) frame:SetBindingClick(priority,key,name,button) end
function ClearOverrideBindings(frame) frame:ClearBindings() end
local create=CreateFrame
function CreateFrame(kind,name,parent,template)
    local frame=create(kind,name,parent,template)
    if template and template:find("SecureActionButtonTemplate",1,true) then
        frame:SetScript("OnClick",function(self,button,down)
            if down then return end
            local kind=self:GetAttribute("type")
            if not kind then return end
            HOST.actions[#HOST.actions+1]={kind=kind,unit=self:GetAttribute("unit"),spell=self:GetAttribute("spell"),macro=self:GetAttribute("macro"),body=self:GetAttribute("macrotext")}
            if kind=="target" then HOST.units.target=HOST.units[self:GetAttribute("unit")] end
        end)
    end
    return frame
end
function HOST.WheelPress(key,index)
    local b=index and W.Radial.cells[index] or W.Radial.dispatch
    b:GetScript("OnClick")(b,key or "LeftButton",true)
    b:GetScript("OnClick")(b,key or "LeftButton",false)
end
function HOST.StickEdge(key, down, x, y)
    local wheel = W.Radial.frame
    HOST.pad.sticks = {{x=0,y=0,len=0}, {x=x,y=y,len=math.sqrt(x*x+y*y)}}
    local binding = assert(wheel.binds[key], "missing direction binding: "..key)
    local button = _G[binding[1]]
    button:GetScript("OnClick")(button,binding[2],down)
end
function HOST.Raid()
    HOST.raid=true
    for i=1,40 do HOST.units["raid"..i]={name="Member"..i,class="PRIEST",group=math.ceil(i/5)} end
    W.Radial:Rebuild()
end
