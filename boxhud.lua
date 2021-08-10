--[[
boxhud.lua 2.0.5 -- aquietone
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
--]]
--- @type mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'
require('boxhud.utils')
require('boxhud.configpanel')

local arg = {...}

-- Control variables
local openGUI = true
local shouldDrawGUI = true
local terminate = false

local peerTable = nil
local peersDirty = false
-- Stores all live observed toon information that will be displayed
local characters = {}
-- Set to 1 to use classname instead of player names
local anonymize = false
local adminMode = false
local adminPeerSelected = 0
local initialRun = true
math.randomseed(os.time())
local tableRandom = math.random(1,100)

local resetObserversName = nil
local storedCommand = nil

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

Character = class(function(b, name, className)
    b.name = name
    b.className = className
    b.properties = nil
end)

function Character:shouldObserveProperty(propSettings)
    if not propSettings['DependsOnName'] then
        -- Does not depend on another property being observed
        return true
    elseif not propSettings['DependsOnValue'] or propSettings['DependsOnValue'] == '' then
        -- Does not care what the value is of the property, just that it is observed
        return true
    elseif propSettings['DependsOnValue'] then
        local dependentValue = mq.TLO.DanNet(self.name).Observe(string.format('"%s"', propSettings['DependsOnName']))()
        if dependentValue and string.lower(propSettings['DependsOnValue']):find(string.lower(dependentValue)) ~= nil then
            -- The value of the dependent property matches
            return true
        end
    end
    -- Do not observe the property
    return false
end

-- Return whether or not a property is observed for a toon
function Character:isObserverSet(propName, propSettings)
    if not mq.TLO.DanNet(self.name)() or mq.TLO.DanNet(self.name).ObserveSet('"'..propName..'"')() then
        return true
    end
    return false
end

-- Return whether or not all expected observers are set for a toon 
function Character:verifyObservers()
    for propName, propSettings in pairs(SETTINGS['Properties']) do
        if propSettings['Type'] == 'Observed' and self:shouldObserveProperty(propSettings) then
            if not self:isObserverSet(propName, propSettings) then
                return false
            end
        end
    end
    return true
end

function Character:addObserver(propName, propSettings)
    if propSettings['DependsOnName'] then
        for depPropName,depPropSettings in pairs(SETTINGS['Properties']) do
            if depPropName == propSettings['DependsOnName'] then
                self:addObserver(depPropName, depPropSettings)
            end
        end
    end
    if self:shouldObserveProperty(propSettings) then
        -- Add the observation if it is not set
        if not mq.TLO.DanNet(self.name).ObserveSet(string.format('"%s"', propName))() then
            mq.cmdf('/dobserve %s -q "%s"', self.name, propName)
        end
        local verifyStartTime = os.time(os.date("!*t"))
        while not self:isObserverSet(propName, propSettings) do
            mq.delay(25)
            if os.difftime(os.time(os.date("!*t")), verifyStartTime) > 20 then
                print_err('Timed out waiting for observer to be added for \ay'..self.name)
                print_err('Exiting the script.')
                mq.exit()
            end
        end
    end
end

function Character:removeObserver(propName, propSettings)
    -- Drop the observation if it is set
    if mq.TLO.DanNet(self.name).ObserveSet(string.format('"%s"', propName))() then
        mq.cmdf('/dobserve %s -q "%s" -drop', self.name, propName)
    end
    local verifyStartTime = os.time(os.date("!*t"))
    while self:isObserverSet(propName, propSettings) do
        mq.delay(25)
        if os.difftime(os.time(os.date("!*t")), verifyStartTime) > 20 then
            print_err('Timed out waiting for observer to be removed for \ay'..self.name)
            print_err('Exiting the script.')
            mq.exit()
        end
    end
end

-- Add or remove observers for the given toon
function Character:manageObservers(drop)
    if drop then
        for propName, propSettings in pairs(SETTINGS['Properties']) do
            if propSettings['Type'] == 'Observed' then
                self:removeObserver(propName, propSettings)
            end
        end
        print_msg('Removed observed properties for: \ay'..self.name)
    else
        for propName, propSettings in pairs(SETTINGS['Properties']) do
            if propSettings['Type'] == 'Observed' then
                self:addObserver(propName, propSettings)
            end
        end
        print_msg('Added observed properties for: \ay'..self.name)
    end
end

