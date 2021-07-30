--[[
boxhud.lua 1.8.1 -- aquietone
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

Usage: /lua run boxhud [settings.lua]
       /boxhud - toggle the UI window
       /boxhudend - end the script
       /bhadmin - toggle admin mode. Only purpose is to hide the UI so it 
                  doesn't error when resetting observers.
       /bhadmin reset toonname - Reset observed properties for the specified toon.
       /bhadmin anon - toggle showing names or class names in the Name column
       /bhhelp - Display help output
       /bhversion - Display the running version

Changes:
1.8.1
- Updated for RG build 216 changes
- Switch to use mq.cmd and mq.cmdf
- Updates to some conditions due to type changes
1.8.0
- Add handling for observing TLOs that may not be present on all toons
  Relies on defining dependencies between observed properties. For example:
    If you have the MQ2Monk, MQ2Eskay and MQ2Rogue plugins, which add TLO `CWTN`, and you want to observe `CWTN.Mode`, then it may interfere
    with macros running on toons without a CWTN class plugin loaded, like bards.
    This can be handled by defining the observed properties like:

     { Name='Me.Class.ShortName' },
     { Name='CWTN.Mode', DependsOnName='Me.Class.ShortName', DependsOnValue='MNK,SHD,ROG' }

- Set initial window size if window has default 32x32 size.
- Exit if game state is not INGAME.
- Append character name to window ID so characters can have separate window settings.
- Add strict settings validation to try and make sure data is correct
- Update button command handling a bit for crashes
1.7.3
- Fix for toons being randomly removed from the table while sorting by something other than the default Name column
1.7.2
- Remove debug accidentally left in 1.7.1 which caused an immediate crash
1.7.1
- fix Push/PopID usage so context menus and buttons in table work properly
1.7.0
- lua table updates
1.6.1
- sort by number or string - SpecialEd
1.6.0
- Add sorting by column
- Add PeerSource to allow getting peer list from either dannet or netbots
- Add "FromIDProperty" to spawn properties to allow getting spawn properties
  for something other than botName. The referred property must be a Spawn ID.
  For example:
    NetBots property: {Name='TargetID'}
    Spawn property:   {Name='CleanName',FromIDProperty='TargetID'}
    Then assign a column to display property 'CleanName'
- Move /boxhudanon under new /bhadmin
- Add some commands to reset observers under /bhadmin:
  /bhadmin (enables admin mode, hides the UI)
  /bhadmin reset toonname (resets observers for the toon toonname)
- Add a /bhversion command
- Add a /bhhelp command
1.5.0
- Add some right click actions on name buttons
- Add /boxhudanon binding to replace names with class names in name column
  Mostly so I don't have to draw over names in screenshots
- Try to adjust observe timeouts based on # of peers
- Misc cleanup
1.4.4
- Fix for some columns showing |server_name instead of correct data
- Make sure peer list is initialized before UI
1.4.3
- Fix conditions broken by 1.4.2 tostring() replacements
1.4.2
- Fix gsub in button commands
- Fix handling button commands with /noparse
- Swap tostrings for mq.TLO.Property()
1.4.1
- Fix for zone shortname formats
- Fix text coloring
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
--- @type mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local arg = {...}

-- Control variables
local VERSION = '1.8.1'
local openGUI = true
local shouldDrawGUI = true
local terminate = false
local settings = {}
-- Default DanNet peer group to use
local peerSource = 'dannet'
local peerGroup = 'all'
local peerTable = nil
local peersDirty = false
local classVarName = 'Me.Class.ShortName'
local zoneID = nil
-- Default observer polling interval (0.25 seconds)
local refreshInterval = 250
-- Default stale observed data timeout (60 seconds)
local staleDataTimeout = 60
-- Stores all live observed toon information that will be displayed
local dataTable = {}
-- Tracks what toons observers have been added for to avoid adding multiple times
local observedToons = {}
-- Set to 1 to use classname instead of player names
local anonymize = false
local adminMode = false
local adminPeerSelected = 0
local initialRun = true
math.randomseed(os.time())
local tableRandom = math.random(1,100)

-- Utility functions

local function print_msg(msg) print('\at[\ayBOXHUD\at] \at' .. msg) end
local function print_err(msg) print('\at[\ayBOXHUD\at] \ar' .. msg) end

local function FileExists(path)
    local f = io.open(path, "r")
    if f ~= nil then io.close(f) return true else return false end
end

-- Split a string using the provided separator, | by default
local function Split(input, sep)
    if sep == nil then
        sep = "|"
    end
    local t={}
    for str in string.gmatch(input, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

-- Create a table of {key:true, ..} from a list for checking a value is in the list 
local function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

local function TitleCase(phrase)
    local result = string.gsub( phrase, "(%a)([%w_']*)",
        function(first, rest)
            return first:upper() .. rest:lower()
        end
    )
    return result
end

local function TableConcat(t1, t2)
    local t = {}
    for k,v in ipairs(t1) do
        table.insert(t, v)
    end
    for k,v in ipairs(t2) do
        table.insert(t, v)
    end
    return t
end

local function TableClone(org)
    return {unpack(org)}
end

-- lists of classes to check against for things like displaying mana % versus endurance %
local casters = Set { 'cleric', 'clr', 'druid', 'dru', 'shaman', 'shm', 'enchanter', 
                      'enc', 'magician', 'mag', 'necromancer', 'nec', 'wizard', 'wiz' }
-- melee, hybrid, ranged overlap for compatibility. 
-- hybrids is checked before melee as it is a more specific subset of classes
local melee = Set { 'rogue', 'rog', 'monk', 'mnk', 'berserker', 'ber', 'warrior', 'war', 
                    'bard', 'brd', 'ranger', 'rng', 'beastlord', 'bst', 'shadow knight', 
                    'shd', 'paladin', 'pal' }
local hybrids = Set { 'bard', 'brd', 'ranger', 'rng', 'beastlord', 'bst', 'shadow knight', 
                      'shd', 'paladin', 'pal' }
local ranged = Set { 'ranger', 'rng' }

local function IsUsingDanNet()
    return peerSource == 'dannet' or (settings['ObservedProperties'] and table.getn(settings['ObservedProperties']) > 0)
end

local function IsUsingNetBots()
    return peerSource == 'netbots' or (settings['NetBotsProperties'] and table.getn(settings['NetBotsProperties']) > 0)
end

-- Load required plugins
local function PluginCheck()
    if IsUsingDanNet() then
        if not mq.TLO.Plugin('mq2dannet').IsLoaded() then
            print_msg("Plugin \ayMQ2DanNet\ax is required. Loading it now.")
            mq.cmd('/plugin mq2dannet noauto')
        end
        -- turn off fullname mode in DanNet
        if mq.TLO.DanNet.FullNames() then
            mq.cmd('/dnet fullnames off')
        end
    end
    if IsUsingNetBots() then
        if not mq.TLO.Plugin('mq2eqbc').IsLoaded() then
            print_msg("Plugin \ayMQ2EQBC\ax is required. Loading it now.")
            mq.cmd('/plugin mq2eqbc noauto')
        end
        if not mq.TLO.Plugin('mq2netbots').IsLoaded() then
            print_msg("Plugin \ayMQ2NetBots\ax is required. Loading it now.")
            mq.cmd('/plugin mq2netbots noauto')
        end
    end
end

local function DoTablesMatch(a, b)
    return table.concat(a) == table.concat(b)
end

-- Return list of DanNet peers from the configured peer group
-- peers list |peer1|peer2|peer3
local function Peers()
    local t = {}
    if peerSource == 'dannet' then
        t = Split(mq.TLO.DanNet.Peers(peerGroup)())
    else
        t={}
        for i=1,mq.TLO.NetBots.Counts() do
            table.insert(t, mq.TLO.NetBots.Client.Arg(i)())
        end
    end
    if peerTable and not DoTablesMatch(peerTable, t) then
        peersDirty = true
    end
    return t
end

local function GetZonePeerGroup()
    local zoneName = mq.TLO.Zone.ShortName()
    if zoneName:find('_') then
        return string.format('zone_%s', zoneName)
    else
        return string.format('zone_%s_%s', mq.TLO.EverQuest.Server(), zoneName)
    end
end

local function CheckOptionalSettings()
    if settings['PeerSource'] then
        if settings['PeerSource'] ~= 'dannet' and  settings['PeerSource'] ~= 'netbots' then
            print_err('PeerSource must be either \'dannet\' or \'netbots\'')
            mq.exit()
        end
        peerSource = settings['PeerSource']
    end
    if peerSource == 'dannet' then
        if settings['DanNetPeerGroup'] and settings['DanNetPeerGroup'] == 'zone' then
            peerGroup = GetZonePeerGroup()
            zoneID = mq.TLO.Zone.ID()
        elseif settings['PeerGroup'] and settings['PeerGroup'] == 'zone' then
            peerGroup = GetZonePeerGroup()
            zoneID = mq.TLO.Zone.ID()
        end
        local classPropertyFound = false
        for _, obsProp in pairs(settings['ObservedProperties']) do
            if obsProp['Name'] == 'Me.Class' or obsProp['Name'] == 'Me.Class.ShortName' then
                classPropertyFound = true
                classVarName = obsProp['Name']
            end
        end
        if not classPropertyFound then
            classVarName = 'Me.Class.ShortName'
            table.insert(settings['ObservedProperties'], {Name='Me.Class.ShortName'})
        end
    else
        local classPropertyFound = false
        for _, netBotsProp in pairs(settings['NetBotsProperties']) do
            if netBotsProp['Name'] == 'Class' then
                classPropertyFound = true
                classVarName = netBotsProp['Name']
            end
        end
        if not classPropertyFound then
            classVarName = 'Class'
            table.insert(settings['NetBotsProperties'], {Name='Class'})
        end
    end
    if settings['RefreshInterval'] and type(settings['RefreshInterval']) == 'number' then
        refreshInterval = settings['RefreshInterval']
    end
    if settings['StaleDataTimeout'] and type(settings['StaleDataTimeout']) == 'number' then
        staleDataTimeout = settings['StaleDataTimeout']
    end
end

local function CopySettingsFile(default_settings, new_settings)
    local f = io.open(default_settings, 'r')
    local defaults = f:read('*a')
    io.close(f)
    f = io.open(new_settings, 'w')
    f:write(defaults)
    io.close(f)
end

local propertyList = {}
local function IsObservedPropertyValid(obsProp, idx)
    if not obsProp['Name'] or type(obsProp['Name']) ~= 'string' then
        print_err(string.format('[ObservedProperties %s] Observed Properties must have a \'Name\' property of type \'string\'. Name=%s', idx, obsProp['Name']))
        return false
    else
        if obsProp['DependsOnName'] and not propertyList[obsProp['DependsOnName']] then
            print_err(string.format('[ObservedProperties %s] \'DependsOnName\' must refer to another observed property name. DependsOnName=%s', obsProp['Name'], obsProp['DependsOnName']))
            return false
        end
        if obsProp['DependsOnValue'] and not obsProp['DependsOnName'] then
            print_err(string.format('[ObservedProperties %s] \'DependsOnValue\' requires \'DependsOnName\' to also be set', obsProp['Name']))
            return false
        end
        if not propertyList[obsProp['Name']] then
            propertyList[obsProp['Name']] = 1
        else
            print_err(string.format('[ObservedProperties %s] Duplicate property name found. ObservedProperties[%d].Name=\'%s\' must be unique among Observed, NetBots and Spawn properties.', obsProp['Name'], idx, obsProp['Name']))
            return false
        end
    end
    return true
end

local function IsNetBotsPropertyValid(nbProp, idx)
    if not nbProp['Name'] or type(nbProp['Name']) ~= 'string' then
        print_err(string.format('[NetBotsProperties %d] NetBots Properties must have a \'Name\' property of type \'string\'. Name=%s', idx, nbProp['Name']))
        return false
    else
        if not propertyList[nbProp['Name']] then
            propertyList[nbProp['Name']] = 1
        else
            print_err(string.format('[NetBotsProperties %s] Duplicate property name found. NetBotsProperties[%d].Name=\'%s\' must be unique among Observed, NetBots and Spawn properties.', nbProp['Name'], idx, nbProp['Name']))
            return false
        end
    end
    return true
end

local function IsSpawnPropertyValid(spawnProp, idx)
    if not spawnProp['Name'] or type(spawnProp['Name']) ~= 'string' then
        print_err(string.format('[SpawnProperties %d] Spawn Properties must have a \'Name\' property of type \'string\'. Name=%s', idx, spawnProp['Name']))
        return false
    else
        if spawnProp['FromIDProperty'] and not propertyList[spawnProp['Name']] then
            print_err(string.format('[SpawnProperties %s] \'FromIDProperty\' must refer to a valid Observed or NetBots property. FromIDProperty=%s', spawnProp['Name'], spawnProp['FromIDProperty']))
            return false
        end
        if not propertyList[spawnProp['Name']] then
            propertyList[spawnProp['Name']] = 1
        else
            print_err(string.format('[SpawnProperties %s] Duplicate property name found. SpawnProperties[%d].Name=\'%s\' must be unique among Observed, NetBots and Spawn properties.', spawnProp['Name'], idx, spawnProp['Name']))
            return false
        end
    end
    return true
end

local function IsColumnPropertiesValid(properties, columnName)
    local valid = true
    for _,propName in pairs(properties) do
        if not propertyList[propName] then
            print_err(string.format('[Column %s] Column \'Properties\' must reference a valid \'Observed\', \'NetBots\' or \'Spawn\' property. Name=%s', columnName, propName))
            valid = false
        end
    end
    return valid
end

local function IsColumnMappingsValid(mappings)
    local valid = true
    -- what makes a mapping invalid?
    return valid
end

local function IsColumnThresholdsValid(thresholds, columnName)
    if #thresholds > 2 then
        print_err(string.format('[Column %s] Column \'Thresholds\' may contain either 1 or 2 number values, no more', columnName))
        return false
    else
        for threshholdIdx, value in ipairs(thresholds) do
            if type(value) ~= 'number' then
                print_err(string.format('[Column %s] Column \'Thresholds\' values must be numbers in ascending order', columnName))
                return false
            end
            if thresholdIdx == 2 and value < thresholds[1] then
                print_err(string.format('[Column %s] Column \'Thresholds\' values must be in ascending order', columnName))
                return false
            end
        end
    end
    return true
end

local function IsColumnValid(column, idx)
    local columnType = 'property'
    if not column['Name'] or type(column['Name']) ~= 'string' then
        print_err(string.format('[Column %d] Columns must have a \'Name\' property of type \'string\'. Name=%s', idx, column['Name']))
        return false
    elseif column['Name'] == 'Name' then
        -- special case name column
        return true
    end
    if column['Type'] then
        if type(column['Type']) ~= 'string' or (column['Type'] ~= 'button' and column['Type'] ~= 'property') then
            print_err(string.format('[Column %d] Column Type must be \'property\' or \'button\'. Type=%s', idx, column['Type']))
            return false
        else
            columnType = column['Type']
        end
    end
    local valid = true
    if columnType == 'property' then
        if not column['Properties'] or type(column['Properties']) ~= 'table' then
            print_err(string.format('[Column %s] Property Columns must have a \'Properties\' table', column['Name']))
            valid = false
        elseif not IsColumnPropertiesValid(column['Properties'], column['Name']) then
            valid = false
        end
        if column['Mappings'] then
            if type(column['Mappings']) ~= 'table' then
                print_err(string.format('[Column %s] Column \'Mappings\' must be a table', column['Name']))
                valid = false
            elseif not IsColumnMappingsValid(column['Mappings']) then
                valid = false
            end
        end
        if column['Thresholds'] then 
            if type(column['Thresholds']) ~= 'table' then
                print_err(string.format('[Column %s] Column \'Thresholds\' must be a table', column['Name']))
                valid = false
            elseif not IsColumnThresholdsValid(column['Thresholds'], column['Name']) then
                valid = false
            end
        end
        if column['Percentage'] ~= nil and type(column['Percentage']) ~= 'boolean' then
            print_err(string.format('[Column %s] Columns \'Percentage\' must be true or false', column['Name']))
            valid = false
        end
        if column['Ascending'] ~= nil and type(column['Ascending']) ~= 'boolean' then
            print_err(string.format('[Column %s] Columns \'Ascending\' must be true or false', column['Name']))
            valid = false
        end
        if column['InZone'] ~= nil and type(column['InZone']) ~= 'boolean' then
            print_err(string.format('[Column %s] Column \'InZone\' must be true or false', column['Name']))
            valid = false
        end
    elseif columnType == 'button' then
        if not column['Action'] or type(column['Action']) ~= 'string' then
            print_err(string.format('[Column %s] Button Columns must have an \'Actions\' property', column['Name']))
            valid = false
        end
    end
    return valid
end

local function IsTabValid(tab, idx)
    local valid = true
    if not tab['Name'] or type(tab['Name']) ~= 'string' then
        print_err(string.format('[Tab %d] Tabs must have a \'Name\' property of type \'string\'. Name=%s', idx, tab['Name']))
        return false
    end
    if tab['Columns'] then
        if type(tab['Columns']) == 'table' then
            for columnIdx,column in pairs(tab['Columns']) do
                valid = IsColumnValid(column, columnIdx) and valid
            end
        else
            return false
        end
    end
    return valid
end

local function ValidateSettings()
    local valid = true
    for idx,obsProp in pairs(settings['ObservedProperties']) do
        valid = IsObservedPropertyValid(obsProp, idx) and valid
    end
    for idx,nbProp in pairs(settings['NetBotsProperties']) do
        valid = IsNetBotsPropertyValid(nbProp, idx) and valid
    end
    for idx,spawnProp in pairs(settings['SpawnProperties']) do
        valid = IsSpawnPropertyValid(spawnProp, idx) and valid
    end
    for idx,column in pairs(settings['Columns']) do
        valid = IsColumnValid(column, idx) and valid
    end
    for idx,tab in pairs(settings['Tabs']) do
        valid = IsTabValid(tab, idx) and valid
    end
    if not valid then
        print_err('Exiting due to invalid configuration. Review the output above.')
        mq.exit()
    end
end

local function LoadSettingsFile()
    local lua_dir = mq.TLO.MacroQuest.Path():gsub('\\', '/') .. '/lua/'
    local settings_file = arg[1] or string.format('boxhud-settings-%s.lua', string.lower(mq.TLO.Me.Name()))
    local settings_path = lua_dir..settings_file
    local default_settings_path = lua_dir..'boxhud-settings.lua'

    if FileExists(settings_path) then
        print_msg('Loading settings from file: ' .. settings_file)
        settings = require(settings_file:gsub('.lua', ''))
        CheckOptionalSettings()
    else
        print_msg('Loading default settings from file: boxhud-settings')
        -- Default settings
        settings = require('boxhud-settings')
        -- Copy defaults into toon specific settings
        CopySettingsFile(default_settings_path, settings_path)
    end

    ValidateSettings()
end

local function ShouldObserveProperty(botName, obsProp)
    if not obsProp['DependsOnName'] then
        -- Does not depend on another property being observed
        return true
    elseif not obsProp['DependsOnValue'] or obsProp['DependsOnValue'] == '' then
        -- Does not care what the value is of the property, just that it is observed
        return true
    elseif obsProp['DependsOnValue'] then
        local dependentValue = mq.TLO.DanNet(botName).Observe(string.format('"%s"', obsProp['DependsOnName']))()
        if dependentValue and obsProp['DependsOnValue']:find(dependentValue) ~= nil then
            -- The value of the dependent property matches
            return true
        end
    end
    -- Do not observe the property
    return false
end

-- Verify all observed properties are set for the given toon
local function VerifyDependencyObserver(botName, obsProp)
    local verifyStartTime = os.time(os.date("!*t"))
    while not mq.TLO.DanNet(botName).ObserveSet('"'..obsProp['Name']..'"')() do
        mq.delay(100)
        if os.difftime(os.time(os.date("!*t")), verifyStartTime) > 20 then
            print_err('Timed out verifying observer for \ay'..botName)
            print_err('Exiting the script.')
            mq.exit()
        end
    end
    return
end

local function AddObserver(botName, obsProp, delay)
    if obsProp['DependsOnName'] then
        for _,prop in pairs(settings['ObservedProperties']) do
            if prop['Name'] == obsProp['DependsOnName'] then
                AddObserver(botName, prop, delay)
                VerifyDependencyObserver(botName, prop)
            end
        end
    end
    if ShouldObserveProperty(botName, obsProp) then
        -- Add the observation if it is not set
        if not mq.TLO.DanNet(botName).ObserveSet(string.format('"%s"', obsProp['Name']))() then
            mq.cmdf('/dobserve %s -q "%s"', botName, obsProp['Name'])
            mq.delay(100*delay)
        end
    end
end

local function RemoveObserver(botName, obsProp, delay)
    -- Drop the observation if it is set
    if mq.TLO.DanNet(botName).ObserveSet(string.format('"%s"', obsProp['Name']))() then
        mq.cmdf('/dobserve %s -q "%s" -drop', botName, obsProp['Name'])
        mq.delay(100*delay)
    end
end

-- Add or remove observers for the given toon
local function ManageObservers(botName, drop)
    local delay = 1+table.getn(peerTable)/10
    if drop then
        for _, obsProp in pairs(settings['ObservedProperties']) do
            RemoveObserver(botName, obsProp, delay)
        end
        observedToons[botName] = nil
    else
        if not observedToons[botName] then
            for _, obsProp in pairs(settings['ObservedProperties']) do
                AddObserver(botName, obsProp, delay)
            end
            observedToons[botName] = true
        end
    end
end

-- Verify all observed properties are set for the given toon
local function VerifyObservers(botName)
    for _, obsProp in pairs(settings['ObservedProperties']) do
        if ShouldObserveProperty(botName, obsProp) then
            if not mq.TLO.DanNet(botName).ObserveSet('"'..obsProp['Name']..'"')() then
                return false
            end
        end
    end
    return true
end

local function AddAndVerifyObservers(botName)
    print_msg('Waiting for observed properties to be added for: \ay'..botName)
    ManageObservers(botName, false)
    local verifyStartTime = os.time(os.date("!*t"))
    while not VerifyObservers(botName) do
        mq.delay(100)
        if os.difftime(os.time(os.date("!*t")), verifyStartTime) > 20 then
            print_err('Timed out verifying observers for \ay'..botName)
            print_err('Exiting the script.')
            mq.exit()
        end
    end
    print_msg('Added observed properties for: \ay'..botName)
end

local function SetText(value, thresholds, ascending, percentage)
    if thresholds ~= nil then
        local valueNum = tonumber(value)
        if valueNum == nil then
            return
        end
        if table.getn(thresholds) == 1 then -- red or green
            if valueNum >= thresholds[1] then
                if ascending then -- green if above
                    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                else -- red if above
                    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                end
            else
                if ascending then -- red if below
                    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                else -- green if below
                    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                end
            end
        elseif table.getn(thresholds) == 2 then -- red or yellow or green
            if valueNum >= thresholds[2] then
                if ascending then
                    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                else
                    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                end
            elseif valueNum >= thresholds[1] and valueNum < thresholds[2] then
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1) -- yellow
            else
                if ascending then
                    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                else
                    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                end
            end
        else -- white, unsupported # of threshold values
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
        end
    else -- white, no thresholds defined
        ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
    end
    if percentage then value = value..'%%' end
    if tonumber(value) then
        -- right align number values
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ImGui.GetColumnWidth() - ImGui.CalcTextSize(tostring(value)) 
            - ImGui.GetScrollX())
    end
    ImGui.Text(value)
    ImGui.PopStyleColor(1)
end

local resetObserversName = nil
local function DrawContextMenu(name, botName)
    if ImGui.BeginPopupContextItem("##popup"..name) then
        if ImGui.SmallButton("Target##"..name) then
            ImGui.CloseCurrentPopup()
            mq.cmdf('/target %s', name)
        end
        ImGui.SameLine()
        if ImGui.SmallButton("Nav To##"..name) then
            ImGui.CloseCurrentPopup()
            mq.cmdf('/nav spawn %s', name)
        end
        ImGui.SameLine()
        if ImGui.SmallButton("Come To Me##"..name) then
            ImGui.CloseCurrentPopup()
            mq.cmdf('/dex %s /nav id ${Me.ID} log=critical', name)
        end
        if ImGui.SmallButton("G Inv##"..name) then
            ImGui.CloseCurrentPopup()
            mq.cmdf('/invite %s', name)
        end
        ImGui.SameLine()
        if ImGui.SmallButton("R Inv##"..name) then
            ImGui.CloseCurrentPopup()
            mq.cmdf('/raidinvite %s', name)
        end
        ImGui.SameLine()
        if ImGui.SmallButton("DZAdd##"..name) then
            ImGui.CloseCurrentPopup()
            mq.cmdf('/dzadd %s', name)
        end
        ImGui.SameLine()
        if ImGui.SmallButton("TAdd##"..name) then
            ImGui.CloseCurrentPopup()
            mq.cmdf('/taskadd %s', name)
        end
        if ImGui.SmallButton("Reset Obs##"..name) then
            print_msg('Resetting observed properties for: \ay'..name)
            ImGui.CloseCurrentPopup()
            resetObserversName = name
        end
        ImGui.Text('Send Command to '..botName..': ')
        local textInput = ""
        textInput, selected = ImGui.InputText("##input"..name, textInput, 32)
        if selected then
            print_msg('Sending command: \ag/dex '..botName..' '..textInput)
            ImGui.CloseCurrentPopup()
            mq.cmdf('/dex %s %s', name, textInput)
        end
        ImGui.EndPopup()
    end
end

local storedCommand = nil
local function DrawNameButton(name, botName, botInZone, botInvis)
    -- Treat Name column special
    -- Fill name column
    local buttonText = TitleCase(botName)
    if botInZone then
        if not botInvis then
            ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
            --buttonText = TitleCase(botName)
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.26, 0.98, 0.98, 1)
            buttonText = '('..TitleCase(botName)..')'
        end
    else
        ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
    end

    if ImGui.SmallButton(buttonText..'##'..name) then
        storedCommand = string.format('/squelch /dex %s /foreground', name)
    end
    ImGui.PopStyleColor(1)
    -- Context menu not working when using table API
    DrawContextMenu(name, botName)
