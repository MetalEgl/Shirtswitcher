-- Addon initialization
ShirtswitcherDB = ShirtswitcherDB or {}
Shirtswitcher = {}

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("CRAFT_SHOW")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("CRAFT_CLOSE")
frame:RegisterEvent("TRADE_SKILL_CLOSE")
frame:RegisterEvent("SPELLCAST_START")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_LOGOUT")

-- Configuration
local NEW_BEGINNINGS_ID = 26003  -- XP shirt
local SAVANT_ID = 26013          -- Profession shirt
local SILVERTONGUE_ID = 26011    -- Reputation shirt
Shirtswitcher.currentMode = "xp"  -- Default mode
Shirtswitcher.chatMessagesEnabled = true  -- Default to showing chat messages
Shirtswitcher.tradeskillWindowOpen = false  -- Track if a tradeskill window is open
Shirtswitcher.addonEnabled = true  -- Track if the addon is enabled
Shirtswitcher.availableShirts = {}  -- Track which shirts are available
local gatheringSkills = {
    ["Skinning"] = {maxSkill = 300},
    ["Mining"] = {maxSkill = 300},
    ["Herbalism"] = {maxSkill = 300, spellName = "Herb Gathering"}
}

-- Function to check if player has a specific shirt (in bags or equipped)
local function HasShirt(itemID)
    local equippedLink = GetInventoryItemLink("player", 4)
    if equippedLink and string.find(equippedLink, "item:"..itemID) then
        return true
    end
    
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(link, "item:"..itemID) then
                return true
            end
        end
    end
    return false
end

-- Function to get the currently equipped shirt ID
local function GetEquippedShirtID()
    local link = GetInventoryItemLink("player", 4)
    if link then
        local _, _, itemID = string.find(link, "item:(%d+):")
        return tonumber(itemID)
    end
    return nil
end

-- Function to check profession skill level
local function CheckProfessionSkill(specificSkill)
    local numSkills = GetNumSkillLines()
    for i = 1, numSkills do
        local skillName, _, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)
        if gatheringSkills[skillName] then
            gatheringSkills[skillName].currentRank = skillRank
            gatheringSkills[skillName].currentMaxRank = skillMaxRank
            if specificSkill then
                if skillName == specificSkill or (gatheringSkills[skillName].spellName and gatheringSkills[skillName].spellName == specificSkill) then
                    return skillRank, skillMaxRank, gatheringSkills[skillName].maxSkill
                end
            end
        end
    end
    if specificSkill then
        return 0, 0, 0
    end
end

-- Function to check if any gathering skill is maxed
local function AnyGatheringSkillMaxed()
    for skillName, skillInfo in pairs(gatheringSkills) do
        if skillInfo.currentRank and skillInfo.currentRank >= skillInfo.maxSkill then
            return true
        end
    end
    return false
end

-- Function to rescan for all shirts
local function RescanShirts()
    Shirtswitcher.availableShirts = {
        [NEW_BEGINNINGS_ID] = HasShirt(NEW_BEGINNINGS_ID),
        [SILVERTONGUE_ID] = HasShirt(SILVERTONGUE_ID),
        [SAVANT_ID] = HasShirt(SAVANT_ID)
    }
    
    local shirtCount = 0
    for _, hasShirt in pairs(Shirtswitcher.availableShirts) do
        if hasShirt then shirtCount = shirtCount + 1 end
    end
    
    if shirtCount < 2 then
        Shirtswitcher.addonEnabled = false
        if Shirtswitcher.chatMessagesEnabled then
            DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: Less than two special shirts found. Addon disabled.", 1, 0, 0)
        end
    else
        Shirtswitcher.addonEnabled = true
        if not Shirtswitcher.availableShirts[NEW_BEGINNINGS_ID] and Shirtswitcher.currentMode == "xp" then
            Shirtswitcher.currentMode = "reputation"
        elseif not Shirtswitcher.availableShirts[SILVERTONGUE_ID] and Shirtswitcher.currentMode == "reputation" then
            Shirtswitcher.currentMode = "xp"
        end
    end
    
    if Shirtswitcher.minimapButton then
        Shirtswitcher:UpdateMinimapButton()
    end
    return Shirtswitcher.addonEnabled
