-- @description Context Selection
-- @author saxmand
-- @version 0.10
-- @provides 
--   [main=midi_editor] .  > Saxmand_Context Selection.lua
-- @link https://ankarfeldt.dk
-- @donation https://paypal.me/saxmand
-- @Repository URI: github.com/saxmand/reaper.git

midiResolution = 960
-- Get the active MIDI editor
local midiEditor = reaper.MIDIEditor_GetActive()
if not midiEditor then
    --reaper.ShowMessageBox("No active MIDI editor found.", "Error", 0)
    return
end

-- Get the active MIDI take
local take = reaper.MIDIEditor_GetTake(midiEditor)
if not take then
    --reaper.ShowMessageBox("No active MIDI take found.", "Error", 0)
    return
end

local noteNames = {"C","C#","D","Eb","E","F","F#","G","G#","A","Bb","B"}


selectPosInBar = false
selectPosInBeat = false
selectChannel = false
selectPitch = true
selectVel = false
selectMuted = false

ctrl = 4096
shift = ctrl*2
alt = shift*2
cmd = alt*2
ctrlAlt = ctrl+alt
ctrlShift = ctrl+shift
altShift = alt+shift
ctrlAltShift = ctrl+alt+shift
cmdShift = cmd+shift
altCmd = alt+cmd
altCmdShift = alt+cmd+shift

local selectedEvents = {}
local lowest = {}
local highest = {}

extStateSection = "ContextSelection"
extStateKey = "Main"

defaultSelectSettings = { 
  ["numberOn"] = true,
  ["number"] = "equal",
  ["numberRangeBelow"] = 0,
  ["numberRangeAbove"] = 0,
  ["amountOn"] = false,
  ["amount"] = "equal",
  ["amountRangeBelow"] = 0,
  ["amountRangeAbove"] = 0,
  ["channelOn"] = false,
  ["channel"] = "equal",
  ["channelRangeBelow"] = 0,
  ["channelRangeAbove"] = 0,
  ["posOn"] = false,
  ["pos"] = "equal", 
  ["posRangeBelow"] = 0,
  ["posRangeAbove"] = 0,
  ["posIsInBar"] = true,
  ["lengthPPQOn"] = false,
  ["lengthPPQ"] = "equal",
  ["lengthPPQRangeBelow"] = 0,
  ["lengthPPQRangeAbove"] = 0,
  ["mutedOn"] = false,
  ["muted"] = "Include",
  ["insideTimeSelectionOn"] = false,
  ["beforeCursorOn"] = false,
  ["afterCursorOn"] = false,
  ["showHelpOn"] = true,
  ["lastEdited"] = "pos",
  ["update"] = "On Focus",
  ["keepFocus"] = false,
--  ["liveUpdate"] = false,
  ["onlyFocusedTakeOn"] = false,
  ["focus"] = "Manually",
}

  

function tableEquals(table1, table2)
    -- Check if both parameters are tables
    if type(table1) ~= "table" or type(table2) ~= "table" then
        return false
    end
    
    -- Check if the number of elements is the same
    if #table1 ~= #table2 then
        return false
    end
    
     -- Check if each element in table1 exists in table2
    for index, event in ipairs(table1) do
      event2 = table2[index]
      for key, value in ipairs(event) do
        if event2[key] ~= value then
            return false
        end
      end
    end
    
    -- If all checks pass, the tables are equal
    return true
end

------------- 
-- SETTINGS PRESETS

local MacOs = string.find(reaper.GetOS(), "OS") ~= nil
--local windows = string.find(r.GetOS(), "Win") ~= nil
local separator = MacOs and '/' or '\\'
local appName = "Context Selection"

function ensureFolderExistsOld(folderPath)
    local command = 'dir "' .. folderPath .. '"'
    local handle = io.popen(command)
    local result = handle:read('*a')
    handle:close()
    if result == nil or result:match("File Not Found") then
      reaper.ShowConsoleMsg(folderPath .. "\n")
      -- create folders
      commandLine = "mkdir -p " .. '"' .. folderPath .. '"'
      os.execute(commandLine)
    end
end

function ensureFolderExists(folderPath)
    if not reaper.file_exists(folderPath) then
      -- create folders
      commandLine = "mkdir -p " .. '"' .. folderPath .. '"'
      os.execute(commandLine)
    end
end


function getDataPath()
  resourcePath = reaper.GetResourcePath()
  dataPath = resourcePath .. separator .."Data"
  ensureFolderExists(dataPath)
  dataPath = dataPath ..separator.."Saxmand"
  ensureFolderExists(dataPath)
  dataPath = dataPath ..separator .. appName
  ensureFolderExists(dataPath)
  return dataPath
end

function writeFile(filePath, text)
  file, err = io.open(filePath, "r") 
  if not file then
    -- create file
    commandLine = "touch " .. '"' .. filePath .. '"'
    os.execute(commandLine)
    -- wait a bit to get the file created
    local endTime = reaper.time_precise() + 3
    reaper.defer(function()
      if reaper.time_precise() < endTime then
          return
      end
    end)
    
  end
  file, err = io.open(filePath, "w")
  -- open plugin and add title
  file:write(text) 
  -- Close the file
  file:close()
end

function getAllTextFilesInFolder(folderPath)
    local textFiles = {}
    counter = 0
    fileName = reaper.EnumerateFiles(folderPath, counter)
    while fileName do
        if fileName:match("%.txt$") then
            fileNameWithoutExtension = fileName:gsub(".txt","")
            table.insert(textFiles, fileNameWithoutExtension)
        end
        counter = counter + 1
        fileName = reaper.EnumerateFiles(folderPath, counter)
    end
    return textFiles
end

function storeLastSettings(data)
  filePath = getDataPath() ..separator .. "Last Settings" .. ".txt"
  dataStr = pickle(data)
  writeFile(filePath,dataStr)
end

function loadLastSettings()
  filePath = getDataPath() .. "/" .. "Last Settings" .. ".txt"
  file = io.open(filePath, "r")
  if file then
    fileStr = file:read("*a")
    file:close()
    data = unpickle(fileStr)
    return data
  else 
    return false 
  end
end


function storePreset()
  if not currentPreset then _, currentPreset = reaper.GetTrackName(reaper.GetSelectedTrack(0,0)) end
  save, name = reaper.GetUserInputs("Store settings",1,"Name",currentPreset)
  if save then 
    filePath = getDataPath() ..separator .. name .. ".txt"
    settingsStr = pickle(settings)
    writeFile(filePath,settingsStr)
    currentPreset = name
  end
end



--------------------------------------------------------------------------------
-- Pickle table serialization - Steve Dekorte, http://www.dekorte.com, Apr 2000
--------------------------------------------------------------------------------
function pickle(t)
  return Pickle:clone():pickle_(t)
end
--------------------------------------------------------------------------------
Pickle = {
  clone = function (t) local nt = {}
  for i, v in pairs(t) do 
    nt[i] = v 
  end
  return nt 
end 
}
--------------------------------------------------------------------------------
function Pickle:pickle_(root)
  if type(root) ~= "table" then 
    error("can only pickle tables, not " .. type(root) .. "s")
  end
  self._tableToRef = {}
  self._refToTable = {}
  local savecount = 0
  self:ref_(root)
  local s = ""
  while #self._refToTable > savecount do
    savecount = savecount + 1
    local t = self._refToTable[savecount]
    s = s .. "{\n"
    for i, v in pairs(t) do
      s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
    end
  s = s .. "},\n"
  end
  return string.format("{%s}", s)
end
--------------------------------------------------------------------------------
function Pickle:value_(v)
  local vtype = type(v)
  if     vtype == "string" then return string.format("%q", v)
  elseif vtype == "number" then return v
  elseif vtype == "boolean" then return tostring(v)
  elseif vtype == "table" then return "{"..self:ref_(v).."}"
  else error("pickle a " .. type(v) .. " is not supported")
  end 
