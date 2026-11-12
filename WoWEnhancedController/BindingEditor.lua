local _,W = ...
local O,B,L = W.Options,W.ControlBindings,W.L
local devices = {"key","pad"}
local height, visible = 32, 10

local function text(parent,value,x,y,width)
    local label=W.Theme.Label(parent,value)
    label:SetPoint("TOPLEFT",x,y); label:SetSize(width,30); label:SetJustifyH("LEFT")
    return label
end
local function button(parent,template,action)
    local b=CreateFrame("Button",nil,parent,template)
    if not b:GetFontString() then b:SetFontString(W.Theme.Label(b,"","GameFontHighlightSmall")) end
    b.action=action; b:SetScript("OnClick",action)
    b.focus=b:CreateTexture(nil,"OVERLAY"); b.focus:SetAllPoints()
    b.focus:SetColorTexture(1,.8,.36,.20); b.focus:Hide()
    return b
end
local function available(f)
    return f:IsVisible() and not W.Combat() and not W.Blocker() and not W.Focus() and not W.Input.active
end
local function selectRow(f,row,col)
    f.selected=row; f.lastAction=not row.header and row or nil; f.column=col or f.column
    f.footerIndex=nil; O.bindingCapture=false; O.bindingHeld=nil
end
local function tokenName(token)
    if token=="" then return NOT_BOUND or L["Unbound"] end
    if B.IsPad(token) then return W.Input:TokenLabel(token) end
    if GetBindingText then return GetBindingText(token,"KEY_") or token end
    return token
end
local function startCapture(f,row,col)
    if not available(f) then return end
    selectRow(f,row,col); O.bindingCapture=true; O.PaintBindings()
end
local function toggle(f,row)
    if not available(f) then return end
    selectRow(f,row); row.expanded=not row.expanded; f.navDirty=true; O.PaintBindings()
end
local function save(f,token)
    local row=f.lastAction
    if not row or not available(f) then return end
    local ok,err=B.Assign(row.scope,row.data,devices[f.column],token)
    O.bindingCapture=not ok
    O.PaintBindings(err)
