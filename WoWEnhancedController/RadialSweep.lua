local _, W = ...
local R = W.Radial
local media = "Interface\\AddOns\\WoWEnhancedController\\Media\\Radial\\"

function R:CreateSweep(parent)
    local surface = CreateFrame("Button", "WoWEnhancedControllerSweepSurface", parent, "SecureActionButtonTemplate")
    surface:SetPoint("CENTER"); surface:SetAttribute("command", "SweepMouse")
    W.RadialSecure.Attach(surface, parent)
    surface:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    parent:SetFrameRef("surface", surface)
    -- Blizzard only dispatches a restricted OnLeave after a wrapped OnEnter.
    SecureHandlerWrapScript(surface, "OnEnter", parent, "return")
    SecureHandlerWrapScript(surface, "OnLeave", parent, [[
        if control:GetAttribute("sweep-button") == "SweepMouse" then control:RunAttribute("op-cancelSweep") end
    ]])
    surface:Hide()
    local layer = CreateFrame("Frame", nil, parent)
    layer:SetPoint("CENTER"); layer:EnableMouse(false); layer:Hide()
    self.sweepLayer, self.sweepSurface = layer, surface
    layer.inner = layer:CreateTexture(nil, "BACKGROUND")
    layer.inner:SetPoint("CENTER")
    layer.mark = layer:CreateTexture(nil, "ARTWORK")
    layer.mark:SetPoint("CENTER")
    layer.name = W.Theme.Label(layer, ""); layer.name:SetPoint("CENTER", 0, 9)
    layer.hp = W.Theme.Label(layer, "", "GameFontHighlightSmall"); layer.hp:SetPoint("CENTER", 0, -12)
    layer.members, layer.spells = {}, {}
    for i=1,5 do
        local cell = CreateFrame("Frame", nil, layer)
        cell.label = W.Theme.Label(cell, ""); cell.label:SetAllPoints()
        cell.bar = CreateFrame("StatusBar", nil, cell)
        cell.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        cell.bar:SetPoint("TOP", cell, "BOTTOM"); cell.bar:SetHeight(4)
        cell:EnableMouse(false); cell.bar:EnableMouse(false)
        layer.members[i] = cell
    end
    for i=1,8 do
        local cell = CreateFrame("Frame", nil, layer)
        cell.art = cell:CreateTexture(nil, "ARTWORK"); cell.art:SetPoint("CENTER", 0, 9)
        cell.label = W.Theme.Label(cell, "", "GameFontNormalSmall")
        cell.label:SetPoint("TOP", cell.art, "BOTTOM", 0, -2); cell:EnableMouse(false)
        layer.spells[i] = cell
    end
end

local function place(cell, parent, index, count, radius)
    local angle = 2*math.pi*(index-1)/count
    cell:ClearAllPoints()
    cell:SetPoint("CENTER", parent, "CENTER", math.sin(angle)*radius, math.cos(angle)*radius)
end
function R:LayoutSweep(size)
    local layer = self.sweepLayer
    self.sweepSurface:SetSize(size, size); layer:SetSize(size, size)
    layer.inner:SetSize(size*.61, size*.61); layer.mark:SetSize(size*.61, size*.61)
    layer.name:SetSize(size*.22, 32); layer.hp:SetWidth(size*.22)
    for _, cell in ipairs(layer.members) do
        cell:SetSize(size*.19, 22); cell.bar:SetWidth(size*.12)
        cell.label:SetFontObject(W.Theme.Font("GameFontNormalSmall"))
    end
    for i,cell in ipairs(layer.spells) do
        cell:SetSize(size*.20, size*.12); cell.label:SetSize(size*.20, 39)
        cell.art:SetSize(size*.068, size*.068)
        cell.label:SetFontObject(W.Theme.Font("GameFontNormalSmall"))
        place(cell, layer, i, 8, size*.396)
    end
end

