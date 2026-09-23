local addonName, addon = ...
local events = CreateFrame("Frame")
local db, ready, queued
local restoreAttempts = 0
local starters = {
    Human = "1-6 Northshire", Dwarf = "1-6 Coldridge Valley",
    Gnome = "1-6 Coldridge Valley", NightElf = "1-6 Shadowglen",
    Orc = "1-6 Durotar", Troll = "1-6 Durotar", Tauren = "1-6 Mulgore",
    Scourge = "1-6 Tirisfal Glades", Skyborne = "1-14 Zephras Isle",
}
local function Say(message)
    print("|cff80ccffForever Helper:|r " .. message)
end
local function CheckSettings(verbose)
    local mismatches = 0
    for name, expected in pairs(db.settings) do
        local actual = GetCVar(name)
        if actual == nil or (tostring(actual) ~= tostring(expected)
            and not (tonumber(actual) and tonumber(actual) == tonumber(expected))) then
            mismatches = mismatches + 1
            Say(name .. " = " .. tostring(actual or "unavailable") .. "; expected " .. tostring(expected))
        end
    end
    if verbose and mismatches == 0 then Say("Settings match.") end
end
local function Position(frame, options, position)
    if not frame or not options then return end
    options.position = { position[1], nil, position[3], position[4], position[5] }
    frame:ClearAllPoints()
    frame:SetPoint(position[1], UIParent, position[3], position[4], position[5])
end
local function LoadGuide(force)
    local rxp = _G.RXP
    if not rxp or type(rxp.GetGuideTable) ~= "function" or type(rxp.LoadGuide) ~= "function" then
        if force then Say("RestedXP is unavailable.") end
        return
    end
    if not force and (db.guideInitialized or
        (not db.guideName and rxp.currentGuide and not rxp.currentGuide.empty)) then return end
    local faction = UnitFactionGroup("player")
    local _, race = UnitRace("player")
    local group = db.guideGroup or (faction == "Alliance" and "RestedXP Forever Guide (A)"
        or faction == "Horde" and "RestedXP Forever Guide (H)")
    local name = db.guideName or starters[race]
    if not db.guideName and not force and UnitLevel("player") > 1 then return end
    local guide = group and name and rxp.GetGuideTable(group, name)
    if not guide or guide.disabled then
        if force then Say("Guide unavailable; use /fh guide Group|Guide name.") end
        return
    end
    rxp:LoadGuide(guide)
    if rxp.currentGuide and (rxp.currentGuide == guide or (guide.key and rxp.currentGuide.key == guide.key)) then
        db.guideInitialized = true
    end
end
-- Resolve active profiles on every read: addons may replace them at runtime.
local function ReadData()
    if not db then return nil end
    local tomtom, rxp = _G.TomTom, _G.RXP
    addon.data = {
        tomtom = tomtom and tomtom.profile,
        restedXP = rxp and rxp.settings and rxp.settings.profile,
        guide = rxp and rxp.currentGuide,
        restedXPTomTom = _G.RXPTT_DB,
        settings = {},
    }
    for name in pairs(db.settings) do addon.data.settings[name] = GetCVar(name) end
    return addon.data
end
addon.ReadData = ReadData
_G.ForeverHelper = addon

local function Report()
    local data = ReadData()
    Say("TomTom: " .. (data.tomtom and "available" or "unavailable"))
    if data.tomtom then
        for _, key in ipairs({ "arrow", "block" }) do
            local options = data.tomtom[key]
            local position = options and options.position
            if position then
                Say(key .. ": " .. tostring(position[1]) .. " / " .. tostring(position[3])
                    .. " / " .. tostring(position[4]) .. ", " .. tostring(position[5]))
            end
        end
    end
    Say("RestedXP: " .. (data.restedXP and "available" or "unavailable"))
    Say("Guide: " .. (data.guide and not data.guide.empty and tostring(data.guide.name) or "none"))
    if data.restedXPTomTom then
        Say("RestedXP-TomTom: minimap=" .. tostring(data.restedXPTomTom.showMinimap)
            .. ", world map=" .. tostring(data.restedXPTomTom.showWorldMap))
    else
        Say("RestedXP-TomTom: unavailable")
    end
    CheckSettings(true)
    addon.BackupStatus()
