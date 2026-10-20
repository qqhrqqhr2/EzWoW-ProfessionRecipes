--===========================================================================
-- EzWoW - Profession Recipes
-- Modules/RecipeIndex.lua : Profession Recipe & Reagent Reverse Lookup Indexer
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local RecipeCatalogIndex = ns.RecipeCatalogIndex or {}
ns.RecipeCatalogIndex = RecipeCatalogIndex
local payloadData, localizedItemNameTable = ns.Data, ns.ItemNames
local CLIENT_LANG = ns.CLIENT_LANG
local PROFESSIONS = ns.PROFESSIONS
local R_SPELL, R_ITEM, R_CAT, R_ORANGE, R_YELLOW, R_GREEN, R_GREY = ns.R_SPELL, ns.R_ITEM, ns.R_CAT, ns.R_ORANGE, ns.R_YELLOW, ns.R_GREEN, ns.R_GREY
local R_FLAGS, R_QTY, R_ICON, R_NAME_KO, R_NAME_EN, R_REAG = ns.R_FLAGS, ns.R_QTY, ns.R_ICON, ns.R_NAME_KO, ns.R_NAME_EN, ns.R_REAG
local R_DESC_KO, R_DESC_EN, R_SRC_KO, R_SRC_EN = ns.R_DESC_KO, ns.R_DESC_EN, ns.R_SRC_KO, ns.R_SRC_EN
local F_NEW, F_TRAINER, F_ALLIANCE, F_HORDE = ns.F_NEW, ns.F_TRAINER, ns.F_ALLIANCE, ns.F_HORDE

