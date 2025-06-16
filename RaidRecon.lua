-- RaidRecon.lua

local LibStub        = _G.LibStub
local AceAddon       = LibStub:GetLibrary("AceAddon-3.0")
local AceConsole     = LibStub:GetLibrary("AceConsole-3.0")
local AceEvent       = LibStub:GetLibrary("AceEvent-3.0")
local AceGUI         = LibStub:GetLibrary("AceGUI-3.0")
local AceConfig      = LibStub:GetLibrary("AceConfig-3.0")
local AceConfigDialog= LibStub:GetLibrary("AceConfigDialog-3.0")

-- Create the addon
local RaidRecon = AceAddon:NewAddon("RaidRecon", "AceConsole-3.0", "AceEvent-3.0")
local RR = RaidRecon

-- State
RR.filterType    = "party"
RR.debug         = false
RR.logLines      = {}
RR.selectedClass = nil

-- Helpers
local function mod(a,b) return a - math.floor(a/b)*b end
local function normalized(name)
  if not name then return "" end
  return name:lower():gsub("[^%a]","")
end

local classList = {
  "Warrior","Paladin","Priest","Rogue","Warlock",
  "Mage","Shaman","Druid","Hunter"
}
local classColors = {
  Warrior={1,0.78,0.55}, Paladin={0.96,0.55,0.73}, Priest={1,1,1},
  Rogue={1,0.96,0.41},   Warlock={0.58,0.51,0.79}, Mage={0.41,0.8,0.94},
  Shaman={0,0.44,0.87},  Druid={1,0.49,0.04},     Hunter={0.67,0.83,0.45},
}

local function GetClassByName(name)
  local n = normalized(name)
  if normalized(UnitName("player") or "") == n then
    return UnitClass("player")
  end
  for i=1,4 do
    if normalized(UnitName("party"..i)) == n then
      return UnitClass("party"..i)
    end
  end
  for i=1,40 do
    if normalized(UnitName("raid"..i)) == n then
      return UnitClass("raid"..i)
    end
  end
end

local function AddLogLine(msg, sender)
  local cls = GetClassByName(sender)
  if not cls then return end
  RR.logLines[cls] = RR.logLines[cls] or {}
  table.insert(RR.logLines[cls], msg)
  if #RR.logLines[cls] > 200 then table.remove(RR.logLines[cls], 1) end
  if RR.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ff00[RaidRecon]|r ["..cls.."] "..msg)
  end
  if cls == RR.selectedClass then
    RR:UpdateLogText()
  end
end

function RR:UpdateLogText()
  if not self.textFrame then return end
  local buf = self.selectedClass and self.logLines[self.selectedClass]
  if not buf or #buf == 0 then
    self.textFrame:SetText("No data for "..(self.selectedClass or "none"))
  else
    self.textFrame:SetText(table.concat(buf, "\n"))
  end
end

function RR:ToggleFilterType()
  self.filterType = (self.filterType=="party") and "raid" or "party"
end

