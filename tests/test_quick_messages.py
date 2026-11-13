"""Paged quick actions and native Settings ownership; simulated callbacks, not hardware."""
import unittest
import test_radial as fixture

class QuickMessageTests(unittest.TestCase):
    def setUp(self):
        self.env=fixture.RadialTests();self.env.load_addon(settings_model=True)
    def run_lua(self,code):self.env.run_lua(code)

    def test_icon_only_pages_and_recycled_labels_do_not_require_implicit_fontstrings(self):
        self.run_lua('''
            local bare=CreateFrame("Button",nil,UIParent)
            bare:SetNormalFontObject(GameFontNormal);bare:SetText("")
            assert(bare:GetFontString()==nil)
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","kept");k:Open(box)
            for _,skin in ipairs({"minimal","classic","gold"})do
                W.db.keyboardAppearance.buttons=skin;k:Draw()
                for _,b in ipairs(k.quickPageButtons)do
                    assert(b:GetText()==""and b:GetFontString()and b.prompt.icons[1]:IsShown())
                end
            end
            local b=k.quickPageButtons[1];b.label=nil
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
            W.Input:Stick("Camera",0,1);assert(not k.composing)
            f:GetScript("OnGamePadButtonUp")(f,"PADLTRIGGER");assert(k.composing and k.composing.slot==1)
            k:Action("clear");k:Insert("Invite 用户!");HOST.Press("PADRTRIGGER")
            assert(k.assigning and not k.composing and box:GetText()=="original" and #HOST.sent==0)
            assert(W.db.phrases["chat:PARTY"][1].text=="Invite 用户!")
            assert(not W.db.bindings["chat:PARTY"]) -- Editing words retains shortcut inheritance.
            HOST.Press("PADFORWARD");W.Input.waitNeutral=false
            f:GetScript("OnGamePadButtonDown")(f,"PADLTRIGGER");W.Input:Stick("Camera",0,1)
            f:GetScript("OnGamePadButtonUp")(f,"PADLTRIGGER")
            assert(box:GetText()=="original" and #HOST.sent==1 and HOST.sent[1][1]=="Invite 用户!" and HOST.sent[1][2]=="PARTY")
            box:SetAttribute("chatType","RAID");W.NativeField.Read(k,false,true);k:Draw()
            assert(k.quickButtons[1]:GetText()=="Ready!")
        ''')

    def test_cancel_assignment_keeps_messages_bindings_focus_and_original_selection(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("SearchBox","keep");k:Open(box)
            k.editor:Select(1,3);k:Sync();k:ToggleAssign();k:UsePhrase(1)
            k:Action("clear");k:Insert("discard");k:Action("back")
            assert(not k.composing and k.assigning and box:HasFocus() and box:GetText()=="keep")
            assert(not W.db.phrases[k:Context().key] and not W.db.bindings[k:Context().key])
            assert(k.editor.anchor==1 and k.editor.cursor==3)
            k:Action("back");assert(not k.assigning and k.frame:IsShown())
            k:Action("back");assert(not k.frame:IsShown())
        ''')

    def test_saved_reload_shortcut_reloads_once_without_sending_the_command_or_draft(self):
        self.run_lua('''
            local k=W.Keyboard
            local box=HOST.Field("ChatFrame1EditBox","unfinished draft")
            box:SetAttribute("chatType","SAY");k:Open(box)
            local reloads=0
            ReloadUI=function() reloads=reloads+1 end
            W.Phrases.Save("chat",1,"/reload")
            local f=k.frame;W.Input.waitNeutral=false
            f:GetScript("OnGamePadButtonDown")(f,"PADLTRIGGER")
            W.Input:Stick("Camera",0,1)
            f:GetScript("OnGamePadButtonUp")(f,"PADLTRIGGER")
            assert(reloads==1 and #HOST.sent==0 and box:GetText()=="unfinished draft")
            W.Phrases.Save("chat",2," /RELOAD ",nil,nil,{chatType="CHANNEL",channelName="Left channel"})
            k:UsePhrase(2)
            assert(reloads==2 and #HOST.sent==0)
            W.Phrases.Save("chat",3,"Try /reload")
            k:UsePhrase(3)
            assert(reloads==2 and #HOST.sent==1 and HOST.sent[1][1]=="Try /reload")
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
            assert(k.frame:GetWidth()<wide and not button("q") and k.focused.messageSlot and k.quickDecoration.highlight:IsShown())
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
                for _,row in ipairs(k.rows) do for _,b in ipairs(row) do assert(not b:IsEnabled() or seen[b],b:GetText()) end end
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

    def test_wedge_positions_and_prompts_follow_remapped_controls(self):
        self.run_lua('''
            W.db.phrases.global={[1]={text="User global"}}
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","");box:SetAttribute("chatType","PARTY");k:Open(box)
            local x,y=k.quickButtons[1].navX,k.quickButtons[1].navY
            assert(k.quickButtons[1]:GetText()=="User global" and y<k.quickButtons[3].navY)
            W.db.style="Nintendo";W.Input:Refresh();k:Draw()
            assert(k.quickButtons[1].navX==x and k.quickButtons[1].navY==y)
            assert(k.quickPageButtons[1].prompt.icons[1].atlas==W.Input:Icon("phrasesLeft"))
            assert(k.quickDecoration.aimGlyph.atlas==W.Input:Icon("phrases"))
            W.db.actionBindings={phrases="",phrasesRight="PAD5"};W.Input:Refresh();k:Draw()
            assert(not k.quickDecoration.aimGlyph:IsShown() and k.quickHint:GetText():find("Unbound",1,true))
            assert(k.quickPageButtons[2]:GetText()==">" and k.quickButtons[1]:GetText()=="User global")
        ''')

    def test_bumper_migration_preserves_custom_binds_and_existing_messages(self):
        self.run_lua('''
            W.db.schema=5;W.db.actionBindings={left="PADLSHOULDER",right="PADRSHOULDER",clear="PADLSTICK",symbols=""}
            W.db.phrases.global={[1]={text="Kept"}};W.db.bindings.global={"back","primary","delete","shift"}
            W.db.quickPages=nil
            local left={text="Pinned",link={kind="tracked"},destination={chatType="PARTY"}}
            W.db.phraseBanks={phrasesLeft={phrases={chat={[3]=left}}},phrasesRight={phrases={global={{text="Right"}}}}}
            W.InitDB();W.Input:Refresh()
            assert(#W.db.quickPages==3 and W.db.quickPages[2]=="phrasesLeft" and W.db.quickPages[3]=="phrasesRight")
            local text,_,link,dest=W.Phrases.Resolve({key="chat:SAY",chat=true},3,W.db.quickPages[2])
            assert(link.kind=="tracked" and dest.chatType=="PARTY" and W.Phrases.Resolve({key="global"},1,W.db.quickPages[3])=="Right")
            assert(W.db.schema==6 and W.Input.keys.left=="" and W.Input.keys.right=="" and W.Input.keys.clear=="")
            assert(W.Input.keys.symbols=="PADLSTICK" and W.Input.keys.phrasesLeft=="PADLSHOULDER" and W.Input.keys.phrasesRight=="PADRSHOULDER")
            assert(W.Phrases.Resolve({key="global"},1)=="Kept" and W.db.bindings.global[1]=="back")
            W.db.schema=5;W.db.actionBindings={left="PAD5",right="PAD6",clear="PAD7",symbols="PAD8"}
            W.InitDB();W.Input:Refresh()
            assert(W.Input.keys.left=="PAD5" and W.Input.keys.right=="PAD6" and W.Input.keys.clear=="PAD7" and W.Input.keys.symbols=="PAD8")
        ''')

    def test_pages_are_unlimited_and_stable_across_removal_and_reload(self):
        self.run_lua('''
            local p=W.Phrases;local party={key="chat:PARTY",chat=true};local guild={key="chat:GUILD",chat=true}
            for n=2,36 do assert(p.AddPage()==n) end
            for _,bank in ipairs(W.db.quickPages)do
                for slot=1,8 do assert(p.Save("global",slot,bank..slot,bank))end
                assert(p.Save("chat",8,bank.." chat",bank) and p.Save(party.key,8,bank.." party",bank))
                assert(p.Resolve(party,8,bank)==bank.." party" and p.Resolve(guild,8,bank)==bank.." chat")
                p.Reset(party.key,8,bank);assert(p.Resolve(party,8,bank)==bank.." chat")
                assert(p.Resolve({key="craft",numeric=true},2,bank)=="5")
            end
            local keep=W.db.quickPages[36]; local removed=W.db.quickPages[2]
            assert(not p.RemovePage(1) and p.RemovePage(2) and not W.db.phraseBanks[removed])
            assert(p.AddPage()==36 and W.db.quickPages[36]~=keep)
            W.InitDB();assert(W.db.quickPages[35]==keep and p.Resolve(guild,8,keep)==keep.." chat")
        ''')

    def test_aim_is_clockwise_and_release_uses_only_the_current_wedge_once(self):
        self.run_lua('''
            local k,I=W.Keyboard,W.Input;local box=HOST.Field("ChatFrame1EditBox","draft");box:SetAttribute("chatType","SAY");k:Open(box)
            for n,xy in ipairs({{0,1},{1,1},{1,0},{1,-1},{0,-1},{-1,-1},{-1,0},{-1,1}}) do
                W.Phrases.Save("global",n,"Slot "..n)
                I.waitNeutral=false;I:Down("PADLTRIGGER");I:Stick("Camera",xy[1],xy[2])
                assert(k.quickAim==n and #HOST.sent==n-1)
                HOST.Press("PAD1");I:Up("PADLTRIGGER");I:Up("PADLTRIGGER")
                assert(#HOST.sent==n and HOST.sent[n][1]=="Slot "..n and box:GetText()=="draft")
            end
            I:Down("PADLTRIGGER");I:Stick("Camera",0,1);I:Stick("Camera",.1,.1);I:Up("PADLTRIGGER")
            I:Down("PADRTRIGGER");I:Down("PADLTRIGGER");I:Up("PADLTRIGGER");I:Up("PADRTRIGGER")
            assert(#HOST.sent==8 and box:GetText()=="draft")
        ''')

    def test_aim_owns_axes_only_while_held_and_uses_the_mapped_stick_at_release(self):
        self.run_lua('''
            local k,i=W.Keyboard,W.Input;local b=HOST.Field("SearchBox","");k:Open(b)
            W.Phrases.Save("global",3,"East");k:Draw();W.Radial.frame:SetAttribute("camera-index",1)
            HOST.pad.sticks={{x=0,y=0,len=0},{x=0,y=1,len=1}}
            assert(not i.quickCapture:IsVisible())
            i.waitNeutral=false;HOST.keys.PADLTRIGGER=true;i:Down("PADLTRIGGER")
            assert(i.quickCapture:IsVisible() and i.quickCapture:IsGamePadStickEnabled() and i.quickCapture.propagateKeyboard==false)
            HOST.pad.sticks[1]={x=1,y=0,len=1};i:Update();assert(k.quickAim==3)
            HOST.pad.sticks[1]={x=0,y=0,len=0};i:Up("PADLTRIGGER");assert(b:GetText()=="" and not i.quickCapture:IsVisible())
            HOST.pad.sticks[1]={x=1,y=0,len=1};i:Down("PADLTRIGGER");i:Up("PADLTRIGGER")
            assert(b:GetText()=="East" and not i.quickCapture:IsVisible())
            i:Down("PADLTRIGGER");k:Close();assert(not i.quickCapture:IsVisible() and not i.quickHold)
        ''')

    def test_lost_release_focus_session_channel_and_page_changes_cancel_aim(self):
        self.run_lua('''
            local k,I=W.Keyboard,W.Input;local box=HOST.Field("ChatFrame1EditBox","kept");box:SetAttribute("chatType","SAY");k:Open(box)
            local function aim()I.waitNeutral=false;I:Down("PADLTRIGGER");I:Stick("Camera",0,1);assert(k.quickAim==1)end
            local function release()I:Up("PADLTRIGGER");assert(#HOST.sent==0 and box:GetText()=="kept" and not I.quickHold)end
            aim();HOST.keys.PADLTRIGGER=false;I:Update();release()
            aim();local foreign=HOST.Field("OtherSearch","foreign");foreign:SetFocus();release();assert(foreign:GetText()=="foreign")
            k:Open(box);aim();k:Close();k:Open(box);release()
            aim();box:SetAttribute("chatType","PARTY");release();W.NativeField.Read(k,false,true);k:Draw()
            W.Phrases.AddPage();aim();HOST.Press("PADRSHOULDER");release();assert(k.quickPage==2)
            aim();HOST.Press("PAD2");release()
            aim();I:Down("PADLSHOULDER");release();I:Up("PADLSHOULDER");assert(k.quickPage==1)
            I:Down("PADRSHOULDER");I:Down("PADLTRIGGER");I:Stick("Camera",0,1);release();I:Up("PADRSHOULDER")
            assert(k.quickPage==2);k:Close();k:Open(box);assert(k.quickPage==2)
        ''')

    def test_page_controls_edit_confirm_deletion_and_keep_the_original_draft(self):
        self.run_lua('''
            local k=W.Keyboard; local box=HOST.Field("ChatFrame1EditBox","original");box:SetAttribute("chatType","PARTY");k:Open(box)
            local function button(label)
                for _,row in ipairs(k.rows)do for _,b in ipairs(row)do if b:GetText()==label then return b end end end
                error(label)
            end
            local cursor=k.editor.cursor;HOST.Press("PADLSHOULDER");assert(k.editor.cursor==cursor)
            HOST.Press("PADLSTICK");assert(k.symbols);HOST.Press("PADLSTICK");assert(not k.symbols)
            HOST.Press("PADFORWARD");assert(not button("Remove page"):IsEnabled());button("Add page").run()
            local key=k.quickBank;k:UsePhrase(8);HOST.Press("PADLSHOULDER");assert(k.composing.bank==key and k.quickPage==2)
            k:Action("clear");k:Insert("Ready on eight");HOST.Press("PADRTRIGGER")
            assert(W.db.phraseBanks[key].phrases["chat:PARTY"][8].text=="Ready on eight" and box:GetText()=="original")
            button("Add page").run();HOST.Press("PADRSHOULDER");assert(k.quickPage==1)
            HOST.Press("PADLSHOULDER");assert(k.quickPage==3);button("Remove page").run();assert(#W.db.quickPages==3)
            HOST.Press("PADLSHOULDER");assert(k.quickPage==2);HOST.Press("PADRSHOULDER")
            button("Remove page").run();button("Confirm removal").run()
            assert(k.quickPage==2 and #W.db.quickPages==2 and k.quickBank==key)
            k:ToggleAssign();k:UsePhrase(8);assert(#HOST.sent==1 and HOST.sent[1][1]=="Ready on eight" and box:GetText()=="original")
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
