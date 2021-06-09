--[[
boxhud.lua 1.6.0 -- aquietone
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
1.6.0
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
local mq = require('mq')

local arg = {...}

-- Control variables
local VERSION = '1.6.0'
local openGUI = true
local shouldDrawGUI = true
local terminate = false
local settings = {}
-- Default DanNet peer group to use
local peerSource = 'dannet'
local peerGroup = 'all'
local peerTable = nil
local classVarName = 'Me.Class'
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
-- Set to 1 to use classname instead of player names
local anonymize = false
local adminMode = false
local adminPeerSelected = 0

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
            mq.cmd.plugin('mq2dannet noauto')
        end
        -- turn off fullname mode in DanNet
        if mq.TLO.DanNet.FullNames() == 1 then
            mq.cmd.dnet('fullnames off')
        end
    end
    if IsUsingNetBots() then
        if not mq.TLO.Plugin('mq2eqbc').IsLoaded() then
            print_msg("Plugin \ayMQ2EQBC\ax is required. Loading it now.")
            mq.cmd.plugin('mq2eqbc noauto')
        end
        if not mq.TLO.Plugin('mq2netbots').IsLoaded() then
            print_msg("Plugin \ayMQ2NetBots\ax is required. Loading it now.")
            mq.cmd.plugin('mq2netbots noauto')
        end
    end
end

-- Return list of DanNet peers from the configured peer group
-- peers list |peer1|peer2|peer3
local function Peers()
    if peerSource == 'dannet' then
        return Split(mq.TLO.DanNet.Peers(peerGroup)())
    else
        local t={}
        for i=1,mq.TLO.NetBots.Counts() do
            table.insert(t, mq.TLO.NetBots.Client.Arg(i)())
        end
        return t
    end
end

local function GetZonePeerGroup()
    local zoneName = mq.TLO.Zone.ShortName()
    if zoneName:find('_') then
        return 'zone_'..zoneName
    else
        return 'zone_'..mq.TLO.EverQuest.Server()..'_'..zoneName
    end
end

local function CheckRequiredSettings()
    if not settings['Columns'] then
        print_err('ERROR: Missing \'Columns\' from settings')
        mq.exit()
    elseif table.getn(settings['Columns']) == 0 then
        print_err('ERROR: \'Columns\' contains no entries')
        mq.exit()
    end
end

local function CheckOptionalSettings()
    if settings['PeerSource'] then
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
    if settings['RefreshInterval'] then
        refreshInterval = settings['RefreshInterval']
    end
    if settings['StaleDataTimeout'] then
        staleDataTimeout = settings['StaleDataTimeout']
    end
end

local function SetWindowWidth()
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

local function CopySettingsFile(default_settings, new_settings)
    local f = io.open(default_settings, 'r')
    local defaults = f:read('*a')
    io.close(f)
    f = io.open(new_settings, 'w')
    f:write(defaults)
    io.close(f)
end

local function LoadSettingsFile()
    local lua_dir = mq.TLO.MacroQuest.Path():gsub('\\', '/') .. '/lua/'
    local settings_file = arg[1] or 'boxhud-settings-'..string.lower(mq.TLO.Me.Name())..'.lua'
    local settings_path = lua_dir..settings_file
    local default_settings_path = lua_dir..'boxhud-settings.lua'

    if FileExists(settings_path) then
        print_msg('Loading settings from file: ' .. settings_file)
        settings = require(settings_file:gsub('.lua', ''))
        CheckRequiredSettings()
        CheckOptionalSettings()
    else
        print_msg('Loading default settings from file: boxhud-settings')
        -- Default settings
        settings = require('boxhud-settings')
        -- Copy defaults into toon specific settings
        CopySettingsFile(default_settings_path, settings_path)
    end
    SetWindowWidth()
end

-- Add or remove observers for the given toon
local function ManageObservers(botName, drop)
    local observeWaitMod = 1+table.getn(peerTable)/10
    if drop then
        for _, obsProp in pairs(settings['ObservedProperties']) do
            -- Drop the observation if it is set
            if mq.TLO.DanNet(botName).ObserveSet('"'..obsProp['Name']..'"')() == 1 then
                mq.cmd.dobserve(botName..' -q "'..obsProp['Name']..'" -drop')
                mq.delay(50*observeWaitMod)
            end
        end
        observedToons[botName] = nil
    else
        if not observedToons[botName] then
            for _, obsProp in pairs(settings['ObservedProperties']) do
                -- Add the observation if it is not set
                if mq.TLO.DanNet(botName).ObserveSet('"'..obsProp['Name']..'"')() == 0 then
                    mq.cmd.dobserve(botName..' -q "'..obsProp['Name']..'"')
                    mq.delay(50*observeWaitMod)
                end
            end
            observedToons[botName] = true
        end
    end
end

-- Verify all observed properties are set for the given toon
local function VerifyObservers(botName)
    for _, obsProp in pairs(settings['ObservedProperties']) do
        if mq.TLO.DanNet(botName).ObserveSet('"'..obsProp['Name']..'"')() == 0 then
            return false
        end
    end
    return true
end

local function AddAndVerifyObservers(botName)
    print_msg('Adding observed properties for: \ay'..botName)
    ManageObservers(botName, false)
    print_msg('Waiting for observed properties to be added for: \ay'..botName)
    local verifyStartTime = os.time(os.date("!*t"))
    while not VerifyObservers(botName) do
        mq.delay(100)
        if os.difftime(os.time(os.date("!*t")), verifyStartTime) > 20 then
            print_err('Timed out verifying observers for \ay'..botName)
            print_err('Exiting the script.')
            mq.exit()
        end
    end
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
    ImGui.Text(value)
    ImGui.PopStyleColor(1)
end

local function DrawContextMenu(name, botName)
    if ImGui.BeginPopupContextItem("popup##"..name) then
        if ImGui.SmallButton("Target##"..name) then
            mq.cmd.target(name)
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.SmallButton("Nav To##"..name) then
            mq.cmd.nav('spawn '..name)
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.SmallButton("Come To Me##"..name) then
            mq.cmd.dex(name..' /nav id ${Me.ID} log=critical')
            ImGui.CloseCurrentPopup()
        end
        if ImGui.SmallButton("G Inv##"..name) then
            mq.cmd.invite(name)
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.SmallButton("R Inv##"..name) then
            mq.cmd.raidinvite(name)
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.SmallButton("DZAdd##"..name) then
            mq.cmd.dzadd(name)
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.SmallButton("TAdd##"..name) then
            mq.cmd.taskadd(name)
            ImGui.CloseCurrentPopup()
        end
        if ImGui.SmallButton("Reset Obs##"..name) then
            print_msg('Resetting observed properties for: \ay'..name)
            ManageObservers(name, true)
            ImGui.CloseCurrentPopup()
        end
        ImGui.Text('Send Command to '..botName..': ')
        local textInput = ""
        textInput, selected = ImGui.InputText("##input"..name, textInput, 32)
        if selected then
            print_msg('Sending command: \ag/dex '..botName..' '..textInput)
            mq.cmd.dex(name..' '..textInput)
            ImGui.CloseCurrentPopup()
        end
        ImGui.EndPopup()
    end
end

local function DrawNameButton(name, botName, botInZone, botInvis)
    -- Treat Name column special
    -- Fill name column
    local buttonText = TitleCase(botName..'##'..name)
    if botInZone then
        if not botInvis then
            ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
            buttonText = TitleCase(botName)
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.26, 0.98, 0.98, 1)
            buttonText = '('..TitleCase(botName)..')'
        end
    else
        ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
    end
    if ImGui.SmallButton(buttonText..'##'..name) then
        -- bring left clicked toon to foreground
        mq.cmd.dex(name..' /foreground')
    end
    ImGui.PopStyleColor(1)
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
        elseif column['Properties']['all'] then
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
        local command = columnAction:gsub('#botName#', name)
        local noparseCmd = string.match(command, '/noparse (.*)')
        if noparseCmd then
            print_msg('Run command: \ag'..command)
            mq.cmd.noparse(noparseCmd)
        else
            print_msg('Run command: \ag'..command)
            mq.cmd.squelch(command)
        end
    end
end

local function DrawHUDColumns(columns)
    ImGui.Columns(table.getn(columns))
    for _, column in pairs(columns) do
        if column['Name'] == 'Name' then
            ImGui.CollapsingHeader(column['Name']..' ('..table.getn(peerTable)..')', 256)
        elseif column['Type'] ~= 'button' then
            ImGui.CollapsingHeader(column['Name'], 256)
        end
        ImGui.SetColumnWidth(-1, column['Width'])
        ImGui.NextColumn()
    end
    for _, name in pairs(peerTable) do
        local botName = name
        local botValues = dataTable[botName]
        if not botValues then
            goto continue
        end
        -- Always read these properties for the toon
        -- as they are not specific to a column
        local botInZone = botValues['BotInZone']
        local botInvis = botValues['Me.Invis']
        local botClass = botValues[classVarName]
        if botClass then
            botClass = botClass:lower()
        end

        if anonymize then
            botName = botClass
        end
        for _, column in pairs(columns) do
            if column['Name'] == 'Name' then
                DrawNameButton(name, botName, botInZone, botInvis)
                ImGui.NextColumn()
            else
                -- Default column type is property (observed or spawn properties)
                if not column['Type'] or column['Type'] == 'property' then
                    DrawColumnProperty(botValues, botClass, botInZone, column)
                elseif column['Type'] == 'button' then
                    DrawColumnButton(name, column['Name'], column['Action'])
                end
                ImGui.NextColumn()
            end
        end
        ::continue::
    end
end

local function DrawHUDTabs()
    if ImGui.BeginTabBar('BOXHUDTABS') then
        for _, tab in pairs(settings['Tabs']) do
            if ImGui.BeginTabItem(tab['Name']) then
                if tab['Columns'] and table.getn(tab['Columns']) > 0 then
                    DrawHUDColumns(TableConcat(settings['Columns'], tab['Columns']))
                    ImGui.EndTabItem()
                    ImGui.Columns(1)
                else
                    ImGui.Text('No columns defined for tab')
                    ImGui.EndTabItem()
                end
            end
        end
        --[[
        if ImGui.BeginTabItem('XP Tracker') then
            ImGui.Text('Kills/hour: '..tostring(mq.TLO.XPTracker.KillsPerHour()))
            ImGui.Text('%%XP/hour: '..tostring(mq.TLO.XPTracker.PctExpPerHour()))
            ImGui.EndTabItem()
        end
        --]]
        -- Admin tab only allows resetting observers, so only show if dannet is being used
        if IsUsingDanNet() then
            if ImGui.BeginTabItem('Admin') then
                ImGui.Text('Reset Observers for:')
                adminPeerSelected, clicked = ImGui.Combo("##combo", adminPeerSelected, peerTable, table.getn(peerTable), 5)
                ImGui.SameLine()
                if ImGui.Button('Reset') then
                    print_msg('Resetting observed properties for: \ay'..peerTable[adminPeerSelected+1])
                    ManageObservers(peerTable[adminPeerSelected+1], true)
                end
            end
        end
        ImGui.EndTabBar()
    end
end

-- ImGui main function for rendering the UI window
local HUDGUI = function()
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
        mq.imgui.destroy('HUDGUI')
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
            botValues[obsProp['Name']] = mq.TLO.DanNet(botName).Observe('"'..obsProp['Name']..'"')()
        end
    end
    if IsUsingNetBots() then
        for _, netbotsProp in pairs(settings['NetBotsProperties']) do
            -- tostring instead of ending with () because class returned a number instead of class string
            botValues[netbotsProp['Name']] = tostring(mq.TLO.NetBots(TitleCase(botName))[netbotsProp['Name']])
        end
    end
    if settings['SpawnProperties'] then
        for _, spawnProp in pairs(settings['SpawnProperties']) do
            if spawnProp['FromIDProperty'] then
                botValues[spawnProp['Name']] = mq.TLO.Spawn('id '..botValues[spawnProp['FromIDProperty']])[spawnProp['Name']]()
            else
                botValues[spawnProp['Name']] = botSpawnData[spawnProp['Name']]()
                if type(botValues[spawnProp['Name']]) == 'number' then
                    botValues[spawnProp['Name']] = math.floor(botValues[spawnProp['Name']])
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
            --ManageObservers(botName, true)
        end
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
                if not VerifyObservers(botName) or not observedToons[botName] then
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
