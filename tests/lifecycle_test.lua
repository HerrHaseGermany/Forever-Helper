-- Exercise the actual event wiring without a game client.
local realPrint = print
print = function() end
date = function() return "2026-09-22 20:00:00" end
UIParent = {}
SlashCmdList = {}
local handler, initialized, guid
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        UnregisterEvent = function() end,
        SetScript = function(_, _, callback) handler = callback end,
    }
end
C_Timer = { After = function(_, callback) callback() end }
GetBuildInfo = function() return nil, nil, nil, 16001 end
GetCVar = function() return "1" end
UnitGUID = function() return guid end
InCombatLockdown = function() return false end
local addon = { config = { settings = {} } }
assert(loadfile("ForeverHelper.lua"))("Forever Helper", addon)
assert(loadfile("Backup.lua"))("Forever Helper", addon)
ForeverHelperAccountDB = {
    characters = {
        ["Player-70-test"] = { version = 1, savedAt = "previous", restedXPTomTom = { showMinimap = false } },
    },
}
handler({}, "ADDON_LOADED", "Forever Helper")
assert(ForeverHelperDB == nil)
handler({}, "PLAYER_ENTERING_WORLD") -- No GUID yet: initialization can retry.
assert(ForeverHelperDB == nil)
guid = "Player-70-test"
RXPTT_DB = { showMinimap = true }
handler({}, "PLAYER_ENTERING_WORLD")
assert(RXPTT_DB.showMinimap == false)
RXPTT_DB.showMinimap = true
handler({}, "PLAYER_LOGOUT")
assert(ForeverHelperAccountDB.characters[guid].restedXPTomTom.showMinimap == true)
assert(ForeverHelperAccountDB.characters[guid].savedAt == "2026-09-22 20:00:00")
handler({}, "PLAYER_ENTERING_WORLD")
assert(RXPTT_DB.showMinimap == true)
realPrint("lifecycle tests passed")
-- Cold login without SavedVariables automatically uses the local rescue addon.
ForeverHelperDB, ForeverHelperAccountDB = nil, nil
C_AddOns = { LoadAddOn = function()
    ForeverHelperRecoveryCharacter = guid
    ForeverHelperRecoverySnapshot = {
        version = 1, savedAt = "rescue", restedXPTomTom = { showMinimap = false },
    }
    return true
end }
local cold = { config = { settings = {} } }
assert(loadfile("ForeverHelper.lua"))("Forever Helper", cold)
assert(loadfile("Backup.lua"))("Forever Helper", cold)
handler({}, "ADDON_LOADED", "Forever Helper")
handler({}, "PLAYER_ENTERING_WORLD")
assert(RXPTT_DB.showMinimap == false and ForeverHelperDB.savedAt == "rescue")
-- A newer regular backup wins over the older recovery snapshot.
RXPTT_DB.showMinimap = true
handler({}, "PLAYER_LOGOUT")
local nextLogin = { config = { settings = {} } }
assert(loadfile("ForeverHelper.lua"))("Forever Helper", nextLogin)
assert(loadfile("Backup.lua"))("Forever Helper", nextLogin)
handler({}, "ADDON_LOADED", "Forever Helper")
handler({}, "PLAYER_ENTERING_WORLD")
assert(RXPTT_DB.showMinimap == true)
-- Manual recover also selects the most recent logout snapshot.
RXPTT_DB.showMinimap = false
SlashCmdList.FOREVERHELPER("recover")
assert(RXPTT_DB.showMinimap == true)
-- Pending restoration retries as delayed addons become ready.
local callbacks = {}
C_Timer.After = function(_, callback) callbacks[#callbacks + 1] = callback end
local attempts = 0
nextLogin.RestoreBackup = function()
    attempts = attempts + 1
    return true, attempts < 3
end
SlashCmdList.FOREVERHELPER("restore")
while #callbacks > 0 do table.remove(callbacks, 1)() end
assert(attempts == 3)
realPrint("automatic recovery and retry tests passed")