end

-- Function to equip a shirt
local function EquipShirt(itemID)
    if not Shirtswitcher.addonEnabled then return false end
    
    local equippedLink = GetInventoryItemLink("player", 4)
    if equippedLink and string.find(equippedLink, "item:"..itemID) then
        return true
    end
    
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(link, "item:"..itemID) then
                PickupContainerItem(bag, slot)
                PickupInventoryItem(4)
                Shirtswitcher:UpdateMinimapButton()
                return true
            end
        end
    end
    return false
end

-- Function to toggle chat messages
local function ToggleChatMessages()
    Shirtswitcher.chatMessagesEnabled = not Shirtswitcher.chatMessagesEnabled
    if Shirtswitcher.chatMessagesEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: Chat messages enabled")
    else
        DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: Chat messages disabled")
    end
    Shirtswitcher:UpdateMinimapButton()
end

-- Function to toggle mode
function Shirtswitcher:ToggleMode()
    RescanShirts()

    if not self.addonEnabled then
        if self.chatMessagesEnabled then
            DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: Addon is disabled due to insufficient shirts.", 1, 0, 0)
        end
        return
    end
    
    local nextMode = self.currentMode == "xp" and "reputation" or "xp"
    local nextShirtID = nextMode == "xp" and NEW_BEGINNINGS_ID or SILVERTONGUE_ID
    
    if self.availableShirts[nextShirtID] then
        self.currentMode = nextMode
        EquipShirt(nextShirtID)
        if self.chatMessagesEnabled then
            local shirtName = nextMode == "xp" and "New Beginnings" or "Silvertongue"
            DEFAULT_CHAT_FRAME:AddMessage("Switched to " .. shirtName .. " (" .. nextMode:gsub("^%l", string.upper) .. " Mode)")
        end
    else
        if self.chatMessagesEnabled then
            DEFAULT_CHAT_FRAME:AddMessage("Cannot switch mode: " .. nextMode:gsub("^%l", string.upper) .. " shirt not available.", 1, 0, 0)
        end
    end
    self:UpdateMinimapButton()
end

-- Minimap button functionality
function Shirtswitcher:InitMinimapButton()
    local button = CreateFrame("Button", "ShirtswitcherMinimapButton", Minimap)
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("MEDIUM")
    button:SetToplevel(true)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(18)
    icon:SetHeight(18)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon = icon
    
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", 0, 0)
    
    local errorText = button:CreateFontString(nil, "OVERLAY")
    errorText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    errorText:SetTextColor(1, 0, 0)
    errorText:SetPoint("BOTTOM", button, "BOTTOM", 0, -15)
    errorText:SetText("No shirts")
    errorText:Hide()
    button.errorText = errorText
    
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            Shirtswitcher:ToggleMode()
        elseif arg1 == "RightButton" then
            ToggleChatMessages()
        end
    end)

    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        Shirtswitcher:UpdateTooltip()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    function UpdateMinimapPosition()
        if ShirtswitcherDB.minimapPos then
            local x = ShirtswitcherDB.minimapPos.x
            local y = ShirtswitcherDB.minimapPos.y
            button:ClearAllPoints()
            button:SetPoint("CENTER", Minimap, "CENTER", x, y)
        else
            -- Default position if no saved position exists
            button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -5, 5)
        end
    end

    UpdateMinimapPosition()
    
    button:SetMovable(true)
    button:EnableMouse(true)
    button:SetClampedToScreen(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    button:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local x, y = this:GetCenter()
        local minimapX, minimapY = Minimap:GetCenter()
        local relativeX = x - minimapX
        local relativeY = y - minimapY
        ShirtswitcherDB.minimapPos = {x = relativeX, y = relativeY}
    end)
    
    if GetMinimapShape then
        hooksecurefunc("GetMinimapShape", UpdateMinimapPosition)
    end
    
    Shirtswitcher.minimapButton = button
    self:UpdateMinimapButton()
    button:Show()
end