local function SetText(value, thresholds, ascending, percentage)
    local col = SETTINGS['Colors']['Default']
    if thresholds ~= nil then
        local valueNum = tonumber(value)
        if valueNum == nil then
            return
        end
        if #thresholds == 1 then
            if valueNum >= thresholds[1] then
                if ascending then
                    col = SETTINGS['Colors']['High']
                else -- red if above
                    col = SETTINGS['Colors']['Low']
                end
            else
                if ascending then
                    col = SETTINGS['Colors']['Low']
                else -- green if below
                    col = SETTINGS['Colors']['High']
                end
            end
        elseif #thresholds == 2 then
            if valueNum >= thresholds[2] then
                if ascending then
                    col = SETTINGS['Colors']['High']
                else
                    col = SETTINGS['Colors']['Low']
                end
            elseif valueNum >= thresholds[1] and valueNum < thresholds[2] then
                col = SETTINGS['Colors']['Medium']
            else
                if ascending then
                    col = SETTINGS['Colors']['Low']
                else
                    col = SETTINGS['Colors']['High']
                end
            end
        end
    end
    ImGui.PushStyleColor(ImGuiCol.Text, col[1], col[2], col[3], 1)
    if tonumber(value) then
        -- right align number values
        if percentage then value = value..'%' end
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ImGui.GetColumnWidth() - ImGui.CalcTextSize(tostring(value)) 
            - ImGui.GetScrollX())
        -- CalcTextSize doesn't consider that `%%` is used to escape the % sign, so add the second % after.
        if percentage then value = value..'%' end
    end
    ImGui.Text(value)
    ImGui.PopStyleColor(1)
end

function Character:drawCmdButton(label, action)
    if ImGui.SmallButton(label) then
        ImGui.CloseCurrentPopup()
        mq.cmdf(action, self.name)
    end
end

function Character:getDisplayName()
    if anonymize then return string.upper(self.className) else return TitleCase(self.name) end
end

function Character:drawContextMenu()
    if ImGui.BeginPopupContextItem("##popup"..self.name) then
        self:drawCmdButton('Target##'..self.name, '/target %s')
        ImGui.SameLine()
        self:drawCmdButton('Nav To##'..self.name, '/nav spawn %s')
        ImGui.SameLine()
        self:drawCmdButton('Come To Me##'..self.name, '/dex %s /nav id ${Me.ID}')
        
        self:drawCmdButton('G Inv##'..self.name, '/invite %s')
        ImGui.SameLine()
        self:drawCmdButton('R Inv##'..self.name, '/raidinvite %s')
        ImGui.SameLine()
        self:drawCmdButton('DZAdd##'..self.name, '/dzadd %s')
        ImGui.SameLine()
        self:drawCmdButton('TAdd##'..self.name, '/taskadd %s')
        
        if ImGui.SmallButton("Reset Obs##"..self.name) then
            print_msg('Resetting observed properties for: \ay'..self.name)
            ImGui.CloseCurrentPopup()
            resetObserversName = self.name
        end
        ImGui.Text('Send Command to '..self:getDisplayName()..': ')
        local textInput = ""
        textInput, selected = ImGui.InputText("##input"..self.name, textInput, 32)
        if selected then
            print_msg('Sending command: \ag/dex '..self:getDisplayName()..' '..textInput)
            ImGui.CloseCurrentPopup()
            mq.cmdf('/dex %s %s', self.name, textInput)
        end
        ImGui.EndPopup()
    end
end

function Character:drawNameButton()
    local buttonText = self:getDisplayName()
    local col = nil
    if self.properties['BotInZone'] then
        if not self.properties['Me.Invis'] then
            col = SETTINGS['Colors']['InZone'] or {0,1,0}
        else
            col = SETTINGS['Colors']['Invis'] or {0.26, 0.98, 0.98}
            buttonText = '('..self:getDisplayName()..')'
        end
    else
        col = SETTINGS['Colors']['NotInZone'] or {1,0,0}
    end
    ImGui.PushStyleColor(ImGuiCol.Text, col[1], col[2], col[3], 1)

    if ImGui.SmallButton(buttonText..'##'..self.name) then
        storedCommand = string.format('/squelch /dex %s /foreground', self.name)
    end
    ImGui.PopStyleColor(1)
    self:drawContextMenu()
end

function Character:drawColumnProperty(column)
    if not column['InZone'] or (column['InZone'] and self.properties['BotInZone']) then
        local value = 'NULL'
        if column['Properties'][self.className] then
            value = self.properties[column['Properties'][self.className]]
        elseif column['Properties']['ranged'] and ranged[self.className] then
            value = self.properties[column['Properties']['ranged']]
        elseif column['Properties']['hybrids'] and hybrids[self.className] then
            value = self.properties[column['Properties']['hybrids']]
        elseif column['Properties']['caster'] and casters[self.className] then
            value = self.properties[column['Properties']['caster']]
        elseif column['Properties']['melee'] and melee[self.className] then
            value = self.properties[column['Properties']['melee']]
        end
        if (value == 'NULL' or value == '') and column['Properties']['all'] then
            value = self.properties[column['Properties']['all']]
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

