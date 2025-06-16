-- RaidRecon.lua

local LAM = LibStub("LibAddonMenu-2.0")

-- main table
RaidRecon = {}
local RR = RaidRecon

-- state
RR.frame         = nil
RR.textFrame     = nil
RR.selectedClass = nil
RR.logLines      = {}
RR.filterType    = "party"
RR.debug         = false

-- helpers
local function mod(a,b) return a - math.floor(a/b)*b end
local function normalized(name)
  if not name then return "" end
  return name:lower():gsub("[^%a]","")
end

-- class data
local classList = {
  "Warrior","Paladin","Priest","Rogue","Warlock",
  "Mage","Shaman","Druid","Hunter"
}
local classColors = {
  Warrior={1,0.78,0.55}, Paladin={0.96,0.55,0.73}, Priest={1,1,1},
  Rogue={1,0.96,0.41},   Warlock={0.58,0.51,0.79}, Mage={0.41,0.8,0.94},
  Shaman={0,0.44,0.87},  Druid={1,0.49,0.04},     Hunter={0.67,0.83,0.45},
}

-- map name → class
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
  return nil
end

-- store a log line
local function AddLogLine(msg, sender)
  local cls = GetClassByName(sender)
  if not cls then return end

  RR.logLines[cls] = RR.logLines[cls] or {}
  table.insert(RR.logLines[cls], msg)
  if #RR.logLines[cls] > 200 then
    table.remove(RR.logLines[cls], 1)
  end

  if RR.debug then
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cff88ff00[RaidRecon Debug]|r ["..cls.."] "..msg
    )
  end

  if cls == RR.selectedClass then
    RR:UpdateLogText()
  end
end

-- redraw output
function RR:UpdateLogText()
  if not self.textFrame then return end
  local buf = self.selectedClass and self.logLines[self.selectedClass]
  if not buf or #buf == 0 then
    self.textFrame:SetText("No data for "..(self.selectedClass or "none"))
  else
    self.textFrame:SetText(table.concat(buf, "\n"))
  end
end

-- toggle party/raid
function RR:ToggleFilterType(btn)
  self.filterType = (self.filterType == "party") and "raid" or "party"
  if btn then btn:SetText("Filter: "..self.filterType) end
  if self.frame then
    self.frame.titleText:SetText("Filter: "..self.filterType)
  end
end

-- build UI
function RR:CreateUI()
  if self.frame then self.frame:Show() return end

  self.logLines = {}

  local f = CreateFrame("Frame","RRFrame",UIParent,"UIPanelDialogTemplate")
  f:SetSize(600,500)
  f:SetPoint("CENTER")
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  f.titleText = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  f.titleText:SetPoint("TOP",f,"TOP",0,-12)
  f.titleText:SetText("Filter: "..self.filterType)

  -- ChatLog button
  local cb = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
  cb:SetSize(100,24); cb:SetPoint("TOPLEFT",f,16,-40)
  cb:SetText("ChatLog")
  cb:SetScript("OnClick",function() SlashCmdList["CHATLOG"]("") end)

  -- Filter button
  local fb = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
  fb:SetSize(100,24); fb:SetPoint("LEFT",cb,"RIGHT",8,0)
  fb:SetText("Filter: "..self.filterType)
  fb:SetScript("OnClick",function() RR:ToggleFilterType(fb) end)
  self.filterButton = fb

  -- class buttons
  local perRow,sx,sy = 6,90,28
  local ox,oy       = 16,-80
  for i,cls in ipairs(classList) do
    local btn = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    btn:SetSize(80,24)
    local row,col = math.floor((i-1)/perRow), mod(i-1,perRow)
    btn:SetPoint("TOPLEFT",f,ox+col*sx,oy-row*sy)
    btn:SetText(cls)
    local r,g,b = unpack(classColors[cls])
    btn:GetFontString():SetTextColor(r,g,b)
    btn:SetScript("OnClick",function()
      RR.selectedClass = cls; RR:UpdateLogText()
    end)
  end

  -- scroll area
  local scroll = CreateFrame("ScrollFrame","RRScroll",f,"UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT",f,16,-250)
  scroll:SetPoint("BOTTOMRIGHT",f,-32,16)
  local edit = CreateFrame("EditBox",nil,scroll)
  edit:SetMultiLine(true); edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(540); edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed",edit.ClearFocus)
  scroll:SetScrollChild(edit)
  self.textFrame = edit

  self.frame = f
end

-- combat log hook
local ev = CreateFrame("Frame")
ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ev:SetScript("OnEvent",function(_,_,...)
  local _,se,_,_,srcName,,,,,dstName = CombatLogGetCurrentEventInfo()
  if not srcName then return end

  local inGroup = (RR.filterType=="party" and (srcName==UnitName("player") or UnitInParty(srcName)))
               or (RR.filterType=="raid"  and (srcName==UnitName("player") or UnitInRaid(srcName)))
  if not inGroup then return end

  if se~="SPELL_CAST_SUCCESS" and not se:find("HEAL")
     and se~="SPELL_AURA_APPLIED" and se~="SPELL_AURA_REMOVED" then
    return
  end

  local _,_,_,_,_,_,_,_,_,_,_,_,sp = CombatLogGetCurrentEventInfo()
  local msg
  if se=="SPELL_CAST_SUCCESS" then
    msg = sp.." → "..(dstName or "unknown")
  elseif se:find("HEAL") then
    msg = sp.." healed "..(dstName or "unknown")
  elseif se=="SPELL_AURA_APPLIED" then
    msg = (srcName==UnitName("player") and "You gain "..sp)
        or (sp.." applied to "..(dstName or "unknown"))
  else -- REMOVED
    msg = sp.." fades from "..(dstName or "unknown")
  end

  AddLogLine(msg,srcName)
end)

-- LAM2 panel
local panel = {
  type               = "panel",
  name               = "RaidRecon",
  displayName        = "RaidRecon",
  author             = "Coldsnappy",
  version            = "GIT",
  registerForRefresh = true,
  registerForDefaults= true,
}
LAM:RegisterAddonPanel("RRPanel", panel)

local options = {
  {
    type = "button",
    name = "Toggle ChatLog",
    func = function() SlashCmdList["CHATLOG"]("") end,
  },
  {
    type    = "dropdown",
    name    = "Filter Type",
    choices = { party="Party", raid="Raid" },
    getFunc = function() return RR.filterType end,
    setFunc = function(v)
      RR.filterType = v
      if RR.filterButton then RR.filterButton:SetText("Filter: "..v) end
    end,
  },
  {
    type    = "toggle",
    name    = "Debug Messages",
    getFunc = function() return RR.debug end,
    setFunc = function(v) RR.debug = v end,
  },
  {
    type = "execute",
    name = "Clear Logs",
    func = function() RR.logLines = {} end,
  },
}
LAM:RegisterOptionControls("RRPanel", options)

-- slash to open window
SLASH_RAIDRECON1 = "/raidrecon"
SlashCmdList["RAIDRECON"] = function() RR:CreateUI() end

-- load message
DEFAULT_CHAT_FRAME:AddMessage("|cffe5b3e5RaidRecon Loaded. Type /raidrecon to open.|r")
