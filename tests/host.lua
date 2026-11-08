-- Deliberately small host for Lua contracts, not a client renderer/security emulator.
local methods = {}
local function object(kind, name, parent)
    local f = setmetatable({ kind=kind, name=name, parent=parent, shown=true, enabled=true, scripts={}, children={}, width=100, height=30, text="", cursor=0, scale=1, attrs={} }, {__index=methods})
    if parent then parent.children[#parent.children+1]=f end
    if name then _G[name]=f end
    return f
end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent=parent end
function methods:GetChildren() return unpack(self.children) end
function methods:IsObjectType(kind) return self.kind==kind end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:IsShown() return self.shown end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetScript(script,fn) self.scripts[script]=fn end
function methods:HookScript(script,fn) local old=self.scripts[script];self.scripts[script]=function(...)if old then old(...)end;fn(...)end end
function methods:GetScript(script) return self.scripts[script] end
function methods:RegisterEvent(event) self.events=self.events or {};self.events[event]=true end
function methods:SetPoint(point,relative,relativePoint,x,y) self.x=x or 0;self.y=y or 0 end
function methods:ClearAllPoints() end
function methods:SetAllPoints() end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetLeft() return self.x or 24 end
function methods:GetBottom() return self.y or 200 end
function methods:GetTop() return self:GetBottom()+self.height end
function methods:GetScale() return self.scale end
function methods:SetScale(s) self.scale=s end
function methods:GetEffectiveScale() return self.scale*(self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetFrameStrata() end
function methods:SetMovable() end
function methods:SetClampedToScreen() end
function methods:StartMoving() end
function methods:StopMovingOrSizing() end
function methods:RegisterForDrag() end
function methods:EnableMouse() end
function methods:EnableGamePadButton(on) assert(not HOST.combat);self.pad=on end
function methods:EnableGamePadStick(on) assert(not HOST.combat);self.stick=on end
function methods:IsGamePadButtonEnabled() return self.pad end
function methods:CreateFontString() return object("FontString",nil,self) end
function methods:CreateTexture() return object("Texture",nil,self) end
function methods:GetFontString() if not self.label then self.label=object("FontString",nil,self) end;return self.label end
function methods:GetFont()
    if self.fontObject then return self.fontObject:GetFont() end
    return self.fontFile or "Fonts\\FRIZQT__.TTF", self.fontHeight or 12, self.fontFlags or ""
end
function methods:SetFont(path,height,flags) self.fontFile=path;self.fontHeight=height;self.fontFlags=flags end
function methods:CopyFontObject(font) self:SetFont(font:GetFont()) end
function methods:SetFontObject(font) self.fontObject=font end
function methods:SetNormalFontObject(font) self.normalFont=font;self:GetFontString():SetFontObject(font) end
function methods:SetHighlightFontObject(font) self.highlightFont=font end
function methods:SetDisabledFontObject(font) self.disabledFont=font end
function methods:SetWordWrap(on) self.wordWrap=on end
function methods:SetAtlas(atlas) self.atlas=atlas end
function methods:SetTexCoord(...) self.texCoords={...} end
function methods:SetHorizTile(on) self.horizTile=on end
function methods:SetVertexColor(...) self.vertexColor={...} end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetTextInsets(...) self.textInsets={...} end
function methods:SetText(s) self.text=s;self.cursor=#s;self.highlight=nil;if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
function methods:ClearHighlightText() self.highlight=nil end
function methods:Insert(value)
    local a,b=self.cursor,self.cursor
    if self.highlight then a,b=self.highlight[1],self.highlight[2] end
    self:SetText(self.text:sub(1,a)..value..self.text:sub(b+1));self:SetCursorPosition(a+#value)
end
function methods:GetText() return self.text end
function methods:GetCursorPosition() return self.cursor end
function methods:SetCursorPosition(n) self.cursor=n;if self.scripts.OnCursorChanged then self.scripts.OnCursorChanged(self) end end
function methods:HighlightText(a,b) self.highlight={a,b} end
function methods:GetAttribute(key) return self.attrs[key] end
function methods:SetAttribute(key,value)
    self.attrs[key]=value
    if key=="chatType" and not self.scripts.OnEnterPressed then self.scripts.OnEnterPressed=HOST.NativeChatEnter end
end
function methods:SetAutoFocus() end
function methods:SetMultiLine(on) self.multi=on end
function methods:IsMultiLine() return self.multi end
function methods:SetMaxBytes(n) self.maxBytes=n end
function methods:GetMaxBytes() return self.maxBytes or 0 end
function methods:GetMaxLetters() return self.maxLetters or 0 end
function methods:GetNumLines() local _,n=self.text:gsub("\n","");return n+1 end
function methods:SetScrollChild(child) self.scrollChild=child end
function methods:SetClipsChildren() end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:SetVerticalScroll(n) self.scroll=n end
function methods:IsNumeric() return self.numeric==true end
function methods:IsPassword() return self.password==true end
function methods:IsForbidden() return false end
function methods:SetFocus()
    if HOST.focus and HOST.focus~=self then HOST.focus:ClearFocus() end
    HOST.focus=self;if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function methods:ClearFocus()
    if HOST.focus==self then HOST.focus=nil;if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end
end
function methods:HasFocus() return HOST.focus==self end
function methods:IsEnabled() return self.enabled end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:SetEnabled(value) self.enabled=value end
-- Forever's button setters require a TextureAsset. Clearing is a separate API;
-- accepting nil here masked a real-client Draw failure at the Focus badge.
for _,state in ipairs({"Normal","Pushed","Highlight"}) do
    local key=state:lower().."Texture"
    methods["Set"..state.."Texture"]=function(self,asset)
        assert(asset~=nil,"Set"..state.."Texture requires a TextureAsset")
        self[key]=asset
    end
    methods["Clear"..state.."Texture"]=function(self) self[key]=nil end
end
for _,name in ipairs({"SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetTexture","SetBlendMode","SetJustifyH","SetAlpha"}) do methods[name]=function()end end
HOST={now=1,focus=nil,combat=false,pad={labelStyle="Xbox",buttons={},sticks={}},keys={},sent={},callbacks={},queue={},nativeEnters={},commands={}}
-- Deliberate native-Enter receiver fixture, not a macro/chat parser emulator.
function HOST.NativeChatEnter(box)
    local text=box:GetText();HOST.nativeEnters[#HOST.nativeEnters+1]=text
    if text:sub(1,1)=="/" then
        local command,args=text:match("^/(%S+)%s*(.*)$")
        if HOST.commands[command] then HOST.commands[command](args,box) end
    elseif text~="" then
        local target=box:GetAttribute("tellTarget")
        if box:GetAttribute("chatType")=="CHANNEL" then target=tostring(box:GetAttribute("channelTarget")) end
        HOST.sent[#HOST.sent+1]={text,box:GetAttribute("chatType"),nil,target}
    end
    box:SetText("");box:ClearFocus();box:Hide()
end
function CreateFrame(kind,name,parent,template) return object(kind,name,parent) end
UIParent=CreateFrame("Frame","UIParent");UIParent:SetSize(1920,1080)
ChatFrame1=CreateFrame("Frame","ChatFrame1",UIParent);ChatFrame1:SetSize(420,160)
function CreateFont(name) return object("Font",name) end
for _,name in ipairs({"GameFontNormal","GameFontNormalSmall","GameFontHighlight","GameFontHighlightLarge","GameFontHighlightSmall","GameFontDisable"})do CreateFont(name) end
function GetTime()return HOST.now end
function InCombatLockdown()return HOST.combat end
function GetCurrentKeyBoardFocus()return HOST.focus end
function IsKeyDown(token)return HOST.keys[token] or false end
function issecretvalue(value)return type(value)=="table" and value.secret==true end
function GetBuildInfo()return "1.60.1","70862","",16001 end
function print()end
Enum={InputDeviceInterfaceType={Gamepad=1,KeyboardAndMouse=0}}
InputUtil={GetCurrentInterfaceStyle=function()return HOST.mode or 1 end}
C_GamePad={GetDeviceMappedState=function()return HOST.pad end}
C_AddOns={IsAddOnLoaded=function(name)return HOST.conflict==name end}
C_ChatInfo={SendChatMessage=function(...) HOST.sent[#HOST.sent+1]={...} end}
C_EditMode={GetLayouts=function()return {activeLayout=1,layouts={{layoutName=HOST.layout or "Modern",layoutType=1}}} end}
C_Timer={After=function(_,fn)HOST.queue[#HOST.queue+1]=fn end}
SlashCmdList={}
EventRegistry={RegisterCallback=function(_,event,fn,owner)HOST.callbacks[event]=HOST.callbacks[event] or {};table.insert(HOST.callbacks[event],{fn,owner})end}
function GetChannelName(target)
    if target==1 or target=="General" then return 1,"General",0,false end
    if target==2 or target=="Trade" then return HOST.tradeID or 2,"Trade",0,false end
    return 0,nil
end
function GetChannelList()return 1,"General",false,2,"Trade",false end
function HOST.Event(event,...)
    for _,cb in ipairs(HOST.callbacks[event] or {})do cb[1](cb[2],...)end
end
function HOST.Field(name,text,numeric,parent)
    local f=CreateFrame("EditBox",name,parent or ChatFrame1);f:SetText(text or "");f.numeric=numeric
    return f
end
function HOST.Press(token)
    local f=WoWEnhancedController.Keyboard.frame
    WoWEnhancedController.Input.waitNeutral=false
    HOST.keys[token]=true
    f:GetScript("OnGamePadButtonDown")(f,token)
    HOST.keys[token]=false
    f:GetScript("OnGamePadButtonUp")(f,token)
end
return HOST
