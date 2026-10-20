--===========================================================================
-- EzWoW - Profession Recipes
-- UI/RecipeBrowser.lua : Split-Pane Profession Recipe Browser, Side Tabs & Reagent Tooltips
--===========================================================================
local ADDON, ns = ...

local RecipeBrowserWindow = ns.RecipeBrowserWindow or {}
ns.RecipeBrowserWindow = RecipeBrowserWindow
local payloadData, localizedItemNameTable = ns.Data, ns.ItemNames
local Theme = ns.Style
local L = ns.L
local DONATE_URL = ns.DONATE_URL
local PROFESSIONS = ns.PROFESSIONS
local PROF_BY_ID = ns.PROF_BY_ID
local resolveProfName = ns.GetLocalizedProfessionName
local resolveCatName = ns.GetLocalizedCategoryName
local containsFlag = ns.HasBitwiseRecipeFlag
local constructRecipeLookupIndex = ns.RebuildRecipeAndReagentIndexes
local resolveRecipeName = ns.GetLocalizedRecipeName
local resolveRecipeDesc = ns.GetLocalizedRecipeDescription
local resolvePlayerFaction = ns.PlayerFaction
local hasOtherFaction = ns.IsOtherFaction
local resolveRecipeSrc = ns.GetLocalizedRecipeSourceText
local bootstrapDB = ns.InitDB
local resolveItemName = ns.ItemName
local resolveItemIcon = ns.ItemIcon
local resolveQualityHex = ns.QualityHex
local resolveRecipeIcon = ns.ResolveRecipeDisplayIcon
local resolveSkillText = ns.FormatRecipeDifficultyThresholds
local scanLearnedProfessionIDs = ns.GetLearnedSkillLines
local queryItemCountAPI = ns.QueryItemCountSafe
local queryItemInfoAPI = ns.QueryItemInfoSafe
local R_SPELL, R_ITEM, R_CAT, R_ORANGE, R_YELLOW, R_GREEN, R_GREY = ns.R_SPELL, ns.R_ITEM, ns.R_CAT, ns.R_ORANGE, ns.R_YELLOW, ns.R_GREEN, ns.R_GREY
local R_FLAGS, R_QTY, R_ICON, R_NAME_KO, R_NAME_EN, R_REAG = ns.R_FLAGS, ns.R_QTY, ns.R_ICON, ns.R_NAME_KO, ns.R_NAME_EN, ns.R_REAG
local R_DESC_KO, R_DESC_EN, R_SRC_KO, R_SRC_EN = ns.R_DESC_KO, ns.R_DESC_EN, ns.R_SRC_KO, ns.R_SRC_EN
local F_NEW, F_TRAINER, F_ALLIANCE, F_HORDE = ns.F_NEW, ns.F_TRAINER, ns.F_ALLIANCE, ns.F_HORDE

local switcher

-----------------------------------------------------------------------------
-- Build Backdrop Frame
-----------------------------------------------------------------------------
local panelFrameEntry
local ROW_H, NUM_ROWS = 18, 40 
local currentProf
local selectedRecipe
local listEntries = {}
local scrollOffset = 0

