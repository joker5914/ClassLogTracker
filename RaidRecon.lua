-- RaidRecon.lua

RaidRecon = {}
local RR = RaidRecon

-- state
RR.filterType    = "party"
RR.selectedClass = nil
RR.logLines      = {}
RR.debug         = false  -- set true to print every line to chat

-- helpers
local function mod(a,b)      return a - math.floor(a/b)*b end
local function normalized(s) return (s or ""):lower():gsub("[^%a]","") end

-- class list & colors
local classList = {
  "Warrior","Paladin","Priest","Rogue","Warlock",
  "Mage","Shaman","Druid","Hunter",
}
local classColors = {
  Warrior={1,0.78,0.55}, Paladin={0.96,0.55,0.73}, Priest={1,1,1},
  Rogue={1,0.96,0.41},   Warlock={0.58,0.51,0.79}, Mage={0.41,0.8,0.94},
  Shaman={0,0.44,0.87},  Druid={1,0.49,0.04},     Hunter={0.67,0.83,0.45},
}

-- find a unit’s class by name
local function GetClassByName(name)
  local n = normalized(name)
  if normalized(UnitName("player")) == n then
    return select(2,UnitClass("player"))
  end
  for i=1,4 do
    if normalized(UnitName("party"..i)) == n then
      return select(2,UnitClass("party"..i))
    end
  end
  for i=1,40 do
    if normalized(UnitName("raid"..i)) == n then
      return select(2,UnitClass("raid"..i))
    end
  end
  return nil
end

-- record a line under the sender’s class
local function AddLogLine(msg, sender)
  local cls = GetClassByName(sender)
  if not cls then return end

  local buf = RR.logLines[cls] or {}
  table.insert(buf, msg)
  if table.getn(buf) > 200 then
    table.remove(buf,1)
  end
  RR.logLines[cls] = buf

  if RR.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ced1[RaidRecon]|r ["..cls.."] "..msg)
  end

  if cls == RR.selectedClass then
    RR:UpdateLogText()
  end
end

-- redraw the EditBox
function RR:UpdateLogText()
  if not self.text then return end
  local cls = self.selectedClass
  if not cls then
    self.text:SetText("No class selected")
    return
  end
  local buf = self.logLines[cls] or {}
  if table.getn(buf)==0 then
    self.text:SetText("No data for "..cls.."s")
  else
    self.text:SetText(table.concat(buf, "\n"))
  end
end

-- toggle party/raid filter
function RR:ToggleFilterType(btn)
  self.filterType = (self.filterType=="party") and "raid" or "party"
  btn:SetText("Filter: "..self.filterType)
  if self.frame then
    self.frame.title:SetText("Filter: "..self.filterType)
  end
end