local recipeProfessionMap, reagentLookupIndex
function RecipeCatalogIndex.constructRecipeLookupIndex()
    if recipeProfessionMap then return end
    recipeProfessionMap, reagentLookupIndex = {}, {}
    for skill, payloadData2 in pairs(payloadData) do
        for _, rowEntry in ipairs(payloadData2.recipes) do
            recipeProfessionMap[rowEntry] = skill
            for _, rgVal in ipairs(rowEntry[13]) do
                local resolvedValue = reagentLookupIndex[rgVal[1]]
                if not resolvedValue then resolvedValue = {}; reagentLookupIndex[rgVal[1]] = resolvedValue end
                resolvedValue[#resolvedValue + 1] = rowEntry
            end
        end
    end
end
function RecipeCatalogIndex.resolveRecipeName(rowEntry)
    local nodeEntry = ns.IS_KO and rowEntry[R_NAME_KO] or rowEntry[R_NAME_EN]
    if not nodeEntry or nodeEntry == "" then nodeEntry = rowEntry[R_NAME_EN] or rowEntry[R_NAME_KO] or ("#" .. tostring(rowEntry[R_SPELL])) end
    return nodeEntry
end
function RecipeCatalogIndex.resolveRecipeDesc(rowEntry)
    local dataEntry = ns.IS_KO and rowEntry[R_DESC_KO] or rowEntry[R_DESC_EN]
    if not dataEntry or dataEntry == "" then dataEntry = rowEntry[R_DESC_EN] or rowEntry[R_DESC_KO] or "" end
    return dataEntry
end

local playerFaction
function RecipeCatalogIndex.resolvePlayerFaction()
    if playerFaction then return playerFaction end
    local isCallOk, windowFrame = pcall(UnitFactionGroup, "player")
    if isCallOk and (windowFrame == "Alliance" or windowFrame == "Horde") then playerFaction = windowFrame end
    return playerFaction
end

function RecipeCatalogIndex.hasOtherFaction(rowEntry)
    local windowFrame = RecipeCatalogIndex.resolvePlayerFaction()
    if not windowFrame then return false end
    if windowFrame == "Alliance" then return bit.band(rowEntry[R_FLAGS], F_HORDE) ~= 0 end
    return bit.band(rowEntry[R_FLAGS], F_ALLIANCE) ~= 0
end

function RecipeCatalogIndex.resolveRecipeSrc(rowEntry)
    local raw = (ns.IS_KO and rowEntry[R_SRC_KO] or rowEntry[R_SRC_EN])
    if not raw or raw == "" then raw = rowEntry[R_SRC_EN] or rowEntry[R_SRC_KO] or "" end
    if raw == "" or not raw:find("@", 1, true) then return raw end
    local mine = RecipeCatalogIndex.resolvePlayerFaction()
    local outputList = {}
    for line in (raw .. "\n"):gmatch("(.-)\n") do
        local tag, rest = line:match("^@([AH]) (.*)$")
        if not tag then
            outputList[#outputList + 1] = line
        elseif not mine or (tag == "A" and mine == "Alliance") or (tag == "H" and mine == "Horde") then
            outputList[#outputList + 1] = rest
        end
    end
    if #outputList == 0 then 
        for line in (raw .. "\n"):gmatch("(.-)\n") do outputList[#outputList + 1] = (line:gsub("^@[AH] ", "")) end
    end
    return table.concat(outputList, "\n")
end

local resolveItemNameByID = (C_Item and C_Item.GetItemNameByID) or function(id) return (GetItemInfo(id)) end
local resolveItemIconByID = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local resolveItemQualityByID = (C_Item and C_Item.GetItemQualityByID) or function(id) return select(3, GetItemInfo(id)) end
local queryItemCountAPI = (C_Item and C_Item.GetItemCount) or GetItemCount
local queryItemInfoAPI = (C_Item and C_Item.GetItemInfo) or GetItemInfo

function RecipeCatalogIndex.resolveItemName(id)
    
    if ns.ACTIVE_LANG ~= CLIENT_LANG and (ns.ACTIVE_LANG == "ko" or ns.ACTIVE_LANG == "en") and localizedItemNameTable[id] then
        return localizedItemNameTable[id][ns.LI] or localizedItemNameTable[id][2] or ("#" .. id)
    end
    local nodeEntry = resolveItemNameByID(id)
    if nodeEntry and nodeEntry ~= "" then return nodeEntry end
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    local windowFrame = localizedItemNameTable[id]
    return (windowFrame and (windowFrame[ns.LI] or windowFrame[2])) or ("#" .. id)
end
ns.ItemName = RecipeCatalogIndex.resolveItemName

function RecipeCatalogIndex.resolveItemIcon(id, fallback)
    local resolvedValue = resolveItemIconByID and resolveItemIconByID(id)
    if resolvedValue then return resolvedValue end
    if fallback and fallback ~= "" then return "Interface\\Icons\\" .. fallback end
    return 134400 
end

function RecipeCatalogIndex.resolveQualityHex(id)
    local priorityQueue = id and id > 0 and resolveItemQualityByID(id)
    if priorityQueue and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[priorityQueue] then
        return ITEM_QUALITY_COLORS[priorityQueue].hex
    end
    return "|cffffd100"
end

function RecipeCatalogIndex.resolveRecipeIcon(rowEntry)
    if rowEntry[R_ICON] ~= "" then return "Interface\\Icons\\" .. rowEntry[R_ICON] end
    if rowEntry[R_ITEM] > 0 then return RecipeCatalogIndex.resolveItemIcon(rowEntry[R_ITEM]) end
    local textureRegion = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(rowEntry[R_SPELL])
    return textureRegion or 134400
end

function RecipeCatalogIndex.resolveSkillText(rowEntry)
    local parts = { "|cffff8040" .. rowEntry[R_ORANGE] .. "|r" }
    if rowEntry[R_YELLOW] > 0 then
        parts[#parts + 1] = "|cffffff00" .. rowEntry[R_YELLOW] .. "|r"
        parts[#parts + 1] = "|cff40bf40" .. rowEntry[R_GREEN] .. "|r"
        parts[#parts + 1] = "|cff808080" .. rowEntry[R_GREY] .. "|r"
    end
    return table.concat(parts, "  ")
end

-----------------------------------------------------------------------------
-- Scan Learned Profession Ids
-----------------------------------------------------------------------------
function RecipeCatalogIndex.scanLearnedProfessionIDs()
    local learned = {}
    if GetProfessions and GetProfessionInfo then
        local itemList = { GetProfessions() }
        for index = 1, 6 do
            local entryIndex = itemList[index]
            if entryIndex then
                local skillLine = select(7, GetProfessionInfo(entryIndex))
                if skillLine then learned[skillLine] = true end
            end
        end
    end
    
    local RANK_SPELLS = {
        [171] = { 2259, 3101, 3464, 11611 }, [164] = { 2018, 3100, 3538, 9785 },
        [333] = { 7411, 7412, 7413, 13920 }, [202] = { 4036, 4037, 4038, 12656 },
        [165] = { 2108, 3104, 3811, 10662 }, [197] = { 3908, 3909, 3910, 12180 },
        [186] = { 2575, 2576, 3564, 10248, 2656 }, [185] = { 2550, 3102, 3413, 18260 },
        [129] = { 3273, 3274, 7924, 10846 },
        [182] = { 2366, 2368, 3570, 11993 }, [393] = { 8613, 8617, 8618, 10768 },
        [356] = { 7620, 7731, 7732, 18248 },
    }
    local hasKnown = IsPlayerSpell or IsSpellKnown
    if hasKnown then
        for skill, spells in pairs(RANK_SPELLS) do
            for _, id in ipairs(spells) do
                local isCallOk, known = pcall(hasKnown, id)
                if isCallOk and known then learned[skill] = true break end
            end
        end
    end
    
    if GetNumSkillLines and GetSkillLineInfo then
        local names = {}
        for _, anchorTarget in ipairs(PROFESSIONS) do
            for _, entryKey in ipairs({ "ko", "en", "de", "fr", "es", "ru", "zhCN", "zhTW" }) do
                if anchorTarget[entryKey] then names[anchorTarget[entryKey]] = anchorTarget.id end
            end
        end
        for index = 1, GetNumSkillLines() do
            local displayName, hasHeader = GetSkillLineInfo(index)
            if displayName and not hasHeader and names[displayName] then learned[names[displayName]] = true end
        end
    end
    return learned
end

ns.RebuildRecipeAndReagentIndexes = RecipeCatalogIndex.constructRecipeLookupIndex
ns.ResolveRecipeProfessionKey = function() RecipeCatalogIndex.constructRecipeLookupIndex(); return recipeProfessionMap end
ns.GetReagentIndex = function() RecipeCatalogIndex.constructRecipeLookupIndex(); return reagentLookupIndex end
ns.GetLocalizedRecipeName = RecipeCatalogIndex.resolveRecipeName
ns.GetLocalizedRecipeDescription = RecipeCatalogIndex.resolveRecipeDesc
ns.PlayerFaction = RecipeCatalogIndex.resolvePlayerFaction
ns.IsOtherFaction = RecipeCatalogIndex.hasOtherFaction
ns.GetLocalizedRecipeSourceText = RecipeCatalogIndex.resolveRecipeSrc
ns.ItemName = RecipeCatalogIndex.resolveItemName
ns.ItemIcon = RecipeCatalogIndex.resolveItemIcon
ns.QualityHex = RecipeCatalogIndex.resolveQualityHex
ns.ResolveRecipeDisplayIcon = RecipeCatalogIndex.resolveRecipeIcon
ns.FormatRecipeDifficultyThresholds = RecipeCatalogIndex.resolveSkillText
ns.GetLearnedSkillLines = RecipeCatalogIndex.scanLearnedProfessionIDs
ns.QueryItemCountSafe = queryItemCountAPI
ns.QueryItemInfoSafe = queryItemInfoAPI

-----------------------------------------------------------------------------
-- Module Class Exports
-----------------------------------------------------------------------------
RecipeCatalogIndex.RebuildRecipeAndReagentIndexes = ns.RebuildRecipeAndReagentIndexes
RecipeCatalogIndex.QueryItemCountSafe = ns.QueryItemCountSafe
RecipeCatalogIndex.QueryItemInfoSafe = ns.QueryItemInfoSafe
RecipeCatalogIndex.ResolveRecipeProfessionKey = ns.ResolveRecipeProfessionKey
RecipeCatalogIndex.GetLocalizedRecipeDescription = ns.GetLocalizedRecipeDescription
RecipeCatalogIndex.ResolveRecipeDisplayIcon = ns.ResolveRecipeDisplayIcon
RecipeCatalogIndex.GetLocalizedRecipeName = ns.GetLocalizedRecipeName
RecipeCatalogIndex.GetLocalizedRecipeSourceText = ns.GetLocalizedRecipeSourceText
RecipeCatalogIndex.FormatRecipeDifficultyThresholds = ns.FormatRecipeDifficultyThresholds
