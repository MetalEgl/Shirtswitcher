-- Addon initialization
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("CRAFT_SHOW")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("SPELLCAST_START")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")

-- Configuration
local QUEST_SHIRT_ID = 26003 -- New Beginnings
local PROFESSION_SHIRT_ID = 26013  -- Savant

local gatheringSkills = {
    ["Skinning"] = true,
    ["Mining"] = true,
    ["Herb Gathering"] = true  
}

-- Function to equip a shirt
local function EquipShirt(itemID)
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

-- Event handler
frame:SetScript("OnEvent", function()
    if event == "QUEST_DETAIL" then
        EquipShirt(QUEST_SHIRT_ID)
    elseif event == "CRAFT_SHOW" or event == "TRADE_SKILL_SHOW" then
        EquipShirt(PROFESSION_SHIRT_ID)
    elseif event == "SPELLCAST_START" then
        local spellName = arg1
        if gatheringSkills[spellName] then
            EquipShirt(PROFESSION_SHIRT_ID)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitExists("target") and UnitCanAttack("player", "target") then
            EquipShirt(QUEST_SHIRT_ID)
        end
    end
end)

-- Slash command to force switch to quest shirt
SLASH_SWITCHSHIRT1 = "/switchshirt"
SLASH_SWITCHSHIRT2 = "/ss"
SlashCmdList["SWITCHSHIRT"] = function(msg)
    EquipShirt(QUEST_SHIRT_ID)
end

print("ShirtSwitcher addon loaded. Use /switchshirt or /ss to manually switch to the quest shirt.")
