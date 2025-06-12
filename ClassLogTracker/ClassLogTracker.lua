-- ClassLogTracker Addon
ClassLogTracker = {}
ClassLogTracker.frame         = nil
ClassLogTracker.scrollFrame   = nil
ClassLogTracker.textFrame     = nil
ClassLogTracker.selectedClass = nil
ClassLogTracker.logLines      = {}
ClassLogTracker.filterType    = "party"

local function mod(a,b) return a - math.floor(a/b)*b end
local function normalized(name)
  if not name then return "" end
  return string.lower(string.gsub(name, "[^%a]", ""))
end

local classList = {
  "Warrior","Paladin","Priest","Rogue","Warlock",
  "Mage","Shaman","Druid","Hunter"
}
local classColors = {
  Warrior={1,0.78,0.55}, Paladin={0.96,0.55,0.73}, Priest={1,1,1},
  Rogue={1,0.96,0.41}, Warlock={0.58,0.51,0.79}, Mage={0.41,0.8,0.94},
  Shaman={0,0.44,0.87}, Druid={1,0.49,0.04}, Hunter={0.67,0.83,0.45},
}

local function GetClassByName(name)
  name = normalized(name)
  if normalized(UnitName("player") or "")==name then return UnitClass("player") end
  for i=1,4 do
    if normalized(UnitName("party"..i))==name then return UnitClass("party"..i) end
  end
  for i=1,40 do
    if normalized(UnitName("raid"..i))==name then return UnitClass("raid"..i) end
  end
  return nil
end

local function AddLogLine(msg, sender)
  local class = GetClassByName(sender)
  if not class then return end
  ClassLogTracker.logLines[class] = ClassLogTracker.logLines[class] or {}
  table.insert(ClassLogTracker.logLines[class], msg)
  if table.getn(ClassLogTracker.logLines[class])>200 then
    table.remove(ClassLogTracker.logLines[class],1)
  end
  if class==ClassLogTracker.selectedClass then
    ClassLogTracker:UpdateLogText()
  end
end

function ClassLogTracker:UpdateLogText()
  if not self.textFrame then return end
  local c = self.selectedClass
  if not c or not self.logLines[c] then
    self.textFrame:SetText("No data for this class.")
    return
  end
  self.textFrame:SetText(table.concat(self.logLines[c], "\n"))
end

function ClassLogTracker:ToggleFilterType()
  self.filterType = (self.filterType=="party") and "raid" or "party"
  self.filterButton:SetText("Filter: "..self.filterType)
end

