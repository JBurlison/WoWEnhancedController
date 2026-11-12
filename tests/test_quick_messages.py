"""Combo assignment and native Settings ownership; simulated callbacks, not hardware."""
import unittest
import test_radial as fixture

class QuickMessageTests(unittest.TestCase):
    def setUp(self):
        self.env=fixture.RadialTests();self.env.load_addon(settings_model=True)
    def run_lua(self,code):self.env.run_lua(code)

    def test_icon_only_banks_and_recycled_labels_do_not_require_implicit_fontstrings(self):
        self.run_lua('''
            local bare=CreateFrame("Button",nil,UIParent)
            bare:SetNormalFontObject(GameFontNormal);bare:SetText("")
            assert(bare:GetFontString()==nil)
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","kept");k:Open(box)
            for _,skin in ipairs({"minimal","classic","gold"})do
                W.db.keyboardAppearance.buttons=skin;k:Draw()
                for _,b in ipairs(k.quickBankButtons)do
                    assert(b:GetText()==""and b:GetFontString()and b.prompt.icons[1]:IsShown())
                end
            end
            local b=k.quickBankButtons[1];b.label=nil
            W.Theme.Prompt(b,b.basePrompt,"bank")
            local label=b:GetFontString();assert(label)
            b:SetText("-");assert(b:GetFontString()==label and label:GetText()=="-")
            W.Theme.Prompt(b,{},"bank");assert(not b.prompt.icons[1]:IsShown())
            k:Draw();assert(box:GetText()=="kept"and #HOST.sent==0)
        ''')

    def test_assign_combo_is_paired_contextual_and_never_sends_original_draft(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","original");box:SetAttribute("chatType","PARTY");k:Open(box)
            HOST.Press("PADFORWARD");assert(k.assigning)
            HOST.Press("PADRTRIGGER");assert(#HOST.sent==0 and box:GetText()=="original")
            local f=k.frame;W.Input.waitNeutral=false
            f:GetScript("OnGamePadButtonDown")(f,"PADLTRIGGER")
            f:GetScript("OnGamePadButtonDown")(f,"PAD1")
            f:GetScript("OnGamePadButtonUp")(f,"PADLTRIGGER")
            assert(not k.composing)
            f:GetScript("OnGamePadButtonUp")(f,"PAD1");assert(k.composing and k.composing.slot==1)
            k:Action("clear");k:Insert("Invite 用户!");HOST.Press("PADRTRIGGER")
            assert(k.assigning and not k.composing and box:GetText()=="original" and #HOST.sent==0)
            assert(W.db.phrases["chat:PARTY"][1].text=="Invite 用户!")
            assert(not W.db.bindings["chat:PARTY"]) -- Editing words retains shortcut inheritance.
            HOST.Press("PADFORWARD");W.Input.waitNeutral=false
            f:GetScript("OnGamePadButtonDown")(f,"PADLTRIGGER");HOST.Press("PAD1")
            f:GetScript("OnGamePadButtonUp")(f,"PADLTRIGGER")
            assert(box:GetText()=="original" and #HOST.sent==1 and HOST.sent[1][1]=="Invite 用户!" and HOST.sent[1][2]=="PARTY")
            box:SetAttribute("chatType","RAID");W.NativeField.Read(k,false,true);k:Draw()
            assert(k.quickButtons[1]:GetText()=="Ready!")
        ''')

    def test_cancel_assignment_keeps_messages_bindings_focus_and_original_selection(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("SearchBox","keep");k:Open(box)
            k.editor:Select(1,3);k:Sync();k:ToggleAssign();k:UsePhrase(1)
            k:Action("clear");k:Insert("discard");k:CycleQuickBinding();k:Action("back")
            assert(not k.composing and k.assigning and box:HasFocus() and box:GetText()=="keep")
            assert(not W.db.phrases[k:Context().key] and not W.db.bindings[k:Context().key])
            assert(k.editor.anchor==1 and k.editor.cursor==3)
            k:Action("back");assert(not k.assigning and k.frame:IsShown())
            k:Action("back");assert(not k.frame:IsShown())
        ''')

    def test_quick_send_uses_active_whisper_target_and_refuses_stale_destinations(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","/p unfinished")
            box:SetAttribute("chatType","WHISPER");box:SetAttribute("tellTarget","Lena")
            k:Open(box);box.languageID=7;k:UsePhrase(1)
            assert(#HOST.sent==1 and HOST.sent[1][2]=="WHISPER" and HOST.sent[1][3]==7 and HOST.sent[1][4]=="Lena")
            assert(box:GetText()=="/p unfinished" and #HOST.nativeEnters==0)
            box:SetAttribute("tellTarget","Other");k:UsePhrase(1);assert(#HOST.sent==1)
            box:SetAttribute("chatType","BN_WHISPER");W.NativeField.Read(k,false,true)
            BNet_GetBNetIDAccount=function(name)if name=="Other" then return 37 end end
            C_BattleNet={SendWhisper=function(id,text)HOST.bn={id,text}end}
            k:UsePhrase(1);assert(HOST.bn[1]==37 and HOST.bn[2]~=box:GetText() and #HOST.sent==1)
            box:SetAttribute("chatType","PARTY");W.NativeField.Read(k,false,true)
            W.Phrases.Save("chat:PARTY",1,string.rep("中",100))
            k:UsePhrase(1);assert(#HOST.sent==1 and k.lastStatus=="This message exceeds the chat length limit.")
        ''')

    def test_assignment_focus_channel_picker_and_shortcut_destination(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","keep this party draft")
            box:SetAttribute("chatType","PARTY");k:Open(box)
            local function button(label)
                for _,row in ipairs(k.rows)do for _,b in ipairs(row)do if b:GetText()==label then return b end end end
            end
            local wide=k.frame:GetWidth()
            button("Channel: Party").run();button("Guild").run();assert(k:Context().chatType=="GUILD")
            button("Channel: Guild").run();HOST.Press("PAD2");assert(k.session and not k.channels and k:Context().chatType=="GUILD")
            button("Channel: Guild").run();button("Party").run();assert(box:GetText()=="keep this party draft")
            k:ToggleAssign()
            assert(k.frame:GetWidth()<wide and not button("q") and k.focused.messageSlot and k.focused.focus:IsShown())
            k:Action("primary");assert(not button("q") and box:HasFocus() and k.focused:GetText()=="Hello!")
            button("Hello!").run();button("Send to: Current chat").run();button("Trade").run()
            assert(button("Send to: Trade") and box:GetAttribute("chatType")=="PARTY")
            button("Save").run();k:ToggleAssign();HOST.tradeID=6;k:UsePhrase(1)
            assert(#HOST.sent==1 and HOST.sent[1][1]=="Hello!" and HOST.sent[1][2]=="CHANNEL" and HOST.sent[1][4]=="6")
            HOST.tradeID=0;k:UsePhrase(1)
            assert(#HOST.sent==1 and k.lastStatus=="This chat channel is no longer joined." and box:GetText()=="keep this party draft")
        ''')

    def test_composer_mouse_buttons_preserve_owned_focus_and_never_reclaim_foreign_fields(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","kept");k:Open(box)
            k:ToggleAssign();k:UsePhrase(1)
            k:CustomMessage(true);local key=k.rows[1][1]
            k.input:ClearFocus();key:GetScript("OnMouseDown")(key)
            assert(k.input:HasFocus() and k.mouseEditing==key)
            k.input:ClearFocus();W.WatchFocus();assert(k.frame:IsShown())
            key:GetScript("OnMouseUp")(key);key.action(key)
            assert(k.input:HasFocus() and k.editor.text:sub(-1)=="q" and box:GetText()=="kept")
            local foreign=HOST.Field("OtherSearch","other");foreign:SetFocus()
            key:GetScript("OnMouseDown")(key);key.action(key)
            assert(foreign:GetText()=="other" and box:GetText()=="kept")
        ''')

    def test_pinned_whisper_uses_the_chosen_recipient_when_a_different_whisper_is_open(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","draft for Tess")
            box:SetAttribute("chatType","WHISPER");box:SetAttribute("tellTarget","Anna");k:Open(box)
            local function click(label)
                for _,row in ipairs(k.rows)do for _,b in ipairs(row)do if b:GetText()==label then b.run();return end end end
                error(label)
            end
            k:ToggleAssign();k:UsePhrase(1);click("Send to: Current chat");click("Whisper to Anna");click("Save");k:ToggleAssign()
            box:SetAttribute("tellTarget","Tess");W.NativeField.Read(k,false,true);k:UsePhrase(1)
            assert(HOST.sent[1][2]=="WHISPER" and HOST.sent[1][4]=="Anna" and box:GetAttribute("tellTarget")=="Tess")
            assert(box:GetText()=="draft for Tess")
        ''')

    def test_dpad_reaches_each_assignment_choice_at_large_font(self):
        self.run_lua('''
            local k=W.Keyboard; W.db.fontSize=20;k:ShowQuickMessages()
            local function reachable()
                local queue,seen={k.focused},{[k.focused]=true}
                for _,b in ipairs(queue) do
                    for _,dir in ipairs({{0,1},{0,-1},{1,0},{-1,0}}) do
                        k:Select(b.row,b.col);k:Move(unpack(dir))
                        if not seen[k.focused] then seen[k.focused]=true;table.insert(queue,k.focused) end
                    end
                end
                for _,row in ipairs(k.rows) do for _,b in ipairs(row) do assert(seen[b],b:GetText()) end end
            end
            reachable();k:UsePhrase(1);reachable();k:Action("channels");reachable()
        ''')

    def test_side_geometry_reachable_and_rectangles_do_not_overlap_at_tv_font(self):
        self.run_lua('''
            local k=W.Keyboard;W.db.fontSize=20;k:Open(HOST.Field("SearchBox",""))
            local controls={};for r,row in ipairs(k.rows)do for c,b in ipairs(row)do
                if b:IsEnabled() then controls[#controls+1]={r=r,c=c,b=b} end
                for _,other in ipairs(controls)do if other.b~=b then
                    local o=other.b
                    assert(math.abs(b.navX-o.navX)>=(b:GetWidth()+o:GetWidth())/2-.1
                        or math.abs(b.navY-o.navY)>=(b:GetHeight()+o:GetHeight())/2-.1)
                end end
            end end
            local queue,seen={{1,1}},{["1:1"]=true};local head=1
            while queue[head]do local at=queue[head];head=head+1
                for _,dir in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
                    k:Select(at[1],at[2]);k:Move(unpack(dir));local key=k.selectedRow..":"..k.selectedCol
                    if not seen[key]then seen[key]=true;queue[#queue+1]={k.selectedRow,k.selectedCol}end
                end
            end
            for _,control in ipairs(controls)do assert(seen[control.r..":"..control.c],control.b:GetText())end
        ''')

    def test_saved_scopes_bindings_remapped_physical_positions_and_unbound_modifier(self):
        self.run_lua('''
            W.db.phrases.global={[1]={text="User global"}};W.db.bindings["chat:PARTY"]={"back","primary","delete","unbound"}
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","");box:SetAttribute("chatType","PARTY");k:Open(box)
            assert(k.quickButtons[1]:GetText()=="User global" and k.quickButtons[1].navX>k.quickButtons[2].navX)
            W.db.style="Nintendo";W.Input:Refresh();k:Draw()
            assert(k.quickButtons[1].navX<k.quickButtons[2].navX)
            assert(k.quickButtons[2].prompt.icons[1].atlas==W.Input:Icon("primary"))
            W.db.actionBindings={phrases=""};W.Input:Refresh();k:Draw();assert(k.quickBankButtons[2]:GetText()=="-" and not k.quickBankButtons[2].prompt.icons[1].shown)
            assert(W.db.phrases.global[1].text=="User global" and W.db.bindings["chat:PARTY"][4]=="unbound")
        ''')

    def test_bumper_migration_preserves_custom_binds_and_existing_messages(self):
        self.run_lua('''
            W.db.schema=5;W.db.actionBindings={left="PADLSHOULDER",right="PADRSHOULDER",clear="PADLSTICK",symbols=""}
            W.db.phrases.global={[1]={text="Kept"}};W.db.bindings.global={"back","primary","delete","shift"}
            W.InitDB();W.Input:Refresh()
            assert(W.db.schema==6 and W.Input.keys.left=="" and W.Input.keys.right=="" and W.Input.keys.clear=="")
            assert(W.Input.keys.symbols=="PADLSTICK" and W.Input.keys.phrasesLeft=="PADLSHOULDER" and W.Input.keys.phrasesRight=="PADRSHOULDER")
            assert(W.Phrases.Resolve({key="global"},1)=="Kept" and W.Phrases.Bindings({key="global"})[1]=="back")
            W.db.schema=5;W.db.actionBindings={left="PAD5",right="PAD6",clear="PAD7",symbols="PAD8"}
            W.InitDB();W.Input:Refresh()
            assert(W.Input.keys.left=="PAD5" and W.Input.keys.right=="PAD6" and W.Input.keys.clear=="PAD7" and W.Input.keys.symbols=="PAD8")
        ''')

    def test_three_independent_banks_context_inheritance_and_numeric_fallback(self):
        self.run_lua('''
            local p=W.Phrases;local party={key="chat:PARTY",chat=true};local guild={key="chat:GUILD",chat=true}
            assert(p.Resolve(party,1,"phrasesLeft")=="" and not next(W.db.phraseBanks))
            for _,bank in ipairs(W.Input.modifiers)do
                for slot=1,4 do assert(p.Save("global",slot,bank..slot,bank))end
                assert(p.Save("chat",1,bank.." chat",bank));assert(p.Save(party.key,1,bank.." party",bank))
                assert(p.Resolve(party,1,bank)==bank.." party" and p.Resolve(guild,1,bank)==bank.." chat")
                assert(p.Resolve({key="auction:search"},2,bank)==bank..2)
                assert(p.Resolve({key="craft",numeric=true},2,bank)=="5")
            end
            assert(p.Bind(party.key,1,"unbound",party,"phrasesLeft"))
            assert(p.Bind(party.key,2,"primary",party,"phrasesLeft"))
            assert(p.Bindings(party,"phrasesRight")[1]=="primary" and p.Bindings(party)[1]=="primary")
            p.Reset(party.key,1,"phrasesLeft");assert(p.Resolve(party,1,"phrasesLeft")=="phrasesLeft chat")
        ''')

    def test_modifier_release_orders_multimod_cancellation_and_send_suppression(self):
        self.run_lua('''
            local k,I=W.Keyboard,W.Input;local box=HOST.Field("ChatFrame1EditBox","");k:Open(box)
            local f=k.frame
            local function down(t)HOST.keys[t]=true;f:GetScript("OnGamePadButtonDown")(f,t)end
            local function up(t)HOST.keys[t]=false;f:GetScript("OnGamePadButtonUp")(f,t)end
            for _,case in ipairs({{"PADLSHOULDER","phrasesLeft"},{"PADLTRIGGER","phrases"},{"PADRSHOULDER","phrasesRight"}})do
                W.Phrases.Save("global",1,case[2],case[2])
                for _,modifierFirst in ipairs({true,false})do
                    k:Action("clear");I.waitNeutral=false;down(case[1]);assert(k.quickBank==case[2] and I.layer==case[2])
                    down("PAD1");if modifierFirst then up(case[1]);up("PAD1")else up("PAD1");up(case[1])end
                    assert(box:GetText()==case[2] and not I.layer and #HOST.sent==0)
                end
                for _,reverse in ipairs({true,false})do
                    I.waitNeutral=false
                    if reverse then down("PADRTRIGGER");down(case[1])else down(case[1]);down("PADRTRIGGER")end
                    up(case[1]);up("PADRTRIGGER");assert(#HOST.sent==0)
                end
            end
            k:Action("clear");I.waitNeutral=false;down("PADLSHOULDER");down("PAD1");down("PADRSHOULDER")
            up("PADRSHOULDER");assert(I.layer=="phrasesLeft");up("PAD1");up("PADLSHOULDER");assert(box:GetText()=="")
            I.waitNeutral=false;down("PADLSHOULDER");down("PADRSHOULDER");up("PADRSHOULDER");down("PAD1");up("PAD1");up("PADLSHOULDER")
            assert(box:GetText()=="phrasesLeft")
        ''')

    def test_lost_modifier_release_foreign_focus_and_new_session_never_insert(self):
        self.run_lua('''
            local k,I=W.Keyboard,W.Input;local box=HOST.Field("SearchBox","kept");k:Open(box)
            W.Phrases.Save("global",1,"stale","phrasesLeft")
            I.waitNeutral=false;HOST.keys.PADLSHOULDER=true;HOST.keys.PAD1=true
            I:Down("PADLSHOULDER");I:Down("PAD1");HOST.keys.PADLSHOULDER=false;I:Update();I:Up("PAD1")
            assert(box:GetText()=="kept" and not I.layer)
            I.waitNeutral=false;I:Down("PADLSHOULDER");I:Down("PAD1")
            local foreign=HOST.Field("OtherSearch","foreign");foreign:SetFocus();I:Up("PADLSHOULDER");I:Up("PAD1")
            assert(box:GetText()=="kept" and foreign:GetText()=="foreign" and not I.layer)
            k:Open(box);I.waitNeutral=false;I:Down("PADLSHOULDER");I:Down("PAD1");k:Close();k:Open(box)
            I:Up("PAD1");I:Up("PADLSHOULDER");assert(box:GetText()=="kept")
        ''')

    def test_bumper_assignment_pins_bank_not_inherited_shortcut_and_l3_symbols(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","original");box:SetAttribute("chatType","PARTY");k:Open(box)
            local cursor=k.editor.cursor;HOST.Press("PADLSHOULDER");assert(k.editor.cursor==cursor and box:GetText()=="original")
            HOST.Press("PADRSHOULDER");assert(k.editor.cursor==cursor and box:GetText()=="original")
            HOST.Press("PADLSTICK");assert(k.symbols and box:GetText()=="original")
            HOST.Press("PADLSTICK");assert(not k.symbols)
            HOST.Press("PADFORWARD");k:SetQuickBank("phrasesLeft");k:UsePhrase(1)
            assert(k.composing.bank=="phrasesLeft");k:SetQuickBank("phrasesRight");assert(k.quickBank=="phrasesLeft")
            k:Action("clear");k:Insert("Left party");HOST.Press("PADRTRIGGER")
            assert(W.db.phraseBanks.phrasesLeft.phrases["chat:PARTY"][1].text=="Left party")
            assert(not W.db.phraseBanks.phrasesLeft.bindings["chat:PARTY"] and not next(W.db.phrases) and not W.db.phraseBanks.phrasesRight)
            k:SetQuickBank("phrasesRight");k:UsePhrase(1);k:Insert("Cancel");k:Action("back")
            assert(not W.db.phraseBanks.phrasesRight and box:GetText()=="original")
            k:ToggleAssign();W.db.style="Nintendo";W.Input:Refresh();k:Draw()
            assert(k.quickBankButtons[1].prompt.icons[1].atlas=="gamepad-switch-128x-shoulder-l-normal")
            assert(k.quickBankButtons[3].prompt.icons[1].atlas=="gamepad-switch-128x-shoulder-r-normal")
            assert(W.Input:Icon("symbols")=="gamepad-switch-128x-stick-l3-normal")
            k:Action("left");assert(k.editor.cursor==#box:GetText()-1)
            k:Action("clear");assert(box:GetText()=="")
        ''')

    def test_standalone_contexts_inheritance_and_numeric_native_exception(self):
        self.run_lua('''
            W.Keyboard:ShowQuickMessages();local k=W.Keyboard
            assert(k.assigning and not k.session and k:Context().key=="global")
            local found=false;for _,c in ipairs(k:QuickContexts())do if c.key=="auction:search"then found=true end end;assert(found)
            GetChannelList=function()return 2,"Trade",false end
            GetChannelName=function()return 2,"Trade"end
            local channel
            for _,c in ipairs(k:QuickContexts())do if c.chatType=="CHANNEL"then channel=c end end
            local field=HOST.Field("ChatFrame1EditBox","");field:SetAttribute("chatType","CHANNEL");field:SetAttribute("channelTarget",2)
            assert(channel.key==W.Contexts.Chat(field).key)
            k:UsePhrase(1);k:Action("clear");k:Insert("Shared");k:Action("confirm")
            assert(W.Phrases.Resolve({key="chat:GUILD",chat=true},1)=="Shared")
            k:Close();k:Open(HOST.Field("Amount","3",true));assert(not k.quickVisible and not k.assigning)
            k:Action("library");assert(not k.assigning);k:Move(0,-1);assert(k.editor.text=="4")
        ''')

    def test_forever_cursor_scrolls_all_assignments_and_releases_to_the_sidebar(self):
        self.run_lua('''
            SMART_NAV_INPUT_DIRECTION={UP="UP",DOWN="DOWN",LEFT="LEFT",RIGHT="RIGHT"}
            SmartNavigation={GetCurrentButton=function(self)return self.current end}
            function SmartNavigation_AddJumpNavigationOverride(b,direction,target)
                assert(not HOST.combat)
                b.nav=b.nav or {};b.nav[direction]=target
            end
            local function focus(b)
                assert(b and b:IsVisible(),"native cursor cannot focus an offscreen row")
                SmartNavigation.current=b
                if b.OnSmartNavSelect then b:OnSmartNavSelect() end
            end
            local O=W.Options;O.OpenBindings();local f=O.bindingEditor
            assert(not f:IsGamePadButtonEnabled())
            for _,r in ipairs(f.rows) do if r.header and not r.expanded then r.button.action() end end
            local side=CreateFrame("Button",nil,SettingsPanel)
            for _,size in ipairs({14,20}) do
                W.db.fontSize=size
                f.rows[1].button:OnSmartNavSelect()
                focus(f.rows[1].button)
                for i,r in ipairs(f.visible) do
                    assert(f.selected==r and not f.footerIndex)
                    if r.cells and f.column==1 then focus(SmartNavigation.current.nav.RIGHT) end
                    assert(r.header or f.column==2)
                    focus(SmartNavigation.current.nav.DOWN)
                end
                assert(f.footerIndex==1 and f.offset>0)
                for i=#f.visible,1,-1 do
                    focus(SmartNavigation.current.nav.UP)
                    assert(f.selected==f.visible[i] and not f.footerIndex)
                end
                assert(f.offset==0)
            end
            local cell=f.rows[2].cells[2];focus(cell);cell.action()
            assert(O.bindingCapture and f.inputOwner.binds.PAD2)
            local click=f.inputButton:GetScript("OnClick")
            click(f.inputButton,"PAD2",true);click(f.inputButton,"PAD2",false)
            assert(not O.bindingCapture and not f.pad and not next(f.inputOwner.binds))
            focus(side);local selected=f.selected
            for _,key in ipairs({"PAD2","PADDDOWN"}) do
                assert(f:GetScript("OnGamePadButtonDown")(f,key)==true)
                assert(f:GetScript("OnGamePadButtonUp")(f,key)==true)
            end
            assert(HOST.settingsOpened==1236 and f.selected==selected)
            O.OpenAppearance();assert(not O.appearanceFrame.pad)
            W.Radial:Edit();assert(not W.Radial.editor.pad)
        ''')

    def test_native_bindings_editor_all_actions_and_reset_reachable_without_keyboard_window(self):
        self.run_lua('''
            W.Options.OpenBindings();local O=W.Options
            assert(HOST.settingsOpened==1236 and O.bindingEditor:IsShown() and not W.Keyboard.frame:IsShown())
            local f=O.bindingEditor
            local function press(key)f:GetScript("OnGamePadButtonDown")(f,key);f:GetScript("OnGamePadButtonUp")(f,key)end
            local typing, symbols
            for _,row in ipairs(f.rows) do
                if row.scope=="text" and row.header then typing=row end
                if row.scope=="text" and row.data and row.data[1]=="symbols" then symbols=row end
            end
            typing.button.action();symbols.cells[2].action();assert(O.bindingCapture)
            press("PAD5");assert(W.db.actionBindings.symbols=="PAD5" and not O.bindingCapture)
            symbols.cells[2].action();press("PAD1");assert(O.bindingCapture and W.db.actionBindings.symbols=="PAD5")
            press("PAD2");assert(not O.bindingCapture)
            press("PADDRIGHT")
            assert(f.footerIndex==1); press("PADDRIGHT");press("PAD1");assert(W.db.actionBindings==nil)
            press("PADDRIGHT");press("PAD1");assert(HOST.settingsOpened==1234)
            HOST.combat=true;assert(not O.AssignAction("primary","PAD5"))
        ''')

if __name__=='__main__':unittest.main()
