local _, W = ...
local R = { cells = {}, elapsed = 0 }
W.Radial = R
local function safe(fn, ...)
    if not fn then return end
    local ok, a, b = pcall(fn, ...)
    if ok and not W.Secret(a) and not W.Secret(b) then return a, b end
end
local function icon(parent, size)
    local texture = parent:CreateTexture(nil, "OVERLAY")
    texture:SetSize(size, size)
    return texture
end
local function healthBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height); bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1); bar:SetValue(0); bar:EnableMouse(false)
    return bar
end
local function auraRow(parent, size, limit)
    local row = { icons = {}, size = size }
    for i = 1, limit do
        local art = icon(parent, size)
        local border = icon(parent, size + 2)
        border:SetPoint("CENTER", art); border:SetAtlas("ui-debuff-border-magic-noicon")
        art:Hide(); border:Hide()
        row.icons[i] = { art = art, border = border }
    end
    row.more = W.Theme.Label(parent, "", "GameFontHighlightSmall")
    row.more:Hide()
    return row
end
function R:PaintAuras(row, parent, x, y, auras)
    local count = math.min(#auras, #row.icons)
    for i, item in ipairs(row.icons) do
        local aura = auras[i]
        item.art:ClearAllPoints(); item.art:SetPoint("CENTER", parent, "CENTER", x + (i - (count + 1) / 2) * (row.size + 3), y)
        item.art:SetShown(aura ~= nil); item.border:SetShown(aura ~= nil)
        if aura then
            item.art:SetTexture(aura.icon)
            item.art:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            item.border:SetAtlas("ui-debuff-border-" .. aura.kind:lower() .. "-noicon")
        end
    end
    row.more:ClearAllPoints(); row.more:SetPoint("CENTER", parent, "CENTER", x, y - row.size / 2 - 8)
    row.more:SetText(#auras > count and W.L.Format("+%d", #auras - count) or "")
    row.more:SetShown(#auras > count)
end
function R:Init()
    W.RadialData.Init()
    if W.Combat() then self.pendingInit = true; return end
    self.pendingInit = nil
    if not SecureHandlerWrapScript or not SecureHandlerExecute or not SetOverrideBindingClick then
        self.failure = W.L["Secure wheel templates are unavailable in this client."]
        return
    end
    local frame = CreateFrame("Frame", "WoWEnhancedControllerWheel", UIParent, "SecureHandlerStateTemplate")
    self.frame = frame
    frame:Hide(); frame:SetFrameStrata("DIALOG"); frame:EnableMouse(false)
    -- Like Forever's SoftCursor, consume Camera and pass every other stick on.
    -- This child follows the secure wheel's visibility even during lockdown.
    local stickListener = CreateFrame("Frame", nil, frame)
    stickListener:SetScript("OnGamepadStick", function(_, stick, x, y)
        return self:StickInput(stick, x, y)
    end)
    stickListener:EnableGamePadStick(true)
    W.Placement.Register("radial", frame, W.L["Party / raid wheel"], { anchor = "center", x = 0, y = 0 })
    for key, body in pairs(W.RadialSecure) do if type(body) == "string" then frame:SetAttribute("op-" .. key, body) end end
    frame:SetAttribute("_onstate-availability", [[
        if newstate == "blocked" then self:RunAttribute("op-close") end
    ]])
    RegisterStateDriver(frame, "availability", "[petbattle][vehicleui] blocked; ready")
    frame.Paint = function() self:Paint() end
    frame.StageChanged = function() self.hover=nil;self:ResetGesture();self:Paint() end
    frame.Edit = function() self:Edit() end
    frame.Whisper = function(_,unit) self:Whisper(unit) end
    self.ring = frame:CreateTexture(nil, "ARTWORK"); self.ring:SetPoint("CENTER")
    self.ring:SetAtlas("gamepad-radial-menu-wheelbg")
    self.highlight = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    self.highlight:SetAtlas("gamepad-radial-menu-selected")
    self.title=W.Theme.Label(frame,"","GameFontHighlightLarge")
    self.headerArt=frame:CreateTexture(nil,"BACKGROUND");self.headerArt:SetAtlas("gamepad-radial-menu-toptext")
    self.footerArt=frame:CreateTexture(nil,"BACKGROUND");self.footerArt:SetAtlas("gamepad-radial-menu-bottomtext")
    self.centerTag = W.Theme.Label(frame, "", "GameFontHighlightSmall"); self.centerTag:SetPoint("CENTER", 0, 46)
    self.center = W.Theme.Label(frame, ""); self.center:SetPoint("CENTER", 0, 16); self.center:SetSize(180, 50)
    self.centerDetail = W.Theme.Label(frame, "", "GameFontHighlightSmall"); self.centerDetail:SetPoint("CENTER", 0, -24)
    self.centerDetail:SetSize(180, 34)
    self.centerGlyph = icon(frame, 24); self.centerGlyph:SetPoint("CENTER", 0, -66)
    self.confirmGlyphs = { icon(frame, 24), icon(frame, 24) }
    self.confirmGlyphs[1]:SetPoint("CENTER", -19, -66)
    self.confirmGlyphs[2]:SetPoint("CENTER", 19, -66)
    self.confirmSeparator = W.Theme.Label(frame, "/", "GameFontHighlightSmall")
    self.confirmSeparator:SetPoint("CENTER", 0, -66)
    self.selectLabel=W.Theme.Label(frame,W.L["Select"])
    self.backGlyph=icon(frame,24);self.backLabel=W.Theme.Label(frame,W.L["Back"])
    self.backDpadGlyph=icon(frame,24);self.backSeparator=W.Theme.Label(frame,"/","GameFontHighlightSmall")
    self.raidGlyph=icon(frame,24);self.raidLabel=W.Theme.Label(frame,W.L["Raid"])
    self.membersGlyph=icon(frame,24);self.membersLabel=W.Theme.Label(frame,"")
    self.pageDots={}
    for i=1,9 do self.pageDots[i]=icon(frame,14) end
    self.pageButtons={}
    for i,command in ipairs({"PagePrevious","PageNext"}) do
        local b=CreateFrame("Button",nil,frame,"SecureActionButtonTemplate")
        b:SetSize(28,28);b:SetAttribute("command",command);b.art=icon(b,26);b.art:SetPoint("CENTER")
        W.RadialSecure.Attach(b,frame);self.pageButtons[i]=b;frame:SetFrameRef("page-button-"..i,b)
    end
    self.centerHealth = W.Theme.Label(frame, "", "GameFontHighlightSmall"); self.centerHealth:SetPoint("CENTER", 0, -44)
    self.centerBar=healthBar(frame,84,4);self.centerBar:SetPoint("CENTER",0,18)
    self.centerHealth:ClearAllPoints(); self.centerHealth:SetPoint("CENTER", 0, -8); self.centerHealth:SetSize(180, 42)
    self.centerAuras = auraRow(frame, 22, 5)
    self.groupHealthRows = {}
    for i = 1, 5 do
        local label = W.Theme.Label(frame, "", "GameFontHighlightSmall")
        label:SetPoint("CENTER", 0, 14 - (i - 1) * 22); label:SetSize(200, 22); label:Hide()
        self.groupHealthRows[i] = label
    end
    self.pageLabel = W.Theme.Label(frame, "", "GameFontHighlightSmall"); self.pageLabel:SetPoint("CENTER", 0, -82)
    local dispatch = CreateFrame("Button", "WoWEnhancedControllerWheelInput", UIParent, "SecureActionButtonTemplate")
    dispatch:SetSize(1, 1); dispatch:SetPoint("TOPLEFT"); dispatch:SetAlpha(0); dispatch:EnableMouse(false)
    self.dispatch = dispatch; frame:SetFrameRef("dispatch", dispatch)
    W.RadialSecure.Attach(dispatch, frame)
    local macroToggle = CreateFrame("Button", "WoWEnhancedControllerWheelToggle", UIParent, "SecureActionButtonTemplate")
    macroToggle:SetSize(1, 1); macroToggle:SetPoint("TOPLEFT"); macroToggle:SetAlpha(0); macroToggle:EnableMouse(false)
    macroToggle:SetAttribute("command", "ToggleMacro")
    W.RadialSecure.Attach(macroToggle, frame)
    self.macroToggle = macroToggle
    for _, mode in ipairs({"Classic", "Sweep"}) do
        local opener = CreateFrame("Button", "WoWEnhancedControllerWheel" .. mode, UIParent, "SecureActionButtonTemplate")
        opener:SetSize(1, 1); opener:SetPoint("TOPLEFT"); opener:SetAlpha(0); opener:EnableMouse(false)
        opener:SetAttribute("command", mode .. "Macro")
        W.RadialSecure.Attach(opener, frame)
    end
    self:CreateSweep(frame)
    self.sweepAuras=auraRow(self.sweepLayer,14,4)
    self.inputEpoch=CreateFrame("Frame",nil,UIParent)
    frame:SetFrameRef("input-epoch",self.inputEpoch)
    for i = 1, 9 do
        local cell = CreateFrame("Button", "WoWEnhancedControllerWheelCell" .. i, frame, "SecureActionButtonTemplate")
        cell:SetAttribute("index", i); cell:SetSize(94, 84)
        cell.art = icon(cell, 32); cell.art:SetPoint("CENTER")
        cell.label = W.Theme.Label(cell, ""); cell.label:SetPoint("TOP", 0, -29); cell.label:SetSize(94, 34)
        cell.detail = W.Theme.Label(cell, "", "GameFontHighlightSmall"); cell.detail:SetPoint("TOP", 0, -64); cell.detail:SetSize(94, 18)
        cell.bar = healthBar(cell, 74, 3)
        cell.bar:SetPoint("BOTTOMLEFT", 10, -3); cell.bar:SetSize(74, 3)
        cell.auras = auraRow(cell, 15, 4)
        cell.groupBars = {}
        for j = 1, 5 do
            local track = cell:CreateTexture(nil, "OVERLAY")
            track:SetPoint("BOTTOMLEFT", 6 + (j - 1) * 17, -1); track:SetSize(14, 5)
            track:SetColorTexture(0.13, 0.13, 0.13, 1)
            local fill = healthBar(cell, 14, 5)
            fill:SetPoint("LEFT", track, "LEFT"); fill:SetSize(14, 5)
            cell.groupBars[j] = { track = track, fill = fill }
        end
        cell:SetScript("OnEnter", function() self.hover = i; self:Paint() end)
        cell:SetScript("OnLeave", function() self.hover = nil; self:Paint() end)
        W.RadialSecure.Attach(cell, frame)
        self.cells[i] = cell; frame:SetFrameRef("cell" .. i, cell)
    end
    self.base = CreateFrame("Frame", nil, UIParent)
    -- Always-visible secure header invalidates token snapshots on EVERY native
    -- roster refresh, even when a raidN string stays the same for a new person.
    local watcher = CreateFrame("Frame", "WoWEnhancedControllerRosterGuard", UIParent, "SecureGroupHeaderTemplate")
    watcher:Hide(); watcher:SetSize(1, 1); watcher:SetPoint("TOPLEFT"); watcher:SetAlpha(0)
    watcher:SetAttribute("_ignore", true)
    SecureHandlerSetFrameRef(watcher, "wheel", frame)
    watcher:SetAttribute("template", "SecureHandlerBaseTemplate")
    watcher:SetAttribute("templateType", "Frame")
    watcher:SetAttribute("initialConfigFunction", [[
        self:SetWidth(1); self:SetHeight(1)
        self:SetAttribute("refreshUnitChange", 'self:GetParent():GetFrameRef("wheel"):RunAttribute("op-invalidate")')
    ]])
    watcher:SetAttribute("showRaid", true); watcher:SetAttribute("showParty", true)
    watcher:SetAttribute("showPlayer", true); watcher:SetAttribute("showSolo", true)
    watcher:SetAttribute("_ignore", nil); watcher:Show()
    self.watcher = watcher
    frame:SetScript("OnUpdate", function(_, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 0.05 then self.elapsed = 0; self:Paint() end
    end)
    frame:SetScript("OnShow", function() self:ResetGesture() end)
    frame:SetScript("OnHide", function() self.hover = nil; self:ResetGesture(true) end)
    -- Native Escape/parent hides must clear the restricted bindings too, even
    -- when they bypass R:Close. The secure wrapper also runs during combat.
    SecureHandlerWrapScript(frame, "OnHide", frame, 'self:RunAttribute("op-close")')
    self:Rebuild()
end
function R:Rebuild()
    if not self.frame or W.Combat() then self.pending = true; return end
    self.pending = nil
    self.defaultShortcut = W.ControlBindings.DefaultR3()
    local f, D = self.frame, W.RadialData
    SecureHandlerExecute(f, 'self:RunAttribute("op-close")')
    local profile=D.Profile()
    self.snapshot = D.Snapshot(); self.actions = W.Copy(profile.actions); self.pages=W.Copy(profile.pages);self.pageSlots={};self.auraCache = {}
    for id=-4,4 do
        f:SetAttribute("page-next-"..id,nil);f:SetAttribute("page-previous-"..id,nil)
        for slot=1,8 do f:SetAttribute("page-slot-"..id.."-"..slot,nil) end
    end
    for i,id in ipairs(self.pages) do
        f:SetAttribute("page-next-"..id,self.pages[i+1]);f:SetAttribute("page-previous-"..id,self.pages[i-1])
        self.pageSlots[id]=D.PageSlots(id,profile)
        for slot,index in pairs(self.pageSlots[id]) do f:SetAttribute("page-slot-"..id.."-"..slot,index) end
    end
    f:SetAttribute("page-count",#self.pages)
    self.actionMeta = {}
    for a, action in ipairs(self.actions) do
        local info = action.kind == "spell" and D.SpellInfo(action)
        self.actionMeta[a] = { spell = info and info.spellID }
    end
    local s = self.snapshot
    f:SetAttribute("raid", s.raid); f:SetAttribute("member-count", #s.members)
    f:SetAttribute("solo", not IsInGroup() and not s.raid and #s.members == 1 and s.members[1].unit == "player")
    f:SetAttribute("action-count", math.min(#self.actions, D.maxActions))
    f:SetAttribute("enabled", W.db.enabled and W.db.radial.enabled)
    f:SetAttribute("after-action", W.db.radial.afterAction)
    f:SetAttribute("default-mode", W.db.radial.behavior)
    W.ControlBindings.ConfigureWheel(f,s.raid)
    f:SetAttribute("primary", W.Input:Style() == "Nintendo" and W.db.swapNintendo and "PAD2" or "PAD1")
    f:SetAttribute("back", W.Input:Style() == "Nintendo" and W.db.swapNintendo and "PAD1" or "PAD2")
    self.boundStyle, self.boundSwap = W.Input:Style(), W.db.swapNintendo
    self.boundFont, self.boundScale, self.boundSize = W.db.fontSize, W.db.scale, W.db.radial.size
    local camera = 2
    local state = W.Input:Device()
    if state and C_GamePad.StickIndexToConfigName then
        for i = 1, state.stickCount or #(state.sticks or {}) do
            if safe(C_GamePad.StickIndexToConfigName, i - 1) == "Camera" then camera = i; break end
        end
    end
    f:SetAttribute("camera-index", camera)
    f:SetAttribute("radius", W.db.radial.size * 128/540)
    for group, members in ipairs(s.groups) do
        f:SetAttribute("group-count-" .. group, #members)
        for i = 1, 5 do f:SetAttribute("group-" .. group .. "-" .. i, members[i]) end
    end
    for i = 1, 40 do
        local member = s.members[i]
        f:SetAttribute("unit-" .. i, member and member.unit)
        for a = 1, D.maxActions do
            local kind, value
            if member and self.actions[a] then
                local texture
                kind, value, texture = D.Compile(self.actions[a], member.unit)
                self.actionMeta[a].icon, self.actionMeta[a].valid = texture, kind ~= nil
            end
            f:SetAttribute("kind-" .. i .. "-" .. a, kind); f:SetAttribute("value-" .. i .. "-" .. a, value)
        end
    end
    f:SetAttribute("roster-valid", true)
    f:SetSize(W.db.radial.size, W.db.radial.size+(s.raid and 240 or 180))
    f:SetScale(math.min(W.db.scale, (UIParent:GetWidth() - 40) / f:GetWidth(), (UIParent:GetHeight() - 40) / f:GetHeight()))
    for _, label in ipairs({ self.centerTag, self.center, self.centerDetail, self.centerHealth, self.pageLabel,
        self.title, self.selectLabel, self.backLabel, self.raidLabel, self.membersLabel }) do
        label:SetFontObject(W.Theme.Font("GameFontNormal"))
    end
    for _, label in ipairs(self.groupHealthRows) do label:SetFontObject(W.Theme.Font("GameFontHighlightSmall")) end
    self.ring:SetSize(W.db.radial.size, W.db.radial.size)
    self:LayoutSweep(W.db.radial.size)
    local size=W.db.radial.size;local half=size/2
    self.highlight:SetSize(size*169/540,size*165/540)
    self.title:ClearAllPoints();self.title:SetPoint("CENTER",0,half+72);self.title:SetSize(size,30)
    self.pageLabel:ClearAllPoints();self.pageLabel:SetPoint("CENTER",0,half+104);self.pageLabel:Hide()
    self.headerArt:SetSize(size,54);self.headerArt:SetPoint("CENTER",0,half+40)
    self.footerArt:SetSize(size,s.raid and 134 or 100);self.footerArt:SetPoint("CENTER",0,-half-(s.raid and 71 or 54))
    self.confirmGlyphs[1]:ClearAllPoints();self.confirmGlyphs[1]:SetPoint("CENTER",-62,-half-32)
    self.confirmGlyphs[2]:ClearAllPoints();self.confirmGlyphs[2]:SetPoint("CENTER",-12,-half-32)
    self.confirmSeparator:ClearAllPoints();self.confirmSeparator:SetPoint("CENTER",-37,-half-32)
    self.selectLabel:SetPoint("CENTER",48,-half-32)
    self.backGlyph:SetPoint("CENTER",-62,-half-66);self.backLabel:SetPoint("CENTER",48,-half-66)
    self.backDpadGlyph:SetPoint("CENTER",-12,-half-66);self.backSeparator:SetPoint("CENTER",-37,-half-66)
    self.raidGlyph:SetPoint("CENTER",-132,-half-100);self.raidLabel:SetPoint("LEFT",self.raidGlyph,"RIGHT",6,0)
    self.membersGlyph:SetPoint("CENTER",20,-half-100);self.membersLabel:SetPoint("LEFT",self.membersGlyph,"RIGHT",6,0)
    local extent=0;for _,id in ipairs(self.pages) do extent=math.max(extent,math.abs(id)) end
    for i,b in ipairs(self.pageButtons) do
        b:ClearAllPoints();b:SetPoint("CENTER",(i==1 and -1 or 1)*(extent*21+38),half+40)
    end
    -- Keep text/icon separation in font units when shrinking the wheel. Scaling
    -- label offsets with the ring caused large text to overlap the icons.
    local anchors={{0,60},{30,45},{60,0},{30,-65},{0,-65},{-30,-65},{-60,0},{-30,45},{0,60}}
    for i,cell in ipairs(self.cells) do
        cell.label:ClearAllPoints();cell.label:SetPoint("CENTER",anchors[i][1],anchors[i][2])
        cell.label:SetSize((i==3 or i==7) and 80 or 90,44)
        cell.detail:ClearAllPoints();cell.detail:SetPoint("CENTER",0,-28);cell.detail:SetSize(90,22)
        cell.bar:ClearAllPoints();cell.bar:SetPoint("CENTER",0,-21);cell.bar:SetWidth(54)
        for j,bar in ipairs(cell.groupBars) do bar.track:ClearAllPoints();bar.track:SetPoint("CENTER",(j-3)*15,-26) end
    end
    W.Placement.Apply("radial"); self:SyncOwnership()
end
function R:SyncOwnership()
    if not self.frame or W.Combat() then return end
    if self.boundStyle ~= W.Input:Style() or self.boundSwap ~= W.db.swapNintendo
        or self.boundFont ~= W.db.fontSize or self.boundScale ~= W.db.scale or self.boundSize ~= W.db.radial.size then self:Rebuild(); return end
    local blocked = not W.db.enabled or not W.db.radial.enabled or W.Focus() or W.Blocker()
        or W.Placement.editing or W.Keyboard.frame:IsShown() or (self.editor and self.editor:IsShown())
        or (W.MacroEditor and W.MacroEditor.frame and W.MacroEditor.frame:IsShown())
        or (W.Launcher and W.Launcher:IsShown())
        or (SettingsPanel and SettingsPanel:IsShown())
    local acquire = not blocked
    local defaultR3 = W.db.radial.defaultR3 and self.defaultShortcut
    local bindDefault = acquire and defaultR3
    if self.baseBound ~= bindDefault then
        ClearOverrideBindings(self.base)
        if bindDefault then SetOverrideBindingClick(self.base, false, "PADRSTICK", self.dispatch:GetName(), "Toggle") end
        self.baseBound = bindDefault
    end
    self.frame:SetAttribute("default-r3", defaultR3)
    self.frame:SetAttribute("enabled", acquire and true or false)
    if blocked and self.frame:GetAttribute("open") then self:Close() end
end
function R:Close()
    if self.frame and not W.Combat() then SecureHandlerExecute(self.frame, 'self:RunAttribute("op-close")') end
end
function R:InputChanged()
    if self.inputEpoch then
        self.inputEpoch:SetAttribute("revision",(self.inputEpoch:GetAttribute("revision") or 0)+1)
    end
    self:ResetGesture(true)
end
function R:Open()
    if not self.frame then W.Print(self.failure or W.L["Wheel unavailable."]); return end
    if W.Combat() then W.Print(W.L["Use the wheel keybinding or /click macro during combat."]); return end
    if W.Focus() then W.Call(W.Focus(), "ClearFocus") end
    W.Keyboard:Close()
    if self.editor and self.editor:IsShown() then self:CloseEditor() end
    self:SyncOwnership()
    SecureHandlerExecute(self.frame, 'self:RunAttribute("op-open")')
end
function R:Entry(index)
    local f, s = self.frame, self.snapshot
    local stage, group, member, page = f:GetAttribute("stage"), f:GetAttribute("group") or 1, f:GetAttribute("member"), f:GetAttribute("page") or 0
    if stage == "root" then
        if s.raid then
            return { label = W.L.Format("Group %d", index), group = s.groups[index], icon = "group", disabled = #s.groups[index] == 0 }
        else member = index end
    elseif stage == "members" then member = s.groups[group][index]
    else
        local a = self.pageSlots[page] and self.pageSlots[page][index]
        local action = self.actions[a]
        if action then
            local meta = self.actionMeta[a] or {}
            local detail = action.kind == "spell" and W.L["Spell"] or action.kind=="friendly" and "" or W.L["Macro"]
            if meta.spell then
                local usable, power = safe(C_Spell.IsSpellUsable, meta.spell)
                local range = safe(C_Spell.IsSpellInRange, meta.spell, s.members[member].unit)
                if power then detail = W.L["No power"] elseif usable == false then detail = W.L["Unusable"] elseif range == false then detail = W.L["Out of range"]
                else
                    local cooldown = safe(C_Spell.GetSpellCooldown, meta.spell)
                    if cooldown and not W.Secret(cooldown.startTime) and not W.Secret(cooldown.duration)
                        and type(cooldown.startTime) == "number" and type(cooldown.duration) == "number" then
                        local left = cooldown.startTime + cooldown.duration - GetTime()
                        if left > 0 then detail = W.L.Format("%.1fs", left) end
                    end
                end
            end
            return { label = action.label, detail = detail, icon = meta.icon or 134400,
                disabled = not meta.valid or action.kind=="friendly" and action.value=="whisper" and W.Combat() }
        end
        return {label="",icon=nil,disabled=true,empty=true}
    end
    local m = member and s.members[member]
    if not m then return { label = W.L["Unavailable"], icon = 134400, disabled = true } end
    return { label = m.unit == "player" and W.L["You"] or m.name, detail = m.className or m.class,
        class = m.class, icon = "class", unit = m.unit, member = m,
        disabled = safe(UnitIsConnected, m.unit) == false or safe(UnitExists, m.unit) == false }
end
-- Secret values may be presented by these native widget APIs. They must not
-- pass through safe(), string.format, arithmetic or concatenated roster text.
function R:PaintHealth(text, bar, member, full, name)
    if not member then if text then text:SetText("") end; if bar then bar:Hide() end; return end
    local unit = member.unit
    local status = safe(UnitIsConnected, unit) == false and W.L["Offline"]
        or safe(UnitIsDeadOrGhost, unit) and W.L["Dead"]
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.class]
    if bar then
        bar:SetStatusBarColor(status == W.L["Dead"] and 0.8 or color and color.r or 0.78,
            status == W.L["Dead"] and 0.15 or color and color.g or 0.65,
            status == W.L["Dead"] and 0.15 or color and color.b or 0.32)
    end
    if status then
        if text then text:SetFormattedText(name and "%s · %s" or "%s", name or status, name and status or nil) end
        if bar then bar:SetMinMaxValues(0, 1); bar:SetValue(status == W.L["Dead"] and 1 or 0); bar:Show() end
        return
    end
    local ok, health = pcall(UnitHealth, unit)
    local okMax, maximum = pcall(UnitHealthMax, unit)
    local valid = ok and okMax and (W.Secret(health) or type(health) == "number")
        and (W.Secret(maximum) or type(maximum) == "number" and maximum > 0)
    if not valid then
        if text then text:SetFormattedText(name and "%s · %s" or "%s", name or W.L["Unknown"], name and W.L["Unknown"] or nil) end
        if bar then bar:Hide() end
        return
    end
    if bar then bar:SetMinMaxValues(0, maximum); bar:SetValue(health); bar:Show() end
    if not text then return end
    local percent, hasPercent
    if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        local percentOk, value = pcall(UnitHealthPercent, unit, true, CurveConstants.ScaleTo100)
        if percentOk and (W.Secret(value) or type(value) == "number") then percent, hasPercent = value, true end
    elseif not W.Secret(health) and not W.Secret(maximum) then percent, hasPercent = health / maximum * 100, true end
    if full then
        if hasPercent then text:SetFormattedText(W.L["%d/%d\n%.0f%%"], health, maximum, percent)
        else text:SetFormattedText(W.L["%d/%d"], health, maximum) end
    elseif hasPercent then
        if name then text:SetFormattedText(W.L["%s · %.0f%%"], name, percent)
        else text:SetFormattedText(W.L["%.0f%%"], percent) end
    elseif name then text:SetFormattedText(W.L["%s · %d/%d"], name, health, maximum)
    else text:SetFormattedText(W.L["%d/%d"], health, maximum) end
end
function R:Dispellable(unit)
    if not unit or not W.db.radial.debuffs then return {} end
    self.auraCache = self.auraCache or {}
    local cached, now = self.auraCache[unit], GetTime()
    if cached and now - cached.time < 0.2 then return cached.auras end
    local auras = {}
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        -- RAID restricts harmful auras to those the player can dispel, using
        -- the native spell/spec rules, not a hardcoded class/type guess.
        for i = 1, 255 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL|RAID")
            if not ok or W.Secret(aura) or aura == nil then break end
            if type(aura) ~= "table" then break end
            local kind, texture = aura.dispelName, aura.icon
            if not W.Secret(kind) and not W.Secret(texture) and type(kind) == "string" and type(texture) == "number"
                and (kind == "Magic" or kind == "Curse" or kind == "Disease" or kind == "Poison" or kind == "Bleed") then
                auras[#auras + 1] = { icon = texture, kind = kind }
            end
        end
    end
    self.auraCache[unit] = { time = now, auras = auras }
    return auras
end
function R:Point()
    local state = W.Input:Device()
    local stick = state and state.sticks and state.sticks[self.frame:GetAttribute("camera-index") or 2]
    if not stick or W.Secret(stick) or W.Secret(stick.len) or W.Secret(stick.x) or W.Secret(stick.y) or (stick.len or 0) < 0.45 then return 0 end
    local count = self.frame:GetAttribute("count") or 0
    if count == 0 then return 0 end
    local angle = (math.deg(math.atan2(stick.x, stick.y)) + 360) % 360
    local slices = self.frame:GetAttribute("dual") and self.frame:GetAttribute("stage") ~= "spells" and count or 8
    local index=math.floor(angle * slices / 360 + 0.5) % slices + 1
    return index<=count and index or 0
end
function R:GestureStage()
    local f = self.frame
    return (f:GetAttribute("stage") or "root") .. ":" .. (f:GetAttribute("group") or 0)
        .. ":" .. (f:GetAttribute("member") or 0) .. ":" .. (f:GetAttribute("page") or 1)
end
function R:ResetGesture(wait)
    self.gestureArmed = nil; self.gestureWait = true; self.gestureMessage = nil
    if not self.frame then return end
    self.gestureStage = self:GestureStage()
    if wait then return end
    local state = W.Input:Device()
    local stick = state and state.sticks and state.sticks[self.frame:GetAttribute("camera-index") or 2]
    if stick and not W.Secret(stick.len) and type(stick.len) == "number" then self.gestureWait = stick.len >= 0.2 end
end
function R:StickInput(stick, x, y)
    if stick ~= "Camera" then return true end
    if not self.frame:IsShown() or not self.frame:GetAttribute("open") then return true end
    if W.Secret(x) or W.Secret(y) or type(x) ~= "number" or type(y) ~= "number" then self:ResetGesture(true); return false end
    local lengthSq, stage = x * x + y * y, self:GestureStage()
    if stage ~= self.gestureStage then self:ResetGesture(true) end
    if W.Placement.editing or W.Focus() or W.Blocker() or SettingsPanel and SettingsPanel:IsShown()
        or not self.frame:GetAttribute("roster-valid") then self:ResetGesture(true); return false end
    if self.gestureWait then
        if lengthSq < 0.04 then self.gestureWait = false end
        return false
    end
    local count = self.frame:GetAttribute("count") or 0
    if lengthSq > 0.25 and count > 0 then
        local angle = (math.deg(math.atan2(x, y)) + 360) % 360
        local slices = self.frame:GetAttribute("dual") and self.frame:GetAttribute("stage") ~= "spells" and count or 8
        local index=math.floor(angle * slices / 360 + 0.5) % slices + 1
        self.gestureArmed = index<=count and index or nil
        self.gestureStage = stage
    elseif lengthSq < 0.04 and self.gestureArmed then
        self.gestureArmed = nil
        self.gestureReleases = (self.gestureReleases or 0) + 1
        -- The directional binding handles selection on its real key-up.
    end
    self:Paint()
    return false
end
function R:Paint()
    local f=self.frame
    if not f or not f:IsShown() or not self.snapshot then return end
    local stage,member,page=f:GetAttribute("stage") or "root",f:GetAttribute("member"),f:GetAttribute("page") or 0
    local count=f:GetAttribute("count") or 0
    local pressed=f:GetAttribute("pressed")
    local confirming=pressed=="Confirm" or pressed=="ConfirmDpad" or pressed=="ConfirmTrigger"
    local aimed = f:GetAttribute("aim-index")
    local selected=confirming and f:GetAttribute("press-index") or aimed or self.gestureArmed or self.hover or self:Point()
    if aimed == nil and (not selected or selected==0) then selected=f:GetAttribute("selected") or 0 end
    self.ring:Show()
    if selected>0 and selected<=count then
        local angle=(selected-1)*math.pi/4;local radius=W.db.radial.size*150/540
        self.highlight:ClearAllPoints();self.highlight:SetPoint("CENTER",math.sin(angle)*radius,math.cos(angle)*radius)
        self.highlight:SetRotation(-math.pi-angle);self.highlight:Show()
    else self.highlight:Hide() end
    local data
    for i=1,count do
        local cell,entry=self.cells[i],self:Entry(i)
        cell.label:SetFontObject(W.Theme.Font("GameFontNormal"));cell.detail:SetFontObject(W.Theme.Font("GameFontHighlightSmall"))
        cell.label:SetText(W.Escape(entry.label));cell.detail:SetText("")
        cell.art:SetShown(not entry.empty)
        if not entry.empty then cell.art:SetTexture(entry.icon=="class" and "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES" or entry.icon=="group" and 136122 or entry.icon) end
        cell.art:SetTexCoord(0,1,0,1)
        if entry.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[entry.class] then cell.art:SetTexCoord(unpack(CLASS_ICON_TCOORDS[entry.class])) end
        cell:SetAlpha(entry.disabled and .4 or 1)
        if entry.unit and W.db.radial.health then self:PaintHealth(nil,cell.bar,entry.member) else cell.bar:Hide() end
        self:PaintAuras(cell.auras,cell,0,-34,self:Dispellable(entry.unit))
        for j,bar in ipairs(cell.groupBars) do
            if entry.group and W.db.radial.health then
                bar.track:Show();local m=self.snapshot.members[entry.group[j]]
                if m then self:PaintHealth(nil,bar.fill,m) else bar.fill:Hide() end
            else bar.track:Hide();bar.fill:Hide() end
        end
        if selected==i then data=entry end
    end
    local recipient=member and self.snapshot.members[member]
    self.title:SetText(stage=="spells" and W.RadialData.PageName(page) or stage=="members" and W.L.Format("Group %d",f:GetAttribute("group") or 1) or self.snapshot.raid and W.L["Raid"] or W.L["Party"])
    self.centerTag:SetText("");self.centerDetail:SetText("")
    self.center:ClearAllPoints();self.center:SetPoint("CENTER",0,40);self.center:SetSize(140,48)
    self.centerHealth:ClearAllPoints();self.centerHealth:SetPoint("CENTER",0,-8);self.centerHealth:SetSize(140,44)
    self.centerHealth:SetFontObject(W.Theme.Font("GameFontHighlightSmall"))
    self.center:SetText(W.Escape(recipient and recipient.name or data and data.label or (stage=="root" and self.snapshot.raid and W.L["Choose group"] or W.L["Choose member"])))
    local statusMember=recipient or data and data.member
    if data and data.group then
        self.center:SetPoint("CENTER",0,60);self.centerHealth:SetText("");self.centerBar:Hide()
        for i,label in ipairs(self.groupHealthRows) do
            local m=self.snapshot.members[data.group[i]];label:SetShown(m~=nil and W.db.radial.health)
            label:ClearAllPoints();label:SetPoint("CENTER",0,30-(i-1)*18);label:SetWidth(140)
            if m then self:PaintHealth(label,nil,m,false,W.Escape(m.name)) end
        end
    else
        for _,label in ipairs(self.groupHealthRows) do label:Hide() end
        if W.db.radial.health then self:PaintHealth(self.centerHealth,self.centerBar,statusMember,true) else self.centerHealth:SetText("");self.centerBar:Hide() end
    end
    self:PaintAuras(self.centerAuras,f,0,-48,self:Dispellable(statusMember and statusMember.unit))
    -- Availability belongs to the highlighted action, not every wedge label.
    if stage=="spells" and data and data.detail and data.detail~="" and data.detail~=W.L["Spell"] and data.detail~=W.L["Macro"] then
        self.center:SetText(W.Escape(data.detail))
    end
    self.centerGlyph:Hide()
    local function prompt(texture,id)
        local atlas=W.Input:TokenIcon(f:GetAttribute("hint-pad-"..id))
        texture:SetShown(atlas~=nil)
        if atlas then texture:SetAtlas(atlas) end
    end
    prompt(self.confirmGlyphs[1],"ConfirmTrigger");prompt(self.confirmGlyphs[2],"ConfirmDpad")
    self.confirmSeparator:SetShown(self.confirmGlyphs[1]:IsShown() and self.confirmGlyphs[2]:IsShown())
    -- The wheel owns its Back binding independently of keyboard remaps.
    prompt(self.backGlyph,"Back");prompt(self.backDpadGlyph,"BackDpad")
    self.backSeparator:SetShown(self.backGlyph:IsShown() and self.backDpadGlyph:IsShown())
    self.backLabel:SetText((stage=="root" or f:GetAttribute("solo")) and W.L["Close"] or W.L["Back"])
    prompt(self.raidGlyph,"RaidGroups");prompt(self.membersGlyph,"RaidMembers")
    for _,region in ipairs({self.raidLabel,self.membersLabel})do region:SetShown(self.snapshot.raid)end
    if not self.snapshot.raid then self.raidGlyph:Hide();self.membersGlyph:Hide() end
    self.membersLabel:SetText(W.L.Format("Group %d",f:GetAttribute("group") or 1))
    local extent=0;for _,id in ipairs(self.pages) do extent=math.max(extent,math.abs(id)) end
    local half=W.db.radial.size/2
    for i,dot in ipairs(self.pageDots) do
        local id=i-5;local exists=self.pageSlots[id]~=nil
        dot:SetShown(stage=="spells" and math.abs(id)<=extent)
        dot:ClearAllPoints();dot:SetPoint("CENTER",id*21,half+40)
        dot:SetAtlas(id==page and "gamepad-radialgamemenu-cursorbg-neutral" or "gamepad-radialgamemenu-cursorbg-inactive")
        dot:SetAlpha(exists and 1 or .15)
    end
    for i,b in ipairs(self.pageButtons) do
        prompt(b.art,i==1 and "PagePrevious" or "PageNext")
        b:SetAlpha(f:GetAttribute((i==1 and "page-previous-" or "page-next-")..page)~=nil and 1 or .35)
    end
    self.pageLabel:SetText(stage=="spells" and W.RadialData.PageName(page) or "")
    self:PaintSweep(stage, member, page)
end
function R:Whisper(unit)
    -- Compose only. Do not overwrite an existing chat draft or transmit text.
    if W.Combat() or not UnitExists(unit) or not ChatFrameUtil or not ChatFrameUtil.SendTell then return end
    local name=safe(GetUnitName,unit,true) or safe(UnitName,unit)
    local box=ChatFrameUtil.ChooseBoxForSend and ChatFrameUtil.ChooseBoxForSend()
    if not name or box and box:GetText()~="" then return end
    ChatFrameUtil.SendTell(name)
end
function R:RefreshSoon()
    self.pending = true
    C_Timer.After(0, function() if self.pending and not W.Combat() then self:Rebuild() end end)
end
