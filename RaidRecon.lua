-- RaidRecon.lua

-- main table
RaidRecon = {}
local RR = RaidRecon

-- state
RR.filterType    = "party"
RR.selectedClass = nil
RR.logLines      = {}
RR.debug         = false

-- helpers
local function mod(a,b) return a - math.floor(a/b)*b end
local function normalized(s) return (s or ""):lower():gsub("[^%a]","") end

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

-- find unit’s class by name
local function GetClassByName(name)
  local n = normalized(name)
  if normalized(UnitName("player")) == n then
    return UnitClass("player")
  end
  for i = 1, 4 do
    if normalized(UnitName("party"..i)) == n then
      return UnitClass("party"..i)
    end
  end
  for i = 1, 40 do
    if normalized(UnitName("raid"..i)) == n then
      return UnitClass("raid"..i)
    end
  end
  return nil
end

-- record a log line under the appropriate class
local function AddLogLine(msg, sender)
  local cls = GetClassByName(sender)
  if not cls then return end

  RR.logLines[cls] = RR.logLines[cls] or {}
  table.insert(RR.logLines[cls], msg)
  if table.getn(RR.logLines[cls]) > 200 then
    table.remove(RR.logLines[cls], 1)
  end

  if RR.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ced1[RaidRecon Debug]|r ["..cls.."] "..msg)
  end

  if cls == RR.selectedClass then
    RR:UpdateLogText()
  end
end

-- update the EditBox display
function RR:UpdateLogText()
  if not self.text then return end
  local buf = self.selectedClass and self.logLines[self.selectedClass]
  if not buf or table.getn(buf) == 0 then
    self.text:SetText("No data for "..(self.selectedClass or "none"))
  else
    self.text:SetText(table.concat(buf, "\n"))
  end
end

-- toggle between party and raid filtering
function RR:ToggleFilterType(button)
  self.filterType = (self.filterType == "party") and "raid" or "party"
  if button then
    button:SetText("Filter: "..self.filterType)
  end
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

  -- reset logs
  self.logLines = {}

  -- create main frame
  local f = CreateFrame("Frame", "RRFrame", UIParent)
  f:SetSize(600, 500)
  f:SetPoint("CENTER")

  -- backdrop
  f:SetBackdrop{
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 16, edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
  }
  f:SetBackdropColor(0, 0, 0, 0.9)

  -- make movable
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop",  f.StopMovingOrSizing)

  -- close button
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, -6, -6)
  close:SetScript("OnClick", function() f:Hide() end)

  -- title text
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOP", f, "TOP", 0, -12)
  f.title:SetText("Filter: "..self.filterType)

  -- ChatLog toggle
  local cb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  cb:SetSize(100, 24)
  cb:SetPoint("TOPLEFT", f, 16, -40)
  cb:SetText("ChatLog")
  cb:SetScript("OnClick", function() SlashCmdList["CHATLOG"]("") end)

  -- Filter toggle
  local fb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  fb:SetSize(100, 24)
  fb:SetPoint("LEFT", cb, "RIGHT", 8, 0)
  fb:SetText("Filter: "..self.filterType)
  fb:SetScript("OnClick", function() RR:ToggleFilterType(fb) end)
  self.filterButton = fb

  -- class buttons
  local perRow, sx, sy = 6, 90, 28
  local ox, oy = 16, -80
  for i, cls in ipairs(classList) do
    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(80, 24)
    local row = math.floor((i-1)/perRow)
    local col = mod(i-1, perRow)
    btn:SetPoint("TOPLEFT", f, ox + col*sx, oy - row*sy)
    btn:SetText(cls)
    local r,g,b = unpack(classColors[cls])
    btn:GetFontString():SetTextColor(r, g, b)
    btn:SetScript("OnClick", function()
      RR.selectedClass = cls
      RR:UpdateLogText()
    end)
  end

  -- scrollable log area
  local scroll = CreateFrame("ScrollFrame", "RRScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, 16, -250)
  scroll:SetPoint("BOTTOMRIGHT", f, -32, 16)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(540)
  edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed", edit.ClearFocus)
  scroll:SetScrollChild(edit)
  self.text = edit

  self.frame = f
end

-- combat-log event hook
local ef = CreateFrame("Frame")
ef:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ef:SetScript("OnEvent", function(_, _, ...)
  local _, se, _, _, src, _, _, _, dst = CombatLogGetCurrentEventInfo()
  if not src then return end

  -- party/raid filter
  local inGroup =
    (RR.filterType=="party" and (src==UnitName("player") or UnitInParty(src))) or
    (RR.filterType=="raid"  and (src==UnitName("player") or UnitInRaid(src)))
  if not inGroup then return end

  -- only track key sub-events
  if se~="SPELL_CAST_SUCCESS"
     and not se:find("HEAL")
     and se~="SPELL_AURA_APPLIED"
     and se~="SPELL_AURA_REMOVED" then
    return
  end

  local _,_,_,_,_,_,_,_,_,_,_,_, sp = CombatLogGetCurrentEventInfo()
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
end)

-- slash command
SLASH_RAIDRECON1 = "/raidrecon"
SlashCmdList["RAIDRECON"] = function() RR:CreateUI() end

-- load message
DEFAULT_CHAT_FRAME:AddMessage("|cff00ced1RaidRecon loaded. Type /raidrecon to open.|r")
