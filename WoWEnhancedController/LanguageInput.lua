local _, W = ...
local K = W.Keyboard
local modes = {koKR={"Hangul", "Latin letters"}, zhCN={"Pinyin", "Latin letters"},
    zhTW={"Zhuyin", "Pinyin", "Latin letters"}, ruRU={"Cyrillic", "Latin letters"}}
local latin = {"qwertyuiop", "asdfghjkl", "zxcvbnm"}
local layouts = {
    ["Latin letters"] = latin, Pinyin = {"qwertyuiop", "asdfghjkl", "zxcvbnmü"},
    Hangul = {"ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ", "ㅁㄴㅇㄹㅎㅗㅓㅏㅣ", "ㅋㅌㅊㅍㅠㅜㅡ"},
    Zhuyin = {"ㄅㄉㄓㄚㄞㄢㄦ", "ㄆㄊㄍㄐㄔㄗㄧㄛㄟㄣ", "ㄇㄋㄎㄑㄕㄘㄨㄜㄠㄤ", "ㄈㄌㄏㄒㄖㄙㄩㄝㄡㄥㄫ"},
}
local shifted = {["ㅂ"]="ㅃ",["ㅈ"]="ㅉ",["ㄷ"]="ㄸ",["ㄱ"]="ㄲ",["ㅅ"]="ㅆ",["ㅐ"]="ㅒ",["ㅔ"]="ㅖ"}
local pageSize = 7

function K:LanguageMode()
    local choices = modes[W.Locale.code]
    return choices and choices[self.languageIndex or 1]
end
function K:LanguageRows()
    return layouts[self:LanguageMode()] or W.Locale.rows
end
function K:KeyLabel(ch)
    if not self.shift then return ch end
    if self.symbols then return W.Locale.Upper(ch) end
    local mode = self:LanguageMode()
    if mode == "Hangul" then return shifted[ch] or ch end
    if mode == "Pinyin" or mode == "Zhuyin" then return ch end
    return W.Locale.Upper(ch)
end
function K:CycleLanguage()
    self.preedit = nil
    self.languageIndex = (self.languageIndex or 1) % #modes[W.Locale.code] + 1
    self.symbols, self.shift = false, false
    self:Draw()
end

-- The native field may be edited or replaced independently of the controller.
local function snapshot(k, state)
    local e = k.editor
    state.editor, state.text, state.cursor, state.anchor = e, e.text, e.cursor, e.anchor
end
function K:CurrentPreedit()
    local s, e = self.preedit, self.editor
    if s and (s.editor ~= e or s.text ~= e.text or s.cursor ~= e.cursor or s.anchor ~= e.anchor) then
        self.preedit = nil
    end
    return self.preedit
end
local function fits(e, a, b, value)
    local text = e.text:sub(1, a) .. value .. e.text:sub(b + 1)
    return W.Text.Limit(text, e.options.maxBytes, e.options.maxLetters) == text
end
local function hangulEdit(k, key)
    local e, state = k.editor, k:CurrentPreedit() or {keys={}}
    if W.Focus() ~= k:InputOwner() or (k.session and not W.Contexts.Valid(k.session)) then return end
    local keys = W.Copy(state.keys)
    if key then keys[#keys+1] = key else table.remove(keys) end
    local completed, remaining, active = W.Hangul.Compose(keys)
    local replacement = completed .. active
    local a = state.active and e.cursor - #state.active or math.min(e.cursor, e.anchor)
    local b = math.max(e.cursor, e.anchor)
    if not fits(e, a, b, replacement) then return end
    if state.active then
        e:Select(a, b)
        k:Sync()
    end
    local expected = e.text:sub(1, a) .. replacement .. e.text:sub(b + 1)
    k:Insert(replacement)
    if active ~= "" and e.text == expected and e.cursor == a + #replacement then
        state.keys, state.active = remaining, active
        snapshot(k, state)
        k.preedit = state
    end
end

-- Readings omit tones. Each list contains the matching homophones.
local function lookup(k, state)
    local reading = state.reading
    if k:LanguageMode() == "Zhuyin" then reading = W.Zhuyin[reading]
    else reading = reading:gsub("ü", "v") end
    state.candidates = W.Locale.Characters(W.Mandarin[reading] or "")
    state.page = 1
end
function K:TypeLetter(ch)
    local mode = self:LanguageMode()
    if self.symbols or self:Numeric() then self:Insert(ch)
    elseif mode == "Hangul" then hangulEdit(self, ch)
    elseif mode == "Pinyin" or mode == "Zhuyin" then
        local state = self:CurrentPreedit() or {reading=""}
        if #W.Locale.Characters(state.reading) < 7 then state.reading = state.reading .. ch end
        lookup(self, state)
        snapshot(self, state)
        self.preedit = state
    else self:Insert(ch) end
    self.shift = false
    self:Draw()
end
local function choose(k, state, ch)
    if k:CurrentPreedit() ~= state or not ch then return end
    local e = k.editor
    if not fits(e, math.min(e.cursor,e.anchor), math.max(e.cursor,e.anchor), ch) then return end
    k:Insert(ch)
    k:Draw()
end
function K:CompositionAction(action)
    local state = self:CurrentPreedit()
    if not state then return false end
    if state.reading then
        if action == "confirm" or action == "space" then
            choose(self, state, state.candidates[(state.page-1)*pageSize+1])
            return true
        elseif action == "back" then
            self.preedit = nil
            self:Draw()
            return true
        elseif action == "delete" then
            state.reading = state.reading:sub(1, W.Text.Previous(state.reading, #state.reading))
            if state.reading == "" then self.preedit = nil else lookup(self, state) end
            self:Draw()
            return true
        end
    elseif action == "delete" then
        hangulEdit(self)
        self:Draw()
        return true
    end
    if action ~= "shift" then self.preedit = nil end
    return false
end
function K:DrawCandidates(y)
    local state = self:CurrentPreedit()
    if not state or not state.reading then return y end
    local count = #state.candidates
    local pages = math.max(1, math.ceil(count / pageSize))
    local items = {{label=true, text=state.reading, weight=1.6}}
    if count == 0 then
        items[#items+1] = {label=true, text=W.L["No matching character"], weight=5}
    else
        local first = (state.page-1)*pageSize+1
        for index=first, math.min(first+pageSize-1, count) do
            local ch = state.candidates[index]
            items[#items+1] = {text=ch, weight=1, action=function() choose(self, state, ch) end}
        end
    end
    if pages > 1 then
        for _, step in ipairs({-1, 1}) do
            items[#items+1] = {text=step < 0 and "‹" or "›", weight=.8, action=function()
                state.page = (state.page-1+step) % pages + 1
                self:Draw()
            end}
        end
    end
    return self:AddRow(items, y, 38)
end
