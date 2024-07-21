-- Addon initialization
Shirtswitcher = {}
local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("CRAFT_SHOW")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("SPELLCAST_START")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_LOGOUT")

-- Configuration
local NEW_BEGINNINGS_ID = 26003  -- XP shirt
local SAVANT_ID = 26013          -- Profession shirt
local SILVERTONGUE_ID = 26011    -- Reputation shirt
Shirtswitcher.currentMode = "xp"  -- Default mode (XP mode uses New Beginnings shirt)
Shirtswitcher.hasNewBeginnings = false
Shirtswitcher.hasSilvertongue = false
Shirtswitcher.hasSavant = false
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

-- Function to rescan for all shirts
local function RescanShirts()
    Shirtswitcher.hasNewBeginnings = HasShirt(NEW_BEGINNINGS_ID)
    Shirtswitcher.hasSilvertongue = HasShirt(SILVERTONGUE_ID)
    Shirtswitcher.hasSavant = HasShirt(SAVANT_ID)
end

-- Function to scan only for Savant shirt
local function ScanSavantShirt()
    local previousState = Shirtswitcher.hasSavant
    Shirtswitcher.hasSavant = HasShirt(SAVANT_ID)
    if Shirtswitcher.hasSavant ~= previousState then
        if Shirtswitcher.hasSavant then
            DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: 'Savant' shirt found!", 0, 1, 0)
        else
            DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: 'Savant' shirt not found!", 1, 0, 0)
        end
    end
end

-- Function to equip a shirt
local function EquipShirt(itemID)
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
                return true
            end
        end
    end
    return false
end

-- Function to toggle between XP and Reputation modes
local function ToggleShirt()
    RescanShirts()  -- Rescan before toggling
    if not Shirtswitcher.hasNewBeginnings or not Shirtswitcher.hasSilvertongue then
        DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: You need both 'New Beginnings' and 'Silvertongue' shirts to toggle.")
        return
    end
    
    if Shirtswitcher.currentMode == "xp" then
        Shirtswitcher.currentMode = "reputation"
        EquipShirt(SILVERTONGUE_ID)
        DEFAULT_CHAT_FRAME:AddMessage("Switched to Silvertongue (Reputation Mode)")
    else
        Shirtswitcher.currentMode = "xp"
        EquipShirt(NEW_BEGINNINGS_ID)
        DEFAULT_CHAT_FRAME:AddMessage("Switched to New Beginnings (XP Mode)")
    end
    Shirtswitcher:UpdateMinimapButton()
end