end

local function DrawColumnProperty(botValues, botClass, botInZone, column)
    if not column['InZone'] or (column['InZone'] and botInZone) then
        local value = 'NULL'
        if column['Properties'][botClass] then
            value = botValues[column['Properties'][botClass]]
        elseif column['Properties']['ranged'] and ranged[botClass] then
            value = botValues[column['Properties']['ranged']]
        elseif column['Properties']['hybrids'] and hybrids[botClass] then
            value = botValues[column['Properties']['hybrids']]
        elseif column['Properties']['caster'] and casters[botClass] then
            value = botValues[column['Properties']['caster']]
        elseif column['Properties']['melee'] and melee[botClass] then
            value = botValues[column['Properties']['melee']]
        end
        if (value == 'NULL' or value == '') and column['Properties']['all'] then
            value = botValues[column['Properties']['all']]
        end
        local thresholds = column['Thresholds']
        if value ~= 'NULL' then
            if column['Mappings'] and column['Mappings'][value] then
                value = column['Mappings'][value]
            end
            SetText(value, thresholds, column['Ascending'], column['Percentage'])
        end
    end
end

local function DrawColumnButton(name, columnName, columnAction)
    if ImGui.SmallButton(columnName..'##'..name) then
        storedCommand = columnAction:gsub('#botName#', name)
        print_msg('Run command: \ag'..storedCommand)
    end
