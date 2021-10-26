local Property = require 'boxhud.classes.config.property'
local Column = require 'boxhud.classes.config.column'
local Tab = require 'boxhud.classes.config.tab'
local Window = require 'boxhud.classes.config.window'
local utils = require 'boxhud.utils.utils'
local state = require 'boxhud.state'
--- @type mq
local mq = require 'mq'
dofile('boxhud/utils/persistence.lua')

local s = {}

local settings_file = nil

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function ConvertSettings(settings)
    local targetSettings = {
        SchemaVersion = 2,
        Columns = {},
        Properties = {},
        Tabs = {},
        PeerSource = settings['PeerSource'] or 'dannet',
        DanNetPeerGroup = settings['DanNetPeerGroup'] or settings['PeerGroup'] or 'zone',
        RefreshInterval = settings['RefreshInterval'] or 250,
        StaleDataTimeout = settings['StaleDataTimeout'] or 30,
    }

    for _, property in pairs(settings['ObservedProperties']) do
        targetSettings['Properties'][property['Name']] = {
            Type = 'Observed',
            DependsOnName = property['DependsOnName'] or nil,
            DependsOnValue = property['DependsOnValue'] or nil
        }
    end
    for _, property in pairs(settings['NetBotsProperties']) do
        targetSettings['Properties'][property['Name']] = {
            Type = 'NetBots'
        }
    end
    for _, property in pairs(settings['SpawnProperties']) do
        targetSettings['Properties'][property['Name']] = {
            Type = 'Spawn',
            FromIDProperty = property['FromIDProperty'] or nil
        }
    end

    for _, column in pairs(settings['Columns']) do
        local c = deepcopy(column)
        targetSettings['Columns'][column['Name']] = deepcopy(column)
        targetSettings['Columns'][column['Name']]['Name'] = nil
    end
    for _, tab in pairs(settings['Tabs']) do
        for _, column in pairs(tab['Columns']) do
            targetSettings['Columns'][column['Name']] = deepcopy(column)
            targetSettings['Columns'][column['Name']]['Name'] = nil
        end
    end

    for _, tab in pairs(settings['Tabs']) do
        local newTab = {
            Name = tab['Name'],
            Columns = {}
        }
        for _, column in pairs(settings['Columns']) do
            table.insert(newTab['Columns'], column['Name'])
        end
        for _, column in pairs(tab['Columns']) do
            table.insert(newTab['Columns'], column['Name'])
        end

        table.insert(targetSettings['Tabs'], newTab)
    end

    return targetSettings
end

local function ValidateOptionalSettings()
    if not state.settings['Windows'] then
        print_msg('No windows defined, adding default')
        state.settings['Windows'] = {
            ['default'] = Window({Name='default',Tabs={},Transparency=false})
        }
        for _,tab in ipairs(state.settings['Tabs']) do
            table.insert(state.settings['Windows']['default']['Tabs'], tab['Name'])
        end
        if state.settings['PeerSource'] and state.settings['PeerSource'] == 'dannet' then
            print_msg('Setting default window peer group to '..state.settings['DanNetPeerGroup'])
            state.settings['Windows']['default']['PeerGroup'] = state.settings['DanNetPeerGroup']
        end
    else
        for name,window in pairs(state.settings['Windows']) do
            state.settings['Windows'][name] = Window(window)
        end
    end

    if state.settings['PeerSource'] then
        if state.settings['PeerSource'] ~= 'dannet' and  state.settings['PeerSource'] ~= 'netbots' then
            print_err('PeerSource must be either \'dannet\' or \'netbots\'')
            return false
        end
        utils.peer_source = state.settings['PeerSource']
    end
    if utils.peer_source == 'dannet' then
        utils.isUsingDanNet = true
        local classPropertyFound = false
        for propName, propSettings in pairs(state.settings['Properties']) do
            if (propName == 'Me.Class' or propName == 'Me.Class.ShortName') and propSettings['Type'] == 'Observed' then
                classPropertyFound = true
                utils.class_var = propName
            end
        end
        if not classPropertyFound then
            utils.class_var = 'Me.Class.ShortName'
            state.settings['Properties'][utils.class_var] = { Type='Observed' }
        end
    elseif utils.peer_source == 'netbots' then
        utils.isUsingNetBots = true
        if table.getn(state.settings['Windows']) > 1 then
            print_err('NetBots only supports 1 window')
            return false
        end
        local classPropertyFound = false
        for propName, propSettings in pairs(state.settings['Properties']) do
            if propName == 'Class' and propSettings['Type'] == 'NetBots' then
                classPropertyFound = true
                utils.class_var = propName
            end
        end
        if not classPropertyFound then
            utils.class_var = 'Class'
            state.settings['Properties'][utils.class_var] = { Type='NetBots' }
        end
    end
    if state.settings['RefreshInterval'] and type(state.settings['RefreshInterval']) == 'number' then
        utils.refresh_interval = state.settings['RefreshInterval']
    end
    if state.settings['StaleDataTimeout'] and type(state.settings['StaleDataTimeout']) == 'number' then
        utils.stale_data_timeout = state.settings['StaleDataTimeout']
    end
    if not state.settings['Colors'] then
        state.settings['Colors'] = {}
    end
    state.settings['Colors']['Default'] = state.settings['Colors']['Default'] or {1,1,1}
    state.settings['Colors']['Low'] = state.settings['Colors']['Low'] or {1,0,0}
    state.settings['Colors']['Medium'] = state.settings['Colors']['Medium'] or {1,1,0}
    state.settings['Colors']['High'] = state.settings['Colors']['High'] or  {0,1,0}
    state.settings['Colors']['True'] = state.settings['Colors']['True'] or {0,1,0}
    state.settings['Colors']['False'] = state.settings['Colors']['False'] or {1,0,0}
    state.settings['Colors']['InZone'] = state.settings['Colors']['InZone'] or {0,1,0}
    state.settings['Colors']['Invis'] = state.settings['Colors']['Invis'] or {0.26, 0.98, 0.98}
    state.settings['Colors']['IVU'] = state.settings['Colors']['IVU'] or {0.95, 0.98, 0.26}
    state.settings['Colors']['DoubleInvis'] = state.settings['Colors']['DoubleInvis'] or {0.68, 0.98, 0.98}
    state.settings['Colors']['NotInZone'] = state.settings['Colors']['NotInZone'] or {1,0,0}
    state.settings['Transparency'] = state.settings['Transparency'] or false
    state.settings['TitleBar'] = state.settings['TitleBar'] or false
    return true
