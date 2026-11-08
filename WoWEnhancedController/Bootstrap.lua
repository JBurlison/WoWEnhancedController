local addonName, W = ...
local eventFrame = CreateFrame("Frame")
W.events = eventFrame
local initialized, sinceFocus, sinceRepeat, sincePosition = false, 0, 0, 0
local resumeAfterNeutral = false
local worldReady, startupFocus = false, nil

function W.Blocker()
    if StaticPopup_Visible and StaticPopup_Visible() then return "Native confirmation dialog" end
    if GameMenuFrame and GameMenuFrame:IsShown() then return "Game menu" end
    if CinematicFrame and CinematicFrame:IsShown() then return "Cinematic" end
    if MovieFrame and MovieFrame:IsShown() then return "Movie" end
end
function W.Usable(box)
    return box and not W.Secret(box) and not box.wecOwned
        and W.Call(box, "IsObjectType", "EditBox") and W.Call(box, "IsVisible")
        and W.Call(box, "IsEnabled") ~= false and W.Call(box, "IsPassword") ~= true
        and W.Call(box, "IsForbidden") ~= true and not W.Contexts.NativeAuctionQuantity(box)
end
function W.Focus()
    if not GetCurrentKeyBoardFocus then return end
    local ok, focus = pcall(GetCurrentKeyBoardFocus)
    if ok and not W.Secret(focus) then return focus end
end
function W.WatchFocus()
    if not initialized or not worldReady or W.Combat() or not W.db.enabled or W.Placement.editing or W.OtherKeyboard() then return end
    local K, focus = W.Keyboard, W.Focus()
    if W.Contexts.NativeAuctionQuantity(focus) then
        if K.session or K.frame:IsShown() then K:Close() end
        return
    end
    -- Ignore a field already focused during login; wait for fresh selection.
    if startupFocus then
        if focus == startupFocus then return end
        startupFocus = nil
    end
    if W.Blocker() then
        if K.session then K.suspended = true; K:Hide() end
        return
    end
    if K.session and not W.Contexts.Valid(K.session) then K:Close("The original field changed; draft not applied.") end
    if K.session and K.mouseEditing and not focus then return end
    if K.suspended and K.session then
        if W.Usable(focus) and focus ~= K.session.target then K:Close()
        else
            if not W.ControllerMode() or (focus ~= K.session.target and not (K.composing and focus == K.input)) then return end
            K.suspended = nil; K.frame:Show(); K:Draw(); K:FocusField(); W.Input:Acquire()
        end
    end
    if focus and focus.wecOwned then return end
    if K.session and focus ~= K.session.target and not W.Usable(focus) then K.suspended = true; K:Hide(); return end
    if focus ~= W.dismissed then W.dismissed = nil end
    if focus and focus ~= W.dismissed and W.Usable(focus) and (W.db.activation == "always" or W.ControllerMode()) then
        if K.session and K.session.target == focus then return end
        if K.session then K:Close() end
        K:Open(focus)
    elseif K.session and focus and focus ~= K.session.target then
        K.suspended = true; K:Hide()
    end
end
local function diagnostics()
    local info = GetBuildInfo and { GetBuildInfo() } or {}
    W.Print("v" .. W.version .. " · client " .. tostring(info[1]) .. " / " .. tostring(info[2]) .. " / interface " .. tostring(info[4]))
    W.Print("Mode " .. (W.ControllerMode() and "controller" or "mouse/keyboard") .. "; capture " .. tostring(W.Input.active)
        .. "; raw callbacks down/up/stick " .. W.Input.counters.down .. "/" .. W.Input.counters.up .. "/" .. W.Input.counters.stick)
    W.Print(W.OtherKeyboard() or W.Input.failure or "No recorded input setup error.")
