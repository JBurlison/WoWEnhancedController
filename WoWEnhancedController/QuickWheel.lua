local _, W = ...
local K = W.Keyboard
local slots = 8

local function control(text, action, hint)
    return { text = text, action = action, hint = hint, weight = 1 }
end

function K:ChangeQuickPage(delta)
    if not self.quickButtons or self.composing or delta == 0 then return end
    self.quickPage = (self.quickPage - 1 + delta) % #W.db.quickPages + 1
    self.removeQuickPage = nil
    self:Draw()
end

function K:DrawQuickHeader(x, y, width, height)
    if not self.quickDecoration then
        local layer = CreateFrame("Frame", nil, self.content)
        layer:SetAllPoints(self.content)
        layer:SetFrameLevel(self.content:GetFrameLevel())
        layer:EnableMouse(false)
        for key, atlas in pairs({header="gamepad-radial-menu-toptext", ring="gamepad-radial-menu-wheelbg",
            footer="gamepad-radial-menu-bottomtext", highlight="gamepad-radial-menu-selected"}) do
            layer[key] = layer:CreateTexture(nil, key == "highlight" and "BORDER" or "BACKGROUND")
            layer[key]:SetAtlas(atlas)
        end
        self.quickDecoration = layer
    end
    local layer = self.quickDecoration
    layer:Show()
    layer.header:ClearAllPoints(); layer.header:SetPoint("TOPLEFT", x, -y); layer.header:SetSize(width, height)
    local label = self:QuickLabel(W.L.Format("Page %d / %d", self.quickPage, #W.db.quickPages), x+48, y, width-96, height)
    label:SetJustifyH("CENTER")
    self.quickPageButtons = {}
    for _, delta in ipairs({ -1, 1 }) do
        local action = delta < 0 and "phrasesLeft" or "phrasesRight"
        local item = control(W.Input:Icon(action) and "" or (delta < 0 and "<" or ">"), function() self:ChangeQuickPage(delta) end, action)
        item.promptMode = "bank"
        self:AddRow({item}, y, height, delta < 0 and x or x+width-44, 44)
        self.quickPageButtons[#self.quickPageButtons+1] = self.rows[#self.rows][1]
    end
end

function K:DrawQuickWheel(x, y, width)
    local layer = self.quickDecoration
    local diameter = math.min(width, 320)
    local radius, cx, cy = diameter*.325, x+width/2, y+diameter/2
    layer.ring:ClearAllPoints(); layer.ring:SetPoint("TOPLEFT", cx-diameter/2, -y)
    layer.ring:SetSize(diameter, diameter)
    layer.highlightRadius = diameter*150/540
    layer.highlight:SetSize(diameter*169/540, diameter*165/540)
    self.quickButtons = {}
    local context = self:Context()
    for slot = 1, slots do
        local angle = (slot-1)*2*math.pi/slots
        local message = W.Phrases.Resolve(context, slot, self.quickBank)
        local item = control(message ~= "" and message or "–", function() self:UsePhrase(slot) end)
        item.messageSlot, item.promptMode = slot, "wedge"
        self:AddRow({item}, cy-radius*math.cos(angle)-18, 36, cx+radius*math.sin(angle)-34, 68)
        self.quickButtons[slot] = self.rows[#self.rows][1]
    end
    self.quickCaption = self:QuickLabel("", cx-72, cy-36, 144, 72)
    self.quickCaption:SetJustifyH("CENTER")
    local footerY = y+diameter+2
    layer.footer:ClearAllPoints(); layer.footer:SetPoint("TOPLEFT", x, -footerY); layer.footer:SetSize(width, 48)
    local atlas = W.Input:Icon("phrases")
    layer.aimGlyph = layer.aimGlyph or layer:CreateTexture(nil, "OVERLAY")
    layer.aimGlyph:SetShown(atlas ~= nil)
    if atlas then
        layer.aimGlyph:SetAtlas(atlas); layer.aimGlyph:SetSize(26, 26)
        layer.aimGlyph:ClearAllPoints(); layer.aimGlyph:SetPoint("TOPLEFT", x+6, -footerY-10)
    end
    local hint = W.L["Hold to aim"]
    if not atlas then hint = W.Input:Hint("phrases") .. " " .. hint end
    local inset = atlas and 38 or 6
    self.quickHint = self:QuickLabel(hint, x+inset, footerY, width-inset-132, 44)
    self.quickIdleHint = hint
    local assign = control(self.assigning and W.L["Done"] or W.L["Assign"], function() self:ToggleAssign() end, "library")
    self:AddRow({assign}, footerY+3, 38, x+width-132, 132)
    local bottom = footerY+50
    if self.assigning then
        local add = control(W.L["Add page"], function()
            self.quickPage = W.Phrases.AddPage(); self.removeQuickPage = nil; self:Draw()
        end)
        local remove = control(self.removeQuickPage == self.quickBank and W.L["Confirm removal"] or W.L["Remove page"], function()
            if self.removeQuickPage == self.quickBank then
                W.Phrases.RemovePage(self.quickPage)
                self.quickPage = math.min(self.quickPage, #W.db.quickPages)
                self.removeQuickPage = nil
            else self.removeQuickPage = self.quickBank end
            self:Draw()
        end)
        remove.disabled = self.quickPage == 1
        bottom = self:AddRow({add, remove}, bottom, 38, x, width)
    end
    return bottom
end

function K:PaintQuickAim()
    local layer = self.quickDecoration
    if not layer or not layer:IsShown() or not self.quickCaption or not self.quickButtons then return end
    local slot
    if W.Input.quickHold then slot = self.quickAim
    elseif self.focused then slot = self.focused.messageSlot end
    self.quickHint:SetText(W.Input.quickHold and W.L["Release to use"] or self.quickIdleHint)
    local button = slot and self.quickButtons[slot]
    layer.highlight:SetShown(button ~= nil)
    if button then
        local angle = (slot-1)*2*math.pi/slots
        layer.highlight:ClearAllPoints()
        layer.highlight:SetPoint("CENTER", layer.ring, "CENTER", math.sin(angle)*layer.highlightRadius, math.cos(angle)*layer.highlightRadius)
        layer.highlight:SetRotation(-math.pi-angle)
    end
    local caption = button and button:GetText()
    if caption == "–" then caption = W.L["Unassigned"] end
    self.quickCaption:SetText(caption or (W.Input.quickHold and W.L["Aim with the right stick"] or W.L["Quick messages"]))
end

function K:AimQuickWheel(x, y)
    local slot
    if not W.Secret(x) and not W.Secret(y) and type(x) == "number" and type(y) == "number" and x*x+y*y >= .45*.45 then
        slot = math.floor(math.deg(math.atan2(x, y))/45+.5) % slots+1
    end
    if slot ~= self.quickAim then self.quickAim = slot; self:PaintQuickAim() end
end
