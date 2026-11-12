"""Page migration and secure action routing; no client-security claim."""
import unittest
import test_radial as fixture

class RadialPagesTests(unittest.TestCase):
    def setUp(self):
        self.env=fixture.RadialTests();self.env.load_addon()
    def run_lua(self,code):self.env.run_lua(code)

    def test_migration_preserves_all_legacy_actions_and_center_page_order(self):
        self.run_lua('''local D=W.RadialData;local p=D.Profile();p.pages=nil;p.actions={}
            for i=1,28 do p.actions[i]={kind="custom",label="User"..i,value="/cast [@{unit}] Renew",icon=1000+i} end
            D.Profile();assert(#p.actions==28 and #p.pages==4)
            for i,a in ipairs(p.actions)do assert(a.label=="User"..i and a.icon==1000+i and a.slot==(i-1)%8+1)end
            assert(p.actions[1].page==0 and p.actions[9].page==-1 and p.actions[17].page==1 and p.actions[25].page==-2)
            assert(D.AddPage()==2);assert(D.AddPage()==-3);assert(D.AddPage()==3)
            assert(not D.RemovePage(0) and not D.RemovePage(-1));assert(D.RemovePage(3));assert(D.AddPage()==3)
            assert(D.AddPage()==-4 and D.AddPage()==4 and D.AddPage()==nil)
            D.Init();assert(#D.Profile().actions==28 and #D.Profile().pages==9)
        ''')

    def test_eight_slots_no_cross_page_duplicate_or_stale_confirm(self):
        self.run_lua('''local R,D=W.Radial,W.RadialData;assert(D.AddPage()==-1)
            assert(D.Save(4,{kind="spell",label="Left heal",value="139",page=-1,slot=8}))
            assert(not D.Save(5,{kind="spell",label="Duplicate",value="139",page=-1,slot=8}))
            HOST.WheelPress("Toggle");HOST.WheelPress("LeftButton",1)
            local b=R.dispatch;b:GetScript("OnClick")(b,"ConfirmTrigger",true)
            R.frame:RunAttribute("op-stage","spells",1,1,-1)
            b:GetScript("OnClick")(b,"ConfirmTrigger",false);assert(#HOST.actions==0)
            HOST.WheelPress("LeftButton",1);assert(#HOST.actions==0 and R.frame:IsShown())
            HOST.WheelPress("LeftButton",8);assert(#HOST.actions==1 and HOST.actions[1].spell==139)
            HOST.WheelPress("LeftButton",1);assert(R.frame:GetAttribute("page")==0 and R.frame:GetAttribute("stage")=="spells")
        ''')

    def test_optional_presets_icons_and_whisper_compose_guard(self):
        self.run_lua('''local D,R=W.RadialData,W.Radial;local presets=D.Presets();assert(#presets==5)
            for _,a in ipairs(presets)do assert(D.Validate(a));local kind,value,icon=D.Compile(a,"party1");assert(icon)
                if a.value=="target" or a.value=="focus" then assert(kind==a.value and value=="party1")
                elseif a.value=="trade" then assert(value=="/target [@party1]\\n/trade")
                elseif a.value=="duel" then assert(value=="/duel party1")
                else assert(kind=="whisper" and value=="party1")end
            end
            local a={kind="custom",label="User",value="/cast [@{unit}] Renew",icon="Interface/Icons/Custom"}
            assert(select(3,D.Compile(a,"player"))==a.icon)
            assert(not D.Validate({kind="friendly",label="Bad",value="run"}))
            local calls=0;local box=HOST.Field("WhisperDraft","")
            ChatFrameUtil={ChooseBoxForSend=function()return box end,SendTell=function(name)calls=calls+1;assert(name=="Elowen")end}
            R:Whisper("party1");assert(calls==1 and #HOST.sent==0)
            box:SetText("Keep draft");R:Whisper("party1");assert(calls==1)
            box:SetText("");HOST.combat=true;R:Whisper("party1");assert(calls==1)
        ''')

    def test_empty_slot_drafts_survive_page_navigation_without_save(self):
        self.run_lua('''local R,D=W.Radial,W.RadialData;R:Edit();R:EditorCell(4)
            R:ChooseEditorItem({kind="spell",label="Draft",value="139",detail=""})
            R.addPage.run();R:EditorPage(0);R:EditorCell(4)
            assert(R:EditorDraft().label=="Draft" and #D.Profile().actions==3)
            R.saveAction.run();assert(#D.Profile().actions==4 and D.Profile().actions[4].slot==4)
            R:EditorCell(8);R:ChooseEditorItem({kind="friendly",label="Focus",value="focus",icon=123,detail=""})
            R.saveAction.run();assert(D.PageSlots(0)[8]==5 and R:EditorDraft().icon==123)
        ''')
