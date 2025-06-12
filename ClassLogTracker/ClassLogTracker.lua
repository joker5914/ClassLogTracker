-- ClassLogTracker Addon
ClassLogTracker = {}
ClassLogTracker.frame = nil
ClassLogTracker.scrollFrame = nil
ClassLogTracker.textFrame = nil
ClassLogTracker.selectedClass = nil
ClassLogTracker.logLines = {}
ClassLogTracker.filterType = "party"

local function mod(a, b)
  return a - math.floor(a / b) * b
end

local function normalized(name)
  if not name then return "" end
  return string.lower(string.gsub(name, "[^%a]", ""))
end

local classList = {
  "Warrior", "Paladin", "Priest", "Rogue", "Warlock",
  "Mage", "Shaman", "Druid", "Hunter"
}

local classColors = {
  Warrior = {1.0, 0.78, 0.55},
  Paladin = {0.96, 0.55, 0.73},
  Priest  = {1.0, 1.0, 1.0},
  Rogue   = {1.0, 0.96, 0.41},
  Warlock = {0.58, 0.51, 0.79},
  Mage    = {0.41, 0.8, 0.94},
  Shaman  = {0.0, 0.44, 0.87},
  Druid   = {1.0, 0.49, 0.04},
  Hunter  = {0.67, 0.83, 0.45},
}

local function GetClassByName(name)
  name = normalized(name)
  if normalized(UnitName("player") or "") == name then
    return UnitClass("player")
  end
  for i = 1, 4 do
    if normalized(UnitName("party" .. i)) == name then
      return UnitClass("party" .. i)
    end
  end
  for i = 1, 40 do
    if normalized(UnitName("raid" .. i)) == name then
      return UnitClass("raid" .. i)
    end
  end
  return nil
end

local function AddLogLine(msg, sender)
  local class = GetClassByName(sender)
  if class then
    if not ClassLogTracker.logLines[class] then
      ClassLogTracker.logLines[class] = {}
    end
    table.insert(ClassLogTracker.logLines[class], msg)
    if table.getn(ClassLogTracker.logLines[class]) > 200 then
      table.remove(ClassLogTracker.logLines[class], 1)
    end
    if class == ClassLogTracker.selectedClass then
      ClassLogTracker:UpdateLogText()
    end
  end
end

function ClassLogTracker:UpdateLogText()
  if not self.textFrame then return end
  local class = self.selectedClass
  if not class or not self.logLines[class] then
    self.textFrame:SetText("No data for this class.")
    return
  end
  self.textFrame:SetText(table.concat(self.logLines[class], "\n"))
end

function ClassLogTracker:ToggleFilterType()
  self.filterType = (self.filterType == "party") and "raid" or "party"
  self.filterButton:SetText("Filter: " .. self.filterType)
end

function ClassLogTracker:CreateUI()
  if self.frame then
    self.frame:Show()
    return
  end

  self.logLines = {}

  local f = CreateFrame("Frame", "ClassLogTrackerFrame", UIParent)
  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  f:SetBackdropColor(0, 0, 0, 0.9)
  f:SetWidth(600)
  f:SetHeight(500)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() f:Hide() end)

  local filter = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  filter:SetWidth(120)
  filter:SetHeight(22)
  filter:SetText("Filter: party")
  filter:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
  filter:SetScript("OnClick", function() ClassLogTracker:ToggleFilterType() end)
  self.filterButton = filter

  local buttonsPerRow = 6
  local buttonSpacingX = 85
  local buttonSpacingY = 26
  local startX = 10
  local startY = -40
  for i, class in ipairs(classList) do
    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetWidth(80)
    btn:SetHeight(22)
    btn:SetText(class)
    local row = math.floor((i - 1) / buttonsPerRow)
    local col = mod((i - 1), buttonsPerRow)
    btn:SetPoint("TOPLEFT", f, "TOPLEFT", startX + col * buttonSpacingX, startY - row * buttonSpacingY)
    local r, g, b = unpack(classColors[class])
    btn:GetFontString():SetTextColor(r, g, b)
    btn:SetScript("OnClick", function()
      ClassLogTracker.selectedClass = class
      ClassLogTracker:UpdateLogText()
    end)
  end

  local scroll = CreateFrame("ScrollFrame", "ClassLogScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -120)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 10)

  local text = CreateFrame("EditBox", nil, scroll)
  text:SetMultiLine(true)
  text:SetFontObject(ChatFontNormal)
  text:SetWidth(540)
  text:SetAutoFocus(false)
  text:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  scroll:SetScrollChild(text)
  self.frame = f
  self.scrollFrame = scroll
  self.textFrame = text
end

function ClassLogTracker:OnEvent()
  local msg = arg1
  local sender = arg2

  if (not sender or sender == "") and string.find(msg, "^You ") then
    sender = UnitName("player")
  elseif not sender or sender == "" then
    return
  end

  sender = string.match(sender, "([^%-]+)")

  if sender and msg then
    AddLogLine(msg, sender)
  end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
eventFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_PARTY_BUFF")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_PARTY")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE")
eventFrame:RegisterEvent("CHAT_MSG_COMBAT_PARTY_HITS")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_FRIENDLYPLAYER")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE")
eventFrame:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS")
eventFrame:SetScript("OnEvent", function() ClassLogTracker:OnEvent() end)

DEFAULT_CHAT_FRAME:AddMessage("|cffe5b3e5ClassLogTracker Loaded. Type /classlog to open.|r")

SLASH_CLASSLOG1 = "/classlog"
SlashCmdList["CLASSLOG"] = function()
  if ClassLogTracker then
    ClassLogTracker:CreateUI()
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Error: ClassLogTracker not loaded properly.|r")
  end
end
