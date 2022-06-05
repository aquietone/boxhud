--[[
boxhud.lua 1.4 -- aquietone
https://www.redguides.com/community/resources/boxhud-lua-requires-mqnext-and-mq2lua.2088/

Recreates the traditional MQ2NetBots/MQ2HUD based HUD with a DanNet observer 
based lua/ImGui UI.

The tabs, columns and contents are all customizable through the included
boxhud-settings.lua file or individual characters boxhud-settings-name.lua files.
See boxhud-settings.lua for more information on configuration options.

The provided boxhud-settings.lua includes some tabs and columns to get started. 

Individual character settings files will always take precedence over the default
settings file.
A specific settings file to use can also be passed in as an argument to the script.

!!!!!
IMPORTANT CONSIDERATIONS: Don't go crazy with the number of properties you observe.
                          I don't know the practical limit to how many things across
                          how many toons can be observed at once.
!!!!!

Usage: /lua run boxhud [settings.lua]
       /boxhud - toggle the UI window
       /boxhudend - end the script

Changes:
1.4
- Add in option to use NetBots properties incase people want them
- Changes to text threshold based coloring, can now define ascending/descending
  to say whether values should be red to green or green to red
- Fixes to escape values in observed property names
- Fix zone peer group name crash
- Try out a send command option on right click toon name
1.3.1
- Small fixes
- Properly escape some values for observed properties with [ ], etc.
- Don't use DanNet.Joined to find zone group name, construct it instead.
- Support buttons with user defined actions
1.3
- Tab support
- Property mappings (see Macro.Paused example)
- Cleanup/refactoring
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

-- Load required plugins
function PluginCheck()
    if mq.TLO.DanNet == nil then
        print_msg("Plugin \ayMQ2DanNet\ax is required. Loading it now.")
        mq.cmd.plugin('mq2dannet noauto')
    end
end

-- Create a table of {key:true, ..} from a list for checking a value
-- is in the list 
function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

-- list of classes to check against for things like displaying mana % versus endurance %
local casters = Set { 'CLR', 'DRU', 'SHM', 'ENC', 'MAG', 'NEC', 'WIZ' }
local melee = Set { 'BRD', 'ROG', 'MNK', 'BER', 'RNG', 'BST', 'WAR', 'SHD', 'PAL'}

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

-- regular zone: zone_server_shortname
-- instance zone: zone_shortname_progress
function GetZonePeerGroup()
    local zoneName = tostring(mq.TLO.Zone.ShortName)
    if zoneName:find('progress') then
        return 'zone_'..zoneName
    else
        return 'zone_'..tostring(mq.TLO.EverQuest.Server)..'_'..zoneName
    end
end

function FileExists(path)
    local f = io.open(path, "r")
    if f ~= nil then io.close(f) return true else return false end
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

    -- turn off fullname mode in DanNet
    if tostring(mq.TLO.DanNet.FullNames) == 'TRUE' then
        mq.cmd.dnet('fullnames off')
    end

    -- Calculate max tab width
    local globalColumnWidth = 0
    if settings['Columns'] and table.getn(settings['Columns']) > 0 then
        for _, column in pairs(settings['Columns']) do
            globalColumnWidth = globalColumnWidth + column['Width']
        end
        windowWidth = globalColumnWidth
    end
    if settings['Tabs'] and table.getn(settings['Tabs']) then
        for _, tab in pairs(settings['Tabs']) do
            local tabWidth = 0
            if tab['Columns'] and table.getn(tab['Columns']) > 0 then
                for _, column in pairs(tab['Columns']) do
                    tabWidth = tabWidth + column['Width']
                end
                if globalColumnWidth + tabWidth > windowWidth then
                    windowWidth = globalColumnWidth + tabWidth
                end
            end
        end
    end
    if globalColumnWidth == 0 then
        -- uhhh, no columns or tabs defined?
        windowWidth = 150
    end
end

-- Add or remove observers for the given toon
function ManageObservers(botName, drop)
    if drop then
        for _, obsProp in pairs(settings['ObservedProperties']) do
            -- Drop the observation if it is set
            if tostring(mq.TLO.DanNet(botName).ObserveSet('"'..obsProp['Name']..'"')) == 'TRUE' then
                mq.cmd.dobserve(botName..' -q "'..obsProp['Name']..'" -drop')
                mq.delay(50)
            end
        end
        observedToons[botName] = nil
    else
        if not observedToons[botName] then
            for _, obsProp in pairs(settings['ObservedProperties']) do
                -- Add the observation if it is not set
                if tostring(mq.TLO.DanNet(botName).ObserveSet('"'..obsProp['Name']..'"')) == 'FALSE' then
                    mq.cmd.dobserve(botName..' -q "'..obsProp['Name']..'"')
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
        if tostring(mq.TLO.DanNet(botName).ObserveSet('"'..obsProp['Name']..'"')) == 'FALSE' then
            return false
        end
    end
    return true
end

function SetText(value, thresholds, ascending, percentage)
    if thresholds ~= nil then
        if table.getn(thresholds) == 1 then
            if tonumber(value) ~= nil and tonumber(value) >= thresholds[1] then
                if ascending then
                    -- green if above threshold
                    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                else
                    -- red if above threshold
                    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                end
            else
                if ascending then
                    -- red otherwise
                    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                else
                    -- green otherwise
                    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                end
            end
        elseif table.getn(thresholds) == 2 then
            if tonumber(value) ~= nil and tonumber(value) >= thresholds[2] then
                if ascending then
                    -- green if above threshold
                    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                else
                    -- red if above threshold
                    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                end
            elseif tonumber(value) ~= nil and tonumber(value) > thresholds[1] and tonumber(value) <= thresholds[2] then
                -- yellow if between high and low
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            else
                if ascending then
                    -- green if above threshold
                    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                else
                    -- red if above threshold
                    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                end
            end
        end
    else
        ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
    end
    if percentage then
        ImGui.Text(value..'%%')
    else
        ImGui.Text(value)
    end
    ImGui.PopStyleColor(1)
end

titleCase = function(phrase)
    local result = string.gsub( phrase, "(%a)([%w_']*)",
        function(first, rest)
            return first:upper() .. rest:lower()
        end
    )
    return result
end

function table.concat(t1, t2)
    local t = {}
    for k,v in ipairs(t1) do
        table.insert(t, v)
    end
    for k,v in ipairs(t2) do
        table.insert(t, v)
    end
    return t
end

function DrawHUDColumns(columns)
    ImGui.Columns(table.getn(columns))
    for _, column in pairs(columns) do
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
        botClass = botValues['Me.Class.ShortName']

        for _, column in pairs(columns) do
            if column['Name'] == 'Name' then
                -- Treat Name column special
                -- Fill name column
                if botInZone then
                    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                    local buttonText = nil
                    if botInvis == 'FALSE' then
                        buttonText = titleCase(botName)
                    else
                        buttonText = '('..titleCase(botName)..')'
                    end
                    if ImGui.SmallButton(buttonText) then
                        -- bring left clicked toon to foreground
                        mq.cmd.dex(botName..' /foreground')
                    end
                else
                    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                    if ImGui.SmallButton(titleCase(botName)) then
                        -- bring left clicked toon to foreground
                        mq.cmd.dex(botName..' /foreground')
                    end
                end
                ImGui.PopStyleColor(1)
                                    
                if ImGui.BeginPopupContextItem("popup##"..botName) then
                    ImGui.Text('Send Command to '..botName..': ')
                    text = ""
                    text, selected = ImGui.InputText("##input"..botName, text, 32)
                    if selected then
                        print_msg('Sending command: /dex '..botName..' '..text)
                        mq.cmd.dex(botName..' '..text)
                        ImGui.CloseCurrentPopup()
                    end
                    if ImGui.Button('Close##'..botName) then
                        ImGui.CloseCurrentPopup()
                    end
                    ImGui.EndPopup()
                end
                ImGui.NextColumn()
            else
                -- Default column type is property (observed or spawn properties)
                if not column['Type'] or column['Type'] == 'property' then
                    if not column['InZone'] or (column['InZone'] and botInZone) then
                        value = 'NULL'
                        if column['Properties']['all'] then
                            value = botValues[column['Properties']['all']]
                        end
                        if value == 'NULL' then
                            if column['Properties'][botClass] then
                                value = botValues[column['Properties'][botClass]]
                            elseif column['Properties']['caster'] and casters[botClass] then
                                value = botValues[column['Properties']['caster']]
                            elseif column['Properties']['melee'] and melee[botClass] then
                                value = botValues[column['Properties']['melee']]
                            end
                        end
                        -- value, thresholds, ascending, percentage
                        thresholds = column['Thresholds']
                        if value ~= 'NULL' then
                            if column['Mappings'] and column['Mappings'][value] then
                                value = column['Mappings'][value]
                            end
                            SetText(value, thresholds, column['Ascending'], column['Percentage'])
                        end
                    end
                elseif column['Type'] == 'button' then
                    if ImGui.SmallButton(column['Name']..'##'..botName) then
                        -- bring left clicked toon to foreground
                        print('Run command: '..column['Action']:gsub('#botName#', botName))
                        mq.cmd.squelch(column['Action']:gsub('#botName#', botName))
                    end
                end
                ImGui.NextColumn()
            end -- end column name condition
        end -- end column loop
    end -- end dataTable loop
end

function DrawHUDTabs()
    if ImGui.BeginTabBar('BOXHUDTABS') then
        for _, tab in pairs(settings['Tabs']) do
            if ImGui.BeginTabItem(tab['Name']) then
                if tab['Columns'] and table.getn(tab['Columns']) > 0 then
                    DrawHUDColumns(table.concat(settings['Columns'], tab['Columns']))
                    ImGui.EndTabItem()
                    ImGui.Columns(1)
                else
                    ImGui.Text('No columns defined for tab')
                    ImGui.EndTabItem()
                end
            end
        end
        ImGui.EndTabBar()
    end
end

-- ImGui main function for rendering the UI window
local HUDGUI = function()
    -- Save, for experimenting with different flag combos: bit = require('bit'); bit.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoBackground)
    ImGui.SetNextWindowSize(windowWidth, 0)
    openGUI, shouldDrawGUI = ImGui.Begin('BOXHUDUI', openGUI, ImGuiWindowFlags.NoTitleBar)
    if shouldDrawGUI then
        ImGui.SetWindowFontScale(0.9)
        
        if settings['Tabs'] and table.getn(settings['Tabs']) > 0 then
            DrawHUDTabs()
        elseif settings['Columns'] and table.getn(settings['Columns']) > 0 then
            DrawHUDColumns(settings['Columns'])
        end

        ImGui.End()
    end
end

PluginCheck()
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
    local verifyStartTime = os.time(os.date("!*t"))
    while not VerifyObservers(botName) do
        mq.delay(100)
        if os.difftime(os.time(os.date("!*t")), verifyStartTime) > 10 then
            print_err('Timed out verifying observers for \ay'..botName)
            print_err('Exiting the script.')
            mq.exit()
        end
    end
end

mq.imgui.init('BOXHUDUI', HUDGUI)

mq.bind('/boxhud', function()
    openGUI = not openGUI
end)

mq.bind('/boxhudend', function() 
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
            local verifyStartTime = os.time(os.date("!*t"))
            while not VerifyObservers(botName) do
                mq.delay(100)
                if os.difftime(os.time(os.date("!*t")), verifyStartTime) > 10 then
                    print_err('Timed out verifying observers for \ay'..botName)
                    print_err('Exiting the script.')
                    mq.exit()
                end
            end
        end

        local botValues = {}
        botSpawnData = mq.TLO.Spawn('='..botName)
        botValues['Me.ID'] = tostring(botSpawnData.ID)
        botValues['Me.Invis'] = tostring(botSpawnData.Invis)
        -- Fill in data from this toons observed properties
        if settings['ObservedProperties'] then
            for _, obsProp in pairs(settings['ObservedProperties']) do
                botValues[obsProp['Name']] = tostring(mq.TLO.DanNet(botName).Observe('"'..obsProp['Name']..'"'))
            end
        end
        if settings['NetBotsProperties'] then
            for _, netbotsProp in pairs(settings['NetBotsProperties']) do
                botValues[netbotsProp['Name']] = tostring(mq.TLO.NetBots(titleCase(botName))[netbotsProp['Name']])
            end
        end
        if settings['SpawnProperties'] then
            for _, spawnProp in pairs(settings['SpawnProperties']) do
                botValues[spawnProp['Name']] = tostring(mq.TLO.Spawn('='..botName)[spawnProp['Name']])
            end
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