-- boxhud/utils.lua 2.0.7 -- aquietone
--- @type mq
local mq = require('mq')
local converter = require('boxhud.settings-converter')
dofile('boxhud/persistence.lua')

VERSION = '2.0.7'

SETTINGS_FILE = nil

SETTINGS = {}
TRANSPARENCY = false
PEER_SOURCE = 'dannet'
-- Default DanNet peer group to use
PEER_GROUP = 'all'
CLASS_VAR = 'Me.Class.ShortName'
-- Default observer polling interval (0.25 seconds)
REFRESH_INTERVAL = 250
-- Default stale observed data timeout (60 seconds)
STALE_DATA_TIMEOUT = 60

local isUsingDanNet = false
local isUsingNetBots = false

function class(base, init)
    local c = {}    -- a new class instance
    if not init and type(base) == 'function' then
        init = base
        base = nil
    elseif type(base) == 'table' then
        -- our new class is a shallow copy of the base class!
        for i,v in pairs(base) do
            c[i] = v
        end
        c._base = base
    end
    -- the class will be the metatable for all its objects,
    -- and they will look up their methods in it.
    c.__index = c
 
    -- expose a constructor which can be called by <classname>(<args>)
    local mt = {}
    mt.__call = function(class_tbl, ...)
    local obj = {}
    setmetatable(obj,c)
    if init then
        init(obj,...)
    else 
        -- make sure that any stuff from the base class is initialized!
        if base and base.init then
        base.init(obj, ...)
        end
    end
    return obj
    end
    c.init = init
    c.is_a = function(self, klass)
        local m = getmetatable(self)
        while m do 
            if m == klass then return true end
            m = m._base
        end
        return false
    end
    setmetatable(c, mt)
    return c
end

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

local function GetZonePeerGroup()
    local zoneName = mq.TLO.Zone.ShortName()
    if zoneName:find('_') then
        return string.format('zone_%s', zoneName)
    else
        return string.format('zone_%s_%s', mq.TLO.EverQuest.Server(), zoneName)
    end
end

function ZoneCheck()
    if PEER_SOURCE == 'dannet' and SETTINGS['DanNetPeerGroup'] == 'zone' then
        PEER_GROUP = GetZonePeerGroup()
    end
end

Property = class(function(p,propSettings)
    p.Name = propSettings['Name']
    p.Type = propSettings['Type']
    p.DependsOnName = propSettings['DependsOnName']
    p.DependsOnValue = propSettings['DependsOnValue']
    p.FromIDProperty = propSettings['FromIDProperty']
end)

function Property:validate()
    local message = nil
    if not self.Name or type(self.Name) ~= 'string' or string.len(self.Name) == 0 then
        message = 'Property name is invalid. Name must be a non-empty string'
        print_err(string.format('[%s %s] %s', propSettings['Type'], propName, message))
        return false, message
    else
        if self.Type == 'Observed' then
            if self.DependsOnName and not SETTINGS['Properties'][self.DependsOnName] then
                message = string.format(
                        '[Properties %s] \'DependsOnName\' must refer to another observed property name. DependsOnName=%s', 
                        self.Name, self.DependsOnName)
                print_err(message)
                return false, message
            end
            if self.DependsOnValue and not self.DependsOnName then
                message = string.format('[Properties %s] \'DependsOnValue\' requires \'DependsOnName\' to also be set', self.Name)
                print_err(message)
                return false, message
            end
            isUsingDanNet = true
        elseif self.Type == 'Spawn' then
            if self.FromIDProperty and not SETTINGS['Properties'][self.FromIDProperty] then
                message = string.format(
                        '[Properties %s] \'FromIDProperty\' must refer to a valid Observed or NetBots property. FromIDProperty=%s',
                        self.Name, self.FromIDProperty)
                print_err(message)
                return false, message
            end
        elseif self.Type == 'NetBots' then
            isUsingNetBots = true
        else
            message = string.format('[Properties %s] Property type not supported. Type=%s', self.Name, self.Type)
            print_err(message)
            return false, message
        end
    end
    return true, nil
end

Column = class(function(c,columnSettings)
    c.Name = columnSettings['Name']
    c.Type = columnSettings['Type']
    c.Properties = columnSettings['Properties']
    c.Mappings = columnSettings['Mappings']
    c.Thresholds = columnSettings['Thresholds']
    c.Percentage = columnSettings['Percentage']
    c.Ascending = columnSettings['Ascending']
    c.InZone = columnSettings['InZone']
    c.Action = columnSettings['Action']
end)

