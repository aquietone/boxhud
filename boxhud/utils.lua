-- boxhud.lua 1.8.1 -- aquietone
--- @type mq
local mq = require('mq')
local converter = require('boxhud.settings-converter')
dofile('boxhud/persistence.lua')

local lyaml = require('lyaml.init')
local utils = {}

VERSION = '2.0.0'

SETTINGS_FILE = nil

SETTINGS = {}
PEER_SOURCE = 'dannet'
-- Default DanNet peer group to use
PEER_GROUP = 'all'
CLASS_VAR = 'Me.Class.ShortName'
-- Default observer polling interval (0.25 seconds)
REFRESH_INTERVAL = 250
-- Default stale observed data timeout (60 seconds)
STALE_DATA_TIMEOUT = 60

local zoneID = nil
local isUsingDanNet = false
local isUsingNetBots = false

function print_msg(msg) print('\at[\ayBOXHUD\at] \at' .. msg) end
function print_err(msg) print('\at[\ayBOXHUD\at] \ar' .. msg) end

local function FileExists(path)
    local f = io.open(path, "r")
    if f ~= nil then io.close(f) return true else return false end
end

local function CopyFile(source, dest)
    local f = io.open(source, 'r')
    local contents = f:read('*a')
    io.close(f)
    f = io.open(dest, 'w')
    f:write(contents)
    io.close(f)
end

local function WriteFile(path, contents)
    local f = io.open(path, 'w')
    f:write(contents)
    io.close(f)
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

-- Create a table of {key:true, ..} from a list for checking a value is in the list 
function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

function TitleCase(phrase)
    local result = string.gsub( phrase, "(%a)([%w_']*)",
        function(first, rest)
            return first:upper() .. rest:lower()
        end
    )
    return result
end

function TableConcat(t1, t2)
    local t = {}
    for k,v in ipairs(t1) do
        table.insert(t, v)
    end
    for k,v in ipairs(t2) do
        table.insert(t, v)
    end
    return t
end

function TableClone(org)
    return {unpack(org)}
end

function IsUsingDanNet()
    return isUsingDanNet
end

-- Load required plugins
function PluginCheck()
    if isUsingDanNet then
        if not mq.TLO.Plugin('mq2dannet').IsLoaded() then
            print_msg("Plugin \ayMQ2DanNet\ax is required. Loading it now.")
            mq.cmd('/plugin mq2dannet noauto')
        end
        -- turn off fullname mode in DanNet
        if mq.TLO.DanNet.FullNames() then
            mq.cmd('/dnet fullnames off')
        end
    end
    if isUsingNetBots then
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

function DoTablesMatch(a, b)
    return table.concat(a) == table.concat(b)
end

function ZoneCheck()
    if PEER_SOURCE == 'dannet' and PEER_GROUP ~= 'all' and zoneID ~= mq.TLO.Zone.ID() then
        PEER_GROUP = GetZonePeerGroup()
        zoneID = mq.TLO.Zone.ID()
    end
end

local function GetZonePeerGroup()
    local zoneName = mq.TLO.Zone.ShortName()
    if zoneName:find('_') then
        return string.format('zone_%s', zoneName)
    else
        return string.format('zone_%s_%s', mq.TLO.EverQuest.Server(), zoneName)
    end
end

