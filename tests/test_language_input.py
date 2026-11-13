"""Controller composition through real keyboard rows, native fields and phrase drafts."""
import unittest
import test_radial as fixture


class LanguageInputTests(unittest.TestCase):
    def env(self, locale):
        env = fixture.RadialTests()
        env.load_addon(locale=locale)
        env.run_lua("""
            k=W.Keyboard
            function findKey(text)
                for _,row in ipairs(k.rows) do for _,b in ipairs(row) do
                    if b:GetText()==text then return b end
                end end
            end
            function press(text)
                local b=assert(findKey(text),"Missing key "..text)
                k:Select(b.row,b.col); HOST.Press(W.Input.keys.primary)
            end
            function letters(text)
                for _,ch in ipairs(W.Locale.Characters(text)) do press(ch) end
            end
            function chat(text)
                box=HOST.Field("ChatFrame1EditBox",text)
                box:SetAttribute("chatType","PARTY");k:Open(box)
            end
        """)
        return env

    def test_alphabets_and_shifted_accents_across_client_locales(self):
        for code, lower, upper in [("enUS","z","Z"),("enGB","z","Z"),("deDE","ß","ẞ"),
                                   ("frFR","œ","Œ"),("esES","ñ","Ñ"),("esMX","ñ","Ñ"),
                                   ("itIT","è","È"),("ptBR","ã","Ã"),("ruRU","я","Я")]:
            with self.subTest(locale=code):
                env=self.env(code)
                env.lua.globals().lower=lower
                env.lua.globals().upper=upper
                env.run_lua("""
                    chat("");if not findKey(lower) then k:Action("symbols") end
                    press(lower);k:Action("shift");press(upper);assert(box:GetText()==lower..upper)
                """)

    def test_korean_real_chat_and_command_switch(self):
        self.env("koKR").run_lua("""
            chat("");letters("ㅇㅏㄴㄴㅕㅇㅎㅏㅅㅔㅇㅛ")
            assert(box:GetText()=="안녕하세요",box:GetText())
            HOST.Press(W.Input.keys.confirm)
            assert(#HOST.sent==1 and HOST.sent[1][1]=="안녕하세요")
            chat("");press(W.L["Hangul"]);press("a");assert(box:GetText()=="a")
        """)

    def test_korean_clusters_backspace_selection_and_field_limits(self):
        self.env("koKR").run_lua("""
            local f=HOST.Field("Search","");k:Open(f);letters("ㄷㅏㄹㄱ")
            assert(f:GetText()=="닭");press("ㅏ");assert(f:GetText()=="달가")
            k:Action("delete");assert(f:GetText()=="달ㄱ")
            k:Action("delete");assert(f:GetText()=="달")
            k:Action("clear");k:Action("shift");press("ㄲ");letters("ㅗㅏ");assert(f:GetText()=="꽈")
        """)
        self.env("koKR").run_lua("""
            local f=HOST.Field("Search","ax");k:Open(f);k.editor:Select(0,1);k:Sync()
            letters("ㅎㅏㄴ");assert(f:GetText()=="한x" and k.editor.cursor==3)
            k.editor.options.maxBytes=4;press("ㅏ");assert(f:GetText()=="한x")
            k:Action("left");press("ㅏ");assert(f:GetText()=="한x")
        """)

    def test_all_modern_hangul_syllables(self):
        self.env("koKR").run_lua("""
            local L=W.Locale.Characters("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
            local vowels={"ㅏ","ㅐ","ㅑ","ㅒ","ㅓ","ㅔ","ㅕ","ㅖ","ㅗ","ㅗㅏ","ㅗㅐ","ㅗㅣ","ㅛ","ㅜ","ㅜㅓ","ㅜㅔ","ㅜㅣ","ㅠ","ㅡ","ㅡㅣ","ㅣ"}
            local tails={"","ㄱ","ㄲ","ㄱㅅ","ㄴ","ㄴㅈ","ㄴㅎ","ㄷ","ㄹ","ㄹㄱ","ㄹㅁ","ㄹㅂ","ㄹㅅ","ㄹㅌ","ㄹㅍ","ㄹㅎ","ㅁ","ㅂ","ㅂㅅ","ㅅ","ㅆ","ㅇ","ㅈ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"}
            local code=0xAC00
            for _,l in ipairs(L) do for _,v in ipairs(vowels) do for _,t in ipairs(tails) do
                local done,_,active=W.Hangul.Compose(W.Locale.Characters(l..v..t))
                local a,b,c=active:byte(1,3)
                assert(done=="" and (a-224)*4096+(b-128)*64+c-128==code)
                code=code+1
            end end end
            assert(code==0xD7A4)
        """)

    def test_chinese_readings_candidates_and_native_submit_for_both_scripts(self):
        for locale, spelling, word, mode in [("zhCN","long","龙","Pinyin"),("zhTW","ㄌㄨㄥ","龍","Zhuyin")]:
            with self.subTest(locale=locale):
                env=self.env(locale)
                env.lua.globals().spelling=spelling
                env.lua.globals().word=word
                env.lua.globals().mode=mode
                env.run_lua("""
                    chat("draft");letters(spelling);assert(box:GetText()=="draft" and #HOST.sent==0)
                    local start=k.preedit.candidates[1];press("›");assert(k.preedit.page==2);press("‹");assert(k.preedit.page==1)
                    local page=1
                    while not findKey(word) and page<=8 do press("›");page=page+1 end
                    press(word);assert(box:GetText()=="draft"..word)
                    letters(spelling);HOST.Press(W.Input.keys.confirm)
                    assert(box:GetText()=="draft"..word..start and #HOST.sent==0)
                    HOST.Press(W.Input.keys.confirm);assert(#HOST.sent==1 and HOST.sent[1][1]=="draft"..word..start)
                """)

    def test_quick_message_editing_preserves_native_draft_for_each_new_layout(self):
        for locale,spelling,want in [("koKR","ㅎㅏㄴ","한"),("zhCN","ni","你"),("zhTW","ㄋㄧ","你")]:
            with self.subTest(locale=locale):
                env=self.env(locale)
                env.lua.globals().spelling=spelling
                env.lua.globals().want=want
                env.run_lua("""
                    chat("party draft");k:ToggleAssign();k:UsePhrase(8);k:CustomMessage(true)
                    letters(spelling)
                    if W.Mandarin then press(want) end
                    assert(k.input:GetText()==want and box:GetText()=="party draft")
                    k:Action("confirm");k:Action("confirm");k:ToggleAssign();k:UsePhrase(8)
                    assert(HOST.sent[1][1]==want and box:GetText()=="party draft")
                """)

    def test_no_match_backspace_cancel_focus_change_and_latin_mode(self):
        self.env("zhTW").run_lua("""
            chat("");press(W.L["Zhuyin"]);letters("zz");assert(#k.preedit.candidates==0)
            HOST.Press(W.Input.keys.confirm);assert(k.frame:IsShown() and #HOST.sent==0)
            k:Action("delete");assert(k.preedit.reading=="z")
            k:Action("back");assert(not k.preedit and k.frame:IsShown())
            letters("nü");assert(k.preedit.candidates[1] and W.Mandarin.nv:find("女",1,true))
            local stale=assert(findKey(k.preedit.candidates[1]));local callback=stale.run
            local other=HOST.Field("Search","keep");k:Open(other);callback()
            assert(other:GetText()=="keep" and box:GetText()=="" and not k:CurrentPreedit())
            press(W.L["Pinyin"]);press("q");assert(other:GetText()=="keepq")
            press(W.L["Latin letters"]);assert(findKey("ㄋ"))
            local amount=HOST.Field("Amount","3",true);k:Open(amount)
            assert(not findKey(W.L["Zhuyin"]) and not k.preedit)
        """)
