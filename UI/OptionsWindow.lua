--===========================================================================
-- EzWoW - Profession Recipes
-- UI/OptionsWindow.lua : EzWoW Style Settings Window, Radio Selectors & Slash Commands
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local SettingsDialog = ns.SettingsDialog or {}
ns.SettingsDialog = SettingsDialog
local Theme = ns.Style
local L = ns.L
local DONATE_URL = ns.DONATE_URL
local PROFESSIONS = ns.PROFESSIONS
local resolveProfName = ns.GetLocalizedProfessionName
local LANG_ALIASES = ns.LANG_ALIASES
local commitLanguage = ns.ApplyLanguage
local bootstrapDB = ns.InitDB
local scanLearnedProfessionIDs = ns.GetLearnedSkillLines
local createRecipeFlatButton = ns.CreateStyledButton
local positionProfessionSideTabs = ns.LayoutTabs
local refreshActiveView = ns.Refresh

-----------------------------------------------------------------------------
-- Open Donate Dialog
-----------------------------------------------------------------------------
local profDonateFrame
function SettingsDialog.openDonateDialog()
    if not profDonateFrame then
        local windowFrame = CreateFrame("Frame", "EzWoWProfessionRecipesDonate", UIParent, "BackdropTemplate")
        windowFrame:SetSize(380, 132)
        windowFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        ns.UIKit:ElevateModal(windowFrame, 260)
        windowFrame:EnableMouse(true)
        windowFrame:SetMovable(true)
        windowFrame:RegisterForDrag("LeftButton")
        windowFrame:SetScript("OnDragStart", windowFrame.StartMoving)
        windowFrame:SetScript("OnDragStop", windowFrame.StopMovingOrSizing)
        ns.UIKit:ApplyBackdrop(windowFrame, 1, 1)
        windowFrame:SetBackdropColor(unpack(Theme.bg))
        windowFrame:SetBackdropBorderColor(unpack(Theme.accent))

        local titleStr = windowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleStr:SetPoint("TOP", windowFrame, "TOP", 0, -12)
        titleStr:SetTextColor(unpack(Theme.accent))
        windowFrame.title = titleStr

        local desc = windowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOP", titleStr, "BOTTOM", 0, -8)
        desc:SetWidth(346)
        windowFrame.desc = desc

        local inputBox = CreateFrame("EditBox", nil, windowFrame, "BackdropTemplate")
        inputBox:SetSize(344, 24)
        inputBox:SetFrameLevel(windowFrame:GetFrameLevel() + 5)
        inputBox:SetPoint("BOTTOM", windowFrame, "BOTTOM", 0, 16)
        inputBox:SetFontObject(ChatFontNormal)
        inputBox:SetTextInsets(6, 6, 0, 0)
        inputBox:SetAutoFocus(false)
        ns.UIKit:ApplyBackdrop(inputBox, 1, 1)
        inputBox:SetBackdropColor(0.047, 0.067, 0.086, 0.96)
        inputBox:SetBackdropBorderColor(unpack(Theme.border))
        inputBox:SetText(DONATE_URL)
        inputBox:SetScript("OnEditFocusGained", function(self)
            self:SetBackdropBorderColor(unpack(Theme.accent))
        end)
        inputBox:SetScript("OnEditFocusLost", function(self)
            self:SetBackdropBorderColor(unpack(Theme.border))
        end)
        inputBox:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                self:SetText(DONATE_URL)
                self:HighlightText()
            end
        end)
        inputBox:SetScript("OnEscapePressed", function() windowFrame:Hide() end)
        inputBox:SetScript("OnEnterPressed", function() windowFrame:Hide() end)
        inputBox:SetScript("OnMouseUp", function(self) self:HighlightText() end)
        windowFrame.eb = inputBox

        local close = createRecipeFlatButton(windowFrame, 22, 22, false, function() windowFrame:Hide() end)
        close:SetPoint("TOPRIGHT", windowFrame, "TOPRIGHT", -8, -8)
        close:SetFrameLevel(windowFrame:GetFrameLevel() + 5)
        close:SetText("X")
        if UISpecialFrames then table.insert(UISpecialFrames, "EzWoWProfessionRecipesDonate") end
        profDonateFrame = windowFrame
    end
    profDonateFrame.title:SetText("EzWoW - Profession Recipes · " .. (L.donate or "후원하기"))
    profDonateFrame.desc:SetText(L.donateText)
    ns.UIKit:ElevateModal(profDonateFrame, 260)
    profDonateFrame:Show()
    if profDonateFrame.Raise then profDonateFrame:Raise() end
    profDonateFrame.eb:SetText(DONATE_URL)
    profDonateFrame.eb:SetFocus()
    profDonateFrame.eb:HighlightText()
