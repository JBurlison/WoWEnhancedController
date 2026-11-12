local _, W = ...
local locale = GetLocale and GetLocale() or "enUS"
local aliases = { enGB = "enUS", esMX = "esES" }
W.Locale = { code = aliases[locale] or locale, client = locale }
-- Keys are the English source text. Missing translations fall back to English;
-- saved phrases, names, macro text and stable action/context IDs never pass here.
local aliasesForLabels = { primary="Select", back="Back", delete="Delete", shift="Shift", left="Left", right="Right",
    space="Space", symbols="Symbols", clear="Clear all", confirm="Send / Done", library="Assign mode",
    phrases="Phrase layer", phrasesLeft="Left messages", phrasesRight="Right messages",
    focus="Focus", context="This context", chat="All chat", global="All contexts", default="Default" }
W.L = setmetatable({}, { __index = function(t, key)
    local display = aliasesForLabels[key]
    return display and (rawget(t, display) or display) or key
end })
function W.L.Format(key, ...) return string.format(W.L[key], ...) end

local rows = {
    deDE = { "qwertzuiopü", "asdfghjklöä", "yxcvbnmß" },
    frFR = { "azertyuiop", "qsdfghjklm", "wxcvbn" },
    esES = { "qwertyuiop", "asdfghjklñ", "zxcvbnm" },
    itIT = { "qwertyuiop", "asdfghjkl", "zxcvbnm" },
    ptBR = { "qwertyuiop", "asdfghjklç", "zxcvbnm" },
    ruRU = { "йцукенгшщзх", "фывапролджэ", "ячсмитьбюё" },
}
local extras = {
    deDE = "äöüß", frFR = "àâçéèêëîïôùûüÿœ", esES = "áéíóúüñ¿¡",
    itIT = "àèéìòù", ptBR = "áàâãçéêíóôõú", ruRU = "ъыэё",
}
W.Locale.rows = rows[W.Locale.code] or { "qwertyuiop", "asdfghjkl", "zxcvbnm" }
W.Locale.extras = extras[W.Locale.code]
local lower = "àâäãçéèêëîïíôöòóõùûüúÿœñßйцукенгшщзхфывапролджэячсмитьбюёъ"
local upper = "ÀÂÄÃÇÉÈÊËÎÏÍÔÖÒÓÕÙÛÜÚŸŒÑẞЙЦУКЕНГШЩЗХФЫВАПРОЛДЖЭЯЧСМИТЬБЮЁЪ"
local function characters(text)
    local result = {}
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do result[#result + 1] = char end
    return result
end
W.Locale.Characters = characters
local uppercase, small, capital = {}, characters(lower), characters(upper)
for i, char in ipairs(small) do uppercase[char] = capital[i] end
function W.Locale.Upper(char) return uppercase[char] or char:upper() end