function ValidateProperty(propName, propSettings, idx)
    local message = nil
    if not propName or type(propName) ~= 'string' or string.len(propName) == 0 then
        message = 'Property name is invalid. Name must be a non-empty string'
        print_err(string.format('[%s %s] %s', propSettings['Type'], propName, message))
        return false, message
    else
        if propSettings['Type'] == 'Observed' then
            if propSettings['DependsOnName'] and not SETTINGS['Properties'][propSettings['DependsOnName']] then
                message = string.format(
                        '[Properties %s] \'DependsOnName\' must refer to another observed property name. DependsOnName=%s', 
                        propName, propSettings['DependsOnName'])
                print_err(message)
                return false, message
            end
            if propSettings['DependsOnValue'] and not propSettings['DependsOnName'] then
                message = string.format('[Properties %s] \'DependsOnValue\' requires \'DependsOnName\' to also be set', propName)
                print_err(message)
                return false, message
            end
            isUsingDanNet = true
        elseif propSettings['Type'] == 'Spawn' then
            if propSettings['FromIDProperty'] and not SETTINGS['Properties'][propSettings['FromIDProperty']] then
                message = string.format(
                        '[Properties %s] \'FromIDProperty\' must refer to a valid Observed or NetBots property. FromIDProperty=%s',
                        propName, propSettings['FromIDProperty'])
                print_err(message)
                return false, message
            end
        elseif propSettings['Type'] == 'NetBots' then
            isUsingNetBots = true
        else
            message = string.format('[Properties %s] Property type not supported. Type=%s', propName, propSettings['Type'])
            print_err(message)
            return false, message
        end
    end
    return true, nil
end

local function ValidateColumnProperties(properties, columnName)
    local message = nil
    local valid = true
    for _,propName in pairs(properties) do
        if not SETTINGS['Properties'][propName] then
            message = string.format('Column \'Properties\' must reference a valid \'Observed\', \'NetBots\' or \'Spawn\' property. Name=%s', propName)
            print_err(string.format('[Column %s] %s', columnName, message))
            valid = false
        end
    end
    return valid, message
end

local function ValidateColumnMappings(mappings)
    local valid = true
    -- what makes a mapping invalid?
    return valid
end

local function ValidateColumnThresholds(thresholds, columnName)
    local message = nil
    if #thresholds > 2 then
        message = 'Column \'Thresholds\' may contain either 1 or 2 number values, no more'
        print_err(string.format('[Column %s] %s', columnName, message))
        return false, message
    else
        for thresholdIdx, value in ipairs(thresholds) do
            if type(value) ~= 'number' then
                message = 'Column \'Thresholds\' values must be numbers in ascending order'
                print_err(string.format('[Column %s] %s', columnName, message))
                return false, message
            end
            if thresholdIdx == 2 and value < thresholds[1] then
                message = 'Column \'Thresholds\' values must be numbers in ascending order'
                print_err(string.format('[Column %s] %s', columnName, message))
                return false, message
            end
        end
    end
    return true, message
end

function ValidateColumn(columnName, columnSettings)
    local message = nil
    local columnType = 'property'
    if not columnName or type(columnName) ~= 'string' or string.len(columnName) == 0 then
        message = 'Columns name is invalid. Name must be a non-empty string.'
        print_err(string.format('[Column %s] %s', columnName, message))
        return false, message
    elseif columnName == 'Name' then
        -- special case name column
        return true, nil
    end
    if columnSettings['Type'] then
        if type(columnSettings['Type']) ~= 'string' or (columnSettings['Type'] ~= 'button' and columnSettings['Type'] ~= 'property') then
            message = string.format('Column Type must be \'property\' or \'button\'. Type=%s', columnSettings['Type'])
            print_err(string.format('[Column %s] %s', columnName, message))
            return false, message
        else
            columnType = columnSettings['Type']
        end
    end
    local valid = true
    if columnType == 'property' then
        if not columnSettings['Properties'] or type(columnSettings['Properties']) ~= 'table' then
            message = 'Property Columns must have a \'Properties\' table'
            print_err(string.format('[Column %s] %s', columnName, message))
            valid = false
        else
            local ok, m1 = ValidateColumnProperties(columnSettings['Properties'], columnName)
            if not ok then
                message = m1
                valid = false
            end
        end
        if columnSettings['Mappings'] then
            if type(columnSettings['Mappings']) ~= 'table' then
                message = 'Column \'Mappings\' must be a table'
                print_err(string.format('[Column %s] %s', columnName, message))
                valid = false
            else
                local ok, m1 = ValidateColumnMappings(columnSettings['Mappings'])
                if not ok then
                    message = m1
                    valid = false
                end
            end
        end
        if columnSettings['Thresholds'] then 
            if type(columnSettings['Thresholds']) ~= 'table' then
                message = 'Column \'Thresholds\' must be a table'
                print_err(string.format('[Column %s] %s', columnName, message))
                valid = false
            else
                local ok, m1 = ValidateColumnThresholds(columnSettings['Thresholds'], columnName)
                if not ok then
                    message = m1
                    valid = false
                end
            end
        end
        if columnSettings['Percentage'] ~= nil and type(columnSettings['Percentage']) ~= 'boolean' then
            message = 'Columns \'Percentage\' must be true or false'
            print_err(string.format('[Column %s] %s', columnName, message))
            valid = false
        end
        if columnSettings['Ascending'] ~= nil and type(columnSettings['Ascending']) ~= 'boolean' then
            message = 'Columns \'Ascending\' must be true or false'
            print_err(string.format('[Column %s] %s', columnName, message))
            valid = false
        end
        if columnSettings['InZone'] ~= nil and type(columnSettings['InZone']) ~= 'boolean' then
            message = 'Column \'InZone\' must be true or false'
            print_err(string.format('[Column %s] %s', columnName, message))
            valid = false
        end
    elseif columnType == 'button' then
        if not columnSettings['Action'] or type(columnSettings['Action']) ~= 'string' then
            message = 'Button Columns must have an \'Actions\' property'
            print_err(string.format('[Column %s] %s', columnName, message))
            valid = false
        end
    end
    return valid, message
