-- Native Settings registration/value contract fixture; not a renderer or
-- controller focus emulator. Deliberately reject duplicate variable names.
HOST.settings={};HOST.initializers={};HOST.settingsOpened=nil;HOST.settingsCanvases={}
Settings={VarType={Boolean="boolean",String="string",Number="number"}}
function Settings.RegisterVerticalLayoutCategory(name)
    return {name=name,GetID=function()return 1234 end}
end
function Settings.RegisterAddOnCategory(category) HOST.settingsCategory=category end
function Settings.RegisterCanvasLayoutSubcategory(category,canvas,name)
    canvas:SetParent(SettingsPanel)
    local id=1235+#HOST.settingsCanvases
    HOST.settingsCanvases[#HOST.settingsCanvases+1]=canvas
    HOST.settingsCanvas=HOST.settingsCanvases[1]
    return {name=name,parent=category,GetID=function()return id end}
end
function Settings.RegisterAddOnSetting(category,id,key,db,kind,name,default)
    assert(not HOST.settings[id],"duplicate setting: "..id)
    if db[key]==nil then db[key]=default end
    local setting={category=category,id=id,key=key,db=db,kind=kind,name=name}
    function setting:SetValueChangedCallback(callback) self.callback=callback end
    function setting:SetValue(value) self.db[self.key]=value;if self.callback then self.callback(self,value) end end
    function setting:GetValue()return self.db[self.key]end
    HOST.settings[id]=setting
    return setting
end
MinimalSliderWithSteppersMixin={Label={Right="right"}}
function Settings.CreateSliderOptions(low,high,step)
    return {low=low,high=high,step=step,labels={},SetLabelFormatter=function(self,side,fn)self.labels[side]=fn end}
end
function Settings.CreateControlTextContainer()
    return {data={},Add=function(self,value,text)self.data[#self.data+1]={value,text}end,GetData=function(self)return self.data end}
end
for _,kind in ipairs({"Checkbox","Slider","Dropdown"})do
    Settings["Create"..kind]=function(category,setting,options)
        HOST.initializers[#HOST.initializers+1]={kind=kind,category=category,setting=setting,options=options}
    end
end
function CreateSettingsButtonInitializer(name,text,run,tooltip,search)
    assert(search~=nil)
    return {name=name,text=text,run=run}
end
function Settings.RegisterInitializer(category,initializer)HOST.initializers[#HOST.initializers+1]=initializer end
function Settings.OpenToCategory(id)
    HOST.settingsOpened=id;SettingsPanel:Show()
    for i,canvas in ipairs(HOST.settingsCanvases) do
        if id==1234+i then
            canvas:Show()
        else canvas:Hide() end
    end
end
SettingsPanel=CreateFrame("Frame","SettingsPanel",UIParent);SettingsPanel:Hide()