end

local current_sort_specs = nil
local current_columns = nil
local function CompareWithSortSpecs(a, b)
    for n = 1, current_sort_specs.SpecsCount, 1 do
        -- Here we identify columns using the ColumnUserID value that we ourselves passed to TableSetupColumn()
        -- We could also choose to identify columns based on their index (sort_spec.ColumnIndex), which is simpler!
        local sort_spec = current_sort_specs:Specs(n)
        local delta = 0

        local column = current_columns[sort_spec.ColumnUserID]
        if not column then
            return a < b
        end
        local aVal = nil
        local bVal = nil
        if column['Name'] == 'Name' or not column['Properties'] or not column['Properties']['all'] then
            aVal = a
            bVal = b
        elseif dataTable[a] and dataTable[b] then
            aVal = dataTable[a][column['Properties']['all']] or -1
            bVal = dataTable[b][column['Properties']['all']] or -1
        else
            aVal = a
            bVal = b
        end
        if tonumber(aVal) ~= nil and tonumber(bVal) ~= nil then
            if tonumber(aVal) < tonumber(bVal) then
                delta = -1
            elseif tonumber(bVal) < tonumber(aVal) then
                delta = 1
            else
                delta = 0
            end
        else
            if aVal < bVal then
                delta = -1
            elseif bVal < aVal then
                delta = 1
            else
                delta = 0
            end
        end

        if delta ~= 0 then
            if sort_spec.SortDirection == ImGuiSortDirection.Ascending then
                return delta < 0
            end
            return delta > 0
        end
    end

    -- Always return a way to differentiate items.
    -- Your own compare function may want to avoid fallback on implicit sort specs e.g. a Name compare if it wasn't already part of the sort specs.
    return a < b
