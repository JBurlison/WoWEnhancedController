"""Bank/mail quick move through production binding and mouse callbacks.

Native transfers are recorded, not emulated; client permissions need WoW.
"""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET
import test_radial as fixture

ROOT = Path(__file__).resolve().parents[1]


class QuickMoveTests(unittest.TestCase):
    def setUp(self):
        self.env = fixture.RadialTests()
        self.env.load_addon(settings_model=True)
        binding = next(b for b in ET.parse(ROOT / 'WoWEnhancedController/Bindings.xml').getroot()
                       if b.attrib['name'] == 'WEC_QUICK_MOVE')
        self.assertEqual(binding.attrib['runOnUp'], 'true')
        self.env.lua.globals().QuickMoveBinding = self.env.lua.execute(
            'return function(keystate)\n' + binding.text + '\nend')
        self.run_lua('''
            Constants=Constants or {};Constants.InventoryConstants={NumBagSlots=4,NumReagentBagSlots=1}
            Enum.BankType={Character=0,Account=2}
            BankFrame=CreateFrame("Frame","BankFrame",UIParent);BankFrame:Hide()
            MailFrame=CreateFrame("Frame","MailFrame",UIParent);MailFrame:Hide()
            SendMailFrame=CreateFrame("Frame","SendMailFrame",MailFrame);SendMailFrame:Hide()
            OpenMailFrame=CreateFrame("Frame","OpenMailFrame",MailFrame);OpenMailFrame:Hide()
            SendMailNameEditBox=HOST.Field("SendMailNameEditBox","",false,SendMailFrame)
            InboxFrame={openMailID=1};HOST.bankType=0;HOST.canBank=true
            function BankFrame:GetActiveBankType()return HOST.bankType end
            C_Bank={CanUseBank=function(t)return HOST.canBank end}
            HOST.moves={};HOST.mailSwitches=0;HOST.inbox={};HOST.outgoing={};HOST.items={}
            HOST.items[0]={[1]={hyperlink="|Hitem:2589|h[Linen]|h",stackCount=10,iconFileID=123,guid="linen-1"}}
            HOST.items[6]={[1]={hyperlink="|Hitem:2592|h[Wool]|h",stackCount=5,iconFileID=124,guid="wool-1"}}
            C_Container={GetContainerItemInfo=function(b,s)return HOST.items[b]and HOST.items[b][s]end,
                UseContainerItem=function(...)HOST.moves[#HOST.moves+1]={...}end}
            ItemLocation={CreateFromBagAndSlot=function(_,b,s)return {bag=b,slot=s}end}
            C_Item={GetItemGUID=function(loc)local i=C_Container.GetContainerItemInfo(loc.bag,loc.slot);return i and i.guid end}
            Item={CreateFromItemGUID=function(_,guid)return {guid=guid}end}
            GetCursorInfo=function()return HOST.cursor end
            SpellIsTargeting=function()return HOST.targeting end
            SmartNavigation={GetCurrentButton=function()return HOST.selected end}
            GetMouseFoci=function()return HOST.mouse and {HOST.mouse}or {}end
            GetBindingKey=function(action)assert(action=="WEC_QUICK_MOVE");return HOST.moveKey,HOST.moveKey2 end
            function HOST.MoveEvent(event)W.QuickMove.driver:GetScript("OnEvent")(W.QuickMove.driver,event)end
            function HOST.MoveTick()W.QuickMove.driver:GetScript("OnUpdate")(W.QuickMove.driver,.11)end
            function HOST.MovePress()QuickMoveBinding("down");QuickMoveBinding("up")end
            HOST.bagButton=CreateFrame("ItemButton",nil,UIParent)
            HOST.bagButton.buttonContext="ButtonContext_ContainerFrameItemButton"
            function HOST.bagButton:GetBagID()return 0 end
            function HOST.bagButton:GetID()return 1 end
            HOST.bankButton=CreateFrame("ItemButton",nil,BankFrame)
            function HOST.bankButton:GetBankTabID()return 6 end
            function HOST.bankButton:GetContainerSlotID()return 1 end
            HOST.inboxButton=CreateFrame("ItemButton",nil,OpenMailFrame)
            function HOST.inboxButton:GetID()return 1 end
            OpenMailFrame.OpenMailAttachments={HOST.inboxButton}
            HOST.sendButton=CreateFrame("Button",nil,SendMailFrame)
            function HOST.sendButton:GetID()return 1 end
            SendMailFrame.SendMailAttachments={HOST.sendButton}
            function MailFrameTab_OnClick(_,id)
                assert(id==2);HOST.mailSwitches=HOST.mailSwitches+1
                OpenMailFrame:Hide();SendMailFrame:Show()
                SendMailNameEditBox:SetFocus()
            end
            function GetInboxItemLink(m,s)return HOST.inbox.link end
            function GetInboxItem(m,s)return "Attachment",5,125,HOST.inbox.count end
            function GetInboxHeaderInfo(m)return nil,nil,"Sender","Subject",0,HOST.inbox.cod or 0 end
            function GetSendMailItemLink(s)return HOST.outgoing.link end
            function GetSendMailItem(s)return "Outgoing",5,126,HOST.outgoing.count end
            function ClickSendMailItemButton(slot,remove)HOST.removed={slot,remove}end
            function OpenMailAttachment_OnClick(button,slot)
                if HOST.inbox.cod then HOST.codPrompt=true else HOST.taken={InboxFrame.openMailID,slot}end
            end
            function StaticPopup_Show(name,a,b,data)HOST.popup={name=name,data=data}end
            function BankUtil_IsAccountBankDepositRefundable(loc)return HOST.refundable end
            function SendMail()error("Quick move must not send mail")end
            function DeleteInboxItem()error("Quick move must not delete mail")end
            function HOST.OpenBank()
                MailFrame:Hide();BankFrame:Show();HOST.MoveEvent("BANKFRAME_OPENED")
                HOST.selected=HOST.bagButton;HOST.MoveTick()
            end
            function HOST.OpenMail()
                BankFrame:Hide();MailFrame:Show();HOST.MoveEvent("MAIL_SHOW")
                HOST.selected=HOST.bagButton;HOST.MoveTick()
            end
        ''')

    def run_lua(self, code):
        self.env.run_lua(code)

    def test_deposit_to_active_bank_and_withdraw_highlighted_stack(self):
        self.run_lua('''
            HOST.OpenBank();assert(W.QuickMove.button:IsShown())
            assert(W.QuickMove.button:GetText()==W.L["Move to bank"])
            HOST.MovePress();assert(#HOST.moves==1 and HOST.moves[1][1]==0 and HOST.moves[1][2]==1)
            assert(HOST.moves[1][4]==Enum.BankType.Character and HOST.moves[1][5]==false)
            HOST.bankType=Enum.BankType.Account;HOST.MoveTick();HOST.MovePress()
            assert(HOST.moves[2][4]==Enum.BankType.Account)
            HOST.selected=HOST.bankButton;HOST.MoveTick()
            assert(W.QuickMove.button:GetText()==W.L["Move to bags"])
            HOST.MovePress();assert(#HOST.moves==3 and HOST.moves[3][1]==6 and HOST.moves[3][4]==nil)
        ''')

    def test_mail_attaches_from_inbox_tab_without_sending_and_removes_draft_attachment(self):
        self.run_lua('''
            HOST.OpenMail();assert(not SendMailFrame:IsShown())
            assert(W.QuickMove.button:GetText()==W.L["Attach to mail"])
            HOST.MovePress();assert(#HOST.moves==1 and HOST.mailSwitches==1 and SendMailFrame:IsShown())
            assert(not SendMailNameEditBox:HasFocus())
            HOST.outgoing={link="|Hitem:2589|h[Linen]|h",count=10}
            HOST.selected=HOST.sendButton;HOST.MoveTick();HOST.MovePress()
            assert(HOST.removed[1]==1 and HOST.removed[2]==true and #HOST.moves==1)
        ''')

    def test_open_mail_takes_only_selected_attachment_and_keeps_native_cod_confirmation(self):
        self.run_lua('''
            HOST.OpenMail();OpenMailFrame:Show();HOST.inbox={link="|Hitem:5|h[Inbox]|h",count=2}
            HOST.selected=HOST.inboxButton;HOST.MoveTick();HOST.MovePress()
            assert(HOST.taken[1]==1 and HOST.taken[2]==1 and #HOST.moves==0)
            HOST.taken=nil;HOST.inbox.cod=100;HOST.MoveTick();HOST.MovePress()
            assert(HOST.codPrompt and HOST.taken==nil)
        ''')

    def test_native_refundable_account_bank_confirmation_is_retained(self):
        self.run_lua('''
            HOST.OpenBank();HOST.bankType=2;HOST.refundable=true;HOST.MoveTick();HOST.MovePress()
            assert(#HOST.moves==0 and HOST.popup.name=="ACCOUNT_BANK_DEPOSIT_NO_REFUND_CONFIRM")
            assert(HOST.popup.data.itemToDeposit.guid=="linen-1")
        ''')

    def test_recycled_identical_item_changed_stack_tab_and_focus_reject_release(self):
        self.run_lua('''
            HOST.OpenBank();QuickMoveBinding("up");assert(#HOST.moves==0)
            QuickMoveBinding("down");HOST.items[0][1].guid="identical-replacement";QuickMoveBinding("up")
            assert(#HOST.moves==0)
            HOST.MoveTick();QuickMoveBinding("down");HOST.items[0][1].stackCount=9;QuickMoveBinding("up")
            assert(#HOST.moves==0)
            HOST.MoveTick();QuickMoveBinding("down");HOST.bankType=2;QuickMoveBinding("up")
            assert(#HOST.moves==0)
            HOST.MoveTick();QuickMoveBinding("down");HOST.selected=HOST.bankButton;QuickMoveBinding("up")
            assert(#HOST.moves==0)
            HOST.MoveTick();QuickMoveBinding("down");QuickMoveBinding("down");QuickMoveBinding("up");QuickMoveBinding("up")
            assert(#HOST.moves==1)
        ''')

    def test_close_inventory_update_disconnect_and_mode_change_cancel_pending_press(self):
        self.run_lua('''
            for _,event in ipairs({"BANKFRAME_CLOSED","BAG_UPDATE_DELAYED","GAME_PAD_DISCONNECTED","INPUT_DEVICE_INTERFACE_TRANSITION"})do
                HOST.OpenBank();QuickMoveBinding("down");HOST.MoveEvent(event);QuickMoveBinding("up")
                assert(#HOST.moves==0)
            end
            HOST.OpenBank();QuickMoveBinding("down");HOST.mode=0;QuickMoveBinding("up");assert(#HOST.moves==0)
            HOST.mode=1;HOST.OpenMail();OpenMailFrame:Show()
            HOST.inbox={link="|Hitem:5|h[Inbox]|h",count=2};HOST.selected=HOST.inboxButton
            HOST.MoveTick();QuickMoveBinding("down");InboxFrame.openMailID=2;QuickMoveBinding("up")
            assert(HOST.taken==nil)
        ''')

    def test_combat_cursor_spell_targeting_locked_full_ui_and_disabled_do_not_use_item(self):
        self.run_lua('''
            HOST.OpenBank()
            for _,key in ipairs({"combat","cursor","targeting"})do
                HOST[key]=true;HOST.MoveTick();HOST.MovePress()
                assert(not W.QuickMove.button:IsShown()and #HOST.moves==0);HOST[key]=nil
            end
            HOST.items[0][1].isLocked=true;HOST.MoveTick();HOST.MovePress();assert(#HOST.moves==0)
            HOST.items[0][1].isLocked=false;HOST.canBank=false;HOST.MovePress();assert(#HOST.moves==0)
            HOST.canBank=true;W.db.quickMove=false;HOST.MovePress();assert(#HOST.moves==0)
            W.db.quickMove=true;MailFrame:Show();HOST.MoveEvent("MAIL_SHOW");HOST.MovePress();assert(#HOST.moves==0)
            MailFrame:Hide();HOST.MoveTick();QuickMoveBinding("down");HOST.combat=true;QuickMoveBinding("up")
            assert(#HOST.moves==0)
            HOST.combat=false;BankFrame:Hide();HOST.MoveTick();HOST.MovePress();assert(#HOST.moves==0)
        ''')

    def test_mail_send_lock_empty_slots_foreign_fields_and_unrelated_buttons_are_ignored(self):
        self.run_lua('''
            HOST.OpenMail();HOST.MoveEvent("MAIL_LOCK_SEND_ITEMS");HOST.MovePress();assert(#HOST.moves==0)
            HOST.MoveEvent("MAIL_UNLOCK_SEND_ITEMS");HOST.MoveTick();HOST.MovePress();assert(#HOST.moves==1)
            HOST.selected=HOST.sendButton;HOST.MoveTick();HOST.MovePress();assert(HOST.removed==nil)
            OpenMailFrame:Show();HOST.selected=HOST.inboxButton;HOST.MoveTick();HOST.MovePress();assert(HOST.taken==nil)
            HOST.selected=HOST.bagButton;HOST.items[0][1]=nil;HOST.MoveTick();HOST.MovePress();assert(#HOST.moves==1)
            HOST.OpenBank();HOST.selected=CreateFrame("Button",nil,UIParent);HOST.MoveTick();HOST.MovePress()
            assert(not W.QuickMove.button:IsShown()and #HOST.moves==1)
        ''')

    def test_mouse_button_retains_explicit_item_and_rechecks_replacement(self):
        self.run_lua('''
            HOST.OpenBank();HOST.mode=0;HOST.mouse=HOST.bagButton;HOST.MoveTick()
            local b=W.QuickMove.button;assert(b:IsShown())
            HOST.mouse=b;HOST.MoveTick();b:GetScript("OnClick")(b,"LeftButton",true)
            b:GetScript("OnClick")(b,"LeftButton",false);assert(#HOST.moves==1)
            HOST.mouse=HOST.bagButton;HOST.MoveTick();HOST.mouse=b
            b:GetScript("OnClick")(b,"LeftButton",true);HOST.items[0][1].guid="new"
            b:GetScript("OnClick")(b,"LeftButton",false);assert(#HOST.moves==1)
        ''')

    def test_controller_to_mouse_handoff_keeps_shown_item_but_cancels_old_press(self):
        self.run_lua('''
            HOST.OpenBank();QuickMoveBinding("down");HOST.mode=0;HOST.mouse=W.QuickMove.button
            HOST.MoveEvent("INPUT_DEVICE_INTERFACE_TRANSITION");QuickMoveBinding("up")
            assert(#HOST.moves==0 and W.QuickMove.button:IsShown())
            local b=W.QuickMove.button;b:GetScript("OnClick")(b,"LeftButton",true)
            b:GetScript("OnClick")(b,"LeftButton",false);assert(#HOST.moves==1)
        ''')

    def test_settings_persistence_and_actual_binding_hint(self):
        self.run_lua('''
            assert(W.db.quickMove and HOST.settings.WEC_quickMove)
            HOST.OpenBank();HOST.moveKey="PADLSTICK";HOST.MoveTick()
            assert(W.QuickMove.button.hint.atlas==W.Input:TokenIcon("PADLSTICK"))
            assert(W.QuickMove.button.hint:IsShown())
            HOST.moveKey=nil;HOST.MoveTick();assert(not W.QuickMove.button.hint:IsShown())
            HOST.moveKey="K";HOST.moveKey2="PAD3";HOST.MoveTick()
            assert(W.QuickMove.button.hint.atlas==W.Input:TokenIcon("PAD3"))
            HOST.mode=0;HOST.mouse=HOST.bagButton;HOST.MoveTick()
            assert(W.QuickMove.button.keyLabel:GetText()=="K")
            HOST.settings.WEC_quickMove:SetValue(false);HOST.MoveTick();assert(not W.QuickMove.button:IsShown())
            W.InitDB();assert(W.db.quickMove==false)
            W.db.quickMove="invalid";W.InitDB();assert(W.db.quickMove==true)
        ''')


if __name__ == '__main__':
    unittest.main()
