local _, W = ...
local R, D = W.Radial, W.RadialData

local function copy(action)
    local result = {}
    for key, value in pairs(action or {}) do result[key] = value end
    return result
end
function R:Edit()
    if W.Combat() then W.Print(W.L["Edit wheel actions outside combat."]); return end
    if not self.frame then W.Print(self.failure or W.L["Wheel unavailable."]); return end
    self:Close()
    if W.Options.spellsCategory then Settings.OpenToCategory(W.Options.spellsCategory:GetID()); return end
    if not self.editor then self:CreateEditor() end
    self:PresentEditor()
end
function R:PresentEditor()
    self.editorCaches=self.editorCaches or {}
    self.editorProfileKey=D.Key()
    local cache=self.editorCaches[self.editorProfileKey]
    if not cache then cache={profile=W.Copy(D.Profile()),drafts={},newDrafts={}};self.editorCaches[self.editorProfileKey]=cache end
    self.editorProfile,self.editorDrafts,self.editorNewDrafts=cache.profile,cache.drafts,cache.newDrafts
    self.editorIndex,self.pickerKind=1,nil
    self.editorPage,self.editorSlot=0,1
    local slots=D.PageSlots(0,self.editorProfile);self.editorIndex=slots[1] or #self.editorProfile.actions+1
    self.editor:Show(); self:LoadAction(); self:SyncOwnership()
    if self.editorInSettings then
        local parent=self.editor:GetParent()
        self.editor:SetScale(math.min(1,(parent:GetWidth()>0 and parent:GetWidth() or 640)/640,(parent:GetHeight()>0 and parent:GetHeight() or 628)/628))
    else
        self.editor:SetScale(math.min(W.db.scale, (UIParent:GetWidth() - 40) / 640, (UIParent:GetHeight() - 40) / 628))
        self.editor:ClearAllPoints(); self.editor:SetPoint("CENTER")
    end
    for i,b in ipairs(self.editorControls)do if b.tabSelected then self.editorSelected=i;break end end
    self:EditorFocus()
