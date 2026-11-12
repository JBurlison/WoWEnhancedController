"""Cold full-addon + secure-snippet contract checks; no client security claim."""
from pathlib import Path
import sys
import unittest
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tools/pydeps'))
from lupa.lua51 import LuaRuntime

class RadialTests(unittest.TestCase):
    def setUp(self):
        self.load_addon()

    def load_addon(self, initial_combat=False, locale='enUS', settings_model=False):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        for name in ('host.lua', 'radial_host.lua'):
            self.lua.execute((ROOT / 'tests' / name).read_text(encoding='utf-8'))
        self.lua.globals().TEST_LOCALE = locale
        self.lua.execute('function GetLocale() return TEST_LOCALE end')
        if settings_model:
            self.lua.execute((ROOT / 'tests/settings_host.lua').read_text(encoding='utf-8'))
        namespace = self.lua.table()
        self.lua.globals().W = namespace
        folder = ROOT / 'WoWEnhancedController'
        for line in (folder / 'WoWEnhancedController.toc').read_text(encoding="utf-8").splitlines():
            if line.endswith('.lua'):
                self.lua.execute('return function(...)\n' + (folder / line).read_text(encoding='utf-8') + '\nend')('WoWEnhancedController', namespace)
        self.lua.globals().HOST.combat = initial_combat
        self.lua.execute('W.events:GetScript("OnEvent")(W.events,"ADDON_LOADED","WoWEnhancedController"); W.events:GetScript("OnEvent")(W.events,"PLAYER_ENTERING_WORLD")')

    def run_lua(self, source):
        self.lua.execute(source)

    def test_default_r3_can_be_unbound_without_disabling_wheel_or_macro(self):
        self.load_addon(settings_model=True)
        self.run_lua('''
            local R=W.Radial
            assert(W.db.radial.defaultR3 and R.base.binds.PADRSTICK)
            HOST.settings.WEC_RADIAL_defaultR3:SetValue(false)
            assert(not R.base.binds.PADRSTICK and R.frame:GetAttribute("enabled"))
            W.RadialData.Init();R:Rebuild();assert(W.db.radial.defaultR3==false)
            R:Open();assert(R.frame:GetAttribute("open") and R.frame.binds.PADRSTICK==nil)
            assert(R.frame.binds.PADLTRIGGER and R.frame.binds.PADDUP)
            R:Close();assert(next(R.base.binds)==nil)
            HOST.settings.WEC_RADIAL_defaultR3:SetValue(true)
            assert(R.base.binds.PADRSTICK and #HOST.actions==0)
        ''')

    def test_macro_toggle_single_native_up_only_opens_menu_and_respects_guards(self):
        self.run_lua('''
            local R=W.Radial;W.db.radial.defaultR3=false;R:Rebuild()
            local b=R.macroToggle;local click=b:GetScript("OnClick")
            HOST.combat=true
            click(b,"LeftButton",true);assert(not R.frame:IsShown())
            click(b,"LeftButton",false);assert(R.frame:IsShown() and #HOST.actions==0)
            assert(R.frame.binds.PADRSTICK==nil)
            click(b,"LeftButton",false);assert(not R.frame:IsShown() and #HOST.actions==0)
            R.frame:RunAttribute("op-invalidate")
            click(b,"LeftButton",false);assert(not R.frame:IsShown())
            HOST.combat=false;R:Rebuild();W.db.radial.enabled=false;R:SyncOwnership()
            click(b,"LeftButton",false);assert(not R.frame:IsShown())
            local ok=pcall(b.Click,b,"LeftButton",false)
            assert(not ok and #HOST.actions==0)
        ''')

    def test_restricted_argument_scrubbing_and_no_wheel_configuration(self):
        self.run_lua('''
            W.db.radial.afterAction="close";W.Radial:Rebuild()
            local R=W.Radial
            R.frame:SetAttribute("probe", "local clicked,key,down=...;return clicked,key,down")
            local clicked,key,down=R.frame:RunAttribute("probe",R.dispatch,"Toggle",false)
            assert(clicked==nil and key=="Toggle" and down==false)
            HOST.WheelPress("Toggle");assert(R.frame:IsShown())
            HOST.WheelPress("Next");HOST.WheelPress("Next")
            HOST.WheelPress("Confirm");assert(R.frame:GetAttribute("member")==2)
            HOST.WheelPress("Next");HOST.WheelPress("Next")
            HOST.WheelPress("Confirm")
            assert(#HOST.actions==1 and HOST.actions[1].unit=="party1" and not R.frame:IsShown())
            HOST.WheelPress("Toggle");HOST.WheelPress("Toggle");assert(not R.frame:IsShown())
            assert(R.edit==nil and R.confirm==nil and R.back==nil and R.toggle==nil and R.page==nil)
            assert(R.frame:GetWidth()==W.db.radial.size and R.frame:GetHeight()==W.db.radial.size+180)
            HOST.WheelPress("Toggle");assert(R.frame.binds.PADFORWARD==nil)
        ''')

    def test_party_members_only_direct_spell_and_no_startup_window(self):
        self.run_lua('''
            local R=W.Radial;assert(not R.frame:IsShown() and not W.Keyboard.frame:IsShown())
            HOST.WheelPress("Toggle");assert(R.frame:IsShown() and R.frame:GetAttribute("count")==5)
            assert(R:Entry(1).unit=="player" and R:Entry(5).unit=="party4")
            assert(R.frame.binds.PADLSTICK==nil)
            assert(R.frame.binds["ALT-CTRL-SHIFT-PAD1"][2]=="Confirm")
            assert(R.frame.binds["SHIFT-PAD2"][2]=="Back")
            HOST.WheelPress("LeftButton",2)
            assert(R.frame:GetAttribute("stage")=="spells" and R.frame:GetAttribute("member")==2 and #HOST.actions==0)
            HOST.WheelPress("LeftButton",2)
            assert(#HOST.actions==1 and HOST.actions[1].kind=="spell" and HOST.actions[1].unit=="party1")
            assert(UnitName("target")=="Stoneguard" and R.frame:IsShown() and R.frame:GetAttribute("stage")=="root")
            HOST.WheelPress("LeftButton",1)
            assert(#HOST.actions==1 and UnitName("target")=="Stoneguard")
            assert(R.frame:GetAttribute("stage")=="spells" and R.frame:GetAttribute("member")==1)
        ''')

    def test_eight_slot_raid_pages_optional_target_without_previous_recipient(self):
        self.run_lua('''
            W.db.radial.afterAction="close";W.Radial:Rebuild() 
            local R,D=W.Radial,W.RadialData;HOST.Raid()
            local actions=D.Profile().actions
            for i=4,8 do actions[i]={kind="custom",label="Shield"..i,value="/cast [@{unit},help] Power Word: Shield"} end
            R:Rebuild();assert(D.AddPage()==-1)
            assert(D.Save(9,{kind="friendly",label="Target",value="target",page=-1,slot=1}))
            HOST.WheelPress("Toggle");assert(R.frame:GetAttribute("count")==8)
            HOST.WheelPress("LeftButton",3);HOST.WheelPress("LeftButton",3)
            assert(R.frame:GetAttribute("member")==13 and R.frame:GetAttribute("page")==0)
            assert(R:Entry(1).label~="Target" and R:Entry(8).label=="Shield8")
            HOST.WheelPress("LeftButton",8)
            assert(HOST.actions[1].body=="/cast [@raid13,help] Power Word: Shield" and UnitName("target")=="Stoneguard")
            HOST.WheelPress("Toggle");HOST.WheelPress("PreviousRecipient")
            assert(#HOST.actions==1 and R.frame.binds.PADLSTICK==nil and UnitName("target")=="Stoneguard")
            HOST.WheelPress("LeftButton",3);HOST.WheelPress("LeftButton",3)
            HOST.WheelPress("PagePrevious");assert(R.frame:GetAttribute("page")==-1 and R:Entry(1).label=="Target")
            HOST.WheelPress("PagePrevious");assert(R.frame:GetAttribute("page")==-1)
            HOST.WheelPress("LeftButton",1);assert(HOST.actions[2].kind=="target" and HOST.actions[2].unit=="raid13")
        ''')

    def test_paired_input_fresh_tier_cancel_and_secure_stick_selection(self):
        self.run_lua('''
            local R=W.Radial;local b=R.dispatch
            b:GetScript("OnClick")(b,"Toggle",false);assert(not R.frame:IsShown())
            HOST.WheelPress("Toggle");assert(#HOST.actions==0)
            HOST.pad.sticks={{x=0,y=0,len=0},{x=1,y=0,len=1}}
            HOST.WheelPress("Confirm");assert(R.frame:GetAttribute("stage")=="spells" and #HOST.actions==0)
            b:GetScript("OnClick")(b,"Confirm",false);assert(#HOST.actions==0)
            HOST.pad.sticks={};HOST.WheelPress("Back");assert(R.frame:GetAttribute("stage")=="root")
            HOST.WheelPress("Previous");assert(R.frame:GetAttribute("selected")==5)
            HOST.WheelPress("Cancel");assert(not R.frame:IsShown() and next(R.frame.binds)==nil)
        ''')

    def test_roster_guard_cancels_in_combat_and_never_rewrites_actions(self):
        self.run_lua('''
            local R=W.Radial
            HOST.WheelPress("Toggle");HOST.WheelPress("LeftButton",2)
            HOST.combat=true
            R.frame:RunAttribute("op-invalidate")
            HOST.units.party1={name="Replacement",class="DRUID",group=1}
            HOST.WheelPress("LeftButton",2);HOST.WheelPress("Toggle")
            assert(#HOST.actions==0 and not R.frame:IsShown() and not R.frame:GetAttribute("roster-valid"))
            R:Rebuild();assert(R.pending)
            HOST.combat=false;R:Rebuild();assert(R.frame:GetAttribute("roster-valid"))
            HOST.WheelPress("Toggle");assert(R:Entry(2).label=="Replacement")
        ''')

    def test_combat_contract_native_click_and_group_health_states(self):
        self.run_lua('''
            HOST.Raid();local R=W.Radial
            HOST.units.raid2.offline=true
            HOST.combat=true
            HOST.WheelPress("Toggle")
            assert(R:Entry(1).group[5]==5 and R:Entry(1).detail==nil)
            R.hover=1;R:Paint()
            assert(R.groupHealthRows[2]:GetText()=="Member2 · Offline")
            assert(R.cells[1].groupBars[1].track:IsShown())
            local originalMax=UnitHealthMax
            UnitHealthMax=function() return 0 end;R:Paint()
            assert(R.groupHealthRows[1]:GetText()=="Member1 · Unknown")
            UnitHealthMax=function() return {secret=true} end;R:Paint()
            assert(R.cells[1].groupBars[1].fill.range[2].secret)
            UnitHealthMax=originalMax
            HOST.WheelPress("LeftButton",1);HOST.WheelPress("LeftButton",3)
            HOST.WheelPress("LeftButton",2)
            assert(HOST.actions[1].unit=="raid3" and HOST.actions[1].kind=="spell")
            assert(UnitName("target")=="Stoneguard")
        ''')

    def test_text_ownership_profiles_validation_and_editor(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData
            assert(R.baseBound)
            local box=HOST.Field("AuctionQuantityInput", "3", true)
            box:SetFocus();R:SyncOwnership();assert(not R.baseBound)
            HOST.WheelPress("Toggle");assert(not R.frame:IsShown())
            box:ClearFocus();R:SyncOwnership();assert(R.baseBound)
            local profile=D.Profile();assert(#profile.actions==3)
            assert(not D.Save(4,{kind="macro",label="Unsafe",value="/run print(1) {unit}"}))
            assert(not D.Save(4,{kind="macro",label="No unit",value="/cast Renew"}))
            assert(D.Save(4,{kind="macro",label="Renew",value="/cast [@{unit},help] Renew"}))
            assert(D.Compile(profile.actions[4],"party2")=="macro")
            HOST.spec=2;assert(#D.Profile().actions==3);HOST.spec=1;assert(#D.Profile().actions==4)
            R:Edit();assert(R.editor:IsShown() and not R.baseBound)
            R:CloseEditor();assert(not R.editor:IsShown() and R.baseBound)
            W.db.style="Nintendo";W.Input:Refresh();R:Rebuild()
            assert(R.frame:GetAttribute("primary")=="PAD2" and R.frame:GetAttribute("back")=="PAD1")
        ''')

    def test_edit_mode_center_defaults_and_per_component_cancel(self):
        self.run_lua('''
            W.Placement.Enter()
            assert(W.Placement.Settings("radial").anchor=="center")
            W.Placement.Nudge("radial",40,-20)
            assert(W.Placement.draft.radial.x==40 and W.Placement.draft.keyboard.x==0)
            W.Placement.Leave();assert(W.Placement.Settings("radial").x==0)
            assert(not W.Radial.frame:IsShown())
        ''')

    def test_combat_reload_defers_protected_setup_and_world_refreshes_profile(self):
        self.load_addon(initial_combat=True)
        self.run_lua('''
            assert(W.Radial.pendingInit and not W.Radial.frame)
            HOST.combat=false;W.events:GetScript("OnEvent")(W.events,"PLAYER_REGEN_ENABLED")
            assert(W.Radial.frame and not W.Radial.pendingInit and not W.Radial.frame:IsShown())
            HOST.spec=2;W.RadialData.Profile().actions={}
            W.events:GetScript("OnEvent")(W.events,"PLAYER_ENTERING_WORLD")
            assert(W.Radial.frame:GetAttribute("action-count")==0)
        ''')

    def test_self_health_and_native_player_dispellable_debuffs_on_both_tiers(self):
        self.run_lua('''
            local R=W.Radial
            local calls=0
            C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
                assert(filter=="HARMFUL|RAID");calls=calls+1
                if unit=="player" and index<=6 then return {icon=135900+index,dispelName="Magic"} end
            end}
            HOST.WheelPress("Toggle");R.hover=1;R:Paint()
            assert(R:Entry(1).label=="You" and R.cells[1].bar.value==62 and R.cells[1].bar.range[2]==100)
            assert(R.centerHealth:GetText()=="62/100\\n62%")
            assert(R.cells[1].auras.icons[1].art:IsShown() and R.cells[1].auras.more:GetText()=="+2")
            assert(R.centerAuras.icons[5].art:IsShown() and R.centerAuras.more:GetText()=="+1")
            local oldCalls=calls;R:Paint();assert(calls==oldCalls)
            HOST.WheelPress("LeftButton",1);R:Paint()
            assert(R.frame:GetAttribute("member")==1 and R.centerHealth:GetText()=="62/100\\n62%")
            assert(R.centerAuras.icons[1].art:IsShown())
            W.db.radial.debuffs=false;R:Paint()
            assert(not R.centerAuras.icons[1].art:IsShown())
        ''')

    def test_aura_unknown_secret_and_offline_health_are_not_guessed(self):
        self.run_lua('''
            local R=W.Radial
            C_UnitAuras={GetAuraDataByIndex=function(unit,index)
                if index==1 then return {icon={secret=true},dispelName="Magic"}
                elseif index==2 then return {icon=135900,dispelName={secret=true}}
                elseif index==3 then return {secret=true} end
            end}
            HOST.WheelPress("Toggle");R.hover=1;R:Paint()
            assert(#R:Dispellable("player")==0 and not R.cells[1].auras.icons[1].art:IsShown())
            local secret={secret=true};UnitHealth=function()return secret end
            R:PaintHealth(R.centerHealth,R.cells[1].bar,R.snapshot.members[1],true)
            assert(R.cells[1].bar.value==secret and R.centerHealth:GetText()=="<native secret text>")
            HOST.units.player.offline=true;R:PaintHealth(R.centerHealth,nil,R.snapshot.members[1],true)
            assert(R.centerHealth:GetText()=="Offline")
            C_UnitAuras.GetAuraDataByIndex=function()error("restricted")end
            HOST.now=HOST.now+1;assert(#R:Dispellable("player")==0)
            assert(#HOST.actions==0)
        ''')

    def test_settings_canvas_reload_in_combat_defers_controller_capture(self):
        self.load_addon(initial_combat=True,settings_model=True)
        self.run_lua('''
            assert(W.Options.spellsCategory and not W.Radial.editor)
            Settings.OpenToCategory(W.Options.spellsCategory:GetID())
            assert(not W.Radial.editor)
            SettingsPanel:Hide();HOST.combat=false
            W.events:GetScript("OnEvent")(W.events,"PLAYER_REGEN_ENABLED")
            W.Radial:Edit()
            assert(W.Radial.editorInSettings and W.Radial.editor:IsShown())
            assert(HOST.settingsOpened==1235)
        ''')

    def test_axis_is_visual_only_even_if_model_grants_native_trust(self):
        self.run_lua('''
            local R=W.Radial;HOST.WheelPress("Toggle")
            local input=HOST.Axis
            local printed=0;W.Print=function()printed=printed+1 end
            for _,trusted in ipairs({false,true})do
                HOST.secureAxis=trusted;HOST.axisAllowed=true
                for i=1,4 do input("Camera",0,0);input("Camera",1,0);input("Camera",0,0)end
                assert(R.frame:GetAttribute("stage")=="root" and #HOST.actions==0)
            end
            assert(printed==0 and not R.cells[3].clickCalls)
            assert(input("Movement",1,0)==true)
            R.cells[3]:GetScript("OnClick")(R.cells[3],"StickRelease",false)
            assert(R.frame:GetAttribute("stage")=="root")
        ''')

    def test_directional_key_release_selects_member_and_casts_one_diagonal(self):
        self.run_lua('''
            local R=W.Radial
            HOST.combat=true;HOST.WheelPress("Classic")
            HOST.StickEdge("PADRSTICKUP",false,0,0)
            HOST.StickEdge("PADRSTICKUP",true,.7,.7)
            HOST.StickEdge("PADRSTICKRIGHT",true,.7,.7)
            HOST.StickEdge("PADRSTICKUP",false,.3,.25)
            assert(R.frame:GetAttribute("stage")=="root" and R.frame:GetAttribute("aim-index")==2)
            HOST.StickEdge("PADRSTICKRIGHT",false,0,0)
            assert(R.frame:GetAttribute("member")==2 and #HOST.actions==0)
            HOST.StickEdge("SHIFT-PADRSTICKRIGHT",true,.7,.7)
            HOST.StickEdge("SHIFT-PADRSTICKUP",true,.7,.7)
            HOST.StickEdge("SHIFT-PADRSTICKUP",true,.7,.7)
            HOST.StickEdge("SHIFT-PADRSTICKRIGHT",false,0,0)
            assert(#HOST.actions==0)
            HOST.StickEdge("SHIFT-PADRSTICKUP",false,0,0)
            assert(#HOST.actions==1 and HOST.actions[1].kind=="spell" and HOST.actions[1].unit=="party1")
            assert(UnitName("target")=="Stoneguard" and R.frame:GetAttribute("stage")=="root")
            HOST.StickEdge("PADRSTICKUP",false,0,0);assert(#HOST.actions==1)
        ''')

    def test_only_camera_is_consumed_when_stick_events_share_an_input_frame(self):
        self.run_lua('''
            local axis = HOST.NativeAxis
            HOST.combat = true
            HOST.pad.sticks = {{x=0,y=0,len=0},{x=0,y=0,len=0}}
            for _, mode in ipairs({"Sweep", "Classic"}) do
                HOST.WheelPress(mode)
                assert(axis("Left", .6, .8))
                assert(axis("Right", 1, 0))
                assert(axis("Movement", .6, .8))
                assert(not axis("Camera", 1, 0))
                HOST.pad.sticks[2] = {x=1,y=0,len=1}
                W.Radial:PollStick()
                assert(W.Radial.gestureArmed)
                assert(axis("Look", 0, .5))
                assert(axis("Right", 0, 0))
                assert(not axis("Camera", 0, 0))
                HOST.pad.sticks[2] = {x=0,y=0,len=0}
                W.Radial:PollStick()
                assert(not W.Radial.gestureArmed and #HOST.actions == 0)
                assert(axis("Left", 1, 0) and axis("Movement", 1, 0))
                -- Missing mapped sample: never carry capture into another frame.
                assert(axis("Right", .7, .7))
                for _, child in ipairs(W.Radial.frame.children) do
                    local update = child:GetScript("OnUpdate")
                    if child:IsGamePadStickEnabled() and update then update(child, .016) end
                end
                assert(axis("Left", -1, 0) and axis("Movement", -1, 0))
                assert(axis("Right", 0, 1))
                W.Radial.frame:RunAttribute("op-invalidate")
                assert(axis("Camera", 0, 1) and axis("Movement", -1, 0))
                W.Radial.frame:SetAttribute("roster-valid", true)
            end
        ''')

    def test_combat_wheel_preserves_movement_during_right_stick_selection(self):
        self.run_lua('''
            local f=W.Radial.frame
            local axis=HOST.Axis
            assert(not f:IsGamePadStickEnabled() and not f:GetScript("OnGamepadStick"))
            assert(axis("Camera",0,1))
            HOST.combat=true;HOST.WheelPress("Classic")
            assert(axis("Movement",.6,.8)==true)
            for key in pairs(f.binds) do assert(not key:find("PADLSTICK",1,true)) end
            local function right(down,y)
                HOST.pad.sticks={{x=.6,y=.8,len=1},{x=0,y=y,len=math.abs(y)}}
                assert(axis("Movement",.6,.8)==true)
                assert(axis("Camera",0,y)==false)
                local bind=f.binds.PADRSTICKUP
                local click=_G[bind[1]];click:GetScript("OnClick")(click,bind[2],down)
            end
            right(true,1);right(false,0);assert(f:GetAttribute("member")==1)
            right(true,1);right(false,0)
            assert(#HOST.actions==1 and HOST.actions[1].unit=="player" and axis("Movement",.6,.8)==true)
            HOST.WheelPress("Classic")
            assert(axis("Camera",0,1) and axis("Movement",.6,.8))
        ''')

    def test_stick_roll_updates_highlight_and_other_input_cancels_old_release(self):
        self.run_lua('''
            local R=W.Radial;HOST.WheelPress("Classic")
            HOST.StickEdge("PADRSTICKUP",true,0,1)
            HOST.StickEdge("PADRSTICKRIGHT",true,.7,.7)
            HOST.StickEdge("PADRSTICKUP",false,1,.1)
            assert(R.frame:GetAttribute("aim-index")==3)
            HOST.StickEdge("PADRSTICKRIGHT",false,0,0)
            assert(R.frame:GetAttribute("member")==3)
            HOST.StickEdge("PADRSTICKRIGHT",true,1,0)
            HOST.WheelPress("BackDpad");assert(R.frame:GetAttribute("stage")=="root")
            HOST.StickEdge("PADRSTICKRIGHT",false,0,0)
            assert(#HOST.actions==0 and R.frame:GetAttribute("stage")=="root")
            HOST.StickEdge("PADRSTICKLEFT",true,-1,0)
            HOST.StickEdge("PADRSTICKLEFT",false,0,0)
            assert(R.frame:GetAttribute("stage")=="root","empty wedge")
            HOST.StickEdge("PADRSTICKUP",true,0,1);R:Close()
            assert(not next(R.frame.binds));HOST.WheelPress("Classic")
            HOST.StickEdge("PADRSTICKRIGHT",true,.7,.7);HOST.StickEdge("PADRSTICKRIGHT",false,0,0)
            assert(R.frame:GetAttribute("stage")=="root","already aimed on open")
            HOST.StickEdge("PADRSTICKUP",true,0,1);HOST.StickEdge("PADRSTICKUP",false,0,0)
            assert(R.frame:GetAttribute("stage")=="spells")
            HOST.StickEdge("PADRSTICKRIGHT",true,.7,.7);R.frame:RunAttribute("op-invalidate")
            assert(not R.frame:IsShown() and not next(R.frame.binds) and #HOST.actions==0)
        ''')

    def test_lt_and_dpad_confirm_snapshot_on_down_and_commit_on_matching_up(self):
        self.run_lua('''
            W.db.radial.afterAction="close";W.Radial:Rebuild()
            local R=W.Radial;HOST.WheelPress("Classic")
            local b=R.dispatch;local click=b:GetScript("OnClick")
            for _,key in ipairs({"PADDUP","PADLTRIGGER"})do
                local command=R.frame.binds[key][2]
                assert(command==(key=="PADDUP" and "ConfirmDpad" or "ConfirmTrigger"))
                assert(R.frame.binds["ALT-CTRL-SHIFT-"..key][2]==command)
                HOST.pad.sticks={{x=0,y=0,len=0},{x=.7,y=.7,len=1}}
                click(b,command,true)
                assert(#HOST.actions==0)
                HOST.pad.sticks={};click(b,command,false)
            end
            assert(#HOST.actions==1 and HOST.actions[1].unit=="party1" and not R.frame:IsShown())
            assert(UnitName("target")=="Stoneguard" and next(R.frame.binds)==nil)
        ''')

    def test_overlapping_confirms_orphan_up_and_stale_tier_cannot_double_activate(self):
        self.run_lua('''
            local R=W.Radial;HOST.WheelPress("Classic")
            local b=R.dispatch;local click=b:GetScript("OnClick")
            HOST.pad.sticks={{x=0,y=0,len=0},{x=1,y=0,len=1}}
            click(b,"ConfirmTrigger",false);assert(R.frame:GetAttribute("stage")=="root")
            click(b,"ConfirmTrigger",true);click(b,"ConfirmDpad",true);click(b,"ConfirmDpad",false)
            assert(R.frame:GetAttribute("pressed")=="ConfirmTrigger")
            click(b,"ConfirmTrigger",false)
            assert(R.frame:GetAttribute("stage")=="spells" and #HOST.actions==0)
            click(b,"ConfirmDpad",false);click(b,"ConfirmTrigger",false);assert(#HOST.actions==0)
            click(b,"ConfirmDpad",true);R.frame:RunAttribute("op-stage","root")
            click(b,"ConfirmDpad",false);assert(R.frame:GetAttribute("stage")=="root" and #HOST.actions==0)
            click(b,"ConfirmTrigger",true);R.frame:RunAttribute("op-invalidate")
            click(b,"ConfirmTrigger",false);assert(#HOST.actions==0 and not R.frame:IsShown())
        ''')

    def test_neutral_confirm_and_nondefault_camera_index(self):
        self.run_lua('''
            local R=W.Radial;HOST.WheelPress("Classic")
            HOST.pad.sticks={};HOST.WheelPress("ConfirmDpad")
            assert(R.frame:GetAttribute("stage")=="root")
            R.frame:SetAttribute("camera-index",1)
            HOST.pad.sticks={{x=.7,y=.7,len=1},{x=0,y=-1,len=1}}
            HOST.WheelPress("ConfirmTrigger")
            assert(R.frame:GetAttribute("member")==2 and #HOST.actions==0)
            HOST.pad.sticks={};HOST.WheelPress("Next");HOST.WheelPress("Next")
            HOST.WheelPress("ConfirmDpad")
            assert(#HOST.actions==1 and HOST.actions[1].unit=="party1")
        ''')

    def test_confirm_images_follow_device_style(self):
        self.run_lua('''
            for style,atlas in pairs({Xbox="gamepad-xbox1-dpadup-normal",PlayStation="gamepad-ps-dpadup-normal",Nintendo="gamepad-switch-128x-dpad-up-normal"})do
                W.db.style=style
                assert(W.Input:TokenIcon("PADDUP")==atlas)
                assert(W.Input:TokenIcon("PADLTRIGGER")~=nil)
            end
        ''')

    def test_wheel_prompts_survive_all_styles_and_unbound_keyboard_back(self):
        self.run_lua('''
            local R=W.Radial
            W.db.actionBindings={primary="",back=""};W.Input:Refresh()
            for style,prefix in pairs({Xbox="gamepad-xbox1-",PlayStation="gamepad-ps-",Nintendo="gamepad-switch-128x-",Generic="gamepad-xbox1-"})do
                W.db.style=style;W.Input:Refresh()
                for token,direction in pairs({PADDUP="up",PADDDOWN="down",PADDLEFT="left",PADDRIGHT="right"})do
                    assert(W.Input:TokenIcon(token)==prefix.."dpad"..(style=="Nintendo" and "-" or "")..direction.."-normal")
                end
                for _,swap in ipairs({false,true})do
                    W.db.swapNintendo=swap;R:Rebuild();HOST.WheelPress("Toggle")
                    R.frame:GetScript("OnUpdate")(R.frame,.1)
                    R.cells[1]:GetScript("OnEnter")();R.cells[1]:GetScript("OnLeave")()
                    local back=style=="Nintendo" and swap and "PAD1" or "PAD2"
                    assert(R.frame.binds[back][2]=="Back")
                    assert(R.backGlyph.atlas==W.Input:TokenIcon(back))
                    assert(R.previousGlyph==nil and R.previousLabel==nil)
                    HOST.WheelPress("Back");assert(not R.frame:IsShown())
                end
            end
            HOST.Raid();R:Open();R:Paint()
            assert(R.previousGlyph==nil and R.frame.binds.PADLSTICK==nil)
            R:Edit();R:EditorFocus()
            for _,b in ipairs(R.editorControls)do if b.promptIcon then assert(not b.promptIcon:IsShown()) end end
            assert(#HOST.actions==0)
        ''')

    def test_secret_health_passes_only_to_native_text_and_statusbar_sinks(self):
        self.run_lua('''
            local R=W.Radial
            local function secret()
                return setmetatable({secret=true},{__tostring=function()error("secret formatted in Lua")end,
                    __div=function()error("secret arithmetic")end,__lt=function()error("secret compared")end,
                    __le=function()error("secret compared")end,__eq=function()error("secret compared")end})
            end
            local health,maximum,percent=secret(),secret(),secret()
            UnitHealth=function()return health end;UnitHealthMax=function()return maximum end
            CurveConstants={ScaleTo100={}}
            UnitHealthPercent=function(unit,predicted,curve)
                assert(predicted and rawequal(curve,CurveConstants.ScaleTo100));return percent
            end
            HOST.WheelPress("Toggle");R.hover=1;R:Paint()
            assert(rawequal(R.cells[1].bar.value,health) and rawequal(R.cells[1].bar.range[2],maximum))
            assert(R.cells[1].detail:GetText()=="") -- compact wedge uses a native bar; full values stay in the hub
            assert(rawequal(R.centerHealth.formatted.values[1],health))
            assert(rawequal(R.centerHealth.formatted.values[2],maximum))
            assert(rawequal(R.centerHealth.formatted.values[3],percent))
            HOST.Raid();R:Open();R.hover=2;R:Paint()
            assert(rawequal(R.groupHealthRows[1].formatted.values[2],percent))
            assert(rawequal(R.cells[2].groupBars[1].fill.value,health))
            assert(#HOST.actions==0)
        ''')

    def test_restricted_snippet_parser_rejects_keywords_even_in_comments(self):
        self.run_lua('''
            local f=W.Radial.frame
            f:SetAttribute("bad-probe","-- helper function comment\\nreturn true")
            local ok,err=pcall(f.RunAttribute,f,"bad-probe")
            assert(not ok and err:find("function keyword",1,true))
            f:SetAttribute("bad-probe","-- braces {} comment\\nreturn true")
            assert(not pcall(f.RunAttribute,f,"bad-probe"))
        ''')

    def test_raid_button_confirms_group_member_spell_in_combat_model(self):
        self.run_lua('''
            HOST.Raid();local R=W.Radial;HOST.combat=true;HOST.WheelPress("Toggle")
            local function point(x,y)HOST.pad.sticks={{x=0,y=0,len=0},{x=x,y=y,len=1}}end
            point(0,1);HOST.WheelPress("ConfirmTrigger")
            assert(R.frame:GetAttribute("stage")=="members" and R.frame:GetAttribute("group")==1)
            point(0,1);HOST.WheelPress("ConfirmDpad")
            assert(R.frame:GetAttribute("stage")=="spells" and R.frame:GetAttribute("member")==1)
            point(1,0);HOST.WheelPress("ConfirmTrigger")
            assert(#HOST.actions==1 and HOST.actions[1].unit=="raid1")
            assert(R.frame:IsShown() and R.frame:GetAttribute("stage")=="members" and UnitName("target")=="Stoneguard")
        ''')

if __name__ == '__main__': unittest.main()
