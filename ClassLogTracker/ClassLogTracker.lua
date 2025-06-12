-- ClassLogTracker Addon
ClassLogTracker = {}
ClassLogTracker.frame         = nil
ClassLogTracker.scrollFrame   = nil
ClassLogTracker.textFrame     = nil
ClassLogTracker.selectedClass = nil
ClassLogTracker.logLines      = {}
ClassLogTracker.filterType    = "party"

-- simple modulo
local function mod(a, b)
  return a - math.floor(a / b) * b
end

-- strip non-letters & lowercase
local function normalized(name)
  if not name then return "" end
  return string.lower(string.gsub(name, "[^%a]", ""))
end

local classList = {
  "Warrior","Paladin","Priest","Rogue","Warlock",
  "Mage","Shaman","Druid","Hunter"
}

local classColors = {
  Warrior = {1.0,0.78,0.55},
  Paladin = {0.96,0.55,0.73},
  Priest  = {1.0,1.0,1.0},
  Rogue   = {1.0,0.96,0.41},
  Warlock = {0.58,0.51,0.79},
  Mage    = {0.41,0.8,0.94},
  Shaman  = {0.0,0.44,0.87},
  Druid   = {1.0,0.49,0.04},
  Hunter  = {0.67,0.83,0.45},
}

-- map unit-name → class token
local function GetClassByName(name)
  name = normalized(name)
  if normalized(UnitName("player") or "") == name then
    return UnitClass("player")
  end
  for i = 1, 4 do
    if normalized(UnitName("party"..i)) == name then
      return UnitClass("party"..i)
    end
  end
  for i = 1, 40 do
    if normalized(UnitName("raid"..i)) == name then
      return UnitClass("raid"..i)
    end
  end
  return nil
end

-- record a log line under the right class
local function AddLogLine(msg, sender)
  local class = GetClassByName(sender)
  if not class then return end

  ClassLogTracker.logLines[class] = ClassLogTracker.logLines[class] or {}
  table.insert(ClassLogTracker.logLines[class], msg)

  -- keep only last 200 entries
  if table.getn(ClassLogTracker.logLines[class]) > 200 then
    table.remove(ClassLogTracker.logLines[class], 1)
  end

  if class == ClassLogTracker.selectedClass then
    ClassLogTracker:UpdateLogText()
  end
end

-- redraw EditBox with the selected class’s log
function ClassLogTracker:UpdateLogText()
  if not self.textFrame then return end
  local c = self.selectedClass
  if not c or not self.logLines[c] then
    self.textFrame:SetText("No data for this class.")
    return
  end
  self.textFrame:SetText(table.concat(self.logLines[c], "\n"))
end

-- toggle party/raid filter text
function ClassLogTracker:ToggleFilterType()
  self.filterType = (self.filterType=="party") and "raid" or "party"
  self.filterButton:SetText("Filter: "..self.filterType)
end

-- build (or show) the UI
function ClassLogTracker:CreateUI()
  if self.frame then
    self.frame:Show()
    return
  end

  self.logLines = {}

  -- main frame
  local f = CreateFrame("Frame","ClassLogTrackerFrame",UIParent)
  f:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile     = true, tileSize=16, edgeSize=16,
    insets   = { left=4, right=4, top=4, bottom=4 },
  })
  f:SetBackdropColor(0,0,0,0.9)
  f:SetWidth(600); f:SetHeight(500)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton"); f:SetMovable(true)
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

  -- close button
  local close = CreateFrame("Button",nil,f,"UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() f:Hide() end)

  -- filter toggle
  local filter = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
  filter:SetWidth(120); filter:SetHeight(22)
  filter:SetText("Filter: party")
  filter:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
  filter:SetScript("OnClick", function() ClassLogTracker:ToggleFilterType() end)
  self.filterButton = filter

  -- class buttons
  local perRow, sx, sy = 6, 85, 26
  local ox, oy = 10, -40
  for i, cls in ipairs(classList) do
    local btn = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    btn:SetWidth(80); btn:SetHeight(22)
    btn:SetText(cls)
    local row = math.floor((i-1)/perRow)
    local col = mod(i-1,perRow)
    btn:SetPoint("TOPLEFT", f, "TOPLEFT", ox+col*sx, oy-row*sy)
    local r,g,b = unpack(classColors[cls])
    btn:GetFontString():SetTextColor(r,g,b)

    -- capture class in a local and use a no-arg closure
    do
      local thisClass = cls
      btn:SetScript("OnClick", function()
        ClassLogTracker.selectedClass = thisClass
        ClassLogTracker:UpdateLogText()
      end)
    end
  end

  -- scrollable text area
  local scroll = CreateFrame("ScrollFrame","ClassLogScroll",f,"UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT",     f, "TOPLEFT",     10,  -120)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30,    10)

  local text = CreateFrame("EditBox",nil,scroll)
  text:SetMultiLine(true)
  text:SetFontObject(ChatFontNormal)
  text:SetWidth(540)
  text:SetAutoFocus(false)
  text:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  scroll:SetScrollChild(text)

  self.frame       = f
  self.scrollFrame = scroll
  self.textFrame   = text
end

-- explicit params, no varargs (still available but unused)
function ClassLogTracker:OnEvent(msg, sender)
  if type(msg)~="string" or msg=="" then return end
  if (not sender or sender=="") and msg:find("^You ") then
    sender = UnitName("player")
  elseif not sender or sender=="" then
    return
  end
  sender = sender:match("^[^-]+")
  AddLogLine(msg, sender)
end

-- replace all CHAT_MSG_* registration with raw combat log hook
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:SetScript("OnEvent", function(_, event)
  if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then return end

  local _, subEvent,
        _, sourceName = CombatLogGetCurrentEventInfo()

  if not sourceName then return end

  -- only these sub-events
  if subEvent == "SPELL_CAST_SUCCESS"
  or subEvent == "SPELL_HEAL"
  or subEvent == "SPELL_PERIODIC_HEAL"
  or subEvent == "SPELL_AURA_APPLIED" then

    -- build a brief message
    local timestamp, _, _, srcGUID, srcName, _, _,
          dstGUID, dstName, _, _, spellId, spellName =
      CombatLogGetCurrentEventInfo()

    local msgText
    if subEvent == "SPELL_CAST_SUCCESS" then
      msgText = spellName .. " → " .. (dstName or "unknown")
    elseif subEvent:find("HEAL") then
      msgText = spellName .. " healed " .. (dstName or "unknown")
    else
      msgText = spellName .. " applied to " .. (dstName or "unknown")
    end

    AddLogLine(msgText, srcName)
  end
end)

DEFAULT_CHAT_FRAME:AddMessage("|cffe5b3e5ClassLogTracker Loaded. Type /classlog to open.|r")

SLASH_CLASSLOG1 = "/classlog"
SlashCmdList["CLASSLOG"] = function()
  ClassLogTracker:CreateUI()
end
