"""Full-TOC macro authoring contracts. No real-client security claims."""
import unittest
import test_radial as fixture
from test_radial_editor import SPELLBOOK

NATIVE = r'''
Constants.MacroConsts.MAX_CHARACTER_MACROS=30
HOST.macroCalls={};HOST.account={};HOST.character={}
local methods=getmetatable(UIParent).__index
function methods:SetJustifyV(value) self.justifyV=value end
function methods:SetTextColor(...) self.textColor={...} end
function methods:EnableKeyboard(value) self.keyboard=value end
function methods:SetPropagateKeyboardInput(value) self.propagate=value end
function GetNumMacros() return #HOST.account,#HOST.character end
local function resolve(index) return index>120 and HOST.character or HOST.account,index>120 and index-120 or index end
function GetMacroInfo(index) local list,n=resolve(index);if list[n]then return unpack(list[n])end end
C_Macro={GetSelectedMacroIcon=function(index)local list,n=resolve(index);return list[n] and list[n][2]end}
function CreateMacro(name,icon,body,character)
 assert(not HOST.combat);local list=character and HOST.character or HOST.account
 HOST.macroCalls[#HOST.macroCalls+1]='create'
 list[#list+1]={name,icon,HOST.truncate and body:sub(1,10) or body}
 return #list+(character and 120 or 0)
end
function EditMacro(index,name,icon,body)
 assert(not HOST.combat);local list,n=resolve(index)
 HOST.macroCalls[#HOST.macroCalls+1]='edit';assert(list[n])
 list[n]={name,icon,HOST.truncate and body:sub(1,10) or body}
 return index
end
function DeleteMacro(index)
 assert(not HOST.combat);local list,n=resolve(index)
 HOST.macroCalls[#HOST.macroCalls+1]='delete';table.remove(list,n)
end
function HOST.MacroPress(token)
 local e=W.MacroEditor
 local binding=e.inputOwner.binds[token]
 if not binding then return end
 local button=_G[binding[1]]
 local click=button:GetScript("OnClick")
 click(button,binding[2],true);click(button,binding[2],false)
end
function HOST.Draft(name,scope,text)
 return {name=name,scope=scope or 'account',icon=134400,raw=text or '/cast Renew'}
end
'''

