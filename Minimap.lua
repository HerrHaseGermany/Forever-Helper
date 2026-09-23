local _, addon = ...
local menu, button
local icon = "Interface\\Icons\\INV_Misc_PocketWatch_01"
local entries = {
    { "Show status", "status" },
    { "Save snapshot", "save" },
    { "Load snapshot", "recover" },
    { "Retry restoration", "restore" },
    { "Check settings", "check" },
    { "Load starting guide", "guide" },
    { "Select guide …", "guide ", true },
    { "Set arrow position …", "arrow ", true },
    { "Set coordinates frame position …", "coords ", true },
}

local function ToggleMenu()
    if not menu then
        menu = CreateFrame("Frame", "ForeverHelperMenu", UIParent, "BasicFrameTemplateWithInset")
        menu:SetSize(280, 38 + #entries * 29)
        menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        menu:SetFrameStrata("DIALOG")
        menu:SetClampedToScreen(true)
        menu:EnableMouse(true)
        menu.TitleText:SetText("Forever Helper")
        table.insert(UISpecialFrames, "ForeverHelperMenu")
        for index, entry in ipairs(entries) do
            local label, command, input = unpack(entry)
            local item = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
            item:SetSize(256, 25)
            item:SetPoint("TOPLEFT", 12, -30 - (index - 1) * 29)
            item:SetText(label)
            item:SetScript("OnClick", function()
                menu:Hide()
                if input then
                    ChatFrame_OpenChat("/fh " .. command)
                else
                    SlashCmdList.FOREVERHELPER(command)
                end
            end)
        end
        menu:Hide()
    end
    if menu:IsShown() then menu:Hide() else menu:Show() end
end

local function Tooltip(tooltip)
    tooltip:AddLine("Forever Helper")
    tooltip:AddLine("Click to open the command menu", 1, 1, 1)
end

function addon.InitializeMinimap()
    if button or not Minimap then return end
    local lib = LibStub and LibStub.GetLibrary and LibStub:GetLibrary("LibDBIcon-1.0", true)
    if lib then
        -- Keep this table outside snapshots so recovery never invalidates the
        -- library's settings reference. ForeverMinimap can collect this button.
        ForeverHelperAccountDB.minimap = ForeverHelperAccountDB.minimap or { minimapPos = 220 }
        lib:Register("ForeverHelper", {
            type = "launcher", icon = icon,
            OnClick = ToggleMenu, OnTooltipShow = Tooltip,
        }, ForeverHelperAccountDB.minimap)
        button = lib:GetMinimapButton("ForeverHelper")
    else
        -- Standalone fallback when TomTom/LibDBIcon is not installed.
        button = CreateFrame("Button", "ForeverHelperMinimapButton", Minimap)
        button:SetSize(32, 32)
        button:SetPoint("CENTER", Minimap, "CENTER", -55, -55)
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        button:SetNormalTexture(icon)
        button:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", ToggleMenu)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            Tooltip(GameTooltip)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
end