end

function SettingsDialog.buildRadioGroup(parent, items, getter, setter, descKey)
    local radioOptionGroup = {}
    for index, itVal in ipairs(items) do
        local checkWidget = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        checkWidget:SetSize(22, 22)
        local labelRegion = checkWidget.Text or checkWidget.text
        if not labelRegion then
            labelRegion = checkWidget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            labelRegion:SetPoint("LEFT", checkWidget, "RIGHT", 0, 1)
        end
        labelRegion:SetFontObject("GameFontHighlightSmall")
        checkWidget.label, checkWidget.value, checkWidget.textKey = labelRegion, itVal.value, itVal.textKey
        checkWidget:SetScript("OnClick", function(self)
            setter(self.value)
            for _, optionRef in ipairs(radioOptionGroup) do optionRef:SetChecked(optionRef.value == getter()) end
        end)
        if descKey then
            checkWidget:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L[self.textKey] or self.textKey, unpack(Theme.accent))
                if L[descKey] then
                    GameTooltip:AddLine(L[descKey], 0.929, 0.957, 0.969, true)
                end
                GameTooltip:Show()
            end)
            checkWidget:SetScript("OnLeave", GameTooltip_Hide)
        end
        radioOptionGroup[index] = checkWidget
    end
    radioOptionGroup.Refresh = function()
        for _, optionRef in ipairs(radioOptionGroup) do
            optionRef:SetChecked(optionRef.value == getter())
            optionRef.label:SetText(L[optionRef.textKey] or optionRef.textKey)
            if optionRef.fitWidth then ns.UIKit:FitFontString(optionRef.label, optionRef.fitWidth, 1) end
        end
    end
    return radioOptionGroup
end

local optionsCanvas

