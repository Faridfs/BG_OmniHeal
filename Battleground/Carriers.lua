local _, ns = ...
local Carriers = ns:NewModule("Carriers")
local Roster = ns.Roster

-- Battleground system messages are localized by the game client. Keep the
-- internal carrier tags stable so pickup and drop messages use the same key.
local PICKUP = {
  -- enUS
  "picked up", "has taken", "have taken",
  -- ruRU
  "поднял", "Поднял", "подняла", "Подняла", "подняли", "Подняли",
  "взял", "Взял", "взяла", "Взяла", "взяли", "Взяли",
  "подобрал", "Подобрал", "подобрала", "Подобрала", "подобрали", "Подобрали",
  "забрал", "Забрал", "забрала", "Забрала", "забрали", "Забрали",
  -- zhCN / zhTW
  "拾起", "拾取", "拿起", "捡起", "撿起", "取走", "拿到", "拿到了", "获得", "獲得",
  "抢走", "搶走", "夺走", "奪走",
}
local DROP = {
  -- enUS
  "dropped", "captured", "returned", "has been reset",
  -- ruRU
  "уронил", "Уронил", "уронила", "Уронила", "уронили", "Уронили",
  "выронил", "Выронил", "выронила", "Выронила", "выронили", "Выронили",
  "выбросил", "Выбросил", "выбросила", "Выбросила", "выбросили", "Выбросили",
  "сбросил", "Сбросил", "сбросила", "Сбросила", "сбросили", "Сбросили",
  "потерял", "Потерял", "потеряла", "Потеряла", "потеряли", "Потеряли",
  "вернул", "Вернул", "вернула", "Вернула", "вернули", "Вернули",
  "возвращен", "Возвращен", "возвращена", "Возвращена", "возвращено", "Возвращено",
  "захватил", "Захватил", "захватила", "Захватила", "захватили", "Захватили",
  -- zhCN / zhTW
  "掉落", "丢下", "丟下", "丢弃", "丟棄", "放下", "归还", "歸還",
  "交还", "交還", "返回", "重置", "夺回", "奪回", "夺取", "奪取", "夺得", "奪得",
  "丢失", "丟失", "失去",
}
local TAGS = {
  { tag = "Alliance", words = {
    "Alliance", "альянс", "Альянс", "альянса", "Альянса", "альянсу", "Альянсу",
    "альянсом", "Альянсом", "альянсе", "Альянсе", "联盟", "聯盟",
    "Silverwing", "серебряного крыла", "Серебряного Крыла", "серебряное крыло", "Серебряное Крыло",
    "银翼军旗", "銀翼軍旗",
  } },
  { tag = "Horde", words = {
    "Horde", "орда", "Орда", "орды", "Орды", "орде", "Орде", "ордой", "Ордой", "部落",
    "Warsong", "песни войны", "Песни Войны", "战歌军旗", "戰歌軍旗",
  } },
  { tag = "Blue", words = {
    "Blue", "синий", "Синий", "синего", "Синего", "синяя", "Синяя", "синюю", "Синюю",
    "синее", "Синее", "синие", "Синие", "синей", "Синей", "синих", "Синих", "蓝色", "藍色",
  } },
  { tag = "Purple", words = {
    "Purple", "фиолетовый", "Фиолетовый", "фиолетовая", "Фиолетовая", "фиолетовое", "Фиолетовое",
    "фиолетового", "Фиолетового", "фиолетовой", "Фиолетовой", "фиолетовую", "Фиолетовую",
    "фиолетовые", "Фиолетовые", "紫色",
  } },
  { tag = "Green", words = {
    "Green", "зелёный", "Зелёный", "зеленый", "Зеленый", "зелёная", "Зелёная", "зеленая", "Зеленая",
    "зелёное", "Зелёное", "зеленое", "Зеленое", "зелёного", "Зелёного", "зеленого", "Зеленого",
    "зелёной", "Зелёной", "зеленой", "Зеленой", "绿色", "綠色",
  } },
  { tag = "Orange", words = {
    "Orange", "оранжевый", "Оранжевый", "оранжевая", "Оранжевая", "оранжевое", "Оранжевое",
    "оранжевого", "Оранжевого", "оранжевой", "Оранжевой", "оранжевую", "Оранжевую", "橙色", "橘色",
  } },
}
local OBJECT_WORDS = {
  "flag", "orb", "orbs", "флаг", "Флаг", "знамя", "Знамя", "сфера", "Сфера", "сферы", "шар", "Шар",
  "旗", "旗帜", "旗幟", "军旗", "軍旗", "战旗", "戰旗", "宝珠", "寶珠",
}