class MacroTests(unittest.TestCase):
    def setUp(self):
        self.env=fixture.RadialTests();self.env.load_addon()
        self.env.run_lua(SPELLBOOK+NATIVE)
    def run_lua(self,code): self.env.run_lua(code)

    def test_localized_compilation_ranks_compound_conditions_and_missing_spells(self):
        self.run_lua('''
            local C=W.MacroCompiler
            local m={tooltip=true,blocks={{kind="cast",rules={
                {spellID=139,ranked=true,target="focus",modifier="shift",relation="help",alive=true,combat="combat",form=0},
                {spellID=139,target="player"}}}}}
            local text,errors=C.Compile(m)
            assert(#errors==0 and text=="#showtooltip\\n/cast [@focus,mod:shift,help,nodead,combat,form:0] Renew(Rank 1); [@player] Renew")
            m.blocks[1].rules[1].spellID=99999
            assert(#select(2,C.Compile(m))==1)
            assert(not C.Conditions({target="target] /run anything"}))
            assert(not C.Block({kind="command",verb="run",arg="anything"}))
        ''')

    def test_sequence_order_reset_and_failure_semantics(self):
        self.run_lua('''
            local C=W.MacroCompiler
            local block={kind="sequence",target="player",steps={{spellID=139},{spellID=17}},resetSeconds=10,resetTarget=true,resetCombat=true,resetModifier="shift"}
            assert(C.Block(block)=="/castsequence [@player] reset=10/target/combat/shift Renew, Power Word: Shield")
            local _,state=C.Preview(block,{modifier="none"});assert(state.index==2)
            _,state=C.Preview(block,{failed=true},state);assert(state.index==2)
            _,state=C.Preview(block,{event="combat"},state);assert(state.index==1)
            _,state=C.Preview(block,{modifier="shift"},{index=2});assert(state.index==2)
            local cast={kind="cast",rules={{spellID=17,target="focus",relation="harm"},{spellID=139,target="player"}}}
            local text=C.Preview(cast,{focus="harm",failed=true});assert(text:find("Power Word: Shield",1,true) and text:find("not retried",1,true))
            assert(#HOST.actions==0)
        ''')

    def test_crud_scope_identity_external_edit_and_shifted_slot(self):
        self.run_lua('''
            local D=W.MacroData
            local a=assert(D.Save(HOST.Draft("Other")))
            local b=assert(D.Save(HOST.Draft("Same")))
            local c=assert(D.Save(HOST.Draft("Same","character")))
            assert(b.index==2 and c.index==121)
            assert(D.Delete(a));assert(D.Resolve(b).index==1)
            local model,snapshot=D.Load(b);assert(model.blocks[1].kind=="raw")
            model.name="Renamed";local saved=assert(D.Save(model,snapshot));assert(saved.name=="Renamed")
            HOST.account[1][3]="/cast Different"
            assert(not D.Save(model,saved));assert(HOST.account[1][3]=="/cast Different")
            assert(not D.Delete(saved));assert(#HOST.character==1)
        ''')

    def test_raw_utf8_limits_capacity_and_native_truncation_rollback(self):
        self.run_lua('''
            local D=W.MacroData;local body='/cast [@focus,exists] Renew\\n/run print("用户")'
            local saved=assert(D.Save(HOST.Draft("用户",nil,body)))
            local model,snapshot=D.Load(saved);assert(W.MacroCompiler.Compile(model)==body)
            model.icon=123;assert(D.Save(model,snapshot).body==body)
            assert(not D.Save(HOST.Draft("Long",nil,string.rep("x",256))))
            assert(not D.Save(HOST.Draft(string.rep("名",17))))
            assert(W.MacroCompiler.Characters(string.rep("名",16))==16)
            Constants.MacroConsts.MAX_CHARACTER_MACROS=0
            assert(not D.Save(HOST.Draft("Full","character")))
            HOST.truncate=true
            assert(not D.Save(HOST.Draft("Truncated",nil,"/cast Power Word: Shield")))
            assert(#HOST.account==1)
            HOST.combat=true;assert(not D.Save(HOST.Draft("Combat")));assert(not D.Delete(saved))
        ''')

    def test_structured_metadata_recovers_only_exact_body_and_preserves_native_text(self):
        self.run_lua('''
            local D=W.MacroData
            local model={name="Test",icon=134400,scope="account",tooltip=true,blocks={{kind="cast",rules={{spellID=139}}}}}
            local saved=assert(D.Save(model));local recovered=D.Load(saved);assert(recovered.blocks[1].kind=="cast")
            HOST.account[1][3]="/cast [@focus] Renew"
            recovered=D.Load(D.List("account")[1]);assert(recovered.blocks[1].kind=="raw" and W.MacroCompiler.Compile(recovered)==HOST.account[1][3])
            assert(#W.MacroTemplates.list==28)
            for _,class in ipairs(W.MacroTemplates.classes)do assert(#W.MacroTemplates.Filter("class",class)==2)end
        ''')

    def test_ui_save_guard_shared_picker_and_keyboard_handoff(self):
        self.run_lua('''
            local E=W.MacroEditor;assert(E:Open());assert(E.frame:GetWidth()==1280 and not W.Radial.baseBound)
            E.controls.name:SetText("Draft");E:Tab("commands");E.controls.commands:SetText("/cast Renew")
            assert(#HOST.macroCalls==0 and E.dirty)
            E:Back();assert(E.modal and E.modal.title=="Unsaved macro")
            E.controls.choice1.run();assert(not E.modal and E.dirty)
            E.controls.save.run();assert(#HOST.account==1 and not E.dirty)
            E:Tab("build");local before=E.model
            local old=W.IconPicker.Open
            W.IconPicker.Open=function(_,request)HOST.iconRequest=request;return true end
            E.controls.icon.run();assert(HOST.iconRequest.owner==E.frame)
            HOST.iconRequest.onSelect(1234);HOST.iconRequest.restoreFocus()
            assert(E.model==before and E.model.icon==1234 and E.selected=="icon")
            W.IconPicker.Open=old
            E:Focus("name");HOST.MacroPress(W.Input.keys.primary)
            assert(W.Keyboard.session.target==E.controls.name and not E:Eligible())
            W.Keyboard:Close();E:Back();E.controls.choice3.run();assert(not E.frame:IsShown())
        ''')

    def test_toolbar_bind_saves_then_hands_off_and_restores_controller_focus(self):
        self.run_lua('''
            local E=W.MacroEditor;E:Open();E.model=HOST.Draft("Toolbar");E.dirty=true;E:Draw();E:RequestFocus()
            C_GamePad={IsEnabled=function()return true end}
            local native=CreateFrame("Frame");native:Hide();GamepadActionBarEditFrame=native
            function native:BindMacro(index)
                assert(not E.frame:IsShown() and not E.frame:IsGamePadButtonEnabled())
                assert(W.Blocker() and not W.Radial.baseBound)
                assert(GetMacroInfo(index)=="Toolbar");self.bound=index;self:Show()
            end
            E:Preview();assert(E.bind:GetText()=="Save & bind" and E.bind:IsEnabled())
            E:Focus("bind");HOST.MacroPress(W.Input.keys.primary)
            assert(native.bound==1 and E.binding and not E.dirty and not E:Eligible())
            assert(not E:Open() and #HOST.account==1)
            local update=E.events:GetScript("OnUpdate")
            -- Native transition between binding and bar-edit modes hides/shows synchronously.
            native:Hide();native:Show();update(E.events,.2);assert(not E.frame:IsShown())
            native:Hide();update(E.events,.2)
            assert(not E.binding and E.frame:IsShown() and E.selected=="bind")
            assert(E.inputOwner.binds[W.Input.keys.primary] and E.bind:GetText()=="Bind to toolbar")
            assert(E.events:GetScript("OnUpdate")==nil and #HOST.account==1)
        ''')

    def test_toolbar_bind_resolves_moved_slots_and_rejects_external_changes(self):
        self.run_lua('''
            local E=W.MacroEditor;E:Open();E:Load(assert(W.MacroData.Save(HOST.Draft("BindMe"))))
            C_GamePad={IsEnabled=function()return true end}
            local native=CreateFrame("Frame");native:Hide();GamepadActionBarEditFrame=native
            function native:BindMacro(index) self.bound=index;self:Show() end
            table.insert(HOST.account,1,{"Earlier",134400,"/cast Other"})
            assert(E:Bind() and native.bound==2)
            native:Hide();E.events:GetScript("OnUpdate")(E.events,.2)
            native.bound=nil;HOST.account[2][3]="/cast Changed elsewhere"
            assert(not E:Bind() and not native.bound and E.frame:IsShown())
            E.model=HOST.Draft("CannotSave");E.snapshot=nil;E.dirty=true;HOST.truncate=true
            assert(not E:Bind() and not native.bound and E.dirty and E.frame:IsShown())
        ''')

    def test_toolbar_bind_failure_and_interrupted_return_do_not_steal_focus(self):
        self.run_lua('''
            local E=W.MacroEditor;E:Open();E.model=HOST.Draft("Saved");E.dirty=true;assert(E:Save())
            C_GamePad={IsEnabled=function()return true end}
            local native=CreateFrame("Frame");native:Hide();GamepadActionBarEditFrame=native
            function native:BindMacro() error("unavailable native flow") end
            assert(not E:Bind() and E.frame:IsShown() and not E.binding and not E.dirty)
            function native:BindMacro()self:Show()end
            assert(E:Bind());HOST.combat=true
            E.events:GetScript("OnEvent")(E.events,"PLAYER_REGEN_DISABLED")
            native:Hide();E.events:GetScript("OnUpdate")(E.events,.2)
            assert(not E.binding and not E.frame:IsShown())
            HOST.combat=false;E:Open();assert(E:Bind())
            E.events:GetScript("OnEvent")(E.events,"GAME_PAD_DISCONNECTED")
            native:Hide();E.events:GetScript("OnUpdate")(E.events,.2)
            assert(not E.binding and not E.frame:IsShown())
            E:Open();GamepadActionBarEditFrame=nil;E:Preview()
            assert(not E.bind:IsEnabled() and E.bind:GetText()=="Binding unavailable")
        ''')

    def test_paired_input_redraw_record_replacement_modals_and_combat(self):
        self.run_lua('''
            local E=W.MacroEditor;E:Open();local f=E.frame
            local click=E.inputButton:GetScript("OnClick")
            E:Focus("add-action");click(E.inputButton,W.Input.keys.primary,true);E:Draw();click(E.inputButton,W.Input.keys.primary,false)
            assert(not E.modal and #E.model.blocks==0)
            E:Focus("add-action");HOST.MacroPress(W.Input.keys.primary);assert(E.modal)
            E:Focus("choice1");HOST.MacroPress(W.Input.keys.primary);assert(#E.model.blocks==1 and E.detail==1)
            local stale=E.controls["remove-action"].run;E.model=W.Copy(E.model);stale();assert(#E.model.blocks==1)
            E:Draw();E:Focus("step1");HOST.MacroPress(W.Input.keys.primary);assert(E.rule==1)
            E.controls["rule-spell"].run();assert(E.modal)
            local hidden=E.pools.button[1].run;hidden();assert(E.modal)
            HOST.combat=true;E.events:GetScript("OnEvent")(E.events,"PLAYER_REGEN_DISABLED")
            assert(not f:IsShown() and E.dirty and #HOST.macroCalls==0)
            HOST.combat=false;E:Open();assert(#E.model.blocks==1 and not E.modal)
        ''')

    def test_navigation_reaches_all_controls_and_template_actions(self):
        self.run_lua('''
            local E=W.MacroEditor;E:Open()
            local function check()
                local reached={};local pending={E.order[1].id}
                while #pending>0 do local id=table.remove(pending);if not reached[id]then
                    reached[id]=true
                    for _,dir in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do E:Focus(id);E:Move(unpack(dir));if not reached[E.selected]then pending[#pending+1]=E.selected end end
                end end
                for _,b in ipairs(E.order)do assert(not b:IsEnabled() or reached[b.id],b.id)end
            end
            check();E:Tab("templates");check()
            E.category="sequence";E:Draw();check()
            E.controls["template-generic-sequence"].run();check();E.controls.choice1.run()
            assert(E.model.templateID=="generic-sequence" and E.dirty)
            E.controls.action1.run();check()
            assert(E.controls["sequence-settings"] and E.controls.step1)
            E.controls["sequence-settings"].run();check()
        ''')

    def test_settings_filters_do_not_dirty_drafts_and_input_redraw_keeps_status(self):
        self.run_lua('''
            local E=W.MacroEditor;E:Open();E:Tab("templates")
            E.controls["template-category"].run();E.controls.choice4.run()
            assert(E.category=="sequence" and not E.dirty)
            E:Status("Keep this error");E:Draw();assert(E.message=="Keep this error")
            E:Tab("commands");E.controls.commands:SetText("/cast Renew");E.model.name="Test"
            E:Status("Keep this error");E:Draw();assert(E.message=="Keep this error")
            E:Choose("Modal",{{label="Close",run=function()end}})
            assert(E.shade:IsShown());E.controls.choice1.run();assert(not E.shade:IsShown())
        ''')

    def test_failed_sorted_rename_rolls_back_returned_slot_only(self):
        self.run_lua('''
            local D=W.MacroData
            local a=assert(D.Save(HOST.Draft("Alpha",nil,"/cast Renew")))
            assert(D.Save(HOST.Draft("Other",nil,"/cast Different")))
            local nativeEdit=EditMacro;local once=true
            EditMacro=function(index,name,icon,body)
                if once then
                    once=false;table.remove(HOST.account,index);HOST.account[#HOST.account+1]={name,icon,body:sub(1,4)};return #HOST.account
                end
                return nativeEdit(index,name,icon,body)
            end
            local model=D.Load(a);model.name="Zulu"
            local saved,err=D.Save(model,a)
            assert(not saved and err:find("rolled back",1,true))
            assert(HOST.account[1][1]=="Other" and HOST.account[1][3]=="/cast Different")
            assert(D.Resolve(a).index==2)
        ''')

    def test_invalid_icon_readback_does_not_become_a_saved_zero_icon(self):
        self.run_lua('''
            C_Macro.GetSelectedMacroIcon=function()return 0 end
            local model=HOST.Draft("Fixed icon");model.icon=136078
            local saved=assert(W.MacroData.Save(model));assert(saved.icon==136078)
        ''')

    def test_native_close_guards_draft_and_focus_badge_reclaims_without_activation(self):
        self.run_lua('''
            local E=W.MacroEditor;E:Open();E:Focus("add-action")
            local mode=W.ControllerMode;W.ControllerMode=function()return false end
            E:Focus();assert(E.controls["add-action"].focus:IsShown())
            E.focusButton:GetScript("OnClick")(E.focusButton)
            assert(E.focusRequested and E.controls["add-action"].focus:IsShown())
            assert(not E.modal and #E.model.blocks==0 and not W.Keyboard.frame:IsShown())
            E.events:GetScript("OnEvent")(E.events,"INPUT_DEVICE_INTERFACE_TRANSITION")
            assert(E.focusRequested and E.controls["add-action"].focus:IsShown())
            E.inputButton:GetScript("OnClick")(E.inputButton,W.Input.keys.focus,false)
            assert(E.focusRequested and not E.modal)
            HOST.MacroPress(W.Input.keys.focus)
            assert(E.focusRequested and not E.modal and #E.model.blocks==0)
            W.Input.active=true;E.focusRequested=nil
            assert(not E:RequestFocus());W.Input.active=false
            E.model=HOST.Draft("Unsaved");E.dirty=true;E.detail=1;E:Draw()
            assert(E.closeButton.template=="UIPanelCloseButtonNoScripts")
            E:Focus("close");HOST.MacroPress(W.Input.keys.primary)
            assert(E.frame:IsShown() and E.modal.title=="Unsaved macro")
            E.controls.choice1.run();assert(E.frame:IsShown() and E.dirty)
            E:Focus("close");HOST.MacroPress(W.Input.keys.primary);E.controls.choice3.run()
            assert(not E.frame:IsShown() and not E.focusRequested and #HOST.macroCalls==0)
            W.ControllerMode=mode
        ''')

    def test_continuous_lists_edge_navigation_scrollbar_and_offscreen_selection(self):
        self.run_lua('''
            for i=1,20 do HOST.account[i]={"Macro "..i,134400,"/cast Renew"} end
            local E=W.MacroEditor;E:Open()
            assert(E.lists.library.bar:IsShown() and not E.controls.librarynext)
            E:Focus("macro:1")
            for i=1,12 do HOST.MacroPress("PADDDOWN") end
            assert(E.selected=="macro:13" and E.lists.library.offset>0 and #HOST.macroCalls==0)
            local entries={}
            for i=1,40 do local n=i;entries[i]={label="Spell "..i,run=function()HOST.chosen=n end} end
            E:Choose("Spells",entries,nil,nil,true)
            local list=E.lists.choices
            assert(#list.rows==40 and list.bar:IsShown() and not E.controls.choicesnext)
            E:Focus("choice7");HOST.MacroPress("PADDDOWN")
            assert(E.selected=="choice8" and list.offset==48)
            E:Focus("choice5")
            local f=E.frame;E.inputButton:GetScript("OnClick")(E.inputButton,W.Input.keys.primary,true)
            list.bar:SetScrollPercentage(1)
            E.inputButton:GetScript("OnClick")(E.inputButton,W.Input.keys.primary,false)
            assert(not HOST.chosen and list.offset==list.maximum and E.selected=="choice5")
            E.controls.choice5.run();assert(not HOST.chosen)
            HOST.MacroPress(W.Input.keys.primary)
            assert(not HOST.chosen and E:ControlVisible(E.controls.choice5))
            HOST.MacroPress(W.Input.keys.primary)
            assert(HOST.chosen==5 and not E.modal and E.selected=="macro:13")
            E.model=W.MacroData.New();E.model.blocks={}
            for i=1,12 do E.model.blocks[i]=W.MacroTemplates.Action("sequence") end
            E:Tab("build");assert(E.lists.actions.bar:IsShown() and not E.controls.actionsnext)
            E:Focus("action12");assert(E.lists.actions.offset>0)
            E.detail=12;local steps=E.model.blocks[12].steps
            for i=2,12 do steps[i]={spellID=139} end
            E:Draw();assert(E.lists.steps.bar:IsShown() and not E.controls.stepsnext)
            E:Focus("step12");assert(E.lists.steps.offset>0)
            E.category="targeting";E:Tab("templates")
            assert(E.lists.templates.bar:IsShown() and not E.controls.templatesnext)
            local before=E.lists.templates.offset
            E.lists.templates.rows[1]:GetScript("OnMouseWheel")(E.lists.templates.rows[1],-1)
            assert(E.lists.templates.offset>before)
        ''')

    def test_starters_shortcuts_reorder_and_linked_coloured_preview(self):
        self.run_lua('''
            local E=W.MacroEditor;E:Open();E:RequestFocus()
            assert(E.selected=="starter-cast" and E.controls["starter-raw"])
            assert(not E.controls["preview-up"]:IsEnabled())
            HOST.MacroPress(W.Input.keys.delete);assert(E.modal and E.modal.title=="Add action")
            HOST.MacroPress(W.Input.keys.library);assert(E.modal.title=="Add action")
            E:Back();assert(not E.modal and #E.model.blocks==0)
            E.controls["starter-raw"].run()
            assert(#E.model.blocks==1 and E.detail==1 and E.model.blocks[1].kind=="raw" and E.dirty)
            E.model.blocks={{kind="raw",text="/cast [@focus] Re|new"},{kind="item",slot=13}};E.detail=nil;E:Draw()
            assert(not E.controls["starter-cast"])
            E:Focus("action1")
            local text=E.codeText:GetText()
            assert(text:find("|cff8ec5f2/cast|r",1,true) and text:find("|cffa5dc94[@focus]|r",1,true))
            assert(text:find("|cffffd100 Re||new|r",1,true) and text:find("/use|r 13",1,true))
            local click=E.inputButton:GetScript("OnClick")
            click(E.inputButton,W.Input.keys.phrases,true);HOST.MacroPress("PADDDOWN")
            assert(E.model.blocks[1].kind=="item" and E.selected=="action2" and E.reorder)
            click(E.inputButton,W.Input.keys.phrases,false);assert(not E.reorder)
            HOST.MacroPress("PADDUP");assert(E.selected=="action1" and E.model.blocks[1].kind=="item")
            assert(E.codeText:GetText():find("|cffffd100 13|r",1,true))
            assert(E.checks:GetText():find("Name needs",1,true) and not E.save:IsEnabled())
            HOST.MacroPress(W.Input.keys.shift);assert(#HOST.account==0 and E.dirty)
            E.model.name="Shortcut";E:Preview();assert(E.checks:GetText():find("Name is valid",1,true))
            HOST.MacroPress(W.Input.keys.shift);assert(#HOST.account==1 and not E.dirty)
            HOST.MacroPress(W.Input.keys.library);assert(E.modal and E.modal.title=="Macro actions")
        ''')

    def test_spell_search_keeps_keyboard_then_resets_scroll_and_empty_results(self):
        self.run_lua('''
            local E=W.MacroEditor;E:Open();E.catalog={}
            for i=1,40 do E.catalog[i]={label=string.format("Spell %02d",i),value=tostring(i)} end
            local entry={};E:Spell(entry);local modal=E.modal
            E:Focus("choice30");assert(E.lists.choices.offset>0)
            E.controls["choice-search"].run();local box=E.controls["choice-search"]
            assert(W.Keyboard.session.target==box)
            box:SetText("Spell 40")
            assert(W.Keyboard.session.target==box and #E.lists.choices.rows==40)
            W.Keyboard:Close();E.frame:GetScript("OnUpdate")(E.frame,.2)
            assert(E.modal==modal and #E.lists.choices.rows==1 and E.lists.choices.offset==0 and not E.lists.choices.bar:IsShown())
            E.controls.choice1.run();assert(entry.spellID==40 and not E.modal)
            E:Spell(entry);E.controls["choice-search"]:SetText("No matching spell")
            E.frame:GetScript("OnUpdate")(E.frame,.2)
            assert(#E.lists.choices.rows==0 and E.lists.choices.offset==0 and not E.lists.choices.bar:IsShown())
            local stale=E.lists.choices
            E:Back();local current=E.selected;stale.bar:SetScrollPercentage(1)
            assert(E.selected==current and not E.modal)
        ''')

if __name__=='__main__': unittest.main()
