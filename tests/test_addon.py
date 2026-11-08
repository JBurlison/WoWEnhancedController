"""Lua 5.1 host checks; no claim to emulate client security or rendering."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tools/pydeps"))
from lupa.lua51 import LuaRuntime


class AddonTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute((ROOT / "tests/host.lua").read_text(encoding="utf-8"))
        namespace = self.lua.table()
        self.lua.globals().W = namespace
        toc = ROOT / "WoWEnhancedController/WoWEnhancedController.toc"
        for line in toc.read_text().splitlines():
            if line.endswith(".lua"):
                source = (toc.parent / line).read_text(encoding="utf-8")
                self.lua.execute("return function(...)\n" + source + "\nend")("WoWEnhancedController", namespace)
        self.lua.execute('W.events:GetScript("OnEvent")(W.events,"ADDON_LOADED","WoWEnhancedController")')
        self.lua.execute('W.events:GetScript("OnEvent")(W.events,"PLAYER_ENTERING_WORLD")')

    def run_lua(self, source):
        self.lua.execute(source)

    def test_native_addon_menu_metadata_entry_opens_options(self):
        toc = (ROOT / "WoWEnhancedController/WoWEnhancedController.toc").read_text()
        callback = next(line.split(":", 1)[1].strip() for line in toc.splitlines()
                        if line.startswith("## AddonCompartmentFunc:"))
        self.lua.globals()[callback]("WoWEnhancedController", "LeftButton")
        self.run_lua('''
            assert(W.Keyboard.frame:IsShown() and W.Keyboard.view=="options" and W.Input.active)
            assert(#HOST.sent==0)
            W.Keyboard:Close();HOST.combat=true
        ''')
        self.lua.globals()[callback]("WoWEnhancedController", "LeftButton")
        self.run_lua('assert(not W.Keyboard.frame:IsShown())')

    def test_xbox_default_migration_and_optional_auto(self):
        self.run_lua('''
            assert(W.db.style=="Xbox" and W.db.schema==5)
            HOST.pad.labelStyle="Reverse";W.Input:Refresh()
            assert(W.Input.keys.primary=="PAD1" and W.Input.keys.back=="PAD2")
            assert(W.Input:Icon("primary")=="gamepad-xbox1-buttona-normal")
            assert(W.Input:Icon("confirm")=="gamepad-xbox1-trigger-rt-normal")
            assert(W.Input:Icon("focus")=="gamepad-xbox1-view-normal")
            assert(W.Input:Icon("library")=="gamepad-xbox1-menu-normal")
            W.db.schema=2;W.db.style="Auto";W.InitDB();assert(W.db.style=="Xbox")
            W.db.schema=2;W.db.style="PlayStation";W.InitDB();assert(W.db.style=="PlayStation")
            W.db.style="Auto";W.InitDB();W.Input:Refresh()
            assert(W.db.style=="Auto" and W.Input.keys.primary=="PAD2")
            W.db.schema=3;W.db.actionBindings={library="PADBACK",delete="PAD5"}
            W.InitDB();W.Input:Refresh()
            assert(W.db.schema==5 and W.Input.keys.library=="PADFORWARD" and W.Input.keys.delete=="PAD5")
            W.db.schema=3;W.db.actionBindings.library="PAD6";W.InitDB();W.Input:Refresh()
            assert(W.Input.keys.library=="PAD6")
        ''')

    def test_unicode_selection_undo_and_numeric_bounds(self):
        self.run_lua('''
            local e=W.Text.New("café",{});e:Delete();assert(e.text=="caf");e:Undo();assert(e.text=="café")
            e=W.Text.New("é",{});e:Delete();assert(e.text=="")
            e=W.Text.New("👩‍🚀🇺🇸",{});e:Delete();assert(e.text=="👩‍🚀");e:Delete();assert(e.text=="")
            e=W.Text.New("12",{numeric=true,min=1,max=20});e:Adjust(10);assert(e.text=="20")
            e:Clear();assert(not e:Validate());e:Undo();assert(e:Validate())
            e:Select(0,2);e:Replace("5");assert(e.text=="5")
            e=W.Text.New("99",{numeric=true,min=0,maxLetters=2});e:Adjust(1);assert(e.text=="99")
        ''')

    def test_full_toc_field_commit_and_cancel(self):
        self.run_lua('''
            local box=HOST.Field("SearchBox","copper")
            assert(W.Keyboard:Open(box));W.Keyboard.editor:Clear();W.Keyboard.editor:Replace("linen")
            assert(box:GetText()=="copper");W.Keyboard:Action("confirm");assert(box:GetText()=="linen")
            W.Keyboard:Open(box);W.Keyboard.editor:Clear();W.Keyboard:Action("back");assert(box:GetText()=="linen")
        ''')

    def test_view_focus_menu_library_and_trigger_send_keep_press_identity(self):
        self.run_lua('''
            local box=HOST.Field("ChatFrame1EditBox","draft");box:SetAttribute("chatType","PARTY")
            W.Keyboard:Open(box)
            assert(W.Input.keys.confirm=="PADRTRIGGER" and W.Input.keys.space=="PADRSTICK")
            HOST.Press("PADBACK");assert(W.Input.active and #HOST.sent==0)
            assert(W.Keyboard.editor.text=="draft")
            HOST.Press("PADFORWARD");assert(W.Keyboard.view=="phrases" and #HOST.sent==0)
            assert(W.Keyboard.editor.text=="draft")
            HOST.Press("PADFORWARD");assert(W.Keyboard.view=="keys")
            HOST.Press("PADRTRIGGER");assert(#HOST.sent==1 and HOST.sent[1][1]=="draft")
            box:Show();W.Keyboard:Open(box);W.Keyboard:Insert("kept")
            local f=W.Keyboard.frame
            for _,order in ipairs({{"PADLTRIGGER","PADRTRIGGER"},{"PADRTRIGGER","PADLTRIGGER"}})do
                W.Input.waitNeutral=false
                f:GetScript("OnGamePadButtonDown")(f,order[1])
                f:GetScript("OnGamePadButtonDown")(f,order[2])
                f:GetScript("OnGamePadButtonUp")(f,"PADLTRIGGER")
                f:GetScript("OnGamePadButtonUp")(f,"PADRTRIGGER")
                assert(#HOST.sent==1 and W.Keyboard.editor.text=="kept")
            end
            HOST.Press("PADBACK");assert(#HOST.sent==1)
            W.Input.waitNeutral=false
            f:GetScript("OnGamePadButtonDown")(f,"PADRTRIGGER")
            f:GetScript("OnGamePadButtonDown")(f,"PADBACK")
            f:GetScript("OnGamePadButtonUp")(f,"PADBACK")
            f:GetScript("OnGamePadButtonUp")(f,"PADRTRIGGER")
            assert(#HOST.sent==1 and W.Keyboard.editor.text=="kept")
        ''')

    def test_focus_binding_opens_reclaims_and_respects_blockers(self):
        self.run_lua('''
            HOST.mode=0
            local box=HOST.Field("SearchBox","old");box:SetFocus()
            assert(W.FocusBinding());assert(W.Input.active and W.Keyboard.session.target==box)
            W.Keyboard.editor:Clear();W.Keyboard.editor:Replace("buffered")
            W.Input:Release();W.Keyboard:Hide();HOST.focus=nil
            assert(W.FocusBinding());assert(W.Keyboard.frame:IsShown() and W.Input.active)
            assert(W.Keyboard.editor.text=="buffered" and box:GetText()=="buffered")
            HOST.combat=true;assert(not W.FocusBinding());HOST.combat=false
            GameMenuFrame=CreateFrame("Frame",nil,UIParent);assert(not W.FocusBinding());GameMenuFrame:Hide()
            HOST.Press("PADRTRIGGER");assert(box:GetText()=="buffered")
            W.db.schema=1;W.db.actionBindings={confirm="PADFORWARD",space="PADRTRIGGER",delete="PAD5"}
            W.InitDB();W.Input:Refresh()
            assert(W.db.schema==5 and W.Input.keys.confirm=="PADRTRIGGER")
            assert(W.Input.keys.focus=="PADBACK" and W.Input.keys.space=="PADRSTICK" and W.Input.keys.delete=="PAD5")
            W.db.actionBindings={confirm="PADBACK"};W.Input:Refresh()
            assert(W.Input.reverse.PADBACK=="focus" and W.Input.keys.confirm=="")
        ''')

    def test_space_shortcut_tabs_and_noninteractive_settings(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("SearchBox","hello");k:Open(box)
            HOST.Press("PADRSTICK")
            assert(k.editor.text=="hello " and box:GetText()=="hello " and not k.symbols)
            assert(W.Input:Icon("space")=="gamepad-xbox1-stick-r3-normal")
            assert(W.Input.keys.symbols=="")
            local function activate(text)
                for r,row in ipairs(k.rows)do for c,b in ipairs(row)do
                    if b:GetText()==text then k:Select(r,c);HOST.Press(W.Input.keys.primary);return end
                end end
                error("Control not reachable: "..text)
            end
            assert(k.rows[1][1].tabSelected and not k.rows[1][4].tabSelected)
            activate("Symbols");assert(k.symbols)
            activate("Options");assert(k.view=="options" and k.rows[1][4].tabSelected)
            k:Select(2,1);HOST.Press("PADDDOWN")
            assert(k.rows[1][4].tabSelected) -- selected tab persists as focus moves
            assert(#k.rows[2]==2 and #k.rows[3]==2 and #k.rows[4]==3)
            for _,row in ipairs(k.rows)do for _,b in ipairs(row)do
                assert(not b:GetText():find("Scale:",1,true) and b:GetText()~="Controller icons")
            end end
            activate("Smaller");assert(W.db.scale<1)
            activate("Reset scale");assert(W.db.scale==1)
            activate("Phrases & bindings");activate("Next slot");assert(k.slot==2)
            activate("Insert phrase");assert(#k.editor.text>6)
            activate("Keyboard");assert(k.labelsUsed==0)
            for _,text in ipairs(k.labels)do assert(not text:IsShown()) end
            -- Pooled tab art never survives on ordinary keys.
            assert(not k.rows[2][1].tabSelected)
            for _,art in ipairs(k.rows[2][1].tabArt or {})do assert(not art:IsShown()) end
            W.db.schema=4;W.db.actionBindings={symbols="PADRSTICK",delete="PAD5"}
            W.InitDB();W.Input:Refresh()
            assert(W.Input.keys.space=="PADRSTICK" and W.Input.keys.symbols=="" and W.Input.keys.delete=="PAD5")
            W.db.schema=4;W.db.actionBindings={space="PAD6",symbols="PAD7"}
            W.InitDB();W.Input:Refresh()
            assert(W.Input.keys.space=="PAD6" and W.Input.keys.symbols=="PAD7")
        ''')

    def test_compact_layout_font_size_and_border_focus(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("SearchBox","draft");k:Open(box)
            assert(k.frame:GetHeight()==364 and k.frame:GetWidth()==708)
            assert(not k.destination:IsShown() and k.destination:GetText()=="")
            k:Status("Review this edit")
            assert(k.destination:IsShown() and k.destination:GetText()=="Review this edit")
            assert(box:GetText()=="draft")
            k:Draw();assert(not k.destination:IsShown() and k.frame:GetHeight()==364)
            assert(k.title==nil and k.status==nil and k.messageLabel==nil)
            assert(k.focusButton:GetParent()==k.frame and k.focusButton:GetText()=="")
            assert(k.focusButton.y==4 and k.focusButton.badgeIcon.atlas==W.Input:Icon("focus"))
            for _,row in ipairs(k.rows)do for _,b in ipairs(row)do assert(b~=k.focusButton) end end
            local function activate(text)
                for r,row in ipairs(k.rows)do for c,b in ipairs(row)do
                    if b:GetText()==text then k:Select(r,c);HOST.Press(W.Input.keys.primary);return end
                end end
                error("Control not reachable: "..text)
            end
            assert(W.db.fontSize==14 and W.db.scale==1)
            activate("Options")
            for i=1,4 do activate("Larger text") end
            assert(W.db.fontSize==20 and W.db.scale==1)
            W.InitDB();assert(W.db.fontSize==20)
            activate("Keyboard");assert(k.frame:GetHeight()==364)
            assert(k.input==nil and k.inputBorder==nil)
            local _,size=k.rows[3][1]:GetFontString():GetFont();assert(size==20)
            _,size=k.rows[3][1].highlightFont:GetFont();assert(size==20)
            _,size=GameFontNormal:GetFont();assert(size==12) -- native shared font untouched
            k.focusButton.action();assert(k.editor.text=="draft" and #HOST.sent==0)
            HOST.Press("PADBACK");assert(k.editor.text=="draft")
            activate("Options");activate("Reset text");assert(W.db.fontSize==14)
            activate("Keyboard");assert(k.frame:GetHeight()==364)
            W.db.fontSize="bad";W.InitDB();assert(W.db.fontSize==14)
            -- Feedback from a rejected native write must not retry that write
            -- while redrawing its temporary caption.
            local attempts=0
            box.SetText=function() attempts=attempts+1;error("native write rejected") end
            k.editor:Replace("x");k:Sync()
            assert(attempts==1 and k.destination:IsShown())
            assert(k.lastStatus=="The native field rejected this edit.")
        ''')

    def test_login_does_not_open_keyboard_for_existing_focus(self):
        # Fresh load with a field that autofocuses before entering the world.
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute((ROOT / "tests/host.lua").read_text(encoding="utf-8"))
        self.lua.execute('LoginBox=HOST.Field("ChatFrame1EditBox","initial");LoginBox:SetFocus()')
        ns=self.lua.table();self.lua.globals().W=ns
        toc=ROOT / "WoWEnhancedController/WoWEnhancedController.toc"
        for line in toc.read_text().splitlines():
            if line.endswith(".lua"):
                self.lua.execute("return function(...)\n"+(toc.parent/line).read_text(encoding="utf-8")+"\nend")("WoWEnhancedController",ns)
        self.run_lua('''
            W.events:GetScript("OnEvent")(W.events,"ADDON_LOADED","WoWEnhancedController")
            W.WatchFocus();assert(not W.Keyboard.frame:IsShown())
            HOST.Event("ChatFrame.OnEditBoxFocusGained",LoginBox)
            W.events:GetScript("OnEvent")(W.events,"PLAYER_ENTERING_WORLD")
            W.WatchFocus();assert(not W.Keyboard.frame:IsShown() and not W.Input.active)
            HOST.focus=nil;W.WatchFocus();LoginBox:SetFocus();W.WatchFocus()
            assert(W.Keyboard.frame:IsShown() and W.Keyboard.session.target==LoginBox)
        ''')

    def test_live_native_selection_undo_typing_and_numeric_done(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("SearchBox","hello there");k:Open(box)
            box:HighlightText(0,5);k:Insert("Hi")
            assert(box:GetText()=="Hi there" and k.editor.text=="Hi there")
            k:Action("undo");assert(box:GetText()=="hello there")
            k:Action("clear");assert(box:GetText()=="")
            k:Action("undo");assert(box:GetText()=="hello there")
            box.text="physical";box.cursor=8;box.highlight=nil;box:GetScript("OnTextChanged")(box,true)
            k:Action("space");assert(box:GetText()=="physical ")
            k:Action("back");assert(box:GetText()=="physical " and not k.frame:IsShown())
            k:Open(box);assert(k.input==nil and k.inputBorder==nil and box:HasFocus())
            local number=HOST.Field("Amount","12",true);k:Close();k:Open(number)
            local enters=0;number:SetScript("OnEnterPressed",function()enters=enters+1 end)
            HOST.Press("PADDUP");assert(number:GetText()=="13")
            HOST.Press("PADRTRIGGER");assert(number:GetText()=="13" and enters==0 and not k.frame:IsShown())
        ''')

    def test_native_enter_dispatch_commands_autocomplete_and_failure(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","");box:SetAttribute("chatType","SAY")
            local args;HOST.commands.sample=function(value)args=value end
            k:Open(box);k:Insert("/sample Player-Realm")
            assert(box:GetText()=="/sample Player-Realm" and #HOST.nativeEnters==0 and #HOST.sent==0)
            HOST.Press("PADRTRIGGER")
            assert(args=="Player-Realm" and HOST.nativeEnters[1]=="/sample Player-Realm" and #HOST.sent==0)
            assert(not k.frame:IsShown() and box:GetText()=="")
            box:Show();k:Open(box);k:Insert("/blocked")
            box:SetScript("OnEnterPressed",function()error("native restriction")end)
            HOST.Press("PADRTRIGGER")
            assert(box:GetText()=="/blocked" and k.editor.text=="/blocked" and k.frame:IsShown())
            box:SetScript("OnEnterPressed",nil)
            HOST.Press("PADRTRIGGER");assert(box:GetText()=="/blocked" and #HOST.sent==0)
            local count=0
            box:SetScript("OnEnterPressed",function(field)count=count+1;field:SetText("/sample Completed")end)
            HOST.Press("PADRTRIGGER")
            assert(count==1 and k.editor.text=="/sample Completed" and k.frame:IsShown() and #HOST.sent==0)
            box:SetScript("OnEnterPressed",HOST.NativeChatEnter)
            HOST.Press("PADRTRIGGER");assert(args=="Completed" and #HOST.nativeEnters==2 and not k.frame:IsShown())
            HOST.commands.options=function()k:Options()end
            box:Show();k:Open(box);k:Insert("/options");HOST.Press("PADRTRIGGER")
            assert(k.frame:IsShown() and k.view=="options" and k.session==nil and W.Input.active)
        ''')

    def test_successful_chat_send_releases_retained_native_focus(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","hello")
            box:SetAttribute("chatType","SAY")
            local sends=0
            -- Native gamepad/IM chat clears the message but can leave the
            -- edit box visible and focused after Enter.
            box:SetScript("OnEnterPressed",function(field)
                sends=sends+1;field:SetText("")
            end)
            box:SetFocus();HOST.Event("ChatFrame.OnEditBoxFocusGained",box)
            k:Open(box);HOST.Press("PADRTRIGGER")
            assert(sends==1 and box:GetText()=="")
            assert(not box:HasFocus() and not k.frame:IsShown() and not W.Input.active)
            assert(W.drafts["chat:SAY"]=="")
            for _,fn in ipairs(HOST.queue)do fn() end;HOST.queue={}
            W.WatchFocus();assert(not k.frame:IsShown())
            -- A genuine new focus transaction can open the next message.
            box:SetFocus();W.WatchFocus();assert(k.frame:IsShown())
            k:Insert("next");HOST.Press("PADRTRIGGER")
            assert(sends==2 and not box:HasFocus() and not k.frame:IsShown())
            local other=HOST.Field("CommandSearch","")
            box:SetScript("OnEnterPressed",function(field)field:SetText("");other:SetFocus()end)
            k:Open(box);k:Insert("/open-search");HOST.Press("PADRTRIGGER")
            assert(other:HasFocus() and not box:HasFocus())
        ''')

    def test_native_parser_context_updates_and_foreign_focus_are_safe(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","");box:SetAttribute("chatType","SAY")
            -- Narrow normalization fixture: the native field consumes a prefix.
            box:SetScript("OnTextChanged",function(field)
                if field:GetText()=="/p " then field:SetAttribute("chatType","PARTY");field:SetText("") end
            end)
            k:Open(box);k:Insert("/p ")
            assert(box:GetText()=="" and k:Context().key=="chat:PARTY" and W.Contexts.Valid(k.session))
            k:InsertPhrase(2);assert(box:GetText()=="Group?")
            local other=HOST.Field("OtherSearch","other");other:SetFocus()
            HOST.Press("PADRSTICK");assert(box:GetText()=="Group?" and other:GetText()=="other")
            W.WatchFocus();assert(k.session.target==other)
            HOST.Press("PADRSTICK");assert(other:GetText()=="other ")
        ''')

    def test_phrase_composer_is_the_only_owned_text_field(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","kept");box:SetAttribute("chatType","PARTY");k:Open(box)
            local function activate(text)
                for r,row in ipairs(k.rows)do for c,b in ipairs(row)do
                    if b:GetText()==text then k:Select(r,c);HOST.Press(W.Input.keys.primary);return end
                end end
                error("Control not reachable: "..text)
            end
            activate("Phrases & bindings");activate("Edit phrase")
            assert(k.composing and k.inputBorder:IsShown() and k.input:HasFocus())
            assert(k.input.textInsets[1]==12 and k.input.textInsets[2]==12)
            k:Action("clear");k:Insert("/sample custom")
            assert(k.input:GetText()=="/sample custom" and box:GetText()=="kept" and #HOST.nativeEnters==0)
            HOST.Press("PADRTRIGGER")
            assert(not k.composing and not k.inputBorder:IsShown() and box:HasFocus())
            assert(W.Phrases.Resolve(k:Context(),1)=="/sample custom" and box:GetText()=="kept")
            activate("Keyboard");assert(k.frame:GetHeight()==364)
        ''')

    def test_mouse_click_reclaims_only_its_existing_native_field(self):
        self.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("SearchBox","hello");k:Open(box)
            local key=k.rows[3][1]
            box:ClearFocus();W.Input:Release();key:GetScript("OnMouseDown")(key)
            assert(box:HasFocus() and W.Input.active)
            -- Also tolerate native mouse dispatch clearing focus after down.
            box:ClearFocus();W.WatchFocus();assert(k.frame:IsShown())
            key:GetScript("OnMouseUp")(key);key.action(key)
            assert(box:GetText()=="helloq" and box:HasFocus())
            local other=HOST.Field("OtherSearch","other");other:SetFocus()
            key:GetScript("OnMouseDown")(key);key.action(key)
            assert(box:GetText()=="helloq" and other:GetText()=="other" and k.session.target==other)
            other:ClearFocus();W.WatchFocus();assert(k.suspended)
            box:SetFocus();W.WatchFocus();assert(k.session.target==box and k.frame:IsShown())
        ''')

    def test_raw_button_callbacks_clear_undo_nintendo_and_pairing(self):
        self.run_lua('''
            local box=HOST.Field("SearchBox","hello");W.Keyboard:Open(box)
            HOST.Press("PADLSTICK");assert(W.Keyboard.editor.text=="")
            W.Keyboard:Action("undo");assert(W.Keyboard.editor.text=="hello")
            local f=W.Keyboard.frame
            f:GetScript("OnGamePadButtonUp")(f,"PAD3");assert(W.Keyboard.editor.text=="hello")
            W.db.style="Nintendo";W.Input:Refresh();assert(W.Input.keys.primary=="PAD2")
            assert(W.Input:Hint("primary")=="[A]");assert(W.Input:Hint("back")=="[B]")
            HOST.Press("PAD1");assert(not W.Keyboard.frame:IsShown())
        ''')

    def test_context_phrase_precedence_conflicts_and_persistence(self):
        self.run_lua('''
            local party={key="chat:PARTY",chat=true};local guild={key="chat:GUILD",chat=true}
            W.Phrases.Save("global",1,"global");W.Phrases.Save("chat",1,"chat")
            W.Phrases.Save(party.key,1,"party");assert(W.Phrases.Resolve(party,1)=="party")
            assert(W.Phrases.Resolve(guild,1)=="chat")
            local ok=W.Phrases.Bind(party.key,2,"primary",party);assert(not ok)
            assert(W.Phrases.Bind(party.key,1,"unbound",party));assert(W.Phrases.Bind(party.key,2,"primary",party))
            W.InitDB();assert(W.Phrases.Resolve(party,1)=="party")
        ''')

    def test_anonymous_auction_parent_keys_are_distinct_contexts(self):
        self.run_lua('''
            local ah=CreateFrame("Frame","AuctionHouseFrame",UIParent)
            ah.SearchBar=CreateFrame("Frame",nil,ah)
            ah.SearchBar.SearchBox=HOST.Field(nil,"",false,ah.SearchBar)
            assert(W.Contexts.Describe(ah.SearchBar.SearchBox).key=="auction:search")
            local money=CreateFrame("Frame",nil,ah)
            money.GoldBox=HOST.Field(nil,"1",true,money);money.SilverBox=HOST.Field(nil,"1",true,money)
            assert(W.Contexts.Describe(money.GoldBox).key~=W.Contexts.Describe(money.SilverBox).key)
        ''')

    def test_controller_library_can_unbind_resolve_conflict_and_edit_scope(self):
        self.run_lua('''
            local box=HOST.Field("ChatFrame1EditBox","");box:SetAttribute("chatType","PARTY");W.Keyboard:Open(box)
            local k=W.Keyboard;k.view="phrases";k:Draw()
            local function activate(label)
                for r,row in ipairs(k.rows)do for c,b in ipairs(row)do
                    if b:GetText():find(label,1,true) then k:Select(r,c);HOST.Press(W.Input.keys.primary);return end
                end end
                error("Control not reachable: "..label)
            end
            activate("Shortcut:");activate("Unbound")
            assert(W.db.bindings["chat:PARTY"][1]=="unbound")
            k.slot=2;k:Draw();activate("Shortcut:")
            for r,row in ipairs(k.rows)do for c,b in ipairs(row)do
                if b.basePrompt[2]=="primary" then k:Select(r,c);HOST.Press(W.Input.keys.primary) end
            end end
            assert(W.db.bindings["chat:PARTY"][2]=="primary")
            k.scopeIndex=3;k:Draw();activate("Shortcut:");activate("Unbound")
            assert(W.db.bindings.global[2]=="unbound")
            assert(W.db.bindings.global[1]=="primary")
        ''')

    def test_native_controller_images_without_duplicate_draft(self):
        self.run_lua('''
            local k=W.Keyboard; k:Open(HOST.Field("ChatFrame1EditBox","Padded draft"))
            assert(k.input==nil and k.inputBorder==nil)
            for _,case in ipairs({{"Letters","gamepad-xbox1-buttona-normal"},
                {"Shapes","gamepad-ps-buttoncrox-normal"},
                {"Reverse","gamepad-switch-128x-face-a-normal"}})do
                W.db.style="Auto";HOST.pad.labelStyle=case[1];W.Input:Refresh();k:Draw()
                assert(W.Input:Icon("primary")==case[2])
                k:Select(3,1)
                assert(k.focused.prompt.icons[1].atlas==case[2])
                local phrase=k.rows[2][1]
                assert(phrase.prompt.icons[1].shown and phrase.prompt.icons[2].shown)
                assert(not phrase:GetText():find("[",1,true))
            end
            W.db.actionBindings={primary="PAD3"};W.Input:Refresh();k:Draw()
            assert(W.Input:Icon("primary")=="gamepad-switch-128x-face-y-normal")
        ''')

    def test_chat_drafts_send_only_explicit_channel_identity(self):
        self.run_lua('''
            local box=HOST.Field("ChatFrame1EditBox","");box:SetAttribute("chatType","CHANNEL");box:SetAttribute("channelTarget",2)
            W.Keyboard:Open(box);W.Keyboard:InsertPhrase(1);assert(#HOST.sent==0)
            W.Keyboard:Action("clear");W.Keyboard.editor:Replace("hello");W.Keyboard:Action("confirm")
            assert(#HOST.sent==1 and HOST.sent[1][2]=="CHANNEL" and HOST.sent[1][4]=="2")
            assert(box:GetText()=="")
            box:Show();W.Keyboard:Open(box);W.Keyboard:Insert("draft");W.Keyboard:Action("back");W.Keyboard:Open(box)
            assert(W.Keyboard.editor.text=="draft")
            HOST.tradeID=7;W.Keyboard:Action("confirm");assert(#HOST.sent==1)
        ''')

    def test_stale_field_and_callback_do_not_commit(self):
        self.run_lua('''
            local box=HOST.Field("SearchBox","old");W.Keyboard:Open(box)
            W.Keyboard.editor:Clear();W.Keyboard.editor:Replace("draft");box:SetText("replacement")
            W.Keyboard:Action("confirm");assert(box:GetText()=="replacement")
            W.Keyboard:Open(box);local f=W.Keyboard.frame;W.Input.waitNeutral=false
            f:GetScript("OnGamePadButtonDown")(f,"PADRTRIGGER")
            W.Keyboard:Close();W.Keyboard:Open(box)
            f:GetScript("OnGamePadButtonUp")(f,"PADRTRIGGER");assert(W.Keyboard.frame:IsShown())
        ''')

    def test_dismissal_requires_fresh_focus_and_numeric_keys_are_numeric(self):
        self.run_lua('''
            local box=HOST.Field("Amount","12",true);W.db.activation="always";W.Keyboard:Open(box)
            W.Keyboard:Action("back");assert(W.dismissed==box)
            box:SetFocus();W.WatchFocus();assert(W.Keyboard.session and W.dismissed==nil)
            W.Keyboard.digits=true;W.Keyboard:Draw()
            for _,row in ipairs(W.Keyboard.rows) do for _,b in ipairs(row) do
                assert(b:GetText()~="Space" and b:GetText()~="Symbols")
            end end
        ''')

    def test_unknown_device_prompt_recycled_owner_and_small_screen(self):
        self.run_lua('''
            W.db.style="Auto";HOST.pad.labelStyle="Unknown";W.Input:Refresh();assert(W.Input:Hint("primary")=="[P1]")
            W.Keyboard.remapping=true;W.Keyboard.remapIndex=1;W.Input:Remap("PADDUP");assert(W.db.actionBindings==nil)
            W.Keyboard.remapping=nil
            local box=HOST.Field("Recycled","old");W.Keyboard:Open(box)
            box:SetParent(UIParent);W.Keyboard:Action("confirm");assert(not W.Keyboard.session)
            UIParent:SetSize(640,480);W.db.scale=1.5;W.db.largeKeys=true;W.Keyboard:Options()
            assert(W.Keyboard.frame:GetWidth()*W.Keyboard.frame:GetScale()<=608)
        ''')

    def test_phrase_layer_and_repeat_release(self):
        self.run_lua('''
            local box=HOST.Field("ChatFrame1EditBox","");box:SetAttribute("chatType","PARTY");W.Keyboard:Open(box)
            local f=W.Keyboard.frame;W.Input.waitNeutral=false
            f:GetScript("OnGamePadButtonDown")(f,"PADLTRIGGER")
            f:GetScript("OnGamePadButtonDown")(f,"PAD1")
            f:GetScript("OnGamePadButtonUp")(f,"PADLTRIGGER")
            f:GetScript("OnGamePadButtonUp")(f,"PAD1");assert(W.Keyboard.editor.text=="Ready!")
            local number=HOST.Field("Amount","3",true);number.GetMinValue=function()return 1 end;number.GetMaxValue=function()return 9 end
            W.Keyboard:Close();W.Keyboard:Open(number);W.Input.waitNeutral=false;HOST.keys.PADDUP=true
            f:GetScript("OnGamePadButtonDown")(f,"PADDUP");assert(W.Keyboard.editor.text=="4")
            HOST.now=2;W.Input:Update();assert(W.Keyboard.editor.text=="5")
            HOST.keys.PADDUP=false;f:GetScript("OnGamePadButtonUp")(f,"PADDUP")
            HOST.now=3;W.Input:Update();assert(W.Keyboard.editor.text=="5")
            W.Keyboard:InsertPhrase(4);assert(W.Keyboard.editor.text=="9")
            assert(number:GetText()=="9")
            W.Phrases.Save("global",1,"hello");assert(W.Phrases.Resolve(W.Keyboard:Context(),1)=="1")
        ''')

    def test_edit_mode_per_layout_cancel_reset_and_chat_anchor(self):
        self.run_lua('''
            HOST.Event("EditMode.Enter");assert(W.Placement.editing)
            W.Placement.Nudge("keyboard",10,20);W.Placement.Save()
            assert(W.Placement.Settings("keyboard").x==10)
            HOST.Event("EditMode.Enter");W.Placement.Nudge("keyboard",30,0);W.Placement.Leave()
            assert(W.Placement.Settings("keyboard").x==10)
            HOST.layout="Other";assert(W.Placement.Settings("keyboard").anchor=="chat")
            HOST.Event("EditMode.Enter");W.Placement.Reset("keyboard");W.Placement.Save()
            assert(W.Placement.Settings("keyboard").y==8)
        ''')

    def test_combat_conflict_focus_watcher_and_native_stick_token(self):
        self.run_lua('''
            local box=HOST.Field("SearchBox","text");box:SetFocus();W.WatchFocus();assert(W.Keyboard.session)
            W.Input.waitNeutral=false;local f=W.Keyboard.frame
            local col=W.Keyboard.selectedCol
            assert(f:GetScript("OnGamepadStick")(f,"Movement",1,0)==false)
            assert(W.Keyboard.selectedCol~=col)
            assert(f:GetScript("OnGamepadStick")(f,"Camera",0,0)==true)
            HOST.combat=true;W.events:GetScript("OnEvent")(W.events,"PLAYER_REGEN_DISABLED")
            assert(not W.Input.active and not f:IsShown())
            HOST.combat=false;HOST.conflict="CompactKeyboard";assert(not W.Keyboard:Open(box))
        ''')


if __name__ == "__main__":
    unittest.main(verbosity=2)
