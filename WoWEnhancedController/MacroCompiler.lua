local _, W = ...
local C = {}
W.MacroCompiler = C

local function errorText(text) return W.L[text] end
function C.Characters(text)
    local _, count = (text or ""):gsub("[^\128-\191]", "")
    return count
end
local function ordinary(text)
    return type(text) == "string" and not W.Secret(text) and not text:find("[\r\n;,%[%]|]")
end
function C.Spell(entry, catalog)
    if type(entry) ~= "table" or not tonumber(entry.spellID) then return nil, errorText("Choose a learned spell.") end
    local id = tonumber(entry.spellID)
    local info = W.RadialData.Info(id)
    if not info or not ordinary(info.name) then return nil, errorText("This spell is unavailable.") end
    local learned, subtext
    for _, spell in ipairs(catalog or W.RadialData.Spells()) do
        if tonumber(spell.value) == id or not entry.ranked and spell.label == info.name then
            learned = true
            if tonumber(spell.value) == id then subtext = spell.detail end
        end
    end
    if not learned then return nil, errorText("Choose a learned spell.") end
    if entry.ranked then
        if not ordinary(subtext) or subtext == "" then return nil, errorText("This spell rank is unavailable.") end
        return info.name .. "(" .. subtext .. ")"
    end
    return info.name
end
local targets = { target=true, player=true, focus=true, mouseover=true, pet=true, cursor=true,
    party1=true, party2=true, party3=true, party4=true }