end

function ValidateTab(tab, idx)
    local message = nil
    local valid = true
    if not tab['Name'] or type(tab['Name']) ~= 'string' or string.len(tab['Name']) == 0 then
        message = string.format('Tabs \'Name\' must be a non-empty \'string\'. Name=%s', tab['Name'])
        print_err(string.format('[Tab %d] %s', idx, message))
        return false, message
    end
    if tab['Columns'] then
        if type(tab['Columns']) == 'table' then
            for columnIdx,column in pairs(tab['Columns']) do
                if not SETTINGS['Columns'][column] then
                    message = 'tab includes bad column name'
                    print_err('tab includes bad column name')
                    valid = false
                end
            end
        else
            return false, 'Tab \'Columns\' is an unexpected format. \'Columns\' must be a table.'
        end
    end
    return valid, message
end

local function ValidateOptionalSettings()
    if SETTINGS['PeerSource'] then
        if SETTINGS['PeerSource'] ~= 'dannet' and  SETTINGS['PeerSource'] ~= 'netbots' then
            print_err('PeerSource must be either \'dannet\' or \'netbots\'')
            return false
        end
        PEER_SOURCE = SETTINGS['PeerSource']
    end
    if PEER_SOURCE == 'dannet' then
        isUsingDanNet = true
        if SETTINGS['DanNetPeerGroup'] and SETTINGS['DanNetPeerGroup'] == 'zone' then
            PEER_GROUP = GetZonePeerGroup()
            zoneID = mq.TLO.Zone.ID()
        end
        local classPropertyFound = false
        for propName, propSettings in pairs(SETTINGS['Properties']) do
            if (propName == 'Me.Class' or propName == 'Me.Class.ShortName') and propSettings['Type'] == 'Observed' then
                classPropertyFound = true
                CLASS_VAR = propName
            end
        end
        if not classPropertyFound then
            CLASS_VAR = 'Me.Class.ShortName'
            SETTINGS['Properties'][CLASS_VAR] = { Type='Observed' }
        end
    elseif PEER_SOURCE == 'netbots' then
        isUsingNetBots = true
        local classPropertyFound = false
        for propName, propSettings in pairs(SETTINGS['Properties']) do
            if propName == 'Class' and propSettings['Type'] == 'NetBots' then
                classPropertyFound = true
                CLASS_VAR = propName
            end
        end
        if not classPropertyFound then
            CLASS_VAR = 'Class'
            SETTINGS['Properties'][CLASS_VAR] = { Type='NetBots' }
        end
    end
    if SETTINGS['RefreshInterval'] and type(SETTINGS['RefreshInterval']) == 'number' then
        REFRESH_INTERVAL = SETTINGS['RefreshInterval']
    end
    if SETTINGS['StaleDataTimeout'] and type(SETTINGS['StaleDataTimeout']) == 'number' then
        STALE_DATA_TIMEOUT = SETTINGS['StaleDataTimeout']
    end
    return true
