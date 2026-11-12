"""Keyboard-only skins and native Settings preview/controller contracts."""
import unittest
import test_radial as fixture

class AppearanceTests(unittest.TestCase):
    def setUp(self):
        self.env=fixture.RadialTests();self.env.load_addon(settings_model=True)
    def run_lua(self,s):self.env.run_lua(s)

    def test_root_customize_and_other_category_links_keep_settings_open(self):
        self.run_lua('''
            local O=W.Options;local hides=0
            SettingsPanel:HookScript("OnHide",function()hides=hides+1 end)
            for _,choice in ipairs({{"Keyboard appearance",1237},{"Controller bindings",1236},{"Wheel spells / macros",1235}})do
                O.Open();local found=false
                for _,entry in ipairs(HOST.initializers)do if entry.name==choice[1]then entry.run();found=true;break end end
                assert(found and HOST.settingsOpened==choice[2]and SettingsPanel:IsShown()and hides==0)
            end
            O.OpenAppearance();assert(O.appearanceFrame:IsShown())
            O.Open();assert(not O.appearanceFrame:IsVisible()and hides==0)
        ''')

    def test_defaults_migration_and_persistence_do_not_touch_user_content(self):
        self.run_lua(''' 
            local c=W.db.keyboardAppearance;assert(not c.background and not c.border and c.buttons=="controller")
            W.db.phrases.global={[1]={text="Custom kept"}};W.db.actionBindings={delete="PAD5"}
            W.db.keyboardAppearance={background="stone",border="tooltip",buttons="minimal"};W.InitDB()
            c=W.db.keyboardAppearance;assert(c.buttons=="controller"and c.version==2 and not c.background and not c.border)
            c.buttons="minimal";W.InitDB();assert(W.db.keyboardAppearance==c and c.buttons=="minimal")
            for _,skin in ipairs({"gold","classic"})do W.db.keyboardAppearance={buttons=skin};W.InitDB();assert(W.db.keyboardAppearance.buttons==skin)end
            W.db.keyboardAppearance.buttons={};W.InitDB();assert(W.db.keyboardAppearance.buttons=="controller")
            W.db.keyboardAppearance=12;W.InitDB();assert(W.db.keyboardAppearance.buttons=="controller")
            assert(W.db.phrases.global[1].text=="Custom kept"and W.db.actionBindings.delete=="PAD5"and W.db.schema==6)
        ''')

    def test_borderless_views_and_fixed_corner_focus_survive_pool_reuse(self):
        self.run_lua('''
            local k=W.Keyboard;k:Open(HOST.Field("ChatFrame1EditBox","text"))
            assert(not k.frame.border and not k.frame.keyboardBackground and not k.frame.keyboardEdge)
            local key=k.rows[2][1];local wide=k.rows[1][1]
            assert(#key.keyboardArt.normal.parts==8 and #wide.keyboardArt.normal.parts==8)
            assert(key.keyboardArt.normal.parts[1]:GetWidth()==wide.keyboardArt.normal.parts[1]:GetWidth())
            local uv=key.keyboardArt.normal.parts[1].texCoords
            assert(uv[1]==.2 and math.abs(uv[2]-(.2+.2*11/64))<.00001)
            assert(not key.highlightTexture and not key.normalTexture and key.keyboardArt.face:IsShown())
            k:Select(2,1);assert(key.focus:IsShown());k:Select(2,2);assert(not key.focus:IsShown())
            key:GetScript("OnMouseDown")(key);assert(k.mouseEditing==key and key.keyboardArt.pressed:IsShown())
            key:GetScript("OnMouseUp")(key);assert(not k.mouseEditing and not key.keyboardArt.pressed:IsShown())
            for _,view in ipairs({"tools","keys"})do k.view=view;k:Draw();assert(not k.frame.border)end
            assert(k.editor.text=="text"and #HOST.sent==0)
        ''')

    def test_button_skin_pool_uv_tint_reset_and_radial_settings_isolation(self):
        self.run_lua('''
            local k=W.Keyboard;k:Open(HOST.Field("ChatFrame1EditBox",""))
            local function key()return k.rows[2][1]end
            W.db.keyboardAppearance.buttons="classic";k:Draw()
            assert(key().normalTexture=="Interface\\\\Buttons\\\\UI-Panel-Button-Up")
            assert(key():GetNormalTexture().texCoords[2]==.625)
            W.db.keyboardAppearance.buttons="minimal";k:Draw()
            assert(key():GetNormalTexture().vertexColor[1]==.13 and key():GetNormalTexture().texCoords[2]==1)
            W.db.keyboardAppearance.buttons="gold";k:Draw()
            assert(key().normalTexture=="Interface\\\\Common\\\\dark-goldframe-button" and key():GetNormalTexture().vertexColor[1]==1)
            W.db.keyboardAppearance.buttons="classic";W.Options.OpenBindings()
            assert(W.Options.bindingEditor.rows[2].cells[1].template=="KeyBindingFrameBindingButtonTemplate")
            local ordinary=W.Theme.Button(UIParent,"ordinary");W.Theme.Regular(ordinary)
            assert(ordinary.normalTexture=="Interface\\\\Common\\\\dark-goldframe-button")
        ''')

    def test_controller_face_keeps_dark_gradient_after_redraw_mouse_and_skin_changes(self):
        self.run_lua('''
            local k=W.Keyboard;k:Open(HOST.Field("ChatFrame1EditBox","kept"))
            local function dark(button,pressed)
                local face=button.keyboardArt.face;local g=face.gradient
                assert(g and g[1]=="VERTICAL","key face lost its gradient")
                assert(not face.vertexColor,"flat vertex color replaces the gradient")
                for i=2,3 do
                    assert(g[i].r>0 and g[i].r<.2 and g[i].g<.2 and g[i].b<.2 and g[i].a==1)
                end
                assert(g[2].r<g[3].r)
                assert(math.abs(g[3].r-.18*(pressed and .65 or 1))<.000001)
            end
            local key=k.rows[2][1];dark(key)
            key:GetScript("OnMouseDown")(key);dark(key,true)
            key:GetScript("OnMouseUp")(key);dark(key)
            key:GetScript("OnMouseDown")(key);key:GetScript("OnLeave")(key);dark(key)
            key:GetScript("OnMouseDown")(key);k:Draw();dark(k.rows[2][1])
            for _,skin in ipairs({"classic","minimal","gold","controller"})do
                W.db.keyboardAppearance.buttons=skin;k:Draw()
            end
            for _,row in ipairs(k.rows)do for _,button in ipairs(row)do dark(button)end end
            W.Options.OpenAppearance()
            for _,sample in ipairs(W.Options.appearanceFrame.controls[1].samples)do dark(sample)end
            W.Options.PaintAppearance()
            for _,sample in ipairs(W.Options.appearanceFrame.controls[1].samples)do dark(sample)end
            assert(#HOST.sent==0)
        ''')

    def test_native_settings_skin_list_reset_and_directional_order(self):
        self.run_lua('''
            W.Options.OpenAppearance();local O=W.Options;local f=O.appearanceFrame
            assert(HOST.settingsOpened==1237 and #f.controls==6 and not W.Keyboard.frame:IsShown())
            local function press(t)f:GetScript("OnGamePadButtonDown")(f,t);f:GetScript("OnGamePadButtonUp")(f,t)end
            f:GetScript("OnGamePadButtonUp")(f,"PAD1");assert(W.db.keyboardAppearance.buttons=="controller")
            for i,skin in ipairs({"controller","gold","classic","minimal"})do
                assert(f.selected==i and f.controls[i].skin==skin and #f.controls[i].samples==3)
                press("PADDRIGHT");assert(f.selected==i)
                press("PAD1");assert(W.db.keyboardAppearance.buttons==skin and f.controls[i].chosen:IsShown())
                for _,sample in ipairs(f.controls[i].samples)do assert(sample.keyboardSkin==skin)end
                press("PADDDOWN")
            end
            assert(f.selected==5 and f.controls[5].template=="UIPanelButtonTemplate")
            press("PADDRIGHT");assert(f.selected==6);press("PADDUP");assert(f.selected==4)
            press("PADDDOWN");press("PAD1");assert(W.db.keyboardAppearance.buttons=="controller")
            press("PADDRIGHT");press("PAD1");assert(HOST.settingsOpened==1234 and #HOST.sent==0)
        ''')

    def test_settings_nintendo_confirm_ignores_keyboard_remaps_and_combat_blocks_edits(self):
        self.run_lua('''
            W.db.style="Nintendo";W.db.actionBindings={primary="",back="PAD5"};W.Input:Refresh()
            W.Options.OpenAppearance();local f=W.Options.appearanceFrame
            assert(f.controls[1].prompt.icons[1].atlas=="gamepad-switch-128x-face-a-normal")
            W.Options.MoveAppearance(0,1)
            f:GetScript("OnGamePadButtonDown")(f,"PAD2");f:GetScript("OnGamePadButtonUp")(f,"PAD2")
            assert(W.db.keyboardAppearance.buttons=="gold")
            HOST.combat=true;W.Options.SetButtonSkin("classic");assert(W.db.keyboardAppearance.buttons=="gold")
            HOST.combat=false;f:GetScript("OnGamePadButtonDown")(f,"PAD1");f:GetScript("OnGamePadButtonUp")(f,"PAD1")
            assert(HOST.settingsOpened==1234 and W.db.actionBindings.back=="PAD5")
        ''')

    def test_direct_native_category_entry_during_combat_defers_input_creation(self):
        self.run_lua('''
            HOST.combat=true;Settings.OpenToCategory(1237);assert(not W.Options.appearanceFrame)
            local canvas=HOST.settingsCanvases[3]
            HOST.combat=false;canvas:GetScript("OnEvent")(canvas,"PLAYER_REGEN_ENABLED")
            local f=W.Options.appearanceFrame;assert(f and f.controls[1]:IsEnabled())
            HOST.combat=true;canvas:GetScript("OnEvent")(canvas,"PLAYER_REGEN_DISABLED")
            assert(not f.controls[1]:IsEnabled()and W.db.keyboardAppearance.buttons=="controller")
        ''')

if __name__=='__main__':unittest.main()
