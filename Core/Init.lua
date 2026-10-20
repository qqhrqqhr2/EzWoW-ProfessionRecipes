--===========================================================================
-- EzWoW - Profession Recipes
-- Core/Init.lua : Namespace, EzWoW Theme Palette, Field Indices & Flags
--===========================================================================
local _, ns = ...
local bitBand = bit and bit.band

local CoreConfig = ns.CoreConfig or {}
ns.CoreConfig = CoreConfig
_G.EzWoW_ProfessionRecipes = ns

ns.Style = {
    bg     = { 0.071, 0.094, 0.122, 0.92 },
    bgSub  = { 0.114, 0.157, 0.192, 0.85 },
    border = { 0.204, 0.298, 0.357, 1.00 },
    accent = { 0.922, 0.659, 0.416, 1.00 },
    cyan   = { 0.294, 0.784, 0.910, 1.00 },
    text   = { 0.929, 0.957, 0.969, 1.00 },
    muted  = { 0.655, 0.725, 0.773, 1.00 },
}

ns.LOCALE_MAP = {
    koKR = "ko",
    enUS = "en",
    enGB = "en",
    deDE = "de",
    frFR = "fr",
    esES = "es",
    esMX = "es",
    ruRU = "ru",
    zhCN = "zhCN",
    zhTW = "zhTW",
}

ns.CLIENT_LOCALE = (GetLocale and GetLocale()) or "enUS"
ns.CLIENT_LANG   = ns.LOCALE_MAP[ns.CLIENT_LOCALE] or "en"
ns.CLIENT_KO     = (ns.CLIENT_LANG == "ko")
ns.ACTIVE_LANG   = ns.CLIENT_LANG
ns.IS_KO         = ns.CLIENT_KO
ns.LI            = ns.IS_KO and 1 or 2

-- Recipe tuple indices (1..17)
ns.R_SPELL   = 1
ns.R_ITEM    = 2
ns.R_CAT     = 3
ns.R_ORANGE  = 4
ns.R_YELLOW  = 5
ns.R_GREEN   = 6
ns.R_GREY    = 7
ns.R_FLAGS   = 8
ns.R_QTY     = 9
ns.R_ICON    = 10
ns.R_NAME_KO = 11
ns.R_NAME_EN = 12
ns.R_REAG    = 13
ns.R_DESC_KO = 14
ns.R_DESC_EN = 15
ns.R_SRC_KO  = 16
ns.R_SRC_EN  = 17

-- Bitwise recipe flags
ns.F_NEW      = 1
ns.F_TRAINER  = 2
ns.F_ALLIANCE = 4
ns.F_HORDE    = 8

function CoreConfig.HasBitwiseRecipeFlag(recipeRow, flagMask)
    return bitBand(recipeRow[8] or 0, flagMask) ~= 0
end
ns.HasBitwiseRecipeFlag = CoreConfig.HasBitwiseRecipeFlag
