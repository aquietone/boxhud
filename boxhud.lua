--[[
boxhud.lua 1.2 -- aquietone

Recreates NetBots based HUD with DanNet observer based lua UI.
It should handle peers dynamically coming/going. 

Configuration is included by requiring a separate lua file. See
the included boxhud-settings.lua for more information on configuration.

A default boxhud-settings.lua is provided. The script will first
look for boxhud-settings-toonname.lua before using the default.
A settings file can also be provided as an argument.

Usage: /lua run boxhud [settings.lua]

Changes:
1.2:
- Correct zone peer group when in instance and when zoning
- Stop observing Me.ID, Me.Invis and Zone.ID and just use spawn data instead
- Change left click button to /dex name /foreground
1.1
- Configuration options externalized
1.0
- Initial release, static configuration UI

--]]
mq = require('mq')

local arg = {...}

-- Control variables
local openGUI = true
local shouldDrawGUI = true
local terminate = false
local settings = {}
-- Default DanNet peer group to use
local peerGroup = 'all'
local zoneID = nil
-- Default observer polling interval (0.25 seconds)
local refreshInterval = 250
-- Default stale observed data timeout (60 seconds)
local staleDataTimeout = 60
-- Stores all live observed toon information that will be displayed
local dataTable = {}
-- Tracks what toons observers have been added for to avoid adding multiple times
local observedToons = {}
local windowWidth = 0

-- Utility functions

function print_msg(msg) print('\at[\ayBOXHUD\at] \at' .. msg) end
function print_err(msg) print('\at[\ayBOXHUD\at] \ar' .. msg) end

-- Create a table of {key:true, ..} from a list for checking a value
-- is in the list 
function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

-- list of classes to check against for things like displaying mana % versus endurance %
local casters = Set { 'Cleric', 'Druid', 'Shaman', 'Enchanter', 'Magician', 'Necromancer', 'Wizard' }
local melee = Set { 'Bard', 'Rogue', 'Monk', 'Berserker', 'Ranger', 'Beastlord', 'Warrior', 'Shadow Knight', 'Paladin'}

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

-- Return list of DanNet peers from the configured peer group
-- peers list |peer1|peer2|peer3
function Peers()
    return Split(tostring(mq.TLO.DanNet.Peers(peerGroup)))
end

function FileExists(path)
    local f = io.open(path, "r")
    if f ~= nil then io.close(f) return true else return false end
end

-- regular zone: zone_server_shortname
-- instance zone: zone_shortname_progress
function GetZonePeerGroup()
    local peerGroupsString = tostring(mq.TLO.DanNet.Joined)
    local peerGroups = Split(peerGroupsString)
    for _, group in pairs(peerGroups) do
        if group:find('zone_') then
            return group
        end
    end
end

function ValidateSettings()
    if not settings['Columns'] then
        print_err('ERROR: Missing \'Columns\' from settings')
        mq.exit()
    elseif not settings['ObservedProperties'] then
        print_err('ERROR: Missing \'ObservedProperties\' from settings')
        mq.exit()
    elseif table.getn(settings['Columns']) == 0 then
        print_err('ERROR: \'Columns\' contains no entries')
        mq.exit()
    elseif table.getn(settings['ObservedProperties']) == 0 then
        print_err('ERROR: \'ObservedProperties\' contains no entries')
        mq.exit()
    end
end

function CopySettingsFile(default_settings, new_settings)
    local f = io.open(default_settings, 'r')
    defaults = f:read('*a')
    io.close(f)
    f = io.open(new_settings, 'w')
    f:write(defaults)
    io.close(f)
end