function Character:drawColumnButton(columnName, columnAction)
    if ImGui.SmallButton(columnName..'##'..self.name) then
        storedCommand = columnAction:gsub('#botName#', self.name)
        print_msg('Run command: \ag'..storedCommand)
    end
end

function Character:updateCharacterProperties(currTime)
    local properties = {}
    local charSpawnData = mq.TLO.Spawn('='..self.name)
    properties['Me.ID'] = charSpawnData.ID()
    properties['Me.Invis'] = charSpawnData.Invis()

    -- Fill in data from this toons observed properties
    for propName, propSettings in pairs(SETTINGS['Properties']) do
        if propSettings['Type'] == 'Observed' then
            if self:shouldObserveProperty(propSettings) then
                properties[propName] = mq.TLO.DanNet(self.name).Observe('"'..propName..'"')()
            else
                properties[propName] = ''
            end
        elseif propSettings['Type'] == 'NetBots' then
            -- tostring instead of ending with () because class returned a number instead of class string
            if propName:find('Class') then
                properties[propName] = tostring(mq.TLO.NetBots(TitleCase(self.name))[propName])
            else
                properties[propName] = mq.TLO.NetBots(TitleCase(self.name))[propName]()
            end
        elseif propSettings['Type'] == 'Spawn' then
            if propSettings['FromIDProperty'] then
                properties[propName] = mq.TLO.Spawn('id '..properties[propSettings['FromIDProperty']])[propName]()
            else
                properties[propName] = charSpawnData[propName]()
                if type(properties[propName]) == 'number' then
                    properties[propName] = string.format("%.2f", properties[propName])
                end
            end
        end
    end

    if SETTINGS['DanNetPeerGroup'] ~= 'zone' then
        properties['BotInZone'] = properties['Me.ID'] ~= 0
    else
        properties['BotInZone'] = true
    end
    properties['lastUpdated'] = currTime
    self.className = properties[CLASS_VAR]:lower()
    self.properties = properties
end

local current_sort_specs = nil
local current_columns = nil
local function CompareWithSortSpecs(a, b)
    for n = 1, current_sort_specs.SpecsCount, 1 do
        -- Here we identify columns using the ColumnUserID value that we ourselves passed to TableSetupColumn()
        -- We could also choose to identify columns based on their index (sort_spec.ColumnIndex), which is simpler!
        local sort_spec = current_sort_specs:Specs(n)
        local delta = 0

        local columnName = current_columns[sort_spec.ColumnUserID]
        local column = SETTINGS['Columns'][columnName]
        if not column then
            return a < b
        end
        local aVal = nil
        local bVal = nil
        if column['Name'] == 'Name' or not column['Properties'] or not column['Properties']['all'] then
            aVal = a
            bVal = b
        elseif characters[a].properties and characters[b].properties then
            aVal = characters[a].properties[column['Properties']['all']] or -1
            bVal = characters[b].properties[column['Properties']['all']] or -1
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

