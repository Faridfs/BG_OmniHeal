local ADDON, ns = ...
local strings = {}

function ns.RegisterLocale(locale, pack)
  local current = strings[locale]
  if current then
    for key, value in pairs(pack) do current[key] = value end
  else
    strings[locale] = pack
  end
end

ns.LANGUAGES = {
  auto = "Automatic", enUS = "English", deDE = "Deutsch",
  esES = "Español (España)", esMX = "Español (Latinoamérica)", frFR = "Français", itIT = "Italiano",
  ptBR = "Português (Brasil)", ruRU = "Русский", koKR = "한국어", zhCN = "简体中文", zhTW = "繁體中文",
}
ns.LANGUAGE_ORDER = { "auto", "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }

local function ActiveLocale()
  local mode = ns.db and ns.db.language or "auto"
  if mode ~= "auto" and strings[mode] then return mode end
  local game = GetLocale()
  return strings[game] and game or "enUS"
end

function ns.L(key, ...)
  local pack = strings[ActiveLocale()] or strings.enUS
  local text = pack[key] or strings.enUS[key] or key
  if select("#", ...) > 0 then return text:format(...) end
  return text
end

function ns.ApplyLanguage()
  local L = ns.L
  ns.LANGUAGES.auto = L("language_auto")
  for _, bracket in ipairs(ns.BRACKETS) do
    ns.BRACKET_NAMES[bracket] = L("bracket_" .. bracket)
  end
  if ns.Frames then
    ns.Frames.BAR_TEXTURE_NAMES = { blizzard = L("tex_blizzard"), flat = L("tex_flat"), raid = L("tex_raid") }
  end
  if ns.Row then
    ns.Row.STYLES = { bars = L("style_bars"), cards = L("style_cards"), compact = L("style_compact"), minimal = L("style_minimal") }
    ns.Row.STYLE_DESC = L("opt_style_desc")
    ns.Row.ROLE_MARKERS = { both = L("role_both"), icon = L("role_icon"), text = L("role_text"), off = L("role_off") }
    ns.Row.AURA_ANCHORS = {
      TOPLEFT = L("anchor_topleft"), TOP = L("anchor_top"), TOPRIGHT = L("anchor_topright"),
      LEFT = L("anchor_left"), CENTER = L("anchor_center"), RIGHT = L("anchor_right"),
      BOTTOMLEFT = L("anchor_bottomleft"), BOTTOM = L("anchor_bottom"), BOTTOMRIGHT = L("anchor_bottomright"),
    }
  end
end

ns:On("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  ns.ApplyLanguage()
end)