function RR:CreateUI()
  if self.frame then
    self.frame:Show()
    return
  end
  -- clear past logs
  self.logLines = {}

  -- Main window
  local f = AceGUI:Create("Frame")
  f:SetTitle("RaidRecon")
  f:SetStatusText("Filter: "..self.filterType)
  f:SetLayout("Flow")
  f:SetCallback("OnClose", function(widget) widget:Hide() end)
  f:SetWidth(600)
  f:SetHeight(500)
  self.frame = f

  -- ChatLog toggle
  local chatBtn = AceGUI:Create("Button")
  chatBtn:SetText("ChatLog")
  chatBtn:SetWidth(120)
  chatBtn:SetCallback("OnClick", function() SlashCmdList["CHATLOG"]("") end)
  f:AddChild(chatBtn)

  -- Filter toggle
  local filterBtn = AceGUI:Create("Button")
  filterBtn:SetText("Filter: "..self.filterType)
  filterBtn:SetWidth(120)
  filterBtn:SetCallback("OnClick", function()
    RR:ToggleFilterType()
    filterBtn:SetText("Filter: "..RR.filterType)
    f:SetStatusText("Filter: "..RR.filterType)
  end)
  f:AddChild(filterBtn)

  -- Spacer
  f:AddChild(AceGUI:Create("Label")).SetFullWidth(true)

  -- Class buttons
  local grp = AceGUI:Create("SimpleGroup")
  grp:SetFullWidth(true); grp:SetLayout("Flow")
  for _,cls in ipairs(classList) do
    local btn = AceGUI:Create("Button")
    btn:SetText(cls); btn:SetWidth(80)
    local r,g,b = unpack(classColors[cls])
    btn:SetColor(r,g,b)
    btn:SetCallback("OnClick", function()
      RR.selectedClass = cls
      RR:UpdateLogText()
    end)
    grp:AddChild(btn)
  end
  f:AddChild(grp)

  -- Spacer
  f:AddChild(AceGUI:Create("Label")).SetFullWidth(true)

  -- Output area
  local scroll = AceGUI:Create("ScrollFrame")
  scroll:SetLayout("Fill")
  scroll:SetFullWidth(true)
  scroll:SetFullHeight(true)

  local edit = AceGUI:Create("MultiLineEditBox")
  edit:DisableButton(true)
  edit:SetFullWidth(true)
  edit:SetFullHeight(true)
  edit:SetText("No data yet...")
  scroll:AddChild(edit)
  f:AddChild(scroll)
  self.textFrame = edit
end

function RR:OnCombatLog()
  local _,subEvent,_,_,srcName,_,_,_,dstName = CombatLogGetCurrentEventInfo()
  if not srcName then return end
  -- Filter party/raid
  local inGroup = (self.filterType=="party" and (srcName==UnitName("player") or UnitInParty(srcName)))
               or (self.filterType=="raid"  and (srcName==UnitName("player") or UnitInRaid(srcName)))
  if not inGroup then return end
  -- Only specific events
  if subEvent ~= "SPELL_CAST_SUCCESS"
     and not subEvent:find("HEAL")
     and subEvent ~= "SPELL_AURA_APPLIED"
     and subEvent ~= "SPELL_AURA_REMOVED" then
    return
  end
  -- Build message
  local _,_,_,_,_,_,_,_,_,_,_,_,spellName = CombatLogGetCurrentEventInfo()
  local msg
  if subEvent=="SPELL_CAST_SUCCESS" then
    msg = spellName.." → "..(dstName or "unknown")
  elseif subEvent:find("HEAL") then
    msg = spellName.." healed "..(dstName or "unknown")
  elseif subEvent=="SPELL_AURA_APPLIED" then
    msg = (srcName==UnitName("player") and "You gain "..spellName)
        or (spellName.." applied to "..(dstName or "unknown"))
  else
    msg = spellName.." fades from "..(dstName or "unknown")
  end
  AddLogLine(msg, srcName)
end

function RR:OnEnable()
  self:RegisterChatCommand("raidrecon", "CreateUI")
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLog")
end

-- Configuration
local options = {
  name    = "RaidRecon",
  type    = "group",
  handler = RR,
  args    = {
    chatlog = {
      type = "execute",
      name = "Toggle ChatLog",
      func = function() SlashCmdList["CHATLOG"]("") end,
      order = 1,
    },
    filter = {
      type = "select",
      name = "Filter Type",
      values = { party="Party", raid="Raid" },
      get  = function() return RR.filterType end,
      set  = function(_,v) RR.filterType=v end,
      order = 2,
    },
    debug = {
      type = "toggle",
      name = "Debug Messages",
      get  = function() return RR.debug end,
      set  = function(_,v) RR.debug=v end,
      order = 3,
    },
    clear = {
      type = "execute",
      name = "Clear Logs",
      func = function() RR.logLines = {} end,
      order = 4,
    },
  },
}

AceConfig:RegisterOptionsTable("RaidRecon", options)
AceConfigDialog:AddToBlizOptions("RaidRecon", "RaidRecon")
