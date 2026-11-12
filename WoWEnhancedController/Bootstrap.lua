local addonName, W = ...
local eventFrame = CreateFrame("Frame")
W.events = eventFrame
local initialized, sinceFocus, sinceRepeat, sincePosition = false, 0, 0, 0
local resumeAfterNeutral = false
local worldReady, startupFocus = false, nil

function W.Blocker()
    if (GamepadActionBarEditFrame and GamepadActionBarEditFrame:IsShown()) or (W.MacroEditor and W.MacroEditor.binding) then return W.L["Controller toolbar"] end
    if StaticPopup_Visible and StaticPopup_Visible() then return W.L["Native confirmation dialog"] end
    if GameMenuFrame and GameMenuFrame:IsShown() then return W.L["Game menu"] end
    if GamepadRadial and GamepadRadial:IsShown() then return W.L["Game menu"] end
    if CinematicFrame and CinematicFrame:IsShown() then return W.L["Cinematic"] end
    if MovieFrame and MovieFrame:IsShown() then return W.L["Movie"] end
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
    if K.session and not W.Contexts.Valid(K.session) then K:Close(W.L["The original field changed; draft not applied."]) end
    if K.session and K.mouseEditing and not focus then return end
    if K.suspended and K.session then
        if W.Usable(focus) and focus ~= K.session.target then K:Close()
        else
            if not W.ControllerMode() or (focus ~= K.session.target and not (K.composing and focus == K.input)) then return end
            K.suspended = nil; K.frame:Show(); K:Draw(); K:FocusField(); W.Input:Acquire()
        end
    end
    if focus and focus.wecOwned then return end
    if K.assigning and not K.session and focus == K.quickOwner then return end
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
    W.Print(W.L.Format("v%s · client %s / %s / interface %s", W.version, tostring(info[1]), tostring(info[2]), tostring(info[4])))
    W.Print(W.L.Format("Mode %s; capture %s; callbacks %d/%d/%d", W.ControllerMode() and W.L["Controller"] or W.L["Mouse / keyboard"],
        W.Input.active and W.L["On"] or W.L["Off"], W.Input.counters.down, W.Input.counters.up, W.Input.counters.stick))
    W.Print(W.OtherKeyboard() or W.Input.failure or W.L["No recorded input setup error."])
    local blocked = W.Input.blockedAction
    if blocked then
        W.Print(blocked.func .. " · " .. (blocked.stage or "-") .. "\n" .. (blocked.stack or ""))
    end
    W.Print(W.L.Format("Wheel releases %d; committed %d; blocked %d", W.Radial.gestureReleases or 0, W.Radial.gestureClicks or 0, W.Radial.gestureBlocked or 0))
