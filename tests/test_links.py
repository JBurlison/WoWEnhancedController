"""Native-link identity, owner/selection, tooltip and controller contracts."""
from pathlib import Path
import unittest
import test_radial as fixture

class LinkTests(unittest.TestCase):
    def setUp(self):
        self.env=fixture.RadialTests();self.env.load_addon()
        self.env.run_lua('''
            Constants=Constants or {};Constants.InventoryConstants={NumBagSlots=4,NumReagentBagSlots=1}
            INVSLOT_FIRST_EQUIPPED=1;INVSLOT_LAST_EQUIPPED=19
            HOST.bag={};HOST.equipped={};HOST.recipeOwner=171
            local function link(id,name)return "|cffffffff|Hitem:"..id..":0:0:0|h["..name.."]|h|r"end
            HOST.link=link
            for i=1,7 do HOST.bag[i]={link=link(i,"Item "..i),guid="bag"..i,icon=100+i,count=i}end
            C_Container={GetContainerNumSlots=function(b)return b==0 and #HOST.bag or 0 end,
                GetContainerItemLink=function(b,s)return b==0 and HOST.bag[s] and HOST.bag[s].link end,
                GetContainerItemInfo=function(b,s)local i=b==0 and HOST.bag[s];return i and {iconFileID=i.icon,stackCount=i.count}end}
            ItemLocation={CreateFromBagAndSlot=function(_,b,s)return {bag=b,slot=s}end,
                CreateFromEquipmentSlot=function(_,s)return {slot=s}end}
            C_Item={GetItemGUID=function(loc)local i=loc.bag and HOST.bag[loc.slot]or HOST.equipped[loc.slot];return i and i.guid end}
            GetInventoryItemLink=function(_,s)return HOST.equipped[s]and HOST.equipped[s].link end
            GetInventoryItemTexture=function(_,s)return HOST.equipped[s]and HOST.equipped[s].icon end
            HOST.equipped[16]={link=link(99,"Equipped mace"),guid="equip99",icon=999}
            GetProfessions=function()return nil,nil,3,nil,nil,6 end
            GetProfessionInfo=function(i)if i==3 then return "Cooking",300,75,75,1,100 elseif i==6 then return "Fishing",600,75,75,1,200 end end
            Enum.SpellBookSpellBank={Player=0}
            C_SpellBook={GetSpellBookItemTradeSkillLink=function(s)return "|Htrade:"..s.."|h[Profession "..s.."]|h"end}
            ProfessionsFrame=CreateFrame("Frame",nil,UIParent)
            C_TradeSkillUI={GetBaseProfessionInfo=function()return {professionID=HOST.recipeOwner}end,
                GetAllRecipeIDs=function()return {1,2}end,
                GetRecipeInfo=function(id)return {name="Recipe "..id,learned=id==1,icon=888}end,
                GetRecipeLink=function(id)return "|Henchant:"..id.."|h[Recipe "..id.."]|h"end}
            GameTooltip=CreateFrame("Frame",nil,UIParent);GameTooltip:Hide()
            function GameTooltip:SetOwner(owner)self.owner=owner end
            function GameTooltip:GetOwner()return self.owner end
            function GameTooltip:SetBagItem(b,s)HOST.tip={"bag",b,s}end
            function GameTooltip:SetInventoryItem(u,s)HOST.tip={"equipped",u,s}end
            function GameTooltip:SetSpellBookItem(s,b)HOST.tip={"profession",s,b}end
            function GameTooltip:SetHyperlink(l)HOST.tip={"link",l}end
            -- Native MinimalScrollBar callback contract, not its rendering or drag engine.
            ScrollBarMixin={Event={OnScroll="OnScroll"}}
            local create=CreateFrame
            CreateFrame=function(kind,name,parent,template)
                local f=create(kind,name,parent,template)
                if template=="MinimalScrollBar"then
                    f.Back=create("Button",nil,f);f.Forward=create("Button",nil,f)
                    f.Track=create("Frame",nil,f);f.Track.Thumb=create("Button",nil,f.Track)
                    function f:Init(v,p)self.visibleExtent=v;self.panExtent=p;self.percentage=0 end
                    function f:SetVisibleExtentPercentage(v)self.visibleExtent=v end
                    function f:SetPanExtentPercentage(p)self.panExtent=p end
                    function f:RegisterCallback(event,fn,owner)self.callback=fn;self.callbackOwner=owner end
                    function f:SetScrollPercentage(p)self.percentage=p;if self.callback then self.callback(self.callbackOwner,p)end end
                    function f:UnregisterUpdate()self.cancelled=true end
                end
                return f
            end
            local box=HOST.Field("ChatFrame1EditBox","before selected after");box:SetAttribute("chatType","PARTY")
            HOST.chat=box;W.Keyboard:Open(box)
            W.Keyboard.editor:Select(7,15);W.Keyboard:Sync()
        ''')
    def run_lua(self,s):self.env.run_lua(s)

    def quest_log(self):
        self.run_lua('''
            HOST.tracked=11; HOST.count=2
            local rows={{isHeader=true},{questID=12},{questID=11},{questID=13,isHidden=true}}
            C_QuestLog={GetNumQuestLogEntries=function()return #rows,3 end,GetInfo=function(i)return rows[i] end,
                GetLogIndexForQuestID=function(id)for i,r in ipairs(rows) do if r.questID==id then return i end end end}
            C_SuperTrack={GetSuperTrackedQuestID=function()return HOST.tracked end}
            function GetQuestLink(id)return "|cffffff00|Hquest:"..id..":1|h[Quest "..id.."]|h|r" end
            function GetNumQuestLeaderBoards(index)return index==3 and 2 or 0 end
            function GetQuestLogLeaderBoard(i,index)
                assert(index==3)
                if i==1 then return "Scout the road","event",true end
                return "Wolf pelts: "..HOST.count.."/6","item",HOST.count==6
            end
        ''')

    def test_quest_and_objective_rows_insert_native_link_and_live_progress(self):
        self.quest_log()
        self.run_lua('''
            local k,l=W.Keyboard,W.Links;l:Open(k)
            for i=2,5 do k.rows[1][1].run() end
            local entries=k.linking.entries
            assert(#entries==4 and entries[1].id==11 and entries[2].kind=="objective" and entries[4].id==12)
            k:Select(4,1);HOST.count=4;HOST.Press("PAD1")
            assert(HOST.chat:GetText()=="before "..GetQuestLink(11).." after" and #HOST.sent==0)
            HOST.count=5;k:Action("confirm")
            assert(#HOST.sent==2 and HOST.sent[1][1]=="before "..GetQuestLink(11).." after")
            assert(HOST.sent[2][1]=="5/6 Wolf pelts" and HOST.sent[2][2]=="PARTY")
        ''')

    def test_title_old_saved_links_and_physical_enter_use_the_live_tracker_lines(self):
        self.quest_log()
        self.run_lua('''
            local k,l,box=W.Keyboard,W.Links,HOST.chat
            GetQuestLogLeaderBoard=function(i)
                if i==1 then return "0/10 Red Silk Bandana","item",false end
                return "", "item", false
            end
            C_QuestLog.GetQuestObjectives=function()return {{},{text="Crate",numRequired=3,numFulfilled=2}} end
            local link=GetQuestLink(11)
            W.Phrases.Save("chat",1,"Old saved quest",nil,{kind="link",link=link},{chatType="GUILD"})
            k:UsePhrase(1)
            assert(#HOST.sent==3 and HOST.sent[1][1]==link and HOST.sent[2][1]=="0/10 Red Silk Bandana" and HOST.sent[3][1]=="2/3 Crate")
            for _,line in ipairs(HOST.sent) do assert(line[2]=="GUILD") end
            function hooksecurefunc(target,key,after)
                local before=target[key];target[key]=function(...)before(...);after(...)end
            end
            function box:SendText()C_ChatInfo.SendChatMessage(self:GetText(),"PARTY")end
            box:SetScript("OnEnterPressed",function(b)
                if HOST.autocomplete then return end
                b:SendText(1);b:SetText("")
            end)
            l:Open(k);k.linking.source=5;k:Draw();l:Insert(k,k.linking.entries[1])
            HOST.autocomplete=true;box:GetScript("OnEnterPressed")(box);assert(#HOST.sent==3)
            HOST.autocomplete=false;box:GetScript("OnEnterPressed")(box)
            assert(#HOST.sent==6 and HOST.sent[5][1]=="0/10 Red Silk Bandana" and HOST.sent[6][2]=="PARTY")
            l:Open(k);k.linking.source=5;k:Draw();l:Insert(k,k.linking.entries[1])
            box:SetText("unrelated");box:GetScript("OnEnterPressed")(box);assert(#HOST.sent==7)
        ''')

    def test_assign_item_in_standalone_settings_then_send_it_after_bag_changes(self):
        self.run_lua('''
            local k=W.Keyboard;k:Close();k:ShowQuickMessages();k:UsePhrase(2)
            local function button(text)
                for _,row in ipairs(k.rows) do for _,b in ipairs(row) do if b:GetText()==text then return b end end end
            end
            button("Link in chat").run()
            assert(k.linking and W.Links:Eligible(k));HOST.Press("PAD2");assert(k.composing and not k.linking)
            button("Link in chat").run();HOST.Press("PAD1")
            assert(k.composing and not k.linking and #HOST.sent==0);HOST.Press("PADRTRIGGER")
            local link=HOST.bag[1].link;HOST.bag[1]=HOST.bag[2];k:Close();k:Open(HOST.chat)
            k.editor:Select(2,4);k:Sync();k:UsePhrase(2)
            assert(#HOST.sent==1 and HOST.sent[1][1]==link and HOST.sent[1][2]=="PARTY")
            assert(HOST.chat:GetText()=="before selected after" and k.editor.anchor==2 and k.editor.cursor==4)
        ''')

    def test_tracked_shortcut_resolves_each_press_and_fixed_objective_keeps_identity(self):
        self.quest_log()
        self.run_lua('''
            local k=W.Keyboard;k:ToggleAssign();k:UsePhrase(1)
            for _,row in ipairs(k.rows) do for _,b in ipairs(row) do
                if b:GetText()=="Current tracked quest" then b.run() end
            end end
            k:Action("confirm");k:UsePhrase(2);W.Links:Open(k,true);k.linking.source=5;k:Draw()
            k:Select(4,1);HOST.Press("PAD1");k:Action("confirm");k:ToggleAssign()
            k:UsePhrase(1);assert(HOST.sent[1][1]==GetQuestLink(11) and HOST.sent[2][1]=="2/6 Wolf pelts")
            HOST.tracked=12;k:UsePhrase(1);assert(HOST.sent[3][1]==GetQuestLink(12))
            HOST.count=6;k:UsePhrase(2);assert(HOST.sent[4][1]==GetQuestLink(11) and HOST.sent[5][1]=="6/6 Wolf pelts")
            HOST.tracked=0;k:UsePhrase(1);assert(#HOST.sent==5 and k.lastStatus=="No quest is actively tracked.")
            C_QuestLog.GetLogIndexForQuestID=function()end;k:UsePhrase(2);assert(#HOST.sent==5)
            assert(HOST.chat:GetText()=="before selected after")
        ''')

    def test_original_selection_raw_link_insert_then_undo_without_sending(self):
        self.run_lua('''
            local k=W.Keyboard;W.Links:Open(k);assert(k.linking and not k.quickVisible and #k.linking.entries==7)
            assert(HOST.tip[1]=="bag" and HOST.tip[2]==0 and HOST.tip[3]==1)
            assert(HOST.chat:GetText()=="before selected after")
            k:Action("confirm");k:Action("space");assert(k.linking and #HOST.sent==0)
            HOST.Press("PAD1");assert(not k.linking and k.view=="keys" and HOST.chat:HasFocus())
            assert(HOST.chat:GetText()=="before "..HOST.bag[1].link.." after" and #HOST.sent==0 and not GameTooltip:IsShown())
            k:Action("undo");assert(HOST.chat:GetText()=="before selected after")
        ''')

    def test_cancel_hides_tooltip_restores_caret_and_does_not_pin_new_bind(self):
        self.run_lua('''
            local k=W.Keyboard;local cursor,anchor=k.editor.cursor,k.editor.anchor;W.Links:Open(k)
            assert(GameTooltip:IsShown());HOST.Press("PAD2")
            assert(not k.linking and not GameTooltip:IsShown() and k.editor.cursor==cursor and k.editor.anchor==anchor)
            assert(HOST.chat:GetText()=="before selected after" and W.db.actionBindings==nil)
        ''')

    def test_moved_identical_guid_changed_item_and_stale_chat_are_rejected(self):
        self.run_lua('''
            local k=W.Keyboard;W.Links:Open(k);local entry=k.linking.entries[1]
            HOST.bag[1].guid="replacement";W.Links:Insert(k,entry)
            assert(k.linking and HOST.chat:GetText()=="before selected after")
            entry=k.linking.entries[1];HOST.bag[1].link=HOST.link(50,"Changed")
            W.Links:Insert(k,entry);assert(HOST.chat:GetText()=="before selected after")
            entry=k.linking.entries[1];HOST.chat:SetText("physical typing")
            W.Links:Insert(k,entry);assert(not k.linking and HOST.chat:GetText()=="physical typing")
        ''')

    def test_controller_scrolls_all_entries_and_modifiers_do_not_edit_or_send(self):
        self.run_lua('''
            local k=W.Keyboard;W.Links:Open(k);local seen={}
            for i=1,12 do if k.focused.linkIndex then seen[k.focused.linkIndex]=true end;k:Move(0,1)end
            for i=1,7 do assert(seen[i])end
            k:Select(2,1)
            for _,token in ipairs({"PADLSHOULDER","PADRSHOULDER","PADLTRIGGER","PADRTRIGGER","PADLSTICK","PADRSTICK","PAD3","PAD4","PADFORWARD"})do HOST.Press(token)end
            assert(k.linking and HOST.chat:GetText()=="before selected after" and #HOST.sent==0 and not k.assigning)
            W.Links:Scroll(k,0);k:Select(5,1);k:Move(0,1)
            assert(k.linking.offset==1 and k.focused.linkEntry.slot==5 and k.rows[2][1].linkEntry.slot==2)
            k:Move(0,-1);k:Move(0,-1);k:Move(0,-1);k:Move(0,-1)
            assert(k.linking.offset==0 and k.focused.linkEntry.slot==1)
            for _,row in ipairs(k.rows)do for _,b in ipairs(row)do assert(b:GetText()~="Previous"and b:GetText()~="Next")end end
            W.Links:Close(k);for _,b in ipairs(k.pool)do if b:IsShown()then assert(not b.linkEntry and (not b.linkIcon or not b.linkIcon:IsShown()))end end
        ''')

    def test_native_scrollbar_drag_wheel_bounds_and_shrinking_list(self):
        self.run_lua('''
            local k,l=W.Keyboard,W.Links;l:Open(k);local bar=l.scrollBar
            assert(bar:IsShown()and bar.visibleExtent==4/7 and bar.panExtent==1/3)
            bar:SetScrollPercentage(1);assert(k.linking.offset==3 and k.rows[2][1].linkEntry.slot==4)
            assert(k.mouseEditing==nil)
            local row=k.rows[2][1];row:GetScript("OnMouseWheel")(row,1)
            assert(k.linking.offset==2 and k.rows[2][1].linkEntry.slot==3)
            l:Scroll(k,-100);assert(k.linking.offset==0);l:Scroll(k,100);assert(k.linking.offset==3)
            HOST.bag[7]=nil;HOST.bag[6]=nil;HOST.bag[5]=nil;HOST.bag[4]=nil
            l:OnEvent("BAG_UPDATE_DELAYED");l:Tick(k)
            assert(k.linking.offset==0 and not bar:IsShown())
            l:Close(k);assert(not bar:IsShown()and bar.cancelled)
        ''')

    def test_scroll_invalidates_held_select_and_never_reclaims_foreign_focus(self):
        self.run_lua('''
            local k,l=W.Keyboard,W.Links;l:Open(k);W.Input.waitNeutral=false;W.Input:Down("PAD1")
            l.scrollBar:SetScrollPercentage(1);W.Input:Up("PAD1")
            assert(k.linking and HOST.chat:GetText()=="before selected after")
            HOST.chat:ClearFocus();l.scrollBar.Track:GetScript("OnMouseDown")(l.scrollBar.Track)
            assert(HOST.chat:HasFocus());l.scrollBar.Track:GetScript("OnMouseUp")(l.scrollBar.Track)
            assert(k.mouseEditing==nil)
            local foreign=HOST.Field("Other","foreign");foreign:SetFocus();local offset=k.linking.offset
            l.scrollBar:SetScrollPercentage(0)
            assert(foreign:HasFocus()and k.linking.offset==offset and foreign:GetText()=="foreign")
        ''')

    def test_foreign_owner_hidden_combat_and_foreign_tooltip_ownership(self):
        self.run_lua('''
            local k=W.Keyboard;W.Links:Open(k);local entry=k.linking.entries[1]
            local other=HOST.Field("OtherSearch","other");other:SetFocus();W.Links:Insert(k,entry);W.Links:Tick(k)
            assert(HOST.chat:GetText()=="before selected after" and other:GetText()=="other" and not GameTooltip:IsShown())
            k:Open(HOST.chat);W.Links:Open(k);local foreign=CreateFrame("Button",nil,UIParent)
            GameTooltip:SetOwner(foreign);GameTooltip:Show();W.Links:Tick(k);W.Links:HideTooltip();assert(GameTooltip:IsShown() and GameTooltip:GetOwner()==foreign)
            k:Close();k:Open(HOST.chat);W.Links:Open(k)
            W.events:GetScript("OnEvent")(W.events,"PLAYER_REGEN_DISABLED");assert(not k.linking and not GameTooltip:IsShown())
        ''')

    def test_native_equipped_profession_holes_and_current_learned_recipes(self):
        self.run_lua('''
            local l,k=W.Links,W.Keyboard;local e=l:Collect("Equipped");assert(#e==1 and e[1].slot==16 and l:Current(e[1]))
            l:Open(k);k.linking.source=2;k:Draw();assert(HOST.tip[1]=="equipped")
            local p=l:Collect("Professions");assert(#p==2 and p[1].name=="Cooking" and p[2].slot==201)
            k.linking.source=3;k:Draw();assert(HOST.tip[1]=="profession" and HOST.tip[2]==101)
            local recipes=l:Collect("Recipes");assert(#recipes==1 and recipes[1].id==1 and l:Current(recipes[1]))
            k.linking.source=4;k:Draw();assert(HOST.tip[1]=="link" and HOST.tip[2]==recipes[1].link)
            HOST.recipeOwner=164;assert(not l:Current(recipes[1]))
            ProfessionsFrame:Hide();assert(#l:Collect("Recipes")==0)
        ''')

    def test_events_refresh_pairing_empty_data_and_non_chat_restrictions(self):
        self.run_lua('''
            local k=W.Keyboard;W.Links:Open(k);W.Input.waitNeutral=false;W.Input:Down("PAD1")
            HOST.bag={};W.events:GetScript("OnEvent")(W.events,"BAG_UPDATE_DELAYED");W.Links:Tick(k);W.Input:Up("PAD1")
            assert(k.linking and #k.linking.entries==0 and HOST.chat:GetText()=="before selected after")
            k:Close();k:Open(HOST.Field("SearchBox","query"));W.Links:Open(k);assert(not k.linking)
            k:Open(HOST.chat);k:ToggleAssign();W.Links:Open(k);assert(not k.linking)
            k:UsePhrase(1);W.Links:Open(k);assert(not k.linking)
        ''')

    def test_mouse_down_then_inventory_redraw_cannot_insert_recycled_row(self):
        self.run_lua('''
            local k=W.Keyboard;W.Links:Open(k);W.Input.padAt=-10
            local row=k.rows[2][1];row:GetScript("OnMouseDown")(row)
            HOST.bag[1]={link=HOST.link(500,"Replacement"),guid="new",icon=500,count=1}
            W.Links:OnEvent("BAG_UPDATE_DELAYED");W.Links:Tick(k)
            row:GetScript("OnMouseUp")(row);row.action(row)
            assert(k.linking and HOST.chat:GetText()=="before selected after")
            row=k.rows[2][1];row:GetScript("OnMouseDown")(row);row:GetScript("OnMouseUp")(row);row.action(row)
            assert(not k.linking and HOST.chat:GetText()=="before "..HOST.bag[1].link.." after")
        ''')

if __name__=='__main__':unittest.main()