end

local function ValidateSettings()
    local valid = true
    valid = valid and ValidateOptionalSettings()
    if not state.settings['Properties'] then
        state.settings['Properties'] = {}
    end
    for propName,propSettings in pairs(state.settings['Properties']) do
        local property = Property(propSettings)
        property['Name'] = propName
        valid,_ = property:validate() and valid
        state.settings['Properties'][propName] = property
    end
    if not state.settings['Columns'] then
        state.settings['Columns'] = {}
    end
    for columnName,columnSettings in pairs(state.settings['Columns']) do
        local column = Column(columnSettings)
        column['Name'] = columnName
        valid,_ = column:validate() and valid
        state.settings['Columns'][columnName] = column
    end
    if not state.settings['Columns']['Name'] then
        state.settings['Columns']['Name'] = {
            ["Name"] = "Name",
            ["Type"] = "property",
			["InZone"] = false,
			["Percentage"] = false
        }
    end
    if not state.settings['Tabs'] then
        state.settings['Tabs'] = {}
    end
    for idx,tabSettings in pairs(state.settings['Tabs']) do
        local tab = Tab(tabSettings)
        valid,_ = tab:validate() and valid
        state.settings['Tabs'][idx] = tab
    end
    if not valid then
        print_err('Exiting due to invalid configuration. Review the output above.')
        mq.exit()
    end
end

s.LoadSettings = function(arg)
    local boxhud_dir = ('%s/boxhud'):format(mq.luaDir)
    settings_file = arg[1] or string.format('boxhud-settings-%s.lua', string.lower(mq.TLO.Me.Name()))
    local settings_path = string.format('%s/settings/%s', boxhud_dir, settings_file)
    local old_settings_path = string.format('%s/%s', mq.luaDir, settings_file)
    local default_settings_path = string.format('%s/settings/%s', boxhud_dir, 'boxhud-settings.lua')

    if utils.FileExists(settings_path) then
        print_msg('Loading settings from file: ' .. settings_file)
        state.settings = require(string.format('boxhud.settings.%s', settings_file:gsub('.lua', '')))
    elseif utils.FileExists(old_settings_path) then
        -- copy old settings to new location in boxhud folder
        print_msg(string.format('Moving lua/%s to lua/boxhud/settings/%s', settings_file, settings_file))
        utils.CopyFile(old_settings_path, settings_path)
        print_msg('Loading settings from file: ' .. settings_file)
        state.settings = require(string.format('boxhud.%s', settings_file:gsub('.lua', '')))
    else
        print_msg('Loading default settings from file: boxhud-settings')
        -- Default settings
        state.settings = require('boxhud.settings.boxhud-settings')
        -- Copy defaults into toon specific settings
        utils.CopyFile(default_settings_path, settings_path)
    end

    if not state.settings['SchemaVersion'] or state.settings['SchemaVersion'] < 2 then
        state.settings = ConvertSettings(state.settings)
    end
    ValidateSettings()
end

s.SaveSettings = function()
    local settings_path = ('%s/boxhud/settings/%s'):format(mq.luaDir, settings_file)
    persistence.store(settings_path, state.settings)
    return true
end

return s