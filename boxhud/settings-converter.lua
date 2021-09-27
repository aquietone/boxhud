-- boxhud/settings-converter.lua 2.1.2 -- aquietone
local converter = {}

function deepcopy(orig)
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

function ConvertSettings(settings)
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
            PropertyType = 'NetBots'
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

return converter
