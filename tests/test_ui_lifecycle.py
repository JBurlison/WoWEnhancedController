"""Mouse/native hide, ancestor hide, Escape and combat cleanup contracts.

Models widget visibility and registered scripts, not Blizzard focus or taint.
"""
from pathlib import Path
import unittest
import test_radial as fixture
from test_macros import NATIVE
from test_radial_editor import SPELLBOOK


class UILifecycleTests(unittest.TestCase):
    def setUp(self):
        self.env = fixture.RadialTests()
        self.env.load_addon(settings_model=True)
        self.env.run_lua(SPELLBOOK + NATIVE)
        self.env.lua.execute((Path(__file__).parent / 'icon_picker_host.lua').read_text(encoding='utf8'))
        self.env.run_lua('''
            function HOST.Drain()
                local pending=HOST.queue;HOST.queue={}
                for _,fn in ipairs(pending)do fn()end
            end
            function HOST.Callback(event)
                for _,entry in ipairs(HOST.callbacks[event] or {})do entry[1](entry[2])end
            end
            function HOST.Regen()
                HOST.combat=false
                W.events:GetScript("OnEvent")(W.events,"PLAYER_REGEN_ENABLED")
            end
        ''')

    def run_lua(self, code):
        self.env.run_lua(code)

    def test_native_escape_closes_keyboard_and_drops_stale_release(self):
        self.run_lua('''
            local k,i=W.Keyboard,W.Input
            local box=HOST.Field("ChatFrame1EditBox","keep this draft")
            box:SetAttribute("chatType","SAY");k:Open(box);i.waitNeutral=false
            k.frame:GetScript("OnGamePadButtonDown")(k.frame,"PADRTRIGGER")
            box:SetScript("OnEscapePressed",function()box:ClearFocus();box:Hide()end)
            box:GetScript("OnEscapePressed")(box);HOST.Drain()
            assert(not k.session and not k.suspended and not k.frame:IsShown())
            assert(not i.active and not k.frame.pad and not k.frame.stick and not next(i.held))
            assert(W.drafts["chat:SAY"]=="keep this draft" and #HOST.sent==0)
            box:Show();k:Open(box)
            k.frame:GetScript("OnGamePadButtonUp")(k.frame,"PADRTRIGGER")
            assert(#HOST.sent==0 and box:GetText()=="keep this draft")
        ''')

    def test_raw_keyboard_hide_closes_but_explicit_suspend_retains_draft(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("Search","draft")
            k:Open(box);k.suspended=true;k:Hide()
            assert(k.session and k.suspended and not W.Input.active and not k.frame.pad)
            k.suspended=nil;k.frame:Show();W.Input:Acquire(true)
            k.frame:Hide()
            assert(not k.session and not k.suspended and not k.editor)
            W.WatchFocus();assert(not k.frame:IsShown())
            box:ClearFocus();box:SetFocus();W.WatchFocus();assert(k.frame:IsShown())
            k:Close();assert(box:GetText()=="draft")
        ''')

    def test_mouse_focus_loss_does_not_restore_or_close_another_field(self):
        self.run_lua('''
            local k=W.Keyboard;local first=HOST.Field("First","one")
            local second=HOST.Field("Second","two")
            k:Open(first);second:SetFocus();assert(not W.Input.active)
            W.WatchFocus();HOST.Drain()
            assert(k.session.target==second and second:HasFocus() and first:GetText()=="one")
            second:ClearFocus();HOST.Drain()
            assert(not k.session and not k.frame:IsShown() and not k.frame.pad)
        ''')

    def test_native_mouse_handoff_does_no_binding_work_on_the_native_stack(self):
        self.run_lua('''
            local k,i=W.Keyboard,W.Input
            local box=HOST.Field("ChatFrame1EditBox","unsent");box:SetAttribute("chatType","PARTY")
            box.chatFrame=ChatFrame1;box:SetFocus();k:Open(box)
            local writes=0;local clear=ClearOverrideBindings
            ClearOverrideBindings=function(owner)writes=writes+1;clear(owner)end
            W.ControllerMode=function()return false end
            W.events:GetScript("OnEvent")(W.events,"INPUT_DEVICE_INTERFACE_TRANSITION")
            box:ClearFocus();box:Hide()
            assert(writes==0 and not i.active)
            HOST.Drain()
            assert(writes==1 and not W.KeyboardBindings.active and not k.session and not box:HasFocus() and #HOST.sent==0)
        ''')

    def test_unfocused_native_chat_field_is_never_refocused_by_the_addon(self):
        self.run_lua('''
            local k=W.Keyboard
            local box=HOST.Field("ChatFrame1EditBox","draft");box:SetAttribute("chatType","PARTY")
            box.chatFrame=ChatFrame1;box:SetFocus();k:Open(box)
            W.ControllerMode=function()return true end
            local calls=0;local focus=box.SetFocus
            box.SetFocus=function(...)calls=calls+1;return focus(...)end
            assert(k:FocusField()==true and calls==0)
            box:ClearFocus()
            assert(k:FocusField()==false and calls==0 and not box:HasFocus())
            local other=HOST.Field("OtherNativeBox","x");other:SetFocus();k:Close();k:Open(other);other:ClearFocus()
            local refocused=0;local plain=other.SetFocus
            other.SetFocus=function(...)refocused=refocused+1;return plain(...)end
            if k.session then assert(k:FocusField()==true and refocused==1) end
        ''')

    def test_native_radial_suspends_capture_then_restores_only_visible_windows(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","kept")
            k:Open(box)
            GamepadRadial=CreateFrame("Frame",nil,UIParent);GamepadRadial:Hide()
            GamepadRadial:Show();HOST.Callback("Gamepad.ShowMainMenu")
            assert(k.suspended and not k.frame:IsShown() and not W.Input.active)
            assert(not W.FocusBinding() and not W.Launcher:Open())
            box:ClearFocus();box:Hide();HOST.Drain();assert(not k.session)
            GamepadRadial:Hide();HOST.Callback("Gamepad.HideMainMenu");HOST.Drain()
            W.WatchFocus();assert(not k.frame:IsShown() and not k.frame.pad)
        ''')

    def test_settings_ancestor_hide_releases_all_custom_pages(self):
        self.run_lua('''
            for _,page in ipairs({"bindings","appearance","spells"})do
                if page=="bindings" then W.Options.OpenBindings()
                elseif page=="appearance"then W.Options.OpenAppearance()
                else W.Radial:Edit()end
                local f=page=="bindings" and W.Options.bindingEditor
                    or page=="appearance"and W.Options.appearanceFrame or W.Radial.editor
                assert(f:IsVisible() and f.pad)
                f:GetScript("OnGamePadButtonDown")(f,"PAD1")
                SettingsPanel:Hide()
                assert(not f.pad and not f.stick and not f:IsVisible())
                assert(not W.Options.bindingHeld and not (W.Options.appearanceFrame and W.Options.appearanceFrame.held)
                    and not W.Radial.editorHeld)
                f:GetScript("OnGamePadButtonUp")(f,"PAD1")
                assert(not W.Options.bindingCapture and not W.IconPicker.request)
            end
        ''')

    def test_escape_passes_to_native_menu_instead_of_closing_a_background_editor(self):
        self.run_lua('''
            W.MacroEditor:Open();local e=W.MacroEditor
            GamepadRadial=CreateFrame("Frame",nil,UIParent)
            e.frame:GetScript("OnKeyDown")(e.frame,"ESCAPE")
            assert(e.frame:IsShown() and e.frame.propagate)
            GamepadRadial:Hide();e.frame:Hide()
            W.Keyboard:ShowQuickMessages();GamepadRadial:Show()
            W.Keyboard.frame:GetScript("OnKeyDown")(W.Keyboard.frame,"ESCAPE")
            assert(W.Keyboard.frame:IsShown() and W.Keyboard.frame.propagate)
        ''')

    def test_launcher_and_macro_escape_release_capture_and_preserve_dirty_guard(self):
        self.run_lua('''
            local m=W.Launcher;m:Open();m:Down("PAD1")
            m.frame:GetScript("OnKeyDown")(m.frame,"ESCAPE")
            assert(not m:IsShown() and not m.frame.pad and not m.held and not m.highlight:IsShown())
            m:Open();m:Up("PAD1");assert(m:IsShown());m:Close()
            local e=W.MacroEditor;e:Open();e.dirty=true;e.model.name="Unsaved"
            e.frame:GetScript("OnKeyDown")(e.frame,"ESCAPE")
            assert(e.frame:IsShown() and e.modal and e.dirty)
            e.frame:Hide()
            assert(not e.frame.pad and not e.held and not e.focusRequested and e.model.name=="Unsaved")
            e:Open();e.dirty=false;e.modal=nil
            e.frame:GetScript("OnKeyDown")(e.frame,"ESCAPE")
            assert(not e.frame:IsShown() and not e.frame.pad)
        ''')

    def test_icon_owner_hide_cancels_once_and_releases_provider(self):
        self.run_lua('''
            local p=W.IconPicker;local cancelled,restored=0,0
            p:Open({onCancel=function()cancelled=cancelled+1 end,restoreFocus=function()restored=restored+1 end})
            assert(p.frame.pad)
            p.frame:GetScript("OnGamePadButtonDown")(p.frame,W.Input.keys.shift)
            p.owner:Hide()
            assert(not p.request and not p.held and not p.frame.pad and not p.frame.iconDataProvider)
            assert(cancelled==1 and restored==1 and HOST.iconReleases==1)
            p:Open({});p.frame:GetScript("OnGamePadButtonUp")(p.frame,W.Input.keys.shift)
            assert(p.request);p:Close()
        ''')

    def test_combat_hide_finishes_capture_cleanup_after_lockdown(self):
        self.run_lua('''
            local m=W.Launcher;m:Open();m:Down("PAD1")
            HOST.combat=true;m.frame:Hide()
            assert(not m:IsShown() and not m.held and not m.controls)
            local owner=m.inputOwner
            local transition=assert(loadstring("return function(self,newstate) "..owner:GetAttribute("_onstate-launcher-combat").." end"))()
            transition(owner,"blocked");assert(not next(owner.binds))
            HOST.Regen();transition(owner,"ready");assert(not m.controls and not next(owner.binds))
            local k=W.Keyboard;local box=HOST.Field("CombatSearch","kept");k:Open(box)
            HOST.combat=true;k.frame:Hide();assert(not k.session and not W.Input.active)
            box:ClearFocus();HOST.Regen();assert(not k.frame.pad and not k.frame.stick)
        ''')

    def test_direct_secure_wheel_hide_and_position_exit_clear_bindings(self):
        self.run_lua('''
            local r=W.Radial;r:Open();assert(r.frame.binds.ESCAPE)
            r.frame:SetAttribute("pressed","Confirm")
            HOST.combat=true;r.frame:Hide()
            assert(not next(r.frame.binds) and not r.frame:GetAttribute("open") and not r.frame:GetAttribute("pressed"))
            HOST.Regen();W.Placement.Enter();W.Placement.Preview("keyboard");W.Placement.Preview("radial")
            r:SyncOwnership();assert(W.Placement.wheelPreview:IsShown() and not r.frame:IsShown() and not next(r.frame.binds))
            W.Keyboard.frame:Hide()
            assert(not W.Placement.editing and not W.Placement.draft and not r.frame:IsShown())
            assert(not next(r.frame.binds) and #HOST.actions==0)
        ''')

    def test_controller_moves_wheel_and_saves_in_native_edit_mode(self):
        self.run_lua('''
            local p,k,input=W.Placement,W.Keyboard,W.Input
            HOST.Event("EditMode.Enter")
            assert(input.active and k.positionId=="radial" and k.focused:GetText()==W.L["Save position"])
            input.waitNeutral=false
            local stick=k.frame:GetScript("OnGamepadStick")
            stick(k.frame,"Movement",1,0);HOST.now=HOST.now+.1;input:Update()
            assert(math.abs(p.draft.radial.x-36)<.001)
            HOST.keys.PAD1=true;input:Down("PAD1")
            HOST.now=HOST.now+.5;input:Update()
            local x=p.draft.radial.x;assert(math.abs(x-72)<.001)
            HOST.keys.PAD1=false;input:Up("PAD1")
            assert(not p.editing and p.Settings("radial").x==x and W.Radial.frame.x==x)
            HOST.Event("EditMode.Enter");input.waitNeutral=false
            stick(k.frame,"Movement",-.5,.5);HOST.now=HOST.now+.1;input:Update()
            HOST.Event("EditMode.SavedLayouts")
            local saved=p.Settings("radial")
            assert(math.abs(saved.y-18)<.001 and math.abs(saved.x-x+18)<.001)
            stick(k.frame,"Movement",0,0);HOST.now=HOST.now+.2;input:Update()
            assert(p.draft.radial.x==saved.x and p.draft.radial.y==saved.y)
            p.Nudge("radial",4,0);HOST.Press("PAD2")
            assert(not p.editing and not input.active and p.Settings("radial").x==saved.x)
            assert(p.Settings("radial").y==saved.y)
        ''')

    def test_drag_and_nudge_preview_from_settings_and_native_edit_mode(self):
        self.run_lua('''
            local p,k,r=W.Placement,W.Keyboard,W.Radial
            local button
            for _,entry in ipairs(HOST.initializers) do
                if entry.name=="Wheel position" then button=entry end
            end
            SettingsPanel:Show();assert(button).run()
            local preview=assert(p.wheelPreview)
            assert(k.positionId=="radial" and preview:IsShown() and W.Input.active)
            r:SyncOwnership();assert(preview:IsShown() and not r.frame:IsShown() and not r.baseBound)
            preview:GetScript("OnDragStart")(preview);preview.x,preview.y=77,93
            preview:GetScript("OnDragStop")(preview)
            k:Select(2,1);k:Action("primary");k:Move(1,0);k:Action("primary")
            assert(not k.nudging and p.draft.radial.x==81 and p.draft.radial.y==93)
            k:Action("confirm")
            assert(p.Settings("radial").anchor=="screen" and r.frame.x==81 and r.frame.y==93)
            assert(not preview:IsShown() and not p.editing and not W.Input.active)
            HOST.Event("EditMode.Enter");assert(k.positionId=="radial" and preview.x==81)
            p.Reset("radial");HOST.Event("EditMode.Exit");assert(r.frame.x==81)
            HOST.Event("EditMode.Enter");k:Select(1,1);k:Action("primary")
            assert(k.positionId=="keyboard" and not preview:IsShown())
            k:Select(1,2);k:Action("primary");assert(preview:IsShown())
            HOST.combat=true;W.events:GetScript("OnEvent")(W.events,"PLAYER_REGEN_DISABLED")
            assert(not p.editing and not preview:IsShown() and not next(r.frame.binds) and #HOST.actions==0)
        ''')

    def test_macro_creator_owns_native_focus_chord_and_restores_after_child(self):
        self.run_lua('''
            local e=W.MacroEditor
            local original=GetBindingKey
            GetBindingKey=function(action,...)
                if action=="TOGGLEUIFOCUS" then return "CTRL-PAD3","PADBACK" end
                return original(action,...)
            end
            HOST.keys.PAD1=true;e:Open();e:Focus("name")
            assert(e.inputOwner.binds["CTRL-PAD3"] and e.inputOwner.binds.PADDUP)
            HOST.MacroPress("PAD1");assert(not W.Keyboard.session)
            HOST.keys.PAD1=false;HOST.MacroPress("CTRL-PAD3");assert(e.selected=="name" and e.focusRequested)
            HOST.MacroPress("PAD1");assert(W.Keyboard.session and not next(e.inputOwner.binds))
            W.Keyboard:Close();e.frame:GetScript("OnUpdate")(e.frame,.2)
            assert(e.selected=="name" and e.focusRequested and e.inputOwner.binds.PAD1)
            local before=e.selected;HOST.MacroPress("PADDRIGHT");assert(e.selected~=before)
            assert(W.FocusBinding() and not W.Keyboard.frame:IsShown())
            e.frame:Hide();assert(not next(e.inputOwner.binds) and not e.focusRequested)
        ''')


if __name__ == '__main__':
    unittest.main()
