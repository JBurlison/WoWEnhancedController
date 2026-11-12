local _, W = ...
local S={x=1280/1100,y=760/688,fonts={}}
W.MacroStyle=S
local inks={ink={.16,.079,.035},secondary={.30,.15,.065},hover={.38,.12,.015}}
function S.Font(role,offset,tone)
    local size=math.max(18,W.db.fontSize or 14)+(offset or 0)
    local key=role..size..(tone or "")
    if not S.fonts[key] then
        local f=CreateFont("WECMacro"..key)
        f:CopyFontObject(_G[role])
        local path,_,flags=_G[role]:GetFont()
        f:SetFont(path,size,flags)
        if tone then
            f:SetTextColor(unpack(inks[tone]))
            f:SetShadowOffset(0,0)
            f:SetShadowColor(0,0,0,0)
        end
        S.fonts[key]=f
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
-- All folio art is decorative and lives below the existing focusable controls.
local function art(frame,atlas,x,y,w,h,layer)
    local t=frame:CreateTexture(nil,layer or "BACKGROUND")
    t:SetAtlas(atlas)
    S.Place(t,x,y,w,h)
    return t
end
local function page(frame,x,y,w,h)
    local backing=frame:CreateTexture(nil,"BACKGROUND",nil,-2)
    backing:SetColorTexture(.81,.64,.42,1)
    S.Place(backing,x,y,w,h)
    local atlas="spellbook-Page-Right-C60"
    local sheet=art(frame,atlas,x,y,w,h)
    local i=C_Texture.GetAtlasInfo(atlas)
    if i then
        -- This atlas includes the dark shelf above the native spellbook.
        sheet:SetTexCoord(i.leftTexCoord,i.rightTexCoord,i.topTexCoord+(i.bottomTexCoord-i.topTexCoord)*.125,i.bottomTexCoord)
    end
end
function S.Folio(frame)
    if frame.border.Bg then frame.border.Bg:Hide() end
    local _,class=UnitClass("player")
    local atlas="talent-background-"..(class or "WARLOCK"):lower()
    if not C_Texture.GetAtlasInfo(atlas) then atlas="talents-background-warlock-affliction" end
    local library=art(frame,atlas,7,79,230,553)
    -- Crop the wide talent illustration to the library's aspect ratio.
    local info=C_Texture.GetAtlasInfo(atlas)
    if info and info.leftTexCoord then
        local span=info.rightTexCoord-info.leftTexCoord
        -- Forever's class painting contains three specializations side by side.
        local mid=info.leftTexCoord+span/6
        local half=span*.5*(library:GetWidth()/library:GetHeight())/(info.width/info.height)
        library:SetTexCoord(mid-half,mid+half,info.topTexCoord,info.bottomTexCoord)
    end
    library:SetVertexColor(.94,.94,.94)
    page(frame,237,79,856,553)
    art(frame,"_UI-Frame-TitleTileBg",7,6,1086,34)
    art(frame,"_UI-Frame-TitleTile",7,5,1086,36,"BORDER")
    local rail=art(frame,"_UI-Frame-TitleTileBg",7,40,1086,39)
    rail:SetVertexColor(.64,.58,.53)
    art(frame,"_UI-Frame-TitleTileBg",7,632,1086,49)
    art(frame,"spellbook-divider",251,164,822,9,"BORDER")
    art(frame,"Talents-divider-vertical-c60",795,181,2,431,"BORDER")
    local portrait=frame:CreateTexture(nil,"ARTWORK")
    portrait:SetTexture("Interface\\Icons\\INV_Scroll_03")
    S.Place(portrait,13,7,50,51)
    local mask=frame:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    mask:SetAllPoints(portrait)
    portrait:AddMaskTexture(mask)
    art(frame,"Talents-Main-Ring-c60",5,-1,66,67,"OVERLAY")
end
function S.Dialog(frame)
    if frame.border.Bg then frame.border.Bg:Hide() end
    page(frame,5,5,610,574)
    art(frame,"spellbook-divider",22,52,576,8,"BORDER")
