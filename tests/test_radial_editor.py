"""Settings draft/picker contracts; these tests never certify client security."""
import unittest
import test_radial as fixture

SPELLBOOK = '''
Enum=Enum or {};Enum.SpellBookSpellBank={Player=0};Enum.SpellBookItemType={Spell=1,FutureSpell=2,Flyout=4}
Constants={MacroConsts={MAX_ACCOUNT_MACROS=120}}
HOST.book={
 {itemType=1,spellID=139,subName="Rank 1"},
 {itemType=1,spellID=17},
 {itemType=1,spellID=2061,isPassive=true},
 {itemType=2,spellID=2061},
 {itemType=1,spellID=2061,isOffSpec=true},
 {itemType=4,actionID=10},
 {itemType=1,spellID=2061},
}
C_SpellBook={GetNumSpellBookSkillLines=function()return 2 end,
 GetSpellBookSkillLineInfo=function(i)
  if i==1 then return {itemIndexOffset=0,numSpellBookItems=6,offSpecID=0} end
  return {itemIndexOffset=6,numSpellBookItems=1,offSpecID=2}
 end,
 GetSpellBookItemInfo=function(slot,bank)assert(bank==0);return HOST.book[slot]end}
function GetFlyoutInfo(id)assert(id==10);return "Ranks","",2,true end
function GetFlyoutSlotInfo(id,i)if i==1 then return 2061,2061,true end;return 17,17,false end
HOST.macros={[1]={"Same",111,"/cast Renew"},[2]={"Other",112,"/cast Renew"},[121]={"Same",113,"/cast Flash Heal"}}
function GetNumMacros()return 2,1 end
function GetMacroInfo(index)local m=HOST.macros[index];if m then return unpack(m)end end
'''