end

local function ValidateSettings()
    local valid = true
    valid = valid and ValidateOptionalSettings()
    for propName,propSettings in pairs(SETTINGS['Properties']) do
        valid,_ = ValidateProperty(propName, propSettings) and valid
    end
    for columnName,columnSettings in pairs(SETTINGS['Columns']) do
        valid,_ = ValidateColumn(columnName, columnSettings) and valid
    end
    for idx,tab in pairs(SETTINGS['Tabs']) do
        valid,_ = ValidateTab(tab, idx) and valid
    end
    if not valid then
        print_err('Exiting due to invalid configuration. Review the output above.')
        mq.exit()
    end
end

function LoadSettings(arg)
    local lua_dir = mq.TLO.MacroQuest.Path():gsub('\\', '/') .. '/lua'
    local boxhud_dir = lua_dir .. '/boxhud'
    SETTINGS_FILE = arg[1] or string.format('boxhud-settings-%s.lua', string.lower(mq.TLO.Me.Name()))
    local settings_path = string.format('%s/%s', boxhud_dir, SETTINGS_FILE)
    local yaml_settings_path = string.format('%s/boxhud-settings.yaml', boxhud_dir)
    local old_settings_path = string.format('%s/%s', lua_dir, SETTINGS_FILE)
    local default_settings_path = string.format('%s/%s', boxhud_dir, 'boxhud-settings.lua')

    if FileExists(settings_path) then
        print_msg('Loading settings from file: ' .. SETTINGS_FILE)
        SETTINGS = require(string.format('boxhud.%s', SETTINGS_FILE:gsub('.lua', '')))
    elseif FileExists(old_settings_path) then
        -- copy old settings to new location in boxhud folder
        print_msg(string.format('Moving lua/%s to lua/boxhud/%s', SETTINGS_FILE, SETTINGS_FILE))
        CopyFile(old_settings_path, settings_path)
        print_msg('Loading settings from file: ' .. SETTINGS_FILE)
        SETTINGS = require(string.format('boxhud.%s', SETTINGS_FILE:gsub('.lua', '')))
        --os.remove(old_settings_path)

        --local new_settings_path = string.format('%s/%s', boxhud_dir, 'newsettings.lua')
        --local new_settings = ConvertSettings(SETTINGS)
        --persistence.store(new_settings_path, new_settings)
    else
        print_msg('Loading default settings from file: boxhud-settings')
        -- Default settings
        SETTINGS = require('boxhud.boxhud-settings')
        -- Copy defaults into toon specific settings
        CopyFile(default_settings_path, settings_path)
    end

    if not SETTINGS['SchemaVersion'] or SETTINGS['SchemaVersion'] < 2 then
        SETTINGS = ConvertSettings(SETTINGS)
        --local backup_settings_path = string.format('%s/%s.bak', boxhud_dir, SETTINGS_FILE)
        --CopyFile(settings_path, backup_settings_path)
        --local new_settings_path = string.format('%s/%s', boxhud_dir, SETTINGS_FILE)
        --persistence.store(new_settings_path, SETTINGS)
    end
    ValidateSettings()

    --[[
    f = io.open(yaml_settings_path, 'w')
    f:write(lyaml.dump({SETTINGS}))
    io.close(f)
    f = io.open(yaml_settings_path, 'r')
    local contents = f:read('*a')
    io.close(f)
    SETTINGS = lyaml.load(contents)
    ValidateSettings()
    --]]
end

function SaveSettings()
    print(SETTINGS_FILE)
    local lua_dir = mq.TLO.MacroQuest.Path():gsub('\\', '/') .. '/lua'
    local boxhud_dir = lua_dir .. '/boxhud'
    local settings_path = string.format('%s/%s', boxhud_dir, SETTINGS_FILE)
    persistence.store(settings_path, SETTINGS)
end

return utils