function RecipeBrowserWindow.buildBackdropFrame(parent, name)
    local isCallOk, windowFrame = pcall(CreateFrame, "Frame", name, parent, "PortraitFrameTemplate")
    if isCallOk and windowFrame then
        if not windowFrame.CloseButton then
            local close = CreateFrame("Button", nil, windowFrame, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", -4, -4)
            windowFrame.CloseButton = close
        end
        return windowFrame, true
    end
    windowFrame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    ns.UIKit:ApplyBackdrop(windowFrame)
    windowFrame:SetBackdropColor(unpack(Theme.bg))
    windowFrame:SetBackdropBorderColor(unpack(Theme.border))
    local close = CreateFrame("Button", nil, windowFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    windowFrame.CloseButton = close
    return windowFrame, false
end

function RecipeBrowserWindow.assignPanelTitle(text)
    if panelFrameEntry.SetTitle then
        panelFrameEntry:SetTitle(text)
    elseif panelFrameEntry.TitleContainer and panelFrameEntry.TitleContainer.TitleText then
        panelFrameEntry.TitleContainer.TitleText:SetText(text)
    elseif panelFrameEntry.TitleText then
        panelFrameEntry.TitleText:SetText(text)
    else
        panelFrameEntry.fallbackTitle:SetText(text)
    end
end

function RecipeBrowserWindow.assignPanelPortrait(tex)
    if panelFrameEntry.SetPortraitToAsset then
        panelFrameEntry:SetPortraitToAsset(tex)
    elseif panelFrameEntry.PortraitContainer and panelFrameEntry.PortraitContainer.portrait then
        SetPortraitToTexture(panelFrameEntry.PortraitContainer.portrait, tex)
    elseif panelFrameEntry.portrait then
        SetPortraitToTexture(panelFrameEntry.portrait, tex)
    end
end

local learnedMode = false
local learnedSpells = {}
local skillEntry = 0

function RecipeBrowserWindow.matchProfName(name)
    if not name then return nil end
    for _, anchorTarget in ipairs(PROFESSIONS) do
        for _, entryKey in ipairs({ "ko", "en", "de", "fr", "es", "ru", "zhCN", "zhTW" }) do
            if name == anchorTarget[entryKey] then return anchorTarget.id end
        end
    end
end

function RecipeBrowserWindow.resolveCurrentTradeSkillLine()
    if C_TradeSkillUI then
        if C_TradeSkillUI.GetBaseProfessionInfo then
            local isCallOk, apiInfo = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
            if isCallOk and type(apiInfo) == "table" then
                local entityID = (apiInfo.professionID and payloadData[apiInfo.professionID] and apiInfo.professionID)
                    or (apiInfo.parentProfessionID and payloadData[apiInfo.parentProfessionID] and apiInfo.parentProfessionID)
                    or RecipeBrowserWindow.matchProfName(apiInfo.professionName) or RecipeBrowserWindow.matchProfName(apiInfo.parentProfessionName)
                if entityID then return entityID, apiInfo.skillLevel end
            end
        end
        if C_TradeSkillUI.GetTradeSkillLine then
            local isCallOk, entityID, name, rank = pcall(C_TradeSkillUI.GetTradeSkillLine)
            if isCallOk then
                entityID = (entityID and payloadData[entityID] and entityID) or RecipeBrowserWindow.matchProfName(name)
                if entityID then return entityID, rank end
            end
        end
    end
    if GetTradeSkillLine then
        local name, rank = GetTradeSkillLine()
        local entityID = RecipeBrowserWindow.matchProfName(name)
        if entityID then return entityID, rank end
    end
end

function RecipeBrowserWindow.syncLearned()
    wipe(learnedSpells)
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local isCallOk, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
        if isCallOk and type(ids) == "table" then
            for _, entityID in ipairs(ids) do
                local ok2, apiInfo = pcall(C_TradeSkillUI.GetRecipeInfo, entityID)
                if ok2 and apiInfo and apiInfo.learned then learnedSpells[entityID] = true end
            end
        end
    end
end

function RecipeBrowserWindow.hasLearned(r)
    if learnedSpells[r[R_SPELL]] then return true end
    if IsPlayerSpell then
        local isCallOk, known = pcall(IsPlayerSpell, r[R_SPELL])
        if isCallOk and known then return true end
    end
    return false
end

function RecipeBrowserWindow.resolveDifficultyColor(r)
    if skillEntry < r[R_ORANGE] then return "|cffff2020" end
    if r[R_YELLOW] == 0 or skillEntry < r[R_YELLOW] then return "|cffff8040" end
    if skillEntry < r[R_GREEN] then return "|cffffff00" end
    if skillEntry < r[R_GREY] then return "|cff40bf40" end
    return "|cff808080"
end

function RecipeBrowserWindow.getRecipeSearchBlob(r)
    local blob = r._searchBlob
    if not blob then
        local parts = {
            (r[R_NAME_KO] or ""):lower(),
            (r[R_NAME_EN] or ""):lower(),
            (r[R_SRC_KO] or ""):lower(),
            (r[R_SRC_EN] or ""):lower(),
            tostring(r[R_SPELL] or ""),
            tostring(r[R_ITEM] or ""),
        }
        for _, rgVal in ipairs(r[R_REAG]) do
            parts[#parts + 1] = tostring(rgVal[1])
            local names = localizedItemNameTable[rgVal[1]]
            if names then
                if names[1] then parts[#parts + 1] = names[1]:lower() end
                if names[2] then parts[#parts + 1] = names[2]:lower() end
            end
        end
        blob = table.concat(parts, "\n")
        r._searchBlob = blob
    end
    return blob
end

function RecipeBrowserWindow.doesRecipeMatchFilter(r, query)
    if ns.DB.onlyNew and not containsFlag(r, F_NEW) then return false end
    if ns.DB.cap and r[R_ORANGE] > 225 then return false end
    if ns.DB.hideOtherFaction and hasOtherFaction(r) then return false end
    if learnedMode and ns.DB.hideLearned and RecipeBrowserWindow.hasLearned(r) then return false end
    if learnedMode and ns.DB.canLearnOnly and (RecipeBrowserWindow.hasLearned(r) or r[R_ORANGE] > skillEntry) then return false end
    if query and query ~= "" then
        local priorityQueue = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
        if priorityQueue == "" then return true end
        if RecipeBrowserWindow.getRecipeSearchBlob(r):find(priorityQueue, 1, true) then return true end
        for _, rgVal in ipairs(r[R_REAG]) do
            if resolveItemName(rgVal[1]):lower():find(priorityQueue, 1, true) then return true end
        end
        return false
    end
    return true
end

function RecipeBrowserWindow.sortRecipeEntryList(list)
    table.sort(list, function(a, b)
        if a[R_ORANGE] ~= b[R_ORANGE] then return a[R_ORANGE] > b[R_ORANGE] end
        return resolveRecipeName(a) < resolveRecipeName(b)
    end)
end

function RecipeBrowserWindow.rebuildFilteredRecipeEntries()
    wipe(listEntries)
    panelFrameEntry.matchCount, panelFrameEntry.totalCount = 0, 0
    local payloadData2 = currentProf and payloadData[currentProf]
    if not payloadData2 then return end
    local query = panelFrameEntry.search:GetText():gsub("^%s+", ""):gsub("%s+$", "")
    panelFrameEntry.totalCount = #payloadData2.recipes

    if ns.DB.searchAll and query ~= "" and not learnedMode then
        local grandTotal = 0
        for _, anchorTarget in ipairs(PROFESSIONS) do
            local pdVal = payloadData[anchorTarget.id]
            if pdVal then
                grandTotal = grandTotal + #pdVal.recipes
                local list = {}
                for _, r in ipairs(pdVal.recipes) do
                    if RecipeBrowserWindow.doesRecipeMatchFilter(r, query) then list[#list + 1] = r end
                end
                if #list > 0 then
                    RecipeBrowserWindow.sortRecipeEntryList(list)
                    listEntries[#listEntries + 1] = { header = true, cat = "p" .. anchorTarget.id, name = resolveProfName(anchorTarget), n = #list, icon = anchorTarget.icon }
                    for _, r in ipairs(list) do listEntries[#listEntries + 1] = { recipe = r } end
                    panelFrameEntry.matchCount = panelFrameEntry.matchCount + #list
                end
            end
        end
        panelFrameEntry.totalCount = grandTotal
        return
    end

    local byCat = {}
    for _, r in ipairs(payloadData2.recipes) do
        if RecipeBrowserWindow.doesRecipeMatchFilter(r, query) then
            local themeColor = r[R_CAT]
            byCat[themeColor] = byCat[themeColor] or {}
            table.insert(byCat[themeColor], r)
        end
    end
    local order, visitedMap = {}, {}
    for _, themeColor in ipairs(payloadData2.cats) do order[#order + 1] = { themeColor[1], resolveCatName(themeColor[2], themeColor[3]) }; visitedMap[themeColor[1]] = true end
    for themeColor in pairs(byCat) do if not visitedMap[themeColor] then order[#order + 1] = { themeColor, L.otherCat } end end
    local searching = query and query ~= ""
    local collapsed = ns.DB.collapsed[currentProf] or {}
    for _, themeColor in ipairs(order) do
        local list = byCat[themeColor[1]]
        if list then
            RecipeBrowserWindow.sortRecipeEntryList(list)
            panelFrameEntry.matchCount = panelFrameEntry.matchCount + #list
            local hasCollapsed = collapsed[themeColor[1]] and not searching
            listEntries[#listEntries + 1] = { header = true, cat = themeColor[1], name = themeColor[2], n = #list, collapsed = hasCollapsed }
            if not hasCollapsed then
                for _, r in ipairs(list) do listEntries[#listEntries + 1] = { recipe = r } end
            end
        end
    end
end

local refreshDetail

function RecipeBrowserWindow.renderVisibleRecipeRows()
    local visible = panelFrameEntry.visibleRows or 26
    local maxOffset = math.max(0, #listEntries - visible)
    if scrollOffset > maxOffset then scrollOffset = maxOffset end
    if scrollOffset < 0 then scrollOffset = 0 end
    panelFrameEntry.slider:SetMinMaxValues(0, maxOffset)
    panelFrameEntry.slider:SetValue(scrollOffset)
    panelFrameEntry.slider:SetShown(maxOffset > 0)
    for index = 1, NUM_ROWS do
        local rowWidget = panelFrameEntry.rows[index]
        local recordEntry = (index <= visible) and listEntries[index + scrollOffset] or nil
        rowWidget.entry = recordEntry
        if not recordEntry then
            rowWidget:Hide()
        else
            rowWidget:Show()
            if recordEntry.header then
                rowWidget.text:SetPoint("LEFT", 22, 0)
                rowWidget.text:SetText("|cffeba86a" .. recordEntry.name .. "|r")
                rowWidget.right:SetText("|cffa7b9c5" .. recordEntry.n .. "|r")
                rowWidget.hl:SetShown(false)
                rowWidget.headerBg:Show()
                if recordEntry.icon then
                    rowWidget.toggle:SetTexture(recordEntry.icon)
                    rowWidget.toggle:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                else
                    rowWidget.toggle:SetTexture(recordEntry.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
                    rowWidget.toggle:SetTexCoord(0, 1, 0, 1)
                end
                rowWidget.toggle:Show()
            else
                local r = recordEntry.recipe
                rowWidget.headerBg:Hide()
                rowWidget.toggle:Hide()
                rowWidget.text:SetPoint("LEFT", 24, 0)
                local name = resolveRecipeName(r)
                if containsFlag(r, F_NEW) then name = name .. " |cff4bc8e8*|r" end
                if learnedMode then
                    if RecipeBrowserWindow.hasLearned(r) then name = "|cff63727b" .. name .. " " .. L.learnedMark .. "|r" end
                    rowWidget.right:SetText(RecipeBrowserWindow.resolveDifficultyColor(r) .. r[R_ORANGE] .. "|r")
                else
                    rowWidget.right:SetText("|cffff8040" .. r[R_ORANGE] .. "|r")
                end
                rowWidget.text:SetText(name)
                rowWidget.hl:SetShown(selectedRecipe == r)
            end
        end
    end
    panelFrameEntry.empty:SetShown(#listEntries == 0)
    panelFrameEntry.info:SetText(L.results:format(panelFrameEntry.matchCount or 0, panelFrameEntry.totalCount or 0) .. "   |cffff8040■|r |cffffff00■|r |cff40bf40■|r |cff808080■|r   |cffa7b9c5" .. L.source .. "|r")
    if panelFrameEntry.UpdateFilterButton then panelFrameEntry.UpdateFilterButton() end
end

function RecipeBrowserWindow.refreshActiveView()
    RecipeBrowserWindow.rebuildFilteredRecipeEntries()
    RecipeBrowserWindow.renderVisibleRecipeRows()
    refreshDetail()
end

function RecipeBrowserWindow.tooltipLines(itemID)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local isCallOk, payloadData2 = pcall(C_TooltipInfo.GetItemByID, itemID)
    if not isCallOk or not payloadData2 or not payloadData2.lines then return nil end
    local outputList = {}
    for index = 2, #payloadData2.lines do
        local line = payloadData2.lines[index]
        local resolvedValue = line.leftText
        if resolvedValue and resolvedValue ~= "" then
            local themeColor = line.leftColor
            if themeColor and themeColor.GenerateHexColor then
                resolvedValue = "|c" .. themeColor:GenerateHexColor() .. resolvedValue .. "|r"
            end
            outputList[#outputList + 1] = resolvedValue
        end
    end
    return table.concat(outputList, "\n")
end

function refreshDetail()
    local dataEntry = panelFrameEntry.detail
    local r = selectedRecipe
    if not r then dataEntry:Hide() return end
    dataEntry:Show()
    dataEntry.icon.tex:SetTexture(resolveRecipeIcon(r))
    dataEntry.name:SetText(resolveQualityHex(r[R_ITEM]) .. resolveRecipeName(r) .. "|r")
    local sourceData = containsFlag(r, F_TRAINER) and L.trainer or L.book
    if learnedMode then
        if RecipeBrowserWindow.hasLearned(r) then
            sourceData = "|cff40bf40" .. L.alreadyLearned .. "|r"
        elseif skillEntry < r[R_ORANGE] then
            sourceData = sourceData .. "  |cffff2020(" .. L.needSkill:format(r[R_ORANGE]) .. ")|r"
        end
    end
    if containsFlag(r, F_NEW) then sourceData = sourceData .. "   |cff4bc8e8" .. L.newTag .. "|r" end
    if containsFlag(r, F_ALLIANCE) then sourceData = sourceData .. "   |cff4a8cff" .. L.allianceOnly .. "|r"
    elseif containsFlag(r, F_HORDE) then sourceData = sourceData .. "   |cffe04040" .. L.hordeOnly .. "|r" end
    constructRecipeLookupIndex()
    local relativePoint = PROF_BY_ID[ns.ResolveRecipeProfessionKey()[r]]
    if relativePoint and ns.ResolveRecipeProfessionKey()[r] ~= currentProf then sourceData = "|cffeba86a" .. resolveProfName(relativePoint) .. "|r · " .. sourceData end
    dataEntry.source:SetText(sourceData)

    local desc = resolveRecipeDesc(r)
    if (not desc or desc == "") and r[R_ITEM] > 0 then
        desc = RecipeBrowserWindow.tooltipLines(r[R_ITEM])
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(r[R_ITEM]) end
    end
    if not desc or desc == "" then desc = "|cffa7b9c5" .. L.hoverHint .. "|r" end
    dataEntry.desc:SetText(desc)

    dataEntry.skill:SetText(L.skill .. "  " .. resolveSkillText(r))

    local where = resolveRecipeSrc(r)
    dataEntry.where:SetText(where)
    local whVal = (where ~= "") and (dataEntry.where:GetStringHeight() or 0) or 0
    dataEntry.desc:SetHeight(math.max(50, (dataEntry.descBase or 170) - whVal))
    if r[R_QTY] and r[R_QTY] > 1 then
        dataEntry.qty:SetText(L.makes:format(r[R_QTY]))
    else
        dataEntry.qty:SetText("")
    end

    for index, actionBtn in ipairs(dataEntry.reagents) do
        local rgVal = r[R_REAG][index]
        if rgVal then
            local entityID, need = rgVal[1], rgVal[2]
            actionBtn.itemID = entityID
            actionBtn.tex:SetTexture(resolveItemIcon(entityID, nil))
            local have = queryItemCountAPI(entityID, true) or 0
            local columnIndex = (have >= need) and "|cffedf4f7" or "|cff63727b"
            actionBtn.text:SetText(columnIndex .. have .. "/" .. need .. "|r  " .. resolveQualityHex(entityID) .. resolveItemName(entityID) .. "|r")
            actionBtn:Show()
        else
            actionBtn:Hide()
        end
    end
end

function RecipeBrowserWindow.presentItemTooltip(owner, itemID, spellID)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if itemID and itemID > 0 then
        GameTooltip:SetItemByID(itemID)
    elseif spellID then
        GameTooltip:SetSpellByID(spellID)
    end
    GameTooltip:Show()
end

function RecipeBrowserWindow.linkRecipe(r, itemID)
    local link
    if itemID and itemID > 0 then
        link = select(2, queryItemInfoAPI(itemID))
    elseif r then
        link = (C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(r[R_SPELL])) or (GetSpellLink and GetSpellLink(r[R_SPELL]))
    end
    if link then ChatEdit_InsertLink(link) end
end

function RecipeBrowserWindow.buildCheck(parent, label, key)
    local checkWidget = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkWidget:SetSize(22, 22)
    local labelRegion = checkWidget.Text or checkWidget.text
    if not labelRegion then
        labelRegion = checkWidget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        labelRegion:SetPoint("LEFT", checkWidget, "RIGHT", 0, 1)
    end
    labelRegion:SetFontObject("GameFontHighlightSmall")
    labelRegion:SetTextColor(unpack(Theme.text))
    labelRegion:SetText(L[label])
    checkWidget.label, checkWidget.labelKey, checkWidget.key = labelRegion, label, key
    checkWidget:SetScript("OnShow", function(self) self:SetChecked(ns.DB[key]) end)
    checkWidget:SetScript("OnClick", function(self)
        ns.DB[key] = self:GetChecked() and true or false
        scrollOffset = 0
        RecipeBrowserWindow.refreshActiveView()
    end)
    return checkWidget
end

function RecipeBrowserWindow.createRecipeFlatButton(parent, w, h, isAccent, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    ns.UIKit:ApplyBackdrop(b, 1, 1)
    local function applyNormalButtonLook()
        if isAccent then
            b:SetBackdropColor(0.24, 0.18, 0.12, 0.96)
            b:SetBackdropBorderColor(unpack(Theme.accent))
        else
            b:SetBackdropColor(unpack(Theme.bgSub))
            b:SetBackdropBorderColor(unpack(Theme.border))
        end
    end
    applyNormalButtonLook()
    b.normalStyle = applyNormalButtonLook
    local label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER")
    label:SetTextColor(unpack(isAccent and Theme.accent or Theme.text))
    b.label = label
    function b:SetText(txt) label:SetText(txt or "") end
    function b:GetText() return label:GetText() end
    b:SetScript("OnEnter", function()
        b:SetBackdropColor(0.20, 0.24, 0.29, 1)
        b:SetBackdropBorderColor(unpack(Theme.accent))
    end)
    b:SetScript("OnLeave", applyNormalButtonLook)
    b:SetScript("OnMouseDown", function() label:SetPoint("CENTER", 1, -1) end)
    b:SetScript("OnMouseUp", function() label:SetPoint("CENTER", 0, 0) end)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function RecipeBrowserWindow.launchInMapFinder(query)
    if not query or query == "" then return end
    if not (SlashCmdList and SlashCmdList.EZWOWMAPFINDER) then
        local loader = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
        if loader then
            pcall(loader, "EzWoW-MapFinder")
            pcall(loader, "EzWoW_MapFinder")
        end
    end
    if WorldMapFrame and not WorldMapFrame:IsShown() then
        if ToggleWorldMap then
            pcall(ToggleWorldMap)
        elseif ShowUIPanel then
            pcall(ShowUIPanel, WorldMapFrame)
        else
            WorldMapFrame:Show()
        end
    end
    if SlashCmdList and SlashCmdList.EZWOWMAPFINDER then
        SlashCmdList.EZWOWMAPFINDER(query)
    end
end

function RecipeBrowserWindow.extractRecipeMapQuery(r)
    if not r then return nil end
    local sourceData = resolveRecipeSrc(r) or ""
    
    local qName = sourceData:match("퀘스트%s*「(.-)」") or sourceData:match("quest%s*“([^”]+)”") or sourceData:match('quest%s*"([^"]+)"')
    if qName and qName ~= "" then
        return "Q " .. qName
    end
    
    local npcEn = sourceData:match("sold by%s+([^/\n%(]+)%s*%(")
    if npcEn then
        npcEn = npcEn:gsub("^%s+", ""):gsub("%s+$", "")
        if npcEn ~= "" then return "N " .. npcEn end
    end
    local npcKo = sourceData:match("·%s*([^·/\n%(]+)%s*%(")
    if npcKo then
        npcKo = npcKo:gsub("^%s+", ""):gsub("%s+$", "")
        if npcKo ~= "" then return "N " .. npcKo end
    end
    
    if containsFlag(r, F_TRAINER) then
        constructRecipeLookupIndex()
        local anchorTarget = PROF_BY_ID[(ns.ResolveRecipeProfessionKey() and ns.ResolveRecipeProfessionKey()[r]) or currentProf]
        if anchorTarget then
            if ns.IS_KO and anchorTarget.ko then
                return "N " .. anchorTarget.ko:gsub("%s+", "") .. " 전문가"
            elseif anchorTarget.en then
                return "N " .. anchorTarget.en .. " Trainer"
            end
        end
    end
    
    return resolveRecipeName(r)
end

function RecipeBrowserWindow.buildProfessionBrowserWindow()
    local windowFrame, templated = RecipeBrowserWindow.buildBackdropFrame(UIParent, "EzWoWProfessionRecipesFrame")
    panelFrameEntry = windowFrame
    windowFrame:SetSize(860, 600)
    windowFrame:SetFrameStrata("HIGH")
    windowFrame:SetToplevel(true)
    windowFrame:EnableMouse(true)
    windowFrame:Hide()
    if not templated then
        windowFrame.fallbackTitle = windowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        windowFrame.fallbackTitle:SetPoint("TOP", 0, -14)
    end
    windowFrame.CloseButton:SetScript("OnClick", function()
        windowFrame:Hide()
        if windowFrame.attached and ProfessionsFrame and ProfessionsFrame:IsShown() then
            HideUIPanel(ProfessionsFrame)
        end
    end)
    windowFrame:SetScript("OnHide", function()
        ns.UpdateTabChecks()
    end)

    windowFrame:SetMovable(true)
    windowFrame:RegisterForDrag("LeftButton")
    windowFrame:SetScript("OnDragStart", function(self)
        if self.attached and ProfessionsFrame then
            
            if not ProfessionsFrame:IsMovable() then ProfessionsFrame:SetMovable(true) end
            ProfessionsFrame:StartMoving()
            self.movingParent = true
        else
            self:StartMoving()
        end
    end)
    windowFrame:SetScript("OnDragStop", function(self)
        if self.movingParent then
            self.movingParent = nil
            if ProfessionsFrame then ProfessionsFrame:StopMovingOrSizing() end
            return
        end
        self:StopMovingOrSizing()
        if not self.attached then
            local anchorTarget, _, relativePoint, coordX, coordY = self:GetPoint()
            ns.DB.standalonePos = { anchorTarget, relativePoint, coordX, coordY }
        end
    end)

    local apiInfo = windowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    apiInfo:SetPoint("BOTTOMLEFT", windowFrame, "BOTTOMLEFT", 22, 9)
    apiInfo:SetTextColor(unpack(Theme.text))
    windowFrame.info = apiInfo

    local left = CreateFrame("Frame", nil, windowFrame, "BackdropTemplate")
    left:SetPoint("TOPLEFT", 12, -62)
    left:SetPoint("BOTTOMLEFT", 12, 28)
    left:SetWidth(300)
    windowFrame.left = left
    ns.UIKit:ApplyBackdrop(left)
    left:SetBackdropColor(unpack(Theme.bgSub))
    left:SetBackdropBorderColor(unpack(Theme.border))

    local search = CreateFrame("EditBox", nil, windowFrame, "BackdropTemplate")
    search:SetPoint("BOTTOMLEFT", left, "TOPLEFT", 60, 4)
    search:SetPoint("RIGHT", left, "RIGHT", -90, 0)
    search:SetHeight(22)
    search:SetFontObject(ChatFontNormal)
    search:SetTextInsets(6, 6, 0, 0)
    search:SetAutoFocus(false)
    ns.UIKit:ApplyBackdrop(search, 1, 1)
    search:SetBackdropColor(0.047, 0.067, 0.086, 0.96)
    search:SetBackdropBorderColor(unpack(Theme.border))
    local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", search, "LEFT", 6, 0)
    hint:SetText(L.search)
    search.Instructions = hint
    search:SetScript("OnEditFocusGained", function(self)
        self.Instructions:Hide()
        self:SetBackdropBorderColor(unpack(Theme.accent))
    end)
    search:SetScript("OnEditFocusLost", function(self)
        self.Instructions:SetShown((self:GetText() or "") == "")
        self:SetBackdropBorderColor(unpack(Theme.border))
    end)
    search:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then self:SetText("") else self:ClearFocus() end
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        self.Instructions:SetShown((self:GetText() or "") == "" and not self:HasFocus())
        scrollOffset = 0
        RecipeBrowserWindow.refreshActiveView()
    end)
    windowFrame.search = search

    local fbtn = RecipeBrowserWindow.createRecipeFlatButton(windowFrame, 84, 22, false)
    fbtn:SetPoint("LEFT", search, "RIGHT", 6, 0)
    windowFrame.filterButton = fbtn

    local menu = CreateFrame("Frame", nil, windowFrame, "BackdropTemplate")
    ns.UIKit:ApplyBackdrop(menu)
    menu:SetBackdropColor(0.071, 0.094, 0.122, 0.96)
    menu:SetBackdropBorderColor(unpack(Theme.border))
    menu:SetPoint("TOPLEFT", fbtn, "BOTTOMLEFT", 0, -2)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(windowFrame:GetFrameLevel() + 30)
    menu:EnableMouse(true)
    menu:Hide()
    windowFrame.filterMenu = menu

    local cbNew = RecipeBrowserWindow.buildCheck(menu, "onlyNew", "onlyNew")
    local cbCap = RecipeBrowserWindow.buildCheck(menu, "cap", "cap")
    local cbAll = RecipeBrowserWindow.buildCheck(menu, "searchAll", "searchAll")
    local cbHide = RecipeBrowserWindow.buildCheck(menu, "hideLearned", "hideLearned")
    local cbCan = RecipeBrowserWindow.buildCheck(menu, "canLearnOnly", "canLearnOnly")
    local cbFaction = RecipeBrowserWindow.buildCheck(menu, "hideOtherFaction", "hideOtherFaction")
    windowFrame.cbHide, windowFrame.cbCan, windowFrame.cbAll, windowFrame.cbFaction = cbHide, cbCan, cbAll, cbFaction
    windowFrame.checks = { cbNew, cbCap, cbHide, cbCan, cbAll, cbFaction }

    function windowFrame.LayoutFilterMenu()
        local itemEntries = { cbNew, cbCap, cbFaction }
        if learnedMode then
            itemEntries[#itemEntries + 1] = cbHide
            itemEntries[#itemEntries + 1] = cbCan
            cbAll:Hide()
        else
            itemEntries[#itemEntries + 1] = cbAll
            cbHide:Hide(); cbCan:Hide()
        end
        local w = 120
        for index, checkWidget in ipairs(itemEntries) do
            checkWidget:ClearAllPoints()
            checkWidget:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -8 - (index - 1) * 24)
            checkWidget:Show()
            checkWidget:SetChecked(ns.DB[checkWidget.key])
            local twVal = checkWidget.label:GetStringWidth() or 100
            if twVal + 40 > w then w = twVal + 40 end
        end
        menu:SetSize(w, 16 + #itemEntries * 24)
    end

    function windowFrame.UpdateFilterButton()
        local nodeEntry = 0
        if ns.DB.onlyNew then nodeEntry = nodeEntry + 1 end
        if ns.DB.cap then nodeEntry = nodeEntry + 1 end
        if ns.DB.hideOtherFaction then nodeEntry = nodeEntry + 1 end
        if learnedMode then
            if ns.DB.hideLearned then nodeEntry = nodeEntry + 1 end
            if ns.DB.canLearnOnly then nodeEntry = nodeEntry + 1 end
        elseif ns.DB.searchAll then
            nodeEntry = nodeEntry + 1
        end
        fbtn:SetText(nodeEntry > 0 and (L.filter .. " (" .. nodeEntry .. ")") or L.filter)
    end

    fbtn:SetScript("OnClick", function()
        if menu:IsShown() then menu:Hide() else windowFrame.LayoutFilterMenu(); menu:Show() end
    end)
    windowFrame:HookScript("OnHide", function() menu:Hide() end)

    windowFrame.rows = {}
    for index = 1, NUM_ROWS do
        local rowWidget = CreateFrame("Button", nil, left)
        rowWidget:SetHeight(ROW_H)
        rowWidget:SetPoint("TOPLEFT", 6, -6 - (index - 1) * ROW_H)
        rowWidget:SetPoint("RIGHT", left, "RIGHT", -22, 0)
        rowWidget.headerBg = rowWidget:CreateTexture(nil, "BACKGROUND")
        rowWidget.headerBg:SetAllPoints()
        rowWidget.headerBg:SetColorTexture(0.922, 0.659, 0.416, 0.16)
        rowWidget.toggle = rowWidget:CreateTexture(nil, "ARTWORK")
        rowWidget.toggle:SetSize(14, 14)
        rowWidget.toggle:SetPoint("LEFT", 4, 0)
        rowWidget.toggle:Hide()
        rowWidget.hl = rowWidget:CreateTexture(nil, "BACKGROUND")
        rowWidget.hl:SetAllPoints()
        rowWidget.hl:SetColorTexture(0.922, 0.659, 0.416, 0.24)
        rowWidget:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        rowWidget.text = rowWidget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rowWidget.text:SetPoint("LEFT", 18, 0)
        rowWidget.text:SetPoint("RIGHT", rowWidget, "RIGHT", -34, 0)
        rowWidget.text:SetJustifyH("LEFT")
        rowWidget.text:SetWordWrap(false)
        rowWidget.right = rowWidget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rowWidget.right:SetPoint("RIGHT", -4, 0)
        rowWidget:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        rowWidget:SetScript("OnClick", function(self, button)
            local recordEntry = self.entry
            if not recordEntry then return end
            if recordEntry.header then
                if recordEntry.icon then return end 
                ns.DB.collapsed[currentProf] = ns.DB.collapsed[currentProf] or {}
                local themeColor = ns.DB.collapsed[currentProf]
                themeColor[recordEntry.cat] = not themeColor[recordEntry.cat] or nil
                RecipeBrowserWindow.refreshActiveView()
            else
                if button == "RightButton" then
                    RecipeBrowserWindow.launchInMapFinder(RecipeBrowserWindow.extractRecipeMapQuery(recordEntry.recipe))
                    return
                end
                if IsModifiedClick("CHATLINK") then RecipeBrowserWindow.linkRecipe(recordEntry.recipe, recordEntry.recipe[R_ITEM]) return end
                selectedRecipe = recordEntry.recipe
                RecipeBrowserWindow.renderVisibleRecipeRows()
                refreshDetail()
            end
        end)
        rowWidget:SetScript("OnEnter", function(self)
            local recordEntry = self.entry
            if recordEntry and recordEntry.recipe then
                RecipeBrowserWindow.presentItemTooltip(self, recordEntry.recipe[R_ITEM], recordEntry.recipe[R_SPELL])
                if SlashCmdList and SlashCmdList.EZWOWMAPFINDER and L.rightClickFindMap then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L.rightClickFindMap, 0.294, 0.784, 0.910)
                    GameTooltip:Show()
                end
            end
        end)
        rowWidget:SetScript("OnLeave", GameTooltip_Hide)
        windowFrame.rows[index] = rowWidget
    end

    local sliderWidget = CreateFrame("Slider", nil, left, "BackdropTemplate")
    sliderWidget:SetPoint("TOPRIGHT", -5, -8)
    sliderWidget:SetPoint("BOTTOMRIGHT", -5, 8)
    sliderWidget:SetWidth(12)
    sliderWidget:SetOrientation("VERTICAL")
    sliderWidget:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    sliderWidget:SetBackdropColor(0.071, 0.094, 0.122, 0.7)
    sliderWidget:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    sliderWidget:SetValueStep(1)
    sliderWidget:SetObeyStepOnDrag(true)
    sliderWidget:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        if v ~= scrollOffset then scrollOffset = v; RecipeBrowserWindow.renderVisibleRecipeRows() end
    end)
    windowFrame.slider = sliderWidget
    left:EnableMouseWheel(true)
    left:SetScript("OnMouseWheel", function(_, delta)
        scrollOffset = scrollOffset - delta * 3
        RecipeBrowserWindow.renderVisibleRecipeRows()
    end)

    windowFrame.empty = left:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    windowFrame.empty:SetPoint("CENTER")
    windowFrame.empty:SetText(L.noRecipes)

    local dataEntry = CreateFrame("Frame", nil, windowFrame, "BackdropTemplate")
    dataEntry:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    dataEntry:SetPoint("BOTTOMRIGHT", -12, 28)
    ns.UIKit:ApplyBackdrop(dataEntry)
    dataEntry:SetBackdropColor(unpack(Theme.bgSub))
    dataEntry:SetBackdropBorderColor(unpack(Theme.border))
    windowFrame.detail = dataEntry

    local iconTex = CreateFrame("Button", nil, dataEntry)
    iconTex:SetSize(48, 48)
    iconTex:SetPoint("TOPLEFT", 16, -16)
    iconTex.tex = iconTex:CreateTexture(nil, "ARTWORK")
    iconTex.tex:SetAllPoints()
    iconTex:SetScript("OnEnter", function(self)
        local r = selectedRecipe
        if r then RecipeBrowserWindow.presentItemTooltip(self, r[R_ITEM], r[R_SPELL]) end
    end)
    iconTex:SetScript("OnLeave", GameTooltip_Hide)
    iconTex:SetScript("OnClick", function()
        local r = selectedRecipe
        if r and IsModifiedClick("CHATLINK") then RecipeBrowserWindow.linkRecipe(r, r[R_ITEM]) end
    end)
    dataEntry.icon = iconTex

    local mapBtn = RecipeBrowserWindow.createRecipeFlatButton(dataEntry, 102, 22, false, function()
        if selectedRecipe then
            RecipeBrowserWindow.launchInMapFinder(RecipeBrowserWindow.extractRecipeMapQuery(selectedRecipe))
        end
    end)
    mapBtn:SetPoint("TOPRIGHT", dataEntry, "TOPRIGHT", -14, -14)
    mapBtn:SetText(L.findOnMap)
    mapBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.findOnMap, unpack(Theme.accent))
        if L.findOnMapTip then
            GameTooltip:AddLine(L.findOnMapTip, 0.929, 0.957, 0.969, true)
        end
        GameTooltip:Show()
    end)
    mapBtn:HookScript("OnLeave", GameTooltip_Hide)
    dataEntry.mapBtn = mapBtn

    dataEntry.name = dataEntry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dataEntry.name:SetPoint("TOPLEFT", iconTex, "TOPRIGHT", 12, -4)
    dataEntry.name:SetPoint("RIGHT", mapBtn, "LEFT", -8, 0)
    dataEntry.name:SetJustifyH("LEFT")

    dataEntry.source = dataEntry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dataEntry.source:SetPoint("TOPLEFT", dataEntry.name, "BOTTOMLEFT", 0, -6)
    dataEntry.source:SetPoint("RIGHT", dataEntry, "RIGHT", -16, 0)
    dataEntry.source:SetJustifyH("LEFT")

    dataEntry.skill = dataEntry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dataEntry.skill:SetPoint("TOPLEFT", iconTex, "BOTTOMLEFT", 0, -12)

    dataEntry.qty = dataEntry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dataEntry.qty:SetPoint("LEFT", dataEntry.skill, "RIGHT", 24, 0)

    dataEntry.desc = dataEntry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dataEntry.where = dataEntry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dataEntry.where:SetPoint("TOPLEFT", dataEntry.skill, "BOTTOMLEFT", 0, -8)
    dataEntry.where:SetPoint("RIGHT", dataEntry, "RIGHT", -16, 0)
    dataEntry.where:SetJustifyH("LEFT")
    dataEntry.where:SetSpacing(2)

    dataEntry.desc:SetPoint("TOPLEFT", dataEntry.where, "BOTTOMLEFT", 0, -10)
    dataEntry.desc:SetPoint("RIGHT", dataEntry, "RIGHT", -16, 0)
    dataEntry.desc:SetJustifyH("LEFT")
    dataEntry.desc:SetJustifyV("TOP")
    dataEntry.desc:SetHeight(170)
    dataEntry.desc:SetSpacing(2)

    local rlVal = dataEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rlVal:SetPoint("TOPLEFT", dataEntry.desc, "BOTTOMLEFT", 0, -10)
    rlVal:SetText(L.reagents)
    windowFrame.reagentLabel = rlVal

    dataEntry.reagents = {}
    for index = 1, 8 do
        local b = CreateFrame("Button", nil, dataEntry)
        b:SetSize(230, 36)
        local columnIndex, rowi = (index - 1) % 2, math.floor((index - 1) / 2)
        b:SetPoint("TOPLEFT", rlVal, "BOTTOMLEFT", columnIndex * 245, -6 - rowi * 40)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetSize(34, 34)
        b.tex:SetPoint("LEFT")
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("LEFT", b.tex, "RIGHT", 6, 0)
        b.text:SetPoint("RIGHT", b, "RIGHT", 0, 0)
        b.text:SetJustifyH("LEFT")
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnEnter", function(self)
            RecipeBrowserWindow.presentItemTooltip(self, self.itemID)
            if SlashCmdList and SlashCmdList.EZWOWMAPFINDER and L.rightClickFindReagent then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L.rightClickFindReagent, 0.294, 0.784, 0.910)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        b:SetScript("OnClick", function(self, button)
            if button == "RightButton" and self.itemID then
                RecipeBrowserWindow.launchInMapFinder(resolveItemName(self.itemID))
                return
            end
            if IsModifiedClick("CHATLINK") then RecipeBrowserWindow.linkRecipe(nil, self.itemID) end
        end)
        dataEntry.reagents[index] = b
    end

    local function relayoutBrowserPanels()
        local w = windowFrame:GetWidth() or 860
        if w <= 0 then return end
        local leftW = math.max(220, math.floor(w * 0.36))
        left:SetWidth(leftW)
        local dwVal = (dataEntry:GetWidth() or (w - leftW - 32)) - 32
        if dwVal <= 0 then dwVal = w - leftW - 64 end
        local twoCols = dwVal >= 380
        local bwVal = twoCols and math.floor((dwVal - 10) / 2) or dwVal
        for index, b in ipairs(dataEntry.reagents) do
            local columnIndex, rowi
            if twoCols then columnIndex, rowi = (index - 1) % 2, math.floor((index - 1) / 2) else columnIndex, rowi = 0, index - 1 end
            b:ClearAllPoints()
            b:SetSize(bwVal, twoCols and 36 or 30)
            b:SetPoint("TOPLEFT", rlVal, "BOTTOMLEFT", columnIndex * (bwVal + 10), -6 - rowi * (twoCols and 40 or 32))
        end
        dataEntry.descBase = twoCols and 170 or 120
        local lhVal = left:GetHeight() or 0
        if lhVal > ROW_H * 6 then 
            panelFrameEntry.visibleRows = math.max(5, math.min(NUM_ROWS, math.floor((lhVal - 12) / ROW_H)))
            if windowFrame:IsShown() then RecipeBrowserWindow.renderVisibleRecipeRows() end
        end
        if windowFrame:IsShown() and selectedRecipe then refreshDetail() end
    end
    windowFrame:HookScript("OnSizeChanged", relayoutBrowserPanels)
    dataEntry:HookScript("OnSizeChanged", relayoutBrowserPanels)
    left:HookScript("OnSizeChanged", relayoutBrowserPanels)
    windowFrame.Relayout = relayoutBrowserPanels
    if windowFrame.SetClipsChildren then windowFrame:SetClipsChildren(true) end
    if dataEntry.SetClipsChildren then dataEntry:SetClipsChildren(true) end
    if left.SetClipsChildren then left:SetClipsChildren(true) end

    windowFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    windowFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    windowFrame:SetScript("OnEvent", function(self, event, itemID, success)
        if event == "GET_ITEM_INFO_RECEIVED" and not success then return end
        if not self:IsShown() then return end
        if self.pendingRefresh then return end
        self.pendingRefresh = true
        C_Timer.After(0.2, function()
            self.pendingRefresh = nil
            if self:IsShown() then RecipeBrowserWindow.refreshActiveView() end
        end)
    end)

    table.insert(UISpecialFrames, "EzWoWProfessionRecipesFrame")
end

function RecipeBrowserWindow.dockBrowserToTradeSkillFrame()
    panelFrameEntry:ClearAllPoints()
    if ProfessionsFrame and ProfessionsFrame:IsShown() then
        panelFrameEntry.attached = true
        panelFrameEntry:SetParent(ProfessionsFrame)
        panelFrameEntry:SetAllPoints(ProfessionsFrame)
        panelFrameEntry:SetFrameStrata("HIGH")
        panelFrameEntry:SetFrameLevel(ProfessionsFrame:GetFrameLevel() + 40)
    else
        panelFrameEntry.attached = false
        panelFrameEntry:SetParent(UIParent)
        panelFrameEntry:SetFrameStrata("HIGH")
        panelFrameEntry:SetSize(860, 600)
        local coordPos = ns.DB.standalonePos
        if coordPos then
            panelFrameEntry:SetPoint(coordPos[1], UIParent, coordPos[2], coordPos[3], coordPos[4])
        else
            panelFrameEntry:SetPoint("CENTER")
        end
    end
end

function ns.OpenProfession(skillLine, isLearned, skill)
    if not panelFrameEntry then RecipeBrowserWindow.buildProfessionBrowserWindow() end
    if not payloadData[skillLine] then return end
    isLearned = isLearned and true or false
    if isLearned then RecipeBrowserWindow.syncLearned(); skillEntry = skill or 0 end
    if currentProf ~= skillLine or learnedMode ~= isLearned then
        learnedMode = isLearned
        currentProf = skillLine
        selectedRecipe = nil
        scrollOffset = 0
        panelFrameEntry.search:SetText("")
    end
    local anchorTarget = PROF_BY_ID[skillLine]
    RecipeBrowserWindow.dockBrowserToTradeSkillFrame()
    RecipeBrowserWindow.assignPanelTitle(resolveProfName(anchorTarget) .. " |cff808080(" .. (learnedMode and L.missingTitle or L.notLearned) .. ")|r")
    panelFrameEntry.filterMenu:Hide()
    RecipeBrowserWindow.assignPanelPortrait(anchorTarget.icon)
    RecipeBrowserWindow.rebuildFilteredRecipeEntries()
    if not selectedRecipe then
        for _, recordEntry in ipairs(listEntries) do
            if recordEntry.recipe then selectedRecipe = recordEntry.recipe break end
        end
    end
    panelFrameEntry:Show()
    if panelFrameEntry.Relayout then panelFrameEntry.Relayout() end
    if ns.switcher then ns.switcher:SetShown(not panelFrameEntry.attached) end
    RecipeBrowserWindow.renderVisibleRecipeRows()
    refreshDetail()
    ns.UpdateTabChecks()
end

function ns.OpenCurrent()
    local entityID, skill = RecipeBrowserWindow.resolveCurrentTradeSkillLine()
    if not entityID then
        print("|cffeba86aEzWoW - Profession Recipes|r: " .. L.openProfFirst)
        return
    end
    ns.OpenProfession(entityID, true, skill)
end

-----------------------------------------------------------------------------
-- Resolve Native Tabs
-----------------------------------------------------------------------------
local buildJournalTabButtons = {}
local nativeHooked = {}

function RecipeBrowserWindow.resolveNativeTabs()
    local outputList = {}
    if not ProfessionsFrame then return outputList end
    for _, key in ipairs({ "Overview", 1, 2, 3, 4, 5, 6, 7, 8, 9 }) do
        local resolvedValue = ProfessionsFrame["Professions" .. key .. "Tab"]
        if type(resolvedValue) == "table" and resolvedValue.GetObjectType then outputList[#outputList + 1] = resolvedValue end
    end
    return outputList
end

function RecipeBrowserWindow.buildTab(findSequenceMatchIndex)
    local isCallOk, tabWidget = pcall(CreateFrame, "Frame", nil, ProfessionsFrame, "QuestLogTabButtonTemplate")
    if not isCallOk or not tabWidget then
        tabWidget = CreateFrame("Button", nil, ProfessionsFrame)
        tabWidget:SetSize(36, 36)
        local backdropTex = tabWidget:CreateTexture(nil, "BACKGROUND")
        backdropTex:SetPoint("TOPLEFT", -4, 4)
        backdropTex:SetPoint("BOTTOMRIGHT", 4, -4)
        backdropTex:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
        backdropTex:SetTexCoord(0, 0.6, 0, 0.6)
        tabWidget.Icon = tabWidget:CreateTexture(nil, "ARTWORK")
        tabWidget.Icon:SetAllPoints()
        tabWidget.Selected = tabWidget:CreateTexture(nil, "OVERLAY")
        tabWidget.Selected:SetAllPoints()
        tabWidget.Selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        tabWidget.Selected:SetBlendMode("ADD")
        tabWidget:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        tabWidget.SetChecked = function(self, v) self.Selected:SetShown(v) end
    end
    tabWidget:EnableMouse(true)
    tabWidget.displayMode = nil
    local function onClick(self)
        if self.skillLine == -1 then
            ns.ToggleSettings()
        elseif self.skillLine == 0 then
            if panelFrameEntry and panelFrameEntry:IsShown() and learnedMode then panelFrameEntry:Hide() else ns.OpenCurrent() end
        elseif panelFrameEntry and panelFrameEntry:IsShown() and currentProf == self.skillLine and not learnedMode then
            panelFrameEntry:Hide()
        else
            ns.OpenProfession(self.skillLine)
        end
    end
    if tabWidget.SetCustomOnMouseUpHandler then
        tabWidget:SetCustomOnMouseUpHandler(function(self, button, upInside)
            if upInside == false then return end
            onClick(self)
        end)
    else
        tabWidget:SetScript("OnMouseUp", function(self, button)
            if self:IsMouseOver() then onClick(self) end
        end)
    end
    tabWidget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("EzWoW - Profession Recipes", unpack(Theme.accent))
        local tipText
        if self.skillLine == -1 then
            tipText = L.settingsTip
        elseif self.skillLine == 0 then
            tipText = L.currentTip
        else
            tipText = L.tabTip:format(resolveProfName(PROF_BY_ID[self.skillLine]))
        end
        local first, rest = (tipText or ""):match("^([^\n]+)\n?(.*)$")
        if first and first ~= "" then
            GameTooltip:AddLine(first, 0.929, 0.957, 0.969, true)
        end
        if rest and rest ~= "" then
            GameTooltip:AddLine(rest, 0.655, 0.725, 0.773, true)
        end
        GameTooltip:Show()
    end)
    tabWidget:SetScript("OnLeave", GameTooltip_Hide)
    buildJournalTabButtons[findSequenceMatchIndex] = tabWidget
    return tabWidget
end

function RecipeBrowserWindow.mirrorPoint(pt)
    if not pt then return pt end
    return (pt:gsub("LEFT", "\001"):gsub("RIGHT", "LEFT"):gsub("\001", "RIGHT"))
end

function RecipeBrowserWindow.anchorTabIcon(tabWidget, want)
    local iconTex = tabWidget.Icon
    if not iconTex or not iconTex.GetNumPoints then return end
    if not iconTex.__ezprPts then
        iconTex.__ezprPts = {}
        for index = 1, (iconTex:GetNumPoints() or 0) do iconTex.__ezprPts[index] = { iconTex:GetPoint(index) } end
        if #iconTex.__ezprPts == 0 then iconTex.__ezprPts[1] = { "CENTER", tabWidget, "CENTER", 0, 0 } end
    end
    iconTex:ClearAllPoints()
    for _, pt in ipairs(iconTex.__ezprPts) do
        local anchorTarget, rel, relativePoint, coordX, coordY = pt[1], pt[2], pt[3], pt[4] or 0, pt[5] or 0
        if want then
            iconTex:SetPoint(RecipeBrowserWindow.mirrorPoint(anchorTarget), rel, RecipeBrowserWindow.mirrorPoint(relativePoint), -coordX, coordY)
        else
            iconTex:SetPoint(anchorTarget, rel, relativePoint, coordX, coordY)
        end
    end
end

function RecipeBrowserWindow.mirrorTabAnchors(tabWidget, want)
    RecipeBrowserWindow.anchorTabIcon(tabWidget, want)
    if tabWidget.__ezprMirrored == want then return end
    local regions = { tabWidget:GetRegions() }
    if tabWidget.GetHighlightTexture then regions[#regions + 1] = tabWidget:GetHighlightTexture() end
    for _, r in ipairs(regions) do
        if r and r ~= tabWidget.Icon and r.GetNumPoints then
            if not r.__ezprPts then
                r.__ezprPts = {}
                for index = 1, (r:GetNumPoints() or 0) do r.__ezprPts[index] = { r:GetPoint(index) } end
            end
            if #r.__ezprPts > 0 then
                r:ClearAllPoints()
                for _, pt in ipairs(r.__ezprPts) do
                    local anchorTarget, rel, relativePoint, coordX, coordY = pt[1], pt[2], pt[3], pt[4] or 0, pt[5] or 0
                    if want then
                        r:SetPoint(RecipeBrowserWindow.mirrorPoint(anchorTarget), rel, RecipeBrowserWindow.mirrorPoint(relativePoint), -coordX, coordY)
                    else
                        r:SetPoint(anchorTarget, rel, relativePoint, coordX, coordY)
                    end
                end
            end
        end
    end
    tabWidget.__ezprMirrored = want
end

function RecipeBrowserWindow.commitTabFlip(tabWidget)
    local want = (ns.DB and ns.DB.tabPos == "left") and true or false
    RecipeBrowserWindow.mirrorTabAnchors(tabWidget, want)
    local regions = { tabWidget:GetRegions() }
    if tabWidget.GetHighlightTexture then regions[#regions + 1] = tabWidget:GetHighlightTexture() end
    for _, r in ipairs(regions) do
        if r and r ~= tabWidget.Icon and r.GetObjectType and r:GetObjectType() == "Texture" and r.GetTexCoord then
            local ulx, uly, llx, lly, urx, ury, lrx, lry = r:GetTexCoord()
            if ulx and urx then
                local flipped = ulx > urx
                if want ~= flipped then
                    r:SetTexCoord(urx, ury, lrx, lry, ulx, uly, llx, lly)
                end
            end
        end
    end
end

function RecipeBrowserWindow.bindTabFlip(tabWidget)
    if tabWidget.__ezprFlipHooked then return end
    tabWidget.__ezprFlipHooked = true
    local function again() RecipeBrowserWindow.commitTabFlip(tabWidget) end
    
    if tabWidget.SetChecked then hooksecurefunc(tabWidget, "SetChecked", again) end
    for _, eventFrame in ipairs({ "OnShow", "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp" }) do
        pcall(tabWidget.HookScript, tabWidget, eventFrame, again)
    end
end

function ns.UpdateTabChecks()
    local shown = panelFrameEntry and panelFrameEntry:IsShown() and panelFrameEntry.attached
    for _, tabWidget in ipairs(buildJournalTabButtons) do
        local onVal
        if tabWidget.skillLine == -1 then onVal = ns.settingsFrame and ns.settingsFrame:IsShown()
        elseif tabWidget.skillLine == 0 then onVal = shown and learnedMode else onVal = shown and not learnedMode and currentProf == tabWidget.skillLine end
        if tabWidget.SetChecked then tabWidget:SetChecked(onVal and true or false) end
    end
end

function RecipeBrowserWindow.bindNativeTab(resolvedValue)
    if nativeHooked[resolvedValue] then return end
    nativeHooked[resolvedValue] = true
    local function hide() if panelFrameEntry and panelFrameEntry.attached then panelFrameEntry:Hide() end end
    pcall(resolvedValue.HookScript, resolvedValue, "OnMouseDown", hide)
    pcall(resolvedValue.HookScript, resolvedValue, "OnMouseUp", hide)
    pcall(resolvedValue.HookScript, resolvedValue, "OnClick", hide)
end

function RecipeBrowserWindow.resolveLowestExistingTab()
    local lowest, lowestBottom
    local function consider(resolvedValue)
        if resolvedValue and resolvedValue:IsShown() and resolvedValue.GetBottom then
            local b = resolvedValue:GetBottom()
            if b and (not lowestBottom or b < lowestBottom) then lowest, lowestBottom = resolvedValue, b end
        end
    end
    for _, resolvedValue in ipairs(RecipeBrowserWindow.resolveNativeTabs()) do consider(resolvedValue) end
    if ProfessionsFrameTabSideBar and ProfessionsFrameTabSideBar.Tabs then
        for _, resolvedValue in pairs(ProfessionsFrameTabSideBar.Tabs) do consider(resolvedValue) end
    end
    return lowest
end

function RecipeBrowserWindow.resolveTabStep()
    local a, b = ProfessionsFrame.ProfessionsOverviewTab, ProfessionsFrame.Professions1Tab
    if a and b and a:GetTop() and b:GetTop() then
        local stateFlag = a:GetTop() - b:GetTop()
        if stateFlag > 20 and stateFlag < 120 then return stateFlag end
    end
    return 50
end

function RecipeBrowserWindow.positionProfessionSideTabs()
    if not ProfessionsFrame then return end
    for _, resolvedValue in ipairs(RecipeBrowserWindow.resolveNativeTabs()) do RecipeBrowserWindow.bindNativeTab(resolvedValue) end

    local learned = scanLearnedProfessionIDs()
    
    local wanted = { { id = 0, icon = "Interface\\Icons\\INV_Scroll_03" } }
    for _, anchorTarget in ipairs(PROFESSIONS) do
        if not learned[anchorTarget.id] and payloadData[anchorTarget.id] then wanted[#wanted + 1] = anchorTarget end
    end
    
    wanted[#wanted + 1] = { id = -1, icon = "Interface\\Icons\\INV_Misc_Gear_01" }

    local anchor = RecipeBrowserWindow.resolveLowestExistingTab()
    local step = RecipeBrowserWindow.resolveTabStep()
    local frameBottom = ProfessionsFrame:GetBottom() or 0
    local topTab = ProfessionsFrame.ProfessionsOverviewTab
    if type(topTab) ~= "table" or not topTab.GetTop or not topTab:IsShown() then topTab = nil end

    local below = 0
    if anchor and anchor:GetBottom() then
        below = math.floor((anchor:GetTop() - frameBottom) / step) - 1
    end
    local perCol = 99
    if topTab and topTab:GetTop() then
        perCol = math.max(1, math.floor((topTab:GetTop() - frameBottom) / step))
    end
    local useSideColumn = anchor and topTab and #wanted > below

    for index, anchorTarget in ipairs(wanted) do
        local tabWidget = buildJournalTabButtons[index] or RecipeBrowserWindow.buildTab(index)
        tabWidget.skillLine = anchorTarget.id
        if tabWidget.Icon then
            tabWidget.Icon:SetTexture(anchorTarget.icon)
            
            local size = ns.DB.iconSize or 30
            tabWidget.Icon:SetSize(size, size)
            tabWidget.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end
        tabWidget:ClearAllPoints()
        local w = (anchor and anchor:GetWidth()) or tabWidget:GetWidth() or 40
        if ns.DB.tabPos == "left" then
            
            local perLeft = math.max(1, math.floor(((ProfessionsFrame:GetHeight() or 600) - 80) / step))
            local columnIndex = math.floor((index - 1) / perLeft)
            local rowWidget = (index - 1) % perLeft
            tabWidget:SetPoint("TOPRIGHT", ProfessionsFrame, "TOPLEFT", 2 - columnIndex * (w + 2), -70 - rowWidget * step)
        elseif ns.DB.tabPos == "bottom" then
            
            tabWidget:SetPoint("TOPLEFT", ProfessionsFrame, "BOTTOMLEFT", 70 + (index - 1) * (w + 4), 2)
        elseif useSideColumn then
            
            local columnIndex = 1 + math.floor((index - 1) / perCol)
            local rowWidget = (index - 1) % perCol
            tabWidget:SetPoint("TOPLEFT", topTab, "TOPLEFT", columnIndex * (w + 2), -rowWidget * step)
        elseif anchor then
            tabWidget:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -index * step)
        else
            tabWidget:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 0, -60 - (index - 1) * step)
        end
        tabWidget:Show()
        RecipeBrowserWindow.bindTabFlip(tabWidget)
        RecipeBrowserWindow.commitTabFlip(tabWidget)
    end
    for index = #wanted + 1, #buildJournalTabButtons do buildJournalTabButtons[index]:Hide() end
    ns.UpdateTabChecks()
end

function RecipeBrowserWindow.onProfessionsFrameReady()
    if not ProfessionsFrame or ProfessionsFrame.__ezprHooked then return end
    ProfessionsFrame.__ezprHooked = true
    ProfessionsFrame:HookScript("OnShow", function()
        
        C_Timer.After(0, RecipeBrowserWindow.positionProfessionSideTabs)
        C_Timer.After(0.3, RecipeBrowserWindow.positionProfessionSideTabs)
    end)
    ProfessionsFrame:HookScript("OnHide", function()
        if panelFrameEntry and panelFrameEntry.attached then panelFrameEntry:Hide() end
    end)
    if ProfessionsFrame:IsShown() then C_Timer.After(0, RecipeBrowserWindow.positionProfessionSideTabs) end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "TRADE_SKILL_LIST_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "GLOBAL_MOUSE_DOWN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            bootstrapDB()
            if ns.RegisterBlizzardSettings then ns.RegisterBlizzardSettings() end
        elseif arg1 == "Blizzard_Professions" then
            RecipeBrowserWindow.onProfessionsFrameReady()
        end
    elseif event == "PLAYER_LOGIN" then
        if ProfessionsFrame then RecipeBrowserWindow.onProfessionsFrameReady() end
    elseif event == "TRADE_SKILL_SHOW" then
        RecipeBrowserWindow.onProfessionsFrameReady()
        if panelFrameEntry and panelFrameEntry.attached then panelFrameEntry:Hide() end
        C_Timer.After(0.1, RecipeBrowserWindow.positionProfessionSideTabs)
    elseif event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        if panelFrameEntry and panelFrameEntry.attached then panelFrameEntry:Hide() end
    elseif event == "GLOBAL_MOUSE_DOWN" then
        
        if panelFrameEntry and panelFrameEntry:IsShown() and panelFrameEntry.attached then
            local others = RecipeBrowserWindow.resolveNativeTabs()
            if ProfessionsFrameTabSideBar and ProfessionsFrameTabSideBar.Tabs then
                for _, resolvedValue in pairs(ProfessionsFrameTabSideBar.Tabs) do others[#others + 1] = resolvedValue end
            end
            for _, resolvedValue in ipairs(others) do
                if resolvedValue:IsShown() and resolvedValue:IsMouseOver() then panelFrameEntry:Hide() break end
            end
        end
    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        if panelFrameEntry and panelFrameEntry:IsShown() and learnedMode and not ns.listUpdatePending then
            ns.listUpdatePending = true
            C_Timer.After(0.5, function()
                ns.listUpdatePending = nil
                if not (panelFrameEntry:IsShown() and learnedMode) then return end
                local entityID, rank = RecipeBrowserWindow.resolveCurrentTradeSkillLine()
                if entityID == currentProf then
                    RecipeBrowserWindow.syncLearned()
                    skillEntry = rank or skillEntry
                    RecipeBrowserWindow.refreshActiveView()
                end
            end)
        end
    elseif event == "SKILL_LINES_CHANGED" then
        if ProfessionsFrame and ProfessionsFrame:IsShown() then C_Timer.After(0.1, RecipeBrowserWindow.positionProfessionSideTabs) end
    end
end)

-----------------------------------------------------------------------------
-- Append Reagent Usage Lines
-----------------------------------------------------------------------------
function RecipeBrowserWindow.appendReagentUsageLines(tooltip, itemID)
    if not (ns.DB and ns.DB.reagentTooltip) or not itemID then return end
    constructRecipeLookupIndex()
    local list = ns.GetReagentIndex()[itemID]
    if not list or #list == 0 then return end
    local byProf, order = {}, {}
    for _, r in ipairs(list) do
        local profIDVal = ns.ResolveRecipeProfessionKey()[r]
        if ns.DB.hideOtherFaction and hasOtherFaction(r) then profIDVal = nil end
        if profIDVal then
            if not byProf[profIDVal] then byProf[profIDVal] = {}; order[#order + 1] = profIDVal end
            table.insert(byProf[profIDVal], r)
        end
    end
    if #order == 0 then return end
    table.sort(order, function(a, b) return #byProf[a] > #byProf[b] end)
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff66ccff" .. L.usedIn .. "|r")
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    for _, profIDVal in ipairs(order) do
        local anchorTarget = PROF_BY_ID[profIDVal]
        local recipes = byProf[profIDVal]
        tooltip:AddLine(L.usedInLine:format(anchorTarget and resolveProfName(anchorTarget) or "?", #recipes), 1, 0.82, 0)
        if shift then
            RecipeBrowserWindow.sortRecipeEntryList(recipes)
            for index = 1, math.min(8, #recipes) do
                local r = recipes[index]
                tooltip:AddDoubleLine("  " .. resolveRecipeName(r), r[R_ORANGE], 1, 1, 1, 1, 0.5, 0.25)
            end
            if #recipes > 8 then tooltip:AddLine(L.andMore:format(#recipes - 8), 0.6, 0.6, 0.6) end
        end
    end
    if not shift then tooltip:AddLine(L.shiftForList, 0.5, 0.5, 0.5) end
end

function RecipeBrowserWindow.onItemTooltip(tooltip, payloadData2)
    
    pcall(function()
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
        local entityID = payloadData2 and payloadData2.id
        if not entityID and tooltip.GetItem then
            local _, link = tooltip:GetItem()
            entityID = link and tonumber(link:match("item:(%d+)"))
        end
        RecipeBrowserWindow.appendReagentUsageLines(tooltip, tonumber(entityID))
    end)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, RecipeBrowserWindow.onItemTooltip)
elseif GameTooltip and GameTooltip.HookScript then
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", function(tt) RecipeBrowserWindow.onItemTooltip(tt, nil) end)
end

-----------------------------------------------------------------------------
-- Refresh Texts
-----------------------------------------------------------------------------
function ns.RefreshTexts()
    if panelFrameEntry then
        if panelFrameEntry.search.Instructions then panelFrameEntry.search.Instructions:SetText(L.search) end
        for _, checkWidget in ipairs(panelFrameEntry.checks or {}) do checkWidget.label:SetText(L[checkWidget.labelKey]) end
        if panelFrameEntry.reagentLabel then panelFrameEntry.reagentLabel:SetText(L.reagents) end
        if panelFrameEntry.detail and panelFrameEntry.detail.mapBtn then panelFrameEntry.detail.mapBtn:SetText(L.findOnMap) end
        panelFrameEntry.empty:SetText(L.noRecipes)
        if panelFrameEntry:IsShown() and currentProf then ns.OpenProfession(currentProf, learnedMode, skillEntry) end
    end
    if ns.settingsFrame then ns.settingsFrame:UpdateTexts() end
end

function ns.ShowStandaloneSwitcher()
    if not panelFrameEntry then return end
    if not switcher then
        switcher = CreateFrame("Frame", nil, panelFrameEntry)
        switcher:SetSize(1, 1)
        switcher:SetPoint("TOPLEFT", panelFrameEntry, "TOPRIGHT", 2, -60)
        switcher.buttons = {}
        for index, anchorTarget in ipairs(PROFESSIONS) do
            local b = CreateFrame("Button", nil, switcher, "BackdropTemplate")
            b:SetSize(32, 32)
            b:SetPoint("TOPLEFT", 0, -(index - 1) * 36)
            ns.UIKit:ApplyBackdrop(b, 1, 1)
            b:SetBackdropColor(unpack(Theme.bg))
            b:SetBackdropBorderColor(unpack(Theme.border))
            local icVal = b:CreateTexture(nil, "ARTWORK")
            icVal:SetPoint("TOPLEFT", 3, -3)
            icVal:SetPoint("BOTTOMRIGHT", -3, 3)
            icVal:SetTexture(anchorTarget.icon)
            icVal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b:SetScript("OnClick", function() ns.OpenProfession(anchorTarget.id) end)
            b:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(unpack(Theme.accent))
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(resolveProfName(anchorTarget), unpack(Theme.accent))
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function(self)
                self:SetBackdropBorderColor(unpack(Theme.border))
                GameTooltip_Hide()
            end)
            switcher.buttons[index] = b
        end
        local cfgBtn = CreateFrame("Button", nil, switcher, "BackdropTemplate")
        cfgBtn:SetSize(32, 32)
        cfgBtn:SetPoint("TOPLEFT", 0, -(#PROFESSIONS * 36 + 6))
        ns.UIKit:ApplyBackdrop(cfgBtn, 1, 1)
        cfgBtn:SetBackdropColor(unpack(Theme.bg))
        cfgBtn:SetBackdropBorderColor(unpack(Theme.border))
        local cfgIc = cfgBtn:CreateTexture(nil, "ARTWORK")
        cfgIc:SetPoint("TOPLEFT", 3, -3)
        cfgIc:SetPoint("BOTTOMRIGHT", -3, 3)
        cfgIc:SetTexture("Interface\\Icons\\INV_Gizmo_02")
        cfgIc:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        cfgBtn:SetScript("OnClick", function()
            if ns.ToggleSettings then ns.ToggleSettings() end
        end)
        cfgBtn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(Theme.accent))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("EzWoW - Profession Recipes", 0.922, 0.659, 0.416)
            GameTooltip:AddLine((SETTINGS or "설정") .. " (/ezpr config)", 0.929, 0.957, 0.969)
            GameTooltip:Show()
        end)
        cfgBtn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(unpack(Theme.border))
            GameTooltip_Hide()
        end)
        switcher.cfgBtn = cfgBtn
        ns.switcher = switcher
    end
    switcher:SetShown(not panelFrameEntry.attached)
end

ns.CreateStyledButton = RecipeBrowserWindow.createRecipeFlatButton
ns.Refresh = RecipeBrowserWindow.refreshActiveView
ns.ResetBrowserScroll = function() scrollOffset = 0 end
ns.LayoutTabs = RecipeBrowserWindow.positionProfessionSideTabs
ns.GetBrowserMainFrame = function() return panelFrameEntry end
ns.GetSelectedProfessionKey = function() return currentProf end
ns.GetProfessionSideTabButtons = function() return buildJournalTabButtons end

-----------------------------------------------------------------------------
-- Module Class Exports
-----------------------------------------------------------------------------
RecipeBrowserWindow.GetSelectedProfessionKey = ns.GetSelectedProfessionKey
RecipeBrowserWindow.GetBrowserMainFrame = ns.GetBrowserMainFrame
RecipeBrowserWindow.GetProfessionSideTabButtons = ns.GetProfessionSideTabButtons
RecipeBrowserWindow.CreateStyledButton = ns.CreateStyledButton