class RadialEditorTests(unittest.TestCase):
    def setUp(self):
        self.env=fixture.RadialTests();self.env.load_addon()
        self.env.run_lua(SPELLBOOK)
    def run_lua(self,code):self.env.run_lua(code)

    def test_spellbook_learned_active_current_spec_flyout_dedupe_and_numeric_cast(self):
        self.run_lua('''
            local D=W.RadialData;local list=D.Spells();assert(#list==3)
            assert(list[1].label=="Flash Heal" and list[3].detail=="Rank 1")
            local _,id=D.Compile({kind="spell",label="Rank",value="139"},"player");assert(id==139)
            C_SpellBook=nil;assert(#D.Spells()==0)
        ''')

    def test_macro_scopes_resolve_after_slot_shift_and_do_not_fall_back_to_names(self):
        self.run_lua('''
            local D=W.RadialData;local list=D.Macros();assert(#list==3)
            local a=list[1];local c=list[3];assert(a.value==c.value and a.macroScope~=c.macroScope)
            assert(select(2,D.Compile(c,"player"))==121)
            HOST.macros[1],HOST.macros[2]=HOST.macros[2],HOST.macros[1]
            assert(select(2,D.Compile(a,"player"))==2)
            HOST.macros[121]=nil;assert(not D.Validate(c))
        ''')

    def test_preview_drafts_survive_slot_navigation_and_save_only_explicitly(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;R:Edit()
            local original=D.Profile().actions[1].value
            R:OpenEditorPicker();R:ChooseEditorItem(R.pickerSource[3])
            assert(R:EditorDraft().value=="139" and D.Profile().actions[1].value==original)
            assert(R.editorPreview.cells[1].index==1)
            R:EditorSlot(2);R:EditorSlot(1);assert(R:EditorDraft().value=="139")
            R.saveAction.run();assert(D.Profile().actions[1].value=="139")
            assert(#HOST.actions==0 and not R.frame:IsShown())
            for i=4,8 do R:EditorProfile().actions[i]={kind="spell",value="139",label="Renew",page=0,slot=i} end
            R:EditorSlot(8)
            assert(R.editorPreview.cells[1]:IsEnabled() and R.editorPreview.cells[8].index==8)
            assert(R.editorPreview.center:GetText()=="Main (default)")
        ''')

    def test_picker_controller_activation_search_and_cancel(self):
        self.run_lua('''
            local R=W.Radial;R:Edit();R:OpenEditorPicker()
            assert(R.pickerRows[1]:IsShown() and not R.valueInput.wrapper:IsShown())
            local selected=R.pickerRows[1].item.value
            local f=R.editor;f:GetScript("OnGamePadButtonDown")(f,W.Input.keys.primary)
            f:GetScript("OnGamePadButtonUp")(f,W.Input.keys.primary)
            assert(not R.pickerKind and R:EditorDraft().value==selected)
            R:OpenEditorPicker();R.searchInput:SetText("rEnEw")
            assert(R.pickerRows[1].item.value=="139" and not R.pickerRows[2]:IsShown())
            f:GetScript("OnGamePadButtonDown")(f,W.Input.keys.back)
            f:GetScript("OnGamePadButtonUp")(f,W.Input.keys.back)
            assert(not R.pickerKind and R.editor:IsShown())
            R:OpenEditorPicker();R.searchInput:SetText("no match")
            assert(R.pickerEmpty:IsShown() and not R.pickerRows[1]:IsShown())
            for i=1,40 do R:EditorStep(1);assert(R.editorControls[R.editorSelected]:IsShown()) end
        ''')

    def test_custom_commands_recipient_templates_and_saved_macro_picker(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;R:Edit();R.editorTabs[3].run()
            assert(R.valueInput.wrapper:IsShown() and R.sourceButton:IsShown())
            R.labelInput:SetText("Focus heal");R.valueInput:SetText("/cast [@focus] Renew")
            R.saveAction.run();assert(D.Profile().actions[1].kind=="custom")
            local kind,body=D.Compile(D.Profile().actions[1],"raid3")
            assert(kind=="macro" and body=="/cast [@focus] Renew")
            assert(not D.Validate({kind="custom",label="Unsafe",value="/run print(1)"}))
            assert(not D.Validate({kind="custom",label="Long",value=string.rep("x",256)}))
            local _,recipient=D.Compile({kind="custom",label="Heal",value="/cast [@{unit}] Renew"},"raid3")
            assert(recipient=="/cast [@raid3] Renew")
            R.editorTabs[2].run();R:OpenEditorPicker();R:ChooseEditorItem(R.pickerSource[3])
            R.saveAction.run();assert(D.Profile().actions[1].macroScope=="character")
        ''')

    def test_picker_scroll_long_localized_labels_and_legacy_templates(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;R:Edit();R:OpenEditorPicker()
            for i=4,7 do R.pickerSource[i]={kind="spell",label="Spell"..i,value="139",detail="",icon=135907} end
            R:DrawPicker();R:ScrollPicker(3);assert(R.pickerOffset==3 and R.pickerRows[1].item.label=="Spell4")
            for i,b in ipairs(R.editorControls)do if b==R.pickerRows[1]then R.editorSelected=i end end;R:EditorFocus()
            assert(R.editorStatus:GetText():find("Spell4",1,true))
            R.pickerScrollBar:SetScrollPercentage(1);assert(R.pickerOffset==4)
            assert(R.pickerRows[3].item.label=="Spell7" and R.pickerScrollBar:IsShown())
            R:CloseEditorPicker()
            local name=string.rep("Ж",30)
            R:ChooseEditorItem({kind="spell",value="139",label=name})
            R.labelInput:SetText(name);R.saveAction.run();assert(D.Profile().actions[1].label==name)
            R:EditorProfile().actions[1]={kind="macro",label="Legacy",value="/cast [@{unit}] Renew",page=0,slot=1}
            R.editorDrafts={};R:LoadAction();assert(R.valueInput.wrapper:IsShown())
            R.editorTabs[3].run();R.valueInput:SetText("/cast [@focus] Renew")
            assert(D.Validate(R:EditorDraft()))
        ''')

    def test_continuous_picker_controller_mouse_scroll_recycling_and_native_settings_buttons(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;R:Edit();R:OpenEditorPicker()
            for i=4,31 do R.pickerSource[i]={kind="spell",label="Spell"..i,value=tostring(i),detail="",icon=135907}end
            R:DrawPicker();assert(not R.pickerPrevious and not R.pickerNext)
            for i,b in ipairs(R.editorControls)do
                if b==R.pickerRows[3]then R.editorSelected=i end
                if b.GetNormalTexture and b.tabSelected==nil and not b.badgeIcon and b~=R.highestRank then assert(b.template=="UIPanelButtonTemplate")end
            end
            R:EditorStep(1);assert(R.pickerOffset==1 and R.pickerRows[3].item.label=="Spell4")
            for i=1,27 do R:EditorStep(1)end
            assert(R.pickerOffset==28 and R.pickerRows[3].item.label=="Spell31")
            R.pickerScrollBar:SetScrollPercentage(0);assert(R.pickerOffset==0)
            R.pickerList:GetScript("OnMouseWheel")(R.pickerList,-1);assert(R.pickerOffset==1)
            local row=R.pickerRows[1];local before=R:EditorDraft().value
            assert(row.mouseWheelEnabled)
            row:GetScript("OnMouseWheel")(row,-1);assert(R.pickerOffset==2)
            row:GetScript("OnMouseDown")(row);R:ScrollPicker(3)
            HOST.now=HOST.now+1;row:GetScript("OnClick")(row)
            assert(R.pickerKind and R:EditorDraft().value==before)
            local f=R.editor;f:GetScript("OnGamePadButtonDown")(f,W.Input.keys.primary)
            R:ScrollPicker(4);f:GetScript("OnGamePadButtonUp")(f,W.Input.keys.primary)
            assert(R.pickerKind and R:EditorDraft().value==before)
            R.searchInput:SetText("no matching item");assert(R.pickerOffset==0 and not R.pickerScrollBar:IsShown())
            R.searchInput:SetText("");R:ScrollPicker(28)
            R.pickerScrollBar.cancelled=false;R:CloseEditorPicker()
            assert(R.pickerScrollBar.cancelled and not R.pickerScrollBar:IsShown()and #HOST.actions==0)
            R.editorTabs[2].run();R:OpenEditorPicker();assert(R.pickerOffset==0 and R.pickerRows[1].item.kind=="saved")
        ''')

    def test_add_from_zero_actions_stages_pending_selection_and_starts_next_slot(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;D.Profile().actions={};R:Edit()
            R:ChooseEditorItem({kind="spell",label="Renew",value="139",detail=""})
            assert(#D.Profile().actions==0)
            for i,b in ipairs(R.editorControls)do if b==R.addAction then R.editorSelected=i end end
            local f=R.editor;local function press(t)f:GetScript("OnGamePadButtonDown")(f,t);f:GetScript("OnGamePadButtonUp")(f,t)end
            f:GetScript("OnGamePadButtonUp")(f,W.Input.keys.primary);assert(#D.Profile().actions==0)
            press(W.Input.keys.primary)
            assert(#D.Profile().actions==0 and #R:EditorProfile().actions==1 and R:EditorProfile().actions[1].value=="139")
            assert(R.editorIndex==2 and R.pickerKind=="spell"and R.actionLabel:GetText()=="Action 2 / 2")
            R.addAction.run();assert(#D.Profile().actions==0 and #R:EditorProfile().actions==1 and R.editorIndex==2)
            R:ChooseEditorItem({kind="spell",label="Shield",value="17",detail=""})
            R.addAction.run();assert(#D.Profile().actions==0 and #R:EditorProfile().actions==2 and R.editorIndex==3)
            R:CloseEditorPicker();R:EditorSlot(1);R.labelInput:SetText("Unsaved rename")
            R.addAction.run();assert(#D.Profile().actions==0)
            R:CloseEditorPicker();R:EditorSlot(1);assert(R:EditorDraft().label=="Unsaved rename")
            assert(#HOST.actions==0 and #HOST.sent==0)
        ''')

    def test_add_validates_macro_and_capacity_without_losing_the_pending_draft(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;D.Profile().actions={};R:Edit();R.editorTabs[3].run()
            R.labelInput:SetText("Bad");R.valueInput:SetText("/run print(1)")
            assert(not R:AddEditorAction()and #D.Profile().actions==0 and R.editorIndex==1)
            assert(R:EditorDraft().value=="/run print(1)")
            R.valueInput:SetText("/cast [@{unit}] Renew");assert(R:AddEditorAction())
            assert(#D.Profile().actions==0 and #R:EditorProfile().actions==1 and R:EditorProfile().actions[1].kind=="custom")
            for i=2,7 do R:EditorProfile().actions[i]={kind="spell",label="Renew",value="139",page=0,slot=i}end
            R:CloseEditorPicker();R.editorPage,R.editorSlot=0,8;R:EditorSlot(8);R:ChooseEditorItem({kind="spell",label="Shield",value="17",detail=""})
            assert(not R:AddEditorAction()and #R:EditorProfile().actions==8 and R.editorIndex==8)
            assert(not R.addAction:IsEnabled()and not R:AddEditorAction()and #R:EditorProfile().actions==8)
            HOST.combat=true;assert(not R:AddEditorAction())
        ''')

    def test_dpad_follows_visible_rows_and_reaches_every_control_in_each_editor_mode(self):
        self.run_lua('''
            local R=W.Radial;R:Edit()
            local function select(b)for i,c in ipairs(R.editorControls)do if c==b then R.editorSelected=i;return end end end
            local function current()return R.editorControls[R.editorSelected]end
            local f=R.editor;local function press(t)f:GetScript("OnGamePadButtonDown")(f,t);f:GetScript("OnGamePadButtonUp")(f,t)end
            assert(current()==R.editorTabs[1])
            press("PADDRIGHT");assert(current()==R.editorTabs[2])
            press("PADDDOWN");assert(current()==R.nextAction)
            press("PADDDOWN");assert(current()==R.sourceButton)
            press("PADDUP");assert(current()==R.nextAction)
            press("PADDUP");assert(current()==R.editorTabs[2])
            local function check()
                local queue,seen={R.editorSelected},{[R.editorSelected]=true};local head=1
                while queue[head]do local index=queue[head];head=head+1
                    for _,token in ipairs({"PADDLEFT","PADDRIGHT","PADDUP","PADDDOWN"})do
                        R.editorSelected=index;press(token)
                        if not seen[R.editorSelected]then seen[R.editorSelected]=true;queue[#queue+1]=R.editorSelected end
                    end
                end
                for i,b in ipairs(R.editorControls)do if b:IsShown()and b:IsEnabled()then assert(seen[i],b.fieldLabel or b:GetText())end end
            end
            check();R.editorTabs[3].run();select(R.editorTabs[3]);check()
            R.editorTabs[1].run();R:OpenEditorPicker();check()
            assert(#HOST.actions==0 and #HOST.sent==0)
        ''')

if __name__=='__main__':unittest.main()
