"""Discovery, click dispatch, lifecycle and controller contracts; no game security emulation."""
import unittest
import test_radial as fixture

class MinimapTests(unittest.TestCase):
    def setUp(self):
        self.env=fixture.RadialTests(); self.env.load_addon(settings_model=True)
        self.run_lua('''
            local methods=getmetatable(UIParent).__index
            function methods:IsProtected()return self.protected or false end
            function methods:IsForbidden()return self.forbidden or false end
            function methods:GetEffectiveAlpha()return self.alpha or 1 end
            function methods:GetTexture()return self.asset end
            MinimapCluster=CreateFrame("Frame","MinimapCluster",UIParent)
            Minimap=CreateFrame("Minimap","Minimap",MinimapCluster);Minimap:SetSize(200,200)
            W.Launcher:Init()
            HOST.targets={}
            HOST.focusKeys={"PADBACK"}
            C_KeyBindings={GetBindingContextForAction=function(action)
                assert(action=="TOGGLEUIFOCUS"); return 9
            end}
            function GetBindingKey(action, mode, context)
                if action=="TOGGLEUIFOCUS" then
                    assert(mode==nil and context==9); return HOST.focusKeys[1], HOST.focusKeys[2]
                end
            end
            function HOST.MenuEdge(key, down)
                local binding=W.Launcher.inputOwner.binds[key]
                if binding then
                    local button=_G[binding[1]]
                    button:GetScript("OnClick")(button,binding[2],down)
                elseif down then HOST.fallthrough=key end
            end
            function HOST.MinimapButton(name,parent)
                local b=CreateFrame("Button",name,parent or Minimap)
                b:SetScript("OnClick",function(self,key,down)
                    assert(not W.Launcher:IsShown() and not next(W.Launcher.inputOwner.binds),"release before dispatch")
                    HOST.clicked={self,key,down}
                end)
                HOST.targets[#HOST.targets+1]=b;return b
            end
            function EnumerateFrames(previous)
                if not previous then return HOST.targets[1] end
                for i,b in ipairs(HOST.targets)do if b==previous then return HOST.targets[i+1] end end
            end
        ''')
    def run_lua(self,s):self.env.run_lua(s)

    def test_discovery_visibility_labels_and_reparented_addon_buttons(self):
        self.run_lua('''
            local a=HOST.MinimapButton("LibDBIcon10_Questie",UIParent);a.dataObject={label="|cffabcdefQuest helper|r",icon=123}
            local b=HOST.MinimapButton("Hidden");b:Hide()
            local c=HOST.MinimapButton("Forbidden");c.forbidden=true
            local d=HOST.MinimapButton("Disabled");d:Disable()
            local e=HOST.MinimapButton("Transparent");e.alpha=0
            local f=HOST.MinimapButton("Unrelated",UIParent)
            local values=W.MinimapTargets:Collect(true)
            assert(#values==2 and values[1].frame==W.Launcher.icon and values[2].frame==a)
            assert(values[2].label=="Quest helper" and values[2].texture==123)
        ''')

    def test_paired_input_scroll_and_single_right_click_handoff(self):
        self.run_lua('''
            for i=1,15 do HOST.MinimapButton(string.format("Addon%02d",i)) end
            local m=W.Launcher;m:Open("minimap");assert(not W.Radial.baseBound and #m.entries==16)
            m:Up("PAD1");assert(m:IsShown() and not HOST.clicked)
            for i=1,15 do m:Down("PADDDOWN");m:Up("PADDDOWN") end
            assert(m.selected==16 and m.offset==7 and m.rows[9].index==16)
            local target=m.entries[16].frame
            m:Down("PAD3");m:Down("PAD3");m:Up("PAD3");m:Up("PAD3")
            assert(HOST.clicked[1]==target and HOST.clicked[2]=="RightButton"and not HOST.clicked[3])
            assert(not m:IsShown() and not m.highlight:IsShown() and W.Radial.baseBound)
        ''')

    def test_disappearing_target_rejects_held_activation_and_retains_identity(self):
        self.run_lua('''
            local a=HOST.MinimapButton("Alpha");local b=HOST.MinimapButton("Beta")
            local m=W.Launcher;m:Open("minimap");m:Select(3);m:Down("PAD1")
            a:Hide();m:Refresh(true);assert(m.selected==2 and m.entries[2].frame==b)
            m:Up("PAD1");assert(not HOST.clicked and m:IsShown())
            m:Down("PAD1");b:Hide();m:Up("PAD1");assert(not HOST.clicked and not m:IsShown())
        ''')

    def test_dropdown_and_mouse_only_dispatch_and_protected_denial(self):
        self.run_lua('''
            local b=HOST.MinimapButton("Dropdown");b:SetScript("OnClick",nil)
            function b:OpenMenu()assert(not W.Launcher:IsShown());HOST.opened=true end
            W.Launcher:Open("minimap");W.Launcher:Select(2);W.Launcher:Activate("LeftButton");assert(HOST.opened)
            b.OpenMenu=nil;local count=0
            b:SetScript("OnMouseDown",function(_,key)assert(key=="RightButton");count=count+1 end)
            b:SetScript("OnMouseUp",function(_,key)assert(key=="RightButton");count=count+1 end)
            local ok=W.MinimapTargets:Activate(W.MinimapTargets:Describe(b),"RightButton");assert(ok and count==2)
            b.protected=true;ok=W.MinimapTargets:Activate(W.MinimapTargets:Describe(b),"LeftButton");assert(not ok and count==2)
        ''')

    def test_native_settings_icon_persistence_commands_and_combat_cleanup(self):
        self.run_lua('''
            local m=W.Launcher;assert(m.icon:IsShown()and W.db.minimapAngle==225)
            W.db.minimapAngle=80;HOST.settings.WEC_minimapVisible:SetValue(false);W.InitDB()
            assert(not m.icon:IsShown()and W.db.minimapAngle==80 and not W.db.minimapVisible)
            SlashCmdList.WOWENHANCEDCONTROLLER("minimap");assert(m:IsShown()and #m.entries==0)
            m:Down("PAD1");HOST.combat=true;m.frame:GetScript("OnEvent")(m.frame,"PLAYER_REGEN_DISABLED")
            assert(not m:IsShown()and not m.held);assert(not m:Open("launcher"))
            HOST.combat=false;SlashCmdList.WOWENHANCEDCONTROLLER("menu");assert(m:IsShown()and m.view=="launcher")
            assert(#m.entries==9);m:Down("PADDRIGHT");m:Up("PADDRIGHT");assert(m.view=="minimap")
            m:Down("PAD2");m:Up("PAD2");assert(not m:IsShown()and not m.frame.pad)
        ''')

    def test_foreign_focus_nintendo_and_skin_gradient(self):
        self.run_lua('''
            local b=HOST.MinimapButton("Addon")
            W.db.style="Nintendo";W.db.actionBindings={primary="PAD5",back="",delete="PAD6"};W.Input:Refresh()
            local m=W.Launcher;m:Open("minimap");m:Select(2)
            assert(m.openButton.prompt.icons[1].atlas=="gamepad-switch-128x-face-a-normal")
            m:Down("PAD2");local box=HOST.Field("ForeignEditor","kept");box:SetFocus();m:Up("PAD2")
            assert(not HOST.clicked and box:GetText()=="kept")
            m.frame:GetScript("OnUpdate")(m.frame,.6);assert(not m:IsShown())
            box:ClearFocus();m:Open();local face=m.rows[1].keyboardArt.face
            assert(face.gradient and not face.vertexColor)
            m:Down("PAD1");m:Up("PAD1");assert(not m:IsShown())
            assert(W.db.actionBindings.primary=="PAD5"and W.db.actionBindings.delete=="PAD6")
        ''')

    def test_explicit_focus_routes_reacquire_without_activating_a_row(self):
        self.run_lua('''
            local m=W.Launcher;m:Open("minimap");m:Select(1)
            HOST.mode=0;m:ReleaseControls();m.held={token="PAD1"}
            m.focusButton.action();assert(m.inputOwner.binds.PADBACK and m.focusRequested and not m.held)
            assert(m.focusButton.badgeIcon.atlas==W.Input:Icon("focus") and m.selected==1)
            m:Up("PAD1");assert(m:IsShown() and m.view=="minimap")
            m:ReleaseControls();assert(W.FocusBinding() and m.inputOwner.binds.PADBACK)
            m:Down("PADBACK");m:Up("PADBACK");assert(m:IsShown()and m.selected==1)
            local box=HOST.Field("ForeignFocus","kept");box:SetFocus()
            m:ReleaseControls();assert(not m:RequestFocus() and not next(m.inputOwner.binds) and box:HasFocus())
            box:ClearFocus();HOST.combat=true;assert(not m:RequestFocus())
            HOST.combat=false;m:Close();assert(not m.focusRequested and not m:RequestFocus())
        ''')

    def test_macro_open_owns_native_focus_and_navigation_until_escape(self):
        self.run_lua('''
            local m=W.Launcher;HOST.keys.PAD1=true
            SlashCmdList.WOWENHANCEDCONTROLLER("menu")
            HOST.MenuEdge("PAD1",true);HOST.keys.PAD1=false;HOST.MenuEdge("PAD1",false)
            assert(m:IsShown() and m.selected==1 and not W.Input.active)
            HOST.MenuEdge("PADDDOWN",true);HOST.MenuEdge("PADDDOWN",false)
            m.focusRequested=nil
            HOST.MenuEdge("PADBACK",true);HOST.MenuEdge("PADBACK",false)
            assert(m.focusRequested and m.selected==2 and not HOST.fallthrough)
            HOST.MenuEdge("PADDRIGHT",true);HOST.MenuEdge("PADDRIGHT",false)
            assert(m.view=="minimap")
            m.frame:GetScript("OnKeyDown")(m.frame,"ESCAPE")
            assert(not m:IsShown() and not next(m.inputOwner.binds))
            HOST.MenuEdge("PADBACK",true);assert(HOST.fallthrough=="PADBACK")
        ''')

    def test_native_focus_remap_unbind_and_stale_releases(self):
        self.run_lua('''
            local m=W.Launcher;HOST.focusKeys={"CTRL-PAD1","PADFORWARD"}
            SlashCmdList.WOWENHANCEDCONTROLLER("minimap")
            assert(m.inputOwner.binds["CTRL-PAD1"] and m.inputOwner.binds.PADFORWARD and not m.inputOwner.binds.PADBACK)
            HOST.MenuEdge("CTRL-PAD1",true);HOST.MenuEdge("PADFORWARD",false)
            assert(m.held and m.held.token=="CTRL-PAD1")
            HOST.MenuEdge("CTRL-PAD1",false);assert(m:IsShown() and not m.held and not HOST.clicked)
            HOST.MenuEdge("PADFORWARD",true)
            HOST.focusKeys={nil,"PAD1"};m.frame:GetScript("OnEvent")(m.frame,"UPDATE_BINDINGS")
            assert(not m.held and not m.inputOwner.binds.PADFORWARD and not m.inputOwner.binds["CTRL-PAD1"])
            HOST.MenuEdge("PAD1",true);HOST.MenuEdge("PAD1",false);assert(m:IsShown())
            HOST.focusKeys={};m.frame:GetScript("OnEvent")(m.frame,"UPDATE_BINDINGS")
            assert(m.focusKey==nil and not m.inputOwner.binds.PADBACK and m.focusButton:GetText()=="Focus")
            m:Close();assert(not next(m.inputOwner.binds))
        ''')

if __name__=='__main__':unittest.main()