end
local function initialize()
    W.InitDB(); W.Keyboard:Init(); W.Input:Init(); W.Placement.Init(); W.Radial:Init(); W.QuickMove:Init(); W.Launcher:Init(); W.Options.Init()
    SLASH_WOWENHANCEDCONTROLLER1 = "/wec"
    SlashCmdList.WOWENHANCEDCONTROLLER = function(command)
        command = (command or ""):lower():match("^%s*(.-)%s*$")
        if command == "diag" then diagnostics()
        elseif command == "menu" then W.Launcher:Toggle("launcher")
        elseif command == "minimap" then W.Launcher:Toggle("minimap")
        elseif command == "settings" then W.Options.Open()
        elseif command == "off" then W.db.enabled = false; W.Launcher:Close(); W.Keyboard:Close(); W.Radial:Close(); W.Radial:SyncOwnership()
        elseif command == "on" then W.db.enabled = true; W.Radial:SyncOwnership(); W.Print(W.L["Enabled."])
        elseif command == "wheel" or command == "radial" then W.Radial:Open()
        elseif command == "spells" then W.Radial:Edit()
        elseif command == "macros" then W.MacroEditor:Open()
        elseif command == "layout" then W.Placement.Enter(); W.Input:Acquire(true)
        elseif command == "focus" then W.FocusBinding()
        elseif command == "open" then
            local box = W.Focus()
            if W.Contexts.NativeAuctionQuantity(box) then return end
            if W.Usable(box) then W.Keyboard:Open(box) else W.Keyboard:Options() end
        else W.Keyboard:Options() end
    end
    SLASH_WECWHEEL1 = "/wecwheel"
    SlashCmdList.WECWHEEL = function() W.Radial:Open() end
    initialized = true
    local conflict = W.OtherKeyboard()
    if conflict then W.Print(conflict) end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("Gamepad.ShowMainMenu", function()
            W.WatchFocus(); W.Input:Release(); W.Input:RefreshWindows()
            W.Launcher:Close(); W.Radial:SyncOwnership()
        end, W)
        EventRegistry:RegisterCallback("Gamepad.HideMainMenu", function()
            -- Blizzard restores its own focus after this notification.
            C_Timer.After(0, function() W.Input:RefreshWindows() end)
        end, W)
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
    W.Links:OnEvent(event)
    if event == "PLAYER_REGEN_DISABLED" then
        if W.Placement.editing then W.Placement.Leave() end
        W.Radial:ResetGesture(true)
        if W.Radial.editor and W.Radial.editor:IsShown() then W.Radial.editor:Hide() end
        if W.Keyboard.session then W.Keyboard.suspended = true end
        W.Input:Release(); W.Keyboard:Hide()
    elseif event == "PLAYER_REGEN_ENABLED" then
        W.Input:FlushCapture(); W.Input:RefreshWindows()
        W.Input:Release()
        if W.Radial.pendingInit then W.Radial:Init() else W.Radial:Rebuild() end
        W.Placement.ApplyAll(); W.WatchFocus()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_NAME_UPDATE" or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "SPELLS_CHANGED" or event == "UPDATE_MACROS" then
        W.Radial:RefreshSoon()
    elseif event == "GAME_PAD_DISCONNECTED" then
        W.Radial:InputChanged()
        W.Radial:Close()
        W.Input:Release(); resumeAfterNeutral = true
        W.Input:RefreshWindows()
    elseif event == "GAME_PAD_CONNECTED" then resumeAfterNeutral = true
    elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        W.Radial:InputChanged()
        if not W.ControllerMode() then W.lastPad = false; W.Input.active = false end
        -- Native chat is changing its gamepad focus stack during this event.
        -- Reconcile our private overrides once the new device owns the UI.
        C_Timer.After(0, function()
            if not W.ControllerMode() then W.Input:Release()
            elseif W.Keyboard.frame:IsShown() then W.Input:Acquire() end
        end)
    elseif event == "GAME_PAD_ACTIVE_CHANGED" or event == "UPDATE_BINDINGS" then
        W.Radial:InputChanged()
        W.Input:Refresh(); if W.Keyboard.frame:IsShown() then W.Keyboard:Draw() end
        W.Radial:RefreshSoon()
    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "PLAYER_ENTERING_WORLD" then
        if event == "PLAYER_ENTERING_WORLD" then W.Radial:Rebuild() end
        if event == "PLAYER_ENTERING_WORLD" and not worldReady then
            worldReady = true
            startupFocus = W.Focus()
            if startupFocus and startupFocus.wecOwned then startupFocus = nil end
            if startupFocus and type(startupFocus.HookScript) == "function" then
                startupFocus:HookScript("OnEditFocusLost", function() startupFocus = nil end)
            end
            W.Keyboard:Close()
        end
        if W.Placement.editing and (event == "PLAYER_ENTERING_WORLD" or W.Placement.layout ~= W.Placement.LayoutKey()) then W.Placement.Leave() end
        W.Placement.ApplyAll()
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local owner, func = ...
        if owner == addonName then
            -- Blocked events can be raised synchronously by release itself.
            -- Record the original native caller without recursively releasing
            -- an already inactive catcher or flooding chat on repeated events.
            if W.Input.handlingBlockedAction then return end
            W.Input.handlingBlockedAction = true
            local previous, now = W.Input.blockedAction, GetTime()
            local blocked = { func = tostring(func), stage = W.Input.releaseStage,
                stack = debugstack and debugstack(2, 20, 12), at = now }
            W.Input.blockedAction = blocked
            -- Keep the last few reports across /reload so the native caller
            -- and the addon operation that reached it can be read afterwards.
            if W.db and (not previous or previous.func ~= blocked.func or now - previous.at >= 5) then
                local log = W.db.blockedLog or {}
                W.db.blockedLog = log
                local focus = W.Focus()
                log[#log + 1] = { func = blocked.func, stage = blocked.stage, stack = blocked.stack,
                    when = date and date("%Y-%m-%d %H:%M:%S") or tostring(now), version = W.version,
                    controller = W.ControllerMode() and true or false, capture = W.Input.active and true or false,
                    keyboard = W.Keyboard.frame and W.Keyboard.frame:IsShown() and true or false,
                    launcher = W.Launcher and W.Launcher:IsShown() and true or false,
                    macros = W.MacroEditor and W.MacroEditor.frame and W.MacroEditor.frame:IsShown() and true or false,
                    focus = focus and W.Call(focus, "GetName") or nil }
                while #log > 5 do table.remove(log, 1) end
            end
            W.Input.failure = W.L.Format("WoW blocked %s. Controller capture suspended; /wec diag reports state.", tostring(func))
            if W.Input.active then W.Input:Release() end
            if not previous or previous.func ~= blocked.func or now - previous.at >= 5 then W.Print(W.Input.failure) end
            W.Input.handlingBlockedAction = nil
        end
    end
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "INPUT_DEVICE_INTERFACE_TRANSITION",
    "GROUP_ROSTER_UPDATE", "UNIT_NAME_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "SPELLS_CHANGED", "UPDATE_MACROS",
    "UPDATE_BINDINGS", "EDIT_MODE_LAYOUTS_UPDATED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
    "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE",
    "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "SUPER_TRACKING_CHANGED" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnUpdate", function(_, elapsed)
    if not initialized then return end
    sinceFocus, sinceRepeat, sincePosition = sinceFocus + elapsed, sinceRepeat + elapsed, sincePosition + elapsed
    if sinceRepeat >= 0.035 then sinceRepeat = 0; W.Input:Update() end
    if sinceFocus >= 0.15 then sinceFocus = 0; W.Radial:SyncOwnership(); W.WatchFocus() end
    if sincePosition >= 0.25 then
        sincePosition = 0
        W.Links:Tick(W.Keyboard)
        if W.Keyboard.frame:IsShown() and not W.Placement.editing then W.Placement.ApplyAll() end
        if resumeAfterNeutral and W.Input:Neutral() and W.Keyboard.frame:IsShown() and W.ControllerMode() then
            resumeAfterNeutral = false; W.Input:Refresh(); W.Input:Acquire()
        end
    end