function LoadSettings()
    lua_dir = mq.TLO.MacroQuest.Path():gsub('\\', '/') .. '/lua/'
    settings_file = arg[1] or 'boxhud-settings-'..string.lower(tostring(mq.TLO.Me.Name))..'.lua'
    settings_path = lua_dir..settings_file
    default_settings_path = lua_dir..'boxhud-settings.lua'

    if FileExists(settings_path) then
        print_msg('Loading settings from file: ' .. settings_file)
        settings = require(settings_file:gsub('.lua', ''))
        ValidateSettings()
    else
        print_msg('Loading default settings from file: boxhud-settings')
        -- Default settings
        settings = require('boxhud-settings')
        -- Copy defaults into toon specific settings
        CopySettingsFile(default_settings_path, settings_path)
    end

    if settings['PeerGroup'] and settings['PeerGroup'] == 'zone' then
        peerGroup = GetZonePeerGroup()
        zoneID = tostring(mq.TLO.Zone.ID)
    end
    if settings['RefreshInterval'] then
        refreshInterval = settings['RefreshInterval']
    end
    if settings['StaleDataTimeout'] then
        staleDataTimeout = settings['StaleDataTimeout']
    end

    for _, column in pairs(settings['Columns']) do
        windowWidth = windowWidth + column['Width']
    end
end

-- Add or remove observers for the given toon
function ManageObservers(botName, drop)
    if drop then
        for _, obsProp in pairs(settings['ObservedProperties']) do
            -- Drop the observation if it is set
            if tostring(mq.TLO.DanNet(botName).ObserveSet(obsProp['Name'])) == 'TRUE' then
                mq.cmd.dobserve(botName..' -q '..obsProp['Name']..' -drop')
                mq.delay(50)
            end
        end
        observedToons[botName] = nil
    else
        if not observedToons[botName] then
            for _, obsProp in pairs(settings['ObservedProperties']) do
                -- Add the observation if it is not set
                if tostring(mq.TLO.DanNet(botName).ObserveSet(obsProp['Name'])) == 'FALSE' then
                    mq.cmd.dobserve(botName..' -q '..obsProp['Name'])
                    mq.delay(50)
                end
            end
            observedToons[botName] = true
        end
    end
end

-- Verify all observed properties are set for the given toon
function VerifyObservers(botName)
    for _, obsProp in pairs(settings['ObservedProperties']) do
        if tostring(mq.TLO.DanNet(botName).ObserveSet(obsProp['Name'])) == 'FALSE' then
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
            if tonumber(value) ~= nil and tonumber(value) >= thresholds[1] then
                -- red if above threshold
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
            else
                -- green otherwise
                ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
            end
        elseif table.getn(thresholds) == 2 then
            if tonumber(value) ~= nil and tonumber(value) >= thresholds[2] then
                -- red if above threshold
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
            elseif tonumber(value) ~= nil and tonumber(value) > thresholds[1] and tonumber(value) <= thresholds[2] then
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
            if tonumber(value) ~= nil and tonumber(value) >= thresholds[1] then
                -- green if above threshold
                ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
            else
                -- red otherwise
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
            end
        elseif table.getn(thresholds) == 2 then
            if tonumber(value) ~= nil and tonumber(value) >= thresholds[2] then
                -- green if above threshold
                ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
            elseif tonumber(value) ~= nil and tonumber(value) > thresholds[1] and tonumber(value) <= thresholds[2] then
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
    ImGui.SetNextWindowSize(windowWidth, 0)
    openGUI, shouldDrawGUI = ImGui.Begin('HUD GUI', openGUI, ImGuiWindowFlags.NoTitleBar)
    if shouldDrawGUI then
        ImGui.SetWindowFontScale(0.9)
        ImGui.Columns(table.getn(settings['Columns']))
        for _, column in pairs(settings['Columns']) do
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

            for _, column in pairs(settings['Columns']) do
                if column['Name'] == 'Name' then
                    -- Treat Name column special
                    -- Fill name column
                    if botInZone then
                        ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                        local buttonText = nil
                        if botInvis == 'FALSE' then
                            buttonText = botName
                        else
                            buttonText = '('..botName..')'
                        end
                        if ImGui.SmallButton(buttonText) then
                            -- bring left clicked toon to foreground
                            mq.cmd.dex(botName..' /foreground')
                        end
                        if ImGui.IsItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.ImGuiMouseButton_Right) then
                            -- target the toon on right click
                            mq.cmd.target('id '..botID)
                            -- nav to toon when right clicking toons name
                            --mq.cmd.nav('id '..botID)--..'|log=off')
                        end
                    else
                        ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                        if ImGui.SmallButton(botName) then
                            -- bring left clicked toon to foreground
                            mq.cmd.dex(botName..' /foreground')
                        end
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
                end -- end column name condition
            end -- end column loop

        end -- end dataTable loop
        ImGui.End()
    end