end
local function scroll(f,offset)
    if O.bindingCapture then return end
    f.offset=W.Clamp(offset,0,math.max(0,#f.visible-visible)); O.bindingHeld=nil
    O.PaintBindings(nil,true)
end
local function rowButton(row, column)
    return row and (row.button or row.cells[column])
end
local function linkButtons(button, direction, target)
    SmartNavigation_AddJumpNavigationOverride(button, SMART_NAV_INPUT_DIRECTION[direction], target)
end
local function updateLinks(f)
    if not O.NativeNavigation() or W.Combat() then return end
    if f.navDirty or f.navColumn~=f.column then
        for i,row in ipairs(f.visible) do
            for col,b in ipairs(row.cells or {row.button}) do
                local column=row.header and f.column or col
                linkButtons(b,"UP",rowButton(f.visible[i-1],column) or true)
                linkButtons(b,"DOWN",rowButton(f.visible[i+1],column) or f.footer[1])
                if row.cells then
                    linkButtons(b,"RIGHT",row.cells[col+1] or f.footer[1])
                    if col==2 then linkButtons(b,"LEFT",row.cells[1]) end
                end
            end
        end
        f.navDirty=nil; f.navColumn=f.column
    end
    local previous=rowButton(f.selected,f.column)
    if previous~=f.footerReturn then
        for _,b in ipairs(f.footer) do linkButtons(b,"UP",previous) end
        f.footerReturn=previous
    end
end
local function syncCapture(f)
    if O.bindingCapture and O.NativeNavigation() and available(f) then
        if not f.boundSignature then
            local keys={}
            for _,token in ipairs(W.KeyboardBindings:Tokens()) do keys[token]=true end
            W.BindMenuControls(f,"SettingsCapture",keys,{},"capture")
        end
    elseif f.boundSignature then
        W.ReleaseMenuControls(f)
    end
    W.Input:RefreshWindowCapture(f)
end
function O.PaintBindings(message,keepOffset)
    local f=O.bindingEditor
    if not f then return end
    height=math.max(32,math.ceil(W.db.fontSize*2.45))
    visible=math.floor(326/height)
    f.visible={}
    local expanded
    for _,row in ipairs(f.rows) do
        if row.header then expanded=row.expanded end
        if row.header or expanded then f.visible[#f.visible+1]=row end
    end
    local selected=1
    for i,row in ipairs(f.visible) do if row==f.selected then selected=i;break end end
    if not keepOffset and not f.footerIndex then
        -- Keep both neighbors visible so native Smart Navigation can focus
        -- the next logical row at either edge of the viewport.
        f.offset=W.Clamp(f.offset,selected-visible+1,selected-2)
    end
    local maxOffset=math.max(0,#f.visible-visible)
    f.offset=W.Clamp(f.offset,0,maxOffset)
    local cursor=O.NativeNavigation() and SmartNavigation:GetCurrentButton()
    local cursorRow=f.navigationRows[cursor]
    local scrollTarget
    if keepOffset and not f.footerIndex then
        local first,last=f.offset+1,math.min(#f.visible,f.offset+visible)
        if cursorRow then
            for i,row in ipairs(f.visible) do if row==cursorRow then selected=i;break end end
            if first>1 then first=first+1 end
            if last<#f.visible then last=last-1 end
        end
        local row=f.visible[W.Clamp(selected,first,last)]
        local column=f.column
        if cursorRow and cursorRow.cells then column=cursor==cursorRow.cells[1] and 1 or 2 end
        selectRow(f,row,column)
        if cursorRow then scrollTarget=rowButton(row,f.column) end
    end
    local displayed={}
    for i=f.offset+1,math.min(#f.visible,f.offset+visible) do
        local row=f.visible[i]
        displayed[row]=true
        local y=-78-(i-f.offset-1)*height
        if row.layoutY~=y then
            row.layoutY=y; row:ClearAllPoints();row:SetPoint("TOPLEFT",f,"TOPLEFT",14,y)
        end
        if not row:IsShown() then row:Show() end
        local active=row==f.selected and not f.footerIndex
        if row.header then
            row.edge:SetAtlas(row.expanded and "Options_ListExpand_Right_Expanded" or "Options_ListExpand_Right",true)
            row.button.focus:SetShown(active and (not cursor or cursor==row.button))
        else
            row.caption:SetHeight(height-2)
            for col,device in ipairs(devices) do
                local b=row.cells[col]
                local token=B.Get(row.scope,row.data,device)
                b:SetText(active and f.column==col and O.bindingCapture and "…" or tokenName(token))
                b.focus:SetShown(active and f.column==col and (O.bindingCapture or not cursor or cursor==b))
                b:SetNormalFontObject(W.Theme.Font(token=="" and "GameFontDisable" or "GameFontHighlightSmall"))
            end
        end
    end
    for _,row in ipairs(f.rows) do if not displayed[row] and row:IsShown() then row:Hide() end end
    updateLinks(f)
    for i,b in ipairs(f.footer) do b.focus:SetShown(i==f.footerIndex and (not cursor or cursor==b)) end
    f.scrollSync=true
    f.scroll:SetHeight(visible*height)
    f.scroll:SetVisibleExtentPercentage(math.min(1,visible/#f.visible))
    f.scroll:SetPanExtentPercentage(maxOffset>0 and 1/maxOffset or 1)
    f.scroll:SetScrollPercentage(maxOffset>0 and f.offset/maxOffset or 0,true)
    f.scroll:SetShown(maxOffset>0); f.scrollSync=nil
    local hint=O.bindingCapture and (f.column==1 and L["Press a keyboard key. Escape cancels."] or L["Press a gamepad button. Escape cancels."])
    if not hint and f.lastAction then
        local id=f.lastAction.data[1]
        local wheelMode=id:match("^CLICK WoWEnhancedControllerWheelInput:(%a+)$")
        if wheelMode then hint="/click WoWEnhancedControllerWheel"..wheelMode
        else hint=L[f.lastAction.section.description] end
    end
    f.status:SetText(message or hint or L["Select a binding to change it."])
    syncCapture(f)
    if scrollTarget and scrollTarget~=cursor then O.FocusCanvasControl(scrollTarget) end
end
local function header(f,scope,title,description,expanded)
    local row=CreateFrame("Frame",nil,f); row:SetSize(568,height)
    row.scope=scope;row.header=true;row.expanded=expanded;row.description=description
    local b=button(row,nil,function() toggle(f,row) end);b:SetAllPoints()
    local left=b:CreateTexture(nil,"BACKGROUND");left:SetAtlas("Options_ListExpand_Left",true);left:SetPoint("TOPLEFT")
    local right=b:CreateTexture(nil,"BACKGROUND");right:SetAtlas("Options_ListExpand_Right",true);right:SetPoint("TOPRIGHT")
    local middle=b:CreateTexture(nil,"BACKGROUND");middle:SetAtlas("_Options_ListExpand_Middle",true)
    middle:SetHorizTile(false);middle:SetPoint("TOPLEFT",left,"TOPRIGHT")
    middle:SetSize(math.max(1,row:GetWidth()-left:GetWidth()-right:GetWidth()),left:GetHeight())
    text(b,L[title],20,0,477);row.edge=right
    row.button=b;f.rows[#f.rows+1]=row
    return row
end
local function actionRow(f,section,data)
    local row=CreateFrame("Frame",nil,f);row:SetSize(568,height)
    row.scope,row.section,row.data,row.cells=section.scope,section,data,{}
    local label=_G["BINDING_NAME_"..data[1]] or L[data[2]]
    row.caption=text(row,label,12,0,244);row.caption:SetWordWrap(true)
    for col=1,2 do
        local b=button(row,"KeyBindingFrameBindingButtonTemplate",function() startCapture(f,row,col) end)
        b:SetSize(152,27);b:SetPoint("TOPLEFT",252+(col-1)*156,-2)
        row.cells[col]=b
    end
    f.rows[#f.rows+1]=row
end
local function move(f,dx,dy)
    if f.footerIndex then
        if dy<0 then f.footerIndex=nil
        elseif dx~=0 then f.footerIndex=W.Clamp(f.footerIndex+dx,1,#f.footer) end
    elseif dx~=0 then
        if f.selected.header then
            if f.selected.expanded~=(dx>0) then toggle(f,f.selected) end
        elseif dx>0 and f.column==2 then f.footerIndex=1
        else f.column=W.Clamp(f.column+dx,1,2) end
    else
        for i,row in ipairs(f.visible) do
            if row==f.selected then
                if i+dy>#f.visible then f.footerIndex=1
                else selectRow(f,f.visible[math.max(1,i+dy)]) end
                break
            end
        end
    end
    O.PaintBindings()
end
local function input(f,token,pad)
    if not available(f) then return end
    local swap=W.Input:Style()=="Nintendo" and W.db.swapNintendo
    local primary,back=swap and "PAD2" or "PAD1",swap and "PAD1" or "PAD2"
    if O.bindingCapture then
        if token=="ESCAPE" or pad and token==back then O.bindingCapture=false;O.PaintBindings();return end
        if pad~=(f.column==2) then return end
        if not pad then
            token=(IsAltKeyDown and IsAltKeyDown() and "ALT-" or "")..(IsControlKeyDown and IsControlKeyDown() and "CTRL-" or "")..(IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or "")..token
        end
        save(f,token);return
    end
    if token=="PADDUP" or token=="UP" then move(f,0,-1)
    elseif token=="PADDDOWN" or token=="DOWN" then move(f,0,1)
    elseif token=="PADDLEFT" or token=="LEFT" then move(f,-1,0)
    elseif token=="PADDRIGHT" or token=="RIGHT" then move(f,1,0)
    elseif token==back or token=="ESCAPE" then O.Open()
    elseif token=="DELETE" and f.lastAction then save(f,"")
    elseif token==primary or token=="ENTER" then
        if f.footerIndex then f.footer[f.footerIndex].action()
        elseif f.selected.header then toggle(f,f.selected)
        else startCapture(f,f.selected,f.column) end
    end
end
function O.CreateBindingEditor(canvas)
    local f=CreateFrame("Frame",nil,canvas);f:SetPoint("TOP");f:SetSize(616,514);f:SetFrameStrata("HIGH")
    O.bindingEditor=f; f.rows={}; f.navigationRows={}; f.column=1; f.offset=0; f.navDirty=true
    text(f,L["Controller bindings"],18,-4,500)
    text(f,L["Keyboard"],270,-43,152);text(f,L["Gamepad"],426,-43,152)
    local general=header(f,"general","General shortcuts","Available through the game's keybindings.",false)
    for _,row in ipairs(B.general) do actionRow(f,general,row) end
    local typing=header(f,"text","Controller keyboard","While the controller keyboard has focus.",false)
    for _,id in ipairs(W.Input.actionOrder) do actionRow(f,typing,{id,id}) end
    local wheel=header(f,"wheel","Healing wheel","While the healing wheel is open.",true)
    for _,row in ipairs(B.wheel) do actionRow(f,wheel,row) end
    f.selected=wheel
    f.scroll=CreateFrame("EventFrame",nil,f,"MinimalScrollBar");f.scroll:SetPoint("TOPRIGHT",-5,-78)
    f.scroll:SetHeight(visible*height);f.scroll:Init(1,1)
    f.scroll:RegisterCallback(ScrollBarMixin.Event.OnScroll,function(_,p)
        if not f.scrollSync then scroll(f,math.floor(math.max(0,#f.visible-visible)*p+.5)) end
    end,f)
    f:EnableMouseWheel(true);f:SetScript("OnMouseWheel",function(_,delta) scroll(f,f.offset-delta) end)
    f.status=text(f,"",20,-404,568);f.status:SetHeight(43)
    local function reset()
        if not available(f) then return end
        local scope=f.selected.scope
        if scope=="text" then W.db.actionBindings=nil;W.db.textKeys=nil
        elseif scope=="wheel" then W.db.radial.controls=nil
        else
            local ok,message=B.ResetGeneral()
            if not ok then O.PaintBindings(message);return end
        end
        O.bindingCapture=false;O.Apply();O.PaintBindings()
    end
    f.footer={}
    for i,entry in ipairs({{"Unbind",function() if f.lastAction then save(f,"") end end},{"Reset section",reset},{"Done",O.Open}}) do
        local b=W.Theme.SettingsButton(f,L[entry[1]],entry[2]);b:SetSize(152,30);b:SetPoint("TOPLEFT",20+(i-1)*176,-460)
        f.footer[i]=b
        b.OnSmartNavDeselect=function() b.focus:Hide() end
        b.OnSmartNavSelect=function() if available(f) and not O.bindingCapture then f.footerIndex=i;O.PaintBindings() end end
    end
    for _,row in ipairs(f.rows) do
        for col,b in ipairs(row.cells or {row.button}) do
            f.navigationRows[b]=row
            -- A horizontal step past the first column should hit the native
            -- Settings left edge rather than a header or footer on a diagonal.
            if col==1 and O.NativeNavigation() and SmartNavigation_SetDirectionBufferThreshold then
                SmartNavigation_SetDirectionBufferThreshold(b,SMART_NAV_INPUT_DIRECTION.LEFT,1)
            end
            b.OnSmartNavDeselect=function() b.focus:Hide() end
            b.OnSmartNavSelect=function()
                if available(f) and not O.bindingCapture then
                    selectRow(f,row,row.cells and col or f.column);O.PaintBindings()
                end
            end
        end
    end
    function f:Down(token)
        if self.waitForUp and self.waitForUp[token] then return end
        if not available(f) or O.NativeNavigation() and not O.bindingCapture then return true end
        if not O.bindingHeld then O.bindingHeld={token=token,row=f.selected,capture=O.bindingCapture} end
        return false
    end
    function f:Up(token)
        if self.waitForUp and self.waitForUp[token] then self.waitForUp[token]=nil;return end
        local held=O.bindingHeld;O.bindingHeld=nil
        if not held or held.token~=token or held.row~=f.selected or held.capture~=O.bindingCapture then return true end
        input(f,token,true);return false
    end
    f:SetScript("OnGamePadButtonDown",function(_,token)
        if f.menuKeys and f.menuKeys[token] then return true end
        return f:Down(token)
    end)
    f:SetScript("OnGamePadButtonUp",function(_,token)
        if f.menuKeys and f.menuKeys[token] then return true end
        return f:Up(token)
    end)
    f:EnableKeyboard(true);f:SetPropagateKeyboardInput(true)
    f:SetScript("OnKeyDown",function(_,token)
        if W.Combat() then return end
        local nativeCursor=O.NativeNavigation() and W.ControllerMode() and SmartNavigation:GetCurrentButton()
        local consume=available(f) and (O.bindingCapture or not nativeCursor and
            (token=="UP" or token=="DOWN" or token=="LEFT" or token=="RIGHT" or token=="ENTER" or token=="DELETE"))
        f:SetPropagateKeyboardInput(not consume)
        if O.bindingCapture and (token:match("SHIFT$") or token:match("CTRL$") or token:match("ALT$") or token:match("META$")) then return end
        if consume and not f.keyHeld then f.keyHeld=token;input(f,token,false) end
    end)
    f:SetScript("OnKeyUp",function(_,token)
        if f.keyHeld==token then f.keyHeld=nil end
        if not W.Combat() then f:SetPropagateKeyboardInput(true) end
    end)
    f:RegisterEvent("UPDATE_BINDINGS"); f:RegisterEvent("PLAYER_REGEN_DISABLED")
    local function resetInput()
        O.bindingHeld=nil; O.bindingCapture=false; f.keyHeld=nil
        if f.boundSignature then W.ReleaseMenuControls(f) end
    end
    f:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_REGEN_DISABLED" then resetInput() end
        if f:IsVisible() then O.PaintBindings() end
    end)
    W.Input:TrackWindow(f,resetInput,false,
        function() return O.bindingCapture or not O.NativeNavigation() end)
end