function SettingsDialog.buildSettings()
    local windowFrame = CreateFrame("Frame", "EzWoWProfessionRecipesSettings", UIParent, "BackdropTemplate")
    ns.UIKit:ApplyBackdrop(windowFrame, 1, 1)
    windowFrame:SetBackdropColor(unpack(Theme.bg))
    windowFrame:SetBackdropBorderColor(unpack(Theme.border))
    ns.settingsFrame = windowFrame
    windowFrame:SetSize(420, 436)
    windowFrame:SetPoint("CENTER")
    windowFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    windowFrame:SetToplevel(true)
    windowFrame:SetClampedToScreen(true)
    windowFrame:EnableMouse(true)
    windowFrame:SetMovable(true)

    local top = CreateFrame("Frame", nil, windowFrame, "BackdropTemplate")
    top:SetPoint("TOPLEFT", windowFrame, "TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", windowFrame, "TOPRIGHT", -1, -1)
    top:SetHeight(56)
    top:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    top:SetBackdropColor(unpack(Theme.bgSub))
    top:EnableMouse(true)
    top:RegisterForDrag("LeftButton")
    top:SetScript("OnDragStart", function() windowFrame:StartMoving() end)
    top:SetScript("OnDragStop", function() windowFrame:StopMovingOrSizing() end)

    local accentLine = top:CreateTexture(nil, "ARTWORK")
    accentLine:SetPoint("BOTTOMLEFT", top, "BOTTOMLEFT", 0, 0)
    accentLine:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", 0, 0)
    accentLine:SetHeight(2)
    accentLine:SetColorTexture(unpack(Theme.accent))

    local titleIcon = top:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(28, 28)
    titleIcon:SetPoint("TOPLEFT", 14, -14)
    titleIcon:SetTexture("Interface\\AddOns\\EzWoW-ProfessionRecipes\\Icon")

    local headingRegion = top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headingRegion:SetPoint("TOPLEFT", 48, -11)
    headingRegion:SetText("EzWoW - Profession Recipes")
    headingRegion:SetTextColor(unpack(Theme.accent))

    local titleStr = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleStr:SetPoint("TOPLEFT", headingRegion, "BOTTOMLEFT", 0, -3)
    titleStr:SetWidth(330)
    titleStr:SetJustifyH("LEFT")
    titleStr:SetTextColor(unpack(Theme.muted))

    local close = createRecipeFlatButton(top, 22, 22, false, function() windowFrame:Hide() end)
    close:SetPoint("TOPRIGHT", top, "TOPRIGHT", -10, -10)
    close:SetFrameLevel(top:GetFrameLevel() + 3)
    close:SetText("X")

    windowFrame:Hide()
    windowFrame:SetScript("OnShow", function() windowFrame:UpdateTexts(); ns.UpdateTabChecks() end)
    windowFrame:SetScript("OnHide", function() ns.UpdateTabChecks() end)
    table.insert(UISpecialFrames, "EzWoWProfessionRecipesSettings")

    local function createSectionDivider(yOffset)
        local labelRegion = windowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        labelRegion:SetPoint("TOPLEFT", 20, yOffset)
        labelRegion:SetTextColor(unpack(Theme.accent))
        local lnVal = windowFrame:CreateTexture(nil, "ARTWORK")
        lnVal:SetColorTexture(0.204, 0.298, 0.357, 0.85)
        lnVal:SetPoint("TOPLEFT", windowFrame, "TOPLEFT", 20, yOffset - 18)
        lnVal:SetPoint("TOPRIGHT", windowFrame, "TOPRIGHT", -20, yOffset - 18)
        lnVal:SetHeight(1)
        return labelRegion
    end

    local langLabel = createSectionDivider(-70)
    -- language: click the box, then pick a language from the list
    local LANG_TEXT_KEYS = {
        { value = "auto", textKey = "langAuto" },
        { value = "ko",   textKey = "langKo" },
        { value = "en",   textKey = "langEn" },
        { value = "de",   textKey = "langDe" },
        { value = "fr",   textKey = "langFr" },
        { value = "es",   textKey = "langEs" },
        { value = "ru",   textKey = "langRu" },
        { value = "zhCN", textKey = "langZhCN" },
        { value = "zhTW", textKey = "langZhTW" },
    }
    local function langName(value)
        for _, item in ipairs(LANG_TEXT_KEYS) do
            if item.value == value then return L[item.textKey] or item.textKey end
        end
        return L.langAuto
    end
    local langBox = createRecipeFlatButton(windowFrame, 240, 24, false, nil)
    langBox:SetPoint("TOPLEFT", 20, -96)
    local langItems = {}
    for index, item in ipairs(LANG_TEXT_KEYS) do
        langItems[index] = { value = item.value, text = function() return L[item.textKey] or item.textKey end }
    end
    ns.LanguageDropdown.Attach(langBox, {
        items = langItems,
        colors = { bg = Theme.bg, border = Theme.border, accent = Theme.accent, text = Theme.text },
        get = function() return ns.DB.lang or "auto" end,
        set = function(v)
            ns.DB.lang = v
            commitLanguage()
            ns.RefreshTexts()
        end,
    })
    -- the single box takes 92px less than the old radio buttons; everything below moves up
    local LANG_ROWS_SAVED = 92
    local note = windowFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", langBox, "BOTTOMLEFT", 2, -4)
    note:SetPoint("RIGHT", windowFrame, "RIGHT", -20, 0)
    note:SetJustifyH("LEFT")
    note:SetTextColor(unpack(Theme.muted))

    local posLabel = createSectionDivider(-252 + LANG_ROWS_SAVED)
    local coordPos = SettingsDialog.buildRadioGroup(windowFrame, {
        { value = "left", textKey = "posLeftL" }, { value = "bottom", textKey = "posBottomL" }, { value = "side", textKey = "posRightL" },
    }, function() return ns.DB.tabPos end, function(v)
        ns.DB.tabPos = v
        positionProfessionSideTabs()
    end, "tabPosDesc")
    coordPos[1]:SetPoint("TOPLEFT", 20, -276 + LANG_ROWS_SAVED)
    coordPos[2]:SetPoint("TOPLEFT", 152, -276 + LANG_ROWS_SAVED)
    coordPos[3]:SetPoint("TOPLEFT", 284, -276 + LANG_ROWS_SAVED)
    for i = 1, 3 do
        if coordPos[i].label then
            coordPos[i].label:SetWidth(104)
            coordPos[i].label:SetJustifyH("LEFT")
            if coordPos[i].label.SetWordWrap then coordPos[i].label:SetWordWrap(false) end
            coordPos[i].fitWidth = 104
        end
    end

    local sizeLabel = windowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", 22, -312 + LANG_ROWS_SAVED)
    sizeLabel:SetTextColor(unpack(Theme.text))
    local function sizeBtn(text, delta)
        local buttonWidget = createRecipeFlatButton(windowFrame, 32, 22, false, function()
            ns.DB.iconSize = math.max(16, math.min(48, (ns.DB.iconSize or 30) + delta))
            positionProfessionSideTabs()
            windowFrame:UpdateTexts()
        end)
        buttonWidget.label:SetText(text)
        return buttonWidget
    end
    local plus = sizeBtn("+", 2)
    plus:SetPoint("TOPRIGHT", -20, -308 + LANG_ROWS_SAVED)
    local minus = sizeBtn("-", -2)
    minus:SetPoint("RIGHT", plus, "LEFT", -6, 0)

    local tipCheck = CreateFrame("CheckButton", nil, windowFrame, "UICheckButtonTemplate")
    tipCheck:SetSize(24, 24)
    tipCheck:SetPoint("TOPLEFT", 18, -342 + LANG_ROWS_SAVED)
    local tipText = tipCheck.Text or tipCheck.text or tipCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not (tipCheck.Text or tipCheck.text) then tipText:SetPoint("LEFT", tipCheck, "RIGHT", 4, 0) end
    tipText:SetFontObject("GameFontHighlight")
    tipText:SetTextColor(unpack(Theme.text))
    tipCheck:SetScript("OnClick", function(self) ns.DB.reagentTooltip = self:GetChecked() and true or false end)
    tipCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.reagentTooltip, unpack(Theme.accent))
        if L.reagentTooltipDesc then
            GameTooltip:AddLine(L.reagentTooltipDesc, 0.929, 0.957, 0.969, true)
        end
        GameTooltip:Show()
    end)
    tipCheck:SetScript("OnLeave", GameTooltip_Hide)

    local quickLabel = createSectionDivider(-378 + LANG_ROWS_SAVED)
    local quick = SettingsDialog.buildRadioGroup(windowFrame, {
        { value = "ALT",   textKey = "quickAlt" },
        { value = "CTRL",  textKey = "quickCtrl" },
        { value = "SHIFT", textKey = "quickShift" },
        { value = "OFF",   textKey = "quickOff" },
    }, function() return ns.DB.quickModifier or "ALT" end, function(v)
        ns.DB.quickModifier = v
        if ns.UpdateQuickModifier then ns.UpdateQuickModifier() end
    end, "quickActionDesc")
    for idx = 1, 4 do
        local col = (idx - 1) % 2
        local row = math.floor((idx - 1) / 2)
        quick[idx]:SetPoint("TOPLEFT", 20 + col * 190, -402 + LANG_ROWS_SAVED - row * 26)
        if quick[idx].label then
            quick[idx].label:SetWidth(158)
            quick[idx].label:SetJustifyH("LEFT")
            if quick[idx].label.SetWordWrap then quick[idx].label:SetWordWrap(false) end
            quick[idx].fitWidth = 158
        end
    end

    local resetBtn = createRecipeFlatButton(windowFrame, 184, 28, false, function()
        ns.DB.tabPos = "left"
        ns.DB.standalonePos = nil
        ns.DB.iconSize = 30
        ns.DB.reagentTooltip = true
        ns.DB.quickModifier = "ALT"
        if ns.UpdateQuickModifier then ns.UpdateQuickModifier() end
        if ns.GetBrowserMainFrame() and not ns.GetBrowserMainFrame().attached then
            ns.GetBrowserMainFrame():ClearAllPoints()
            ns.GetBrowserMainFrame():SetPoint("CENTER")
        end
        positionProfessionSideTabs()
        windowFrame:UpdateTexts()
    end)
    resetBtn:SetPoint("BOTTOMLEFT", 20, 32)

    local donate = createRecipeFlatButton(windowFrame, 184, 28, true, SettingsDialog.openDonateDialog)
    donate:SetPoint("BOTTOMRIGHT", -20, 32)

    local footerRegion = windowFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerRegion:SetPoint("BOTTOMRIGHT", -20, 10)
    footerRegion:SetText("EzWoW - Profession Recipes · /ezpr")
    footerRegion:SetTextColor(unpack(Theme.muted))

    function windowFrame:UpdateTexts()
        titleStr:SetText(L.settings)
        langLabel:SetText(L.language)
        note:SetText(L.langNote)
        posLabel:SetText(L.tabPosLabel)
        sizeLabel:SetText(L.iconSizeLabel:format(ns.DB.iconSize or 30))
        ns.UIKit:FitFontString(sizeLabel, 300, 1)  -- must stay left of the -/+ buttons
        quickLabel:SetText(L.quickActionLabel)
        resetBtn.label:SetText(L.resetSettings or RESET or "Reset")
        ns.UIKit:FitFontString(resetBtn.label, 176, 1)
        donate.label:SetText(L.donate)
        ns.UIKit:FitFontString(donate.label, 176, 1)
        tipText:SetText(L.reagentTooltip)
        ns.UIKit:FitFontString(tipText, 360, 1)
        tipCheck:SetChecked(ns.DB.reagentTooltip)
        langBox.label:SetText(langName(ns.DB.lang or "auto") .. " ▼")
        ns.UIKit:FitFontString(langBox.label, 228, 1)
        ns.LanguageDropdown.Refresh(langBox)
        coordPos.Refresh()
        quick.Refresh()
        if optionsCanvas and optionsCanvas.UpdateTexts then
            optionsCanvas:UpdateTexts()
        end
    end
    return windowFrame
