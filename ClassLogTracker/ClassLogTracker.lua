-- ClassLogTracker Addon
-- Requires LibStub and AceGUI-3.0 embedded via your TOC under Libs/

local AceGUI = LibStub("AceGUI-3.0")

ClassLogTracker = {}
ClassLogTracker.frame         = nil
ClassLogTracker.textFrame     = nil
ClassLogTracker.selectedClass = nil
ClassLogTracker.logLines      = {}
ClassLogTracker.filterType    = "party"
ClassLogTracker.debug         = false

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

-- record a log line under the right class
local function AddLogLine(msg, sender)
  local cls = GetClassByName(sender)
  if not cls then return end

  ClassLogTracker.logLines[cls] = ClassLogTracker.logLines[cls] or {}
  table.insert(ClassLogTracker.logLines[cls], msg)
  if table.getn(ClassLogTracker.logLines[cls]) > 200 then
    table.remove(ClassLogTracker.logLines[cls], 1)
  end

  if ClassLogTracker.debug then
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cff88ff00[CLT Debug]|r ["..cls.."] "..msg
    )
  end

  if cls == ClassLogTracker.selectedClass then
    ClassLogTracker:UpdateLogText()
  end
end

-- redraw the MultiLineEditBox with the selected class’s log
function ClassLogTracker:UpdateLogText()
  if not self.textFrame then return end
  local cls = self.selectedClass
  local buf = cls and self.logLines[cls]
  if not buf or table.getn(buf) == 0 then
    self.textFrame:SetText("No data for "..(cls or "none"))
  else
    self.textFrame:SetText(table.concat(buf, "\n"))
  end
end

-- toggle party/raid filter
function ClassLogTracker:ToggleFilterType(button)
  self.filterType = (self.filterType == "party") and "raid" or "party"
  if button then
    button:SetText("Filter: "..self.filterType)
  end
end

-- build (or show) the AceGUI UI
function ClassLogTracker:CreateUI()
  if self.frame then
    self.frame:Show()
    return
  end

  -- reset logs
  self.logLines = {}

  -- main window
  local f = AceGUI:Create("Frame")
  f:SetTitle("ClassLogTracker")
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
  chatBtn:SetCallback("OnClick", function()
    SlashCmdList["CHATLOG"]("")
  end)
  f:AddChild(chatBtn)

  -- Filter toggle
  local filterBtn = AceGUI:Create("Button")
  filterBtn:SetText("Filter: "..self.filterType)
  filterBtn:SetWidth(120)
  filterBtn:SetCallback("OnClick", function()
    ClassLogTracker:ToggleFilterType(filterBtn)
    f:SetStatusText("Filter: "..ClassLogTracker.filterType)
  end)
  f:AddChild(filterBtn)
  self.filterButton = filterBtn

  -- spacer
  local sep1 = AceGUI:Create("Label")
  sep1:SetText(" ")
  sep1:SetFullWidth(true)
  f:AddChild(sep1)

  -- class buttons container
  local classFlow = AceGUI:Create("SimpleGroup")
  classFlow:SetLayout("Flow")
  classFlow:SetFullWidth(true)
  for _, cls in ipairs(classList) do
    local btn = AceGUI:Create("Button")
    btn:SetText(cls)
    btn:SetWidth(80)
    local r,g,b = unpack(classColors[cls])
    btn:SetColor(r,g,b)
    btn:SetCallback("OnClick", function()
      ClassLogTracker.selectedClass = cls
      ClassLogTracker:UpdateLogText()
    end)
    classFlow:AddChild(btn)
  end
  f:AddChild(classFlow)

  -- spacer
  local sep2 = AceGUI:Create("Label")
  sep2:SetText(" ")
  sep2:SetFullWidth(true)
  f:AddChild(sep2)

  -- output scroll area
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

-- raw combat-log hook
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:SetScript("OnEvent", function(_, event)
  if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then return end

  local _,subEvent,_,srcGUID,srcName,_,_,dstGUID,dstName =
    CombatLogGetCurrentEventInfo()
  if not srcName then return end

  -- party/raid filter
  local inGroup = false
  if ClassLogTracker.filterType == "party" then
    if srcName == UnitName("player") then inGroup = true end
    for i=1,4 do if UnitName("party"..i)==srcName then inGroup = true end end
  else
    if srcName == UnitName("player") then inGroup = true end
    for i=1,40 do if UnitName("raid"..i)==srcName then inGroup = true end end
  end
  if not inGroup then return end

  -- only track these sub-events
  if subEvent ~= "SPELL_CAST_SUCCESS"
     and not subEvent:find("HEAL")
     and subEvent ~= "SPELL_AURA_APPLIED"
     and subEvent ~= "SPELL_AURA_REMOVED" then
    return
  end

  -- build message
  local _,_,_,_,_,_,_,_,_,_,_,spellId,spellName =
    CombatLogGetCurrentEventInfo()
  local msg
  if subEvent=="SPELL_CAST_SUCCESS" then
    msg = spellName.." → "..(dstName or "unknown")
  elseif subEvent:find("HEAL") then
    msg = spellName.." healed "..(dstName or "unknown")
  elseif subEvent=="SPELL_AURA_APPLIED" then
    if srcName==UnitName("player") then
      msg = "You gain "..spellName
    else
      msg = spellName.." applied to "..(dstName or "unknown")
    end
  else -- SPELL_AURA_REMOVED
    if dstName==UnitName("player") then
      msg = spellName.." fades from you"
    else
      msg = spellName.." fades from "..(dstName or "unknown")
    end
  end

  AddLogLine(msg, srcName)
end)

-- slash to open UI
SLASH_CLASSLOG1 = "/classlog"
SlashCmdList["CLASSLOG"] = function()
  ClassLogTracker:CreateUI()
end

-- initial load message
DEFAULT_CHAT_FRAME:AddMessage("|cffe5b3e5ClassLogTracker Loaded. Type /classlog to open.|r")