local function mouseAim(surface, count)
    if not surface:IsMouseOver() or not GetCursorPosition then return end
    local x, y = GetCursorPosition()
    local scale = surface:GetEffectiveScale()
    x = (x/scale-surface:GetLeft())/surface:GetWidth()-.5
    y = (y/scale-surface:GetBottom())/surface:GetHeight()-.5
    local d = x*x+y*y
    if d < .0121 or d > .25 then return end
    local angle = (math.deg(math.atan2(x,y))+360)%360
    if d >= .09 then return nil, math.floor(angle/45+.5)%8+1 end
    return math.floor(angle*count/360+.5)%count+1
end
function R:PaintSweep(stage, member, page)
    local f,layer = self.frame,self.sweepLayer
    local dual = f:GetAttribute("dual")
    local diameter = W.db.radial.size * (dual and 1.16 or 1)
    if self.ring:GetWidth()~=diameter then self.ring:SetSize(diameter,diameter) end
    layer:SetShown(dual)
    self.selectLabel:SetText(W.L["Select"])
    for _,region in ipairs({self.center,self.centerHealth}) do region:SetShown(not dual) end
    if not dual then return end
    self.centerBar:Hide(); self.highlight:Hide()
    if stage~="spells" or f:GetAttribute("sweep-button") then
        self.confirmGlyphs[2]:Hide(); self.confirmSeparator:Hide()
    end
    local group = f:GetAttribute("group") or 1
    local roster = self.snapshot.groups[group]
    local count = #roster
    if count==0 then return end
    local held = f:GetAttribute("sweep-button")
    local mouseMember,mouseSpell
    if GetCursorPosition and (held=="SweepMouse" or not W.ControllerMode()) then
        mouseMember,mouseSpell = mouseAim(self.sweepSurface,count)
    end
    local pointed = self:Point()
    local selected = f:GetAttribute("selected") or 0
    local ally, spell
    if stage=="spells" then
        if held=="SweepMouse" then spell=mouseSpell
        elseif selected>0 then spell=selected
        else spell=pointed>0 and pointed or (not held and mouseSpell) end
    else ally=pointed>0 and pointed or selected>0 and selected or mouseMember end
    local solo = f:GetAttribute("solo")
    layer.inner:SetShown(not solo)
    layer.inner:SetTexture(media.."Wheel"..count)
    local marked=ally
    for i,cell in ipairs(layer.members) do
        local m = self.snapshot.members[roster[i]]
        cell:SetShown(m~=nil and not solo)
        if m and not solo then
            if roster[i]==member then marked=i end
            place(cell,layer,i,count,W.db.radial.size*.211)
            cell.label:SetText(W.Escape(m.unit=="player" and W.L["You"] or m.name))
            if W.db.radial.health then self:PaintHealth(nil,cell.bar,m) else cell.bar:Hide() end
        end
    end
    layer.mark:SetShown(marked~=nil and not solo)
    if marked then
        layer.mark:SetTexture(media.."Highlight"..count); layer.mark:SetRotation(-(marked-1)*2*math.pi/count)
    end
    local recipient = self.snapshot.members[member or roster[ally]]
    layer.name:SetText(recipient and W.Escape(recipient.name) or W.L["Choose member"])
    self:PaintHealth(layer.hp,nil,W.db.radial.health and recipient)
    self:PaintAuras(self.sweepAuras,layer,0,-31,self:Dispellable(recipient and recipient.unit))
    self.selectLabel:SetText(W.L[held and "Release to cast" or stage=="spells" and "Cast" or "Hold & sweep"])
    for i,cell in ipairs(layer.spells) do
        local slot = self.pageSlots[page] and self.pageSlots[page][i]
        local action = slot and self.actions[slot]
        cell:SetShown(action~=nil)
        if action then
            cell.art:SetTexture(self.actionMeta[slot].icon or 134400)
            cell.label:SetText(W.Escape(action.label))
            cell:SetAlpha(stage=="spells" and 1 or .62)
            if spell==i then
                local angle=(i-1)*math.pi/4; local radius=W.db.radial.size*150/540
                self.highlight:ClearAllPoints();self.highlight:SetPoint("CENTER",math.sin(angle)*radius,math.cos(angle)*radius)
                self.highlight:SetRotation(-math.pi-angle);self.highlight:Show()
                self.title:SetText(W.Escape(action.label))
            end
        end
    end
end
