-- boxhud.lua 1.8.1 -- aquietone
--- @type mq
local mq = require('mq')
local converter = require('boxhud.settings-converter')
dofile('boxhud/persistence.lua')

local utils = {}

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

local function ValidateProperty(propName, propSettings, idx)
    if not propName or type(propName) ~= 'string' then
        print_err(string.format('[%s %s] Property name is invalid. Must be a string', propSettings['Type'], propName))
        return false
    else
        if propSettings['Type'] == 'Observed' then
            if propSettings['DependsOnName'] and not SETTINGS['Properties'][propSettings['DependsOnName']] then
                print_err(string.format(
                        '[Properties %s] \'DependsOnName\' must refer to another observed property name. DependsOnName=%s', 
                        propName, propSettings['DependsOnName'])
                    )
                return false
            end
            if propSettings['DependsOnValue'] and not propSettings['DependsOnName'] then
                print_err(string.format('[Properties %s] \'DependsOnValue\' requires \'DependsOnName\' to also be set', propName))
                return false
            end
            isUsingDanNet = true
        elseif propSettings['Type'] == 'Spawn' then
            if propSettings['FromIDProperty'] and not SETTINGS['Properties'][property['FromIDProperty']] then
                print_err(string.format(
                        '[Properties %s] \'FromIDProperty\' must refer to a valid Observed or NetBots property. FromIDProperty=%s',
                        propName, propSettings['FromIDProperty'])
                    )
                return false
            end
        elseif propSettings['Type'] == 'NetBots' then
            isUsingNetBots = true
        else
            print_err(string.format('[Properties %s] Property type not supported. Type=%s', propName, propSettings['Type']))
            return false
        end
    end
    return true
end

local function ValidateColumnProperties(properties, columnName)
    local valid = true
    for _,propName in pairs(properties) do
        if not SETTINGS['Properties'][propName] then
            print_err(string.format('[Column %s] Column \'Properties\' must reference a valid \'Observed\', \'NetBots\' or \'Spawn\' property. Name=%s', columnName, propName))
            valid = false
        end
    end
    return valid
end

local function ValidateColumnMappings(mappings)
    local valid = true
    -- what makes a mapping invalid?
    return valid
end

local function ValidateColumnThresholds(thresholds, columnName)
    if #thresholds > 2 then
        print_err(string.format('[Column %s] Column \'Thresholds\' may contain either 1 or 2 number values, no more', columnName))
        return false
    else
        for threshholdIdx, value in ipairs(thresholds) do
            if type(value) ~= 'number' then
                print_err(string.format('[Column %s] Column \'Thresholds\' values must be numbers in ascending order', columnName))
                return false
            end
            if threshholdIdx == 2 and value < thresholds[1] then
                print_err(string.format('[Column %s] Column \'Thresholds\' values must be in ascending order', columnName))
                return false
            end
        end
    end
    return true
end

local function ValidateColumn(columnName, columnSettings)
    local columnType = 'property'
    if not columnName or type(columnName) ~= 'string' then
        print_err(string.format('[Column %s] Columns name is invalid. Must be a string.', columnName))
        return false
    elseif columnName == 'Name' then
        -- special case name column
        return true
    end
    if columnSettings['Type'] then
        if type(columnSettings['Type']) ~= 'string' or (columnSettings['Type'] ~= 'button' and columnSettings['Type'] ~= 'property') then
            print_err(string.format('[Column %s] Column Type must be \'property\' or \'button\'. Type=%s', columnName, columnSettings['Type']))
            return false
        else
            columnType = columnSettings['Type']
        end
    end
    local valid = true
    if columnType == 'property' then
        if not columnSettings['Properties'] or type(columnSettings['Properties']) ~= 'table' then
            print_err(string.format('[Column %s] Property Columns must have a \'Properties\' table', columnName))
            valid = false
        elseif not ValidateColumnProperties(columnSettings['Properties'], columnName) then
            valid = false
        end
        if columnSettings['Mappings'] then
            if type(columnSettings['Mappings']) ~= 'table' then
                print_err(string.format('[Column %s] Column \'Mappings\' must be a table', columnName))
                valid = false
            elseif not ValidateColumnMappings(columnSettings['Mappings']) then
                valid = false
            end
        end
        if columnSettings['Thresholds'] then 
            if type(columnSettings['Thresholds']) ~= 'table' then
                print_err(string.format('[Column %s] Column \'Thresholds\' must be a table', columnName))
                valid = false
            elseif not ValidateColumnThresholds(columnSettings['Thresholds'], columnName) then
                valid = false
            end
        end
        if columnSettings['Percentage'] ~= nil and type(columnSettings['Percentage']) ~= 'boolean' then
            print_err(string.format('[Column %s] Columns \'Percentage\' must be true or false', columnName))
            valid = false
        end
        if columnSettings['Ascending'] ~= nil and type(columnSettings['Ascending']) ~= 'boolean' then
            print_err(string.format('[Column %s] Columns \'Ascending\' must be true or false', columnName))
            valid = false
        end
        if columnSettings['InZone'] ~= nil and type(columnSettings['InZone']) ~= 'boolean' then
            print_err(string.format('[Column %s] Column \'InZone\' must be true or false', columnName))
            valid = false
        end
    elseif columnType == 'button' then
        if not columnSettings['Action'] or type(columnSettings['Action']) ~= 'string' then
            print_err(string.format('[Column %s] Button Columns must have an \'Actions\' property', columnName))
            valid = false
        end
    end
    return valid
