local _, W = ...
local P = {}
W.IconPicker = P
local function fold(text)
    local chars={}
    for _,char in ipairs(W.Locale.Characters(tostring(text))) do chars[#chars+1]=W.Locale.Upper(char) end
    return table.concat(chars)
end
-- Reuse the widget, not Blizzard's registered macro-window focus manager.
WoWEnhancedControllerIconPickerMixin = {
    RegisterForTransitions=function()end,
    OnShow=function(self)
        self:RegisterEvent("CURSOR_CHANGED");self:RegisterEvent("GLOBAL_MOUSE_UP")
        self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconSelector(self)
        self.BorderBox.IconSelectorEditBox:SetIconSelector(self)
        self:UpdateStateFromCursorType()
    end,
    OnHide=function(self)self:UnregisterEvent("CURSOR_CHANGED");self:UnregisterEvent("GLOBAL_MOUSE_UP")end,
}

-- Caller-neutral native picker. Only a confirmed icon is returned to the caller;
-- this module never writes radial actions, macros, or SavedVariables.
function P:Finish(confirmed)
    local request=self.request
    if not request then return end
    local icon=self.frame.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()
    self.request=nil
    self.frame:Hide()
    if confirmed then if request.onSelect then request.onSelect(icon) end
    elseif request.onCancel then request.onCancel() end
    if request.restoreFocus then request.restoreFocus() end
end
function P:Close() self:Finish(false) end
function P:Filter()
    local f=self.frame
    if not f or not self.request then return end
    local query=fold(f.BorderBox.IconSelectorEditBox:GetText() or "")
    self.filtered={}
    for i=1,f.iconDataProvider:GetNumIcons() do
        local icon=f.iconDataProvider:GetIconByIndex(i)
        local name=self.names[icon] or ""
        local key=self.searchText[icon]
        if query~="" and not key then key=fold(tostring(icon).." "..name);self.searchText[icon]=key end
        if query=="" or key:find(query,1,true) then self.filtered[#self.filtered+1]=icon end
    end
    f.IconSelector:UpdateSelections();f:ReevaluateSelectedIcon();f.IconSelector:ScrollToSelectedIndex()
    self.index=math.min(math.max(1,self.index or 1),math.max(1,#self.filtered));self.generation=(self.generation or 0)+1
    self:Focus()
end
function P:Focus()
    local f=self.frame;if not f or not self.request then return end
    f.BorderBox.OkayButton:SetEnabled(f.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()~=nil)
    for _,region in ipairs({f.searchFocus,f.filterFocus})do region:Hide()end
    if self.zone=="search" then f.searchFocus:Show()
    elseif self.zone=="filter" then f.filterFocus:Show()
    elseif self.zone=="grid" and #self.filtered>0 then
        f.IconSelector:SetSelectedIndex(self.index);f.IconSelector:ScrollToSelectedIndex()
    end
    local function glyph(action)
        local atlas=W.Input:Icon(action)
        return atlas and "|A:"..atlas..":20:20|a" or W.Input:Hint(action)
    end
    f.hint:SetText(W.L.Format("%s Select · %s Use icon · %s Back",glyph("primary"),glyph("shift"),glyph("back")))
end
function P:Move(token)
    if self.zone=="grid" then
        local n=self.index or 1
        if token=="PADDUP" and n<=10 then self.zone="search"
        elseif token=="PADDDOWN" then n=n+10
        elseif token=="PADDUP" then n=n-10
        elseif token=="PADDLEFT" then n=n-1
        elseif token=="PADDRIGHT" then n=n+1 end
        self.index=math.max(1,math.min(math.max(1,#self.filtered),n))
    elseif token=="PADDDOWN" then self.zone="grid"
    elseif token=="PADDLEFT" then self.zone="search"
    elseif token=="PADDRIGHT" then self.zone="filter" end
    self:Focus()
end
function P:Activate()
    local f=self.frame
    if self.zone=="search" then f.BorderBox.IconSelectorEditBox:SetFocus();W.WatchFocus()
    elseif self.zone=="filter" then
        local filters={IconSelectorPopupFrameIconFilterTypes.All,IconSelectorPopupFrameIconFilterTypes.Spell,IconSelectorPopupFrameIconFilterTypes.Item}
        local current=1;for i,value in ipairs(filters)do if value==f.iconFilter then current=i end end
        f:SetIconFilter(filters[current%3+1])
    else
        local icon=self.filtered[self.index or 1]
        if icon then f.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon);f:SetSelectedIconText() end
    end
end
function P:Create()
    local owner=CreateFrame("Frame",nil,UIParent);owner:Hide();owner:SetFrameStrata("TOOLTIP");owner:SetAllPoints()
    self.owner=owner
    local f=CreateFrame("Frame","WoWEnhancedControllerIconPicker",owner,"WoWEnhancedControllerIconPickerTemplate")
    self.frame=f
    f.IconSelector:SetFrameStrata("TOOLTIP")
    if UISpecialFrames then table.insert(UISpecialFrames,"WoWEnhancedControllerIconPicker") end
    f:ClearAllPoints();f:SetPoint("CENTER",UIParent);f:EnableMouse(true)
    f.BG:SetColorTexture(0,0,0,1)
    f.BorderBox.EditBoxHeaderText:SetText(W.L["Search icons (spell name or ID)"])
    local search=f.BorderBox.IconSelectorEditBox
    search:SetAutoFocus(false);search:SetMaxLetters(0);search:SetMaxBytes(128);search:SetIconSelector(f)
    search.wecOwned=false
    search:SetScript("OnTextChanged",function() if not self.loading then self:Filter() end end)
    search:SetScript("OnEnterPressed",function()search:ClearFocus();self.zone="grid";self:Focus()end)
    search:SetScript("OnEscapePressed",function()search:ClearFocus();self.zone="grid";self:Focus()end)
    f.searchFocus=search:CreateTexture(nil,"OVERLAY");f.searchFocus:SetAllPoints();f.searchFocus:SetColorTexture(1,.75,.15,.2)
    f.filterFocus=f.BorderBox.IconTypeDropdown:CreateTexture(nil,"OVERLAY");f.filterFocus:SetAllPoints();f.filterFocus:SetColorTexture(1,.75,.15,.2)
    f.hint=W.Theme.Label(f,"");f.hint:SetPoint("TOP",f,"BOTTOM",0,-12);f.hint:SetSize(525,30)
    f.GetNumIcons=function()return #(self.filtered or {})end
    f.GetIconByIndex=function(_,index)return self.filtered and self.filtered[index]end
    f.GetIndexOfIcon=function(_,icon)for i,value in ipairs(self.filtered or {})do if value==icon then return i end end end
    f.SetIconFilterInternal=function(frame,filter)
        frame.iconFilter=filter
        local types=filter==IconSelectorPopupFrameIconFilterTypes.Spell and {IconDataProviderIconType.Spell}
            or filter==IconSelectorPopupFrameIconFilterTypes.Item and {IconDataProviderIconType.Item}
            or IconDataProvider_GetAllIconTypes()
        frame.iconDataProvider:SetIconTypes(types);self:Filter()
    end
    f.OkayButton_OnClick=function()self:Finish(true)end
    f.CancelButton_OnClick=function()self:Close()end
    f.IconSelector:SetSelectedCallback(function(index,icon)
        self.index=index;self.zone="grid";self.generation=(self.generation or 0)+1
        f.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon)
        f.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription:SetText(ICON_SELECTION_CLICK)
    end)
    f:SetScript("OnGamePadButtonDown",function(_,token)
        if not self.request or not f:IsVisible() or W.Blocker() or W.Input.active or W.Combat() then return true end
        if self.held then return false end
        W.lastPad=true;W.Input.padAt=GetTime();self.held={token=token,zone=self.zone,index=self.index,generation=self.generation}
        if token:match("^PADD") then self:Move(token) end
        return false
    end)
    f:SetScript("OnGamePadButtonUp",function(_,token)
        local held=self.held;self.held=nil
        if not self.request or not f:IsVisible() or W.Blocker() or W.Input.active or not held or held.token~=token or W.Combat() then return true end
        W.Input.padAt=GetTime()
        if token==W.Input.keys.back then self:Close()
        elseif held.zone==self.zone and held.index==self.index and held.generation==self.generation then
            if token==W.Input.keys.primary then self:Activate()
            elseif token==W.Input.keys.shift then self:Finish(true) end
        end
        return false
    end)
    f:HookScript("OnHide",function()
        self.held=nil;local session=W.Keyboard.session
        if session and session.target==search then W.Keyboard:Close() end
        search:ClearFocus()
        if f.iconDataProvider then f.iconDataProvider:Release();f.iconDataProvider=nil end
        self.owner:Hide()
        if self.request then local request=self.request;self.request=nil
            if request.onCancel then request.onCancel() end
            if request.restoreFocus then request.restoreFocus() end
        end
    end)
    owner:RegisterEvent("PLAYER_REGEN_DISABLED")
    owner:SetScript("OnEvent",function()self:Close()end)
    owner:SetScript("OnUpdate",function()
        if self.request and self.request.owner and not self.request.owner:IsShown() then self:Close() end
    end)
    W.Input:TrackWindow(f,function()self.held=nil end)
end
function P:Open(request)
    request=request or {}
    if W.Combat() then return false end
    if not IconDataProviderMixin or not IconSelectorPopupFrameTemplateMixin then
        W.Print(W.L["The native icon picker is unavailable."]);return false
    end
    self:Close();if not self.frame then self:Create() end
    self.request=request or {};self.searchText={};self.names={ [134400]=W.L["Automatic"] }
    for _,item in ipairs(W.RadialData and W.RadialData.Spells and W.RadialData.Spells() or {}) do
        self.names[item.icon]=(self.names[item.icon] or "").." "..item.label.." "..tostring(item.value or "")
    end
    local f=self.frame
    f.iconDataProvider=CreateAndInitFromMixin(IconDataProviderMixin,IconDataProviderExtraType.Spellbook)
    f.iconFilter=IconSelectorPopupFrameIconFilterTypes.All;f:UpdateDropdown()
    self.loading=true;f.BorderBox.IconSelectorEditBox:SetText("");self.loading=nil
    self.filtered={};self.zone="grid";self.index=1;self.held=nil
    f.IconSelector:SetSelectionsDataProvider(function(i)return f:GetIconByIndex(i)end,function()return f:GetNumIcons()end)
    self:Filter()
    f.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(request.selectedIcon or 134400)
    f:ReevaluateSelectedIcon();f.IconSelector:ScrollToSelectedIndex()
    f:SetScale(math.min(1.15,(UIParent:GetWidth()-40)/525,(UIParent:GetHeight()-80)/495))
    self.owner:Show();f:Show()
    self.index=f:GetIndexOfIcon(request.selectedIcon or 134400) or 1;self:Focus()
    return true
end