end
function S.Button(parent,kind)
    local b=W.Theme.Button(parent,"",nil,kind=="primary")
    if kind=="row" or kind=="tab" or kind=="icon" then
        b:ClearNormalTexture();b:ClearPushedTexture()
        b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2","ADD")
    elseif kind=="button" then
        W.Theme.KeyboardButton(b,"controller")
    end
    b.edge=S.Panel(b,{0,0,0,0});b.edge:SetPoint("TOPLEFT",-2,2);b.edge:SetPoint("BOTTOMRIGHT",2,-2);b.edge:SetBackdropBorderColor(1,.76,.22,1);b.edge:Hide()
    b.cardIcon=b:CreateTexture(nil,"ARTWORK");b.cardIcon:Hide()
    if kind=="row" then
        b.selection=b:CreateTexture(nil,"BACKGROUND")
        b.selection:SetAllPoints();b.selection:SetColorTexture(.76,.46,.06,.42);b.selection:Hide()
        b.pointer=b:CreateTexture(nil,"OVERLAY")
        b.pointer:SetAtlas("gamepad-largecursor")
        b.pointer:SetSize(24,40);b.pointer:SetPoint("LEFT",0,0);b.pointer:Hide()
        b.iconFrame=b:CreateTexture(nil,"OVERLAY")
        b.iconFrame:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        b.iconFrame:SetPoint("CENTER",b.cardIcon,"CENTER");b.iconFrame:SetSize(64,64)
    end
    b.caret=b:CreateTexture(nil,"OVERLAY",nil,5);b.caret:SetAtlas("common-dropdown-a-button");b.caret:SetSize(24,24);b.caret:SetPoint("RIGHT",-10,0);b.caret:Hide()
    b.subtitle=W.Theme.Label(b,"");b.subtitle:Hide()
    return b
end
function S.Paint(b)
    local paper=b.card and not b.library
    b:SetNormalFontObject(S.Font((b.card or b.tabSelected) and "GameFontHighlight" or "GameFontNormal",0,paper and "ink" or nil))
    b:SetHighlightFontObject(S.Font("GameFontHighlight",0,paper and "hover" or nil));b:SetDisabledFontObject(S.Font("GameFontDisable"))
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
        local inset=b.texture and 74 or 24
        label:ClearAllPoints();label:SetPoint("TOPLEFT",inset,b.detail and -10 or -5);label:SetPoint("TOPRIGHT",-36,b.detail and -10 or -5);label:SetHeight(b.detail and 24 or b:GetHeight()-10);label:SetJustifyH("LEFT")
        b.subtitle:ClearAllPoints();b.subtitle:SetPoint("TOPLEFT",inset,-37);b.subtitle:SetPoint("BOTTOMRIGHT",-12,4);b.subtitle:SetJustifyH("LEFT");b.subtitle:SetJustifyV("TOP");b.subtitle:SetFontObject(S.Font("GameFontHighlight",-2,paper and "secondary" or nil))
        b.subtitle:SetText(b.detail or "");b.subtitle:SetShown(b.detail~=nil)
        b.cardIcon:SetTexture(b.texture or 134400);b.cardIcon:ClearAllPoints();b.cardIcon:SetPoint("LEFT",24,0);b.cardIcon:SetSize(38,38);b.cardIcon:SetShown(b.texture~=nil)
        b.iconFrame:SetShown(b.texture~=nil)
    else
        local inset=b.dropdown and 34 or 10
        b.cardIcon:Hide();b.subtitle:Hide();label:ClearAllPoints();label:SetPoint("TOPLEFT",inset,-4);label:SetPoint("BOTTOMRIGHT",-inset,4);label:SetJustifyH("CENTER");label:SetJustifyV("MIDDLE")
    end
end
-- Display-only syntax colouring. Input is escaped first, so user text can
-- never inject markup; colour runs are flat because |r does not nest.
local function code(line,base)
    line=W.Escape(line)
    if line:sub(1,1)=="#" then return "|cff634320"..line.."|r" end
    local out={}
    local command,rest=line:match("^(/%S+)(.*)$")
    if command then out[1]="|cff193f68"..command.."|r" else rest=line end
    local position=1
    while true do
        local first,last=rest:find("%b[]",position)
        local plain=rest:sub(position,first and first-1 or -1)
        if plain~="" then out[#out+1]=base and base..plain.."|r" or plain end
        if not first then break end
        out[#out+1]="|cff264c2b"..rest:sub(first,last).."|r";position=last+1
    end
    return table.concat(out)
end
function S.Code(text,focused)
    local lines={}
    for line in ((text or "").."\n"):gmatch("(.-)\n") do lines[#lines+1]=code(line,focused and "|cff852f08") end
    return table.concat(lines,"\n")
end
S.ready="|TInterface\\RaidFrame\\ReadyCheck-Ready:16|t "
S.notReady="|TInterface\\RaidFrame\\ReadyCheck-NotReady:16|t "
function S.Dropdown(b)
    b.dropdown=true;S.Paint(b);return b
end
function S.Card(b,detail,texture,library)
    b.card=true;b.detail=detail;b.texture=texture;b.library=library;S.Paint(b);return b
end
function S.Selected(b,selected)
    b.edge:SetShown(selected and not b.keyboardArt and not b.tabArt and not b.card)
    if b.pointer then b.pointer:SetShown(selected) end
    if b.tabArt then
        b.focus:ClearAllPoints();b.focus:SetPoint("BOTTOMLEFT");b.focus:SetPoint("BOTTOMRIGHT");b.focus:SetHeight(b.tabSelected and 34 or 28)
    end
end
