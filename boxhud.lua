--[[
boxhud.lua -- aquietone

Recreates NetBots based HUD with DanNet observer based lua UI.
It should handle peers dynamically coming/going. 
Stale data will be removed after 30 seconds.

Usage: /lua run boxhud.lua
--]]
mq = require('mq')

local TLO = mq.TLO
local DanNet = TLO.DanNet
local Spawn = TLO.Spawn
local Zone = TLO.Zone

--[[ Maybe someday read table config from file, needs lua extensions though
filepath = debug.getinfo(1).short_src:gsub("lua\\hud.lua", "config\\hud.ini")
file = io.open(filepath, 'r')
if f ~= nil then 
    io.input(file)
    print(io.read())
    io.close(file)
end
--]]

-- Utility functions

-- Create a table of {key:true, ..} from a list for checking a value
-- is in the list 
function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

-- Split a string using the provided separator, | by default
function Split(input, sep)
    if sep == nil then
        sep = "|"
    end
    local t={}
    for str in string.gmatch(input, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

-- name: (string) name of the column
-- properties: (table) table of properties for this column
-- thresholds: (array) 1 threshold value for red/green coloring, or
--                     2 threshold values for red/yellow/green coloring
-- percentage: (boolean) is the property value a percentage
-- inzone: (boolean) only use this property when BotInZone == true
-- width: (number) column width
function DefineColumn(name, properties, thresholds, percentage, inzone, width)
    col = {}
    col['Name'] = name
    col['Properties'] = properties
    col['Thresholds'] = thresholds
    col['Percentage'] = percentage
    col['InZone'] = inzone
    col['Width'] = width
    return col
end

-- Control variables
local openGUI = true
local shouldDrawGUI = true
local terminate = false

-- list of classes to check against for things like displaying mana % versus endurance %
local casters = Set { 'Cleric', 'Druid', 'Shaman', 'Enchanter', 'Magician', 'Necromancer', 'Wizard' }
local melee = Set { 'Bard', 'Rogue', 'Monk', 'Berserker', 'Ranger', 'Beastlord', 'Warrior', 'Shadow Knight', 'Paladin'}

-- Stores all live observed toon information that will be displayed
local dataTable = {}

local columnInfo = {}
table.insert(columnInfo, DefineColumn('Name', nil, nil, false, false, 75))
table.insert(columnInfo, DefineColumn('HP%', {all='Me.PctHPs'}, {35,70}, true, false, 40))
table.insert(columnInfo, DefineColumn('MP%', {caster='Me.PctMana',melee='Me.PctEndurance'}, {35,70}, true, false, 40))
table.insert(columnInfo, DefineColumn('Distance', {all='Distance3D'}, {100,200}, false, true, 60))
table.insert(columnInfo, DefineColumn('Target', {all='Target.CleanName'}, nil, false, true, 125))
table.insert(columnInfo, DefineColumn('Spell/Disc', {all='Me.Casting.Name',melee='Me.ActiveDisc.Name'}, nil, false, false, 125))

-- Define properties to observe
local observePropsConfig = {
    ObservedProperties = {
        {Name='Me.ID'},
        {Name='Me.Class'},
        {Name='Me.PctHPs'},
        {Name='Me.PctMana', 'caster'},
        {Name='Me.PctEndurance', 'melee'},
        {Name='Me.Casting.Name'},
        {Name='Me.ActiveDisc.Name'},
        {Name='Me.Invis'},
        {Name='Target.CleanName'},
        {Name='Zone.ID'}
    },
    SpawnProperties = {
        {Name='Distance3D'}
    }
}

-- Add or remove observers for the given toon
function ManageObservers(botName, drop)
    if drop then
        for _, obsProp in pairs(observePropsConfig['ObservedProperties']) do
            -- Drop the observation if it is set
            if tostring(DanNet(botName).ObserveSet(obsProp['Name'])) == 'TRUE' then
                mq.cmd.dobserve(botName..' -q '..obsProp['Name']..' -drop')
            end
        end
    else
        for _, obsProp in pairs(observePropsConfig['ObservedProperties']) do
            -- Add the observation if it is not set
            if tostring(DanNet(botName).ObserveSet(obsProp['Name'])) == 'FALSE' then
                mq.cmd.dobserve(botName..' -q '..obsProp['Name'])
            end
        end
    end
end

-- Verify all observed properties are set for the given toon
function VerifyObservers(botName)
    for _, obsProp in pairs(observePropsConfig['ObservedProperties']) do
        if tostring(DanNet(botName).ObserveSet(obsProp['Name'])) == 'FALSE' then
            return false
        end
    end
    return true
end

-- Evaluates threshold as:
--   lower == better (green)
--   higher == worse (red)
-- e.g. Distance: close == green, far away == red
function SetColoredText(thresholds, value)
    -- Fill HP% column
    if thresholds ~= nil then
        if table.getn(thresholds) == 1 then
            if value ~= 'null' and tonumber(value) >= thresholds[1] then
                -- red if above threshold
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
            else
                -- green otherwise
                ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
            end
        elseif table.getn(thresholds) == 2 then
            if value ~= 'null' and tonumber(value) >= thresholds[2] then
                -- red if above threshold
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
            elseif value ~= 'null' and tonumber(value) > thresholds[1] and tonumber(value) <= thresholds[2] then
                -- yellow if between high and low
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            else
                -- red otherwise
                ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
            end
        end
    else
        ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
    end
    ImGui.Text(value)
    ImGui.PopStyleColor(1)
end

-- Evaluates thresholds as percentage:
--   lower == worse (red)
--   higher == better (green)
-- e.g. PctHPs: low == red, high == green
function SetColoredTextPct(thresholds, value)
    -- Fill HP% column
    if thresholds ~= nil then
        if table.getn(thresholds) == 1 then
            if value ~= 'null' and tonumber(value) >= thresholds[1] then
                -- green if above threshold
                ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
            else
                -- red otherwise
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
            end
        elseif table.getn(thresholds) == 2 then
            if value ~= 'null' and tonumber(value) >= thresholds[2] then
                -- green if above threshold
                ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
            elseif value ~= 'null' and tonumber(value) > thresholds[1] and tonumber(value) <= thresholds[2] then
                -- yellow if nearby
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            else
                -- red otherwise
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
            end
        end
    else
        ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
    end
    ImGui.Text(value..'%%')
    ImGui.PopStyleColor(1)
end

-- ImGui main function for rendering the UI window
local HUDGUI = function()
    -- Save, for experimenting with different flag combos: bit = require('bit'); bit.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoBackground)
    ImGui.SetNextWindowSize(470, 0)
    openGUI, shouldDrawGUI = ImGui.Begin('HUD GUI', openGUI, ImGuiWindowFlags.NoTitleBar)
    if shouldDrawGUI then
        ImGui.SetWindowFontScale(0.9)
        ImGui.Columns(table.getn(columnInfo))
        for _, column in pairs(columnInfo) do
            ImGui.CollapsingHeader(column['Name'], 256)
            ImGui.SetColumnWidth(-1, column['Width'])
            ImGui.NextColumn()
        end

        for botName, botValues in pairs(dataTable) do
            -- Always read these properties for the toon
            -- as they are not specific to a column
            botInZone = botValues['BotInZone']
            botInvis = botValues['Me.Invis']
            botID = botValues['Me.ID']
            botClass = botValues['Me.Class']

            for _, column in pairs(columnInfo) do
                if column['Name'] == 'Name' then
                    -- Treat Name column special
                    -- Fill name column, name is clickable to nav to that spawn
                    if botInZone then
                        ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                        local buttonText = nil
                        if botInvis == 'FALSE' then
                            buttonText = botName
                        else
                            buttonText = '('..botName..')'
                        end
                        if ImGui.SmallButton(buttonText) then
                            -- nav to toon when clicking toons name
                            mq.cmd.nav('id '..botID)
                        end
                    else
                        ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                        ImGui.Text(botName)
                    end
                    ImGui.PopStyleColor(1)
                    ImGui.NextColumn()
                else
                    if not column['InZone'] or (column['InZone'] and botInZone) then
                        value = 'NULL'
                        if column['Properties']['all'] then
                            value = botValues[column['Properties']['all']]
                        end
                        if value == 'NULL' then
                            if column['Properties']['caster'] and casters['botClass'] then
                                value = botValues[column['Properties']['caster']]
                            elseif column['Properties']['melee'] and not casters['botClass'] then
                                value = botValues[column['Properties']['melee']]
                            end
                        end
                        thresholds = column['Thresholds']
                        if value ~= 'NULL' then
                            if column['Percentage'] then
                                SetColoredTextPct(thresholds, value)
                            else
                                SetColoredText(thresholds, value)
                            end
                        end
                    end
                    ImGui.NextColumn()
                end
            end

        end
        ImGui.End()
    end
