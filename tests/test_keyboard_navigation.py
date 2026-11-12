"""Visible keyboard order and paired D-pad delivery; not physical hardware."""
import unittest
import test_radial as fixture


class KeyboardNavigationTests(unittest.TestCase):
    def setUp(self):
        self.env = fixture.RadialTests()
        self.env.load_addon(settings_model=True)

    def test_dpad_order_staggered_rows_wide_actions_and_no_edge_wrap(self):
        self.env.run_lua('''
            local k=W.Keyboard;local box=HOST.Field("ChatFrame1EditBox","kept");k:Open(box)
            k:Select(2,1)
            for i,char in ipairs(W.Locale.Characters("qwertyuiop"))do
                assert(k.focused:GetText()==char,k.focused:GetText().." expected "..char)
                if i<10 then HOST.Press("PADDRIGHT")end
            end
            for i=10,2,-1 do HOST.Press("PADDLEFT");assert(k.selectedCol==i-1 and k.selectedRow==2)end
            HOST.Press("PADDLEFT");assert(k.focused:GetText()=="q")
            for _,text in ipairs({"a","z","Left","Symbols","Close"})do
                HOST.Press("PADDDOWN");assert(k.focused:GetText()==text,k.focused:GetText().." expected "..text)
            end
            HOST.Press("PADDDOWN");assert(k.focused:GetText()=="Close")
            for _,text in ipairs({"Symbols","Left","z","a","q","Keyboard"})do
                HOST.Press("PADDUP");assert(k.focused:GetText()==text,k.focused:GetText().." expected "..text)
            end
            HOST.Press("PADDUP");assert(k.focused:GetText()=="Keyboard")
            for col,text in ipairs(W.Locale.Characters("asdfghjkll"))do
                k:Select(2,col);HOST.Press("PADDDOWN");assert(k.focused:GetText()==text)
            end
            for row=3,4 do
                k:Select(row,1)
                for col=2,#k.rows[row]do HOST.Press("PADDRIGHT");assert(k.selectedRow==row and k.selectedCol==col)end
            end
            assert(box:GetText()=="kept" and #HOST.sent==0)
        ''')

    def test_disabled_action_navigation_and_every_view_remains_reachable(self):
        self.env.run_lua('''
            local k=W.Keyboard;k:Open(HOST.Field("ChatFrame1EditBox","keep"))
            for _,view in ipairs({"keys","tools"})do
                for _,assigning in ipairs({false,true})do
                    k.view=view;k.assigning=assigning;k:Draw()
                    local queue,seen={{1,1}},{["1:1"]=true};local head=1
                    while queue[head]do local at=queue[head];head=head+1
                        for _,dir in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
                            k:Select(at[1],at[2]);k:Move(unpack(dir))
                            assert(k.focused:IsEnabled())
                            local key=k.selectedRow..":"..k.selectedCol
                            if not seen[key]then seen[key]=true;queue[#queue+1]={k.selectedRow,k.selectedCol}end
                        end
                    end
                    for r,row in ipairs(k.rows)do for c,b in ipairs(row)do
                        if b:IsEnabled()then assert(seen[r..":"..c],view.." unreachable "..b:GetText())end
                    end end
                end
            end
        ''')

    def test_localized_and_symbol_rows_keep_left_to_right_order(self):
        for locale in ('enUS', 'deDE', 'frFR', 'esES', 'itIT', 'ptBR', 'ruRU', 'koKR', 'zhCN', 'zhTW'):
            with self.subTest(locale=locale):
                env = fixture.RadialTests()
                env.load_addon(locale=locale)
                env.run_lua('''
                    local k=W.Keyboard;k:Open(HOST.Field("ChatFrame1EditBox","kept"))
                    W.db.fontSize=20
                    for _,symbols in ipairs({false,true})do
                        k.symbols=symbols;k:Draw()
                        local last=1+(symbols and (W.Locale.extras and 5 or 4) or #W.Locale.rows)
                        for r=2,last do
                            k:Select(r,1)
                            for c=2,#k.rows[r]do
                                local previous=k.focused
                                HOST.Press("PADDRIGHT")
                                assert(k.focused==k.rows[r][c] and k.focused.navX>previous.navX)
                                assert(math.abs(k.focused:GetWidth()-previous:GetWidth())<.00001)
                            end
                            for c=#k.rows[r]-1,1,-1 do
                                HOST.Press("PADDLEFT");assert(k.focused==k.rows[r][c])
                            end
                        end
                    end
                    assert(k.editor.text=="kept"and #HOST.sent==0)
                ''')


if __name__ == '__main__':
    unittest.main()