end

function ns.ToggleSettings()
    if not ns.settingsFrame then SettingsDialog.buildSettings() end
    ns.settingsFrame:SetShown(not ns.settingsFrame:IsShown())
    if ns.settingsFrame:IsShown() then ns.settingsFrame:Raise() end
end

function SettingsDialog.registerBlizzardSettings()
    if optionsCanvas then return end
    local canvasFrame = CreateFrame("Frame", "EzWoWProfessionRecipesOptionsPanel", UIParent)
    canvasFrame.name = "EzWoW - Profession Recipes"
    optionsCanvas = canvasFrame

    local iconTex = canvasFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(32, 32)
    iconTex:SetPoint("TOPLEFT", 18, -18)
    iconTex:SetTexture("Interface\\AddOns\\EzWoW-ProfessionRecipes\\Icon")

    local resolvedValue = canvasFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    resolvedValue:SetPoint("LEFT", iconTex, "RIGHT", 10, 0)
    resolvedValue:SetTextColor(unpack(Theme.accent))
    resolvedValue:SetText("EzWoW - Profession Recipes")

    local desc = canvasFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", iconTex, "BOTTOMLEFT", 0, -14)
    desc:SetWidth(520)
    desc:SetJustifyH("LEFT")

    local buttonWidget = createRecipeFlatButton(canvasFrame, 240, 28, true, function()
        ns.ToggleSettings()
    end)
    buttonWidget:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)

    local hint = canvasFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", buttonWidget, "BOTTOMLEFT", 0, -14)
    hint:SetTextColor(unpack(Theme.muted))

    function canvasFrame:UpdateTexts()
        desc:SetText(ns.IS_KO and "모든 전문기술의 제조법, 숙련도 구간, 필요 재료 및 도안 획득처를 한눈에 확인합니다." or "Browse recipes, skill ranges, reagents, and recipe sources for all professions.")
        buttonWidget:SetText((L.settings or "설정") .. " (/ezpr)")
        hint:SetText(ns.IS_KO and "채팅창에 /ezpr 또는 /ezpr config를 입력해도 열립니다." or "Type /ezpr or /ezpr config in chat to open settings.")
    end
    canvasFrame:SetScript("OnShow", function(self) self:UpdateTexts() end)
    canvasFrame:UpdateTexts()

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local isCallOk, categoryKey = pcall(Settings.RegisterCanvasLayoutCategory, canvasFrame, "EzWoW - Profession Recipes")
        if isCallOk and categoryKey then pcall(Settings.RegisterAddOnCategory, categoryKey) end
    elseif InterfaceOptions_AddCategory then
        pcall(InterfaceOptions_AddCategory, canvasFrame)
    end