local function DrawTableTab(columns, tabName)
    local flags = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.MultiSortable,
            ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.ScrollY, ImGuiTableFlags.NoSavedSettings)
    if ImGui.BeginTable('##bhtable'..tabName..tostring(tableRandom), #columns, flags, 0, 0, 0.0) then
        for i, columnName in ipairs(columns) do
            local column = SETTINGS['Columns'][columnName]
            if columnName == 'Name' then
                ImGui.TableSetupColumn('Name',     bit32.bor(ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.WidthFixed),   -1.0, i)
            elseif column['Type'] ~= 'button' then
                ImGui.TableSetupColumn(columnName, ImGuiTableColumnFlags.WidthFixed,                                                 -1.0, i)
            else
                ImGui.TableSetupColumn(columnName, bit32.bor(ImGuiTableColumnFlags.NoSort, ImGuiTableColumnFlags.WidthFixed),        -1.0, i)
            end
        end
        ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible
        local sort_specs = ImGui.TableGetSortSpecs()
        if sort_specs then
            if sort_specs.SpecsDirty or peersDirty then
                if #peerTable > 0 then
                    current_sort_specs = sort_specs
                    current_columns = columns
                    sortedPeers = TableClone(peerTable)
                    table.sort(sortedPeers, CompareWithSortSpecs)
                    current_sort_specs = nil
                    current_columns = nil
                end
                sort_specs.SpecsDirty = false
                peersDirty = false
            end
        end

        -- Display data
        ImGui.TableHeadersRow()
        local clipper = ImGuiListClipper.new()
        if sortedPeers == nil then
            sortedPeers = TableClone(peerTable)
        end
        clipper:Begin(#sortedPeers)
        while clipper:Step() do
            for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
                local clipName = sortedPeers[row_n+1]
                local char = characters[clipName]
                if char and char.properties then
                    ImGui.PushID(clipName)
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    for i,columnName in ipairs(columns) do
                        local column = SETTINGS['Columns'][columnName]
                        if columnName == 'Name' then
                            char:drawNameButton()
                        else
                            -- Default column type is property (observed or spawn properties)
                            if not column['Type'] or column['Type'] == 'property' then
                                char:drawColumnProperty(column)
                            elseif column['Type'] == 'button' then
                                char:drawColumnButton(columnName, column['Action'])
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
        for _, tab in ipairs(SETTINGS['Tabs']) do
            ImGui.PushID(tab['Name'])
            if ImGui.BeginTabItem(tab['Name']) then
                if tab['Columns'] and #tab['Columns'] > 0 then
                    DrawTableTab(tab['Columns'], tab['Name'])
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
                ImGui.Text('DanNet Peer Group: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, PEER_GROUP)
                ImGui.Text('Reset Observers for:')
                adminPeerSelected, clicked = ImGui.Combo("##combo", adminPeerSelected, peerTable, #peerTable, 5)
                ImGui.SameLine()
                if ImGui.Button('Reset') then
                    print_msg('Resetting observed properties for: \ay'..peerTable[adminPeerSelected+1])
                    resetObserversName = peerTable[adminPeerSelected+1]
                end
                ImGui.EndTabItem()
            end
        end

        if ImGui.BeginTabItem('Configuration') then
            ConfigurationTab()
            ImGui.EndTabItem()
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

        DrawHUDTabs()
    end
    ImGui.End()
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
            for _,char in pairs(characters) do
                char:manageObservers(true)
                char:manageObservers(false)
            end
        else
            print_msg('Resetting observed properties for: \ay'..name)
            characters[name]:manageObservers(true)
            characters[name]:manageObservers(false)
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

local function CleanupStaleData(currTime)
    for name, char in pairs(characters) do
        if os.difftime(currTime, char.properties['lastUpdated']) > STALE_DATA_TIMEOUT then
            print_msg('Removing stale toon data: \ay'..name)
            characters[name] = nil
        end
    end
end

local function SendCommand()
    mq.cmd(storedCommand)
    storedCommand = nil
end

local function RefreshPeers()
    local t = {}
    if PEER_SOURCE == 'dannet' then
        t = Split(mq.TLO.DanNet.Peers(PEER_GROUP)())
    else
        t={}
        for i=1,mq.TLO.NetBots.Counts() do
            table.insert(t, mq.TLO.NetBots.Client.Arg(i)())
        end
    end
    if not peerTable or not DoTablesMatch(peerTable, t) then
        peersDirty = true
        peerTable = t
    end
    for i,peerName in ipairs(peerTable) do
        if not characters[peerName] then
            characters[peerName] = Character(peerName,nil)
        end
    end
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
    LoadSettings(arg)
    PluginCheck()
    SetupBindings()

    -- Initialize peer list before the UI, since UI iterates over peer list
    RefreshPeers()

    mq.imgui.init('BOXHUDUI', HUDGUI)

    -- Initial setup of observers
    if IsUsingDanNet() then
        for _, char in pairs(characters) do
            char:manageObservers(false)
        end
    end

    -- Main run loop to populate observed property data of toons
    while not terminate do
        CheckGameState()
        if storedCommand then
            SendCommand()
        end
        -- Update PEER_GROUP if we've zoned and using the zone peer group
        ZoneCheck()
        local currTime = os.time(os.date("!*t"))
        RefreshPeers()
        for _, charName in pairs(peerTable) do
            local char = characters[charName]
            -- Ensure observers are set for the toon
            if IsUsingDanNet() then
                if resetObserversName == char.name then
                    resetObserversName = nil
                    char:manageObservers(true)
                    char:manageObservers(false)
                elseif not char:verifyObservers() then
                    char:manageObservers(false)
                end
            end
            char:updateCharacterProperties(currTime)
        end
        CleanupStaleData(currTime)
        mq.delay(REFRESH_INTERVAL)
    end
end

main()