end
--------------------------------------------------------------------------------
function Pickle:ref_(t)
  local ref = self._tableToRef[t]
  if not ref then 
    if t == self then error("can't pickle the pickle class") end
    table.insert(self._refToTable, t)
    ref = #self._refToTable
    self._tableToRef[t] = ref
  end
  return ref
end
--------------------------------------------------------------------------------
-- unpickle
--------------------------------------------------------------------------------
function unpickle(s)
  if type(s) ~= "string" then
    error("can't unpickle a " .. type(s) .. ", only strings")
  end
  local gentables = load("return " .. s)
  tables = gentables()
  for tnum = 1, #tables do
    local t = tables[tnum]
    local tcopy = {}
    for i, v in pairs(t) do tcopy[i] = v end
    for i, v in pairs(tcopy) do
      local ni, nv
      if type(i) == "table" then ni = tables[i[1]] else ni = i end
      if type(v) == "table" then nv = tables[v[1]] else nv = v end
      t[i] = nil
      t[ni] = nv
    end
  end
  return tables[1]
end
--------------------------------------------------------------------------------
-- Extra Table Functions
--------------------------------------------------------------------------------
function ClearTable(t) -- set all items in table 't' to nil  
  local debug = false
  if debug then
    msg("ClearTable()")
  end
  for i, v in ipairs(t) do
    t[i] = nil
  end
end
------------------------------------------------------------
function CopyTable(t1, t2) -- copies indexed table data from t1 to t2
  ClearTable(t2)
  local i = 1
  while t1[i] do
    local j = 1
    t2[i] = {}    
    while (t1[i][j] ~= nil) do
      t2[i][j] = t1[i][j]
      j = j + 1
    end
    i = i + 1
  end
end
--------------------------------------------------------------------------------
-- Debug Utility
--------------------------------------------------------------------------------
function msg(...)
  local Table = {...}
  for i = 1, #Table do
    reaper.ShowConsoleMsg(tostring(Table[i])..'\n')
  end
end

----------------------------------------------

function TableCompareNoOrder(table1, table2)
    if #table1 ~= #table2 then return false end
    -- Consider an early "return true" if table1 == table2 here
    local t1_counts = {}
    -- Check if the same elements occur the same number of times
    for _, v1 in ipairs(table1) do
        t1_counts[v1] = (t1_counts[v1] or 0) + 1
    end
    for _, v2 in ipairs(table2) do
        local count = t1_counts[v2] or 0
        if count == 0 then return false end
        t1_counts[v2] = count - 1
    end
    return true
end


function deepcompare(t1,t2,ignore_mt)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then return false end
  -- non-table types can be directly compared
  if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
  -- as well as tables which have the metamethod __eq
  local mt = getmetatable(t1)
  if not ignore_mt and mt and mt.__eq then return t1 == t2 end
  for k1,v1 in pairs(t1) do
  local v2 = t2[k1]
  if v2 == nil or not deepcompare(v1,v2) then return false end
  end
  for k2,v2 in pairs(t2) do
  local v1 = t1[k2]
  if v1 == nil or not deepcompare(v1,v2) then return false end
  end
  return true
end

----------------------------------------------
  
function getSelectedEvents()
   _, notes, ccs, _ = reaper.MIDI_CountEvts(take)
  if reaper.MIDI_EnumSelNotes(take,-1) ~= -1 then isNotes = true else isNotes = false end
  
  if isNotes then
    eventCount = notes
  else
    eventCount = ccs
  end
  
  newSelectedEvents = {}
  for i = 0, eventCount - 1 do
      if isNotes then
         _, selected, muted, startPPQ, endPPQ, channel, number, amount = reaper.MIDI_GetNote(take, i)
         lengthPPQ = endPPQ - startPPQ
      else
         _, selected, muted, startPPQ, chanmsg, channel, number, amount = reaper.MIDI_GetCC(take, i)
        --local endPPQ = nil
        lengthPPQ = 0
      end
      
      if selected then 
          local startOfMeasurePpq = reaper.MIDI_GetPPQPos_StartOfMeasure( take, startPPQ )
          local posInBar = startPPQ - startOfMeasurePpq
          local posInBeat = (startPPQ - startOfMeasurePpq)%midiResolution
          
          if isNotes then name = noteNames[number%12+1] .. math.floor(number/12)-2 else name = "CC" .. number end
          
          local noteInfo = {
          ["selected"] = selected, 
          ["muted"] = muted, 
          ["startPPQ"] = startPPQ, 
          ["endPPQ"] = endPPQ, 
          ["lengthPPQ"] = lengthPPQ, 
          ["posInBar"] = posInBar, 
          ["posInBeat"] = posInBeat, 
          ["channel"] = channel, 
          ["name"] = name, 
          ["number"] = number, 
          ["amount"] = amount,
          ["active"] = true,
          ["index"] = i
          }
          table.insert(newSelectedEvents, noteInfo)
      end
  end
  return newSelectedEvents
end

function findHighestLowest(selectedEvents) 
  lowest = {}
  highest = {}
  for e, info in ipairs(selectedEvents) do
    if not lowest.number or lowest.number > info.number or #selectedEvents == 1 then lowest.number = info.number end
    if not highest.number or highest.number < info.number or #selectedEvents == 1 then highest.number = info.number end
    
    if not lowest.amount or lowest.amount > info.amount or #selectedEvents == 1 then lowest.amount = info.amount end
    if not highest.amount or highest.amount < info.amount or #selectedEvents == 1 then highest.amount = info.amount end
    
    if not lowest.channel or lowest.channel > info.channel or #selectedEvents == 1 then lowest.channel = info.channel end
    if not highest.channel or highest.channel < info.channel or #selectedEvents == 1 then highest.channel = info.channel end
    
    if not lowest.posInBar or lowest.posInBar > info.posInBar or #selectedEvents == 1 then lowest.posInBar = info.posInBar end
    if not highest.posInBar or highest.posInBar < info.posInBar or #selectedEvents == 1 then highest.posInBar = info.posInBar end
    
    if not lowest.posInBeat or lowest.posInBeat > info.posInBeat or #selectedEvents == 1 then lowest.posInBeat = info.posInBeat end
    if not highest.posInBeat or highest.posInBeat < info.posInBeat or #selectedEvents == 1 then highest.posInBeat = info.posInBeat end
    
    if not lowest.lengthPPQ or lowest.lengthPPQ > info.lengthPPQ or #selectedEvents == 1 then lowest.lengthPPQ = info.lengthPPQ end
    if not highest.lengthPPQ or highest.lengthPPQ < info.lengthPPQ or #selectedEvents == 1 then highest.lengthPPQ = info.lengthPPQ end
  end
end


