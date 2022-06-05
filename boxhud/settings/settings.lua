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

local function ValidateOptionalSettings()
    if not state.Settings['Windows'] then
        print_msg('No windows defined, adding default')
        state.Settings['Windows'] = {
            ['default'] = Window({Name='default',Tabs={},Transparency=false,TitleBar=false})
        }
        for _,tab in ipairs(state.Settings['Tabs']) do
            table.insert(state.Settings['Windows']['default']['Tabs'], tab['Name'])
        end
        if state.Settings['PeerSource'] and state.Settings['PeerSource'] == 'dannet' then
            print_msg('Setting default window peer group to '..state.Settings['DanNetPeerGroup'])
            state.Settings['Windows']['default']['PeerGroup'] = state.Settings['DanNetPeerGroup']
        end
    else
        for name,window in pairs(state.Settings['Windows']) do
            state.Settings['Windows'][name] = Window(window)
        end
    end

    if state.Settings['PeerSource'] then
        if state.Settings['PeerSource'] ~= 'dannet' and  state.Settings['PeerSource'] ~= 'netbots' then
            print_err('PeerSource must be either \'dannet\' or \'netbots\'')
            return false
        end
        utils.PeerSource = state.Settings['PeerSource']
    end
    if utils.PeerSource == 'dannet' then
        utils.IsUsingDanNet = true
        local classPropertyFound = false
        for propName, propSettings in pairs(state.Settings['Properties']) do
            if (propName == 'Me.Class' or propName == 'Me.Class.ShortName') and propSettings['Type'] == 'Observed' then
                classPropertyFound = true
                utils.ClassVar = propName
            end
        end
        if not classPropertyFound then
            utils.ClassVar = 'Me.Class.ShortName'
            state.Settings['Properties'][utils.ClassVar] = { Type='Observed' }
        end
    elseif utils.PeerSource == 'netbots' then
        utils.IsUsingNetBots = true
        if table.getn(state.Settings['Windows']) > 1 then
            print_err('NetBots only supports 1 window')
            return false
        end
        local classPropertyFound = false
        for propName, propSettings in pairs(state.Settings['Properties']) do
            if propName == 'Class' and propSettings['Type'] == 'NetBots' then
                classPropertyFound = true
                utils.ClassVar = propName
            end
        end
        if not classPropertyFound then
            utils.ClassVar = 'Class'
            state.Settings['Properties'][utils.ClassVar] = { Type='NetBots' }
        end
    end
    if state.Settings['RefreshInterval'] and type(state.Settings['RefreshInterval']) == 'number' then
        utils.RefreshInterval = state.Settings['RefreshInterval']
    end
    if state.Settings['StaleDataTimeout'] and type(state.Settings['StaleDataTimeout']) == 'number' then
        utils.StaleDataTimeout = state.Settings['StaleDataTimeout']
    end
    if not state.Settings['Colors'] then
        state.Settings['Colors'] = {}
    end
    state.Settings['Colors']['Default'] = state.Settings['Colors']['Default'] or {1,1,1}
    state.Settings['Colors']['Low'] = state.Settings['Colors']['Low'] or {1,0,0}
    state.Settings['Colors']['Medium'] = state.Settings['Colors']['Medium'] or {1,1,0}
    state.Settings['Colors']['High'] = state.Settings['Colors']['High'] or  {0,1,0}
    state.Settings['Colors']['True'] = state.Settings['Colors']['True'] or {0,1,0}
    state.Settings['Colors']['False'] = state.Settings['Colors']['False'] or {1,0,0}
    state.Settings['Colors']['InZone'] = state.Settings['Colors']['InZone'] or {0,1,0}
    state.Settings['Colors']['Invis'] = state.Settings['Colors']['Invis'] or {0.26, 0.98, 0.98}
    state.Settings['Colors']['IVU'] = state.Settings['Colors']['IVU'] or {0.95, 0.98, 0.26}
    state.Settings['Colors']['DoubleInvis'] = state.Settings['Colors']['DoubleInvis'] or {0.68, 0.98, 0.98}
    state.Settings['Colors']['NotInZone'] = state.Settings['Colors']['NotInZone'] or {1,0,0}
    state.Settings['Transparency'] = state.Settings['Transparency'] or false
    state.Settings['TitleBar'] = state.Settings['TitleBar'] or false
    return true
end

local function ValidateSettings()
    local valid = true
    valid = valid and ValidateOptionalSettings()
    if not state.Settings['Properties'] then
        state.Settings['Properties'] = {}
    end
    for propName,propSettings in pairs(state.Settings['Properties']) do
        local property = Property(propSettings)
        property['Name'] = propName
        valid,_ = property:validate() and valid
        state.Settings['Properties'][propName] = property
    end
    if not state.Settings['Columns'] then
        state.Settings['Columns'] = {}
    end
    for columnName,columnSettings in pairs(state.Settings['Columns']) do
        local column = Column(columnSettings)
        column['Name'] = columnName
        valid,_ = column:validate() and valid
        state.Settings['Columns'][columnName] = column
    end
    if not state.Settings['Columns']['Name'] then
        state.Settings['Columns']['Name'] = {
            ["Name"] = "Name",
            ["Type"] = "property",
			["InZone"] = false,
			["Percentage"] = false
        }
    end
    if not state.Settings['Tabs'] then
        state.Settings['Tabs'] = {}
    end
    for idx,tabSettings in pairs(state.Settings['Tabs']) do
        local tab = Tab(tabSettings)
        valid,_ = tab:validate() and valid
        state.Settings['Tabs'][idx] = tab
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
    local old_settings_path = string.format('%s/%s', boxhud_dir, settings_file)
    local default_settings_path = string.format('%s/settings/%s', boxhud_dir, 'boxhud-settings.lua')

    if utils.FileExists(settings_path) then
        print_msg('Loading settings from file: ' .. settings_file)
        state.Settings = require(string.format('boxhud.settings.%s', settings_file:gsub('.lua', '')))
    elseif utils.FileExists(old_settings_path) then
        -- copy old settings to new location in boxhud folder
        print_msg(string.format('Moving lua/boxhud/%s to lua/boxhud/settings/%s', settings_file, settings_file))
        utils.CopyFile(old_settings_path, settings_path)
        print_msg('Loading settings from file: ' .. settings_file)
        state.Settings = require(string.format('boxhud.%s', settings_file:gsub('.lua', '')))
    else
        print_msg('Loading default settings from file: boxhud-settings')
        -- Default settings
        state.Settings = require('boxhud.settings.boxhud-settings')
        -- Copy defaults into toon specific settings
        utils.CopyFile(default_settings_path, settings_path)
    end

    ValidateSettings()
end

s.SaveSettings = function()
    local settings_path = ('%s/boxhud/settings/%s'):format(mq.luaDir, settings_file)
    persistence.store(settings_path, state.Settings)
    return true
end

return s