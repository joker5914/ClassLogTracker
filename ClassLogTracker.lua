-- ClassLogTracker.lua

-- grab AceGUI (LibStub must already be loaded via your TOC)
local AceGUI = LibStub("AceGUI-3.0")

ClassLogTracker = {}
local CLT = ClassLogTracker

-- state
CLT.frame         = nil
CLT.textFrame     = nil
CLT.selectedClass = nil
CLT.logLines      = {}
CLT.filterType    = "party"
CLT.debug         = false

-- simple modulo
local function mod(a,b) return a - math.floor(a/b)*b end

-- strip non-letters & lowercase
local function normalized(name)
  if not name then return "" end
  return name:lower():gsub("[^%a]","")
end

-- your class lists
local classList = {
  "Warrior","Paladin","Priest","Rogue","Warlock",
  "Mage","Shaman","Druid","Hunter"
}
local classColors = {
  Warrior={1,0.78,0.55}, Paladin={0.96,0.55,0.73}, Priest={1,1,1},
  Rogue={1,0.96,0.41},   Warlock={0.58,0.51,0.79}, Mage={0.41,0.8,0.94},
  Shaman={0,0.44,0.87},  Druid={1,0.49,0.04},     Hunter={0.67,0.83,0.45},
}

-- map a unit name → class token
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

-- stash a message under the given class
local function AddLogLine(msg, sender)
  local cls = GetClassByName(sender)
  if not cls then return end

  CLT.logLines[cls] = CLT.logLines[cls] or {}
  table.insert(CLT.logLines[cls], msg)
  if table.getn(CLT.logLines[cls]) > 200 then
    table.remove(CLT.logLines[cls], 1)
  end

  if CLT.debug then
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cff88ff00[CLT Debug]|r ["..cls.."] "..msg
    )
  end

  if cls == CLT.selectedClass then
    CLT:UpdateLogText()
  end
end

-- redraw the output box
function CLT:UpdateLogText()
  if not self.textFrame then return end
  local cls = self.selectedClass
  local buf = cls and self.logLines[cls]
  if not buf or table.getn(buf) == 0 then
    self.textFrame:SetText("No data for "..(cls or "none"))
  else
    self.textFrame:SetText(table.concat(buf, "\n"))
  end
end

-- flip party/raid
function CLT:ToggleFilterType()
  self.filterType = (self.filterType=="party") and "raid" or "party"
end

-- === AceGUI UI (replaces your old CreateUI) ===
function CLT:CreateUI()
  if CLT.frame then
    CLT.frame:Show()
    return
  end

  -- clear old logs
  self.logLines = {}

  -- main window
  local f = AceGUI:Create("Frame")
  f:SetTitle("ClassLogTracker")
  f:SetStatusText("Filter: "..self.filterType)
  f:SetLayout("Flow")
  f:SetCallback("OnClose", function(widget) widget:Hide() end)
  f:SetWidth(600)
  f:SetHeight(500)
  CLT.frame = f

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
    CLT:ToggleFilterType()
    filterBtn:SetText("Filter: "..CLT.filterType)
    f:SetStatusText("Filter: "..CLT.filterType)
  end)
  f:AddChild(filterBtn)
  CLT.filterButton = filterBtn

  -- small spacer
  local spacer = AceGUI:Create("Label")
  spacer:SetText(" ")
  spacer:SetFullWidth(true)
  f:AddChild(spacer)

  -- class buttons group
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
      CLT.selectedClass = cls
      CLT:UpdateLogText()
    end)
    classFlow:AddChild(btn)
  end
  f:AddChild(classFlow)

  -- spacer above output
  local spacer2 = AceGUI:Create("Label")
  spacer2:SetText(" ")
  spacer2:SetFullWidth(true)
  f:AddChild(spacer2)

  -- scrollable output area
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
  CLT.textFrame = edit
end

-- === Combat log hook ===
local evf = CreateFrame("Frame")
evf:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
evf:SetScript("OnEvent", function(_, event)
  if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then return end

  local _,subEvent,_,srcGUID,srcName,_,_,dstGUID,dstName =
    CombatLogGetCurrentEventInfo()
  if not srcName then return end

  -- apply party/raid filter
  local inGroup = false
  if CLT.filterType=="party" then
    if srcName==UnitName("player") then inGroup=true end
    for i=1,4 do if UnitName("party"..i)==srcName then inGroup=true end end
  else
    if srcName==UnitName("player") then inGroup=true end
    for i=1,40 do if UnitName("raid"..i)==srcName then inGroup=true end end
  end
  if not inGroup then return end

  -- track only certain sub-events
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
    msg = (srcName==UnitName("player") and "You gain "..spellName)
        or (spellName.." applied to "..(dstName or "unknown"))
  else -- REMOVED
    msg = spellName.." fades from "..(dstName or "unknown")
  end

  AddLogLine(msg, srcName)
end)

-- slash to open the window
SLASH_CLASSLOG1 = "/classlog"
SlashCmdList["CLASSLOG"] = function()
  CLT:CreateUI()
end

-- ready message
DEFAULT_CHAT_FRAME:AddMessage("|cffe5b3e5ClassLogTracker Loaded. Type /classlog to open.|r")