function selectNewEventsInTake(selectedEvents,specificTake) 
  reaper.MIDI_DisableSort(specificTake)
  reaper.MIDI_SelectAll(specificTake,false)
  
  for i = 0, notes - 1 do
    if isNotes then
      _, selected, muted, startPPQ, endPPQ, channel, number, amount = reaper.MIDI_GetNote(specificTake, i)
      lengthPPQ = endPPQ - startPPQ
    else
      _, selected, muted, startPPQ, chanmsg, channel, number, amount = reaper.MIDI_GetCC(take, i)
      selectSettings.lengthPPQOn = false
    end
    startOfMeasurePpq = reaper.MIDI_GetPPQPos_StartOfMeasure( specificTake, startPPQ )
    endOfMeasurePpq = reaper.MIDI_GetPPQPos_EndOfMeasure(specificTake,startPPQ+1)
    cursorInTake = reaper.MIDI_GetPPQPosFromProjTime(specificTake, reaper.GetCursorPosition())
    loopStart, loopEnd = reaper.GetSet_LoopTimeRange(false,false,0,0,false)
    loopStartInTake = reaper.MIDI_GetPPQPosFromProjTime(specificTake, loopStart)
    loopEndInTake = reaper.MIDI_GetPPQPosFromProjTime(specificTake, loopEnd)
    --local startOfMeasurePpq = reaper.MIDI_GetPPQPos_StartOfMeasure( specificTake, startPPQ )
    local posInBar = startPPQ - startOfMeasurePpq
    local posInBeat = (startPPQ - startOfMeasurePpq)%midiResolution
    
    
    _types = {"pos","number","amount","channel","lengthPPQ","muted"}
    if selectSettings.posIsInBar then
      typeValues = {posInBar,number,amount,channel,lengthPPQ,muted}
    else
      typeValues = {posInBeat,number,amount,channel,lengthPPQ,muted}
    end
    
    selectEvent = true
    for t, _type in ipairs(_types) do 
      if selectSettings.beforeCursorOn and cursorInTake <= startPPQ then
        selectEvent = false
      elseif selectSettings.afterCursorOn and cursorInTake > startPPQ then
        selectEvent = false
      end
      if selectSettings.insideTimeSelectionOn and (loopStartInTake > startPPQ or loopEndInTake <= startPPQ) then
        selectEvent = false
      end
      
      if selectEvent then 
        if not selectSettings[_type .. "On"] then
          --reaper.ShowConsoleMsg(_type .. "\n")
          selectEvent = true
        else
          if _type == "muted" then
            if selectSettings[_type] == "Include" then
              selectEvent = true
            elseif selectSettings[_type] == "Exclude" and not muted then
              selectEvent = true
            elseif selectSettings[_type] == "Only Muted" and muted then
              selectEvent = true
            else
              selectEvent = false
            end 
          elseif _type == "pos" then 
            if selectSettings.posIsInBar then
              textPos = "InBar"
              posValueExtensionStart = startOfMeasurePpq
              posValueExtensionEnd = endOfMeasurePpq - startOfMeasurePpq
            else
              textPos = "InBeat"
              posValueExtensionEnd = midiResolution
            end            
            posFound = false
            for _, info in ipairs(selectedEvents) do
              -- could consider to only check all events on "equal" as there's some unnessesary processing here. 
              if info.active then
                if selectSettings[_type] == "equal" then
                  lowestValue = info[_type .. textPos] + selectSettings[_type.."RangeBelow"]
                  highestValue = info[_type .. textPos] + selectSettings[_type.."RangeAbove"]
                elseif selectSettings[_type] == "lower" then
                  lowestValue = 0  + selectSettings[_type.."RangeBelow"]
                  highestValue = lowest[_type .. textPos] + selectSettings[_type.."RangeAbove"] - 1
                elseif selectSettings[_type] == "lowerEqual" then
                  lowestValue = 0  + selectSettings[_type.."RangeBelow"]
                  highestValue = lowest[_type .. textPos] + selectSettings[_type.."RangeAbove"]
                elseif selectSettings[_type] == "higher" then
                  lowestValue = highest[_type .. textPos] + selectSettings[_type.."RangeBelow"] + 1
                  highestValue = posValueExtension + selectSettings[_type.."RangeAbove"]-1
                elseif selectSettings[_type] == "higherEqual" then
                  lowestValue = highest[_type .. textPos] + selectSettings[_type.."RangeBelow"]
                  highestValue = posValueExtension + selectSettings[_type.."RangeAbove"]-1
                elseif selectSettings[_type] == "inRange" then
                  lowestValue = lowest[_type .. textPos] + selectSettings[_type.."RangeBelow"] + 1
                  highestValue = highest[_type .. textPos] + selectSettings[_type.."RangeAbove"] - 1
                elseif selectSettings[_type] == "inRangeEqual" then
                  lowestValue = lowest[_type .. textPos] + selectSettings[_type.."RangeBelow"]
                  highestValue = highest[_type .. textPos] + selectSettings[_type.."RangeAbove"]
                end
                --reaper.ShowConsoleMsg(lowestValue .. "  " .. highestValue .. "  " ..  typeValues[t] .. "  " .. posValueExtensionEnd.."\n")
                if lowestValue <= typeValues[t] and highestValue >= typeValues[t] then
                  posFound = true
                elseif lowestValue < 0 and (lowestValue + posValueExtensionEnd) % posValueExtensionEnd <= typeValues[t] then
                  posFound = true
                elseif highestValue >= posValueExtensionEnd and highestValue - posValueExtensionEnd >= typeValues[t] then
                  posFound = true
                elseif highestValue < 0 and (highestValue + posValueExtensionEnd) % posValueExtensionEnd <= typeValues[t] then
                  posFound = true
                elseif lowestValue >= posValueExtensionEnd and lowestValue - posValueExtensionEnd >= typeValues[t] then
                  posFound = true
                end
              end
            end
            selectEvent = posFound
          else            
            eventFound = false
            for _, info in ipairs(selectedEvents) do
              -- could consider to only check all events on "equal" as there's some unnessesary processing here. 
              -- in here it would require to split up and not have the things as one long search line, so change it to what's above
              -- maybe possible to combine
              if info.active then                 
                if                 
                (selectSettings[_type] == "equal" and info[_type] + selectSettings[_type.."RangeBelow"]  <= typeValues[t] and info[_type] + selectSettings[_type.."RangeAbove"] >= typeValues[t] ) or
                (selectSettings[_type] == "lower" and lowest[_type] + selectSettings[_type.."RangeAbove"] > typeValues[t] + selectSettings[_type.."RangeBelow"]) or
                (selectSettings[_type] == "lowerEqual" and highest[_type] + selectSettings[_type.."RangeAbove"] >= typeValues[t] + selectSettings[_type.."RangeBelow"]) or
                (selectSettings[_type] == "higher" and highest[_type] + selectSettings[_type.."RangeBelow"] < typeValues[t] + selectSettings[_type.."RangeAbove"]) or
                (selectSettings[_type] == "higherEqual" and lowest[_type] + selectSettings[_type.."RangeBelow"] <= typeValues[t] + selectSettings[_type.."RangeAbove"]) or
                (selectSettings[_type] == "inRange" and lowest[_type] + selectSettings[_type.."RangeBelow"] < typeValues[t] and highest[_type] + selectSettings[_type.."RangeAbove"] > typeValues[t]) or
                (selectSettings[_type] == "inRangeEqual" and lowest[_type] + selectSettings[_type.."RangeBelow"] <= typeValues[t] and highest[_type] + selectSettings[_type.."RangeAbove"] >= typeValues[t]) or
                ( _type == "number" and selectSettings[_type] == "equalAllOctaves" and info[_type]%12 == typeValues[t]%12) then
                  --reaper.ShowConsoleMsg(_type .. "\n")
                  eventFound = true
                end
              end
            end
            selectEvent = eventFound
          end
        end
      end
    end
    if selectEvent then
      if isNotes then
        reaper.MIDI_SetNote(specificTake,i,true)
      else
        reaper.MIDI_SetCC(specificTake,i,true)
      end
    end
  end
  reaper.MIDI_Sort(specificTake)
end

function unselectAllEvents() 
  local numSelectedItems = reaper.CountSelectedMediaItems(0)
  for i = 0, numSelectedItems - 1 do
    
    local selectedItem = reaper.GetSelectedMediaItem(proj, i)
    
    -- Get the active take of the selected media item
    local specificTake = reaper.GetActiveTake(selectedItem)
    reaper.MIDI_SelectAll(specificTake,false)
  end
end