local function HasAny(msg, words, lowerMsg)
  lowerMsg = lowerMsg or msg:lower()
  for i = 1, #words do
    local word = words[i]
    if msg:find(word, 1, true) or lowerMsg:find(word:lower(), 1, true) then
      return true
    end
  end
  return false
end

local function FindTag(msg, lowerMsg)
  lowerMsg = lowerMsg or msg:lower()
  for i = 1, #TAGS do
    local aliases = TAGS[i].words
    for j = 1, #aliases do
      local word = aliases[j]
      if msg:find(word, 1, true) or lowerMsg:find(word:lower(), 1, true) then
        return TAGS[i].tag
      end
    end
  end
  return "Flag"
end

-- A qualified name is authoritative. A bare name is usable only when it identifies
-- one roster entry. Requiring complete names also avoids matching Bob inside Bobby.
local locale = GetLocale and GetLocale()
local chinese = locale == "zhCN" or locale == "zhTW"
local PUNCTUATION = { "«", "»", "“", "”", "‘", "’", "—", "–", "，", "。", "！", "：", "、", "【", "】", "（", "）" }
local CHINESE_WORDS = { "被", "由", "把", "將", "将", "已經", "已经", "已", "了", "的", "玩家" }

local function IsAdjacent(message, edge, before, words)
  for _, word in ipairs(words) do
    local first = before and edge - #word + 1 or edge
    if first >= 1 and message:sub(first, first + #word - 1) == word then return true end
  end
  return false
end

local function IsBoundary(message, edge, before)
  local byte = message:byte(edge)
  if not byte then return true end
  if byte < 128 then return not message:sub(edge, edge):find("[%w_'%-]") end
  if IsAdjacent(message, edge, before, PUNCTUATION) then return true end
  -- Chinese announcements can put the name directly next to a pickup or drop verb.
  return chinese and (IsAdjacent(message, edge, before, CHINESE_WORDS)
    or IsAdjacent(message, edge, before, PICKUP) or IsAdjacent(message, edge, before, DROP))
end

local function MatchRealm(message, last, realm)
  -- The UI may write Area 52 in prose and Area52 in the roster key.
  for i = 1, #realm do
    if i > 1 then
      while message:byte(last + 1) == 32 do last = last + 1 end
    end
    last = last + 1
    if message:byte(last) ~= realm:byte(i) then return nil end
  end
  return last
end

local function ContainsName(message, name)
  local stem, realm = name:match("^([^-]+%-)(.+)$")
  local from = 1
  while true do
    local first, last = message:find(stem or name, from, true)
    if not first then return false end
    from = last + 1
    if IsBoundary(message, first - 1, true) then
      if realm then last = MatchRealm(message, last, realm) end
      if last and IsBoundary(message, last + 1, false) then return true end
    end
  end
end

local function MatchIndex(message, index)
  local match
  for name, rec in pairs(index) do
    if ContainsName(message, name) then
      if match or not rec then return nil, true end
      match = rec
    end
  end
  return match, match ~= nil
end

local function FindPlayer(msg)
  local linkedName = msg:match("|Hplayer:([^:|]+)")
  if linkedName then return Roster:ResolveName(linkedName) end
  msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local rec, found = MatchIndex(msg, Roster.byKey)
  if found then return rec end
  return MatchIndex(msg, Roster.byShortName)
end

local function SetCarrier(rec, tag)
  if rec.carrier ~= tag then
    rec.carrier = tag
    ns.Frames:UpdateDynamic(rec)
  end
end

local function ClearTag(tag)
  for _, rec in pairs(Roster.byKey) do
    if rec.carrier == tag then
      SetCarrier(rec, nil)
    end
  end
end

local function OnMessage(_, msg)
  if ns.state ~= "bg" then
    return
  end
  ns.lastBGMessageSecret = ns.IsSecret(msg)
  if ns.lastBGMessageSecret or type(msg) ~= "string" then
    return
  end

  local lowerMsg = msg:lower()
  local rec = FindPlayer(msg)
  local tag = FindTag(msg, lowerMsg)
  if HasAny(msg, PICKUP, lowerMsg) then
    ClearTag(tag)
    if rec then SetCarrier(rec, tag) end
  elseif HasAny(msg, DROP, lowerMsg) then
    if rec and rec.carrier then
      SetCarrier(rec, nil)
    else
      ClearTag(tag)
      -- A team announcement may name its faction while referring to a neutral flag.
      if tag ~= "Flag" and HasAny(msg, OBJECT_WORDS, lowerMsg) then
        ClearTag("Flag")
      end
    end
  end
end

ns:OnActive("CHAT_MSG_BG_SYSTEM_ALLIANCE", OnMessage)
ns:OnActive("CHAT_MSG_BG_SYSTEM_HORDE", OnMessage)
ns:OnActive("CHAT_MSG_BG_SYSTEM_NEUTRAL", OnMessage)
