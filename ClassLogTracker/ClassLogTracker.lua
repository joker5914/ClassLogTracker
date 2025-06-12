-- ClassLogTracker Addon (AceGUI version)
local ADDON, ns = ...
local L = {}  -- for localization later

local AceGUI = LibStub("AceGUI-3.0")
local EventFrame = CreateFrame("Frame")

local classList = {
  "Warrior","Paladin","Priest","Rogue","Warlock",
  "Mage","Shaman","Druid","Hunter"
}

local classColors = {
  Warrior={1,0.78,0.55}, Paladin={0.96,0.55,0.73}, Priest={1,1,1},
  Rogue={1,0.96,0.41}, Warlock={0.58,0.51,0.79}, Mage={0.41,0.8,0.94},
  Shaman={0,0.44,0.87}, Druid={1,0.49,0.04}, Hunter={0.67,0.83,0.45},
}

local function normalized(name)
  return name and name:lower():gsub("[^a-z]","") or ""
end

local function GetClassByName(name)
  local n = normalized(name)
  if normalized(UnitName("player") or "")==n then
    return UnitClass("player")
  end
  for i=1,4 do
    if normalized(UnitName("party"..i))==n then return UnitClass("party"..i) end
  end
  for i=1,40 do
    if normalized(UnitName("raid"..i))==n then return UnitClass("raid"..i) end
  end
end

-- store per-class buffers
local logBuffers = {}
local selectedClass = nil
local filterType = "party"

-- create or update the AceGUI window
local gui
local outputBox
function ns:ShowUI()
  if gui then
    gui:Show()
    return
  end

  gui = AceGUI:Create("Frame")
  gui:SetTitle("Class Log Tracker")
  gui:SetStatusText("Click a class to filter, or toggle chatlog")
  gui:SetCallback("OnClose", function(widget) AceGUI:Release(widget) gui=nil end)
  gui:SetLayout("Flow")
  gui:SetWidth(650); gui:SetHeight(520)

  -- Header group: ChatLog & Filter
  local header = AceGUI:Create("InlineGroup")
  header:SetTitle("Features")
  header:SetFullWidth(true)
  header:SetLayout("Flow")

  local chatBtn = AceGUI:Create("Button")
  chatBtn:SetText("ChatLog")
  chatBtn:SetWidth(100)
  chatBtn:SetCallback("OnClick", function() SlashCmdList["CHATLOG"]("") end)
  header:AddChild(chatBtn)

  local filterBtn = AceGUI:Create("Button")
  filterBtn:SetText("Filter: "..filterType)
  filterBtn:SetWidth(100)
  filterBtn:SetCallback("OnClick", function()
    filterType = (filterType=="party" and "raid" or "party")
    filterBtn:SetText("Filter: "..filterType)
  end)
  header:AddChild(filterBtn)

  gui:AddChild(header)

  -- Classes group
  local classGroup = AceGUI:Create("InlineGroup")
  classGroup:SetTitle("Classes")
  classGroup:SetFullWidth(true)
  classGroup:SetLayout("Flow")

  for _,cls in ipairs(classList) do
    local b = AceGUI:Create("Button")
    b:SetText(cls)
    b:SetWidth(80)
    local r,g,bc = unpack(classColors[cls])
    b:SetColor(r,g,bc)
    b:SetCallback("OnClick", function()
      selectedClass = cls
      -- update output
      local buf = logBuffers[cls] or {}
      if #buf==0 then
        outputBox:SetText("No data for "..cls)
      else
        outputBox:SetText(table.concat(buf, "\n"))
      end
    end)
    classGroup:AddChild(b)
  end

  gui:AddChild(classGroup)

  -- Output area
  local outGroup = AceGUI:Create("InlineGroup")
  outGroup:SetTitle("Log Output")
  outGroup:SetFullWidth(true)
  outGroup:SetHeight(350)
  outGroup:SetLayout("Fill")

  outputBox = AceGUI:Create("MultiLineEditBox")
  outputBox:DisableButton(true)
  outputBox:SetFullWidth(true)
  outputBox:SetFullHeight(true)
  outputBox:SetText("No data yet...")
  outGroup:AddChild(outputBox)

  gui:AddChild(outGroup)
end

-- handle combat log events (same filters as before)
EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
EventFrame:SetScript("OnEvent", function(self, event)
  local _, subEvent, _, srcGUID, srcName, _, _, dstGUID, dstName, _, _, spellId, spellName =
    CombatLogGetCurrentEventInfo()
  if not srcName then return end

  -- only track party/raid
  if not GetClassByName(srcName) then return end

  -- only these subEvents
  if subEvent~="SPELL_CAST_SUCCESS"
  and not subEvent:find("HEAL")
  and subEvent~="SPELL_AURA_APPLIED"
  and subEvent~="SPELL_AURA_REMOVED" then
    return
  end

  -- skip out-of-party based on filterType
  local unit = (filterType=="party" and "party") or "raid"
  if not UnitInParty(srcName) and filterType=="party" then return end
  if not UnitInRaid(srcName) and filterType=="raid" then return end

  -- build message
  local msg
  if subEvent=="SPELL_CAST_SUCCESS" then
    msg = spellName.." → "..(dstName or "?")
  elseif subEvent:find("HEAL") then
    msg = spellName.." healed "..(dstName or "?")
  elseif subEvent=="SPELL_AURA_APPLIED" then
    msg = (srcName==UnitName("player") and "You gain "..spellName)
      or (spellName.." applied to "..(dstName or "?"))
  else -- REMOVED
    msg = spellName.." fades from "..(dstName or "?")
  end

  -- stash
  local cls = GetClassByName(srcName)
  logBuffers[cls] = logBuffers[cls] or {}
  table.insert(logBuffers[cls], msg)
  if #logBuffers[cls] > 200 then
    table.remove(logBuffers[cls], 1)
  end

  -- if currently selected, update live
  if gui and selectedClass==cls then
    outputBox:SetText(table.concat(logBuffers[cls], "\n"))
  end
end)

SLASH_CLASSLOG1 = "/classlog"
SlashCmdList["CLASSLOG"] = function()
  ns:ShowUI()
end
