-- RaidRecon.lua

local RaidRecon = CreateFrame("Frame")
RaidRecon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
RaidRecon:RegisterEvent("PLAYER_LOGIN")

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

-- normalize a unit name for matching
local function normalized(s)
  return (s or ""):lower():gsub("[^%a]","")
end

-- find class by unit name
local function GetClassByName(name)
  local n = normalized(name)
  if normalized(UnitName("player")) == n then
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

-- record a log line under the right class
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

-- redraw the EditBox
function RaidRecon:UpdateLogText()
  if not self.text then return end

  local cls = self.selectedClass
  if not cls then
    self.text:SetText("No class selected")
    return
  end

  local buf = self.logLines[cls] or {}
  if table.getn(buf) == 0 then
    -- pluralize by adding “s”
    self.text:SetText("No data for " .. cls .. "s")
  else
    self.text:SetText(table.concat(buf, "\n"))
  end
end

-- build (or show) the UI
function RaidRecon:CreateUI()
  if self.frame then
    self.frame:Show()
    return
  end

  -- main window
  local f = CreateFrame("Frame", "RaidReconFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(600, 400)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop",  f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  self.frame = f

  -- title text
  f.title = f:CreateFontString(nil, "OVERLAY")
  f.title:SetFontObject("GameFontHighlight")
  f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
  f.title:SetText("Filter: " .. self.filterType)

  -- close button
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT")
  close:SetScript("OnClick", function() f:Hide() end)

  -- scrollable output
  local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",     10, -40)
  scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 10)

  local editBox = CreateFrame("EditBox", nil, scrollFrame)
  editBox:SetMultiLine(true)
  editBox:SetFontObject(ChatFontNormal)
  editBox:SetWidth(540)
  editBox:SetAutoFocus(false)
  editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
  scrollFrame:SetScrollChild(editBox)
  self.text = editBox

  -- class buttons
  local btnFrame = CreateFrame("Frame", nil, f)
  btnFrame:SetSize(580, 30)
  btnFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)

  local xOffset = 0
  for _, cls in ipairs(classList) do
    local b = CreateFrame("Button", nil, btnFrame, "UIPanelButtonTemplate")
    b:SetSize(60, 20)
    b:SetPoint("TOPLEFT", xOffset, 0)
    b:SetText(cls)
    local r,g,bc = unpack(classColors[cls])
    b:GetFontString():SetTextColor(r,g,bc)
    b:SetScript("OnClick", function()
      self.selectedClass = cls
      f.title:SetText("Filter: " .. self.filterType .. " | Class: " .. cls)
      self:UpdateLogText()
    end)
    xOffset = xOffset + 65
  end

  -- default to first class
  self.selectedClass = classList[1]
  f.title:SetText("Filter: " .. self.filterType .. " | Class: " .. self.selectedClass)
  self:UpdateLogText()
end

-- parse all key combat-log events (damage + buff/aura)
function RaidRecon:ParseCombatLog()
  local timestamp, subevent,
        _, srcGUID, sourceName, srcFlags,
        _, dstGUID, destName, dstFlags,
        spellID, spellName = CombatLogGetCurrentEventInfo()

  if not sourceName then return end

  -- only track party/raid or self
  local inGroup =
    (self.filterType=="party" and (sourceName==UnitName("player") or UnitInParty(sourceName))) or
    (self.filterType=="raid"  and (sourceName==UnitName("player") or UnitInRaid(sourceName)))
  if not inGroup then return end

  local msg

  -- spell casts / heals / auras
  if subevent == "SPELL_CAST_SUCCESS" then
    msg = spellName .. " → " .. (destName or "unknown")
  elseif subevent:find("HEAL") then
    msg = spellName .. " healed " .. (destName or "unknown")
  elseif subevent == "SPELL_AURA_APPLIED" then
    msg = (sourceName==UnitName("player") and "You gain " .. spellName)
        or (spellName .. " applied to " .. (destName or "unknown"))
  elseif subevent == "SPELL_AURA_REMOVED" then
    msg = spellName .. " fades from " .. (destName or "unknown")

  -- damage events
  elseif subevent == "SWING_DAMAGE" then
    local amount = select(12, CombatLogGetCurrentEventInfo())
    msg = "Auto-attack hits " .. (destName or "unknown") .. " for " .. amount
  elseif subevent == "RANGE_DAMAGE" or subevent == "SPELL_DAMAGE" then
    local _, _, _, _, _, _, _, _, _, _, _, _, dmg = CombatLogGetCurrentEventInfo()
    msg = spellName .. " hits " .. (destName or "unknown") .. " for " .. dmg
  elseif subevent == "SPELL_PERIODIC_DAMAGE" then
    local _, _, _, _, _, _, _, _, _, _, _, _, tick = CombatLogGetCurrentEventInfo()
    msg = spellName .. " ticks on " .. (destName or "unknown") .. " for " .. tick
  end

  if msg then
    AddLogLine(msg, sourceName)
  end
end

-- event dispatcher
RaidRecon:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    SLASH_RAIDRECON1 = "/raidrecon"
    SlashCmdList["RAIDRECON"] = function() RaidRecon:CreateUI() end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    RaidRecon:ParseCombatLog()
  end
end)