-- Event handler
frame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        -- Load saved mode
        if ShirtswitcherDB and ShirtswitcherDB.currentMode then
            Shirtswitcher.currentMode = ShirtswitcherDB.currentMode
            DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: Loaded last used mode - " .. 
                (Shirtswitcher.currentMode == "xp" and "XP (New Beginnings)" or "Reputation (Silvertongue)"))
        end
        -- Initial scan for shirts
        RescanShirts()
        if not Shirtswitcher.hasSavant then
            DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: Warning - 'Savant' shirt not found in bags or equipped!", 1, 0, 0)
        end
        -- Initialize minimap button after variables are loaded
        Shirtswitcher:InitMinimapButton()
    elseif event == "QUEST_DETAIL" or event == "GOSSIP_SHOW" then
        if Shirtswitcher.currentMode == "xp" then
            EquipShirt(NEW_BEGINNINGS_ID)
        else
            EquipShirt(SILVERTONGUE_ID)
        end
    elseif event == "CRAFT_SHOW" or event == "TRADE_SKILL_SHOW" then
        ScanSavantShirt()  -- Scan for Savant shirt when opening profession window
        if Shirtswitcher.hasSavant then
            EquipShirt(SAVANT_ID)
        else
            DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: Cannot equip 'Savant' shirt - not found in bags or equipped!", 1, 0, 0)
        end
    elseif event == "SPELLCAST_START" then
        if gatheringSkills[arg1] then
            ScanSavantShirt()  -- Scan for Savant shirt when starting a gathering skill
            if Shirtswitcher.hasSavant then
                EquipShirt(SAVANT_ID)
            else
                DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher: Cannot equip 'Savant' shirt - not found in bags or equipped!", 1, 0, 0)
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitExists("target") then
            if UnitCanAttack("player", "target") then
                if Shirtswitcher.currentMode == "xp" then
                    EquipShirt(NEW_BEGINNINGS_ID)
                else
                    EquipShirt(SILVERTONGUE_ID)
                end
            elseif not UnitIsPlayer("target") then  -- Check if target is an NPC
                if Shirtswitcher.currentMode == "xp" then
                    EquipShirt(NEW_BEGINNINGS_ID)
                else
                    EquipShirt(SILVERTONGUE_ID)
                end
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        if not ShirtswitcherDB then ShirtswitcherDB = {} end
        ShirtswitcherDB.currentMode = Shirtswitcher.currentMode
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
    
    button:SetScript("OnClick", ToggleShirt)
    
    -- Tooltip functionality
    button:SetScript("OnEnter", function()
        RescanShirts()  -- Rescan shirts when hovering over the button
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        if Shirtswitcher.currentMode == "xp" then
            GameTooltip:SetText("XP Mode (New Beginnings)")
            GameTooltip:AddLine("Click to switch to Reputation Mode (Silvertongue)", 1, 1, 1)
        else
            GameTooltip:SetText("Reputation Mode (Silvertongue)")
            GameTooltip:AddLine("Click to switch to XP Mode (New Beginnings)", 1, 1, 1)
        end
        if not Shirtswitcher.hasNewBeginnings then
            GameTooltip:AddLine("Warning: 'New Beginnings' shirt not found!", 1, 0, 0)
        end
        if not Shirtswitcher.hasSilvertongue then
            GameTooltip:AddLine("Warning: 'Silvertongue' shirt not found!", 1, 0, 0)
        end
        if not Shirtswitcher.hasSavant then
            GameTooltip:AddLine("Warning: 'Savant' shirt not found!", 1, 0, 0)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Minimap button positioning
    local function UpdatePosition()
        local angle = ShirtswitcherDB.minimapPos or random(0, 360)
        local x = cos(angle)
        local y = sin(angle)
        button:SetPoint("CENTER", Minimap, "CENTER", x * 80, y * 80)
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
        local x, y = this:GetCenter()
        local cx, cy = Minimap:GetCenter()
        ShirtswitcherDB.minimapPos = deg(atan2(y - cy, x - cx))
        UpdatePosition()
    end)
    
    if not ShirtswitcherDB then ShirtswitcherDB = {} end
    if not ShirtswitcherDB.minimapPos then
        ShirtswitcherDB.minimapPos = random(0, 360)
    end
    
    UpdatePosition()
    Shirtswitcher.minimapButton = button
    Shirtswitcher:UpdateMinimapButton()  -- Ensure the icon is set immediately
    button:Show()
end

function Shirtswitcher:UpdateMinimapButton()
    if not Shirtswitcher.minimapButton then return end
    
    if Shirtswitcher.currentMode == "xp" then
        Shirtswitcher.minimapButton.icon:SetTexture("Interface\\Icons\\INV_Shirt_White_01")
    else
        Shirtswitcher.minimapButton.icon:SetTexture("Interface\\Icons\\INV_Shirt_Black_01")
    end
    Shirtswitcher.minimapButton.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
end

-- Slash commands
SLASH_SWITCHSHIRT1 = "/switchshirt"
SLASH_SWITCHSHIRT2 = "/ss"
SlashCmdList["SWITCHSHIRT"] = ToggleShirt

DEFAULT_CHAT_FRAME:AddMessage("Shirtswitcher addon loaded. Use /switchshirt, /ss, or click the minimap icon to toggle between XP (New Beginnings) and Reputation (Silvertongue) modes.")
