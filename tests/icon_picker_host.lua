-- Native-widget contract fixture, not a renderer or controller focus emulator.
IconDataProviderMixin={};IconSelectorPopupFrameTemplateMixin={}
IconDataProviderExtraType={Spellbook=1};IconDataProviderIconType={Spell=1,Item=2}
IconSelectorPopupFrameIconFilterTypes={All=1,Spell=2,Item=3}
function IconDataProvider_GetAllIconTypes()return {1,2}end
HOST.iconReleases=0;HOST.iconCatalog={134400,135907,999,"Interface/Icons/UserArt"}
function CreateAndInitFromMixin()
    local provider={icons=HOST.iconCatalog}
    function provider:GetNumIcons()return #self.icons end
    function provider:GetIconByIndex(i)return self.icons[i]end
    function provider:SetIconTypes(types)self.icons=#types==2 and HOST.iconCatalog or types[1]==1 and {134400,135907} or {999,"Interface/Icons/UserArt"}end
    function provider:Release()HOST.iconReleases=HOST.iconReleases+1 end
    return provider
end
local create=CreateFrame
function CreateFrame(kind,name,parent,template)
    local f=create(kind,name,parent,template)
    if template=="WoWEnhancedControllerIconPickerTemplate" then
        local b=create("Frame",nil,f);f.BorderBox=b
        b.OkayButton=create("Button",nil,b);b.CancelButton=create("Button",nil,b)
        b.EditBoxHeaderText=b:CreateFontString();b.IconSelectorEditBox=create("EditBox",nil,b)
        b.IconSelectorEditBox.SetIconSelector=function()end
        b.IconTypeDropdown=create("Button",nil,b)
        b.SelectedIconArea={SelectedIconButton=create("Button",nil,b),SelectedIconText={SelectedIconDescription=b:CreateFontString()}}
        local icon=b.SelectedIconArea.SelectedIconButton
        function icon:SetIconTexture(value)self.icon=value end
        function icon:GetIconTexture()return self.icon end
        f.BG=f:CreateTexture();f.IconSelector=create("Frame",nil,f)
        local grid=f.IconSelector
        function grid:SetSelectedCallback(fn)self.callback=fn end
        function grid:SetSelectionsDataProvider(item,count)self.item,self.count=item,count end
        function grid:SetSelectedIndex(i)self.selected=i end
        function grid:GetSelectedIndex()return self.selected end
        function grid:UpdateSelections()end
        function grid:ScrollToSelectedIndex()self.scrolled=self.selected end
        function f:UpdateDropdown()end
        function f:SetIconFilter(value)self:SetIconFilterInternal(value);self:UpdateDropdown()end
        function f:ReevaluateSelectedIcon()grid:SetSelectedIndex(self:GetIndexOfIcon(icon:GetIconTexture()))end
        function f:SetSelectedIconText()end
    end
    return f
end
