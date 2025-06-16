-- RaidRecon.lua

local LibStub        = _G.LibStub
local AceAddon       = LibStub:GetLibrary("AceAddon-3.0")
local AceConsole     = LibStub:GetLibrary("AceConsole-3.0")
local AceEvent       = LibStub:GetLibrary("AceEvent-3.0")
local AceGUI         = LibStub:GetLibrary("AceGUI-3.0")
local AceConfig      = LibStub:GetLibrary("AceConfig-3.0")
local AceConfigDialog= LibStub:GetLibrary("AceConfigDialog-3.0")

-- create addon
local RaidRecon = AceAddon:NewAddon("RaidRecon","AceConsole-3.0","AceEvent-3.0")
local RR = RaidRecon

-- state
RR.filterType    = "party"
RR.debug         = false
RR.logLines      = {}
RR.selectedClass = nil

-- helpers
local function mod(a,b) return a - math.floor(a/b)*b end
local function normalized(s) return (s or ""):lower():gsub("[^%a]","") end

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
  if normalized(UnitName("player"))==n then return UnitClass("player") end
  for i=1,4 do
    if normalized(UnitName("party"..i))==n then return UnitClass("party"..i) end
  end
  for i=1,40 do
    if normalized(UnitName("raid"..i))==n then return UnitClass("raid"..i) end
  end
  return nil
end

local function AddLogLine(msg,sender)
  local cls = GetClassByName(sender)
  if not cls then return end

  RR.logLines[cls] = RR.logLines[cls] or {}
  table.insert(RR.logLines[cls], msg)
  if table.getn(RR.logLines[cls]) > 200 then
    table.remove(RR.logLines[cls], 1)
  end

  if RR.debug then
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cff00ced1[RaidRecon]|r ["..cls.."] "..msg
    )
  end

  if cls == RR.selectedClass then
    RR:UpdateLogText()
  end
end

function RR:UpdateLogText()
  if not self.textFrame then return end
  local buf = self.selectedClass and self.logLines[self.selectedClass]
  if not buf or table.getn(buf) == 0 then
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
  self.logLines = {}

  local f = AceGUI:Create("Frame")
  f:SetTitle("|cff00ced1[CS]|r |cffffffffRaidRecon|r")
  f:SetStatusText("Filter: "..self.filterType)
  f:SetLayout("Flow")
  f:SetCallback("OnClose",function(w) w:Hide() end)
  f:SetWidth(600); f:SetHeight(500)
  self.frame = f

  -- ChatLog toggle
  local cb = AceGUI:Create("Button")
  cb:SetText("ChatLog"); cb:SetWidth(100)
  cb:SetCallback("OnClick",function() SlashCmdList["CHATLOG"]("") end)
  f:AddChild(cb)

  -- Filter toggle
  local fb = AceGUI:Create("Button")
  fb:SetText("Filter: "..self.filterType); fb:SetWidth(100)
  fb:SetCallback("OnClick",function()
    RR:ToggleFilterType()
    fb:SetText("Filter: "..RR.filterType)
    f:SetStatusText("Filter: "..RR.filterType)
  end)
  f:AddChild(fb)

  -- spacer
  local sp = AceGUI:Create("Label")
  sp:SetText(" "); sp:SetFullWidth(true)
  f:AddChild(sp)

  -- class buttons
  local grp = AceGUI:Create("SimpleGroup")
  grp:SetLayout("Flow"); grp:SetFullWidth(true)
  for _,cls in ipairs(classList) do
    local b = AceGUI:Create("Button")
    b:SetText(cls); b:SetWidth(80)
    local r,g,bcol = unpack(classColors[cls])
    b:SetColor(r,g,bcol)
    b:SetCallback("OnClick",function()
      RR.selectedClass = cls
      RR:UpdateLogText()
    end)
    grp:AddChild(b)
  end
  f:AddChild(grp)

  -- spacer
  local sp2 = AceGUI:Create("Label")
  sp2:SetText(" "); sp2:SetFullWidth(true)
  f:AddChild(sp2)

  -- output scroll
  local scr = AceGUI:Create("ScrollFrame")
  scr:SetLayout("Fill"); scr:SetFullWidth(true); scr:SetFullHeight(true)
  local ed = AceGUI:Create("MultiLineEditBox")
  ed:DisableButton(true); ed:SetFullWidth(true); ed:SetFullHeight(true)
  ed:SetText("No data yet...")
  scr:AddChild(ed)
  f:AddChild(scr)
  self.textFrame = ed
end

function RR:OnCombatLog()
  local _,se,_,_,src,_,_,_,dst = CombatLogGetCurrentEventInfo()
  if not src then return end

  local inGroup =
    (self.filterType=="party" and (src==UnitName("player") or UnitInParty(src))) or
    (self.filterType=="raid"  and (src==UnitName("player") or UnitInRaid(src)))
  if not inGroup then return end

  if se~="SPELL_CAST_SUCCESS"
     and not se:find("HEAL")
     and se~="SPELL_AURA_APPLIED"
     and se~="SPELL_AURA_REMOVED" then
    return
  end

  local _,_,_,_,_,_,_,_,_,_,_,_,sp =
    CombatLogGetCurrentEventInfo()
  local msg
  if se=="SPELL_CAST_SUCCESS" then
    msg = sp.." → "..(dst or "unknown")
  elseif se:find("HEAL") then
    msg = sp.." healed "..(dst or "unknown")
  elseif se=="SPELL_AURA_APPLIED" then
    msg = (src==UnitName("player") and "You gain "..sp)
        or (sp.." applied to "..(dst or "unknown"))
  else
    msg = sp.." fades from "..(dst or "unknown")
  end

  AddLogLine(msg, src)
end

function RR:OnEnable()
  self:RegisterChatCommand("raidrecon","CreateUI")
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED","OnCombatLog")
end

-- AceConfig options
local opts = {
  name    = "RaidRecon",
  handler = RR,
  type    = "group",
  args    = {
    chatlog = {
      type="execute", name="Toggle ChatLog",
      func=function() SlashCmdList["CHATLOG"]("") end,
      order=1
    },
    filter = {
      type="select", name="Filter Type",
      values={ party="Party", raid="Raid" },
      get=function() return RR.filterType end,
      set=function(_,v) RR.filterType=v end,
      order=2
    },
    debug = {
      type="toggle", name="Debug Messages",
      get=function() return RR.debug end,
      set=function(_,v) RR.debug=v end,
      order=3
    },
    clear = {
      type="execute", name="Clear Logs",
      func=function() RR.logLines = {} end,
      order=4
    },
  },
}

AceConfig:RegisterOptionsTable("RaidRecon", opts)
AceConfigDialog:AddToBlizOptions("RaidRecon", "RaidRecon")
