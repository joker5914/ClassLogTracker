-- ClassLogTracker.lua

local ADDON, ns = ...
local LibStub = _G.LibStub

-- pull in AceConfig and the Blizzard‐style options dialog
local AceConfig     = LibStub("AceConfig-3.0")
local AceConfigDlg  = LibStub("AceConfigDialog-3.0")

-- our main table
local CLT = {}
ns.ClassLogTracker = CLT

-- defaults
CLT.filterType = "party"
CLT.debug      = false
CLT.logLines   = {}

-- tiny helpers
local function mod(a,b) return a - math.floor(a/b)*b end
local function normalized(name)
  return name and name:lower():gsub("[^a-z]","") or ""
end

-- class list & colors
local classList = {
  "Warrior","Paladin","Priest","Rogue","Warlock",
  "Mage","Shaman","Druid","Hunter"
}
local classColors = {
  Warrior={1,0.78,0.55}, Paladin={0.96,0.55,0.73}, Priest={1,1,1},
  Rogue={1,0.96,0.41},   Warlock={0.58,0.51,0.79}, Mage={0.41,0.8,0.94},
  Shaman={0,0.44,0.87},  Druid={1,0.49,0.04},     Hunter={0.67,0.83,0.45},
}

-- map unit name → class token
local function GetClassByName(name)
  local n = normalized(name)
  if normalized(UnitName("player") or "")==n then
    return UnitClass("player")
  end
  for i=1,4 do
    if normalized(UnitName("party"..i))==n then
      return UnitClass("party"..i)
    end
  end
  for i=1,40 do
    if normalized(UnitName("raid"..i))==n then
      return UnitClass("raid"..i)
    end
  end
  return nil
end

-- store a log line under the right class
local function AddLogLine(msg, sender)
  local cls = GetClassByName(sender)
  if not cls then return end

  CLT.logLines[cls] = CLT.logLines[cls] or {}
  table.insert(CLT.logLines[cls], msg)
  if #CLT.logLines[cls] > 200 then
    table.remove(CLT.logLines[cls], 1)
  end

  if CLT.debug then
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cff88ff00[CLT Debug]|r ["..cls.."] "..msg
    )
  end
end

-- hook raw combat log
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", function(_, event)
  if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then return end

  local _, subEvent, _, srcGUID, srcName, _, _, dstGUID, dstName, _, _, spellId, spellName =
    CombatLogGetCurrentEventInfo()
  if not srcName then return end

  -- enforce party/raid filter
  local inUnit = (CLT.filterType=="party" and UnitInParty(srcName))
              or (CLT.filterType=="raid"  and UnitInRaid(srcName))
  if not inUnit then return end

  -- only track these
  if subEvent == "SPELL_CAST_SUCCESS"
  or subEvent:find("HEAL")
  or subEvent == "SPELL_AURA_APPLIED"
  or subEvent == "SPELL_AURA_REMOVED" then

    local msg
    if subEvent == "SPELL_CAST_SUCCESS" then
      msg = spellName.." → "..(dstName or "unknown")
    elseif subEvent:find("HEAL") then
      msg = spellName.." healed "..(dstName or "unknown")
    elseif subEvent == "SPELL_AURA_APPLIED" then
      msg = (srcName==UnitName("player") and "You gain "..spellName)
          or (spellName.." applied to "..(dstName or "unknown"))
    else  -- SPELL_AURA_REMOVED
      msg = spellName.." fades from "..(dstName or "unknown")
    end

    AddLogLine(msg, srcName)
  end
end)

-- =========================
-- AceConfig Options Table
-- =========================

local options = {
  name    = "Class Log Tracker",
  type    = "group",
  handler = CLT,
  args = {
    chatlog = {
      type = "execute",
      name = "Toggle ChatLog",
      desc = "Turn Blizzard's /chatlog on or off",
      func = function() SlashCmdList["CHATLOG"]("") end,
      order = 1,
    },
    filter = {
      type = "select",
      name = "Filter Type",
      desc = "Show only party- or raid-member logs",
      values = { party = "Party", raid = "Raid" },
      get = function() return CLT.filterType end,
      set = function(_, v) CLT.filterType = v end,
      order = 2,
    },
    debug = {
      type = "toggle",
      name = "Enable Debug",
      desc = "Print each captured entry to chat",
      get = function() return CLT.debug end,
      set = function(_, v) CLT.debug = v end,
      order = 3,
    },
    clear = {
      type = "execute",
      name = "Clear Logs",
      desc = "Erase all stored log entries",
      func = function() CLT.logLines = {} end,
      order = 4,
    },
  },
}

AceConfig:RegisterOptionsTable("ClassLogTracker", options)
AceConfigDlg:AddToBlizOptions("ClassLogTracker", "Class Log Tracker")

-- slash to open the config panel
SLASH_CLASSLOG1 = "/classlog"
SlashCmdList["CLASSLOG"] = function()
  AceConfigDlg:Open("ClassLogTracker")
end
