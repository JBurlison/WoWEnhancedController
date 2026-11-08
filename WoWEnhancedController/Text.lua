local _, W = ...
local Text = {}
W.Text = Text

local function decode(s, i)
    local a, b, c, d = s:byte(i, i + 3)
    if not a then return nil, i end
    if a < 128 then return a, i + 1 end
    if a < 224 and b then return (a - 192) * 64 + b - 128, i + 2 end
    if a < 240 and b and c then return (a - 224) * 4096 + (b - 128) * 64 + c - 128, i + 3 end
    if b and c and d then return (a - 240) * 262144 + (b - 128) * 4096 + (c - 128) * 64 + d - 128, i + 4 end
    return a, i + 1
end
local function extending(cp)
    return (cp >= 0x300 and cp <= 0x36F) or (cp >= 0x1AB0 and cp <= 0x1AFF)
        or (cp >= 0x1DC0 and cp <= 0x1DFF) or (cp >= 0x20D0 and cp <= 0x20FF)
        or (cp >= 0xFE00 and cp <= 0xFE0F) or (cp >= 0xFE20 and cp <= 0xFE2F)
        or (cp >= 0x1F3FB and cp <= 0x1F3FF) or (cp >= 0xE0100 and cp <= 0xE01EF)
end

-- Byte offsets agree with WoW EditBox cursors. Preserve existing UTF-8 bytes.
-- Combining marks, variation selectors, emoji modifiers, ZWJ and flag pairs stay together.
function Text.Boundaries(s)
    local out, i, previous, regional = { 0 }, 1, nil, 0
    while i <= #s do
        local cp, nextIndex = decode(s, i)
        local isRegional = cp >= 0x1F1E6 and cp <= 0x1F1FF
        local join = extending(cp) or cp == 0x200D or previous == 0x200D
            or (cp == 10 and previous == 13) or (isRegional and regional % 2 == 1)
        if i > 1 and not join then out[#out + 1] = i - 1 end
        regional = isRegional and regional + 1 or 0
        previous, i = cp, nextIndex
    end
    if out[#out] ~= #s then out[#out + 1] = #s end
    return out
end
function Text.Previous(s, cursor)
    local result = 0
    for _, b in ipairs(Text.Boundaries(s)) do if b >= cursor then break end; result = b end
    return result
end
function Text.Next(s, cursor)
    for _, b in ipairs(Text.Boundaries(s)) do if b > cursor then return b end end
    return #s
end
function Text.Limit(s, maxBytes, maxLetters)
    local pos, count, i = 0, 0, 1
    while i <= #s do
        local _, nextIndex = decode(s, i)
        if (maxBytes and maxBytes > 0 and nextIndex - 1 > maxBytes)
            or (maxLetters and maxLetters > 0 and count >= maxLetters) then break end
        pos, count, i = nextIndex - 1, count + 1, nextIndex
    end
    return s:sub(1, pos)
end
function Text.New(text, options)
    return setmetatable({ text = text or "", cursor = #(text or ""), anchor = #(text or ""),
        undo = {}, redo = {}, options = options or {} }, { __index = Text })
end
function Text:Snapshot() return { self.text, self.cursor, self.anchor } end
function Text:Remember()
    self.undo[#self.undo + 1] = self:Snapshot()
    if #self.undo > 30 then table.remove(self.undo, 1) end
    self.redo = {}
end
function Text:Select(a, b)
    self.anchor, self.cursor = W.Clamp(a, 0, #self.text), W.Clamp(b, 0, #self.text)
end
function Text:Replace(value)
    local o = self.options
    if o.numeric then
        local pattern = o.decimal and "[^%d%.%-]" or "[^%d]"
        value = value:gsub(pattern, "")
    end
    local a, b = math.min(self.anchor, self.cursor), math.max(self.anchor, self.cursor)
    local nextText = self.text:sub(1, a) .. value .. self.text:sub(b + 1)
    nextText = Text.Limit(nextText, o.maxBytes, o.maxLetters)
    self:Remember()
    self.text = nextText
    self.cursor = math.min(#nextText, a + #value)
    self.anchor = self.cursor
end
function Text:Clear() self:Select(0, #self.text); self:Replace("") end
function Text:Delete()
    if self.anchor == self.cursor then self.anchor = Text.Previous(self.text, self.cursor) end
    self:Replace("")
end
function Text:Move(direction)
    local pos = direction < 0 and Text.Previous(self.text, self.cursor) or Text.Next(self.text, self.cursor)
    self:Select(pos, pos)
end
function Text:Undo(forward)
    local from, to = forward and self.redo or self.undo, forward and self.undo or self.redo
    if #from == 0 then return end
    to[#to + 1] = self:Snapshot()
    local state = table.remove(from)
    self.text, self.cursor, self.anchor = state[1], state[2], state[3]
end
function Text:Adjust(delta)
    local o = self.options
    local n = W.Clamp((tonumber(self.text) or o.min or 0) + delta * (o.step or 1), o.min, o.max)
    local value = o.decimal and ("%.2f"):format(n):gsub("0+$", ""):gsub("%.$", "") or tostring(math.floor(n + 0.000001))
    -- A digit limit must stop an increment, never turn 99 + 1 into 10 by truncation.
    if Text.Limit(value, o.maxBytes, o.maxLetters) ~= value then return end
    self:Select(0, #self.text); self:Replace(value)
end
function Text:Validate()
    local o = self.options
    if not o.numeric then return true end
    local n = tonumber(self.text)
    if not n or (not o.decimal and n % 1 ~= 0) then return false, "Enter a valid number." end
    if o.min and n < o.min then return false, "Minimum: " .. o.min end
    if o.max and n > o.max then return false, "Maximum: " .. o.max end
    return true
end