function Shirtswitcher:UpdateMinimapButton()
    if not self.minimapButton then return end
    
    if not self.addonEnabled then
        self.minimapButton.icon:SetTexture("Interface\\Icons\\INV_Shirt_Grey_01")
        self.minimapButton.errorText:Show()
    else
        self.minimapButton.errorText:Hide()
        local equippedShirtID = GetEquippedShirtID()
        if equippedShirtID == NEW_BEGINNINGS_ID then
            self.minimapButton.icon:SetTexture("Interface\\Icons\\INV_Shirt_White_01")
        elseif equippedShirtID == SILVERTONGUE_ID then
            self.minimapButton.icon:SetTexture("Interface\\Icons\\INV_Shirt_Black_01")
        elseif equippedShirtID == SAVANT_ID then
            self.minimapButton.icon:SetTexture("Interface\\Icons\\INV_Shirt_Orange_01")
        else
            self.minimapButton.icon:SetTexture("Interface\\Icons\\INV_Shirt_Grey_01")
        end
    end
    self.minimapButton.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    if GameTooltip:IsOwned(self.minimapButton) then
        self:UpdateTooltip()
    end
end

function Shirtswitcher:UpdateTooltip()
    GameTooltip:ClearLines()
    if not self.addonEnabled then
        GameTooltip:SetText("Shirtswitcher: Addon Disabled")
        GameTooltip:AddLine("Less than two special shirts found", 1, 0, 0)
    else
        local equippedShirtID = GetEquippedShirtID()
        if equippedShirtID == NEW_BEGINNINGS_ID then
            GameTooltip:SetText("New Beginnings (XP) Shirt Equipped")
        elseif equippedShirtID == SILVERTONGUE_ID then
            GameTooltip:SetText("Silvertongue (Reputation) Shirt Equipped")
        elseif equippedShirtID == SAVANT_ID then
            GameTooltip:SetText("Savant (Profession) Shirt Equipped")
        else
            GameTooltip:SetText("No special shirt equipped")
        end
        
        if self.currentMode == "xp" then
            GameTooltip:AddLine("Current Mode: XP", 1, 1, 0)
        else
            GameTooltip:AddLine("Current Mode: Reputation", 0, 1, 0)
        end
        
        local stuckInMode = false
        if self.currentMode == "xp" and not self.availableShirts[SILVERTONGUE_ID] then
            stuckInMode = true
            GameTooltip:AddLine("Stuck in XP mode (Silvertongue shirt not available)", 1, 0, 0)
        elseif self.currentMode == "reputation" and not self.availableShirts[NEW_BEGINNINGS_ID] then
            stuckInMode = true
            GameTooltip:AddLine("Stuck in Reputation mode (New Beginnings shirt not available)", 1, 0, 0)
        end
        
        if not stuckInMode then
            GameTooltip:AddLine("Left-click to toggle XP/Reputation mode", 1, 1, 1)
        end
        
        GameTooltip:AddLine("Right-click to toggle chat messages " .. (self.chatMessagesEnabled and "off" or "on"), 1, 1, 1)
        
        if self.availableShirts[SAVANT_ID] then
            if AnyGatheringSkillMaxed() then
                GameTooltip:AddLine("Savant shirt available (some skills maxed)", 0, 1, 1)
            else
                GameTooltip:AddLine("Savant shirt available for gathering", 0, 1, 1)
            end
            for skillName, skillInfo in pairs(gatheringSkills) do
                if skillInfo.currentRank then
                    GameTooltip:AddLine(string.format("%s: %d/%d", skillName, skillInfo.currentRank, skillInfo.maxSkill), 1, 1, 1)
                end
            end
        else
            GameTooltip:AddLine("Savant shirt not available", 1, 0, 0)
        end
    end
    GameTooltip:Show()
end