-- build (or show) the UI
function RR:CreateUI()
  if self.frame then
    self.frame:Show()
    return
  end
  self.logLines = {}

  local f = CreateFrame("Frame","RRFrame",UIParent)
  f:SetSize(600,500)
  f:SetPoint("CENTER")
  f:SetBackdrop{
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize=16, edgeSize=16,
    insets   = {4,4,4,4},
  }
  f:SetBackdropColor(0,0,0,0.9)
  f:EnableMouse(true); f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop",  f.StopMovingOrSizing)
  RR.frame = f

  -- close button
  local close = CreateFrame("Button",nil,f,"UIPanelCloseButton")
  close:SetPoint("TOPRIGHT",f,-6,-6)
  close:SetScript("OnClick",function() f:Hide() end)

  -- title
  f.title = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  f.title:SetPoint("TOP",f,"TOP",0,-12)
  f.title:SetText("Filter: "..self.filterType)

  -- CombatLog toggle (writes to Logs/CombatLog.txt)
  local cb = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
  cb:SetSize(100,24)
  cb:SetPoint("TOPLEFT",f,16,-40)
  cb:SetText("CombatLog")
  cb:SetScript("OnClick",function() SlashCmdList["COMBATLOG"]("") end)

  -- Filter toggle
  local fb = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
  fb:SetSize(100,24)
  fb:SetPoint("LEFT",cb,"RIGHT",8,0)
  fb:SetText("Filter: "..self.filterType)
  fb:SetScript("OnClick",function() RR:ToggleFilterType(fb) end)
  RR.filterButton = fb

  -- class buttons
  local perRow,sx,sy,ox,oy = 6,90,28,16,-80
  for i,cls in ipairs(classList) do
    local btn = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    btn:SetSize(80,24)
    local row = math.floor((i-1)/perRow)
    local col = mod(i-1,perRow)
    btn:SetPoint("TOPLEFT",f,ox+col*sx,oy-row*sy)
    btn:SetText(cls)
    local r,g,b = unpack(classColors[cls])
    btn:GetFontString():SetTextColor(r,g,b)
    btn:SetScript("OnClick",function()
      RR.selectedClass = cls
      RR:UpdateLogText()
    end)
  end

  -- scrollable EditBox
  local scroll = CreateFrame("ScrollFrame","RRScroll",f,"UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT",f,16,-250)
  scroll:SetPoint("BOTTOMRIGHT",f,-32,16)
  local edit = CreateFrame("EditBox",nil,scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(ChatFontNormal)
  edit:SetSize(540,230)
  edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
  scroll:SetScrollChild(edit)
  RR.text = edit

  -- default to first class
  RR.selectedClass = classList[1]
  RR:UpdateLogText()
end

-- COMBAT_LOG_EVENT_UNFILTERED handler (damage & buff/aura)
local logFrame = CreateFrame("Frame")
logFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
logFrame:SetScript("OnEvent", function()
  local timestamp, subEvent,
        _, srcGUID, sourceName,
        _, _, dstGUID, destName = CombatLogGetCurrentEventInfo()

  if not sourceName then return end

  -- party/raid filter
  local inG = (RR.filterType=="party" and (sourceName==UnitName("player") or UnitInParty(sourceName)))
          or (RR.filterType=="raid"  and (sourceName==UnitName("player") or UnitInRaid(sourceName)))
  if not inG then return end

  local msg, spellName, amount

  if subEvent=="SPELL_CAST_START" then
    spellName = select(13, CombatLogGetCurrentEventInfo())
    msg = "begins to cast "..spellName

  elseif subEvent=="SPELL_CAST_SUCCESS" then
    spellName = select(13, CombatLogGetCurrentEventInfo())
    msg = spellName.." → "..(destName or "unknown")

  elseif subEvent:find("HEAL") then
    spellName,amount = select(13, CombatLogGetCurrentEventInfo())
    msg = spellName.." healed "..(destName or "unknown").." for "..amount

  elseif subEvent=="SPELL_AURA_APPLIED" then
    spellName = select(13, CombatLogGetCurrentEventInfo())
    msg = (sourceName==UnitName("player") and "You gain "..spellName)
        or (spellName.." applied to "..(destName or "unknown"))

  elseif subEvent=="SPELL_AURA_REMOVED" then
    spellName = select(13, CombatLogGetCurrentEventInfo())
    msg = spellName.." fades from "..(destName or "unknown")

  elseif subEvent=="SWING_DAMAGE" then
    amount = select(12, CombatLogGetCurrentEventInfo())
    msg = "Auto-attack hits "..(destName or "unknown").." for "..amount

  elseif subEvent=="SPELL_DAMAGE" or subEvent=="RANGE_DAMAGE" then
    spellName,amount = select(13, CombatLogGetCurrentEventInfo())
    msg = spellName.." hits "..(destName or "unknown").." for "..amount

  elseif subEvent=="SPELL_PERIODIC_DAMAGE" then
    spellName,amount = select(13, CombatLogGetCurrentEventInfo())
    msg = spellName.." ticks on "..(destName or "unknown").." for "..amount
  end

  if msg then
    AddLogLine(msg, sourceName)
  end
end)

-- slash to open
SLASH_RAIDRECON1 = "/raidrecon"
SlashCmdList["RAIDRECON"] = function() RR:CreateUI() end

-- load notice
DEFAULT_CHAT_FRAME:AddMessage("|cff00ced1RaidRecon loaded. Type /raidrecon to open.|r")
