"""Binding dispatch contracts, separate from physical client input acceptance."""
import unittest
import test_radial as fixture
from test_macros import NATIVE
from test_radial_editor import SPELLBOOK


class KeyboardBindingTests(unittest.TestCase):
    def setUp(self):
        self.env = fixture.RadialTests()
        self.env.load_addon(settings_model=True)
        self.env.run_lua(SPELLBOOK + NATIVE)
        self.env.run_lua('''
            HOST.gameplay=0
            function HOST.BindingEdge(key,down)
                local b=W.KeyboardBindings
                local binding=b.owner and b.owner.binds and b.owner.binds[key]
                if binding then
                    local button=_G[binding[1]]
                    button:GetScript("OnClick")(button,binding[2],down)
                elseif not down then HOST.gameplay=HOST.gameplay+1 end
            end
            function HOST.BindingPress(key)
                W.Input.waitNeutral=false
                HOST.BindingEdge(key,true);HOST.BindingEdge(key,false)
            end
            function HOST.Drain()
                local queue=HOST.queue;HOST.queue={};for _,fn in ipairs(queue)do fn()end
            end
        ''')

    def run_lua(self, code):
        self.env.run_lua(code)

    def test_macro_name_keyboard_owns_base_and_modifier_bindings_once(self):
        self.run_lua('''
            W.MacroEditor:Open();local box=W.MacroEditor.controls.name
            box:SetFocus();W.WatchFocus()
            local k,b=W.Keyboard,W.KeyboardBindings
            assert(k.session.target==box and W.Input.active and b.active)
            assert(not k.frame:IsGamePadButtonEnabled() and k.frame:IsGamePadStickEnabled())
            k:Select(2,1)
            for _,prefix in ipairs({"","SHIFT-","CTRL-","ALT-","CTRL-SHIFT-","ALT-SHIFT-","ALT-CTRL-","ALT-CTRL-SHIFT-"})do
                HOST.BindingPress(prefix..W.Input.keys.primary)
            end
            assert(box:GetText()=="qqqqqqqq" and W.MacroEditor.model.name==box:GetText() and HOST.gameplay==0)
            assert(not W.MacroEditor.held and #HOST.macroCalls==0)
            k:Close();assert(not b.active and not next(b.owner.binds))
            HOST.BindingPress("PAD1");assert(HOST.gameplay==1)
        ''')

    def test_native_trigger_modifiers_cannot_fall_through_to_gameplay(self):
        self.run_lua('''
            local box=HOST.Field("Search","");W.Keyboard:Open(box)
            local b=W.KeyboardBindings;W.Input.waitNeutral=false
            local context=W.Keyboard:Context()
            W.Phrases.Save(context.key,1,"ready", "primary", "phrases")
            HOST.BindingEdge("PADLTRIGGER",true)
            HOST.BindingEdge("SHIFT-PAD1",true);HOST.BindingEdge("SHIFT-PAD1",false)
            HOST.BindingEdge("PADLTRIGGER",false)
            assert(HOST.gameplay==0 and not W.Input.layer and not next(W.Input.held))
            assert(b.owner.binds["ALT-CTRL-SHIFT-PAD1"] and b.owner.binds.PADLTRIGGER)
        ''')

    def test_focus_loss_hide_and_reopen_drop_stale_release_and_preserve_other_overrides(self):
        self.run_lua('''
            local other=CreateFrame("Frame",nil,UIParent)
            SetOverrideBindingClick(other,true,"F9","OtherAddonInput","LeftButton")
            local box=HOST.Field("Search","kept");W.Keyboard:Open(box)
            W.Input.waitNeutral=false;HOST.BindingEdge("PAD1",true)
            box:ClearFocus();assert(not W.Input.active and W.KeyboardBindings.active)
            HOST.Drain();assert(not W.KeyboardBindings.active and W.KeyboardBindings.draining.PAD1)
            HOST.BindingEdge("PAD1",false)
            assert(HOST.gameplay==0 and not next(W.KeyboardBindings.owner.binds))
            HOST.Drain();assert(not W.Keyboard.session)
            W.Keyboard:Open(box);HOST.BindingEdge("PAD1",false)
            assert(box:GetText()=="kept" and other.binds.F9)
            W.Keyboard.frame:Hide();assert(not next(W.KeyboardBindings.owner.binds) and other.binds.F9)
        ''')

    def test_rebind_and_mapped_extra_buttons_refresh_without_saved_binding_changes(self):
        self.run_lua('''
            C_GamePad.ButtonIndexToBinding=function(index)return index==0 and "PADPADDLE1" or nil end
            HOST.pad.buttonCount=1
            local box=HOST.Field("Search","");W.Keyboard:Open(box)
            assert(W.KeyboardBindings.owner.binds.PADPADDLE1)
            W.db.actionBindings={primary="PAD5"};W.Input:Refresh();W.Keyboard:Select(2,1)
            HOST.BindingPress("PAD5");assert(box:GetText()=="q" and HOST.gameplay==0)
            assert(W.db.actionBindings.primary=="PAD5")
        ''')

    def test_partial_binding_failure_releases_only_keyboard_owner_and_capture(self):
        self.run_lua('''
            local original=SetOverrideBindingClick;local count=0
            SetOverrideBindingClick=function(...)
                count=count+1;if count==3 then error("binding failed")end
                return original(...)
            end
            W.Keyboard:Open(HOST.Field("Search","kept"))
            assert(not W.Input.active and W.Input.failure and not W.KeyboardBindings.active)
            assert(not next(W.KeyboardBindings.owner.binds))
            assert(not W.Keyboard.frame.pad and not W.Keyboard.frame.stick)
        ''')

    def test_restricted_combat_cleanup_cannot_rearm_on_exit(self):
        self.run_lua('''
            local box=HOST.Field("Search","kept");W.Keyboard:Open(box)
            local b=W.KeyboardBindings;local owner=b.owner
            HOST.combat=true
            local body=owner:GetAttribute("_onstate-keyboard-combat")
            local callback=assert(loadstring("return function(self,newstate) "..body.." end"))()
            callback(owner,"blocked")
            assert(not b.active and not W.Input.active and not next(owner.binds))
            b.button:GetScript("OnClick")(b.button,"PAD1",true)
            b.button:GetScript("OnClick")(b.button,"PAD1",false)
            assert(box:GetText()=="kept")
            HOST.combat=false;callback(owner,"ready")
            assert(not b.active and not next(owner.binds))
            W.Keyboard:Close();W.Input:FlushCapture()
        ''')


if __name__ == '__main__':
    unittest.main()
