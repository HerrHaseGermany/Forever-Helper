local _, addon = ...
local restored = {}
local captured = {}
local loadedAt
local characterKey, loadedFrom

-- SavedVariables must contain only plain serializable values, never live tables.
local function Copy(value, seen)
    local kind = type(value)
    if kind ~= "table" then
        if kind == "string" or kind == "number" or kind == "boolean" then return value end
        return nil
    end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local result = {}
    for key, child in pairs(value) do
        if type(key) == "string" or type(key) == "number" then result[key] = Copy(child, seen) end
    end
    seen[value] = nil
    return result
end
local function Merge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            Merge(target[key], value)
        else
            target[key] = Copy(value)
        end
    end
end
local function Say(text)
    print("|cff80ccffForever Helper:|r " .. text)
end
function addon.InitializeBackup()
    characterKey = UnitGUID("player")
    if not characterKey then return false end
    if type(ForeverHelperAccountDB) ~= "table" then ForeverHelperAccountDB = {} end
    if type(ForeverHelperAccountDB.characters) ~= "table" then
        ForeverHelperAccountDB.characters = {}
    end
    local account = ForeverHelperAccountDB.characters[characterKey]
    loadedFrom = "character file"
    if type(account) == "table" and account.version == 1 and
        (type(ForeverHelperDB) ~= "table" or ForeverHelperDB.version ~= 1 or
        (account.savedAt or "") >= (ForeverHelperDB.savedAt or "")) then
        ForeverHelperDB = Copy(account)
        loadedFrom = "account file"
    end
    if type(ForeverHelperDB) ~= "table" or ForeverHelperDB.version ~= 1 then
        ForeverHelperDB = { version = 1 }
        loadedFrom = "new backup"
    end
    loadedAt = ForeverHelperDB.savedAt
    ForeverHelperAccountDB.characters[characterKey] = Copy(ForeverHelperDB)
    return true
end

function addon.RecoverBackup(automatic)
    if not characterKey then return end
    -- Recover the latest captured state, including snapshots from this session.
    -- The fixed rescue addon is only a fallback when no regular snapshot exists.
    local recovery = ForeverHelperDB
    local account = ForeverHelperAccountDB.characters[characterKey]
    local function Valid(snapshot)
        return type(snapshot) == "table" and snapshot.version == 1 and snapshot.savedAt
    end
    if Valid(account) and (not Valid(recovery) or account.savedAt >= recovery.savedAt) then
        recovery = account
    end
    local source = "latest snapshot"
    if not Valid(recovery) then
        recovery = ForeverHelperAccountDB.recovery
        source = "rescue snapshot"
    end
    if type(recovery) ~= "table" or recovery.version ~= 1 then
        -- A separate load-on-demand addon survives loss of SavedVariables files.
        local loadAddon = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
        if loadAddon then
            local ok, loaded, reason = pcall(loadAddon, "ForeverHelperRecovery")
            if (not ok or not loaded) and not automatic then
                Say("Recovery addon could not load: " .. tostring(ok and reason or loaded))
            end
        end
        recovery = _G.ForeverHelperRecoverySnapshot
        if automatic and _G.ForeverHelperRecoveryCharacter ~= characterKey then return end
    end
    if not characterKey or type(recovery) ~= "table" or recovery.version ~= 1 then
        if not automatic then Say("No recovery snapshot available.") end
        return
    end
    ForeverHelperDB = Copy(recovery)
    ForeverHelperAccountDB.characters[characterKey] = Copy(recovery)
    restored, captured = {}, {}
    if not automatic then loadedFrom = source end
    if source == "rescue snapshot" then loadedFrom = source end
    loadedAt = recovery.savedAt
    Say("Snapshot selected: " .. tostring(loadedAt))
    if not automatic then addon.RestoreBackup() end
end

local function RestoreTomTom(saved)
    local tomtom = _G.TomTom
    if not tomtom or not tomtom.db or not tomtom.db.profile or not tomtom.ReloadOptions then return false end
    Merge(tomtom.db.profile, saved.profile)
    tomtom:ReloadOptions()
    -- ReloadOptions updates visibility/style, but only PLAYER_ENTERING_WORLD
    -- anchors the arrow. That event has already fired when we restore.
    local position = saved.profile.arrow and saved.profile.arrow.position
    if position then
        local frame = _G.TomTomCrazyArrow
        if not frame then return false end
        tomtom.db.profile.arrow.position = Copy(position)
        frame:ClearAllPoints()
        frame:SetPoint(position[1], UIParent, position[3], position[4], position[5])
    end
    return true
end
local function RestoreImportedGuides(saved)
    local rxp = _G.RXP
    if not rxp or not rxp.db or not rxp.db.profile or not rxp.LoadCachedGuides then return false end
    if rxp.guideImporter and (rxp.guideImporter.importBufferSize or 0) > 0 then return false end
    local guides = rxp.db.profile.guides
    if type(guides) ~= "table" then return false end
    for key, value in pairs(saved) do
        -- Preserve a newly imported entry if this cache key already exists.
        if guides[key] == nil then guides[key] = Copy(value) end
    end
    -- Restore completed imports from the native compressed cache, without
    -- starting RXP's separate interactive import-string workflow.
    local pendingString, savedString = rxp.string, _G.RXPString
    rxp.string, _G.RXPString = nil, nil
    local ok, message = pcall(rxp.LoadCachedGuides)
    rxp.string, _G.RXPString = pendingString, savedString
    if not ok then error(message) end
    for key in pairs(saved) do
        -- RXP deletes incompatible/undecodable cache entries. Keep our backup
        -- pending instead of replacing it with the now-empty cache at logout.
        if guides[key] == nil then return false end
    end
    if rxp.RXPFrame and rxp.RXPFrame.GenerateMenuTable and rxp.ScheduleTask then
        rxp:ScheduleTask(rxp.RXPFrame.GenerateMenuTable)
    end
    return true
