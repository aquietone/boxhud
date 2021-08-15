-- boxhud/utils.lua 2.1.4 -- aquietone
--- @type mq
local mq = require('mq')
local converter = require('boxhud.settings-converter')
dofile('boxhud/persistence.lua')

local utils = {
    version = '2.1.4',
    settings = {},
    peer_source = 'dannet',
    peer_groups = {},
    class_var = 'Me.Class.ShortName',
    -- Default observer polling interval (0.25 seconds)
    refresh_interval = 250,
    -- Default stale observed data timeout (60 seconds)
    stale_data_timeout = 60
}

local settings_file = nil

local isUsingDanNet = false
local isUsingNetBots = false

utils.class = function(base, init)
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

function utils.print_msg(msg) print('\at[\ayBOXHUD\at] \at' .. msg) end
function utils.print_err(msg) print('\at[\ayBOXHUD\at] \ar' .. msg) end

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
utils.Split = function(input, sep)
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
utils.Set = function(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

utils.TitleCase = function(phrase)
    local result = string.gsub( phrase, "(%a)([%w_']*)",
        function(first, rest)
            return first:upper() .. rest:lower()
        end
    )
    return result
end

utils.TableConcat = function(t1, t2)
    local t = {}
    for k,v in ipairs(t1) do
        table.insert(t, v)
    end
    for k,v in ipairs(t2) do
        table.insert(t, v)
    end
    return t
end

utils.TableClone = function(org)
    return {unpack(org)}
end

utils.TableLength = function(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
 end

utils.DoTablesMatch = function(a, b)
    return table.concat(a) == table.concat(b)
end

utils.IsUsingDanNet = function()
    return isUsingDanNet
end

-- Load required plugins
utils.PluginCheck = function()
    if isUsingDanNet then
        if not mq.TLO.Plugin('mq2dannet').IsLoaded() then
            utils.print_msg("Plugin \ayMQ2DanNet\ax is required. Loading it now.")
            mq.cmd('/plugin mq2dannet noauto')
        end
        -- turn off fullname mode in DanNet
        if mq.TLO.DanNet.FullNames() then
            mq.cmd('/dnet fullnames off')
        end
    end
    if isUsingNetBots then
        if not mq.TLO.Plugin('mq2eqbc').IsLoaded() then
            utils.print_msg("Plugin \ayMQ2EQBC\ax is required. Loading it now.")
            mq.cmd('/plugin mq2eqbc noauto')
        end
        if not mq.TLO.Plugin('mq2netbots').IsLoaded() then
            utils.print_msg("Plugin \ayMQ2NetBots\ax is required. Loading it now.")
            mq.cmd('/plugin mq2netbots noauto')
        end
    end
end

utils.GetZonePeerGroup = function()
    local zoneName = mq.TLO.Zone.ShortName()
    if zoneName:find('_') then
        return string.format('zone_%s', zoneName)
    else
        return string.format('zone_%s_%s', mq.TLO.EverQuest.Server(), zoneName)
    end
end

utils.GetTabByName = function(tabName)
    for _,tab in ipairs(utils.settings['Tabs']) do
        if tab['Name'] == tabName then
            return tab
        end
    end
    return nil
end

local Property = utils.class(function(p,propSettings)
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
        utils.print_err(string.format('[%s %s] %s', self.Type, self.Name, message))
        return false, message
    else
        if self.Type == 'Observed' then
            if self.DependsOnName and not utils.settings['Properties'][self.DependsOnName] then
                message = string.format(
                        '[Properties %s] \'DependsOnName\' must refer to another observed property name. DependsOnName=%s', 
                        self.Name, self.DependsOnName)
                utils.print_err(message)
                return false, message
            end
            if self.DependsOnValue and not self.DependsOnName then
                message = string.format('[Properties %s] \'DependsOnValue\' requires \'DependsOnName\' to also be set', self.Name)
                utils.print_err(message)
                return false, message
            end
            isUsingDanNet = true
        elseif self.Type == 'Spawn' then
            if self.FromIDProperty and not utils.settings['Properties'][self.FromIDProperty] then
                message = string.format(
                        '[Properties %s] \'FromIDProperty\' must refer to a valid Observed or NetBots property. FromIDProperty=%s',
                        self.Name, self.FromIDProperty)
                utils.print_err(message)
                return false, message
            end
        elseif self.Type == 'NetBots' then
            isUsingNetBots = true
        else
            message = string.format('[Properties %s] Property type not supported. Type=%s', self.Name, self.Type)
            utils.print_err(message)
            return false, message
        end
    end
    return true, nil
end

local Column = utils.class(function(c,columnSettings)
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
            if not utils.settings['Properties'][propName] then
                message = string.format('Column \'Properties\' must reference a valid \'Observed\', \'NetBots\' or \'Spawn\' property. Name=%s', propName)
                utils.print_err(string.format('[Column %s] %s', self.Name, message))
                valid = false
            end
        else
            message = 'Column \'Properties\' must be non-empty \'string\''
            utils.print_err(string.format('[Column %s] %s', self.Name, message))
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
        utils.print_err(string.format('[Column %s] %s', self.Name, message))
        return false, message
    else
        for thresholdIdx, value in ipairs(self.Thresholds) do
            if type(value) ~= 'number' then
                message = 'Column \'Thresholds\' values must be numbers in ascending order'
                utils.print_err(string.format('[Column %s] %s', self.Name, message))
                return false, message
            end
            if thresholdIdx == 2 and value < self.Thresholds[1] then
                message = 'Column \'Thresholds\' values must be numbers in ascending order'
                utils.print_err(string.format('[Column %s] %s', self.Name, message))
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
        utils.print_err(string.format('[Column %s] %s', self.Name, message))
        return false, message
    elseif self.Name == 'Name' then
        -- special case name column
        return true, nil
    end
    if self.Type then
        if type(self.Type) ~= 'string' or (self.Type ~= 'button' and self.Type ~= 'property') then
            message = string.format('Column Type must be \'property\' or \'button\'. Type=%s', self.Type)
            utils.print_err(string.format('[Column %s] %s', self.Name, message))
            return false, message
        end
    else
        self.Type = 'property'
    end
    local valid = true
    if self.Type == 'property' then
        if not self.Properties or type(self.Properties) ~= 'table' then
            message = 'Property Columns must have a \'Properties\' table'
            utils.print_err(string.format('[Column %s] %s', self.Name, message))
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
                utils.print_err(string.format('[Column %s] %s', self.Name, message))
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
                utils.print_err(string.format('[Column %s] %s', self.Name, message))
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
            utils.print_err(string.format('[Column %s] %s', self.Name, message))
            valid = false
        end
        if self.Ascending and type(self.Ascending) ~= 'boolean' then
            message = 'Columns \'Ascending\' must be true or false'
            utils.print_err(string.format('[Column %s] %s', self.Name, message))
            valid = false
        end
        if self.InZone and type(self.InZone) ~= 'boolean' then
            message = 'Column \'InZone\' must be true or false'
            utils.print_err(string.format('[Column %s] %s', self.Name, message))
            valid = false
        end
    elseif self.Type == 'button' then
        if not self.Action or type(self.Action) ~= 'string' then
            message = 'Button Columns must have an \'Actions\' property'
            utils.print_err(string.format('[Column %s] %s', self.Name, message))
            valid = false
        end
    end
    return valid, message
end

local Tab = utils.class(function(t,tabSettings)
    t.Name = tabSettings['Name']
    t.Columns = tabSettings['Columns']
end)

function Tab:validate()
    local message = nil
    local valid = true
    if not self.Name or type(self.Name) ~= 'string' or string.len(self.Name) == 0 then
        message = string.format('Tabs \'Name\' must be a non-empty \'string\'. Name=%s', self.Name)
        utils.print_err(string.format('[Tab %s] %s', self.Name, message))
        return false, message
    end
    if self.Columns then
        if type(self.Columns) == 'table' then
            for columnIdx,column in ipairs(self.Columns) do
                if string.len(column) > 0 then
                    if not utils.settings['Columns'][column] then
                        message = string.format('Tab references a column which does not exist. Column=%s', column)
                        utils.print_err(string.format('[Tab %s] %s', self.Name, message))
                        valid = false
                    end
                else
                    message = 'Tab \'Column\' values must be non-empty \'string\''
                    utils.print_err(string.format('[Tab %s] %s', self.Name, message))
                    valid = false
                end
            end
        else
            message = 'Tab \'Columns\' is an unexpected format. \'Columns\' must be a table.'
            utils.print_err(string.format('[Tab %s] %s', self.Name, message))
            valid = false
        end
    end
    return valid, message
end

local Window = utils.class(function(w,windowSettings)
    w.Name = windowSettings['Name']
    w.PeerGroup = windowSettings['PeerGroup']
    w.Tabs = windowSettings['Tabs']
end)

function Window:validate()
    local message = nil
    local valid = true
    if not self.Name or type(self.Name) ~= 'string' or string.len(self.Name) == 0 then
        message = 'Window name is invalid. Name must be a non-empty string'
        utils.print_err(string.format('[Window %s] %s', self.Name, message))
        return false, message
    end
    if self.Tabs then
        if type(self.Tabs) == 'table' then
            for tabIdx,tab in ipairs(self.Tabs) do
                if string.len(tab) > 0 then
                    if not utils.GetTabByName(tab) then
                        message = string.format('Window references a tab which does not exist. Tab=%s', tab)
                        utils.print_err(string.format('[Window %s] %s', self.Name, message))
                        valid = false
                    end
                else
                    message = 'Window \'Tab\' values must be non-empty \'string\''
                    utils.print_err(string.format('[Window %s] %s', self.Name, message))
                    valid = false
                end
            end
        else
            message = 'Window \'Tab\' is an unexpected format. \'Tabs\' must be a table.'
            utils.print_err(string.format('[Window %s] %s', self.Name, message))
            valid = false
        end
    end
    return valid, message
end

local function ValidateOptionalSettings()
    if not utils.settings['Windows'] then
        utils.print_msg('No windows defined, adding default')
        utils.settings['Windows'] = {
            ['default'] = Window({Name='default',Tabs={},Transparency=false})
        }
        for _,tab in ipairs(utils.settings['Tabs']) do
            table.insert(utils.settings['Windows']['default']['Tabs'], tab['Name'])
        end
        if utils.settings['PeerSource'] and utils.settings['PeerSource'] == 'dannet' then
            utils.print_msg('Setting default window peer group to '..utils.settings['DanNetPeerGroup'])
            utils.settings['Windows']['default']['PeerGroup'] = utils.settings['DanNetPeerGroup']
        end
    else
        for name,window in pairs(utils.settings['Windows']) do
            utils.settings['Windows'][name] = Window(window)
        end
    end

    if utils.settings['PeerSource'] then
        if utils.settings['PeerSource'] ~= 'dannet' and  utils.settings['PeerSource'] ~= 'netbots' then
            utils.print_err('PeerSource must be either \'dannet\' or \'netbots\'')
            return false
        end
        utils.peer_source = utils.settings['PeerSource']
    end
    if utils.peer_source == 'dannet' then
        isUsingDanNet = true
        local classPropertyFound = false
        for propName, propSettings in pairs(utils.settings['Properties']) do
            if (propName == 'Me.Class' or propName == 'Me.Class.ShortName') and propSettings['Type'] == 'Observed' then
                classPropertyFound = true
                utils.class_var = propName
            end
        end
        if not classPropertyFound then
            utils.class_var = 'Me.Class.ShortName'
            utils.settings['Properties'][utils.class_var] = { Type='Observed' }
        end
    elseif utils.peer_source == 'netbots' then
        isUsingNetBots = true
        if table.getn(utils.settings['Windows']) > 1 then
            utils.print_err('NetBots only supports 1 window')
            return false
        end
        local classPropertyFound = false
        for propName, propSettings in pairs(utils.settings['Properties']) do
            if propName == 'Class' and propSettings['Type'] == 'NetBots' then
                classPropertyFound = true
                utils.class_var = propName
            end
        end
        if not classPropertyFound then
            utils.class_var = 'Class'
            utils.settings['Properties'][utils.class_var] = { Type='NetBots' }
        end
    end
    if utils.settings['RefreshInterval'] and type(utils.settings['RefreshInterval']) == 'number' then
        utils.refresh_interval = utils.settings['RefreshInterval']
    end
    if utils.settings['StaleDataTimeout'] and type(utils.settings['StaleDataTimeout']) == 'number' then
        utils.stale_data_timeout = utils.settings['StaleDataTimeout']
    end
    if not utils.settings['Colors'] then
        utils.settings['Colors'] = {}
    end
    utils.settings['Colors']['Default'] = utils.settings['Colors']['Default'] or {1,1,1}
    utils.settings['Colors']['Low'] = utils.settings['Colors']['Low'] or {1,0,0}
    utils.settings['Colors']['Medium'] = utils.settings['Colors']['Medium'] or {1,1,0}
    utils.settings['Colors']['High'] = utils.settings['Colors']['High'] or  {0,1,0}
    utils.settings['Colors']['True'] = utils.settings['Colors']['True'] or {0,1,0}
    utils.settings['Colors']['False'] = utils.settings['Colors']['False'] or {1,0,0}
    utils.settings['Colors']['InZone'] = utils.settings['Colors']['InZone'] or {0,1,0}
    utils.settings['Colors']['Invis'] = utils.settings['Colors']['Invis'] or {0.26, 0.98, 0.98}
    utils.settings['Colors']['IVU'] = utils.settings['Colors']['IVU'] or {0.95, 0.98, 0.26}
    utils.settings['Colors']['DoubleInvis'] = utils.settings['Colors']['DoubleInvis'] or {0.68, 0.98, 0.98}
    utils.settings['Colors']['NotInZone'] = utils.settings['Colors']['NotInZone'] or {1,0,0}
    utils.settings['Transparency'] = utils.settings['Transparency'] or false
    utils.settings['TitleBar'] = utils.settings['TitleBar'] or false
    return true
end

local function ValidateSettings()
    local valid = true
    valid = valid and ValidateOptionalSettings()
    if not utils.settings['Properties'] then
        utils.settings['Properties'] = {}
    end
    for propName,propSettings in pairs(utils.settings['Properties']) do
        local property = Property(propSettings)
        property['Name'] = propName
        valid,_ = property:validate() and valid
        utils.settings['Properties'][propName] = property
    end
    if not utils.settings['Columns'] then
        utils.settings['Columns'] = {}
    end
    for columnName,columnSettings in pairs(utils.settings['Columns']) do
        local column = Column(columnSettings)
        column['Name'] = columnName
        valid,_ = column:validate() and valid
        utils.settings['Columns'][columnName] = column
    end
    if not utils.settings['Columns']['Name'] then
        utils.settings['Columns']['Name'] = {
            ["Name"] = "Name",
            ["Type"] = "property",
			["InZone"] = false,
			["Percentage"] = false
        }
    end
    if not utils.settings['Tabs'] then
        utils.settings['Tabs'] = {}
    end
    for idx,tabSettings in pairs(utils.settings['Tabs']) do
        local tab = Tab(tabSettings)
        valid,_ = tab:validate() and valid
        utils.settings['Tabs'][idx] = tab
    end
    if not valid then
        utils.print_err('Exiting due to invalid configuration. Review the output above.')
        mq.exit()
    end
end

utils.LoadSettings = function(arg)
    local boxhud_dir = ('%s/boxhud'):format(mq.luaDir)
    settings_file = arg[1] or string.format('boxhud-settings-%s.lua', string.lower(mq.TLO.Me.Name()))
    local settings_path = string.format('%s/%s', boxhud_dir, settings_file)
    local old_settings_path = string.format('%s/%s', mq.luaDir, settings_file)
    local default_settings_path = string.format('%s/%s', boxhud_dir, 'boxhud-settings.lua')

    if FileExists(settings_path) then
        utils.print_msg('Loading settings from file: ' .. settings_file)
        utils.settings = require(string.format('boxhud.%s', settings_file:gsub('.lua', '')))
    elseif FileExists(old_settings_path) then
        -- copy old settings to new location in boxhud folder
        utils.print_msg(string.format('Moving lua/%s to lua/boxhud/%s', settings_file, settings_file))
        CopyFile(old_settings_path, settings_path)
        utils.print_msg('Loading settings from file: ' .. settings_file)
        utils.settings = require(string.format('boxhud.%s', settings_file:gsub('.lua', '')))
    else
        utils.print_msg('Loading default settings from file: boxhud-settings')
        -- Default settings
        utils.settings = require('boxhud.boxhud-settings')
        -- Copy defaults into toon specific settings
        CopyFile(default_settings_path, settings_path)
    end

    if not utils.settings['SchemaVersion'] or utils.settings['SchemaVersion'] < 2 then
        utils.settings = converter.ConvertSettings(utils.settings)
    end
    ValidateSettings()
end

function SaveSettings()
    local settings_path = ('%s/boxhud/%s'):format(mq.luaDir, settings_file)
    persistence.store(settings_path, utils.settings)
    return true
end

utils.Property = Property
utils.Column = Column
utils.Tab = Tab
utils.Window = Window

return utils