local modifiers = { any=true, nomod=true, shift=true, ctrl=true, alt=true }
function C.Conditions(rule)
    local conditions = {}
    local target, modifier = rule.target or "target", rule.modifier or "any"
    if not targets[target] or not modifiers[modifier] then return nil, errorText("Invalid macro condition.") end
    if target ~= "target" then conditions[#conditions+1] = "@" .. target end
    if modifier ~= "any" then conditions[#conditions+1] = modifier == "nomod" and modifier or "mod:" .. modifier end
    local relation = rule.relation or "any"
    if relation ~= "any" then
        if relation ~= "help" and relation ~= "harm" and relation ~= "exists" then return nil, errorText("Invalid macro condition.") end
        conditions[#conditions+1] = relation
    end
    if rule.alive then conditions[#conditions+1] = "nodead" end
    if rule.combat and rule.combat ~= "any" then
        if rule.combat ~= "combat" and rule.combat ~= "nocombat" then return nil, errorText("Invalid macro condition.") end
        conditions[#conditions+1] = rule.combat
    end
    if rule.form then
        local n = tonumber(rule.form)
        if not n or n < 0 or n > 10 or n ~= math.floor(n) then return nil, errorText("Invalid macro condition.") end
        conditions[#conditions+1] = "form:" .. n
    end
    return #conditions > 0 and "[" .. table.concat(conditions, ",") .. "]" or ""
end
local commands = { startattack=true, stopattack=true, stopcasting=true, petattack=true, petpassive=true,
    petfollow=true, cancelform=true, cancelaura=true, equipslot=true, dismount=true, assist=true, focus=true, clearfocus=true }
function C.Block(block, catalog)
    if type(block) ~= "table" then return nil, errorText("Invalid macro action.") end
    if block.kind == "raw" then
        if type(block.text) ~= "string" or W.Secret(block.text) then return nil, errorText("Invalid macro action.") end
        return block.text
    elseif block.kind == "cast" then
        local parts = {}
        for _, rule in ipairs(block.rules or {}) do
            local spell, err = C.Spell(rule, catalog); if not spell then return nil, err end
            local condition; condition, err = C.Conditions(rule); if not condition then return nil, err end
            parts[#parts+1] = (condition ~= "" and condition .. " " or "") .. spell
        end
        if #parts == 0 then return nil, errorText("Add a spell or condition.") end
        return "/cast " .. table.concat(parts, "; ")
    elseif block.kind == "sequence" then
        if block.target == "cursor" then return nil, errorText("Choose a unit for this sequence.") end
        local condition, err = C.Conditions({target=block.target}); if not condition then return nil, err end
        local spells, reset = {}, {}
        for _, entry in ipairs(block.steps or {}) do
            local spell; spell, err = C.Spell(entry, catalog); if not spell then return nil, err end
            spells[#spells+1] = spell
        end
        if #spells == 0 then return nil, errorText("Add a spell to the sequence.") end
        local seconds = block.resetSeconds==nil and 0 or tonumber(block.resetSeconds)
        if not seconds or seconds < 0 or seconds > 3600 or seconds ~= math.floor(seconds) then return nil, errorText("Invalid sequence timeout.") end
        if seconds > 0 then reset[#reset+1] = tostring(seconds) end
        if block.resetTarget then reset[#reset+1] = "target" end
        if block.resetCombat then reset[#reset+1] = "combat" end
        local modifier = block.resetModifier or "none"
        if modifier ~= "none" then
            if modifier ~= "shift" and modifier ~= "ctrl" and modifier ~= "alt" then return nil, errorText("Invalid macro condition.") end
            reset[#reset+1] = modifier
        end
        return "/castsequence " .. (condition ~= "" and condition .. " " or "")
            .. (#reset > 0 and "reset=" .. table.concat(reset, "/") .. " " or "") .. table.concat(spells, ", ")
    elseif block.kind == "item" then
        local slot = tonumber(block.slot)
        if slot ~= 13 and slot ~= 14 then return nil, errorText("Choose a trinket slot.") end
        return "/use " .. slot
    elseif block.kind == "command" then
        if not commands[block.verb] then return nil, errorText("Invalid macro action.") end
        local arg = block.arg or ""
        if not ordinary(arg) then return nil, errorText("Use Commands for custom macro syntax.") end
        if (block.verb == "cancelaura" or block.verb == "equipslot") and arg:match("^%s*$") then
            return nil, errorText("Choose an item or buff.")
        end
        if block.verb == "equipslot" and not arg:match("^1[67] .+") then return nil, errorText("Start with slot 16 or 17, followed by the item name.") end
        local condition, err = C.Conditions({modifier=block.modifier}); if not condition then return nil, err end
        return "/" .. block.verb .. (condition ~= "" and " " .. condition or "") .. (arg ~= "" and " " .. arg or "")
    end
    return nil, errorText("Invalid macro action.")
end
function C.Compile(model, catalog)
    if type(model.raw) == "string" then return model.raw end
    local lines, errors, warnings, casts, items, nonempty = {}, {}, {}, 0, 0, false
    if model.tooltip then lines[#lines+1] = "#showtooltip" end
    for i, block in ipairs(model.blocks or {}) do
        local line, err = C.Block(block, catalog)
        if line then lines[#lines+1] = line else errors[#errors+1] = {index=i,message=err} end
        if line and not line:match("^%s*$") then nonempty=true end
        if block.kind == "cast" or block.kind == "sequence" then casts = casts+1 end
        if block.kind == "item" then items = items+1 end
    end
    if not nonempty and #errors==0 then errors[#errors+1] = {message=errorText("Add an action before saving.")} end
    if casts > 1 then warnings[#warnings+1] = errorText("Actions on separate lines run on the same press. Use a sequence for successive presses.") end
    if casts > 0 and items > 0 then warnings[#warnings+1] = errorText("Using an item and casting together depends on the item's cooldown rules.") end
    return table.concat(lines, "\n"), errors, warnings
end

-- An educational model driven solely by explicit scenario inputs. Never reads
-- live combat data or casts, uses items, changes targets or advances a real macro.
function C.Preview(block, scenario, state, catalog)
    state = state or {index=1}; scenario = scenario or {}
    if block.kind == "sequence" then
        if scenario.event then
            local reset = scenario.event == "target" and block.resetTarget or scenario.event == "combat" and block.resetCombat
                or scenario.event == "idle" and (tonumber(block.resetSeconds) or 0) > 0
            if reset then state.index=1 end
            return reset and errorText("Reset: next press starts at step 1.") or errorText("No reset configured for this event."), state
        end
        if scenario.modifier == block.resetModifier and block.resetModifier ~= "none" then state.index=1 end
        local index = math.min(state.index or 1, #(block.steps or {}))
        local spell, err = C.Spell(block.steps and block.steps[index], catalog); if not spell then return err, state end
        if scenario.failed then return W.L.Format("%s fails. Still on step %d.", spell, index), state end
        state.index = index % #block.steps + 1
        return W.L.Format("%s succeeds. Next press: step %d.", spell, state.index), state
    elseif block.kind == "cast" then
        for _, rule in ipairs(block.rules or {}) do
            local unit = rule.target == "player" and "help" or rule.target == "cursor" and "ground"
                or scenario[rule.target or "target"] or "none"
            local mod, rel = rule.modifier or "any", rule.relation or "any"
            local matches = (mod == "any" or mod == "nomod" and scenario.modifier == "none" or mod == scenario.modifier)
                and (not rule.combat or rule.combat == "any" or rule.combat == scenario.combat)
                and (rel == "any" or rel == "exists" and unit ~= "none" or rel == unit)
                and (not rule.alive or unit ~= "dead" and unit ~= "none")
                and (not rule.form or tonumber(rule.form) == tonumber(scenario.form))
            if matches then
                local spell, err = C.Spell(rule, catalog); if not spell then return err, state end
                return W.L.Format(scenario.failed and "%s is selected but fails. Later alternatives are not retried." or "%s is selected. Assumed cast succeeds.", spell), state
            end
        end
        return errorText("No condition matches. This action does nothing."), state
    end
    return errorText("Read this action's commands. Preview does not execute them."), state
end