-- Event handler
frame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        -- Initialize default values if they don't exist
        ShirtswitcherDB.currentMode = ShirtswitcherDB.currentMode or "xp"
        ShirtswitcherDB.chatMessagesEnabled = ShirtswitcherDB.chatMessagesEnabled
        if ShirtswitcherDB.chatMessagesEnabled == nil then ShirtswitcherDB.chatMessagesEnabled = true end
        ShirtswitcherDB.minimapPos = ShirtswitcherDB.minimapPos or {x = -15, y = -15}

        -- Load preferences into the addon
        Shirtswitcher.currentMode = ShirtswitcherDB.currentMode
        Shirtswitcher.chatMessagesEnabled = ShirtswitcherDB.chatMessagesEnabled

        -- Initialize minimap button after variables are loaded
        Shirtswitcher:InitMinimapButton()
        
        if Shirtswitcher.chatMessagesEnabled then
            DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher addon loaded. Left-click the minimap button to toggle XP/Reputation mode, right-click to toggle chat messages.")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Delay the initial scan to ensure all data is loaded
        frame:SetScript("OnUpdate", function()
            this.timer = (this.timer or 0) + arg1
            if this.timer >= 1 then
                this:SetScript("OnUpdate", nil)
                RescanShirts()
                Shirtswitcher:UpdateMinimapButton()
            end
        end)
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then
            RescanShirts()
        end
    elseif event == "CRAFT_SHOW" or event == "TRADE_SKILL_SHOW" then
        Shirtswitcher.tradeskillWindowOpen = true
        CheckProfessionSkill()  -- Update all gathering skills
    elseif event == "CRAFT_CLOSE" or event == "TRADE_SKILL_CLOSE" then
        Shirtswitcher.tradeskillWindowOpen = false
        if Shirtswitcher.addonEnabled then
            if Shirtswitcher.currentMode == "xp" and Shirtswitcher.availableShirts[NEW_BEGINNINGS_ID] then
                EquipShirt(NEW_BEGINNINGS_ID)
            elseif Shirtswitcher.availableShirts[SILVERTONGUE_ID] then
                EquipShirt(SILVERTONGUE_ID)
            end
        end
    elseif event == "SPELLCAST_START" then
        if Shirtswitcher.addonEnabled then
            local skillName = arg1
            for profession, info in pairs(gatheringSkills) do
                if skillName == profession or (info.spellName and skillName == info.spellName) then
                    local skillRank, skillMaxRank, absoluteMaxSkill = CheckProfessionSkill(profession)
                    if Shirtswitcher.availableShirts[SAVANT_ID] and skillRank < absoluteMaxSkill then
                        EquipShirt(SAVANT_ID)
                    elseif Shirtswitcher.chatMessagesEnabled and not Shirtswitcher.availableShirts[SAVANT_ID] then
                        DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: Cannot equip 'Savant' shirt - not found in bags or equipped!", 1, 0, 0)
                    end
                    break
                end
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if Shirtswitcher.addonEnabled and UnitExists("target") and not UnitIsDead("target") then
            if UnitCanAttack("player", "target") or not UnitIsPlayer("target") then
                if Shirtswitcher.currentMode == "xp" and Shirtswitcher.availableShirts[NEW_BEGINNINGS_ID] then
                    EquipShirt(NEW_BEGINNINGS_ID)
                elseif Shirtswitcher.availableShirts[SILVERTONGUE_ID] then
                    EquipShirt(SILVERTONGUE_ID)
                end
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        ShirtswitcherDB.currentMode = Shirtswitcher.currentMode
        ShirtswitcherDB.chatMessagesEnabled = Shirtswitcher.chatMessagesEnabled
        -- Minimap position is now saved immediately after dragging, so we don't need to save it here
    end
end)

-- Slash commands
SLASH_SHIRTSWITCHER1 = "/shirtswitcher"
SLASH_SHIRTSWITCHER2 = "/ss"
SlashCmdList["SHIRTSWITCHER"] = function(msg)
    if msg == "toggle" then
        ToggleChatMessages()
    elseif msg == "mode" then
        Shirtswitcher:ToggleMode()
    else
        print("Shirtswitcher commands:")
        print("/ss toggle - Toggle chat messages on/off")
        print("/ss mode - Toggle between XP and Reputation modes")
    end
end

if Shirtswitcher.chatMessagesEnabled then
    DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher addon loaded. Left-click the minimap button to toggle XP/Reputation mode, right-click to toggle chat messages.")
end