end)

-- Unassigned entry points are available in WoW's native binding UI.
BINDING_HEADER_WOWENHANCEDCONTROLLER = "Enhanced Controller"
_G["BINDING_NAME_CLICK WoWEnhancedControllerWheelInput:Classic"] = W.L["Open classic healing wheel"]
_G["BINDING_NAME_CLICK WoWEnhancedControllerWheelInput:Sweep"] = W.L["Open hold & sweep healing wheel"]
BINDING_NAME_WEC_OPEN = W.L["Open controller keyboard / options"]
BINDING_NAME_WEC_FOCUS = W.L["Focus controller keyboard"]
BINDING_NAME_WEC_MENU = W.L["Open Enhanced Controller launcher"]
BINDING_NAME_WEC_MINIMAP = W.L["Navigate minimap buttons"]
_G["BINDING_NAME_CLICK WoWEnhancedControllerWheelInput:Toggle"] = W.L["Toggle party / raid spell wheel"]
function W.FocusBinding()
    if not initialized or not W.db.enabled or W.Combat() or W.Blocker() or W.OtherKeyboard() then return false end
    if W.Launcher:IsShown() then
        return W.Launcher:RequestFocus()
    end
    if W.MacroEditor:Eligible() then return W.MacroEditor:RequestFocus() end
    local k, box = W.Keyboard, W.Focus()
    if W.Contexts.NativeAuctionQuantity(box) then
        k:Close()
        return false
    end
    if W.Usable(box) and (not k.session or k.session.target ~= box) then
        if k.session then k:Close() end
        if not k:Open(box) then return false end
    end
    if k.session and not W.Contexts.Valid(k.session) then k:Close(W.L["Field changed; draft was not applied."]); return false end
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
    W.Launcher:Toggle("launcher")
end