end
local function RestoreBugButton(saved)
    local frame = _G.PTR_IssueReporter
    if not frame or not frame.SetPoint then return false end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", saved.x, saved.y)
    local settings = _G.Blizzard_PTRIssueReporter_Saved
    if type(settings) == "table" then
        settings.x, settings.y = saved.x, saved.y
    end
    return true
end
local function RestoreRXP(saved)
    local rxp = _G.RXP
    if not rxp or not rxp.settings or not rxp.settings.profile or not rxp.enabledFrames
        or not rxp.settings.LoadFramePositions then return false end
    if saved.guide then
        if not rxp.GetGuideTable or not rxp.LoadGuide or not rxp.SetStep then return false end
        local guide = rxp.GetGuideTable(saved.guide.group, saved.guide.name)
        if not guide or guide.disabled then return false end
        Merge(rxp.settings.profile, saved.profile)
        rxp:LoadGuide(guide, true)
        local current = rxp.currentGuide
        if not current or current.empty or current.group ~= guide.group or current.name ~= guide.name then return false end
        if saved.guide.step then rxp.SetStep(saved.guide.step) end
    else
        Merge(rxp.settings.profile, saved.profile)
    end
    rxp.settings:LoadFramePositions()
    return true
end
local restorers = {
    tomtom = RestoreTomTom,
    importedGuides = RestoreImportedGuides,
    bugButton = RestoreBugButton,
    restedXP = RestoreRXP,
    restedXPTomTom = function(saved)
        if type(_G.RXPTT_DB) ~= "table" then return false end
        Merge(_G.RXPTT_DB, saved)
        return true
    end,
}
local restoreOrder = { "importedGuides", "tomtom", "restedXP", "restedXPTomTom", "bugButton" }
function addon.RestoreBackup()
    if InCombatLockdown() then return false end
    local pending = false
    for _, name in ipairs(restoreOrder) do
        local restore = restorers[name]
        if not restored[name] and not captured[name] and ForeverHelperDB[name] then
            local ok, result = pcall(restore, ForeverHelperDB[name])
            if ok and result then
                restored[name] = true
                Say(name .. ": backup restored.")
            elseif not ok then
                Say(name .. ": restore failed: " .. tostring(result))
            end
            if not restored[name] then pending = true end
        end
    end
    return true, pending
end
function addon.SaveBackup()
    if not characterKey or not ForeverHelperDB then return end
    local data = addon.ReadData()
    if not data then return end
    local saved = false
    local function CanSave(name)
        -- Do not replace an unrestored backup with initialization defaults.
        return not ForeverHelperDB[name] or restored[name] or captured[name]
    end
    local rxp = _G.RXP
    if rxp and rxp.db and rxp.db.profile and type(rxp.db.profile.guides) == "table"
        and not (rxp.guideImporter and (rxp.guideImporter.importBufferSize or 0) > 0)
        and CanSave("importedGuides") then
        ForeverHelperDB.importedGuides = Copy(rxp.db.profile.guides)
        captured.importedGuides = true
        saved = true
    end
    local bugButton = _G.PTR_IssueReporter
    if bugButton and bugButton.GetLeft and CanSave("bugButton") then
        local x, y = bugButton:GetLeft(), bugButton:GetBottom()
        if x and y then
            ForeverHelperDB.bugButton = { x = x, y = y }
            captured.bugButton = true
            saved = true
        end
    end
    if data.tomtom and CanSave("tomtom") then
        local profile = Copy(data.tomtom)
        for key, frame in pairs({ arrow = _G.TomTomCrazyArrow, block = _G.TomTomBlock }) do
            if profile[key] and frame:GetNumPoints() > 0 then
                local point, relative, relativePoint, x, y = frame:GetPoint(1)
                if not relative or relative == UIParent then
                    profile[key].position = { point, nil, relativePoint, x, y }
                end
            end
        end
        captured.tomtom = true
        ForeverHelperDB.tomtom = { profile = profile }
        saved = true
    end
    if data.restedXP and CanSave("restedXP") then
        local rxp = _G.RXP
        if rxp.settings.SaveFramePositions then rxp.settings:SaveFramePositions() end
        local backup = { profile = Copy(data.restedXP) }
        if data.guide and not data.guide.empty then
            backup.guide = { group = data.guide.group, name = data.guide.name,
                step = rxp.GetGuideProgress and rxp.GetGuideProgress() }
        end
        captured.restedXP = true
        ForeverHelperDB.restedXP = backup
        saved = true
    end
    if data.restedXPTomTom and CanSave("restedXPTomTom") then
        captured.restedXPTomTom = true
        ForeverHelperDB.restedXPTomTom = Copy(data.restedXPTomTom)
        saved = true
    end
    if saved then ForeverHelperDB.savedAt = date("%Y-%m-%d %H:%M:%S") end
    ForeverHelperAccountDB.characters[characterKey] = Copy(ForeverHelperDB)
end
function addon.BackupStatus()
    Say("Backup loaded at login: " .. tostring(loadedAt or "none (first run or not persisted)"))
    Say("Backup source: " .. tostring(loadedFrom) .. "; character: " .. tostring(characterKey))
    Say("Latest capture: " .. tostring(ForeverHelperDB.savedAt or "none"))
    for name in pairs(restorers) do
        Say(name .. ": " .. (restored[name] and "restored" or captured[name] and "captured this session" or
            ForeverHelperDB[name] and "pending" or "no backup"))
    end
end
