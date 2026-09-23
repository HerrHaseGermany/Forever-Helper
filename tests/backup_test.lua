-- Run from the addon directory with Lua 5.1+.
local realPrint = print
print = function() end
date = function() return "test timestamp" end
local combat = false
InCombatLockdown = function() return combat end
UIParent = {}
local character = "Player-70-1234"
UnitGUID = function() return character end
local function Frame(x, y)
    return {
        point = { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y },
        GetNumPoints = function() return 1 end,
        GetPoint = function(self) return unpack(self.point) end,
        ClearAllPoints = function(self) self.point = {} end,
        SetPoint = function(self, ...) self.point = { ... } end,
        GetLeft = function(self) return self.point[4] end,
        GetBottom = function(self) return self.point[5] end,
    }
end
local function NewSession()
    local addon = {}
    addon.ReadData = function()
        return { tomtom = TomTom and TomTom.profile,
            restedXP = RXP and RXP.settings.profile,
            guide = RXP and RXP.currentGuide, restedXPTomTom = RXPTT_DB }
    end
    assert(loadfile("Backup.lua"))("Forever Helper", addon)
    addon.InitializeBackup()
    return addon
end
local function InitializeAddons()
    TomTom = { db = { profile = { arrow = {}, block = {} } } }
    TomTom.profile = TomTom.db.profile
    function TomTom:ReloadOptions() self.profile = self.db.profile end
    TomTomCrazyArrow, TomTomBlock = Frame(0, 0), Frame(0, 0)
    PTR_IssueReporter = Frame(0, 0)
    Blizzard_PTRIssueReporter_Saved = { unrelated = true }
    RXPTT_DB = { showMinimap = true }
    RXP = {
        db = { profile = { guides = {} } },
        settings = { profile = {}, LoadFramePositions = function() end },
        enabledFrames = {}, guideImporter = { importBufferSize = 0 }, guides = {},
    }
    function RXP.LoadCachedGuides()
        assert(RXP.string == nil and RXPString == nil)
        for _, entry in pairs(RXP.db.profile.guides) do
            RXP.guides[entry.key] = { group = "Imported", name = "Test", key = entry.key }
        end
    end
    function RXP.GetGuideTable(group, name)
        if group == "Imported" and name == "Test" then return RXP.guides.custom end
    end
    function RXP:LoadGuide(guide) assert(guide); self.currentGuide = guide end
    function RXP.SetStep(step) RXP.step = step end
    function RXP.GetGuideProgress() return RXP.step end
