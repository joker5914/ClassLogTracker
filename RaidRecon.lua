-- RaidRecon.lua: Fixed addon with GUID→class mapping and class-filter buttons

----------------------
-- Addon Namespace
----------------------
RaidRecon = {}
local RR = RaidRecon

----------------------
-- State & Caches
----------------------
RR.logLines      = {}        -- raw combat entries
RR.selectedClass = nil       -- current filter, e.g. "Warrior"
RR.classByGUID   = {}        -- GUID → class lookup

----------------------
-- Configuration
----------------------
local classList = {
  "Warrior","Paladin","Priest","Rogue","Warlock",
  "Mage","Shaman","Druid","Hunter",
}

-- Optional: define colors per class if you display colored text
local classColors = {
  Warrior={1,0.78,0.55}, Paladin={0.96,0.55,0.73}, Priest={1,1,1},
  Rogue={1,0.96,0.41}, Warlock={0.58,0.51,0.79}, Mage={0.41,0.8,0.94},
  Shaman={0,0.44,0.87}, Druid={1,0.49,0}, Hunter={0.67,0.83,0.45},
}

----------------------
-- Frame & Event Setup
----------------------
local frame = CreateFrame("Frame", "RaidReconFrame", UIParent)
frame:SetSize(300, 400)
frame:SetPoint("CENTER")
frame:Show()

-- Register roster updates and combat log
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
    RR:RefreshRoster()
  else  -- COMBAT_LOG_EVENT_UNFILTERED
    RR:HandleCombatEvent(CombatLogGetCurrentEventInfo())
  end
end)

----------------------
-- Roster Refresh
----------------------
function RR:RefreshRoster()
  table.wipe(self.classByGUID)

  -- Add player
  local playerGUID = UnitGUID("player")
  local _, playerClass = UnitClass("player")
  self.classByGUID[playerGUID] = playerClass

  -- Raid members
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid"..i
      local guid = UnitGUID(unit)
      if guid then
        local _, cls = UnitClass(unit)
        self.classByGUID[guid] = cls
      end
    end

  -- Party members
  elseif IsInGroup() then
    for i = 1, GetNumSubgroupMembers() do
      local unit = "party"..i
      local guid = UnitGUID(unit)
      if guid then
        local _, cls = UnitClass(unit)
        self.classByGUID[guid] = cls
      end
    end
  end
end

----------------------
-- Combat Log Handler
----------------------
function RR:HandleCombatEvent(timestamp, subevent, hideCaster,
    srcGUID, srcName, srcFlags, destGUID, destName, destFlags, ...)
  local class = self.classByGUID[srcGUID]
  if not class then return end  -- skip non-roster

  table.insert(self.logLines, {
    time  = timestamp,
    event = subevent,
    name  = srcName,
    class = class,
  })
  self:UpdateDisplay()
end

----------------------
-- Class Button Click Handler
----------------------
function RR:OnClassButtonClick(className)
  self.selectedClass = className  -- nil for All
  self:UpdateDisplay()
end

----------------------
-- UI Update
----------------------
function RR:UpdateDisplay()
  -- Build filtered list
  local lines = {}
  for _, entry in ipairs(self.logLines) do
    if not self.selectedClass or entry.class == self.selectedClass then
      table.insert(lines, entry)
    end
  end

  -- Show status or populate scrollframe
  if #lines == 0 then
    RaidReconStatusText:SetText(
      "No data for " .. (self.selectedClass or "All"))
  else
    RaidReconStatusText:SetText("")
    -- TODO: populate your scrollframe or fontstrings from `lines`
  end
end

----------------------
-- Hook Up Buttons
----------------------
-- Assuming XML or global buttons named RaidReconFilterAll, RaidReconFilter<Class>
RaidReconFilterAll:SetScript("OnClick", function() RR:OnClassButtonClick(nil) end)
for _, cls in ipairs(classList) do
  local btn = _G["RaidReconFilter"..cls]
  if btn then
    btn:SetScript("OnClick", function() RR:OnClassButtonClick(cls) end)
  end
end