function ClassLogTracker:CreateUI()
  if self.frame then self.frame:Show() return end
  self.logLines = {}

  local f = CreateFrame("Frame","ClassLogTrackerFrame",UIParent)
  f:SetBackdrop{
    bgFile="Interface/Tooltips/UI-Tooltip-Background",
    edgeFile="Interface/Tooltips/UI-Tooltip-Border",
    tile=true, tileSize=16, edgeSize=16,
    insets={left=4,right=4,top=4,bottom=4},
  }
  f:SetBackdropColor(0,0,0,0.9)
  f:SetWidth(600); f:SetHeight(500)
  f:SetPoint("CENTER",UIParent,"CENTER",0,0)
  f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetMovable(true)
  f:SetScript("OnDragStart",function()f:StartMoving()end)
  f:SetScript("OnDragStop",function()f:StopMovingOrSizing()end)

  -- ChatLog toggle
  local chatToggle = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
  chatToggle:SetSize(120,22)
  chatToggle:SetText("ChatLog")
  chatToggle:SetPoint("TOPLEFT",f,"TOPLEFT",10,-10)
  chatToggle:SetScript("OnClick",function()
    SlashCmdList["CHATLOG"]("")
  end)

  -- Filter toggle
  local filter = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
  filter:SetSize(120,22)
  filter:SetText("Filter: party")
  filter:SetPoint("TOPLEFT",f,"TOPLEFT",140,-10)
  filter:SetScript("OnClick",function()ClassLogTracker:ToggleFilterType()end)
  self.filterButton = filter

  -- separator below header
  local headerSep = f:CreateTexture(nil,"ARTWORK")
  headerSep:SetColorTexture(1,1,1,0.25)
  headerSep:SetHeight(2)
  headerSep:SetPoint("TOPLEFT",f,"TOPLEFT",5,-35)
  headerSep:SetPoint("TOPRIGHT",f,"TOPRIGHT",-5,-35)

  -- class buttons
  local perRow,sx,sy=6,85,26
  local ox,oy=10,-40
  for i,cls in ipairs(classList) do
    local btn=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    btn:SetSize(80,22)
    btn:SetText(cls)
    local row,col=math.floor((i-1)/perRow),mod(i-1,perRow)
    btn:SetPoint("TOPLEFT",f,"TOPLEFT",ox+col*sx,oy-row*sy)
    local r,g,b=unpack(classColors[cls])
    btn:GetFontString():SetTextColor(r,g,b)
    do
      local thisClass=cls
      btn:SetScript("OnClick",function()
        ClassLogTracker.selectedClass=thisClass
        ClassLogTracker:UpdateLogText()
      end)
    end
  end

  -- separator above output
  local classSep = f:CreateTexture(nil,"ARTWORK")
  classSep:SetColorTexture(1,1,1,0.25)
  classSep:SetHeight(2)
  classSep:SetPoint("TOPLEFT",f,"TOPLEFT",5,-100)
  classSep:SetPoint("TOPRIGHT",f,"TOPRIGHT",-5,-100)

  -- scrollable output
  local scroll=CreateFrame("ScrollFrame","ClassLogScroll",f,"UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT",f,"TOPLEFT",10,-120)
  scroll:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-30,10)
  local text=CreateFrame("EditBox",nil,scroll)
  text:SetMultiLine(true); text:SetFontObject(ChatFontNormal)
  text:SetWidth(540); text:SetAutoFocus(false)
  text:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
  scroll:SetScrollChild(text)

  self.frame=f; self.scrollFrame=scroll; self.textFrame=text
end

function ClassLogTracker:OnEvent(msg,sender)
  if type(msg)~="string" or msg=="" then return end
  if (not sender or sender=="") and msg:find("^You ") then
    sender=UnitName("player")
  elseif not sender or sender=="" then return end
  sender=sender:match("^[^-]+")
  AddLogLine(msg,sender)
end

-- raw combat-log hook + debug
local eventFrame=CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:SetScript("OnEvent",function(_,event)
  if event~="COMBAT_LOG_EVENT_UNFILTERED" then return end
  local _,subEvent,_,srcGUID,srcName,_,_,dstGUID,dstName,_,_,spellId,spellName=
    CombatLogGetCurrentEventInfo()
  -- debug print
  DEFAULT_CHAT_FRAME:AddMessage(
    "|cff88ff00[CLT Debug]|r subEvent="..tostring(subEvent)..
    " src="..tostring(srcName).." dst="..tostring(dstName)
  )
  if not srcName then return end
  if not GetClassByName(srcName) then return end

  local msgText
  if subEvent=="SPELL_CAST_SUCCESS" then
    msgText=spellName.." → "..(dstName or "unknown")
  elseif subEvent:find("HEAL") then
    msgText=spellName.." healed "..(dstName or "unknown")
  elseif subEvent=="SPELL_AURA_APPLIED" then
    msgText=(srcName==UnitName("player") and "You gain "..spellName)
         or (spellName.." applied to "..(dstName or "unknown"))
  elseif subEvent=="SPELL_AURA_REMOVED" then
    msgText=(dstName==UnitName("player") and spellName.." fades from you")
         or (spellName.." fades from "..(dstName or "unknown"))
  else return end

  AddLogLine(msgText,srcName)
end)

DEFAULT_CHAT_FRAME:AddMessage("|cffe5b3e5ClassLogTracker Loaded. Type /classlog to open.|r")
SLASH_CLASSLOG1="/classlog"
SlashCmdList["CLASSLOG"]=function() ClassLogTracker:CreateUI() end