end

local function DrawHUDColumns(columns, tabName)
    local flags = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.MultiSortable,
            ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.ScrollY, ImGuiTableFlags.NoSavedSettings)
    if ImGui.BeginTable('##bhtable'..tabName..tostring(tableRandom), #columns, flags, 0, 0, 0.0) then
        for i, column in pairs(columns) do
            if column['Name'] == 'Name' then
                ImGui.TableSetupColumn('Name',         bit32.bor(ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.WidthFixed),   -1.0, i)
            elseif column['Type'] ~= 'button' then
                ImGui.TableSetupColumn(column['Name'], ImGuiTableColumnFlags.WidthFixed,                                                 -1.0, i)
            else
                ImGui.TableSetupColumn(column['Name'], bit32.bor(ImGuiTableColumnFlags.NoSort, ImGuiTableColumnFlags.WidthFixed),        -1.0, i)
            end
        end
        ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible
        local sort_specs = ImGui.TableGetSortSpecs()
        if sort_specs then
            if sort_specs.SpecsDirty or peersDirty then
                if #peerTable > 1 then
                    current_sort_specs = sort_specs
                    current_columns = columns
                    sortedPeers = TableClone(peerTable)
                    table.sort(sortedPeers, CompareWithSortSpecs)
                    current_sort_specs = nil
                    current_columns = nil
                end
                sort_specs.SpecsDirty = false
            end
        end

        -- Display data
        ImGui.TableHeadersRow()

        local clipper = ImGuiListClipper.new()
        if sortedPeers == nil then
            sortedPeers = TableClone(peerTable)
        end
        clipper:Begin(table.getn(sortedPeers))
        while clipper:Step() do
            for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
                local clipName = sortedPeers[row_n+1]
                local item = dataTable[clipName]
                if item ~= nil then
                    local botName = clipName
                    local botInZone = item['BotInZone']
                    local botInvis = item['Me.Invis']
                    local botClass = item[classVarName]
                    if botClass then
                        botClass = botClass:lower()
                    end
                    if anonymize then
                        botName = botClass
                    end
                    ImGui.PushID(clipName)
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    for i,column in pairs(columns) do
                        if column['Name'] == 'Name' then
                            DrawNameButton(clipName, botName, botInZone, botInvis)
                        else
                            -- Default column type is property (observed or spawn properties)
                            if not column['Type'] or column['Type'] == 'property' then
                                DrawColumnProperty(item, botClass, botInZone, column)
                            elseif column['Type'] == 'button' then
                                DrawColumnButton(clipName, column['Name'], column['Action'])
                            end
                        end
                        if i < #columns then
                            ImGui.TableNextColumn()
                        end
                    end
                    ImGui.PopID()
                end
            end
        end
        clipper:End()
        ImGui.EndTable()
    end
end

local function DrawHUDTabs()
    if ImGui.BeginTabBar('BOXHUDTABS') then
        for _, tab in pairs(settings['Tabs']) do
            ImGui.PushID(tab['Name'])
            if ImGui.BeginTabItem(tab['Name']) then
                if tab['Columns'] and #tab['Columns'] > 0 then
                    DrawHUDColumns(TableConcat(settings['Columns'], tab['Columns']), tab['Name'])
                    ImGui.EndTabItem()
                else
                    ImGui.Text('No columns defined for tab')
                    ImGui.EndTabItem()
                end
            end
            ImGui.PopID()
        end

        -- Admin tab only allows resetting observers, so only show if dannet is being used
        if IsUsingDanNet() then
            if ImGui.BeginTabItem('Admin') then
                ImGui.Text('Reset Observers for:')
                adminPeerSelected, clicked = ImGui.Combo("##combo", adminPeerSelected, peerTable, table.getn(peerTable), 5)
                ImGui.SameLine()
                if ImGui.Button('Reset') then
                    print_msg('Resetting observed properties for: \ay'..peerTable[adminPeerSelected+1])
                    resetObserversName = peerTable[adminPeerSelected+1]
                end
            end
        end
        ImGui.EndTabBar()
    end
end

-- ImGui main function for rendering the UI window
local HUDGUI = function()
    if mq.TLO.Me.CleanName() == 'load' then
        return
    end
    openGUI, shouldDrawGUI = ImGui.Begin('Box HUD##'..mq.TLO.Me.CleanName(), openGUI, ImGuiWindowFlags.NoTitleBar)
    if shouldDrawGUI then
        if initialRun and ImGui.GetWindowHeight() == 32 and ImGui.GetWindowWidth() == 32 then
            ImGui.SetWindowSize(460, 177)
            initialRun = false
        end
        if settings['Tabs'] and #settings['Tabs'] > 0 then
            DrawHUDTabs()
        elseif settings['Columns'] and #settings['Columns'] > 0 then
            DrawHUDColumns(settings['Columns'], 'notabs')
        end

        ImGui.End()
    end
end

local Admin = function(action, name)
    if action == nil then
        adminMode = not adminMode
        openGUI = not adminMode
        print_msg('Setting \ayadminMode\ax = \ay'..tostring(adminMode))
    elseif action == 'anon' then
        anonymize = not anonymize
    elseif action  == 'reset' then
        if not adminMode then
            print_err('\ayadminMode\ax must be enabled')
            return
        end
        if name == nil then
            print_msg('Resetting observed properties for: \ayALL')
            for _, botName in pairs(peerTable) do
                ManageObservers(botName, true)
            end
        else
            print_msg('Resetting observed properties for: \ay'..name)
            ManageObservers(name, true)
        end
    end
end

local Help = function()
    print_msg('Available commands:')
    print('\ao    /bhhelp\a-w -- Displays this help output')
    print('\ao    /bhversion\a-w -- Displays the version')
    print('\ao    /boxhud\a-w -- Toggle the display')
    print('\ao    /boxhudend\a-w -- End the script')
    print('\ao    /bhadmin\a-w -- Enable admin mode')
    print('\ao    /bhadmin anon\a-w -- Enable anon mode')
    print('\ao    /bhadmin reset all\a-w -- Reset DanNet Observed Properties for all toons')
    print('\ao    /bhadmin reset <name>\a-w -- Reset DanNet Observed Properties for <name>')
end

local ShowVersion = function()
    print_msg('Version '..VERSION)
end

local function SetupBindings()
    mq.bind('/bhversion', ShowVersion)

    mq.bind('/bhhelp', Help)

    mq.bind('/boxhud', function()
        openGUI = not openGUI
    end)

    mq.bind('/boxhudend', function() 
        mq.imgui.destroy('BOXHUDUI')
        shouldDrawGUI = false
        terminate = true
    end)

    mq.bind('/bhadmin', Admin)
end

local function UpdateBotValues(botName, currTime)
    local botValues = {}
    local botSpawnData = mq.TLO.Spawn('='..botName)
    botValues['Me.ID'] = botSpawnData.ID()
    botValues['Me.Invis'] = botSpawnData.Invis()
    
    -- Fill in data from this toons observed properties
    if IsUsingDanNet() then
        for _, obsProp in pairs(settings['ObservedProperties']) do
            if ShouldObserveProperty(botName, obsProp) then
                botValues[obsProp['Name']] = mq.TLO.DanNet(botName).Observe('"'..obsProp['Name']..'"')()
            else
                botValues[obsProp['Name']] = ''
            end
        end
    end
    if IsUsingNetBots() then
        for _, netbotsProp in pairs(settings['NetBotsProperties']) do
            -- tostring instead of ending with () because class returned a number instead of class string
            if netbotsProp['Name']:find('Class') then
                botValues[netbotsProp['Name']] = tostring(mq.TLO.NetBots(TitleCase(botName))[netbotsProp['Name']])
            else
                botValues[netbotsProp['Name']] = mq.TLO.NetBots(TitleCase(botName))[netbotsProp['Name']]()
            end
        end
    end
    if settings['SpawnProperties'] then
        for _, spawnProp in pairs(settings['SpawnProperties']) do
            if spawnProp['FromIDProperty'] then
                botValues[spawnProp['Name']] = mq.TLO.Spawn('id '..botValues[spawnProp['FromIDProperty']])[spawnProp['Name']]()
            else
                botValues[spawnProp['Name']] = botSpawnData[spawnProp['Name']]()
                if type(botValues[spawnProp['Name']]) == 'number' then
                    botValues[spawnProp['Name']] = string.format("%.2f", botValues[spawnProp['Name']])
                end
            end
        end
    end
    if peerGroup == 'all' then
        botValues['BotInZone'] = (botValues['Me.ID'] ~= nil)
    else
        botValues['BotInZone'] = true
    end
    botValues['lastUpdated'] = currTime
    dataTable[botName] = botValues
end

local function CleanupStaleData(currTime)
    for botName, botValues in pairs(dataTable) do
        if os.difftime(currTime, botValues['lastUpdated']) > staleDataTimeout then
            print_msg('Removing stale toon data: \ay'..botName)
            dataTable[botName] = nil
        end
    end
end

local function SendCommand()
    mq.cmdf(storedCommand)
    storedCommand = nil
end

local function CheckGameState()
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        print_err('\arNot in game, stopping boxhud.\ax')
        openGUI = false
        shouldDrawGUI = false
        mq.imgui.destroy('BOXHUDUI')
        mq.exit()
    end
end

local function main()
    LoadSettingsFile()
    PluginCheck()
    SetupBindings()

    -- Initialize peer list before the UI, since UI iterates over peer list
    peerTable = Peers()

    mq.imgui.init('BOXHUDUI', HUDGUI)

    -- Initial setup of observers
    if IsUsingDanNet() then
        for _, botName in pairs(peerTable) do
            AddAndVerifyObservers(botName)
        end
    end

    -- Main run loop to populate observed property data of toons
    while not terminate do
        CheckGameState()
        if storedCommand then
            SendCommand()
        end
        -- Update peerGroup if we've zoned and using the zone peer group
        if peerSource == 'dannet' and peerGroup ~= 'all' and zoneID ~= mq.TLO.Zone.ID() then
            peerGroup = GetZonePeerGroup()
            zoneID = mq.TLO.Zone.ID()
        end
        local currTime = os.time(os.date("!*t"))
        peerTable = Peers()
        for botIdx, botName in pairs(peerTable) do
            -- Ensure observers are set for the toon
            if IsUsingDanNet() then
                if resetObserversName == botName then
                    resetObserversName = nil
                    ManageObservers(botName, true)
                    AddAndVerifyObservers(botName)
                elseif not VerifyObservers(botName) or not observedToons[botName] then
                    AddAndVerifyObservers(botName)
                end
            end
            UpdateBotValues(botName, currTime)
        end
        CleanupStaleData(currTime)
        mq.delay(refreshInterval)
    end
end

main()