end
local function initialize()
    W.InitDB(); W.Keyboard:Init(); W.Input:Init(); W.Placement.Init()
    SLASH_WOWENHANCEDCONTROLLER1 = "/wec"
    SlashCmdList.WOWENHANCEDCONTROLLER = function(command)
        command = (command or ""):lower():match("^%s*(.-)%s*$")
        if command == "diag" then diagnostics()
        elseif command == "off" then W.db.enabled = false; W.Keyboard:Close()
        elseif command == "on" then W.db.enabled = true; W.Print("Enabled.")
        elseif command == "layout" then W.Placement.Enter(); W.Input:Acquire(true)
        elseif command == "focus" then W.FocusBinding()
        elseif command == "open" then
            local box = W.Focus()
            if W.Contexts.NativeAuctionQuantity(box) then return end
            if W.Usable(box) then W.Keyboard:Open(box) else W.Keyboard:Options() end
        else W.Keyboard:Options() end
    end
    initialized = true
    local conflict = W.OtherKeyboard()
    if conflict then W.Print(conflict) end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", function(_, box)
            if W.Keyboard.session and W.Keyboard.session.target == box then return end
            if worldReady and box ~= startupFocus and W.db.enabled and not W.Combat() and W.ControllerMode() and not W.OtherKeyboard() then
                -- Defer until the native focus transaction has completed.
                C_Timer.After(0, function()
                    if worldReady and not W.Blocker() and W.Focus() == box and W.Usable(box)
                        and (not W.Keyboard.session or W.Keyboard.session.target ~= box) then W.Keyboard:Open(box) end
                end)
            end
        end, W)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == addonName and not initialized then initialize() end
        return
    end
    if not initialized then return end
    if event == "PLAYER_REGEN_DISABLED" then
        if W.Keyboard.session then W.Keyboard.suspended = true end
        W.Input:Release(); W.Keyboard:Hide()
    elseif event == "PLAYER_REGEN_ENABLED" then
        W.Input:Release(); W.Placement.ApplyAll(); W.WatchFocus()
    elseif event == "GAME_PAD_DISCONNECTED" then
        W.Input:Release(); resumeAfterNeutral = true
    elseif event == "GAME_PAD_CONNECTED" then resumeAfterNeutral = true
    elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        if not W.ControllerMode() then W.lastPad = false; W.Input:Release()
        elseif W.Keyboard.frame:IsShown() then W.Input:Acquire() end
    elseif event == "GAME_PAD_ACTIVE_CHANGED" or event == "UPDATE_BINDINGS" then
        W.Input:Refresh(); if W.Keyboard.frame:IsShown() then W.Keyboard:Draw() end
    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "PLAYER_ENTERING_WORLD" then
        if event == "PLAYER_ENTERING_WORLD" and not worldReady then
            worldReady = true
            startupFocus = W.Focus()
            if startupFocus and startupFocus.wecOwned then startupFocus = nil end
            if startupFocus and type(startupFocus.HookScript) == "function" then
                startupFocus:HookScript("OnEditFocusLost", function() startupFocus = nil end)
            end
            W.Keyboard:Close()
        end
        if W.Placement.editing then W.Placement.Leave() end
        W.Placement.ApplyAll()
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local owner, func = ...
        if owner == addonName then
            W.Input.failure = "WoW blocked " .. tostring(func) .. ". Controller capture suspended; /wec diag reports state."
            W.Input:Release(); W.Print(W.Input.failure)
        end
    end
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "INPUT_DEVICE_INTERFACE_TRANSITION",
    "UPDATE_BINDINGS", "EDIT_MODE_LAYOUTS_UPDATED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnUpdate", function(_, elapsed)
    if not initialized then return end
    sinceFocus, sinceRepeat, sincePosition = sinceFocus + elapsed, sinceRepeat + elapsed, sincePosition + elapsed
    if sinceRepeat >= 0.035 then sinceRepeat = 0; W.Input:Update() end
    if sinceFocus >= 0.15 then sinceFocus = 0; W.WatchFocus() end
    if sincePosition >= 0.25 then
        sincePosition = 0
        if W.Keyboard.frame:IsShown() and not W.Placement.editing then W.Placement.ApplyAll() end
        if resumeAfterNeutral and W.Input:Neutral() and W.Keyboard.frame:IsShown() and W.ControllerMode() then
            resumeAfterNeutral = false; W.Input:Refresh(); W.Input:Acquire()
        end
    end
end)

-- Unassigned entry points are available in WoW's native binding UI.
BINDING_HEADER_WOWENHANCEDCONTROLLER = "Enhanced Controller"
BINDING_NAME_WEC_OPEN = "Open controller keyboard / options"
BINDING_NAME_WEC_FOCUS = "Focus controller keyboard"
function W.FocusBinding()
    if not initialized or not W.db.enabled or W.Combat() or W.Blocker() or W.OtherKeyboard() then return false end
    local k, box = W.Keyboard, W.Focus()
    if W.Contexts.NativeAuctionQuantity(box) then
        k:Close()
        return false
    end
    if W.Usable(box) and (not k.session or k.session.target ~= box) then
        if k.session then k:Close() end
        if not k:Open(box) then return false end
    end
    if k.session and not W.Contexts.Valid(k.session) then k:Close("Field changed; draft was not applied."); return false end
    if not k.session and not k.frame:IsShown() then return false end
    k.suspended = nil
    if k.editor then k:FocusField() end
    if not k.frame:IsShown() then k.frame:Show(); k:Draw() end
    -- Explicit focus works even when the last interface sample was mouse input.
    return W.Input:Acquire(true)
end
function W.OpenBinding()
    if not initialized or W.Combat() then return end
    local box = W.Focus()
    if W.Contexts.NativeAuctionQuantity(box) then return end
    if W.Usable(box) then W.Keyboard:Open(box) else W.Keyboard:Options() end
end

-- The native minimap addon menu resolves this global from TOC metadata.
function WoWEnhancedController_OnAddonCompartmentClick()
    if not initialized or W.Combat() or W.Blocker() then return end
    W.Keyboard:Options()
end
