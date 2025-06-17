-- RaidRecon.lua

RaidRecon = {}
local RR = RaidRecon

-- toggle this to true to see every log line in chat as well
RR.debug = false

-- state
RR.filterType    = "party"
RR.selectedClass = nil
RR.logLines      = {}

-- helpers
local function mod(a,b) return a - math.floor(a/b)*b end
local function normalized(s) return (s or ""):lower():gsub("[^%a]","") end

local classList = { "Warrior","Paladin","Priest","Rogue","Warlock","Mage","Shaman","Druid","Hunter" }
local classColors = {
  Warrior={1,0.78,0.55}, Paladin={0.96,0.55,0.73}, Priest={1,1,1},
  Rogue={1,0.96,0.41},   Warlock={0.58,0.51,0.79}, Mage={0.41,0.8,0.94},
  Shaman={0,0.44,0.87},  Druid={1,0.49,0.04},     Hunter={0.67,0.83,0.45},
}

local function GetClassByName(name)
  local n = normalized(name)
  if normalized(UnitName("player"))==n then return UnitClass("player") end
  for i=1,4 do
    if normalized(UnitName("party"..i))==n then return UnitClass("party"..i) end
  end
  for i=1,40 do
    if normalized(UnitName("raid"..i))==n then return UnitClass("raid"..i) end
  end
  return nil
end

local function AddLogLine(msg,sender)
  local cls = GetClassByName(sender)
  if not cls then return end

  RR.logLines[cls] = RR.logLines[cls] or {}
  table.insert(RR.logLines[cls], msg)
  if table.getn(RR.logLines[cls]) > 200 then
    table.remove(RR.logLines[cls], 1)
  end

  -- debug in chat if you’ve turned it on
  if RR.debug then
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cff00ced1[RaidRecon]|r ["..cls.."] "..msg
    )
  end

  if cls == RR.selectedClass then
    RR:UpdateLogText()
  end
end

function RR:UpdateLogText()
  if not self.text then return end
  local buf = self.selectedClass and self.logLines[self.selectedClass]
  if not buf or table.getn(buf)==0 then
    self.text:SetText("No data for "..(self.selectedClass or "none"))
  else
    self.text:SetText(table.concat(buf, "\n"))
  end
end

function RR:ToggleFilterType(button)
  RR.filterType = (RR.filterType=="party") and "raid" or "party"
  if button then button:SetText("Filter: "..RR.filterType) end
  if RR.frame then RR.frame.title:SetText("Filter: "..RR.filterType) end
end

function RR:CreateUI()
  if RR.frame then
    RR.frame:Show()
    return
  end
  RR.logLines = {}

  -- Main frame
  local f = CreateFrame("Frame","RRFrame",UIParent)
  f:SetWidth(600); f:SetHeight(500)
  f:SetPoint("CENTER",UIParent,"CENTER",0,0)
  f:SetBackdrop{
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize=16, edgeSize=16,
    insets   = { left=4, right=4, top=4, bottom=4 },
  }
  f:SetBackdropColor(0,0,0,0.9)
  f:EnableMouse(true); f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

  -- Close button
  local close = CreateFrame("Button",nil,f,"UIPanelCloseButton")
  close:SetPoint("TOPRIGHT",f,-6,-6)
  close:SetScript("OnClick", function() f:Hide() end)

  -- Title
  f.title = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  f.title:SetPoint("TOP",f,"TOP",0,-12)
  f.title:SetText("Filter: "..RR.filterType)

  -- ChatLog toggle
  local cb = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
  cb:SetWidth(100); cb:SetHeight(24)
  cb:SetPoint("TOPLEFT",f,16,-40)
  cb:SetText("ChatLog")
  cb:SetScript("OnClick", function() SlashCmdList["CHATLOG"]("") end)

  -- Filter toggle
  local fb = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
  fb:SetWidth(100); fb:SetHeight(24)
  fb:SetPoint("LEFT",cb,"RIGHT",8,0)
  fb:SetText("Filter: "..RR.filterType)
  fb:SetScript("OnClick", function() RR:ToggleFilterType(fb) end)
  RR.filterButton = fb

  -- Class buttons
  local perRow,sx,sy,ox,oy = 6,90,28,16,-80
  for i,cls in ipairs(classList) do
    local btn = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    btn:SetWidth(80); btn:SetHeight(24)
    local row = math.floor((i-1)/perRow)
    local col = mod(i-1,perRow)
    btn:SetPoint("TOPLEFT",f,ox+col*sx,oy-row*sy)
    btn:SetText(cls)
    local r,g,b = unpack(classColors[cls])
    btn:GetFontString():SetTextColor(r,g,b)
    btn:SetScript("OnClick", function()
      RR.selectedClass = cls
      RR:UpdateLogText()
    end)
  end

  -- Scrollable EditBox
  local scroll = CreateFrame("ScrollFrame","RRScroll",f,"UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT",f,16,-250)
  scroll:SetPoint("BOTTOMRIGHT",f,-32,16)

  local edit = CreateFrame("EditBox",nil,scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(540)
  edit:SetHeight(230)        -- **you need a real height!**
  edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
  scroll:SetScrollChild(edit)

  RR.text  = edit
  RR.frame = f

  -- Default to first class so you don’t see “none”
  RR.selectedClass = classList[1]
  RR:UpdateLogText()
end

-- Combat log hook
local ef = CreateFrame("Frame")
ef:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ef:SetScript("OnEvent", function(_,_,...)
  local _,se,_,_,src,_,_,_,dst = CombatLogGetCurrentEventInfo()
  if not src then return end

  local inG = (RR.filterType=="party" and (src==UnitName("player") or UnitInParty(src)))
          or (RR.filterType=="raid"  and (src==UnitName("player") or UnitInRaid(src)))
  if not inG then return end

  if se~="SPELL_CAST_SUCCESS" and not se:find("HEAL")
     and se~="SPELL_AURA_APPLIED" and se~="SPELL_AURA_REMOVED" then return end

  local _,_,_,_,_,_,_,_,_,_,_,_,sp = CombatLogGetCurrentEventInfo()
  local msg
  if se=="SPELL_CAST_SUCCESS" then
    msg = sp.." → "..(dst or"unknown")
  elseif se:find("HEAL") then
    msg = sp.." healed "..(dst or"unknown")
  elseif se=="SPELL_AURA_APPLIED" then
    msg = (src==UnitName("player") and "You gain "..sp)
        or (sp.." applied to "..(dst or"unknown"))
  else
    msg = sp.." fades from "..(dst or"unknown")
  end

  AddLogLine(msg,src)
end)

-- slash
SLASH_RAIDRECON1 = "/raidrecon"
SlashCmdList["RAIDRECON"] = function() RR:CreateUI() end

-- load notice
DEFAULT_CHAT_FRAME:AddMessage("|cff00ced1RaidRecon loaded. Type /raidrecon to open.|r")
