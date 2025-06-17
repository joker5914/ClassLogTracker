-- RaidRecon.lua

local RaidRecon = CreateFrame("Frame")
RaidRecon:RegisterEvent("PLAYER_LOGIN")
RaidRecon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

local classList = {
  "Warrior","Paladin","Priest","Rogue","Warlock",
  "Mage","Shaman","Druid","Hunter"
}
local classColors = {
  Warrior={1,0.78,0.55}, Paladin={0.96,0.55,0.73}, Priest={1,1,1},
  Rogue={1,0.96,0.41},   Warlock={0.58,0.51,0.79}, Mage={0.41,0.8,0.94},
  Shaman={0,0.44,0.87},  Druid={1,0.49,0.04},     Hunter={0.67,0.83,0.45},
}

RaidRecon.filterType    = "party"
RaidRecon.logLines      = {}
RaidRecon.selectedClass = nil
RaidRecon.frame         = nil
RaidRecon.text          = nil

-- normalize unit names for matching
local function normalized(name)
  return (name or ""):lower():gsub("[^%a]","")
end

-- map a unit name to class token
local function GetClassByName(name)
  local n = normalized(name)
  if normalized(UnitName("player")) == n then
    return select(2, UnitClass("player"))
  end
  for i = 1, 4 do
    local unit = "party"..i
    if normalized(UnitName(unit)) == n then
      return select(2, UnitClass(unit))
    end
  end
  for i = 1, 40 do
    local unit = "raid"..i
    if normalized(UnitName(unit)) == n then
      return select(2, UnitClass(unit))
    end
  end
  return nil
end

-- record a log line under the appropriate class
local function AddLogLine(msg, sender)
  local cls = GetClassByName(sender)
  if not cls then return end
  RaidRecon.logLines[cls] = RaidRecon.logLines[cls] or {}
  table.insert(RaidRecon.logLines[cls], msg)
  if table.getn(RaidRecon.logLines[cls]) > 200 then
    table.remove(RaidRecon.logLines[cls], 1)
  end
  if cls == RaidRecon.selectedClass then
    RaidRecon:UpdateLogText()
  end
end

-- update the scrollable EditBox text
function RaidRecon:UpdateLogText()
  if not self.text then return end
  local cls = self.selectedClass
  if not cls then
    self.text:SetText("No class selected")
    return
  end
  local buf = self.logLines[cls] or {}
  if table.getn(buf) == 0 then
    self.text:SetText("No data for " .. cls .. "s")
  else
    self.text:SetText(table.concat(buf, "\n"))
  end
end

-- build or show the main UI
function RaidRecon:CreateUI()
  if self.frame then
    self.frame:Show()
    return
  end

  -- main frame
  local f = CreateFrame("Frame", "RaidReconFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(600, 400)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  self.frame = f

  -- title text
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
  f.title:SetText("Filter: " .. self.filterType)

  -- close button
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT")
  close:SetScript("OnClick", function() f:Hide() end)

  -- scroll frame for output
  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 10)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(540)
  edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed", edit.ClearFocus)
  scroll:SetScrollChild(edit)
  self.text = edit

  -- class buttons
  local btnFrame = CreateFrame("Frame", nil, f)
  btnFrame:SetSize(580, 30)
  btnFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)

  local xOff = 0
  for _, cls in ipairs(classList) do
    local b = CreateFrame("Button", nil, btnFrame, "UIPanelButtonTemplate")
    b:SetSize(60, 20)
    b:SetPoint("TOPLEFT", xOff, 0)
    b:SetText(cls)
    local r,g,bcol = unpack(classColors[cls])
    b:GetFontString():SetTextColor(r, g, bcol)
    b:SetScript("OnClick", function()
      RaidRecon.selectedClass = cls
      f.title:SetText("Filter: " .. RaidRecon.filterType .. " | Class: " .. cls)
      RaidRecon:UpdateLogText()
    end)
    xOff = xOff + 65
  end

  -- default selection
  self.selectedClass = classList[1]
  f.title:SetText("Filter: " .. self.filterType .. " | Class: " .. self.selectedClass)
  self:UpdateLogText()
end

-- parse combat log for buff/aura and damage events
function RaidRecon:ParseCombatLog()
  local _, subEvent, _, srcGUID, sourceName, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
  if not sourceName then return end

  -- filter by party/raid
  local inGroup = (self.filterType=="party" and (sourceName==UnitName("player") or UnitInParty(sourceName)))
               or (self.filterType=="raid"  and (sourceName==UnitName("player") or UnitInRaid(sourceName)))
  if not inGroup then return end

  local msg, spellName, amount

  if subEvent == "SPELL_CAST_SUCCESS" then
    _,_,_,_,_,_,_,_,_,_,_,_,spellName = CombatLogGetCurrentEventInfo()
    msg = spellName .. " → " .. (destName or "unknown")
  elseif subEvent:find("HEAL") then
    _,_,_,_,_,_,_,_,_,_,_,_,spellName, amount = CombatLogGetCurrentEventInfo()
    msg = spellName .. " healed " .. (destName or "unknown")
  elseif subEvent == "SPELL_AURA_APPLIED" then
    _,_,_,_,_,_,_,_,_,_,_,_,spellName = CombatLogGetCurrentEventInfo()
    msg = (sourceName==UnitName("player") and "You gain " .. spellName)
        or (spellName .. " applied to " .. (destName or "unknown"))
  elseif subEvent == "SPELL_AURA_REMOVED" then
    _,_,_,_,_,_,_,_,_,_,_,_,spellName = CombatLogGetCurrentEventInfo()
    msg = spellName .. " fades from " .. (destName or "unknown")
  elseif subEvent == "SWING_DAMAGE" then
    _,_,_,_,_,_,_,_,_,_,_,amount = CombatLogGetCurrentEventInfo()
    msg = "Auto-attack hits " .. (destName or "unknown") .. " for " .. amount
  elseif subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" then
    _,_,_,_,_,_,_,_,_,_,_,_,spellName, amount = CombatLogGetCurrentEventInfo()
    msg = spellName .. " hits " .. (destName or "unknown") .. " for " .. amount
  elseif subEvent == "SPELL_PERIODIC_DAMAGE" then
    _,_,_,_,_,_,_,_,_,_,_,_,spellName, amount = CombatLogGetCurrentEventInfo()
    msg = spellName .. " ticks on " .. (destName or "unknown") .. " for " .. amount
  end

  if msg then
    AddLogLine(msg, sourceName)
  end
end

-- event dispatch
RaidRecon:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    SLASH_RAIDRECON1 = "/raidrecon"
    SlashCmdList["RAIDRECON"] = function() RaidRecon:CreateUI() end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    RaidRecon:ParseCombatLog()
  end
end)
