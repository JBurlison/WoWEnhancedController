"""Translation completeness, UTF-8, user-content and native Settings contracts."""
from pathlib import Path
import importlib.util
import json
import re
import unittest
import test_radial as fixture

ROOT=Path(__file__).resolve().parents[1]
DATA=json.loads((ROOT/'localization/catalog.json').read_text(encoding='utf8'))

class LocalizationTests(unittest.TestCase):
    def env(self, locale='enUS', settings=False):
        env=fixture.RadialTests()
        env.load_addon(locale=locale,settings_model=settings)
        return env

    def test_catalog_complete_format_safe_and_export_matches(self):
        spec=importlib.util.spec_from_file_location('localization',ROOT/'tools/localization.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        formats=lambda text: re.findall(r'%(?:[-+ #0]*\d*(?:\.\d+)?[cdiouxXeEfgGqs]|%)',text)
        for key,values in DATA['messages'].items():
            self.assertEqual(len(values),9,key)
            for locale,value in zip(DATA['locales'],values):
                self.assertTrue(value.strip(),(locale,key))
                self.assertEqual(formats(key),formats(value),(locale,key))
                if '{unit}' in key:self.assertIn('{unit}',value,(locale,key))
        for locale in DATA['locales']:
            env=self.env(locale)
            for key,values in DATA['messages'].items():
                self.assertEqual(env.lua.globals().W.L[key],values[DATA['locales'].index(locale)],(locale,key))

    def test_aliases_english_fallback_and_user_content_is_unchanged(self):
        for locale in ['enUS','enGB','deDE','frFR','esES','esMX','itIT','ptBR','ruRU','koKR','zhCN','zhTW','xxXX']:
            env=self.env(locale)
            env.run_lua('''
                assert(W.L["Future untranslated label"]=="Future untranslated label")
                W.db.phrases.global={[1]={text="Hello! 用户 Привет"}}
                assert(W.Phrases.Resolve({key="global"},1)=="Hello! 用户 Привет")
                assert(W.RadialData.Save(1,{kind="spell",value="139",label="Target 用户"}))
                assert(W.RadialData.Profile().actions[1].label=="Target 用户")
                local kind,body=W.RadialData.Compile({kind="macro",label="User",value="/cast [@{unit},help] Renew"},"raid13")
                assert(kind=="macro" and body=="/cast [@raid13,help] Renew")
                HOST.WheelPress("Toggle");HOST.WheelPress("LeftButton",3)
                assert(W.Radial.frame:GetAttribute("stage")=="spells")
                HOST.WheelPress("Back");assert(W.Radial.frame:GetAttribute("stage")=="root")
                HOST.WheelPress("Cancel");assert(not W.Radial.frame:IsShown())
            ''')
            if locale=='esMX':self.assertEqual(env.lua.globals().W.Locale.code,'esES')
            if locale in ('enUS','enGB','xxXX'):self.assertEqual(env.lua.globals().W.L['Keyboard'],'Keyboard')

    def test_unicode_keyboard_rows_uppercase_and_native_names(self):
        env=self.env('ruRU')
        env.run_lua('''
            assert(W.Locale.Upper("й")=="Й" and W.Locale.Upper("é")=="É")
            assert(#W.Locale.Characters("йцукенгшщзх")==11)
            local field=HOST.Field("UserText","");field:SetFocus();W.Keyboard:Open(field)
            local found=false
            for _,b in ipairs(W.Keyboard.pool)do
                if b:IsShown() and b:GetText()=="й" then b.run();found=true;break end
            end
            assert(found and field:GetText()=="й")
            W.Keyboard.shift=true;W.Keyboard:Draw()
            found=false
            for _,b in ipairs(W.Keyboard.pool)do
                if b:IsShown() and b:GetText()=="Й" then b.run();found=true;break end
            end
            assert(found and field:GetText()=="йЙ")
            C_Item={GetItemNameByID=function(id)assert(id==2589);return "Native localized item"end}
            assert(W.Phrases.Resolve({key="auction:search"},1)=="Native localized item")
            local profile=W.RadialData.Profile()
            local old=C_Spell.GetSpellInfo
            C_Spell.GetSpellInfo=function(id)local info=old(id);if info then info.name="Native localized spell" end;return info end
            assert(W.RadialData.Profile().actions[1].label=="Native localized spell")
        ''')

    def test_native_settings_registration_shared_values_and_addon_menu(self):
        env=self.env('frFR',settings=True)
        env.run_lua('''
            assert(HOST.settingsCategory.name=="Enhanced Controller" and #HOST.initializers==27 and HOST.settings.WEC_RADIAL_behavior:GetValue()=="sweep")
            assert(HOST.settings.WEC_enabled and HOST.settings.WEC_RADIAL_enabled)
            assert(HOST.settings.WEC_fontSize.name==W.L["Font size"])
            local controls={}
            for _,item in ipairs(HOST.initializers)do if item.setting then controls[item.setting.id]=item end end
            assert(controls.WEC_fontSize.options.labels.right(20)=="20")
            assert(controls.WEC_scale.options.labels.right(1)=="100%")
            assert(HOST.settings.WEC_RADIAL_defaultR3.name==W.L["Use R3 to open the wheel"])
            SettingsPanel:Show();W.Radial:SyncOwnership();assert(not W.Radial.baseBound)
            SettingsPanel:Hide();W.Radial:SyncOwnership();assert(W.Radial.baseBound)
            HOST.settings.WEC_fontSize:SetValue(20)
            assert(W.db.fontSize==20 and W.Radial.boundFont==20)
            HOST.settings.WEC_style:SetValue("Nintendo")
            assert(W.db.style=="Nintendo" and W.Radial.frame:GetAttribute("primary")=="PAD2")
            HOST.settings.WEC_RADIAL_enabled:SetValue(false)
            assert(W.db.enabled and not W.db.radial.enabled and not W.Radial.baseBound)
            HOST.settings.WEC_RADIAL_enabled:SetValue(true)
            assert(W.Radial.baseBound)
            WoWEnhancedController_OnAddonCompartmentClick()
            assert(W.Launcher:IsShown() and not W.Keyboard.frame:IsShown())
            W.Launcher:Close()
            W.Radial:Edit()
            assert(HOST.settingsOpened==1235 and W.Radial.editorInSettings and W.Radial.editor:IsShown())
            assert(not W.Placement.registry.radialEditor)
            W.Radial:CloseEditor();assert(HOST.settingsOpened==1234)
            HOST.combat=true;HOST.settings.WEC_fontSize:SetValue(18)
            assert(W.Radial.pending and W.Radial.boundFont==20)
        ''')

    def test_editor_native_glyph_focus_and_multiline_macro_scroll(self):
        env=self.env('deDE')
        env.run_lua('''
            W.db.fontSize=20;local R=W.Radial;R:Edit()
            assert(R.editorTabs[1].prompt.icons[1].atlas==W.Input:Icon("primary"))
            R.editorTabs[3].run()
            for i,b in ipairs(R.editorControls) do if b.fieldLabel==W.L["Command / macro"] then R.editorSelected=i end end
            R:EditorFocus()
            assert(R.editorControls[R.editorSelected].promptIcon:IsShown())
            assert(R.editorStatus:GetText():find(W.L["Command / macro"],1,true))
            R.valueInput:SetText("#showtooltip\\n/cast [@{unit},help,nodead] Renew\\n/stopmacro\\n/usertext")
            assert(R.valueInput:GetHeight()>80)
            R.valueInput:GetScript("OnCursorChanged")(R.valueInput,4,-180,1,20)
            assert(R.valueInput.wecScroll:GetVerticalScroll()>0)
        ''')

    def test_settings_exit_cleans_partial_editor_and_search_without_stealing_foreign_focus(self):
        env=self.env('enUS',settings=True)
        env.run_lua('''
            local R=W.Radial;local canvas=HOST.settingsCanvases[1]
            -- This deliberately partial editor tests the hide callback alone.
            local hide=canvas:GetScript("OnHide")
            R.editor=CreateFrame("Frame",nil,canvas)
            R.labelInput=nil;R.valueInput=HOST.Field("PartialMacro","kept")
            R.valueInput:SetFocus();hide(canvas)
            assert(not R.valueInput:HasFocus()and not R.editor:IsShown())
            R.valueInput=nil;R.searchInput=HOST.Field("PartialSearch","query")
            W.Keyboard:Open(R.searchInput);assert(W.Keyboard.session.target==R.searchInput)
            hide(canvas)
            assert(not R.searchInput:HasFocus()and not W.Keyboard.frame:IsShown()and not W.Input.active)
            local foreign=HOST.Field("OtherText","untouched");W.Keyboard:Open(foreign)
            hide(canvas)
            assert(foreign:HasFocus()and W.Keyboard.session.target==foreign and foreign:GetText()=="untouched")
            assert(#HOST.sent==0)
        ''')

if __name__=='__main__':unittest.main()
