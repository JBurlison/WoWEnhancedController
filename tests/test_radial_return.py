"""Post-action menu routing; a secure-handler model, not client security proof."""
import unittest
import test_radial as fixture

class RadialReturnTests(unittest.TestCase):
    def setUp(self):
        self.env=fixture.RadialTests();self.env.load_addon(settings_model=True)
    def run_lua(self,code): self.env.run_lua(code)

    def test_default_returns_to_party_members_after_exactly_one_action(self):
        self.run_lua('''
            local R=W.Radial;assert(W.db.radial.afterAction=="members")
            HOST.WheelPress("Toggle");HOST.WheelPress("LeftButton",2)
            HOST.WheelPress("LeftButton",2)
            assert(#HOST.actions==1 and HOST.actions[1].unit=="party1")
            assert(R.frame:IsShown() and R.frame:GetAttribute("stage")=="root" and not R.frame:GetAttribute("member"))
            assert(R.frame:GetAttribute("selected")==0 and not R.gestureArmed and not R.hover)
            R.dispatch:GetScript("OnClick")(R.dispatch,"ConfirmTrigger",false)
            assert(#HOST.actions==1 and UnitName("target")=="Stoneguard")
            assert(R.frame.binds.PADDDOWN[2]=="BackDpad" and R.frame.binds["SHIFT-PADDDOWN"][2]=="BackDpad")
            HOST.WheelPress("BackDpad");assert(not R.frame:IsShown() and next(R.frame.binds)==nil)
        ''')

    def test_raid_default_current_group_and_directional_shortcuts(self):
        self.run_lua('''
            local R=W.Radial;HOST.Raid();HOST.combat=true
            HOST.WheelPress("Toggle");HOST.WheelPress("LeftButton",3);HOST.WheelPress("LeftButton",3)
            HOST.WheelPress("LeftButton",1)
            assert(#HOST.actions==1 and HOST.actions[1].unit=="raid13")
            assert(R.frame:GetAttribute("stage")=="members" and R.frame:GetAttribute("group")==3)
            assert(R.center:GetText()=="Choose member")
            assert(R.frame.binds.PADDLEFT[2]=="RaidGroups" and R.frame.binds.PADDRIGHT[2]=="RaidMembers")
            assert(R.frame.binds["ALT-CTRL-SHIFT-PADDLEFT"][2]=="RaidGroups")
            HOST.WheelPress("RaidGroups");assert(R.frame:GetAttribute("stage")=="root" and R.frame:GetAttribute("group")==3)
            HOST.WheelPress("RaidMembers");assert(R.frame:GetAttribute("stage")=="members" and R.frame:GetAttribute("group")==3)
            HOST.WheelPress("LeftButton",2);HOST.WheelPress("BackDpad")
            assert(R.frame:GetAttribute("stage")=="members")
            HOST.WheelPress("BackDpad");assert(R.frame:GetAttribute("stage")=="root")
            HOST.WheelPress("BackDpad");assert(not R.frame:IsShown() and #HOST.actions==1)
        ''')

    def test_same_member_keeps_page_and_requires_fresh_confirmation(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;HOST.settings.WEC_RADIAL_afterAction:SetValue("target")
            D.AddPage();D.Save(4,{kind="spell",label="Heal",value="139",page=-1,slot=2})
            HOST.WheelPress("Toggle");HOST.WheelPress("LeftButton",2);HOST.WheelPress("PagePrevious")
            HOST.pad.sticks={{x=0,y=0,len=0},{x=.7,y=.7,len=1}}
            HOST.WheelPress("ConfirmTrigger")
            assert(#HOST.actions==1 and R.frame:GetAttribute("stage")=="spells" and R.frame:GetAttribute("member")==2 and R.frame:GetAttribute("page")==-1)
            local b=R.dispatch;local click=b:GetScript("OnClick")
            click(b,"ConfirmTrigger",false);click(b,"ConfirmDpad",false);assert(#HOST.actions==1)
            HOST.WheelPress("ConfirmTrigger");assert(#HOST.actions==2 and HOST.actions[2].unit=="party1")
            HOST.WheelPress("BackDpad");assert(R.frame:GetAttribute("stage")=="root")
            HOST.WheelPress("LeftButton",2);assert(R.frame:GetAttribute("page")==0)
        ''')

    def test_native_setting_preserves_choices_and_defers_runtime_change_in_combat(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;local setting=HOST.settings.WEC_RADIAL_afterAction
            assert(setting.kind==Settings.VarType.String and setting:GetValue()=="members")
            for _,choice in ipairs({"close","target","members"})do setting:SetValue(choice);D.Init();assert(W.db.radial.afterAction==choice and R.frame:GetAttribute("after-action")==choice)end
            HOST.combat=true;setting:SetValue("close");assert(R.pending and R.frame:GetAttribute("after-action")=="members")
            HOST.combat=false;W.events:GetScript("OnEvent")(W.events,"PLAYER_REGEN_ENABLED")
            assert(R.frame:GetAttribute("after-action")=="close")
            HOST.WheelPress("Toggle");HOST.WheelPress("LeftButton",2);HOST.WheelPress("LeftButton",1)
            assert(#HOST.actions==1 and not R.frame:IsShown() and next(R.frame.binds)==nil)
            W.db.radial.afterAction="obsolete";D.Init();assert(W.db.radial.afterAction=="members")
        ''')

    def test_cancel_or_roster_invalidation_during_action_does_not_reopen(self):
        self.run_lua('''
            local R=W.Radial;HOST.WheelPress("Toggle");HOST.WheelPress("LeftButton",2)
            R.frame:SetAttribute("finish-member",2);R.frame:SetAttribute("finish-group",1)
            R.frame:RunAttribute("op-invalidate");R.frame:RunAttribute("op-finish")
            assert(not R.frame:IsShown() and #HOST.actions==0)
            R:Rebuild();HOST.WheelPress("Toggle");HOST.WheelPress("LeftButton",2)
            R.frame:SetAttribute("finish-member",2);R.frame:SetAttribute("finish-group",1)
            HOST.WheelPress("Cancel");R.frame:RunAttribute("op-finish");assert(not R.frame:IsShown())
        ''')

    def test_removed_previous_recipient_is_inert_and_empty_group_is_safe(self):
        self.run_lua('''
            local R=W.Radial;HOST.Raid();W.db.radial.afterAction="target";R:Rebuild()
            HOST.WheelPress("Toggle");HOST.WheelPress("LeftButton",4);HOST.WheelPress("LeftButton",2);HOST.WheelPress("LeftButton",1)
            HOST.WheelPress("RaidGroups");assert(R.frame.binds.PADLSTICK==nil)
            HOST.WheelPress("PreviousRecipient")
            assert(#HOST.actions==1 and UnitName("target")=="Stoneguard")
            assert(R.frame:GetAttribute("stage")=="root" and R.frame:GetAttribute("group")==4)
            R.frame:SetAttribute("group-count-4",0)
            HOST.WheelPress("RaidMembers");assert(R.frame:GetAttribute("stage")=="root" and #HOST.actions==1)
        ''')

    def test_whisper_always_hands_off_and_never_reopens_over_text_entry(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;local calls=0
            R.frame.Whisper=function(_,unit)calls=calls+1;assert(unit=="party1")end
            for _,choice in ipairs({"members","target","close"})do
                HOST.settings.WEC_RADIAL_afterAction:SetValue(choice)
                D.Save(1,{kind="friendly",label="Whisper",value="whisper",page=0,slot=1})
                HOST.WheelPress("Toggle");HOST.WheelPress("LeftButton",2);HOST.WheelPress("LeftButton",1)
                assert(not R.frame:IsShown() and #HOST.actions==0)
            end
            assert(calls==3 and #HOST.sent==0)
        ''')

    def test_stale_confirmation_cannot_cross_direct_raid_navigation(self):
        self.run_lua('''
            local R=W.Radial;HOST.Raid();HOST.WheelPress("Toggle");HOST.WheelPress("LeftButton",2);HOST.WheelPress("LeftButton",1)
            local b=R.dispatch;local click=b:GetScript("OnClick")
            click(b,"ConfirmTrigger",true);R.frame:RunAttribute("op-stage","members",2)
            click(b,"ConfirmTrigger",false);assert(#HOST.actions==0)
            assert(R.frame:GetAttribute("stage")=="members" and not R.frame:GetAttribute("pressed"))
        ''')

if __name__=='__main__': unittest.main()