end

-- Initial setup of observers
-- peers list |peer1|peer2|peer3
local peerTable = Split(tostring(DanNet.Peers('All')))
for _, botName in pairs(peerTable) do
    print('Adding observed properties for: '..botName)
    ManageObservers(botName, false)
    print('Waiting for observed properties to be added for: '..botName)
    while not VerifyObservers(botName) do
        mq.delay(100)
    end
end

mq.imgui.init('HUDGUI', HUDGUI)

mq.bind('/hudgui', function()
    openGUI = not openGUI
end)

mq.bind('/hudend', function() 
    mq.imgui.destroy('HUDGUI')
    shouldDrawGUI = false
    terminate = true
end)

-- Main run loop to populate observed property data of toons
while not terminate do
    currTime = os.time(os.date("!*t"))
    peerTable = Split(tostring(DanNet.Peers('All')))
    for botIdx, botName in pairs(peerTable) do
        -- Ensure observers are set for the toon
        if not VerifyObservers(botName) then
            ManageObservers(botName, false)
            -- If observers were newly added, delay for them to initialize
            while not VerifyObservers(botName) do
                mq.delay(100)
            end
        end

        local botValues = {}
        -- Fill in data from this toons observed properties
        for _, obsProp in pairs(observePropsConfig['ObservedProperties']) do
            botValues[obsProp['Name']] = tostring(DanNet(botName).Observe(obsProp['Name']))
        end
        for _, spawnProp in pairs(observePropsConfig['SpawnProperties']) do
            botValues[spawnProp['Name']] = tostring(Spawn(botValues['Me.ID'])[spawnProp['Name']])
        end
        botValues['BotInZone'] = (botValues['Zone.ID'] == tostring(Zone.ID))
        botValues['lastUpdated'] = currTime
        dataTable[botName] = botValues
    end
    -- Cleanup stale toon data
    for botName, botValues in pairs(dataTable) do
        if os.difftime(currTime, botValues['lastUpdated']) > 30 then
            print('Removing stale toon data: '..botName)
            dataTable[botName] = nil
            ManageObservers(botName, true)
        end
    end
    mq.delay(250) -- equivalent to '0.25s'
end

-- Cleanup observers before exiting
-- Removing/re-adding observers seems a bit unreliable though...
peerTable = Split(tostring(DanNet.Peers('All')))
for _, botName in pairs(peerTable) do
    print('Removing observed properties for: '..botName)
    ManageObservers(botName, true)
    -- If observers were newly added, delay for them to initialize
    print('Waiting for observers to be removed for: '..botName)
    while VerifyObservers(botName) do
        mq.delay(100)
    end
end