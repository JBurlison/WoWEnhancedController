local _, W = ...
local S={x=1280/1100,y=760/688,fonts={}}
W.MacroStyle=S
function S.Font(role,offset)
    local size=math.max(18,W.db.fontSize or 14)+(offset or 0)
    local key=role..size
    if not S.fonts[key] then
        local f=CreateFont("WECMacro"..key);f:CopyFontObject(_G[role]);local path,_,flags=_G[role]:GetFont();f:SetFont(path,size,flags);S.fonts[key]=f
    end
    return S.fonts[key]
end
function S.Panel(parent,color)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    f:SetBackdropColor(unpack(color or {.065,.075,.072,1}));f:SetBackdropBorderColor(.44,.35,.18,1)
    return f
end
function S.Place(frame,x,y,w,h)
    frame:ClearAllPoints();frame:SetPoint("TOPLEFT",x*S.x,-y*S.y);frame:SetSize(w*S.x,h*S.y)
end
function S.Button(parent,kind)
    local b
    if kind=="primary" then b=W.Theme.SettingsButton(parent,"",function()end)
    else
        b=CreateFrame("Button",nil,parent,kind~="tab" and "BackdropTemplate" or nil)
        -- Native tab artwork supplies its own face and border.
        if kind~="tab" then
            b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
            b:SetBackdropColor(.105,.115,.10,1);b:SetBackdropBorderColor(.42,.36,.22,1)
        end
        b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2","ADD")
        b:SetFontString(W.Theme.Label(b,""))
        b.prompt=CreateFrame("Frame",nil,b);b.prompt.icons={};b.prompt.plus=b.prompt:CreateTexture(nil,"OVERLAY");b.prompt.plus:SetAtlas("gamepad-symbols-plus");b.prompt.plus:Hide()
        b.focus=b:CreateTexture(nil,"OVERLAY");b.focus:SetAllPoints();b.focus:SetColorTexture(1,.72,.15,.16);b.focus:Hide()
        b:SetScript("OnDisable",function()b:SetAlpha(.4)end);b:SetScript("OnEnable",function()b:SetAlpha(1)end)
    end
    b.edge=S.Panel(b,{0,0,0,0});b.edge:SetPoint("TOPLEFT",-2,2);b.edge:SetPoint("BOTTOMRIGHT",2,-2);b.edge:SetBackdropBorderColor(1,.76,.22,1);b.edge:Hide()
    b.cardIcon=b:CreateTexture(nil,"ARTWORK");b.cardIcon:Hide()
    b.caret=b:CreateTexture(nil,"ARTWORK");b.caret:SetAtlas("common-dropdown-a-button");b.caret:SetSize(20,21);b.caret:SetPoint("RIGHT",-12,0);b.caret:Hide()
    b.subtitle=W.Theme.Label(b,"");b.subtitle:Hide()
    return b
end
function S.Paint(b)
    b:SetNormalFontObject(S.Font(b.tabSelected and "GameFontHighlight" or "GameFontNormal"));b:SetHighlightFontObject(S.Font("GameFontHighlight"));b:SetDisabledFontObject(S.Font("GameFontDisable"))
    local label=b:GetFontString();label:SetWordWrap(true)
    b.caret:SetShown(b.dropdown==true)
    if b.dropdown then
        -- Reserve distinct slots for the controller hint and menu affordance.
        b.prompt:ClearAllPoints();b.prompt:SetPoint("LEFT",12,0)
    end
    if b.tabArt then
        -- Theme.Prompt aligns text and device hints inside the native tab.
        b.cardIcon:Hide();b.subtitle:Hide()
    elseif b.card then
        local inset=b.texture and 58 or 14
        label:ClearAllPoints();label:SetPoint("TOPLEFT",inset,b.detail and -10 or -5);label:SetPoint("TOPRIGHT",-36,b.detail and -10 or -5);label:SetHeight(b.detail and 24 or b:GetHeight()-10);label:SetJustifyH("LEFT")
        b.subtitle:ClearAllPoints();b.subtitle:SetPoint("TOPLEFT",inset,-37);b.subtitle:SetPoint("BOTTOMRIGHT",-14,8);b.subtitle:SetJustifyH("LEFT");b.subtitle:SetJustifyV("TOP");b.subtitle:SetFontObject(S.Font("GameFontHighlight",-3));b.subtitle:SetTextColor(.7,.72,.66)
        b.subtitle:SetText(b.detail or "");b.subtitle:SetShown(b.detail~=nil)
        b.cardIcon:SetTexture(b.texture or 134400);b.cardIcon:ClearAllPoints();b.cardIcon:SetPoint("LEFT",10,0);b.cardIcon:SetSize(38,38);b.cardIcon:SetShown(b.texture~=nil)
    else
        local inset=b.dropdown and 40 or 10
        b.cardIcon:Hide();b.subtitle:Hide();label:ClearAllPoints();label:SetPoint("TOPLEFT",inset,-4);label:SetPoint("BOTTOMRIGHT",-inset,4);label:SetJustifyH("CENTER");label:SetJustifyV("MIDDLE")
    end
end
-- Display-only syntax colouring. Input is escaped first, so user text can
-- never inject markup; colour runs are flat because |r does not nest.
local function code(line,base)
    line=W.Escape(line)
    if line:sub(1,1)=="#" then return "|cff9c9784"..line.."|r" end
    local out={}
    local command,rest=line:match("^(/%S+)(.*)$")
    if command then out[1]="|cff8ec5f2"..command.."|r" else rest=line end
    local position=1
    while true do
        local first,last=rest:find("%b[]",position)
        local plain=rest:sub(position,first and first-1 or -1)
        if plain~="" then out[#out+1]=base and base..plain.."|r" or plain end
        if not first then break end
        out[#out+1]="|cffa5dc94"..rest:sub(first,last).."|r";position=last+1
    end
    return table.concat(out)
end
function S.Code(text,focused)
    local lines={}
    for line in ((text or "").."\n"):gmatch("(.-)\n") do lines[#lines+1]=code(line,focused and "|cffffd100") end
    return table.concat(lines,"\n")
end
S.ready="|TInterface\\RaidFrame\\ReadyCheck-Ready:16|t "
S.notReady="|TInterface\\RaidFrame\\ReadyCheck-NotReady:16|t "
function S.Dropdown(b)
    b.dropdown=true;S.Paint(b);return b
end
function S.Card(b,detail,texture)
    b.card=true;b.detail=detail;b.texture=texture;S.Paint(b);return b
end
function S.Selected(b,selected)
    b.edge:SetShown(selected and not b.tabArt)
    if b.tabArt then
        b.focus:ClearAllPoints();b.focus:SetPoint("BOTTOMLEFT");b.focus:SetPoint("BOTTOMRIGHT");b.focus:SetHeight(b.tabSelected and 34 or 28)
    end
    if b.SetBackdropBorderColor and not b.tabArt then b:SetBackdropBorderColor(selected and .95 or .42,selected and .7 or .36,selected and .22 or .22,1) end
end