function Column:validateProperties()
    local message = nil
    local valid = true
    for _,propName in pairs(self.Properties) do
        if string.len(propName) > 0 then
            if not SETTINGS['Properties'][propName] then
                message = string.format('Column \'Properties\' must reference a valid \'Observed\', \'NetBots\' or \'Spawn\' property. Name=%s', propName)
                print_err(string.format('[Column %s] %s', self.Name, message))
                valid = false
            end
        else
            message = 'Column \'Properties\' must be non-empty \'string\''
            print_err(string.format('[Column %s] %s', self.Name, message))
            valid = false
        end
    end
    return valid, message
end

function Column:validateMappings()
    local valid = true
    -- what makes a mapping invalid?
    return valid
end

function Column:validateThresholds()
    local message = nil
    if #self.Thresholds > 2 then
        message = 'Column \'Thresholds\' may contain either 1 or 2 number values, no more'
        print_err(string.format('[Column %s] %s', self.Name, message))
        return false, message
    else
        for thresholdIdx, value in ipairs(self.Thresholds) do
            if type(value) ~= 'number' then
                message = 'Column \'Thresholds\' values must be numbers in ascending order'
                print_err(string.format('[Column %s] %s', self.Name, message))
                return false, message
            end
            if thresholdIdx == 2 and value < self.Thresholds[1] then
                message = 'Column \'Thresholds\' values must be numbers in ascending order'
                print_err(string.format('[Column %s] %s', self.Name, message))
                return false, message
            end
        end
    end
    return true, message
end

function Column:validate()
    local message = nil
    if not self.Name or type(self.Name) ~= 'string' or string.len(self.Name) == 0 then
        message = 'Columns name is invalid. Name must be a non-empty string.'
        print_err(string.format('[Column %s] %s', self.Name, message))
        return false, message
    elseif self.Name == 'Name' then
        -- special case name column
        return true, nil
    end
    if self.Type then
        if type(self.Type) ~= 'string' or (self.Type ~= 'button' and self.Type ~= 'property') then
            message = string.format('Column Type must be \'property\' or \'button\'. Type=%s', self.Type)
            print_err(string.format('[Column %s] %s', self.Name, message))
            return false, message
        end
    else
        self.Type = 'property'
    end
    local valid = true
    if self.Type == 'property' then
        if not self.Properties or type(self.Properties) ~= 'table' then
            message = 'Property Columns must have a \'Properties\' table'
            print_err(string.format('[Column %s] %s', self.Name, message))
            valid = false
        else
            local ok, m1 = self:validateProperties()
            if not ok then
                message = m1
                valid = false
            end
        end
        if self.Mappings then
            if type(self.Mappings) ~= 'table' then
                message = 'Column \'Mappings\' must be a table'
                print_err(string.format('[Column %s] %s', self.Name, message))
                valid = false
            else
                local ok, m1 = self:validateMappings()
                if not ok then
                    message = m1
                    valid = false
                end
            end
        end
        if self.Thresholds then 
            if type(self.Thresholds) ~= 'table' then
                message = 'Column \'Thresholds\' must be a table'
                print_err(string.format('[Column %s] %s', self.Name, message))
                valid = false
            else
                local ok, m1 = self:validateThresholds()
                if not ok then
                    message = m1
                    valid = false
                end
            end
        end
        if self.Percentage and type(self.Percentage) ~= 'boolean' then
            message = 'Columns \'Percentage\' must be true or false'
            print_err(string.format('[Column %s] %s', self.Name, message))
            valid = false
        end
        if self.Ascending and type(self.Ascending) ~= 'boolean' then
            message = 'Columns \'Ascending\' must be true or false'
            print_err(string.format('[Column %s] %s', self.Name, message))
            valid = false
        end
        if self.InZone and type(self.InZone) ~= 'boolean' then
            message = 'Column \'InZone\' must be true or false'
            print_err(string.format('[Column %s] %s', self.Name, message))
            valid = false
        end
    elseif self.Type == 'button' then
        if not self.Action or type(self.Action) ~= 'string' then
            message = 'Button Columns must have an \'Actions\' property'
            print_err(string.format('[Column %s] %s', self.Name, message))
            valid = false
        end
    end
    return valid, message
end

Tab = class(function(t,tabSettings)
    t.Name = tabSettings['Name']
    t.Columns = tabSettings['Columns']
end)