end
local function Schedule()
    if queued or not ready then return end
    queued = true
    C_Timer.After(1, function()
        queued = false
        local allowed, pending = addon.RestoreBackup()
        if not allowed then
            events:RegisterEvent("PLAYER_REGEN_ENABLED")
        elseif pending then
            restoreAttempts = restoreAttempts + 1
            if restoreAttempts < 60 then
                Schedule()
            else
                Say("Some backups are still pending; use /fh status for details and /fh restore to retry.")
            end
        end
        ReadData()
    end)
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == addonName then
            local interfaceVersion = select(4, GetBuildInfo())
            if tonumber(interfaceVersion) ~= 16001 then
                self:UnregisterAllEvents()
                return
            end
            db = { settings = addon.config.settings }
        elseif name == "TomTom" or name == "RXPGuides" or name == "RestedXP-TomTom"
            or name == "Blizzard_PTRFeedback" then
            Schedule()
        end
    elseif event == "PLAYER_LOGOUT" and db then
        local ok, message = pcall(addon.SaveBackup)
        if not ok then Say("Backup failed: " .. tostring(message)) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent(event)
        Schedule()
    elseif event == "PLAYER_ENTERING_WORLD" and db then
        if not ready then
            if not addon.InitializeBackup() then return end
            addon.RecoverBackup(true)
            ready = true
            if addon.InitializeMinimap then addon.InitializeMinimap() end
            CheckSettings(false)
        end
        Schedule()
    end
end)

SLASH_FOREVERHELPER1 = "/fh"
SLASH_FOREVERHELPER2 = "/foreverhelper"
SlashCmdList.FOREVERHELPER = function(input)
    if not ready then Say("Requires WoW Forever Beta (interface 16001).") return end
    local command, args = input:match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" then
        Report()
    elseif command == "save" then
        addon.SaveBackup()
        addon.BackupStatus()
    elseif command == "restore" then
        restoreAttempts = 0
        Schedule()
    elseif command == "recover" then
        restoreAttempts = 0
        addon.RecoverBackup()
        Schedule()
    elseif command == "check" then
        CheckSettings(true)
    elseif command == "read" or command == "status" or command == "apply" then
        Report()
    elseif command == "guide" then
        if InCombatLockdown() then Say("Load guides after combat.") return end
        if args ~= "" then
            local group, name = args:match("^%s*(.-)%s*|%s*(.-)%s*$")
            if not group or group == "" or name == "" then
                Say("Usage: /fh guide Group|Guide name")
                return
            end
            db.guideGroup, db.guideName = group, name
            db.guideInitialized = nil
        end
        LoadGuide(true)
    elseif command == "arrow" or command == "coords" then
        local x, y = args:match("^(%-?%d+)%s+(%-?%d+)$")
        if not x then Say("Usage: /fh " .. command .. " x y (offsets from top center)") return end
        if InCombatLockdown() then Say("Move frames after combat.") return end
        local tomtom = _G.TomTom
        local key = command == "arrow" and "arrow" or "block"
        local frame = command == "arrow" and _G.TomTomCrazyArrow or _G.TomTomBlock
        if not tomtom or not tomtom.profile or not tomtom.profile[key] or not frame then
            Say("TomTom frame unavailable.")
            return
        end
        Position(frame, tomtom.profile[key], { "TOP", nil, "TOP", tonumber(x), tonumber(y) })
        ReadData()
    else
        Say("/fh read | save | restore | recover | check | arrow x y | coords x y | guide [Group|Guide name]")
    end
end
