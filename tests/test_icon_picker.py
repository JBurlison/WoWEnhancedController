"""Shared picker selection/cancel and stale-input contracts. Native UI tested separately."""
from pathlib import Path
import unittest
import test_radial as fixture

class IconPickerTests(unittest.TestCase):
    def setUp(self):
        self.env=fixture.RadialTests();self.env.load_addon()
        self.env.lua.execute((Path(__file__).parent/'icon_picker_host.lua').read_text(encoding='utf8'))
        self.env.run_lua('W.RadialData.Spells=function()return {{value="2061",label="Лечение",icon=135907}}end')
    def run_lua(self,code):self.env.run_lua(code)

    def test_unbound_and_conflicting_actions_keep_picker_hints_available(self):
        self.run_lua('''local P=W.IconPicker;local selected=0
            local function expected(action)
                local atlas=W.Input:Icon(action)
                return atlas and "|A:"..atlas..":20:20|a" or W.Input:Hint(action)
            end
            for _,bindings in ipairs({{primary=""},{back=""},{shift=""},
                {primary="",back="",shift=""},{back="PAD1",shift="PAD1"},
                {primary="PADBACK"},{shift="PADPADDLE1"}}) do
                W.db.actionBindings=bindings;W.Input:Refresh()
                assert(P:Open({onSelect=function()selected=selected+1 end}))
                P:Focus();P:Move("PADDDOWN")
                assert(P.frame.hint:GetText()==W.L.Format("%s Select · %s Use icon · %s Back",
                    expected("primary"),expected("shift"),expected("back")))
                assert(not P.frame.hint:GetText():find("|A::",1,true))
                P:Close();assert(selected==0)
            end
            W.db.actionBindings={};W.Input:Refresh();assert(P:Open({}))
            assert(P.frame.hint:GetText():find("gamepad-xbox1-buttona-normal",1,true))
            P:Close();assert(#HOST.actions==0 and #HOST.sent==0)
        ''')

    def test_shared_cancel_confirm_auto_icon_and_single_focus_restore(self):
        self.run_lua('''local P=W.IconPicker;local chosen,cancelled,restored=0,0,0
            local request={selectedIcon=999,onSelect=function(icon)chosen=icon end,onCancel=function()cancelled=cancelled+1 end,restoreFocus=function()restored=restored+1 end}
            assert(P:Open(request));P.index=1;P:Activate();assert(chosen==0)
            P:Close();P:Close();assert(chosen==0 and cancelled==1 and restored==1 and HOST.iconReleases==1)
            P:Open(request);P.index=1;P:Activate();P:Finish(true)
            assert(chosen==134400 and cancelled==1 and restored==2 and HOST.iconReleases==2)
            P:Open(request);P.owner:GetScript("OnEvent")();assert(cancelled==2 and restored==3)
            HOST.combat=true;assert(not P:Open(request) and not P.request)
            assert(#HOST.actions==0 and #HOST.sent==0)
        ''')

    def test_search_unicode_spell_and_texture_ids_filters_and_empty_results(self):
        self.run_lua('''local P=W.IconPicker;P:Open({selectedIcon=999});local f=P.frame;local search=f.BorderBox.IconSelectorEditBox
            search:SetText("ЛЕЧЕНИЕ");assert(f:GetNumIcons()==1 and f:GetIconByIndex(1)==135907)
            search:SetText("2061");assert(f:GetNumIcons()==1)
            search:SetText("UserArt");assert(f:GetNumIcons()==1 and type(f:GetIconByIndex(1))=="string")
            search:SetText("absent");assert(f:GetNumIcons()==0);P:Move("PADDUP");P:Move("PADDDOWN");P:Activate()
            search:SetText("");f:SetIconFilter(IconSelectorPopupFrameIconFilterTypes.Item);assert(f:GetNumIcons()==2)
            assert(f.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()==999)
            P:Close();W.RadialData=nil;assert(P:Open({}))
        ''')

    def test_long_grid_navigation_stale_confirm_and_owner_hide(self):
        self.run_lua('''for i=5,1000 do HOST.iconCatalog[i]=100000+i end
            local P=W.IconPicker;local owner=CreateFrame("Frame");local saved=0
            P:Open({owner=owner,onSelect=function()saved=saved+1 end});local f=P.frame
            local function down(t)f:GetScript("OnGamePadButtonDown")(f,t)end
            local function up(t)f:GetScript("OnGamePadButtonUp")(f,t)end
            down("PADDDOWN");up("PADDDOWN");assert(P.index==11 and f.IconSelector.scrolled==11)
            up(W.Input.keys.shift);assert(P.request and saved==0)
            down(W.Input.keys.shift);f.BorderBox.IconSelectorEditBox:SetText("100999");up(W.Input.keys.shift)
            assert(P.request and saved==0)
            P:Move("PADDUP");assert(P.zone=="search");P:Move("PADDRIGHT");assert(P.zone=="filter")
            P:Activate();assert(f.iconFilter==IconSelectorPopupFrameIconFilterTypes.Spell)
            owner:Hide();P.owner:GetScript("OnUpdate")();assert(not P.request and saved==0)
        ''')