function Tab:validate()
    local message = nil
    local valid = true
    if not self.Name or type(self.Name) ~= 'string' or string.len(self.Name) == 0 then
        message = string.format('Tabs \'Name\' must be a non-empty \'string\'. Name=%s', self.Name)
        print_err(string.format('[Tab %s] %s', self.Name, message))
        return false, message
    end
    if self.Columns then
        if type(self.Columns) == 'table' then
            for columnIdx,column in ipairs(self.Columns) do
                if string.len(column) > 0 then
                    if not SETTINGS['Columns'][column] then
                        message = string.format('Tab references a column which does not exist. Column=%s', column)
                        print_err(string.format('[Tab %s] %s', self.Name, message))
                        valid = false
                    end
                else
                    message = 'Tab \'Column\' values must be non-empty \'string\''
                    print_err(string.format('[Tab %s] %s', self.Name, message))
                    valid = false
                end
            end
        else
            message = 'Tab \'Columns\' is an unexpected format. \'Columns\' must be a table.'
            print_err(string.format('[Tab %s] %s', self.Name, message))
            valid = false
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
        if SETTINGS['DanNetPeerGroup'] then
            if SETTINGS['DanNetPeerGroup'] == 'zone' then
                PEER_GROUP = GetZonePeerGroup()
            else
                PEER_GROUP = SETTINGS['DanNetPeerGroup']
            end
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
    if not SETTINGS['Colors'] then
        SETTINGS['Colors'] = {}
    end
    SETTINGS['Colors']['Default'] = SETTINGS['Colors']['Default'] or {1,1,1}
    SETTINGS['Colors']['Low'] = SETTINGS['Colors']['Low'] or {1,0,0}
    SETTINGS['Colors']['Medium'] = SETTINGS['Colors']['Medium'] or {1,1,0}
    SETTINGS['Colors']['High'] = SETTINGS['Colors']['High'] or  {0,1,0}
    SETTINGS['Colors']['True'] = SETTINGS['Colors']['True'] or {0,1,0}
    SETTINGS['Colors']['False'] = SETTINGS['Colors']['False'] or {1,0,0}
    SETTINGS['Colors']['InZone'] = SETTINGS['Colors']['InZone'] or {0,1,0}
    SETTINGS['Colors']['Invis'] = SETTINGS['Colors']['Invis'] or {0.26, 0.98, 0.98}
    SETTINGS['Colors']['NotInZone'] = SETTINGS['Colors']['NotInZone'] or {1,0,0}
    return true
end

local function ValidateSettings()
    local valid = true
    valid = valid and ValidateOptionalSettings()
    if not SETTINGS['Properties'] then
        SETTINGS['Properties'] = {}
    end
    for propName,propSettings in pairs(SETTINGS['Properties']) do
        local property = Property(propSettings)
        property['Name'] = propName
        valid,_ = property:validate() and valid
        SETTINGS['Properties'][propName] = property
    end
    if not SETTINGS['Columns'] then
        SETTINGS['Columns'] = {}
    end
    for columnName,columnSettings in pairs(SETTINGS['Columns']) do
        local column = Column(columnSettings)
        column['Name'] = columnName
        valid,_ = column:validate() and valid
        SETTINGS['Columns'][columnName] = column
    end
    if not SETTINGS['Columns']['Name'] then
        SETTINGS['Columns']['Name'] = {
            ["Name"] = "Name",
            ["Type"] = "property",
			["InZone"] = false,
			["Percentage"] = false
        }
    end
    if not SETTINGS['Tabs'] then
        SETTINGS['Tabs'] = {}
    end
    for idx,tabSettings in pairs(SETTINGS['Tabs']) do
        local tab = Tab(tabSettings)
        valid,_ = tab:validate() and valid
        SETTINGS['Tabs'][idx] = tab
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
    else
        print_msg('Loading default settings from file: boxhud-settings')
        -- Default settings
        SETTINGS = require('boxhud.boxhud-settings')
        -- Copy defaults into toon specific settings
        CopyFile(default_settings_path, settings_path)
    end

    if not SETTINGS['SchemaVersion'] or SETTINGS['SchemaVersion'] < 2 then
        SETTINGS = ConvertSettings(SETTINGS)
    end
    ValidateSettings()
end

function SaveSettings()
    local lua_dir = mq.TLO.MacroQuest.Path():gsub('\\', '/') .. '/lua'
    local boxhud_dir = lua_dir .. '/boxhud'
    local settings_path = string.format('%s/%s', boxhud_dir, SETTINGS_FILE)
    persistence.store(settings_path, SETTINGS)
    return true
end
