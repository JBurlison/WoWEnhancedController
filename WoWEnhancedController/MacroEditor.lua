local _, W = ...
local E = {scope="account",tab="build",pools={},scrollPositions={}}
W.MacroEditor=E
local L,C,D,T,S=W.L,W.MacroCompiler,W.MacroData,W.MacroTemplates,W.MacroStyle
local function fold(value)
    local chars={};for _,char in ipairs(W.Locale.Characters(value or "")) do chars[#chars+1]=W.Locale.Upper(char) end
    return table.concat(chars)
end

-- Ordinary addon UI only. No macro execution, global binding changes or
-- protected action simulation lives in this editor.
function E:Status(text) self.message=text; if self.status then self.status:SetText(text or "") end end
function E:Changed() self.dirty=true;self.message=nil;self:Preview() end
function E:ClearFields()
    local session=W.Keyboard.session
    if session and session.target.wecMacro then W.Keyboard:Close() end
    for _,box in ipairs(self.pools.field or {}) do box:ClearFocus() end
end
function E:Eligible()
    local focus=W.Focus()
    return self.frame and self.frame:IsVisible() and not self.disconnected and not W.Combat() and W.db.enabled
        and (not focus or focus.wecMacro)
        and not W.Input.active and not (W.IconPicker and W.IconPicker.request)
        and not W.Blocker() and not (SettingsPanel and SettingsPanel:IsShown())
        and not W.Placement.editing and not (W.Keyboard.frame and W.Keyboard.frame:IsShown())
end
function E:BindControls()
    local keys, focus = W.Input.keys, W.UIFocusBindings()
    local controls = { PADDUP="up", PADDDOWN="down", PADDLEFT="left", PADDRIGHT="right" }
    local signature = {}
    for _, action in ipairs({ "primary", "back", "phrasesLeft", "phrasesRight", "delete", "shift", "library", "phrases", "focus" }) do
        local key = keys[action] or ""
        signature[#signature + 1] = key
        if key ~= "" then controls[key] = action end
    end
    return W.BindMenuControls(self, "MacroEditor", controls, focus, table.concat(signature, "|") .. "|" .. table.concat(focus, "|"))
end
function E:RequestFocus()
    if not self:Eligible() then return false end
    if not self:BindControls() then return false end
    self.held=nil;self.reorder=nil;self.focusRequested=true;self:RevealControl(self.controls[self.selected]);self:Focus();return true
end
function E:SyncControls(refresh)
    if not self:Eligible() then
        if self.boundSignature then W.ReleaseMenuControls(self); self:Focus() end
    elseif not self.boundSignature then
        self:RequestFocus()
    elseif refresh then
        if self:BindControls() then self.focusRequested=true end
        self:Focus()
    end
end
function E:Focus(id)
    if id and self.controls[id] then self.selected=id;self:RevealControl(self.controls[id]) end
    local selected=self.controls[self.selected]
    if not selected or not selected:IsEnabled() then
        self.selected=nil
        for _,b in ipairs(self.order) do if b:IsEnabled() then self.selected=b.id;break end end
    end
    for _,b in ipairs(self.order) do
        local on=b.id==self.selected and self:ControlVisible(b) and self:Eligible() and self.focusRequested == true
        b.focus:SetShown(on and not b.card)
        if b.prompt then
            local hint=on and "primary" or b.shortcut
            W.Theme.Prompt(b,hint and {hint} or {},"corner")
        end
        if b.edge then S.Selected(b,on);S.Paint(b) end
    end
    if self.focusButton then W.Theme.FocusBadge(self.focusButton, self.focusKey or W.Input.keys.focus) end
    if self.preview and not self.drawing and self:FocusedBlock()~=self.previewFocus then self:PaintPreview() end
    self:PaintFooter()
end
function E:PaintFooter()
    if not self.footer then return end
    local keys=W.Input.keys
    local function glyph(action)
        if not keys[action] or keys[action]=="" then return "" end
        local atlas=W.Input:Icon(action)
        return atlas and "|A:"..atlas..":30:30|a" or W.Input:Hint(action)
    end
    self.leftBumper:SetText(not self.modal and glyph("phrasesLeft") or "")
    self.rightBumper:SetText(not self.modal and glyph("phrasesRight") or "")
    local parts={L["Move with D-pad"],glyph("primary").." "..L["Select"]}
    local function add(action,text,gold)
        if (keys[action] or "")~="" then parts[#parts+1]=glyph(action).." "..(gold and "|cffffd100"..text.."|r" or text) end
    end
    add("back",L["Back"])
    if not self.modal and self.controls["add-action"] and #self.model.blocks>1 then add("phrases",L["Reorder"],self.reorder~=nil) end
    self.footer:SetText(table.concat(parts,"    "))
end
-- Hold the reorder button and press up or down to move the focused action.
function E:Reorder(dy)
    local index=tonumber((self.selected or ""):match("^action(%d+)$"));local blocks=self.model.blocks
    if not index or self.modal or self.detail or not blocks or not blocks[index+dy] then return end
    blocks[index],blocks[index+dy]=blocks[index+dy],blocks[index]
    self:Changed();self:Draw();self:Focus("action"..(index+dy))
end
function E:Shortcut(action)
    if self.modal then return end
    if action=="delete" then
        local add=self.controls["add-action"]
        if add and add:IsEnabled() then self:Focus("add-action");self:AddAction() end
    elseif action=="shift" then
        if self:NativeBinder() then self:Bind() else self:Save() end
    elseif action=="library" then self:More() end
end
function E:Move(dx,dy)
    local current=self.controls[self.selected];if not current then self:Focus();return end
    if current.list and dy~=0 then
        local nextRow=current.list.rows[current.listIndex+dy]
        if nextRow then self:Focus(nextRow.id);return end
    end
    local best,bestScore,bestAligned
    for _,b in ipairs(self.order) do if b~=current and b:IsEnabled() and self:ControlVisible(b) then
        local x,y=b.navX-current.navX,b.navY-current.navY
        local along=x*dx+y*dy
        if along>1 then
            local cross=math.abs(x*dy-y*dx)
            local span=dx~=0 and (current.navH+b.navH)/2 or (current.navW+b.navW)/2
            local gap=math.max(0,cross-span);local aligned=gap==0
            local score=along+gap*4+cross*.001
            if not best or aligned and not bestAligned or aligned==bestAligned and score<bestScore then best,bestScore,bestAligned=b,score,aligned end
        end
    end end
    if best then self:Focus(best.id) end
end
function E:Down(token)
    if not self:Eligible() then return true end
    local action = self.menuKeys and self.menuKeys[token]
    if not action then return true end
    if self.waitForUp[token:match("(PAD[%w]+)$")] then return false end
    W.lastPad=true;W.Input.padAt=GetTime()
    if action=="phrases" then self.reorder=token;self:PaintFooter();return false end
    if self.held then return self.held.token~=token end
    local revealed=self:RevealControl(self.controls[self.selected])
    self.held={token=token,action=action,id=self.selected,generation=self.generation,model=self.model,modal=self.modal,scrollRevision=self.scrollRevision,revealOnly=revealed and action=="primary"}
    if self.reorder and (action=="up" or action=="down") then self:Reorder(action=="up" and -1 or 1)
    elseif action=="up" then self:Move(0,-1) elseif action=="down" then self:Move(0,1)
    elseif action=="left" then self:Move(-1,0) elseif action=="right" then self:Move(1,0) end
    return false
end
function E:Up(token)
    if self.waitForUp then self.waitForUp[token:match("(PAD[%w]+)$")] = nil end
    if self.reorder==token then self.reorder=nil;self:PaintFooter();return false end
    local held=self.held
    if not held or held.token~=token then return true end
    self.held=nil
    if not self:Eligible() then return false end
    W.Input.padAt=GetTime()
    if held.generation~=self.generation or held.model~=self.model or held.modal~=self.modal or held.scrollRevision~=self.scrollRevision or held.revealOnly then return false end
    local action=held.action
    if action=="focus" then self:RequestFocus()
    elseif action=="back" then self:Back()
    elseif action=="primary" and held.id==self.selected then
        local b=self.controls[held.id];if b and b:IsEnabled() then b.run() end
    elseif action=="delete" or action=="shift" or action=="library" then self:Shortcut(action)
    elseif not self.modal and (action=="phrasesLeft" or action=="phrasesRight") then
        local tabs={"build","commands","templates"};local index=1
        for i,v in ipairs(tabs) do if v==self.tab then index=i end end
        self:Tab(tabs[(index+(action=="phrasesRight" and 1 or -1)-1)%3+1])
    end
    return false
end
function E:Acquire(kind)
    local n=(self.used[kind] or 0)+1;self.used[kind]=n
    local pool=self.pools[kind] or {};self.pools[kind]=pool
    local b=pool[n]
    if not b then
        if kind=="label" then b=W.Theme.Label(self.frame,"")
        elseif kind=="button" or kind=="tab" or kind=="primary" or kind=="row" or kind=="icon" then
            b=S.Button(self.frame,kind)
            b:SetScript("OnClick",function() if GetTime()-(W.Input.padAt or -1)<.15 then return end;if b.run then b.run() end end)
        elseif kind=="field" then
            local wrap;b,wrap=W.Theme.Input(self.frame);b.wrapper=wrap;b.wecOwned=false;b.wecMacro=true
            b.focus=wrap:CreateTexture(nil,"OVERLAY");b.focus:SetAllPoints();b.focus:SetColorTexture(1,.75,.15,.2);b.focus:Hide()
            b:SetScript("OnTextChanged",function(input)
                if self.drawing or input:GetText()==input.lastText then return end
                input.lastText=input:GetText()
                local _,size=input:GetFont();input:SetHeight(math.max(input.minimumHeight or 30,input:GetNumLines()*((size or 14)+3)+12))
                if input.change then input.change(input:GetText()) end
            end)
            b:SetScript("OnCursorChanged",function(input,_,y,_,height)
                if not y then return end
                local scroll=input.wecScroll;local offset=scroll:GetVerticalScroll();local top=-y
                if top<offset then scroll:SetVerticalScroll(math.max(0,top))
                elseif top+(height or 20)>offset+scroll:GetHeight() then scroll:SetVerticalScroll(math.max(0,top+(height or 20)-scroll:GetHeight())) end
            end)
            b:SetScript("OnEscapePressed",function()b:ClearFocus();self:Focus(b.id)end)
            b:SetScript("OnEnterPressed",function()if not b:IsMultiLine() then b:ClearFocus();self:Focus(b.id)end end)
        end
        pool[n]=b
    end
    b:Show();if b.wrapper then b.wrapper:Show() end
    return b
end
function E:Label(text,x,y,w,h,parent,tone)
    local b=self:Acquire("label");b:SetParent(parent or self.frame);S.Place(b,x,y,w,h or 28)
    b:SetFontObject(S.Font("GameFontNormal",0,tone~="light" and "ink" or nil));b:SetJustifyH("LEFT");b:SetJustifyV("TOP");b:SetText(text or "");return b
end
function E:Register(b,id,x,y,w,h)
    b.id=id;b.navX=x+w/2;b.navY=y+h/2;b.navW=w;b.navH=h
    self.controls[id]=b;self.order[#self.order+1]=b
end
function E:Button(id,text,x,y,w,run,h,parent,kind)
    kind=kind or (id:match("^tab%-") and "tab" or (id=="save" or id=="new") and "primary" or "button")
    local b=self:Acquire(kind);b:SetParent(parent or self.frame);S.Place(b,x,y,w,h or 36)
    b.card=nil;b.detail=nil;b.texture=nil;b.dropdown=nil;b.library=nil;b.list=nil;b.listIndex=nil
    b.shortcut=id=="add-action" and "delete" or id=="more" and "library" or nil
    if b.selection then b.selection:Hide();b.pointer:Hide();b.iconFrame:Hide() end
    b:EnableMouseWheel(false);b:SetText(text);S.Paint(b);b:Enable()
    local generation,model,modal=self.generation,self.model,self.modal
    b.run=function()
        if generation~=self.generation or model~=self.model or modal~=self.modal or self.controls[id]~=b or not b:IsEnabled() or not self:ControlVisible(b) or W.Combat() or W.Input.active or (W.IconPicker and W.IconPicker.request) or not self.frame:IsShown() then return end
        self.selected=id;run()
    end
    self:Register(b,id,x,y,w,h or 36)
    return b
end
function E:Dropdown(...)
    return S.Dropdown(self:Button(...))
end
function E:Field(id,text,x,y,w,h,multiline,change,parent)
    local b=self:Acquire("field");local wrap=b.wrapper;wrap:SetParent(parent or self.frame);S.Place(wrap,x,y,w,h)
    b:Enable();b:SetWidth(w*S.x-16);b:SetMultiLine(multiline);b:SetMaxBytes(0);b:SetMaxLetters(0);b.minimumHeight=h*S.y-14;b:SetHeight(b.minimumHeight)
    b:SetFontObject(S.Font("GameFontHighlight"));b.lastText=text or "";b:SetText(b.lastText);b:SetCursorPosition(0);b.wecScroll:SetVerticalScroll(0)
    b.change=change;b.run=function() if not W.Combat() then b:SetFocus();W.WatchFocus() end end
    self:Register(b,id,x,y,w,h);return b
end
function E:Begin()
    self.drawing=true;self:ClearFields();self.choicePending=nil;self.generation=(self.generation or 0)+1;self.controls={};self.order={};self.used={};self.lists={}
    for _,pool in pairs(self.pools) do for _,b in ipairs(pool) do b:Hide();if b.wrapper then b.wrapper:Hide() end end end
    for _,list in pairs(self.listFrames or {}) do list:Hide() end
end
function E:ControlVisible(b)
    local list=b.list
    return not list or b.listTop+b.listHeight>list.offset and b.listTop<list.offset+list.viewHeight
end
function E:RevealControl(b)
    local list=b and b.list;if not list then return false end
    local offset=list.offset
    if b.listTop<offset then offset=b.listTop
    elseif b.listTop+b.listHeight>offset+list.viewHeight then offset=b.listTop+b.listHeight-list.viewHeight end
    return self:ScrollList(list,offset)
end
function E:ScrollList(list,offset,native)
    offset=W.Clamp(offset,0,list.maximum)
    local changed=math.abs(offset-list.offset)>.01
    list.offset=offset;list.position.offset=offset;list.viewport:SetVerticalScroll(offset*S.y)
    for _,row in ipairs(list.rows) do row.navY=list.navY+row.listTop-offset+row.listHeight/2 end
    if not native then
        list.syncing=true;list.bar:SetScrollPercentage(list.maximum>0 and offset/list.maximum or 0,true);list.syncing=nil
    end
    if changed then
        self.scrollRevision=(self.scrollRevision or 0)+1
        if not self.drawing then self:Focus() end
    end
    return changed
end
function E:List(id,items,x,y,w,h,stride,rowHeight,render,identity,parent)
    self.listFrames=self.listFrames or {}
    local list=self.listFrames[id]
    if not list then
        list=CreateFrame("Frame",nil,self.frame);self.listFrames[id]=list;list.id=id
        list.viewport=CreateFrame("ScrollFrame",nil,list);list.viewport:SetPoint("TOPLEFT");list.viewport:SetClipsChildren(true)
        list.content=CreateFrame("Frame",nil,list.viewport);list.content:SetPoint("TOPLEFT");list.viewport:SetScrollChild(list.content)
        list.bar=CreateFrame("EventFrame",nil,list,"MinimalScrollBar");list.bar:SetPoint("TOPRIGHT");list.bar:Init(1,1)
        list.bar:RegisterCallback(ScrollBarMixin.Event.OnScroll,function(_,percentage)
            if list.syncing or self.lists[id]~=list or not self:Eligible() then return end
            self:ScrollList(list,percentage*list.maximum,true)
        end,self)
        list.wheel=function(_,delta)
            if self.lists[id]==list and self:Eligible() then self:ScrollList(list,list.offset-delta*list.stride) end
        end
        list:EnableMouseWheel(true);list:SetScript("OnMouseWheel",list.wheel)
        list.viewport:EnableMouseWheel(true);list.viewport:SetScript("OnMouseWheel",list.wheel)
        list:SetScript("OnHide",function()list.bar:UnregisterUpdate()end)
    end
    list:SetParent(parent or self.frame);S.Place(list,x,y,w,h);list:Show();list.rows={};list.navY=y;list.viewHeight=h;list.stride=stride
    local position=self.scrollPositions[id]
    if not position or position.identity~=identity then position={identity=identity,offset=0};self.scrollPositions[id]=position end
    list.position=position;list.offset=position.offset
    local contentHeight=math.max(h,(#items-1)*stride+rowHeight)
    list.maximum=contentHeight-h
    local width=w-(list.maximum>0 and 24 or 0)
    list.viewport:SetSize(width*S.x,h*S.y);list.content:SetSize(width*S.x,contentHeight*S.y);list.bar:SetHeight(h*S.y)
    self.lists[id]=list
    for i,item in ipairs(items) do
        local row=render(item,i,list.content,width,(i-1)*stride)
        row.list=list;row.listIndex=i;row.listTop=(i-1)*stride;row.listHeight=rowHeight;row.navX=x+width/2
        row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",list.wheel);list.rows[i]=row
    end
    list.syncing=true
    list.bar:SetVisibleExtentPercentage(h/contentHeight);list.bar:SetPanExtentPercentage(list.maximum>0 and math.min(1,stride/list.maximum) or 1)
    list.syncing=nil;list.bar:SetShown(list.maximum>0)
    self:ScrollList(list,list.offset)
    return list
end
function E:Tab(tab) self.tab=tab;self.detail=nil;self.rule=nil;self:Draw();self:Focus("tab-"..tab) end
function E:Guard(run)
    if not self.dirty then run();return end
    self:Choose(L["Unsaved macro"],{
        {label=L["Keep editing"],run=function()end},
        {label=L["Save and continue"],run=function()if self:Save() then run()end end},
        {label=L["Discard changes"],run=function()self.dirty=false;run()end}
    },L["Your draft has changes. Choose what to do before leaving it."])
end
function E:Load(entry)
    self:Guard(function()
        local model,snapshot=D.Load(entry);if not model then self:Status(snapshot);return end
        self.model,self.snapshot,self.dirty=model,snapshot,false;self.detail=nil;self.rule=nil;self.tab="build";self:Draw()
    end)
end
function E:New(scope)
    self:Guard(function()
        self.scope=scope or self.scope;self.model=D.New(self.scope);self.snapshot=nil;self.dirty=false;self.detail=nil;self.rule=nil;self:Draw();self:Focus("name")
    end)
end
function E:Save()
    local snapshot,err=D.Save(self.model,self.snapshot,self.catalog)
    if not snapshot then self:Status(err);return false end
    self.snapshot=snapshot;self.dirty=false;self.message=L["Macro saved."];self:Draw();return true
end
function E:NativeBinder()
    local native=GamepadActionBarEditFrame
    if native and type(native.BindMacro)=="function" and not native:IsShown() then return native end
end
function E:FinishBinding()
    local session=self.binding;if not session then return end
    self.binding=nil;self.events:SetScript("OnUpdate",nil)
    -- Do not reopen over combat, another input owner, or a replacement draft.
    if session.restore and self.model==session.model and W.db.enabled and not W.Combat() and not W.Blocker()
        and not W.Focus() and not W.Input.active and not W.Placement.editing
        and not (SettingsPanel and SettingsPanel:IsShown())
        and not (W.IconPicker and W.IconPicker.request) then
        self:Open();self:Focus("bind")
        if session.focus then self:RequestFocus() end
    end
    if W.Radial then W.Radial:SyncOwnership() end
end
function E:Bind()
    if not self:Eligible() or self.modal or self.binding then return false end
    local native=self:NativeBinder()
    if not native then self:Status(L["Controller toolbar binding is unavailable."]);return false end
    -- Save & bind is an explicit action. A failed save never reaches the bar.
    if (self.dirty or not self.snapshot) and not self:Save() then return false end
    -- Native macro slots can move after renames/deletions; resolve at activation.
    local entry,err=D.Resolve(self.snapshot)
    if not entry then self:Status(err);return false end
    local session={native=native,model=self.model,restore=true,focus=self.focusRequested or W.ControllerMode()}
    self.binding=session;self:ClearFields();self.held=nil;self.frame:Hide()
    W.Input:RefreshWindows()
    local elapsed=0
    self.events:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt;if elapsed<.15 then return end;elapsed=0
        if W.Combat() or not W.db.enabled then session.restore=false end
        if not native:IsShown() then self:FinishBinding() end
    end)
    -- Use the native entry point, never duplicate its protected slot logic.
    local ok=pcall(native.BindMacro,native,entry.index)
    if not ok or not native:IsShown() then
        if native:IsShown() then pcall(HideUIPanel,native) end
        if not native:IsShown() then self:FinishBinding() end
        self:Status(L["WoW could not open toolbar binding. Your macro is still saved."])
        if not self.frame:IsShown() then W.Print(self.message) end
        return false
    end
    return true
end
function E:More()
    local entries={{label=L["Duplicate to account"],run=function()self:Duplicate("account")end},
        {label=L["Duplicate to character"],run=function()self:Duplicate("character")end}}
    if self.snapshot then entries[#entries+1]={label=L["Delete macro"],run=function()
        local snapshot=self.snapshot
        self:Choose(L["Delete macro"],{{label=L["Cancel"],run=function()end},{label=L["Delete permanently"],run=function()
            local ok,err=D.Delete(snapshot);if not ok then self:Status(err);return end
            self.dirty=false;self:New(self.scope)
        end}},L.Format("Delete %s? This cannot be undone.",W.Escape(snapshot.name)))
    end} end
    self:Choose(L["Macro actions"],entries)
end
function E:Duplicate(scope)
    local model=W.Copy(self.model)
    self:Guard(function()self.model=model;self.model.scope=scope;self.model.name="";self.scope=scope;self.snapshot=nil;self.dirty=true;self:Draw();self:Focus("name")end)
end
function E:Back()
    if self.modal then local back,restore=self.modal.back,self.modal.returnID;self.modal=nil;self:Draw();self:Focus(restore);if back then back()end
    elseif self.rule then self.rule=nil;self:Draw()
    elseif self.detail then self.detail=nil;self:Draw()
    else self:Guard(function()self.frame:Hide()end) end
end
function E:Choose(title,entries,help,back,searchable)
    self:ClearFields();self.modal={title=title,entries=entries,help=help or "",back=back,search=searchable and "" or nil,returnID=self.selected};self:Draw()
end
function E:DrawModal()
    local m=self.modal
    self.dialog:Show();self:Label(m.title,24,20,572,36,self.dialog)
    self:Label(m.help,24,62,572,m.search~=nil and 44 or 70,self.dialog)
    if m.search~=nil then
        self:Label(L["Search spells"],24,108,572,24,self.dialog)
        self:Field("choice-search",m.search,24,132,572,36,false,function(value)
        m.search=value;if self.scrollPositions.choices then self.scrollPositions.choices.offset=0 end;self:DrawChoices()
    end,self.dialog) end
    self:DrawChoices()
end
function E:DrawChoices()
    -- Filter refresh is a full render except while typing: defer until
    -- text entry ends so pooled rows cannot steal the keyboard's source field.
    local m=self.modal
    if not self.drawing then self.choicePending=true;return end
    local entries={};for _,entry in ipairs(m.entries) do
        if not m.search or m.search=="" or fold(entry.search or entry.label):find(fold(m.search),1,true) then entries[#entries+1]=entry end
    end
    self:List("choices",entries,24,180,572,328,48,40,function(entry,i,parent,width,y)
        local b=self:Button("choice"..i,entry.label,0,y,width,function()
            local restore=m.returnID;self.modal=nil;self:Draw();self:Focus(restore);entry.run()
        end,40,parent,"row")
        S.Card(b)
        return entry.dropdown and S.Dropdown(b) or b
    end,m,self.dialog)
    if #entries==0 then self:Label(L["No matches."],24,182,572,40,self.dialog) end
    self:Button("choice-back",L["Back"],424,530,172,function()self:Back()end,36,self.dialog)
end
function E:FocusedBlock()
    if self.modal or self.tab~="build" then return false end
    return self.detail or tonumber((self.selected or ""):match("^action(%d+)$")) or false
end
-- Keep the displayed lines aligned with MacroCompiler and accent the focused action.
function E:PaintPreview()
    if not self.model or not self.preview then return end
    local focused=self:FocusedBlock();self.previewFocus=focused
    local lines={}
    if type(self.model.raw)=="string" then lines[1]=S.Code(self.model.raw)
    else
        if self.model.tooltip then lines[1]=S.Code("#showtooltip") end
        for i,block in ipairs(self.model.blocks or {}) do
            local text=C.Block(block,self.catalog)
            if text then lines[#lines+1]=S.Code(text,i==focused) end
        end
    end
    self.preview:SetText(table.concat(lines,"\n"))
    local overflow=false
    local viewport=self.codeScroll:GetHeight()
    local needed=viewport
    if self.preview.GetStringHeight then
        local width=self.codeScroll:GetWidth()
        self.preview:SetWidth(width-8)
        needed=self.preview:GetStringHeight()+10
        overflow=needed>viewport+1
        if overflow then
            self.preview:SetWidth(width-26)
            needed=self.preview:GetStringHeight()+10
        end
    end
    local height=math.max(viewport,needed)
    self.preview:SetHeight(height);self.codeContent:SetHeight(height)
    self.codeBar:SetShown(overflow)
    self.codeBar:SetVisibleExtentPercentage(viewport/height)
    self.codeBar:SetPanExtentPercentage(math.min(1,60/math.max(1,height-viewport)))
    self:ScrollPreview(0)
    for _,b in ipairs(self.previewButtons or {}) do b:SetShown(overflow);b:SetEnabled(overflow) end
end
function E:Preview()
    if not self.model or not self.preview then return end
    local body,errors,warnings=C.Compile(self.model,self.catalog)
    self:PaintPreview()
    local count=C.Characters(body)
    self.counter:SetText((count>255 and "|cff8b1816" or "|cff45270f")..L.Format("%d / 255",count).."|r")
    self.meterFill:SetWidth(math.max(1,self.meterBack:GetWidth()*math.min(1,count/255)))
    if count>255 then self.meterFill:SetColorTexture(1,.25,.2,1) elseif count>230 then self.meterFill:SetColorTexture(1,.6,.15,1) else self.meterFill:SetColorTexture(1,.82,0,1) end
    local value,err=D.Validate(self.model,self.snapshot,self.catalog)
    local name=self.model.name
    local named=type(name)=="string" and not W.Secret(name) and not name:match("^%s*$") and not name:find('[\r\n|"%z]') and C.Characters(name)<=16
    local complete=body and not body:match("^%s*$") and not (errors and #errors>0)
    local function check(ok,yes,no) return ok and S.ready..L[yes] or S.notReady.."|cff812b13"..L[no].."|r" end
    self.checks:SetText(check(named,"Name is valid","Name needs 1–16 characters").."\n"
        ..check(count<=255,"Fits in 255 characters","Over 255 characters").."\n"
        ..check(complete,"Actions are complete","Actions need attention"))
    if self.save then self.save:SetEnabled(value~=nil) end
    if self.bind then
        local available=self:NativeBinder()~=nil
        self.bind:SetText(L[not available and "Binding unavailable" or (self.dirty or not self.snapshot) and "Save & bind" or "Bind to toolbar"])
        self.bind:SetEnabled(value~=nil and available)
        self.bind.shortcut=available and "shift" or nil
        self.save.shortcut=not available and "shift" or nil
    end
    self.status:SetText(self.message or err or (warnings and warnings[1]) or L["Ready to save. Preview does not execute commands."])
    if self.draftLabel then
        self.draftLabel:SetText(self.dirty and L["Unsaved changes"] or self.snapshot and L["Saved macro"] or L["New macro"])
    end
    self:PaintFooter()
end
function E:Draw()
    if not self.frame or not self.model then return end
    self:Begin();self.dialog:Hide();self.shade:Hide();self.preview=nil;self.status=nil;self.counter=nil;self.save=nil;self.checks=nil;self.previewButtons=nil
    local header=self:Label(L["Macro creator"],100,7,900,31,nil,"light")
    header:SetFontObject(S.Font("GameFontNormal",6));header:SetJustifyH("CENTER");header:SetJustifyV("MIDDLE")
    self:Register(self.closeButton,"close",1080,0,20,22)
    self:Register(self.focusButton,"focus",536,670,28,29)
    self:Label(L["Macro library"],24,97,204,30,nil,"light"):SetFontObject(S.Font("GameFontHighlight",4))
    self:Dropdown("scope",L[self.scope=="account" and "Account macros" or "Character macros"],19,135,208,function()
        self:Choose(L["Macro library"],{{label=L["Account macros"],run=function() if self.scope~="account" then self:New("account") end end},
            {label=L["Character macros"],run=function() if self.scope~="character" then self:New("character") end end}})
    end)
    self:Button("new",L["New macro"],24,581,196,function()self:New()end)
    local list,err=D.List(self.scope)
    self:List("library",list,10,181,221,389,52,44,function(entry,i,parent,width,y)
        local b=self:Button("macro:"..entry.index,W.Escape(entry.name),0,y,width,function()self:Load(entry)end,44,parent,"row")
        S.Card(b,nil,entry.displayIcon,true)
        local saved=self.snapshot
        b.selection:SetShown(saved and saved.scope==entry.scope and saved.name==entry.name and saved.body==entry.body and saved.icon==entry.icon)
        return b
    end,self.scope)
    if #list==0 then self:Label(err or L["No macros in this scope."],24,197,196,90,nil,"light"):SetFontObject(S.Font("GameFontHighlight",-1)) end
    self:Label(L["Macro name"],330,88,450,26)
    self.counter=self:Label("",812,418,264,23)
    S.Place(self.meterBack,812,447,254,4);S.Place(self.meterFill,812,447,254,4)
    self:Field("name",self.model.name,330,115,458,40,false,function(value)self.model.name=value;self:Changed()end)
    local iconButton=self:Button("icon","",252,91,64,function()
        self:ClearFields();local model=self.model
        local opened=W.IconPicker:Open({owner=self.frame,selectedIcon=model.icon,onSelect=function(icon)
            if self.model==model then model.icon=icon;self:Changed();self:Draw() end
        end,restoreFocus=function()self.shade:Hide();if self.frame:IsShown()then self:SyncControls();self:Focus("icon")end end})
        if opened then self.shade:Show();self:SyncControls() end
    end,66,nil,"icon")
    self.icon:SetParent(iconButton);self.icon:ClearAllPoints();self.icon:SetPoint("CENTER");self.icon:SetTexture(self.model.icon or 134400);self.icon:Show()
    self.iconRim:SetParent(iconButton);self.iconRim:ClearAllPoints();self.iconRim:SetPoint("CENTER",self.icon,"CENTER")
    for i,tab in ipairs({{"build","Visual builder"},{"commands","Commands"},{"templates","Templates"}}) do
        local b=self:Button("tab-"..tab[1],L[tab[2]],278+(i-1)*182,42,178,function()self:Tab(tab[1])end)
        W.Theme.Tab(b,self.tab==tab[1])
    end
    self.leftBumper=self:Label("",235,51,40,24,nil,"light");self.leftBumper:SetJustifyH("RIGHT")
    self.rightBumper=self:Label("",830,51,48,24,nil,"light")
    self.draftLabel=self:Label("",812,120,264,32)
    self:Label(L[self.tab=="build" and "Actions" or self.tab=="commands" and "Commands" or "Templates"],252,176,536,28):SetFontObject(S.Font("GameFontNormal",3,"ink"))
    self:Label(L["Live command preview"],812,176,264,42):SetFontObject(S.Font("GameFontNormal",3,"ink"))
    self.preview=self.codeText;self.codeScroll:Show();self.preview:SetFontObject(S.Font("GameFontHighlight",-1,"ink"));self.codeScroll:SetVerticalScroll(0)
    -- Scroll buttons join the focus graph only while the preview overflows.
    self.previewButtons={self:Button("preview-up",L["Up"],812,380,124,function()self:ScrollPreview(-120)end,28),
        self:Button("preview-down",L["Down"],952,380,124,function()self:ScrollPreview(120)end,28)}
    self.checks=self:Label("",812,463,264,76);self.checks:SetFontObject(S.Font("GameFontHighlight",-2,"ink"))
    self.status=self:Label("",812,547,264,74);self.status:SetFontObject(S.Font("GameFontHighlight",-2,"secondary"))
    self.save=self:Button("save",L["Save macro"],580,639,150,function()self:Save()end)
    self.bind=self:Button("bind",L["Bind to toolbar"],737,639,193,function()self:Bind()end)
    self:Dropdown("more",L["More"],937,639,144,function()self:More()end)
    if self.tab=="commands" then
        self:Label(L["Editing commands preserves your text exactly. Visual actions stay as custom commands until you replace them."],252,213,536,56)
        local body=C.Compile(self.model,self.catalog)
        self:Field("commands",body,252,272,536,278,true,function(value)self.model.raw=value;self:Changed()end)
        self:Button("commands-builder",L["Keep text as an action"],252,564,536,function()
            local text=C.Compile(self.model,self.catalog);self.model.raw=nil;self.model.tooltip=false;self.model.blocks={{kind="raw",text=text}};self:Changed();self:Tab("build")
        end)
    elseif self.tab=="templates" then self:DrawTemplates()
    elseif self.model.raw then
        self:Label(L["Your custom commands are preserved. Keep them as an action to add visual steps."],252,206,536,100)
        self:Button("raw-keep",L["Keep text as an action"],252,326,536,function()
            self.model.blocks={{kind="raw",text=self.model.raw}};self.model.raw=nil;self.model.tooltip=false;self:Changed();self:Draw()
        end)
    else self:DrawBuilder() end
    self.footer=self:Label("",18,635,552,45,nil,"light");self.footer:SetFontObject(S.Font("GameFontHighlight",-3));self.footer:SetJustifyV("MIDDLE")
    self:Preview()
    if self.modal then
        self.shade:Show()
        -- Main controls remain visible but are not in the active graph.
        for _,b in ipairs(self.order) do b.focus:Hide() end
        for _,box in ipairs(self.pools.field or {}) do box:Disable() end
        self.controls={};self.order={};self.lists={};self.icon:Hide();self:DrawModal()
    end
    self.drawing=nil;self:Focus()
end
function E:Open()
    if W.Combat() then W.Print(L["Edit macros outside combat."]);return false end
    if self.binding or (GamepadActionBarEditFrame and GamepadActionBarEditFrame:IsShown()) then return false end
    if not self.frame then self:Create() end
    D.Init();self.catalog=D.Spells()
    if not self.model then self.model=D.New(self.scope);self.selected="starter-cast" end
    if W.Radial then W.Radial:Close() end
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    self.frame:SetScale(math.min(W.db.scale or 1,(UIParent:GetWidth()-40)/1280,(UIParent:GetHeight()-40)/760))
    self.frame:Show();self:Draw();self:SyncControls(true);if W.Radial then W.Radial:SyncOwnership() end
    return true
end
function E:Create()
    local f=CreateFrame("Frame","WoWEnhancedControllerMacroEditor",UIParent);self.frame=f;f:Hide();f:SetSize(1280,760);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:EnableMouse(true);W.Theme.Shell(f)
    -- Native exit artwork, with our draft decision replacing the default hide.
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButtonNoScripts");self.closeButton=close
    close:SetSize(24,24);close:SetPoint("TOPRIGHT",1,0);close:SetFrameLevel(f:GetFrameLevel()+2)
    close.focus=close:CreateTexture(nil,"OVERLAY");close.focus:SetAllPoints();close.focus:SetColorTexture(1,.75,.15,.25);close.focus:Hide()
    close.run=function()
        if self.modal or not self:Eligible() then return end
        self:Guard(function()f:Hide()end)
    end
    close:SetScript("OnClick",function()if GetTime()-(W.Input.padAt or -1)>=.15 then close.run()end end)
    self.focusButton=W.Theme.Button(f,"",function()if not self.modal then self:RequestFocus()end end)
    self.focusButton:SetPoint("CENTER",f,"BOTTOM",0,4);self.focusButton:SetSize(32,32);self.focusButton:SetFrameLevel(f:GetFrameLevel()+2)
    self.focusButton.run=function()if not self.modal then self:RequestFocus()end end
    S.Folio(f)
    self.meterBack=f:CreateTexture(nil,"ARTWORK");self.meterBack:SetColorTexture(.2,.2,.16,1)
    self.meterFill=f:CreateTexture(nil,"OVERLAY");self.meterFill:SetColorTexture(1,.82,0,1)
    self.icon=f:CreateTexture(nil,"OVERLAY");self.icon:SetPoint("TOPLEFT",261*S.x,-77*S.y);self.icon:SetSize(46*S.x,46*S.y)
    self.iconRim=f:CreateTexture(nil,"OVERLAY",nil,1);self.iconRim:SetTexture("Interface\\Buttons\\UI-Quickslot2");self.iconRim:SetSize(78*S.x,78*S.y)
    self.codeScroll=CreateFrame("ScrollFrame",nil,f);S.Place(self.codeScroll,812,224,264,150);self.codeScroll:SetClipsChildren(true)
    local code=CreateFrame("Frame",nil,self.codeScroll);self.codeContent=code;code:SetSize(264*S.x,1000);self.codeScroll:SetScrollChild(code)
    self.codeText=W.Theme.Label(code,"");self.codeText:SetPoint("TOPLEFT");self.codeText:SetWidth(264*S.x-8);self.codeText:SetHeight(1000);self.codeText:SetJustifyH("LEFT");self.codeText:SetJustifyV("TOP")
    self.codeScroll:EnableMouseWheel(true);self.codeScroll:SetScript("OnMouseWheel",function(_,delta)self:ScrollPreview(-delta*60)end)
    self.codeBar=CreateFrame("EventFrame",nil,f,"MinimalScrollBar")
    self.codeBar:SetPoint("TOPRIGHT",self.codeScroll,"TOPRIGHT");self.codeBar:SetHeight(self.codeScroll:GetHeight());self.codeBar:Init(1,1)
    self.codeBar:RegisterCallback(ScrollBarMixin.Event.OnScroll,function(_,fraction)
        if self.preview and not self.modal and self:Eligible() then
            self.codeScroll:SetVerticalScroll(fraction*math.max(0,self.preview:GetHeight()-self.codeScroll:GetHeight()))
        end
    end,self)
    self.shade=CreateFrame("Frame",nil,f);self.shade:SetAllPoints();self.shade:SetFrameLevel(f:GetFrameLevel()+8);self.shade:EnableMouse(true)
    local dim=self.shade:CreateTexture(nil,"BACKGROUND");dim:SetAllPoints();dim:SetColorTexture(0,0,0,.7);self.shade:Hide()
    local dialog=CreateFrame("Frame",nil,f);self.dialog=dialog;dialog:SetSize(620*S.x,584*S.y);dialog:SetPoint("CENTER");dialog:SetFrameLevel(f:GetFrameLevel()+20);dialog:EnableMouse(true);W.Theme.Shell(dialog);S.Dialog(dialog);dialog:Hide()
    -- Do not put the parent in UISpecialFrames: Escape must visit the draft guard.
    f:EnableKeyboard(true);f:SetPropagateKeyboardInput(true)
    f:SetScript("OnKeyDown",function(_,key)
        if W.Combat() then return end
        if key=="ESCAPE" and self:Eligible() then f:SetPropagateKeyboardInput(false);self:Back()
        else f:SetPropagateKeyboardInput(true) end
    end)
    f:SetScript("OnHide",function()
        W.ReleaseMenuControls(self);self:ClearFields();self.modal=nil;self.reorder=nil
        self.codeBar:UnregisterUpdate()
        for _,list in pairs(self.listFrames or {}) do list.bar:UnregisterUpdate() end
        if W.IconPicker and W.IconPicker.request and W.IconPicker.request.owner==f then W.IconPicker:Close() end
        if W.Radial then W.Radial:SyncOwnership() end
    end)
    local elapsed=0
    f:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt;if elapsed<.15 then return end;elapsed=0
        if self.choicePending and not W.Input.active then
            local box=self.controls["choice-search"]
            if not box or not box:HasFocus() or W.dismissed==box then self.choicePending=nil;self:Draw() end
        end
        self:SyncControls()
        if self.reorder and IsKeyDown and not IsKeyDown(self.reorder:match("(PAD[%w]+)$")) then self.reorder=nil;self:PaintFooter() end
        for key in pairs(self.waitForUp or {}) do
            if IsKeyDown and not IsKeyDown(key) then self.waitForUp[key] = nil end
        end
    end)
    local events=CreateFrame("Frame");self.events=events
    for _,event in ipairs({"PLAYER_REGEN_DISABLED","UPDATE_MACROS","SPELLS_CHANGED","UPDATE_BINDINGS","GAME_PAD_DISCONNECTED","GAME_PAD_CONNECTED","GAME_PAD_ACTIVE_CHANGED"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_REGEN_DISABLED" then if self.binding then self.binding.restore=false end;self.message=L["Combat paused editing. Your draft is still available."];f:Hide()
        elseif event=="GAME_PAD_DISCONNECTED" or event=="GAME_PAD_CONNECTED" or event=="GAME_PAD_ACTIVE_CHANGED" then
            if event=="GAME_PAD_DISCONNECTED" and self.binding then self.binding.restore=false end
            self.disconnected=event=="GAME_PAD_DISCONNECTED";self:SyncControls(true)
        elseif event=="SPELLS_CHANGED" then self.catalog=D.Spells();if f:IsShown()then self:Preview()end
        elseif event=="UPDATE_MACROS" then if f:IsShown()then self:Preview()end
        elseif event=="UPDATE_BINDINGS" and f:IsShown() then self:SyncControls(true) end
    end)
    W.Keyboard.frame:HookScript("OnShow",function() self:SyncControls() end)
    W.Keyboard.frame:HookScript("OnHide",function() self:SyncControls() end)
end
function E:ScrollPreview(delta)
    local maximum=math.max(0,self.preview:GetHeight()-self.codeScroll:GetHeight())
    local offset=W.Clamp(self.codeScroll:GetVerticalScroll()+delta,0,maximum)
    self.codeScroll:SetVerticalScroll(offset)
    self.codeBar:SetScrollPercentage(maximum>0 and offset/maximum or 0,true)
end
