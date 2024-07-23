-- Addon initialization
Shirtswitcher = {}
local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
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
    ["Skinning"] = true,
    ["Mining"] = true,
    ["Herb Gathering"] = true
}

-- Function to check if player has a specific shirt (in bags or equipped)
local function HasShirt(itemID)
    -- Check equipped shirt
    local equippedLink = GetInventoryItemLink("player", 4) -- 4 is the slot ID for shirts
    if equippedLink and string.find(equippedLink, "item:"..itemID) then
        return true
    end
    
    -- Check bags
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
    local link = GetInventoryItemLink("player", 4)  -- 4 is the slot ID for shirts
    if link then
        local _, _, itemID = string.find(link, "item:(%d+):")
        return tonumber(itemID)
    end
    return nil
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
        -- Ensure currentMode is set to a mode with an available shirt
        if not Shirtswitcher.availableShirts[NEW_BEGINNINGS_ID] and Shirtswitcher.currentMode == "xp" then
            Shirtswitcher.currentMode = "reputation"
        elseif not Shirtswitcher.availableShirts[SILVERTONGUE_ID] and Shirtswitcher.currentMode == "reputation" then
            Shirtswitcher.currentMode = "xp"
        end
    end
    
    Shirtswitcher:UpdateMinimapButton()
    return Shirtswitcher.addonEnabled
end

-- Function to equip a shirt
local function EquipShirt(itemID)
    if not Shirtswitcher.addonEnabled then return false end
    
    -- Check if already equipped
    local equippedLink = GetInventoryItemLink("player", 4)
    if equippedLink and string.find(equippedLink, "item:"..itemID) then
        return true
    end
    
    -- Check bags and equip if found
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(link, "item:"..itemID) then
                PickupContainerItem(bag, slot)
                PickupInventoryItem(4)  -- 4 is the slot ID for shirts
                Shirtswitcher:UpdateMinimapButton()  -- Update minimap button after equipping
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
    -- Rescan shirts before attempting to switch modes
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

-- Event handler
frame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        -- Load saved preferences
        if ShirtswitcherDB then
            Shirtswitcher.currentMode = ShirtswitcherDB.currentMode or Shirtswitcher.currentMode
            Shirtswitcher.chatMessagesEnabled = ShirtswitcherDB.chatMessagesEnabled
            if Shirtswitcher.chatMessagesEnabled == nil then Shirtswitcher.chatMessagesEnabled = true end
        end
        -- Initial scan for shirts
        RescanShirts()
        -- Initialize minimap button after variables are loaded
        Shirtswitcher:InitMinimapButton()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then
            RescanShirts()
        end
    elseif event == "CRAFT_SHOW" or event == "TRADE_SKILL_SHOW" then
        Shirtswitcher.tradeskillWindowOpen = true
        if Shirtswitcher.addonEnabled and Shirtswitcher.availableShirts[SAVANT_ID] then
            EquipShirt(SAVANT_ID)
        end
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
        if Shirtswitcher.addonEnabled and (Shirtswitcher.tradeskillWindowOpen or gatheringSkills[arg1]) then
            if Shirtswitcher.availableShirts[SAVANT_ID] then
                EquipShirt(SAVANT_ID)
            elseif Shirtswitcher.chatMessagesEnabled then
                DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: Cannot equip 'Savant' shirt - not found in bags or equipped!", 1, 0, 0)
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
        if not ShirtswitcherDB then ShirtswitcherDB = {} end
        ShirtswitcherDB.currentMode = Shirtswitcher.currentMode
        ShirtswitcherDB.chatMessagesEnabled = Shirtswitcher.chatMessagesEnabled
        -- Save minimap button position
        local point, _, _, x, y = Shirtswitcher.minimapButton:GetPoint()
        ShirtswitcherDB.minimapPos = {point, x, y}
    end
end)

-- Minimap button functionality
function Shirtswitcher:InitMinimapButton()
    local button = CreateFrame("Button", "ShirtswitcherMinimapButton", Minimap)
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("LOW")
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
    errorText:SetTextColor(1, 0, 0)  -- Red color
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
    
    -- Tooltip functionality
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        Shirtswitcher:UpdateTooltip()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Restore minimap button position
    if ShirtswitcherDB and ShirtswitcherDB.minimapPos then
        button:SetPoint(ShirtswitcherDB.minimapPos[1], Minimap, ShirtswitcherDB.minimapPos[1], ShirtswitcherDB.minimapPos[2], ShirtswitcherDB.minimapPos[3])
    else
        button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    end
    
    -- Make the button draggable
    button:SetMovable(true)
    button:EnableMouse(true)
    button:SetClampedToScreen(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    button:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        -- Save the new position
        local point, _, _, x, y = this:GetPoint()
        ShirtswitcherDB.minimapPos = {point, x, y}
    end)
    
    Shirtswitcher.minimapButton = button
    self:UpdateMinimapButton()  -- Ensure the icon is set immediately
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

    -- Update tooltip if it's currently shown
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
        
        -- Add mode information with color coding
        if self.currentMode == "xp" then
            GameTooltip:AddLine("Current Mode: XP", 1, 1, 0)  -- Yellow color
        else
            GameTooltip:AddLine("Current Mode: Reputation", 0, 1, 0)  -- Green color
        end
        
        -- Check if player is stuck in current mode
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
        
        -- Add information about Savant shirt
        if self.availableShirts[SAVANT_ID] then
            GameTooltip:AddLine("Savant shirt available for professions", 0, 1, 1)
        else
            GameTooltip:AddLine("Savant shirt not available", 1, 0, 0)
        end
    end
    GameTooltip:Show()
end

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