end
ns.RegisterBlizzardSettings = SettingsDialog.registerBlizzardSettings

SLASH_EZWOWPROFESSIONRECIPES1 = "/ezpr"
SLASH_EZWOWPROFESSIONRECIPES2 = "/apr"
SLASH_EZWOWPROFESSIONRECIPES3 = "/제조법"
SLASH_EZWOWPROFESSIONRECIPES4 = "/전문기술"
SlashCmdList.EZWOWPROFESSIONRECIPES = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "reset" then
        EzWoW_ProfessionRecipesDB = nil
        EzWoW_ProfessionRecipesDB = nil
        bootstrapDB()
        positionProfessionSideTabs()
        ns.RefreshTexts()
        if ns.settingsFrame then ns.settingsFrame:UpdateTexts() end
        if ns.GetBrowserMainFrame() then
            for _, checkWidget in ipairs(ns.GetBrowserMainFrame().checks) do checkWidget:SetChecked(ns.DB[checkWidget.key]) end
            ns.GetBrowserMainFrame().filterMenu:Hide()
            if ns.ResetBrowserScroll then ns.ResetBrowserScroll() end
            refreshActiveView()
        end
        print("|cffeba86aEzWoW - Profession Recipes|r: " .. L.resetDone)
        return
    elseif msg:match("^lang%s+") then
        local arg = msg:match("^lang%s+(%S+)")
        local mapped = arg and LANG_ALIASES[arg]
        if mapped then
            ns.DB.lang = mapped
            commitLanguage()
            ns.RefreshTexts()
            print("|cffeba86aEzWoW - Profession Recipes|r: " .. L.language .. " = " .. mapped)
        end
        return
    elseif msg:match("^quick%s+") then
        local arg = msg:match("^quick%s+(%S+)")
        local map = { alt = "ALT", ctrl = "CTRL", shift = "SHIFT", off = "OFF" }
        local mapped = arg and map[arg]
        if mapped then
            ns.DB.quickModifier = mapped
            if ns.UpdateQuickModifier then ns.UpdateQuickModifier() end
            if ns.settingsFrame then ns.settingsFrame:UpdateTexts() end
            print("|cffeba86aEzWoW - Profession Recipes|r: " .. L.quickActionLabel .. " = " .. mapped)
        end
        return
    elseif msg == "side" or msg == "bottom" or msg == "left" then
        ns.DB.tabPos = msg
        positionProfessionSideTabs()
        local matchRef = (msg == "side" and L.posSide) or (msg == "left" and L.posLeft) or L.posBottom
        print("|cffeba86aEzWoW - Profession Recipes|r: " .. matchRef)
        return
    elseif msg == "config" or msg == "settings" or msg == "설정" then
        ns.ToggleSettings()
        return
    elseif msg:match("^icon%s+%d+$") then
        local nodeEntry = tonumber(msg:match("%d+"))
        if nodeEntry >= 16 and nodeEntry <= 48 then
            ns.DB.iconSize = nodeEntry
            positionProfessionSideTabs()
            print("|cffeba86aEzWoW - Profession Recipes|r: icon " .. nodeEntry)
        end
        return
    elseif msg == "help" or msg == "?" then
        print("|cffeba86aEzWoW - Profession Recipes|r: " .. L.help)
        return
    end
    
    local learned = scanLearnedProfessionIDs()
    local targetKey = ns.GetSelectedProfessionKey()
    if not targetKey then
        for _, anchorTarget in ipairs(PROFESSIONS) do
            if not learned[anchorTarget.id] then targetKey = anchorTarget.id break end
        end
    end
    targetKey = targetKey or 202
    if ns.GetBrowserMainFrame() and ns.GetBrowserMainFrame():IsShown() and not ns.GetBrowserMainFrame().attached then ns.GetBrowserMainFrame():Hide() return end
    ns.OpenProfession(targetKey)
    ns.ShowStandaloneSwitcher()
end

local switcher

ns.RegisterBlizzardSettings = SettingsDialog.registerBlizzardSettings