end


LoadSettings()

-- Initial setup of observers
local peerTable = Peers()
for _, botName in pairs(peerTable) do
    --print_msg('Cleanup any previously set observers for: '..botName)
    --ManageObservers(botName, true)
    --print_msg('Waiting for observed properties to be removed for: '..botName)
    --while VerifyObservers(botName) do
    --    mq.delay(100)
    --end
    print_msg('Adding observed properties for: \ay'..botName)
    ManageObservers(botName, false)
    print_msg('Waiting for observed properties to be added for: \ay'..botName)
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
    -- Update peerGroup if we've zoned and using the zone peer group
    if peerGroup ~= 'all' and zoneID ~= tostring(mq.TLO.Zone.ID) then
        peerGroup = GetZonePeerGroup()
        zoneID = tostring(mq.TLO.Zone.ID)
    end
    currTime = os.time(os.date("!*t"))
    local peerTable = Peers()
    for botIdx, botName in pairs(peerTable) do
        -- Ensure observers are set for the toon
        if not VerifyObservers(botName) or not observedToons[botName] then
            --print_msg('Cleanup any previously set observers for: '..botName)
            --ManageObservers(botName, true)
            --print_msg('Waiting for observed properties to be removed for: '..botName)
            --while VerifyObservers(botName) do
            --    mq.delay(100)
            --end
            print_msg('Adding observed properties for: \ay'..botName)
            ManageObservers(botName, false)
            -- If observers were newly added, delay for them to initialize
            print_msg('Waiting for observed properties to be added for: \ay'..botName)
            while not VerifyObservers(botName) do
                mq.delay(100)
            end
        end

        local botValues = {}
        botSpawnData = mq.TLO.Spawn('='..botName)
        botValues['Me.ID'] = tostring(botSpawnData.ID)
        botValues['Me.Invis'] = tostring(botSpawnData.Invis)
        -- Fill in data from this toons observed properties
        for _, obsProp in pairs(settings['ObservedProperties']) do
            botValues[obsProp['Name']] = tostring(mq.TLO.DanNet(botName).Observe(obsProp['Name']))
        end
        for _, spawnProp in pairs(settings['SpawnProperties']) do
            botValues[spawnProp['Name']] = tostring(mq.TLO.Spawn('='..botName)[spawnProp['Name']])
        end
        if peerGroup == 'all' then
            botValues['BotInZone'] = (botValues['Me.ID'] ~= 'null')
        else
            botValues['BotInZone'] = true
        end
        botValues['lastUpdated'] = currTime
        dataTable[botName] = botValues
    end
    -- Cleanup stale toon data
    for botName, botValues in pairs(dataTable) do
        if os.difftime(currTime, botValues['lastUpdated']) > staleDataTimeout then
            print_msg('Removing stale toon data: \ay'..botName)
            dataTable[botName] = nil
            --ManageObservers(botName, true)
        end
    end
    mq.delay(refreshInterval)
end

--[[
-- Cleanup observers before exiting
-- Removing/re-adding observers seems a bit unreliable though...
local peerTable = Peers()
for _, botName in pairs(peerTable) do
    print_msg('Removing observed properties for: '..botName)
    ManageObservers(botName, true)
    -- If observers were newly added, delay for them to initialize
    print_msg('Waiting for observers to be removed for: '..botName)
    while VerifyObservers(botName) do
        mq.delay(100)
    end
end
--]]