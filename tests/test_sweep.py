"""Forever hardware-click contract fixtures; gamepad events are simulated."""
import unittest
import test_radial as fixture


class SweepTests(unittest.TestCase):
    def setUp(self):
        self.env = fixture.RadialTests()
        self.env.load_addon(settings_model=True)
        self.run_lua('''
            R=W.Radial; f=R.frame; b=R.dispatch
            function edge(command,down) b:GetScript("OnClick")(b,command,down) end
            function point(x,y) HOST.pad.sticks={{x=0,y=0,len=0},{x=x,y=y,len=math.sqrt(x*x+y*y)}} end
            function macro(mode) local m=_G["WoWEnhancedControllerWheel"..mode];m:GetScript("OnClick")(m,"LeftButton",false) end
        ''')

    def run_lua(self, source):
        self.env.run_lua(source)

    def test_movement_during_trigger_hold_and_camera_handoff(self):
        self.run_lua('''
            assert(not f:IsGamePadStickEnabled() and not f:GetScript("OnGamepadStick"))
            HOST.combat=true;macro("Sweep")
            point(.95,.31);HOST.pad.sticks[1]={x=0,y=1,len=1}
            assert(HOST.Axis("Movement",0,1) and not HOST.Axis("Camera",.95,.31))
            edge("ConfirmTrigger",true);point(0,1);HOST.pad.sticks[1]={x=-1,y=0,len=1}
            assert(HOST.Axis("Movement",-1,0) and not HOST.Axis("Camera",0,1))
            edge("ConfirmTrigger",false);assert(#HOST.actions==1 and HOST.actions[1].unit=="party1")
            macro("Sweep");assert(HOST.Axis("Camera",0,1) and HOST.Axis("Movement",-1,0))
            HOST.combat=false;W.db.radial.enabled=false;R:SyncOwnership();assert(HOST.Axis("Camera",0,1))
            W.db.radial.enabled=true;R:SyncOwnership();assert(HOST.Axis("Camera",0,1))
        ''')

    def test_default_held_cast_once_and_independent_macro_openers(self):
        self.run_lua('''
            assert(W.db.radial.behavior=="sweep")
            HOST.combat=true;HOST.WheelPress("Toggle")
            assert(f:GetAttribute("dual") and R.sweepSurface:IsShown())
            point(.95,.31);edge("ConfirmTrigger",true)
            assert(f:GetAttribute("member")==2 and #HOST.actions==0)
            edge("ConfirmDpad",false);edge("KeyConfirmTrigger",false)
            assert(f:GetAttribute("sweep-button")=="ConfirmTrigger" and #HOST.actions==0)
            point(0,1);edge("ConfirmTrigger",false);edge("ConfirmTrigger",false)
            assert(#HOST.actions==1 and HOST.actions[1].unit=="party1" and HOST.actions[1].spell==2061)
            assert(UnitName("target")=="Stoneguard" and f:GetAttribute("stage")=="root")
            macro("Classic");assert(f:IsShown() and f:GetAttribute("mode")=="classic" and not R.sweepSurface:IsShown())
            macro("Sweep");assert(f:IsShown() and f:GetAttribute("dual"))
            macro("Sweep");assert(not f:IsShown())
            HOST.combat=false;HOST.settings.WEC_RADIAL_behavior:SetValue("classic")
            macro("Toggle");assert(f:GetAttribute("mode")=="classic")
            macro("Sweep");assert(f:GetAttribute("dual") and W.db.radial.behavior=="classic")
        ''')

    def test_solo_top_spell_highlights_and_casts_without_stick_button_events(self):
        self.run_lua('''
            for i=1,4 do HOST.units["party"..i]=nil end
            R:Rebuild();macro("Sweep")
            assert(f:GetAttribute("member-count")==1)
            for attempt=1,2 do
                point(0,1);edge("ConfirmTrigger",true);R:Paint()
                assert(R.highlight:IsShown() and R.title:GetText()=="Flash Heal","top highlight on hold")
                if attempt==2 then
                    point(.71,.71);R:Paint()
                    assert(R.highlight:IsShown() and R.title:GetText()~="Flash Heal")
                    point(0,-1);R:Paint();assert(not R.highlight:IsShown(),"empty slot")
                    point(-.02,.99);R:Paint()
                    assert(R.highlight:IsShown() and R.title:GetText()=="Flash Heal","return to top")
                end
                assert(#HOST.actions==attempt-1,"aiming must not cast")
                edge("ConfirmTrigger",false);edge("ConfirmTrigger",false)
                assert(#HOST.actions==attempt and HOST.actions[attempt].spell==2061)
                assert(HOST.actions[attempt].unit=="player" and UnitName("target")=="Stoneguard")
            end
        ''')

    def test_stale_neutral_and_empty_releases(self):
        self.run_lua('''
            macro("Sweep")
            for _,cancel in ipairs({"neutral","empty","back","switch","roster","device"}) do
                if not f:IsShown() then R:Rebuild();macro("Sweep") end
                point(0,1);edge("ConfirmTrigger",true);point(.7,.7)
                if cancel=="neutral" then point(0,0)
                elseif cancel=="empty" then point(0,-1)
                elseif cancel=="back" then HOST.WheelPress("Back")
                elseif cancel=="switch" then macro("Classic")
                elseif cancel=="roster" then f:RunAttribute("op-invalidate")
                else HOST.combat=true; R:InputChanged(); HOST.combat=false end
                edge("ConfirmTrigger",false);assert(#HOST.actions==0,cancel)
                R:Close()
            end
        ''')

    def test_mouse_drag_keyboard_scopes_and_raid_pages(self):
        self.run_lua('''
            local D=W.RadialData;D.AddPage();D.Save(4,{kind="spell",value="139",label="Renew",page=-1,slot=3})
            HOST.Raid();macro("Sweep");assert(not f:GetAttribute("dual"))
            HOST.WheelPress("LeftButton",2);assert(f:GetAttribute("dual"))
            local surface=R.sweepSurface
            function surface:GetMousePosition()return self.mx,self.my end
            surface.mx,surface.my=.7,.56
            local click=surface:GetScript("OnClick");click(surface,"LeftButton",true)
            assert(f:GetAttribute("member")==7)
            HOST.WheelPress("PagePrevious");surface.mx,surface.my=.9,.5;click(surface,"LeftButton",false)
            assert(#HOST.actions==1 and HOST.actions[1].unit=="raid7" and f:GetAttribute("group")==2)
            R:Close()
            local B=W.ControlBindings;assert(B.Assign("wheel",B.wheel[1],"key","F8"))
            assert(B.Assign("text",{"symbols"},"key","F8"))
            assert(W.Input.reverse.F8=="symbols")
            assert(not B.Assign("wheel",B.wheel[2],"key","F8"))
            HOST.raid=false;R:Rebuild();macro("Sweep");assert(f.binds.F8[2]=="KeyConfirmTrigger")
            point(.95,.31);edge("KeyConfirmTrigger",true);point(0,1);edge("ConfirmTrigger",false)
            assert(#HOST.actions==1);edge("KeyConfirmTrigger",false)
            assert(#HOST.actions==2 and HOST.actions[2].unit=="party1")
            R:Close();assert(not next(f.binds))
            local k=W.Keyboard;k:Open(HOST.Field("ChatFrame1EditBox",""));W.Input:Acquire(true)
            assert(W.KeyboardBindings.owner.binds.F8 and not W.KeyboardBindings.owner.binds["ALT-F8"])
        ''')

    def test_fresh_mouse_drag_recovers_after_lost_release(self):
        self.run_lua('''
            macro("Sweep")
            local surface=R.sweepSurface
            function surface:GetMousePosition()return self.mx,self.my end
            local click=surface:GetScript("OnClick")
            surface.mx,surface.my=.69,.56;click(surface,"LeftButton",true)
            assert(f:GetAttribute("member")==2)
            surface.mx,surface.my=.5,.71;click(surface,"LeftButton",true)
            assert(#HOST.actions==0 and f:GetAttribute("member")==1)
            surface.my=.89;click(surface,"LeftButton",false)
            assert(#HOST.actions==1 and HOST.actions[1].unit=="player")
        ''')

    def test_keyboard_capture_accepts_modifier_then_base_key(self):
        self.run_lua('''
            local O=W.Options;O.OpenBindings();local editor=O.bindingEditor
            local row
            for _,entry in ipairs(editor.rows) do
                if entry.scope=="wheel" and entry.data and entry.data[1]=="ConfirmTrigger" then row=entry;break end
            end
            row.cells[1].action();assert(O.bindingCapture)
            IsControlKeyDown=function()return true end
            local down,up=editor:GetScript("OnKeyDown"),editor:GetScript("OnKeyUp")
            down(editor,"LCTRL");down(editor,"F8");up(editor,"F8");up(editor,"LCTRL")
            assert(not O.bindingCapture and not editor.keyHeld)
            assert(W.ControlBindings.Get("wheel",row.data,"key")=="CTRL-F8")
        ''')

    def test_global_columns_preserve_other_keys_and_scope(self):
        self.run_lua('''
            local B=W.ControlBindings;local row=B.general[2];local keys={F9=row[1],PAD5=row[1],F1="TOGGLEHELP"}
            assert(not B.IsPad("NUMPAD1") and not B.IsPad("CTRL-NUMPAD4") and B.IsPad("ALT-PAD1"))
            C_KeyBindings={GetBindingContextForAction=function() return 9 end}
            function GetBindingKey(id,_,ctx) assert(ctx==9);local t={};for k,v in pairs(keys) do if v==id then t[#t+1]=k end end;return unpack(t) end
            function GetBindingAction(key)return keys[key] or "" end
            function SetBinding(key,action,ctx) assert(ctx==9);if key=="F12" then return false end;keys[key]=action;return true end
            function GetCurrentBindingSet()return 2 end
            function SaveBindings(n)assert(n==2) end
            assert(B.Get("general",row,"key")=="F9" and B.Get("general",row,"pad")=="PAD5")
            assert(not B.Assign("general",row,"key","F1") and keys.F1=="TOGGLEHELP")
            assert(not B.Assign("general",row,"key","F12") and keys.F9==row[1])
            assert(B.Assign("general",row,"key","F10") and not keys.F9 and keys.F10==row[1] and keys.PAD5==row[1])
            assert(B.Assign("general",row,"pad","") and not keys.PAD5 and keys.F10==row[1])
            assert(B.ResetGeneral() and not keys.F10 and keys.F1=="TOGGLEHELP" and W.db.radial.defaultR3)
        ''')