end
function R:EditorProfile() return self.editorProfile or D.Profile() end
function R:SaveEditor()
    if self.editorProfileKey~=D.Key() then self:EditorStatus(W.L["Reopen the editor for the current character/spec."]);return false end
    self:ClearEditorFocus();self:StoreNewDraft()
    local candidate=W.Copy(self:EditorProfile())
    for i in ipairs(candidate.actions)do candidate.actions[i]=copy(self.editorDrafts[i] or candidate.actions[i]) end
    for _,page in ipairs(candidate.pages)do
        local slots=D.PageSlots(page,candidate)
        for slot=1,8 do
            local action=self.editorNewDrafts[page..":"..slot]
            if not slots[slot] and action and (action.value~="" or action.label~="") then candidate.actions[#candidate.actions+1]=copy(action) end
        end
    end
    local ok,err=D.SaveProfile(candidate)
    if ok then
        local page,slot=self.editorPage,self.editorSlot
        self.editorCaches[self.editorProfileKey]=nil;self:PresentEditor();self:EditorPage(page);self:EditorCell(slot)
    end
    self:EditorStatus(ok and W.L["Wheel changes saved."] or err)
    return ok
end
function R:EditorStatus(text) self.editorStatus:SetText(text or "") end
function R:EditorFocus()
    local active=self.editorControls[self.editorSelected or 1]
    if not active or not active:IsShown() or not active:IsEnabled() then
        self.editorSelected=1
        for i,b in ipairs(self.editorControls) do if b:IsShown() and b:IsEnabled() then self.editorSelected=i;break end end
    end
    local cursor=self.editorInSettings and W.Options.NativeNavigation() and SmartNavigation:GetCurrentButton()
    for i, b in ipairs(self.editorControls) do
        local selected = i == self.editorSelected and b:IsShown() and (not cursor or cursor==(b.input or b))
        if b.focus then b.focus:SetShown(selected) end
        if b.prompt then W.Theme.Prompt(b, selected and { "primary" } or {}, "corner") end
        if b.promptIcon then
            local atlas=W.Input:Icon("primary")
            if atlas then b.promptIcon:SetAtlas(atlas) end
            b.promptIcon:SetShown(selected and atlas~=nil)
        end
    end
    local selected = self.editorControls[self.editorSelected]
    if selected then
        self:EditorStatus(W.L["D-pad: select · Confirm: use · Back: close"] .. "\n"
            .. W.L.Format("Selected: %s", selected.fieldLabel or selected:GetText()))
    end
end
function R:EditorStep(delta) self:EditorMove(0,delta) end
function R:EditorMove(dx,dy)
    if self.pickerKind and dy~=0 then
        for i, row in ipairs(self.pickerRows) do
            if self.editorControls[self.editorSelected] == row then
                local nextIndex = (self.pickerOffset or 0) + i + dy
                if nextIndex >= 1 and nextIndex <= #(self.pickerFiltered or {})
                    and (i + dy < 1 or i + dy > #self.pickerRows) then
                    self:ScrollPicker((self.pickerOffset or 0) + dy)
                    return
                end
                break
            end
        end
    end
    local current=self.editorControls[self.editorSelected or 1]
    if not current or not current.navX then self:EditorFocus();return end
    local best,bestAligned,bestScore
    for i,b in ipairs(self.editorControls)do
        if b~=current and b.navX and b:IsShown() and b:IsEnabled()then
            local x,y=b.navX-current.navX,b.navY-current.navY
            local forward=x*dx+y*dy
            if forward>1 then
                local cross=math.abs(x*dy-y*dx)
                local span=dx~=0 and (current.navHeight+b.navHeight)/2 or (current.navWidth+b.navWidth)/2
                local gap=math.max(0,cross-span)
                local aligned=gap==0
                local along=dx~=0 and (current.navWidth+b.navWidth)/2 or (current.navHeight+b.navHeight)/2
                local score=math.max(0,forward-along)+gap*3+cross*.001
                if not best or aligned and not bestAligned or aligned==bestAligned and score<bestScore then
                    best,bestAligned,bestScore=i,aligned,score
                end
            end
        end
    end
    if best then self.editorSelected=best end
    self:EditorFocus()
end
function R:EditorDraft()
    local action = self.editorDrafts[self.editorIndex]
    if not action then
        action = copy(self:EditorProfile().actions[self.editorIndex] or {kind="spell",label="",value="",page=self.editorPage or 0,slot=self.editorSlot or 1})
        self.editorDrafts[self.editorIndex] = action
    end
    return action
end
function R:EditorSlot(index,skipStore)
    self:ClearEditorFocus()
    if not skipStore then self:StoreNewDraft() end
    self.editorIndex, self.pickerKind = index, nil
    local a=self:EditorProfile().actions[index]
    if a then self.editorPage,self.editorSlot=a.page,a.slot end
    if not a then self.editorDrafts[index]=self.editorNewDrafts[self.editorPage..":"..self.editorSlot] end
    self:LoadAction()
end
function R:EditorPage(id)
    self:ClearEditorFocus();self.pickerKind=nil
    local actions=self:EditorProfile().actions
    self:StoreNewDraft()
    self.editorDrafts[#actions+1]=nil
    self.editorPage,self.editorSlot=id,1
    self:EditorSlot(D.PageSlots(id,self:EditorProfile())[1] or #actions+1,true)
end
function R:EditorCell(slot)
    self:ClearEditorFocus();local actions=self:EditorProfile().actions
    local index=D.PageSlots(self.editorPage,self:EditorProfile())[slot]
    self:StoreNewDraft()
    if not index then self.editorDrafts[#actions+1]=nil end
    self.editorSlot=slot;self:EditorSlot(index or #actions+1,true)
end
function R:StoreNewDraft()
    if self.editorIndex==#self:EditorProfile().actions+1 then
        self.editorNewDrafts[self.editorPage..":"..self.editorSlot]=self.editorDrafts[self.editorIndex]
    end
end
function R:AddEditorAction()
    if W.Combat() or W.Placement.editing then return false end
    local profile=self:EditorProfile();local actions=profile.actions;local draft=self:EditorDraft()
    if self.editorIndex==#actions+1 and draft.value~="" then
        local ok,err=D.Save(self.editorIndex,draft,profile)
        if not ok then self:EditorStatus(err);return false end
        self.editorDrafts[self.editorIndex]=nil
        self.editorNewDrafts[draft.page..":"..draft.slot]=nil
    end
    local slots=D.PageSlots(self.editorPage,profile)
    for slot=1,8 do if not slots[slot] then
        self:EditorCell(slot)
        if self:EditorDraft().kind=="spell" or self:EditorDraft().kind=="saved" then self:OpenEditorPicker() end
        return true
    end end
    self:LoadAction();self:EditorStatus(W.L["This page is full. Add another page for more actions."]);return false
end
function R:ClearEditorFocus()
    local session = W.Keyboard.session
    if session and (session.target == self.labelInput or session.target == self.valueInput or session.target == self.searchInput) then W.Keyboard:Close() end
    -- Creation can stop before every field exists; do not let a missing
    -- earlier field skip cleanup of the later fields or crash category exit.
    for _, box in pairs({self.labelInput,self.valueInput,self.searchInput}) do box:ClearFocus() end
end
function R:CreateEditor(settingsCanvas)
    local f = CreateFrame("Frame", "WoWEnhancedControllerWheelEditor", settingsCanvas or UIParent)
    self.editor = f; f:Hide(); f:SetSize(640, 628)
    self.editorInSettings = settingsCanvas ~= nil
    f:SetFrameStrata(settingsCanvas and "HIGH" or "DIALOG")
    if settingsCanvas then f:SetPoint("TOP", settingsCanvas, "TOP") else W.Theme.Shell(f) end
    f:EnableMouse(true)
    self.editorControls, self.editorLabels = {}, {}
    local function label(text,x,y,width,height,parent)
        if not parent and y>=78 then y=y+48 end
        local l = W.Theme.Label(parent or f,text)
        l:SetPoint("TOPLEFT",x,-y); l:SetSize(width,height or 24); l:SetJustifyH("LEFT")
        self.editorLabels[#self.editorLabels+1]=l
        return l
    end
    local function button(text,x,y,width,run,height,parent,plain)
        if not parent and y>=78 then y=y+48 end
        local function activate() if not W.Combat() and not W.Placement.editing then run() end end
        local b=(plain and W.Theme.Button or W.Theme.SettingsButton)(parent or f,text,activate)
        b:SetPoint("TOPLEFT",x,-y); b:SetSize(width,height or 34); b.run=activate
        b.navX,b.navY,b.navWidth,b.navHeight=x+width/2,y+(height or 34)/2,width,height or 34
        self.editorControls[#self.editorControls+1]=b
        return b
    end
    local function field(x,y,width,height,multiline,caption)
        y=y+48
        local box,border=W.Theme.Input(f)
        border:SetPoint("TOPLEFT",x,-y);border:SetSize(width,height)
        box:SetWidth(width-16);box:SetMultiLine(multiline);box:SetMaxBytes(multiline and 255 or 128)
        box:SetTextInsets(8,28,5,5);box.wecOwned=false;box.wrapper=border
        box.focus=border:CreateTexture(nil,"OVERLAY");box.focus:SetAllPoints();box.focus:SetColorTexture(1,.75,.15,.2);box.focus:Hide()
        box.promptIcon=border:CreateTexture(nil,"OVERLAY");box.promptIcon:SetSize(22,22);box.promptIcon:SetPoint("BOTTOMRIGHT",-4,4)
        local control={input=box,focus=box.focus,promptIcon=box.promptIcon,fieldLabel=caption,
            navX=x+width/2,navY=y+height/2,navWidth=width,navHeight=height,
            run=function()box:SetFocus();W.WatchFocus()end,
            IsShown=function()return border:IsShown()end,IsEnabled=function()return true end}
        self.editorControls[#self.editorControls+1]=control
        box:SetScript("OnTextChanged",function(input)
            if multiline then
                local _,size=input:GetFont()
                input:SetHeight(math.max(height-16,input:GetNumLines()*((size or 14)+2)+10))
                if not input:HasFocus() then input.wecScroll:SetVerticalScroll(0) end
            end
            if not self.editorLoading then
                if input==self.searchInput then self.pickerOffset=0;self:DrawPicker()
                else
                    local action=self:EditorDraft()
                    if input==self.labelInput then action.label=input:GetText();action.autoLabel=nil
                    else action.value=input:GetText() end
                    self:DrawEditorPreview()
                end
            end
        end)
        box:SetScript("OnCursorChanged",function(input,_,y,_,lineHeight)
            if not y then return end
            local scroll,top=input.wecScroll,-y;local offset=scroll:GetVerticalScroll()
            if top<offset then scroll:SetVerticalScroll(math.max(0,top))
            elseif top+(lineHeight or 16)>offset+scroll:GetHeight() then
                scroll:SetVerticalScroll(math.max(0,top+(lineHeight or 16)-scroll:GetHeight()))
            end
        end)
        box:SetScript("OnEscapePressed",function()box:ClearFocus()end)
        return box
    end
    label(W.L["Enhanced Controller · Wheel spells"],24,16,592)
    self.profileLabel=label("",24,44,592)
    local pageRow=CreateFrame("Frame",nil,f);pageRow:SetAllPoints()
    self.editorPageButtons={}
    for i=1,3 do
        local b=button("",24+(i-1)*104,78,100,function()
            local id=self.editorPageButtons[i].pageID;if id then self:EditorPage(id) end
        end,30,pageRow)
        self.editorPageButtons[i]=b
    end
    self.addPage=button(W.L["Add page"],344,78,124,function()
        local id=D.AddPage(self:EditorProfile());if id then self:EditorPage(id) end
    end,30,pageRow)
    self.removePage=button(W.L["Remove page"],484,78,132,function()
        local pending=false;self:StoreNewDraft()
        for slot=1,8 do local a=self.editorNewDrafts[self.editorPage..":"..slot];if a and (a.value~="" or a.label~="")then pending=true end end
        if not pending and D.RemovePage(self.editorPage,self:EditorProfile()) then self:EditorPage(0)
        else self:EditorStatus(W.L["Empty this page before removing it."]) end
    end,30,pageRow)

    local previous=button("<",24,126,48,function()self:EditorSlot(math.max(1,self.editorIndex-1))end)
    previous.fieldLabel=W.L["Previous"]
    self.previousAction=previous
    self.actionLabel=label("",80,132,164)
    local nextAction=button(">",252,126,48,function()self:EditorSlot(math.min(#self:EditorProfile().actions+1,D.maxActions,self.editorIndex+1))end)
    nextAction.fieldLabel=W.L["Next"]
    self.nextAction=nextAction
    self.editorTabs={}
    for i, mode in ipairs({"spell","saved","custom"}) do
        self.editorTabs[i]=button(W.L[({"Spells","Macros","Custom"})[i]],24+(i-1)*200,78,192,function()
            self:ClearEditorFocus();self.pickerKind=nil
            local action=self:EditorDraft()
            local kind=(action.kind=="macro" or action.kind=="friendly") and "custom" or action.kind
            if kind~=mode then
                local info=action.kind=="spell" and D.Info(action.value)
                if action.autoLabel or action.label==action.value or (info and action.label==info.name) then action.label="" end
                action.kind=mode;action.value="";action.macroScope=nil;action.autoLabel=nil;action.highestRank=nil
            end
            if mode=="custom" and action.kind~="friendly" then action.kind="custom" end
            self:LoadAction()
        end,nil,nil,true)
    end
    self.sourceButton=button("",24,174,276,function()self:OpenEditorPicker()end,44)
    self.sourceButton:GetFontString():SetWordWrap(false)
    self.labelCaption=label(W.L["Label"],24,224,276)
    self.labelInput=field(24,250,276,40,false,W.L["Label"])
    self.valueCaption=label(W.L["Command / macro"],24,302,276)
    self.valueInput=field(24,330,276,96,true,W.L["Command / macro"])
    self.editorHelp=label("",24,304,276,120)
    local rank=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
    self.highestRank=rank;rank:SetSize(32,32);rank:SetPoint("TOPLEFT",24,-348)
    rank:SetHitRectInsets(0,-244,0,0);rank.fieldLabel=W.L["Highest learned rank"]
    rank.caption=label(rank.fieldLabel,38,0,214,40,rank)
    rank.promptIcon=rank:CreateTexture(nil,"OVERLAY");rank.promptIcon:SetSize(22,22);rank.promptIcon:SetPoint("LEFT",254,0)
    rank.focus=rank:CreateTexture(nil,"OVERLAY");rank.focus:SetPoint("TOPLEFT");rank.focus:SetSize(276,32);rank.focus:SetColorTexture(1,.75,.15,.2)
    rank.navX,rank.navY,rank.navWidth,rank.navHeight=162,364,276,32
    rank.run=function()
        if W.Combat() or W.Placement.editing then rank:SetChecked(self:EditorDraft().highestRank==true);return end
        local action=self:EditorDraft();action.highestRank=not action.highestRank;rank:SetChecked(action.highestRank);self:DrawEditorPreview()
    end
    rank:SetScript("OnClick",function()
        if GetTime()-(W.Input.padAt or -1)<.15 then rank:SetChecked(self:EditorDraft().highestRank==true);return end
        rank.run()
    end)
    self.editorControls[#self.editorControls+1]=rank
    self.previewTitle=label(W.L["Wheel preview"],328,126,288)
    local preview=CreateFrame("Frame",nil,f);self.editorPreview=preview
    preview:SetPoint("TOPLEFT",346,-212);preview:SetSize(252,252)
    preview.ring=preview:CreateTexture(nil,"BACKGROUND");preview.ring:SetAllPoints();preview.ring:SetAtlas("gamepad-radial-menu-wheelbg")
    preview.highlight=preview:CreateTexture(nil,"BORDER");preview.highlight:SetSize(252*169/540,252*165/540);preview.highlight:SetAtlas("gamepad-radial-menu-selected")
    preview.center=label("",83,94,86,64,preview);preview.center:SetJustifyH("CENTER")
    preview.cells={}
    for i=1,8 do
        local cell=button("",0,0,68,function()
            self:EditorCell(i)
        end,58,preview,true)
        W.Theme.FocusBadge(cell);cell.badgeIcon:Hide();cell.prompt:Show()
        cell.art=cell:CreateTexture(nil,"ARTWORK");cell.art:SetSize(26,26);cell.art:SetPoint("CENTER",0,3)
        cell.caption=label("",0,32,68,24,cell);cell.caption:SetJustifyH("CENTER");cell.caption:SetWordWrap(false)
        cell.fieldLabel="";preview.cells[i]=cell
    end
    self.previewDetail=label("",328,402,288,24)
    self.iconButton=button(W.L["Choose icon..."],328,424,288,function()
        self:ClearEditorFocus();local action=self:EditorDraft();local index=self.editorIndex
        for i,control in ipairs(self.editorControls) do if control==self.iconButton then self.editorSelected=i end end
        local _,_,icon=D.Compile(action,"player")
        W.IconPicker:Open({owner=f,returnButton=self.iconButton,selectedIcon=action.icon or icon or 134400,
            onSelect=function(value)if self.editorDrafts[index]==action then action.icon=value;self:DrawEditorPreview() end end,
            restoreFocus=function()if f:IsShown() then self:EditorFocus() end end})
    end,24)
    self.previewDetail:SetJustifyH("CENTER");self.previewDetail:SetWordWrap(false)
    self.customHelp=label(W.L["Use {unit} for the selected member."],24,488,296,40)
    self.addAction=button(W.L["Add action"],24,446,132,function()self:AddEditorAction()end)
    button(W.L["Remove"],172,446,132,function()
        self.editorNewDrafts[self.editorPage..":"..self.editorSlot]=nil
        table.remove(self:EditorProfile().actions,self.editorIndex)
        for i=self.editorIndex,D.maxActions do self.editorDrafts[i]=self.editorDrafts[i+1] end
        self:EditorSlot(math.max(1,math.min(self.editorIndex,#self:EditorProfile().actions+1)),true)
    end)
    local function move(delta)
        local actions,i=self:EditorProfile().actions,self.editorIndex;local action=actions[i]
        if not action then return end
        local slot=action.slot+delta;if slot<1 or slot>8 then return end
        local other=D.PageSlots(action.page,self:EditorProfile())[slot];local old=action.slot
        action.slot=slot
        if self.editorDrafts[i] then self.editorDrafts[i].slot=slot end
        if other then
            actions[other].slot=old
            if self.editorDrafts[other] then self.editorDrafts[other].slot=old end
        end
        local key,oldKey=action.page..":"..slot,action.page..":"..old
        local pending=self.editorNewDrafts[key]
        if not other and pending then pending.slot=old;self.editorNewDrafts[oldKey]=pending;self.editorNewDrafts[key]=nil end
        self:EditorSlot(i)
    end
    button(W.L["Move left"],320,446,140,function()move(-1)end)
    button(W.L["Move right"],476,446,140,function()move(1)end)
    self.saveAction=button(W.L["Save"],344,490,124,function()
        self:SaveEditor()
    end)
    button(W.L["Done"],484,490,132,function()self:CloseEditor()end)
    self.editorStatus=label("",24,534,592,42)
    self.pickerTitle=label("",24,164,276)
    self.searchInput=field(24,192,276,38,false,W.L["Search"])
    self.pickerList=CreateFrame("Frame",nil,f)
    self.pickerList:SetPoint("TOPLEFT",24,-284);self.pickerList:SetSize(276,160)
    self.pickerList:EnableMouseWheel(true)
    self.pickerList:SetScript("OnMouseWheel",function(_,delta)
        if self.pickerKind and not W.Combat() then self:ScrollPicker((self.pickerOffset or 0)-delta) end
    end)
    self.pickerRows={}
    for i=1,3 do
        local row=button("",0,(i-1)*54,260,function()
            local item=self.pickerRows[i].item
            if item then self:ChooseEditorItem(item) end
        end,52,self.pickerList)
        row.navX,row.navY=154,310+(i-1)*54
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel",self.pickerList:GetScript("OnMouseWheel"))
        row:HookScript("OnMouseDown",function(b) b.pressedItem=b.item;b.pressedGeneration=self.pickerGeneration end)
        row:SetScript("OnClick",function(b)
            if W.Input and GetTime()-(W.Input.padAt or -1)<.15 then return end
            local valid=self.pickerKind and b:IsVisible() and b.pressedItem==b.item and b.pressedGeneration==self.pickerGeneration
            b.pressedItem,b.pressedGeneration=nil,nil
            if valid then b.run() end
        end)
        row.art=row:CreateTexture(nil,"OVERLAY");row.art:SetSize(28,28);row.art:SetPoint("LEFT",6,0)
        row.caption=label("",42,4,182,44,row);row.caption:SetWordWrap(false)
        self.pickerRows[i]=row
    end
    self.pickerScrollBar=CreateFrame("EventFrame",nil,self.pickerList,"MinimalScrollBar")
    self.pickerScrollBar:SetPoint("TOPRIGHT");self.pickerScrollBar:SetHeight(160)
    self.pickerScrollBar:Init(1,1)
    self.pickerScrollBar:RegisterCallback(ScrollBarMixin.Event.OnScroll,function(_,percentage)
        if self.pickerScrollSync or not self.pickerKind or W.Combat() then return end
        local maximum=math.max(0,#(self.pickerFiltered or {})-#self.pickerRows)
        self.pickerNativeScrolling=true
        self:ScrollPicker(math.floor(percentage*maximum+.5))
        self.pickerNativeScrolling=nil
    end,self)
    self.pickerBack=button(W.L["Back"],24,402,276,function()self:CloseEditorPicker()end)
    self.pickerEmpty=label("",24,244,276,128)
    local function nativeNavigation()
        return settingsCanvas and W.Options.NativeNavigation()
    end
    local function pickerBack(token)
        if not self.pickerKind or token~=W.Input.keys.back then return false end
        local target=SmartNavigation:GetCurrentButton()
        while target do
            if target==f then return true end
            target=target:GetParent()
        end
        return false
    end
    if nativeNavigation() then
        for index,control in ipairs(self.editorControls) do
            local target=control.input or control
            target.OnSmartNavSelect=function() self.editorSelected=index; self:EditorFocus() end
            target.OnSmartNavDeselect=function()
                if control.focus then control.focus:Hide() end
                if control.prompt then W.Theme.Prompt(control,{},"corner") end
                if control.promptIcon then control.promptIcon:Hide() end
            end
        end
        -- The picker reuses three buttons. At an edge keep the cursor on the
        -- same button while advancing the data underneath it by one entry.
        local function pickerEdge(row, direction, delta)
            SmartNavigation_AddJumpNavigationOverride(row, SMART_NAV_INPUT_DIRECTION[direction], function()
                if not self.pickerKind or W.Combat() then return end
                local offset=self.pickerOffset
                self:ScrollPicker(offset+delta)
                if self.pickerOffset~=offset then return true end
            end)
        end
        pickerEdge(self.pickerRows[1],"UP",-1)
        pickerEdge(self.pickerRows[#self.pickerRows],"DOWN",1)
    end
    f:SetScript("OnGamePadButtonDown",function(_,token)
        if nativeNavigation() and not pickerBack(token) then return true end
        if not f:IsVisible() or W.Blocker() or W.Input.active or W.IconPicker.request or W.Combat() or W.Placement.editing then return true end
        W.lastPad=true;if self.editorHeld then return false end
        W.Input.padAt=GetTime()
        self.editorHeld={token=token,selected=self.editorSelected,generation=self.pickerGeneration}
        if token=="PADDLEFT" then self:EditorMove(-1,0)
        elseif token=="PADDRIGHT" then self:EditorMove(1,0)
        elseif token=="PADDUP" then self:EditorMove(0,-1)
        elseif token=="PADDDOWN" then self:EditorMove(0,1) end
        return false
    end)
    f:SetScript("OnGamePadButtonUp",function(_,token)
        local held=self.editorHeld;self.editorHeld=nil
        if not f:IsVisible() or W.Blocker() or W.Input.active or W.IconPicker.request or not held or held.token~=token or W.Combat() or W.Placement.editing then return true end
        W.Input.padAt=GetTime()
        if token==W.Input.keys.primary then
            if held.selected~=self.editorSelected or held.generation~=self.pickerGeneration then return false end
            local b=self.editorControls[self.editorSelected]
            if b and b:IsShown() and b:IsEnabled() then b.run() end
        elseif token==W.Input.keys.back then
            if self.pickerKind then self:CloseEditorPicker() else self:CloseEditor() end
        end
        return false
    end)
    f:SetScript("OnHide",function()
        if self.editorProfile and self.editorDrafts then self:StoreNewDraft() end
        self.editorHeld=nil;self:ClearEditorFocus();if W.IconPicker.request and W.IconPicker.request.owner==f then W.IconPicker:Close() end
        self.pickerScrollBar:UnregisterUpdate();self.pickerScrollBar:Hide()
    end)
    W.Input:TrackWindow(f,function()self.editorHeld=nil end,false,
        function() return not nativeNavigation() or self.pickerKind~=nil end)
end
function R:OpenEditorPicker()
    self:ClearEditorFocus()
    self.pickerKind=self:EditorDraft().kind
    if self.pickerKind=="custom" or self.pickerKind=="macro" or self.pickerKind=="friendly" then
        self.pickerKind="friendly";self.pickerSource=D.Presets()
        self.pickerSource[#self.pickerSource+1]={kind="custom",label=W.L["Write custom command..."],value="",detail="",icon=134400}
    else self.pickerSource=self.pickerKind=="spell" and D.Spells() or D.Macros() end
    self.pickerOffset=0;self.editorLoading=true;self.searchInput:SetText("");self.editorLoading=false
    self:DrawPicker()
    for i,b in ipairs(self.editorControls) do if b==self.pickerRows[1] and b:IsShown() then self.editorSelected=i;break end end
    self:EditorFocus()
end
function R:ScrollPicker(offset)
    if not self.pickerKind or W.Combat() then return end
    local maximum=math.max(0,#(self.pickerFiltered or {})-#self.pickerRows)
    offset=math.max(0,math.min(maximum,offset))
    if offset==self.pickerOffset then return end
    self.pickerOffset=offset;self:DrawPicker()
end
local function fold(text)
    local out={}
    for _,char in ipairs(W.Locale.Characters(text)) do out[#out+1]=W.Locale.Upper(char) end
    return table.concat(out)
end
function R:DrawPicker()
    local open=self.pickerKind~=nil
    W.Input:RefreshWindowCapture(self.editor)
    local action=self:EditorDraft();local custom=action.kind=="custom" or action.kind=="macro"
    self.sourceButton:SetShown(not open)
    self.iconButton:SetShown(not open)
    self.labelCaption:SetShown(not open);self.labelInput.wrapper:SetShown(not open)
    self.valueCaption:SetShown(not open and custom);self.valueInput.wrapper:SetShown(not open and custom)
    self.editorHelp:SetShown(not open and not custom)
    self.highestRank:SetShown(not open and action.kind=="spell")
    self.customHelp:SetShown(custom and not open)
    self.pickerTitle:SetShown(open);self.searchInput.wrapper:SetShown(open)
    self.pickerList:SetShown(open);self.pickerBack:SetShown(open)
    self.pickerEmpty:Hide()
    local filtered={}
    if open then
        local query=fold(self.searchInput:GetText())
        for _,item in ipairs(self.pickerSource) do
            if fold(item.label.." "..item.detail):find(query,1,true) then filtered[#filtered+1]=item end
        end
        self.pickerOffset=math.max(0,math.min(self.pickerOffset or 0,math.max(0,#filtered-#self.pickerRows)))
        self.pickerTitle:SetText(self.pickerKind=="spell" and W.L["Choose spell"] or self.pickerKind=="friendly" and W.L["Common actions"] or W.L["Choose macro"])
        if #filtered==0 then self.pickerEmpty:SetText(W.L["No matches. Learn spells or create macros in the game first."]);self.pickerEmpty:Show() end
    end
    self.pickerFiltered=filtered;self.pickerGeneration=(self.pickerGeneration or 0)+1
    for i,row in ipairs(self.pickerRows) do
        local item=open and filtered[(self.pickerOffset or 0)+i]
        row.item=item;row:SetShown(item~=nil and item~=false)
        if item then
            row.art:SetTexture(item.icon or 134400)
            row.caption:SetText(item.label..(item.detail~="" and "\n"..item.detail or ""))
            row.fieldLabel=item.label..(item.detail~="" and " · "..item.detail or "")
        end
    end
    local bar,maximum=self.pickerScrollBar,math.max(0,#filtered-#self.pickerRows)
    self.pickerScrollSync=true
    bar:SetVisibleExtentPercentage(#filtered>0 and math.min(1,#self.pickerRows/#filtered)or 1)
    bar:SetPanExtentPercentage(maximum>0 and 1/maximum or 1)
    if not self.pickerNativeScrolling then bar:SetScrollPercentage(maximum>0 and (self.pickerOffset or 0)/maximum or 0,true)end
    self.pickerScrollSync=nil
    if not open then bar:UnregisterUpdate()end
    bar:SetShown(open and maximum>0)
    self:EditorFocus()
end
function R:ChooseEditorItem(item)
    local action=self:EditorDraft()
    local old=D.Info(action.value)
    if item.kind=="friendly" then action.label=item.label;action.icon=item.icon end
    if action.label=="" or action.autoLabel or action.label==action.value or (action.kind=="spell" and old and action.label==old.name) then action.label=item.label end
    action.kind,action.value,action.macroScope=item.kind,item.value,item.macroScope
    if item.kind~="spell" then action.highestRank=nil end
    if item.kind=="custom" and item.value=="" then action.label="" end
    action.autoLabel=item.kind=="spell" and action.label==item.label or nil
    local actions=self:EditorProfile().actions
    if item.value~="" and self.editorIndex==#actions+1 then
        actions[self.editorIndex]=action
        self.editorNewDrafts[self.editorPage..":"..self.editorSlot]=nil
    end
    self:CloseEditorPicker()
end
function R:CloseEditorPicker()
    self:ClearEditorFocus();self.pickerKind=nil;self:LoadAction()
    for i,b in ipairs(self.editorControls) do if b==self.sourceButton then self.editorSelected=i end end
    self:EditorFocus()
end
function R:DrawEditorPreview()
    local preview=self.editorPreview
    if not preview or not self.editorDrafts then return end
    local profile=self:EditorProfile();local slots=D.PageSlots(self.editorPage,profile)
    local selected=self.editorSlot or 1
    local angle=(selected-1)*math.pi/4
    preview.highlight:ClearAllPoints();preview.highlight:SetPoint("CENTER",math.sin(angle)*70,math.cos(angle)*70)
    preview.highlight:SetRotation(-math.pi-angle)
    preview.center:SetText(D.PageName(self.editorPage))
    for i,cell in ipairs(preview.cells) do
        local index=slots[i]
        local action=index and (self.editorDrafts[index] or profile.actions[index]) or self.editorNewDrafts[self.editorPage..":"..i] or i==selected and self:EditorDraft()
        cell.index=index;cell:Show();cell:SetEnabled(true)
        local texture
        if action then local _,_,value=D.Compile(action,"player");texture=value end
        cell.art:SetTexture(action and action.icon or texture or 134400);cell.art:SetShown(action~=nil and action~=false)
        cell.caption:SetText(tostring(i));cell.fieldLabel=action and action.label~="" and action.label or W.L["New action"]
        local a=(i-1)*math.pi/4
        cell:ClearAllPoints();cell:SetPoint("CENTER",preview,"CENTER",math.sin(a)*88,math.cos(a)*88)
        cell.navX,cell.navY=472+math.sin(a)*88,338-math.cos(a)*88
    end
    local action=self:EditorDraft()
    self.previewDetail:SetText(W.L.Format("Selected: %s",action.label~="" and action.label or W.L["New action"]))
end
function R:LoadAction()
    for _,label in ipairs(self.editorLabels) do label:SetFontObject(W.Theme.Font("GameFontNormal")) end
    for _,control in ipairs(self.editorControls) do if control.SetNormalFontObject then W.Theme.ButtonFonts(control) end end
    for _,box in ipairs({self.labelInput,self.valueInput,self.searchInput}) do box:SetFontObject(W.Theme.Font("GameFontHighlight")) end
    local action=self:EditorDraft()
    self.editorLoading=true;self.labelInput:SetText(action.label);self.valueInput:SetText(action.value);self.editorLoading=false
    local mode=(action.kind=="macro" or action.kind=="friendly") and "custom" or action.kind
    for i,kind in ipairs({"spell","saved","custom"}) do W.Theme.Tab(self.editorTabs[i],mode==kind) end
    local profile=self:EditorProfile();local actions=profile.actions
    local slots=D.PageSlots(self.editorPage,profile);local used=0;for _ in pairs(slots) do used=used+1 end
    self.addAction:SetEnabled(used<8 and #actions<D.maxActions)
    local pages=profile.pages;local selected=1
    for i,id in ipairs(pages) do if id==self.editorPage then selected=i end end
    local first=math.max(1,math.min(selected-1,#pages-2))
    for i,b in ipairs(self.editorPageButtons) do
        local id=pages[first+i-1];b.pageID=id;b:SetShown(id~=nil)
        if id then b:SetText(id==0 and W.L["Main"] or D.PageName(id));b.fieldLabel=D.PageName(id);b.focus:SetShown(id==self.editorPage) end
    end
    self.addPage:SetEnabled(#pages<D.maxPages);self.removePage:SetEnabled(self.editorPage~=0)
    self.previousAction:SetEnabled(self.editorIndex>1)
    self.nextAction:SetEnabled(self.editorIndex<math.min(#actions+1,D.maxActions))
    self.profileLabel:SetText(D.PageName(self.editorPage).." · "..W.L.Format("%d / 8 slots",used))
    self.actionLabel:SetText(W.L.Format("Action %d / %d",self.editorIndex,math.max(1,#actions,self.editorIndex)))
    local info=mode=="spell" and D.SpellInfo(action)
    self.highestRank:SetChecked(action.highestRank==true)
    self.sourceButton:SetText(mode=="custom" and W.L["Common actions"] or (info and info.name) or (action.value~="" and action.value) or (mode=="spell" and W.L["Choose spell"] or W.L["Choose macro"]))
    self.sourceButton.fieldLabel=self.sourceButton:GetText()
    self.editorHelp:SetText(mode=="spell" and W.L["Spells cast directly on the selected member."] or W.L["Uses the saved macro's own conditions. An explicit target in that macro can override the chosen member."])
    self.editorHelp:ClearAllPoints();self.editorHelp:SetPoint("TOPLEFT",24,mode=="spell" and -390 or -352);self.editorHelp:SetHeight(mode=="spell" and 80 or 120)
    if mode=="spell" then self.editorHelp:SetText(W.L["Save applies all wheel edits. Unsaved edits are lost on reload."]) end
    if action.kind=="friendly" then self.editorHelp:SetText(action.value=="trade" and W.L["Targets this member and opens trade."] or action.value=="whisper" and W.L["Opens a whisper. Does not send a message."] or W.L["Uses the selected member."]) end
    if action.macroScope then self.editorHelp:SetText((action.macroScope=="account" and W.L["Account"] or W.L["Character"]).."\n"..self.editorHelp:GetText()) end
    self:DrawPicker();self:DrawEditorPreview();self:EditorFocus()
end
function R:CloseEditor()
    if not self.editor or W.Combat() then return end
    self:ClearEditorFocus();self.editor:Hide();self:SyncOwnership()
    if self.editorInSettings and W.Options.category then Settings.OpenToCategory(W.Options.category:GetID()) end
end