function selectNewEvents(selectedEvents)
  findHighestLowest(selectedEvents)

  -- Get the number of selected media items
  local numSelectedItems = reaper.CountSelectedMediaItems(0)
  
  -- Check if there are selected media items
  if numSelectedItems > 0 and not selectSettings.onlyFocusedTakeOn then 
  
    -- Iterate through selected media items
    for i = 0, numSelectedItems - 1 do
      
      local selectedItem = reaper.GetSelectedMediaItem(proj, i)
      
      -- Get the active take of the selected media item
      local specificTake = reaper.GetActiveTake(selectedItem)
      selectNewEventsInTake(selectedEvents,specificTake) 
    end
  else
    if selectSettings.onlyFocusedTakeOn then
      unselectAllEvents() 
    end
    selectNewEventsInTake(selectedEvents,take) 
  end
end  

getDataPath()
selectSettings = loadLastSettings()
if not selectSettings then
  selectSettings = defaultSelectSettings
end
  
--selectSettings = defaultSelectSettings

selectedEvents = getSelectedEvents()
previousSelectedEvents = selectedEvents
selectNewEvents(selectedEvents)

local ctx = reaper.ImGui_CreateContext('midiContextSelection')
local font = reaper.ImGui_CreateFont('sans-serif',14)
local font10 = reaper.ImGui_CreateFont('sans-serif',10)
local font12 = reaper.ImGui_CreateFont('sans-serif',12)
local font13 = reaper.ImGui_CreateFont('sans-serif',13)
local font18 = reaper.ImGui_CreateFont('sans-serif',18)
--sans_serif = reaper.ImGui_CreateFont('Arial', 13)
reaper.ImGui_Attach(ctx, font)
reaper.ImGui_Attach(ctx, font10)
reaper.ImGui_Attach(ctx, font12)
reaper.ImGui_Attach(ctx, font13)
reaper.ImGui_Attach(ctx, font18)
local state = 0
local statusText = ""
waitForFocused = 0
waitForFocusABit = -1
focusCounter = 0
isFocused = true
--reaper.ImGui_SetNextWindowSize(ctx,600,380)
local function loop()
--local ImGui = require 'imgui' '0.9'
  
  local rounding = 3
  reaper.ImGui_PushStyleVar(ctx,reaper.ImGui_StyleVar_WindowRounding(),rounding*2) 
  reaper.ImGui_PushStyleVar(ctx,reaper.ImGui_StyleVar_ChildRounding(),0)
  reaper.ImGui_PushStyleVar(ctx,reaper.ImGui_StyleVar_FrameRounding(),0)
  
  visible, open = reaper.ImGui_Begin(ctx, 'main', true,    
    reaper.ImGui_WindowFlags_TopMost() -- | reaper.ImGui_WindowFlags_NoMove()
    | reaper.ImGui_WindowFlags_NoTitleBar()
    | reaper.ImGui_WindowFlags_NoResize()
    --| reaper.ImGui_WindowFlags_NoDocking()
    --| reaper.ImGui_WindowFlags_NoBackground()
    | reaper.ImGui_WindowFlags_NoScrollbar()
    | reaper.ImGui_WindowFlags_AlwaysAutoResize()
    
    
    )
 --reaper.ImGui_WindowFlags_NoDecoration() |  
 -- | reaper.ImGui_WindowFlags_NoBackground()
 -- | reaper.ImGui_FocusedFlags_None()
  if visible then  
    
    
    if waitForFocused > 10 then
        focusedPopupWindow = reaper.JS_Window_GetFocus()
        reaper.SetExtState(extStateSection,extStateKey,reaper.BR_Win32_HwndToString(focusedPopupWindow),false)
        waitForFocused = -1
        isFocused = true
    end
    if waitForFocused > -1 then waitForFocused = waitForFocused + 1 end
    
    local TEXT_BASE_WIDTH  = reaper.ImGui_CalcTextSize(ctx, 'A')
    local TEXT_BASE_HEIGHT = reaper.ImGui_GetTextLineHeightWithSpacing(ctx)
    
    function helpMarker(desc)
      --reaper.ImGui_TextDisabled(ctx, '(?)')
      if selectSettings.showHelpOn and reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_DelayShort()) and reaper.ImGui_BeginTooltip(ctx) then
        
        reaper.ImGui_PushStyleColor(ctx,reaper.ImGui_Col_Text(),0xFFFFFFFF)
        reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
        reaper.ImGui_Text(ctx, desc)
        reaper.ImGui_PopStyleColor(ctx)
        reaper.ImGui_PopTextWrapPos(ctx)
        reaper.ImGui_EndTooltip(ctx)
      end
    end
    
    function pushGreyWhiteColor(white)
      if white then  
        reaper.ImGui_PushStyleColor(ctx,reaper.ImGui_Col_Text(),0xFFFFFFFF) 
      else  
        reaper.ImGui_PushStyleColor(ctx,reaper.ImGui_Col_Text(),0x555555FF) 
      end
    end
    
    reaper.ImGui_PushFont(ctx,font)
    
    --reaper.ImGui_PushStyleVar(ctx,reaper.ImGui_StyleVar_FrameRounding(),20)
    reaper.ImGui_PushFont(ctx,font12)
    if reaper.ImGui_Button(ctx,"X") then
      open = false
    end
    helpMarker('Press "Escape" to close app')
    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_SameLine(ctx)
    
    reaper.ImGui_SameLine(ctx,130)
    pushGreyWhiteColor(isFocused)
    reaper.ImGui_PushFont(ctx,font18)
    reaper.ImGui_Text(ctx,"MIDI CONTEXT SELECTION")
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_PopFont(ctx)
    
    reaper.ImGui_SameLine(ctx,458)
    
    reaper.ImGui_PushFont(ctx,font12)
    if reaper.ImGui_Selectable(ctx,"HELP",selectSettings.showHelpOn,nil,36) then
      setSettings("showHelp")
    end 
    helpMarker("When enabled, a popups help window will show when hovering over things. Press H to toggle")
    reaper.ImGui_PopFont(ctx)
    --if reaper.ImGui_Button(ctx,"Update Context") or (reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_U(),false) and not reaper.ImGui_IsKeyDown(ctx,reaper.ImGui_Mod_Super())) then
    --  selectedEvents = getSelectedEvents()
    --  setSettings()
    --end 
    --helpMarker('Press U or click to update context')
    -- reaper.ImGui_NewLine(ctx)
    
    function setSettings(columnName,rowSetting,doNotSetLastEdited)
      if columnName then
        if columnName == "posIsInBar" then
          selectSettings[columnName] = rowSetting
          selectSettings["posOn"] = true
        else
          if not rowSetting then
            --if selectSettings.lastEdited == columnName then
              selectSettings[columnName .. "On"] = not selectSettings[columnName .. "On"]
            --end
          else 
            if selectSettings[columnName] == rowSetting then
              selectSettings[columnName .. "On"] = not selectSettings[columnName .. "On"]
            else
                selectSettings[columnName .. "On"] = true
                selectSettings[columnName] = rowSetting
            end
          end 
        end 
        if not doNotSetLastEdited then
          selectSettings["lastEdited"] = columnName
        end
      end
      storeLastSettings(selectSettings)
      
      selectNewEvents(selectedEvents)
    end
    
    function selectOnlyEvent(index)
      reaper.MIDI_DisableSort(take)
      --reaper.MIDI_SelectAll(take,false)
      unselectAllEvents() 
      
      for _, info in ipairs(selectedEvents) do
        selectEvent = false
        if reaper.ImGui_GetKeyMods(ctx) == 0 then 
          if info.index == index then selectEvent = true end
        elseif reaper.ImGui_GetKeyMods(ctx) == shift then
          if info.index == index then selectEvent = true end
        elseif  reaper.ImGui_GetKeyMods(ctx) == ctrl then
          if info.index > index then selectEvent = true end
        elseif reaper.ImGui_GetKeyMods(ctx) == alt  then
          if info.index < index then selectEvent = true end
        elseif reaper.ImGui_GetKeyMods(ctx) == ctrlAlt then
          selectEvent = true
        elseif  reaper.ImGui_GetKeyMods(ctx) == ctrlShift then 
          if info.index >= index then selectEvent = true end
        elseif reaper.ImGui_GetKeyMods(ctx) == altShift  then 
          if info.index <= index then selectEvent = true end
        elseif reaper.ImGui_GetKeyMods(ctx) == ctrlAltShift then 
          selectEvent = true
        elseif reaper.ImGui_GetKeyMods(ctx) == cmd then 
          selectEvent = true
        end
        
        if selectEvent or index == -1 then
          if isNotes then
            reaper.MIDI_SetNote(take,info.index,true)
          else
            reaper.MIDI_SetCC(take,info.index,true)
          end
        end
      end
      reaper.MIDI_Sort(take)
    end
    
    types = {"Equal","Higher", "Lower", "In Range"}
    isBar = selectSettings["posIsInBar"]
    columnWidths = {64,64,64,70,64,64,36}
    
    function setupColumnTable()
      if isNotes then
        reaper.ImGui_TableSetupColumn(ctx, 'Pitch', reaper.ImGui_TableColumnFlags_WidthFixed(),columnWidths[1])
      else
        reaper.ImGui_TableSetupColumn(ctx, 'Number',reaper.ImGui_TableColumnFlags_WidthFixed(),columnWidths[1])
      end
      if isNotes then
        reaper.ImGui_TableSetupColumn(ctx, 'Velocity',reaper.ImGui_TableColumnFlags_WidthFixed(),columnWidths[2])
      else
        reaper.ImGui_TableSetupColumn(ctx, 'Value',reaper.ImGui_TableColumnFlags_WidthFixed(),columnWidths[2])
      end 
      reaper.ImGui_TableSetupColumn(ctx, 'Channel',reaper.ImGui_TableColumnFlags_WidthFixed(),columnWidths[3])
      --if isNotes then
      --end
      reaper.ImGui_TableSetupColumn(ctx, 'Position',reaper.ImGui_TableColumnFlags_WidthFixed(),columnWidths[4])
      --reaper.ImGui_TableSetupColumn(ctx, 'Beat Pos',nil,0.0)
      reaper.ImGui_TableSetupColumn(ctx, 'Length',reaper.ImGui_TableColumnFlags_WidthFixed(),columnWidths[5])
      reaper.ImGui_TableSetupColumn(ctx, 'Muted',reaper.ImGui_TableColumnFlags_WidthFixed(),columnWidths[6]) 
      reaper.ImGui_TableSetupColumn(ctx, 'Use', reaper.ImGui_TableColumnFlags_WidthFixed(),columnWidths[7]) -- removes from selection
      --reaper.ImGui_TableSetupColumn(ctx, '  ', nil,0.0) -- removes from selection
    end
    
    --collapsFlag = reaper.ImGui_WindowFlags_NoCollapse()
    --contextRet, contextShown = reaper.ImGui_CollapsingHeader(ctx, 'Context',nil,collapsFlag)
    --if contextRet then
      --if isNotes then 
      columnAmount = 6-- else columnAmount = 6 end
      flags = 
      reaper.ImGui_TableFlags_RowBg() |
      reaper.ImGui_TableFlags_BordersOuter() 
      | reaper.ImGui_TableFlags_BordersV() 
      | reaper.ImGui_TableFlags_Reorderable() 
      --| reaper.ImGui_TableFlags_BordersInnerV()
      --| reaper.ImGui_TableFlags_SizingFixedFit()
      --| reaper.ImGui_TableFlags_NoPadInnerX()
      --| reaper.ImGui_TableFlags_Resizable()
      | reaper.ImGui_TableFlags_ScrollY()
      
      --rowTypes = {"Equal", "Higher", "Lower", "Higher+Equal", "Lower+Equal", "In Range", "In Range+Equal"} 
      rowTypes = {"Equal", "Higher", "Lower", "In Range"} 
      --rowSettingTypeExtended =  {"equal", "lower", "lowerEqual" , "higher", "higherEqual" ,"inRange" , "inRangeEqual", "equalAllOctaves"}
      rowSettingType =  {"equal", "higher","lower","inRange", "equalAllOctaves"}
      --if isBar then barBeatColumnSetting = "posInBar" else  barBeatColumnSetting = "posInBeat" end
      columnNames = {"number","amount","channel","pos","lengthPPQ","muted"}
      
      for n = 0, 1 do
        if n == 0 then
          if #selectedEvents > 4 then
            --height = TEXT_BASE_HEIGHT * (6)
            height = TEXT_BASE_HEIGHT * (4*1.7) + (14-4*2)
          else
            height = TEXT_BASE_HEIGHT * (#selectedEvents*1.7) + (16-#selectedEvents*2)
          end
        else
          height = TEXT_BASE_HEIGHT * 8-6
        end
        if reaper.ImGui_BeginTable(ctx, 'table_scrollx1', columnAmount+1, flags ,0,height ) then
          if n == 0 then
            reaper.ImGui_TableSetupScrollFreeze(ctx,0,1)
          end
          --reaper.ImGui_TableSetupScrollFreeze(ctx,0,2)
          setupColumnTable()
          if n == 0 then
            reaper.ImGui_TableNextRow(ctx, reaper.ImGui_TableRowFlags_Headers())
            for column = 0, columnAmount do
              reaper.ImGui_TableSetColumnIndex(ctx, column)
              local column_name = reaper.ImGui_TableGetColumnName(ctx,column)
              if reaper.ImGui_Selectable(ctx,column_name,false) then
                local columnName = columnNames[column+1]
                setSettings(columnName,selectSettings[columnName])
              end
              helpMarker("Click to toggle")
              --reaper.ImGui_TableHeader(ctx, column_name) 
            end
            --reaper.ImGui_TableHeadersRow(ctx)
          end
          
          eventHelpText = "Click to select context event. Hold down a modifier to select all context events or click O to select context events" 
          
          if n == 0 then
            for e, event in ipairs(selectedEvents) do
              reaper.ImGui_TableNextRow(ctx)
              for column = 0,columnAmount do
                reaper.ImGui_TableNextColumn(ctx)
                --reaper.ImGui_TableSetColumnIndex(ctx, column)
                if column == 0 then if reaper.ImGui_Selectable(ctx, event.name .. "##"..e) then selectOnlyEvent(event.index) end helpMarker(eventHelpText) end
                if column == 1 then if reaper.ImGui_Selectable(ctx, event.amount) then selectOnlyEvent(event.index) end helpMarker(eventHelpText) end
                if column == 2 then if reaper.ImGui_Selectable(ctx, event.channel + 1 .. "##"..e) then selectOnlyEvent(event.index) end helpMarker(eventHelpText) end
                if column == 3 then
                  if isBar then
                    if reaper.ImGui_Selectable(ctx, event.posInBar .. "##"..e) then selectOnlyEvent(event.index) end helpMarker(eventHelpText)
                  else
                    if reaper.ImGui_Selectable(ctx, event.posInBeat .. "##"..e)  then selectOnlyEvent(event.index) end helpMarker(eventHelpText)
                  end
                end
                
                if column == 4 then if reaper.ImGui_Selectable(ctx, event.lengthPPQ .. "##"..e) then selectOnlyEvent(event.index) end helpMarker(eventHelpText) end
                if event.muted then mutedText = "Yes" else mutedText = "No" end
                if column == 5 then if reaper.ImGui_Selectable(ctx,mutedText .. "##"..e) then selectOnlyEvent(event.index) end helpMarker(eventHelpText) end
                
                if column == columnAmount then 
                  if #selectedEvents > 1 then
                    if reaper.ImGui_RadioButton(ctx, "##"..e,selectedEvents[e].active) then
                      if reaper.ImGui_GetKeyMods(ctx) == 0 then
                        selectedEvents[e].active = not selectedEvents[e].active
                      else
                        table.remove(selectedEvents,e)
                      end
                      setSettings()
                    end
                    helpMarker("Click to toggle if an event is used for context.\nAdd a modifier to remove event from list")
                  end
                end
              end 
            end
            
         else
            --reaper.ImGui_TableNextRow(ctx)
            --for column = 0,columnAmount -1 do
            --  reaper.ImGui_TableSetColumnIndex(ctx, column)
            --  reaper.ImGui_Text(ctx,"----")
            --end     
            
            --reaper.ImGui_TableNextRow(ctx)
          for column = 0,5 do
            reaper.ImGui_TableNextColumn(ctx)
            if column == 0 then
              reaper.ImGui_Spacing(ctx)
            end
            
            --reaper.ImGui_TableSetColumnIndex(ctx, column)
            columnName = columnNames[column+1]
            columnSetting = selectSettings[columnName]
            columnSettingOn = selectSettings[columnName .. 'On'] 
            if columnSettingOn then  
              reaper.ImGui_PushStyleColor(ctx,reaper.ImGui_Col_Text(),0xFFFFFFFF) 
            else  
              reaper.ImGui_PushStyleColor(ctx,reaper.ImGui_Col_Text(),0x555555FF) 
            end
            if selectSettings.lastEdited == columnName then
              reaper.ImGui_TableSetBgColor(ctx,reaper.ImGui_TableBgTarget_CellBg(),0xFFFFFF11)
            else
              reaper.ImGui_TableSetBgColor(ctx,reaper.ImGui_TableBgTarget_CellBg(),0x000000FF)
            end
            
            helpTextExtended = "\n\nUse modifiers to select filters:\ncmd = Equal\nctrl = Higher\nalt = Lower\nctrl+alt = In Range\n"
            helpTextPitch = "cmd = All Octaves\n"
            helpTextPos = "cmd = Toggle between Bar and Beat\n"
            helpTextExtended2 = "Use shift or double click to add Equal to filter"
            helpTextMuted = "\n\nshift = Include\nctrl = Exclude\nalt = Only Muted"
            if column == 0 then 
              helpText = "Press Q or N to toggle " .. columnName ..'!' .. helpTextExtended .. helpTextPitch .. helpTextExtended2
            elseif column == 1 then 
              helpText = "Press W or V to toggle " .. columnName ..'!' .. helpTextExtended .. helpTextExtended2
            elseif column == 2 then 
              helpText = "Press E or C to toggle " .. columnName ..'!' .. helpTextExtended .. helpTextExtended2
            elseif column == 3 then 
              helpText = "Press R or P to toggle " .. columnName ..'!' .. helpTextExtended .. helpTextPos .. helpTextExtended2
            elseif column == 4 then 
              helpText = "Press T or L to toggle " .. columnName ..'!' .. helpTextExtended .. helpTextExtended2
            elseif column == 5 then 
              helpText = "Press Y or M to toggle " .. columnName ..'!' ..helpTextMuted
            end
            
            reaper.ImGui_PushFont(ctx,font13)
            if column < 5 then
              for row, rowType in ipairs(rowTypes) do
                rowSetting = rowSettingType[row]
                isSelected = columnSettingOn and string.lower(columnSetting):match(string.lower(rowSetting)) ~= nil
                if reaper.ImGui_Selectable(ctx, rowType .. "##".. rowType .. ":"..columnName, isSelected,reaper.ImGui_SelectableFlags_AllowDoubleClick()) then
                  if (reaper.ImGui_IsMouseDoubleClicked(ctx,0) or reaper.ImGui_GetKeyMods(ctx) > 0) and not string.lower(rowSetting):find("equal") then
                    rowSetting = rowSetting .. "Equal" 
                    columnName = columnName
                  end 
                  setSettings(columnName,rowSetting)
                end 
                helpMarker(helpText)
              end
              
            elseif column == columnAmount-1 then
              muteRowTypes = {"Include","Exclude","Only Muted"}
              for row, rowType in ipairs(muteRowTypes) do
                rowSetting = muteRowTypes[row]
                isSelected = columnSettingOn and rowSetting == columnSetting
                if reaper.ImGui_Selectable(ctx, rowType .. "##".. rowType .. ":"..columnName, isSelected) then
                  setSettings(columnName,rowSetting)
                end
                helpMarker(helpText)
              end
            end
            
            
            if column == 0 then
              if isNotes then
                rowSetting = rowSettingType[#rowSettingType]
                isSelected = columnSettingOn and rowSetting == columnSetting
                if reaper.ImGui_Selectable(ctx, "All octaves", isSelected) then
                  setSettings(columnName,rowSetting)
                end
              else
                reaper.ImGui_Selectable(ctx,"")
              end
            end
            
            
            if column == 3 then
              rowSetting = rowSettingType[#rowSettingType]
              isSelected = columnSettingOn and rowSetting == columnSetting
              width = 80
              barIsSelected = columnSettingOn and selectSettings["posIsInBar"]
              
              pushGreyWhiteColor(barIsSelected)
              if reaper.ImGui_Selectable(ctx,"Bar", barIsSelected, nil, width/2-8)  then
                --selectSettings["posIsInBar"] = true
                --selectSettings["posInBarOn"] = true
                --selectSettings["posInBeatOn"] = false
                setSettings("posIsInBar",true)
                selectSettings.lastEdited = columnName
              end 
              helpMarker(helpText)
              reaper.ImGui_SameLine(ctx,width/2)
              beatIsOn = columnSettingOn and not selectSettings["posIsInBar"]
              pushGreyWhiteColor(beatIsOn)
              if reaper.ImGui_Selectable(ctx,"Beat", beatIsOn, nil, width/2) then
                setSettings("posIsInBar",false)
                selectSettings.lastEdited = columnName
              end 
              helpMarker(helpText)
              reaper.ImGui_PopStyleColor(ctx,2)
            end
            
            -- insert empty fields to allign things
            if column == 1 or column == 2 or  column == 4 then
              reaper.ImGui_Text(ctx,"")
            end 
            reaper.ImGui_PopFont(ctx)
            
            if column < 5 then
              --reaper.ImGui_PushStyleColor(ctx,reaper.ImGui_Col_Text(),0x555555FF)
              reaper.ImGui_PushFont(ctx,font10)
              reaper.ImGui_Spacing(ctx)
              if reaper.ImGui_Selectable(ctx, "extend range:##"..columnName,false,nil) then
                selectSettings[columnName .. "RangeBelow"] = 0
                selectSettings[columnName .. "RangeAbove"] = 0 
                setSettings()
              end
              reaper.ImGui_PopFont(ctx)
              helpMarker("Click to reset exteded range, or press 0 (zero) to reset last edited context type")
              --reaper.ImGui_PopStyleColor(ctx)
              if column > 2 then 
                extendRangeRange = 2*midiResolution
              elseif column == 2 then
                extendRangeRange = 16
              else
                extendRangeRange = 127
              end
                
              reaper.ImGui_PushFont(ctx,font12)
              halfColumnWidth = columnWidths[column+1] / 2
              reaper.ImGui_PushItemWidth(ctx, halfColumnWidth-2)
              ret1, selectSettings[columnName .. "RangeBelow"] = reaper.ImGui_DragInt(ctx,"##Below"..columnName,selectSettings[columnName .. "RangeBelow"],1,-extendRangeRange,extendRangeRange)
              if ret1 then 
                 setSettings()
              end 
              if reaper.ImGui_IsItemClicked(ctx) then
                if reaper.ImGui_GetKeyMods(ctx) ~= 0 then
                  selectSettings[columnName .. "RangeBelow"] = 0
                end 
                setSettings()
              end
              helpMarker("Drag to extend lower range of selection.\nClick with any modifier to reset to 0\nUse ctrl and numlock +/- if last edited")
              
              reaper.ImGui_SameLine(ctx,halfColumnWidth)
              ret2, selectSettings[columnName .. "RangeAbove"] = reaper.ImGui_DragInt(ctx,"##Above"..columnName,selectSettings[columnName .. "RangeAbove"],1,-extendRangeRange,extendRangeRange)
              if ret2 then  
                setSettings()
              end
              if reaper.ImGui_IsItemClicked(ctx) then
                if reaper.ImGui_GetKeyMods(ctx) ~= 0 then
                  selectSettings[columnName .. "RangeAbove"] = 0
                end
                setSettings()
              end
              helpMarker("Drag to extend upper range of selection.\nClick with any modifier to reset to 0\nUse alt and numlock +/- if last edited")
              reaper.ImGui_PopFont(ctx)
              reaper.ImGui_PopItemWidth(ctx)
              
              
            end
            
            reaper.ImGui_PopStyleColor(ctx)
          end
          
            
          
        -- if n == 0 then 
          
          
        end        
  
        
          reaper.ImGui_EndTable(ctx)
        end
    end
    
    reaper.ImGui_PushFont(ctx,font12)
    
    reaper.ImGui_PushStyleColor(ctx,reaper.ImGui_Col_Text(),0x888888FF) 
    reaper.ImGui_Text(ctx, "More selection: ") 
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_SameLine(ctx)
    
    --reaper.ImGui_PushStyleColor(ctx,reaper.ImGui_Col_Header(),0x0000BBFF)
    timeSelectionTypes = {"Inside Time Selection","Before Cursor","Beyond Cursor","Only Focused Take"}
    for s, selectType in ipairs(timeSelectionTypes) do
      
      if s == 1 then reaper.ImGui_SameLine(ctx); isSelected = selectSettings.insideTimeSelectionOn
      elseif s == 2 then reaper.ImGui_SameLine(ctx,nil,14); isSelected = selectSettings.beforeCursorOn
      elseif s == 3 then reaper.ImGui_SameLine(ctx); isSelected = selectSettings.afterCursorOn
      elseif s == 4 then reaper.ImGui_SameLine(ctx,nil,14); isSelected = selectSettings.onlyFocusedTakeOn end
      
      local width = reaper.ImGui_CalcTextSize(ctx,selectType)
      if reaper.ImGui_Selectable(ctx,selectType,isSelected,nil,width) then
        if s == 1 then 
          setSettings("insideTimeSelection",nil,true)
        elseif s == 2 then 
          setSettings("beforeCursor",nil,true)
          if selectSettings.afterCursorOn then 
            setSettings("afterCursor",nil,true) 
          end
        elseif s == 3 then 
          setSettings("afterCursor",nil,true)
          if selectSettings.beforeCursorOn then 
            setSettings("beforeCursor", false,true) 
          end
        elseif s == 4 then 
          setSettings("onlyFocusedTake") 
        end
      end
      if s == 1 then helpMarker("Press I or A to toggle")
      elseif s == 2 then helpMarker("Press B or S to toggle between before cursor, beyond cursor or neither")
      elseif s == 3 then helpMarker("Press B or S to toggle between before cursor, beyond cursor or neither")
      elseif s == 4 then helpMarker("Press D to toggle") end
    end

    
    
    updateTypes = {"Manually","On Focus","On Selection","Select context and focus Piano Roll"}
    
    reaper.ImGui_PushStyleColor(ctx,reaper.ImGui_Col_Text(),0x888888FF)
    reaper.ImGui_Text(ctx, "Update context:") 
    reaper.ImGui_PopStyleColor(ctx)
    
    helpMarker('Press U to toggle through settings')
    for f, updateType in ipairs(updateTypes) do
      local isSelected = selectSettings.update == updateType
      local width = reaper.ImGui_CalcTextSize(ctx,updateType)
      
      if f < 4 then
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Selectable(ctx,updateType..'##update'..updateType,isSelected,nil,width) then
          selectSettings.update = updateType
          if updateType == "Manually" and selectSettings.update == "Manually" then
            selectedEvents = getSelectedEvents()
          end
          setSettings()
        end
        if updateType == "Manually" then
          helpMarker('Press cmd+U to toggle through settings\nPress U to update manually')
        else
          helpMarker('Press cmd+U to toggle through settings')
        end
      end
      
      if f == 4 and selectSettings.update ~= "On Selection" then
        reaper.ImGui_SameLine(ctx,nil,14)
        if reaper.ImGui_Selectable(ctx,updateType..'##focus'..updateType,true,nil,width) then
          selectOnlyEvent(-1)
        end
        helpMarker("Click to select original events or press O or G")
      end
      
    end
    
    
    focuseTypes = {"Manually","Piano Roll","App Window"} 
    focusText = 'Press cmd+F to toggle through settings\nPress F to focus piano roll in manual mode'
    reaper.ImGui_PushStyleColor(ctx,reaper.ImGui_Col_Text(),0x888888FF)
    reaper.ImGui_Text(ctx, "Keep focus:      ") 
    reaper.ImGui_PopStyleColor(ctx)
    helpMarker(focusText)
    for _, focusType in ipairs(focuseTypes) do
      reaper.ImGui_SameLine(ctx)
      local isSelected = selectSettings.focus == focusType
      local width = reaper.ImGui_CalcTextSize(ctx,focusType) 
      
      if reaper.ImGui_Selectable(ctx,focusType..'##focus'..focusType,isSelected,nil,width) then
        selectSettings.focus = focusType
        setSettings()
      end
      helpMarker(focusText)
    end
    
    --reaper.ImGui_SameLine(ctx,nil,10)
    --if reaper.ImGui_Button(ctx,"Select original context and focus Piano Roll") then
    --  selectOnlyEvent(-1)
    --end
    
    
    
    --reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_PopFont(ctx)
        
        
    function setSettingsWithModifiers(columnName)
      if reaper.ImGui_GetKeyMods(ctx) == 0 then
        setSettings(columnName)
      elseif reaper.ImGui_GetKeyMods(ctx) == shift then
        setSettings(columnName,"equal")
      elseif reaper.ImGui_GetKeyMods(ctx) == ctrl then
        setSettings(columnName,"higher")
      elseif reaper.ImGui_GetKeyMods(ctx) == alt  then
        setSettings(columnName,"lower")
      elseif reaper.ImGui_GetKeyMods(ctx) == ctrlAlt then
        setSettings(columnName,"inRange") 
      elseif  reaper.ImGui_GetKeyMods(ctx) == ctrlShift then
        setSettings(columnName,"higherEqual")
      elseif reaper.ImGui_GetKeyMods(ctx) == altShift  then
        setSettings(columnName,"lowerEqual")
      elseif reaper.ImGui_GetKeyMods(ctx) == ctrlAltShift then
        setSettings(columnName,"inRangeEqual")
      end
    end
    
    
    function setMutedSettingsWithModifiers(columnName)
      if reaper.ImGui_GetKeyMods(ctx) == 0 then
        setSettings(columnName)
      elseif reaper.ImGui_GetKeyMods(ctx) == shift then
        setSettings(columnName,"Include")
      elseif  reaper.ImGui_GetKeyMods(ctx) == ctrl then
        setSettings(columnName,"Exclude")
      elseif reaper.ImGui_GetKeyMods(ctx) == alt  then
        setSettings(columnName,"Only Muted")
      end
    end
    
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_Escape(),false) then
      open = false
    end
    

    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_Q(),false)
      or reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_N(),false) 
      then 
      columnName = "number"
      if isNotes and reaper.ImGui_IsKeyDown(ctx,reaper.ImGui_Mod_Super())  then
        setSettings(columnName,"equalAllOctaves")
      else
        setSettingsWithModifiers(columnName)
      end
    end
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_W(),false) 
      or reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_V(),false) 
      then 
      columnName = "amount"
      setSettingsWithModifiers(columnName)
    end
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_E(),false)
      or reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_C(),false) 
      then 
      columnName = "channel"
      setSettingsWithModifiers(columnName)
    end
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_P(),false)
      or reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_R(),false) 
      then 
        columnName = "pos"
        if reaper.ImGui_IsKeyDown(ctx,reaper.ImGui_Mod_Super()) then 
          setSettings("posIsInBar",not isBar)
        else
          setSettingsWithModifiers(columnName)
        end
    end
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_T(),false)
      or reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_L(),false) 
      then 
      columnName = "lengthPPQ"
      setSettingsWithModifiers(columnName)
    end
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_Y(),false)
      or reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_M(),false) 
      then 
      columnName = "muted"
      setMutedSettingsWithModifiers(columnName)
    end
    
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_I(),false) 
      or reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_A(),false) 
      then
      setSettings("insideTimeSelection",nil,true)
    end
    
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_B(),false) 
      or reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_S(),false) 
      then 
      if selectSettings.beforeCursorOn then 
        setSettings("afterCursor",nil,true)
        setSettings("beforeCursor",nil,true)
      elseif selectSettings.afterCursorOn then
        setSettings("afterCursor",nil,true)
      else 
        setSettings("beforeCursor",nil,true)
      end
    end
    
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_D(),false) 
      then
      setSettings("onlyFocusedTake",nil,true)
    end
    
    
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_H(),false) then
      setSettings("showHelp",nil,true)
    end
    
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_O(),false) then
      newEvents = getSelectedEvents()
      if tableEquals(newEvents, selectedEvents) then
        setSettings()
      else
        selectOnlyEvent(-1)
        reaper.BR_Win32_SetForegroundWindow(midiEditor)
      end
    end
    
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_0(),false) or reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_Keypad0(),false) then
      if reaper.ImGui_IsKeyDown(ctx,reaper.ImGui_Mod_Alt()) then
        selectSettings[selectSettings.lastEdited .. "RangeAbove"] = 0
      elseif reaper.ImGui_IsKeyDown(ctx,reaper.ImGui_Mod_Ctrl()) then
        selectSettings[selectSettings.lastEdited .. "RangeBelow"] = 0
      else
        selectSettings[selectSettings.lastEdited .. "RangeBelow"] = 0
        selectSettings[selectSettings.lastEdited .. "RangeAbove"] = 0
      end
      setSettings()
    end
    
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_KeypadAdd(),true) or  reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_T(),true) then
      if reaper.ImGui_IsKeyDown(ctx,reaper.ImGui_Mod_Super()) then jumpValue = 10 else jumpValue = 1 end
      if reaper.ImGui_IsKeyDown(ctx,reaper.ImGui_Mod_Alt()) then
        selectSettings[selectSettings.lastEdited .. "RangeAbove"] = selectSettings[selectSettings.lastEdited .. "RangeAbove"] +jumpValue
      elseif reaper.ImGui_IsKeyDown(ctx,reaper.ImGui_Mod_Ctrl()) then
        selectSettings[selectSettings.lastEdited .. "RangeBelow"] = selectSettings[selectSettings.lastEdited .. "RangeBelow"] +jumpValue
      else
        selectSettings[selectSettings.lastEdited .. "RangeAbove"] = selectSettings[selectSettings.lastEdited .. "RangeAbove"] +jumpValue
      end
      setSettings()
    end
    
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_KeypadSubtract(),true) or  reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_G(),true) then
      if reaper.ImGui_IsKeyDown(ctx,reaper.ImGui_Mod_Super()) then jumpValue = 10 else jumpValue = 1 end
      if reaper.ImGui_IsKeyDown(ctx,reaper.ImGui_Mod_Alt()) then
        selectSettings[selectSettings.lastEdited .. "RangeAbove"] = selectSettings[selectSettings.lastEdited .. "RangeAbove"] -jumpValue
      elseif reaper.ImGui_IsKeyDown(ctx,reaper.ImGui_Mod_Ctrl()) then
        selectSettings[selectSettings.lastEdited .. "RangeBelow"] = selectSettings[selectSettings.lastEdited .. "RangeBelow"] -jumpValue
      else
        selectSettings[selectSettings.lastEdited .. "RangeBelow"] = selectSettings[selectSettings.lastEdited .. "RangeBelow"] -jumpValue
      end
      setSettings()
    end
    
    if reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_F(),false) or reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_Enter(),false) then
      reaper.BR_Win32_SetForegroundWindow(midiEditor)
    end
    
    if (reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_U(),false)) or reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_Z(),false) then
      if reaper.ImGui_IsKeyDown(ctx,reaper.ImGui_Mod_Super()) then
        if selectSettings.update == "Manually" then
          selectedEvents = getSelectedEvents()
        end
        selectSettings.update = "Manually" 
      else
        if selectSettings.update == "Manually" then
          selectSettings.update = "On Focus"
        elseif selectSettings.update == "On Focus" then
          selectSettings.update = "On Selection" 
        else
          selectSettings.update = "Manually" 
        end 
      end 
      
      setSettings()
    end
    
    if (reaper.ImGui_IsKeyPressed(ctx,reaper.ImGui_Key_X(),false)) then
        if selectSettings.focus == "Manually" then
          selectSettings.focus = "Piano Roll"
        elseif selectSettings.focus == "Piano Roll" then
          selectSettings.focus = "App Window" 
        else
          selectSettings.focus = "Manually" 
        end 
      
      setSettings()
    end
    
    
    
    -- when refocusing using command, ensure we focus the window
    if reaper.HasExtState(extStateSection,"refocus") then
      reaper.DeleteExtState(extStateSection,"refocus",false)
      reaper.ImGui_SetNextWindowFocus(ctx)
      if selectSettings.update == "On Focus" then 
        --reaper.BR_Win32_SetFocus(focusedPopupWindow) 
        --reaper.ImGui_SetNextWindowFocus(ctx)
        --isFocused = true
        --selectedEvents = getSelectedEvents()
        --setSettings()
      end
    end
    
    if not reaper.ImGui_IsWindowFocused(ctx, reaper.ImGui_FocusedFlags_AnyWindow()) then
      if selectSettings.focus == "App Window" then
        --if previousSelectedEvents then
          reaper.BR_Win32_SetFocus(focusedPopupWindow) 
          --reaper.BR_Win32_SetForegroundWindow(focsuedPopupWindow)
          --reaper.ImGui_SetWindowFocus(ctx)
          reaper.ImGui_SetNextWindowFocus(ctx)
        --end
      end
      isFocused = false
    else
      if not isFocused and selectSettings.update == "On Focus" then
        selectedEvents = getSelectedEvents()
        setSettings()
      end
      isFocused = true
    end
    
     
    if selectSettings.update == "On Selection" then
      if waitForFocusABit == 2 then
        newSelectedEvents = getSelectedEvents()
        if not deepcompare(newSelectedEvents,previousSelectedEvents,false) then
          if not lastSelectionFromApp or not deepcompare(newSelectedEvents,lastSelectionFromApp) then 
            selectedEvents = newSelectedEvents
            selectNewEvents(selectedEvents)
            lastSelectionFromApp = getSelectedEvents()      
          end
          
          previousSelectedEvents = newSelectedEvents
        end
        waitForFocusABit = -1
      else
        waitForFocusABit = waitForFocusABit + 1
      end
    end
    
    if selectSettings.focus == "Piano Roll" and reaper.BR_Win32_GetFocus() ~= midiEditor then
      --if previousSelectedEvents then
      if waitForFocusABit == 10 then
        reaper.BR_Win32_SetFocus(midiEditor) 
        waitForFocusABit = -1
      else
        waitForFocusABit = waitForFocusABit + 1
      end
    end
    
    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_PopStyleVar(ctx,3)
    
    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)

reaper.atexit(function()
  reaper.DeleteExtState(extStateSection,extStateKey,true)
end)
