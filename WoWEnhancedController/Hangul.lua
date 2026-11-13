local _, W = ...
-- Modern two-set Korean input. Only the final, unfinished syllable is retained.
local H = {}
W.Hangul = H
local function indexes(chars, first)
    local result = {}
    for index, letter in ipairs(W.Locale.Characters(chars)) do result[letter] = first + index - 1 end
    return result
end
local initials = indexes("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ", 0)
local vowels = indexes("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ", 0)
local finals = indexes("ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ", 1)
local joinVowel = {["ㅗㅏ"]="ㅘ",["ㅗㅐ"]="ㅙ",["ㅗㅣ"]="ㅚ",["ㅜㅓ"]="ㅝ",["ㅜㅔ"]="ㅞ",["ㅜㅣ"]="ㅟ",["ㅡㅣ"]="ㅢ"}
local joinFinal = {["ㄱㅅ"]="ㄳ",["ㄴㅈ"]="ㄵ",["ㄴㅎ"]="ㄶ",["ㄹㄱ"]="ㄺ",["ㄹㅁ"]="ㄻ",["ㄹㅂ"]="ㄼ",
    ["ㄹㅅ"]="ㄽ",["ㄹㅌ"]="ㄾ",["ㄹㅍ"]="ㄿ",["ㄹㅎ"]="ㅀ",["ㅂㅅ"]="ㅄ"}
local function render(initial, vowel, final)
    if not initial or not vowel then return initial or vowel or "" end
    local cp = 0xAC00 + (initials[initial] * 21 + vowels[vowel]) * 28 + (finals[final] or 0)
    return string.char(224 + math.floor(cp / 4096), 128 + math.floor(cp / 64) % 64, 128 + cp % 64)
end

-- Returns completed text, remaining keystrokes, and their display. Before a vowel,
-- the last consonant of a final (including a cluster) begins the next syllable.
function H.Compose(keys)
    local committed, start = "", 1
    local initial, vowel, final, firstFinal
    for index, key in ipairs(keys) do
        if vowels[key] and final then
            committed = committed .. render(initial, vowel, firstFinal)
            initial, vowel, final, firstFinal = keys[index - 1], key, nil, nil
            start = index - 1
        elseif vowels[key] and vowel and joinVowel[vowel .. key] then
            vowel = joinVowel[vowel .. key]
        elseif vowels[key] and not vowel then
            vowel = key
        elseif finals[key] and initial and vowel and not final then
            final = key
        elseif finals[key] and final and joinFinal[final .. key] then
            firstFinal, final = final, joinFinal[final .. key]
        else
            committed = committed .. render(initial, vowel, final)
            start, initial, vowel, final, firstFinal = index, nil, nil, nil, nil
            if vowels[key] then vowel = key else initial = key end
        end
    end
    local remaining = {}
    for index = start, #keys do remaining[#remaining + 1] = keys[index] end
    return committed, remaining, render(initial, vowel, final)
end
