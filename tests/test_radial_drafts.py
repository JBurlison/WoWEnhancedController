"""Batch settings transactions and rank dispatch, independent of client hardware."""
import unittest
import test_radial_editor as fixture

class RadialDraftTests(unittest.TestCase):
    def setUp(self):
        self.env = fixture.RadialEditorTests()
        self.env.setUp()
    def run_lua(self, code): self.env.run_lua(code)

    def test_multiple_assignments_pages_reopen_and_one_atomic_save(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;D.Profile().actions={};R:Rebuild();R:Edit()
            local rebuild=R.Rebuild;local calls=0;R.Rebuild=function(self)calls=calls+1;return rebuild(self)end
            R:ChooseEditorItem({kind="spell",value="139",label="Renew",detail=""})
            R.addAction.run();R:ChooseEditorItem({kind="spell",value="17",label="Shield",detail=""})
            R.addPage.run();assert(R.editorPage==-1)
            R:ChooseEditorItem({kind="spell",value="2061",label="Heal",detail=""})
            R:EditorPage(0);assert(R.editorPreview.cells[1].index==1 and R.editorPreview.cells[2].index==2)
            R:CloseEditor();R:Edit();R:EditorCell(2);assert(R:EditorDraft().value=="17")
            assert(#D.Profile().actions==0 and #D.Profile().pages==1 and calls==0)
            assert(R:SaveEditor());assert(calls==1 and #D.Profile().actions==3 and #D.Profile().pages==2)
            assert(D.Profile().actions[3].page==-1 and #HOST.actions==0)
        ''')

    def test_invalid_draft_and_combat_never_partially_commit(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;R:Edit();local old=D.Profile().actions[1].label
            R.labelInput:SetText("Pending rename");R:EditorCell(4);R.editorTabs[3].run()
            R.labelInput:SetText("Bad command");R.valueInput:SetText("/run print(1)")
            R:CloseEditor();R:Edit();assert(not R:SaveEditor())
            assert(D.Profile().actions[1].label==old and #D.Profile().actions==3)
            R:EditorCell(4);assert(R:EditorDraft().label=="Bad command")
            R.valueInput:SetText("/cast [@{unit}] Renew")
            HOST.combat=true;assert(not R:SaveEditor());assert(#D.Profile().actions==3)
            HOST.combat=false;assert(R:SaveEditor());assert(#D.Profile().actions==4 and D.Profile().actions[1].label=="Pending rename")
        ''')

    def test_remove_reorder_and_pages_remain_pending(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;R:Edit();local original=D.Profile().actions[1].value
            local function button(text)for _,b in ipairs(R.editorControls)do if b.GetText and b:GetText()==text then return b end end end
            button("Move right").run();assert(R:EditorProfile().actions[1].slot==2 and D.Profile().actions[1].slot==1)
            R:EditorCell(3);button("Remove").run();assert(#R:EditorProfile().actions==2 and #D.Profile().actions==3)
            R.addPage.run();R.removePage.run();assert(#R:EditorProfile().pages==1)
            assert(R:SaveEditor());assert(#D.Profile().actions==2 and D.Profile().actions[1].value==original and D.Profile().actions[1].slot==2)
        ''')

    def test_drafts_are_isolated_by_specialization(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;R:Edit();R.labelInput:SetText("Spec one")
            HOST.spec=2;assert(not R:SaveEditor());R:CloseEditor();R:Edit();assert(R:EditorDraft().label~="Spec one")
            R.labelInput:SetText("Spec two");R:CloseEditor();HOST.spec=1;R:Edit();assert(R:EditorDraft().label=="Spec one")
            assert(R:SaveEditor());HOST.spec=2;R:CloseEditor();R:Edit();assert(R:EditorDraft().label=="Spec two")
        ''')

    def test_rank_checkbox_uses_localized_name_and_preserves_pinned_rank(self):
        self.run_lua('''
            local R,D=W.Radial,W.RadialData;R:Edit();R:ChooseEditorItem({kind="spell",value="139",label="Renew",detail=""})
            assert(not R.highestRank:GetChecked() and select(2,D.Compile(R:EditorDraft(),"player"))==139)
            for i,b in ipairs(R.editorControls)do if b==R.highestRank then R.editorSelected=i end end
            local f=R.editor;f:GetScript("OnGamePadButtonDown")(f,W.Input.keys.primary);f:GetScript("OnGamePadButtonUp")(f,W.Input.keys.primary)
            assert(R.highestRank:GetChecked() and R:EditorDraft().highestRank)
            assert(select(2,D.Compile(R:EditorDraft(),"player"))=="Renew")
            assert(R:SaveEditor());assert(D.Profile().actions[1].value=="139" and D.Profile().actions[1].highestRank)
            HOST.now=HOST.now+1;R.highestRank:GetScript("OnClick")();assert(not R:EditorDraft().highestRank)
            HOST.combat=true;R.highestRank:SetChecked(true);R.highestRank:GetScript("OnClick")();assert(not R.highestRank:GetChecked())
            HOST.combat=false;R.editorTabs[2].run();assert(not R.highestRank:IsShown() and not R:EditorDraft().highestRank)
        ''')

    def test_newly_learned_rank_updates_metadata_without_changing_saved_id(self):
        self.run_lua('''
            local D=W.RadialData;local original=C_Spell.GetSpellInfo;local learned=139
            C_Spell.GetSpellInfo=function(v)if v=="Renew" then return {name="Renew",spellID=learned,iconID=135953}end;return original(v)end
            local a={kind="spell",label="Renew",value="139",highestRank=true}
            assert(D.SpellInfo(a).spellID==139);learned=6074
            assert(D.SpellInfo(a).spellID==6074 and select(2,D.Compile(a,"player"))=="Renew" and a.value=="139")
            a.highestRank=nil;assert(D.SpellInfo(a).spellID==139 and select(2,D.Compile(a,"player"))==139)
            local p=W.Copy(D.Profile());p.actions[2].slot=p.actions[1].slot
            assert(not D.SaveProfile(p));assert(D.Profile().actions[2].slot==2)
        ''')

if __name__ == '__main__': unittest.main()