end

local function ValidateTab(tab, idx)
    local valid = true
    if not tab['Name'] or type(tab['Name']) ~= 'string' then
        print_err(string.format('[Tab %d] Tabs must have a \'Name\' property of type \'string\'. Name=%s', idx, tab['Name']))
        return false
    end
    if tab['Columns'] then
        if type(tab['Columns']) == 'table' then
            for columnIdx,column in pairs(tab['Columns']) do
                if not SETTINGS['Columns'][column] then
                    print_err('tab includes bad column name')
                    valid = false
                end
            end
        else
            return false
        end
    end
    return valid
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
        valid = ValidateProperty(propName, propSettings) and valid
    end
    for columnName,columnSettings in pairs(SETTINGS['Columns']) do
        valid = ValidateColumn(columnName, columnSettings) and valid
    end
    for idx,tab in pairs(SETTINGS['Tabs']) do
        valid = ValidateTab(tab, idx) and valid
    end
    if not valid then
        print_err('Exiting due to invalid configuration. Review the output above.')
        mq.exit()
    end
end

function LoadSettings(arg)
    local lua_dir = mq.TLO.MacroQuest.Path():gsub('\\', '/') .. '/lua'
    local boxhud_dir = lua_dir .. '/boxhud'
    local settings_file = arg[1] or string.format('boxhud-settings-%s.lua', string.lower(mq.TLO.Me.Name()))
    local settings_path = string.format('%s/%s', boxhud_dir, settings_file)
    local old_settings_path = string.format('%s/%s', lua_dir, settings_file)
    local default_settings_path = string.format('%s/%s', boxhud_dir, 'boxhud-settings.lua')

    if FileExists(settings_path) then
        print_msg('Loading settings from file: ' .. settings_file)
        SETTINGS = require(string.format('boxhud/%s', settings_file:gsub('.lua', '')))
    elseif FileExists(old_settings_path) then
        -- copy old settings to new location in boxhud folder
        print_msg(string.format('Moving lua/%s to lua/boxhud/%s', settings_file, settings_file))
        CopyFile(old_settings_path, settings_path)
        print_msg('Loading settings from file: ' .. settings_file)
        SETTINGS = require(string.format('boxhud/%s', settings_file:gsub('.lua', '')))
        --os.remove(old_settings_path)

        --local new_settings_path = string.format('%s/%s', boxhud_dir, 'newsettings.lua')
        --local new_settings = ConvertSettings(SETTINGS)
        --persistence.store(new_settings_path, new_settings)
    else
        print_msg('Loading default settings from file: boxhud-settings')
        -- Default settings
        SETTINGS = require('boxhud/boxhud-settings')
        -- Copy defaults into toon specific settings
        CopyFile(default_settings_path, settings_path)
    end

    if not SETTINGS['SchemaVersion'] or SETTINGS['SchemaVersion'] < 2 then
        SETTINGS = ConvertSettings(SETTINGS)
        local backup_settings_path = string.format('%s/%s.bak', boxhud_dir, settings_file)
        CopyFile(settings_path, backup_settings_path)
        local new_settings_path = string.format('%s/%s', boxhud_dir, settings_file)
        persistence.store(new_settings_path, SETTINGS)
    end
    ValidateSettings()
end

return utils