end
InitializeAddons()
local first = NewSession()
TomTomCrazyArrow.point = { "TOP", UIParent, "TOP", 123, -456 }
TomTomBlock.point[4] = 50
PTR_IssueReporter.point[4], PTR_IssueReporter.point[5] = 22, 248
RXP.settings.profile.option = false
RXP.db.profile.guides.custom = { key = "custom", groupOrContent = "compressed\000bytes" }
RXP.currentGuide = { group = "Imported", name = "Test", key = "custom" }
RXP.step = 7
first.SaveBackup()
assert(ForeverHelperDB.tomtom.profile.arrow.position[4] == 123)
assert(ForeverHelperDB.bugButton.x == 22)
-- Snapshot must not change when the source is mutated.
RXP.db.profile.guides.custom.groupOrContent = "changed"
assert(ForeverHelperDB.importedGuides.custom.groupOrContent == "compressed\000bytes")
-- Simulate a reload with profiles reset to defaults.
InitializeAddons()
RXP.string, RXPString = "pending source", "saved source"
local second = NewSession()
combat = true
assert(second.RestoreBackup() == false)
assert(TomTomCrazyArrow.point[4] == 0)
combat = false
assert(second.RestoreBackup())
assert(TomTomCrazyArrow.point[1] == "TOP" and TomTomCrazyArrow.point[4] == 123)
assert(TomTomCrazyArrow.point[5] == -456)
assert(TomTom.profile.arrow.position[4] == 123)
assert(PTR_IssueReporter:GetLeft() == 22 and PTR_IssueReporter:GetBottom() == 248)
assert(Blizzard_PTRIssueReporter_Saved.x == 22 and Blizzard_PTRIssueReporter_Saved.unrelated)
assert(RXP.currentGuide.name == "Test" and RXP.step == 7)
assert(RXP.settings.profile.option == false)
assert(RXP.string == "pending source" and RXPString == "saved source")
-- Later attempts must not reset positions the user has changed.
TomTomCrazyArrow.point[4] = 321
second.RestoreBackup()
assert(TomTomCrazyArrow.point[4] == 321)
second.SaveBackup()
assert(ForeverHelperDB.tomtom.profile.arrow.position[4] == 321)
-- Recover uses the latest snapshot, never an older fixed rescue copy.
ForeverHelperAccountDB.recovery = { version = 1, savedAt = "old", bugButton = { x = 1, y = 2 } }
TomTomCrazyArrow.point[4] = 888
RXP.step = 99
second.RecoverBackup()
assert(TomTomCrazyArrow.point[4] == 321 and RXP.step == 7)
ForeverHelperAccountDB.recovery = nil
-- Missing optional addons preserve existing backups.
TomTom, RXP, PTR_IssueReporter, RXPTT_DB = nil, nil, nil, nil
local third = NewSession()
third.RestoreBackup()
third.SaveBackup()
assert(ForeverHelperDB.tomtom.profile.arrow.position[4] == 321)
assert(ForeverHelperDB.importedGuides.custom)
-- A failed/incompatible cache load must preserve the backup, including on logout.
InitializeAddons()
local fourth = NewSession()
RXP.LoadCachedGuides = function() RXP.db.profile.guides.custom = nil end
fourth.RestoreBackup()
fourth.SaveBackup()
assert(ForeverHelperDB.importedGuides.custom)
assert(ForeverHelperDB.restedXP.guide.name == "Test")
-- Exceptions during cache loading must not lose the original import strings.
InitializeAddons()
RXP.string, RXPString = "pending", "saved"
RXP.LoadCachedGuides = function() error("bad cache") end
local fifth = NewSession()
fifth.RestoreBackup()
assert(RXP.string == "pending" and RXPString == "saved")
-- A cold start can lose the per-character file; the account copy survives.
local previousTime = ForeverHelperDB.savedAt
ForeverHelperDB = nil
InitializeAddons()
local cold = NewSession()
assert(ForeverHelperDB.savedAt == previousTime)
cold.RestoreBackup()
assert(RXP.currentGuide.name == "Test" and RXP.step == 7)
assert(TomTomCrazyArrow.point[4] == 321)
-- The snapshots do not share tables, and characters remain isolated.
ForeverHelperDB.tomtom.profile.arrow.position[4] = 999
assert(ForeverHelperAccountDB.characters[character].tomtom.profile.arrow.position[4] == 321)
character = "Player-70-5678"
ForeverHelperDB = nil
local other = NewSession()
assert(ForeverHelperDB.tomtom == nil)
-- The old per-character format migrates without needing an account backup.
character = "Player-70-legacy"
ForeverHelperDB = { version = 1, savedAt = "legacy", bugButton = { x = 10, y = 20 } }
local legacy = NewSession()
assert(ForeverHelperAccountDB.characters[character].bugButton.x == 10)
-- Explicit recovery replaces the session snapshot and retries restoration.
ForeverHelperDB = { version = 1 }
ForeverHelperAccountDB.characters[character] = nil
ForeverHelperAccountDB.recovery = {
    version = 1, savedAt = "recovered", bugButton = { x = 30, y = 40 },
}
legacy.RecoverBackup()
assert(PTR_IssueReporter:GetLeft() == 30)
assert(ForeverHelperAccountDB.characters[character].savedAt == "recovered")
-- Recovery remains available even if its SavedVariables file disappeared.
ForeverHelperDB = { version = 1 }
ForeverHelperAccountDB.characters[character] = nil
ForeverHelperAccountDB.recovery = nil
local loads = 0
C_AddOns = { LoadAddOn = function(name)
    assert(name == "ForeverHelperRecovery")
    loads = loads + 1
    ForeverHelperRecoverySnapshot = {
        version = 1, savedAt = "addon snapshot", bugButton = { x = 55, y = 66 },
    }
    return true
end }
legacy.RecoverBackup()
assert(loads == 1 and PTR_IssueReporter:GetLeft() == 55)
assert(ForeverHelperAccountDB.characters[character].savedAt == "addon snapshot")
-- A missing recovery addon must leave the current backup intact.
ForeverHelperRecoverySnapshot = nil
C_AddOns.LoadAddOn = function() return nil, "MISSING" end
legacy.RecoverBackup()
assert(ForeverHelperDB.savedAt == "addon snapshot")
-- Initialization waits until the game exposes a character ID.
character = nil
local waiting = {}
assert(loadfile("Backup.lua"))("Forever Helper", waiting)
assert(waiting.InitializeBackup() == false)
realPrint("backup tests passed")
