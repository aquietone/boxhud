--[[
boxhud.lua 2.1.4 -- aquietone
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
local DanNet = mq.TLO.DanNet
local NetBots = mq.TLO.NetBots
--- @type ImGui
require 'ImGui'
local bh = require('boxhud.utils')
local ConfigurationPanel = require('boxhud.configpanel')

local arg = {...}

-- GUI Control variables
local openGUI = true
local shouldDrawGUI = true
local terminate = false

local peerTable = {}
local sortedPeers = {}
-- Stores all live observed toon information that will be displayed
local characters = {}
local anonymize = false
local adminMode = false
local adminPeerSelected = 0
math.randomseed(os.time())
local tableRandom = math.random(1,100)
local windowStates = {}

local resetObserversName = nil
local storedCommand = nil

-- lists of classes to check against for things like displaying mana % versus endurance %
local casters = bh.Set { 'cleric', 'clr', 'druid', 'dru', 'shaman', 'shm', 'enchanter',
                      'enc', 'magician', 'mag', 'necromancer', 'nec', 'wizard', 'wiz' }
-- melee, hybrid, ranged overlap for compatibility.
-- hybrids is checked before melee as it is a more specific subset of classes
local melee = bh.Set { 'rogue', 'rog', 'monk', 'mnk', 'berserker', 'ber', 'warrior', 'war',
                    'bard', 'brd', 'ranger', 'rng', 'beastlord', 'bst', 'shadow knight',
                    'shd', 'paladin', 'pal' }
local hybrids = bh.Set { 'bard', 'brd', 'ranger', 'rng', 'beastlord', 'bst', 'shadow knight',
                      'shd', 'paladin', 'pal' }
local ranged = bh.Set { 'ranger', 'rng' }

--[[
Internal runtime settings of a boxhud window, separate from the
static window settings stored in boxhud-settings.lua
--]]
local WindowState = bh.class(function(w, name, peerGroup)
    w.name = name
    if peerGroup == 'zone' then
        w.peerGroup = bh.GetZonePeerGroup()
    else
        w.peerGroup = peerGroup
    end
    w.peers = nil
    w.peersDirty = false
    w.sortedPeers = nil
    w.configPanel = ConfigurationPanel(name)
end)

--[[
Stores all information about a given character to be displayed
in a boxhud window.
--]]
local Character = bh.class(function(b, name, className)
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
        local dependentValue = DanNet(self.name).Observe(string.format('"%s"', propSettings['DependsOnName']))()
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
    if not DanNet(self.name)() or DanNet(self.name).ObserveSet('"'..propName..'"')() then
        return true
    end
    return false
end

-- Return whether or not all expected observers are set for a toon 
function Character:verifyObservers()
    for propName, propSettings in pairs(bh.settings['Properties']) do
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
        for depPropName,depPropSettings in pairs(bh.settings['Properties']) do
            if depPropName == propSettings['DependsOnName'] then
                self:addObserver(depPropName, depPropSettings)
            end
        end
    end
    if self:shouldObserveProperty(propSettings) then
        -- Add the observation if it is not set
        if not DanNet(self.name).ObserveSet(string.format('"%s"', propName))() then
            mq.cmdf('/dobserve %s -q "%s"', self.name, propName)
        end
        local verifyStartTime = os.time(os.date("!*t"))
        while not self:isObserverSet(propName, propSettings) do
            mq.delay(25)
            if os.difftime(os.time(os.date("!*t")), verifyStartTime) > 20 then
                bh.print_err('Timed out waiting for observer to be added for \ay'..self.name)
                bh.print_err('Exiting the script.')
                mq.exit()
            end
        end
    end
end

function Character:removeObserver(propName, propSettings)
    -- Drop the observation if it is set
    if DanNet(self.name).ObserveSet(string.format('"%s"', propName))() then
        mq.cmdf('/dobserve %s -q "%s" -drop', self.name, propName)
    end
    local verifyStartTime = os.time(os.date("!*t"))
    while self:isObserverSet(propName, propSettings) do
        mq.delay(25)
        if os.difftime(os.time(os.date("!*t")), verifyStartTime) > 20 then
            bh.print_err('Timed out waiting for observer to be removed for \ay'..self.name)
            bh.print_err('Exiting the script.')
            mq.exit()
        end
    end
end

-- Add or remove observers for the given toon
function Character:manageObservers(drop)
    if drop then
        for propName, propSettings in pairs(bh.settings['Properties']) do
            if propSettings['Type'] == 'Observed' then
                self:removeObserver(propName, propSettings)
            end
        end
        bh.print_msg('Removed observed properties for: \ay'..self.name)
    else
        for propName, propSettings in pairs(bh.settings['Properties']) do
            if propSettings['Type'] == 'Observed' then
                self:addObserver(propName, propSettings)
            end
        end
        bh.print_msg('Added observed properties for: \ay'..self.name)
    end
end

local function SetText(value, thresholds, ascending, percentage)
    local col = bh.settings['Colors']['Default']
    if thresholds ~= nil then
        local valueNum = tonumber(value)
        if valueNum == nil then
            return
        end
        if #thresholds == 1 then
            if valueNum >= thresholds[1] then
                if ascending then
                    col = bh.settings['Colors']['High']
                else -- red if above
                    col = bh.settings['Colors']['Low']
                end
            else
                if ascending then
                    col = bh.settings['Colors']['Low']
                else -- green if below
                    col = bh.settings['Colors']['High']
                end
            end
        elseif #thresholds == 2 then
            if valueNum >= thresholds[2] then
                if ascending then
                    col = bh.settings['Colors']['High']
                else
                    col = bh.settings['Colors']['Low']
                end
            elseif valueNum >= thresholds[1] and valueNum < thresholds[2] then
                col = bh.settings['Colors']['Medium']
            else
                if ascending then
                    col = bh.settings['Colors']['Low']
                else
                    col = bh.settings['Colors']['High']
                end
            end
        end
    end
    if value:lower() == 'true' then
        col = SETTINGS['Colors']['True']
    elseif value:lower() == 'false' then
        col = SETTINGS['Colors']['False']
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
    if anonymize then
        if self.className then
            return string.upper(self.className)
        else
            return 'UNKNOWN'
        end
    else
        return bh.TitleCase(self.name)
    end
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
            bh.print_msg('Resetting observed properties for: \ay'..self.name)
            ImGui.CloseCurrentPopup()
            resetObserversName = self.name
        end
        ImGui.Text('Send Command to '..self:getDisplayName()..': ')
        local textInput = ""
        textInput, selected = ImGui.InputText("##input"..self.name, textInput, ImGuiInputTextFlags.EnterReturnsTrue)
        if selected then
            bh.print_msg('Sending command: \ag/dex '..self:getDisplayName()..' '..textInput)
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
        if self.properties['Me.Invis'] == true then -- Me.Invis* isn't observed, just getting ANY invis from spawn data
            col = bh.settings['Colors']['Invis'] or {0.26, 0.98, 0.98}
            buttonText = '('..self:getDisplayName()..')'
        elseif self.properties['Me.Invis'] == 1 then -- Me.Invis[1] is observed and toon has regular invis
            col = bh.settings['Colors']['Invis'] or {0.26, 0.98, 0.98}
            buttonText = '('..self:getDisplayName()..')'
        elseif self.properties['Me.Invis'] == 2 then -- Me.Invis[2] is observed and toon  has ivu
            col = bh.settings['Colors']['IVU'] or {0.95, 0.98, 0.26}
            buttonText = '('..self:getDisplayName()..')'
        elseif self.properties['Me.Invis'] == 3 then -- Me.Invis[1,2] is observed and toon has double invis
            col = bh.settings['Colors']['DoubleInvis'] or {0.68, 0.98, 0.98}
            buttonText = '('..self:getDisplayName()..')'
        else -- toon has no invis
            col = bh.settings['Colors']['InZone'] or {0,1,0}
        end
    else
        col = bh.settings['Colors']['NotInZone'] or {1,0,0}
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
        if value and value ~= 'NULL' then
            if column['Mappings'] and column['Mappings'][value] then
                value = column['Mappings'][value]
            end
            SetText(value, thresholds, column['Ascending'], column['Percentage'])
        end
    end
end

function Character:drawColumnButton(columnName, columnAction)
    if ImGui.SmallButton(columnName..'##'..self.name) then
        if self.name == mq.TLO.Me.Name():lower() and columnAction:find('/dex #botName# ') ~= -1 then
            storedCommand = columnAction:gsub('/dex #botName# ', '')
        else
            storedCommand = columnAction:gsub('#botName#', self.name)
        end
        bh.print_msg('Run command: \ag'..storedCommand)
    end
end

function Character:updateCharacterProperties(currTime, peerGroup)
    local properties = {}
    local charSpawnData = mq.TLO.Spawn('='..self.name)
    properties['Me.ID'] = charSpawnData.ID()
    properties['Me.Invis'] = charSpawnData.Invis()

    -- Fill in data from this toons observed properties
    for propName, propSettings in pairs(bh.settings['Properties']) do
        if propSettings['Type'] == 'Observed' then
            if self:shouldObserveProperty(propSettings) then
                properties[propName] = DanNet(self.name).Observe('"'..propName..'"')()
            else
                properties[propName] = ''
            end
        elseif propSettings['Type'] == 'NetBots' then
            -- tostring instead of ending with () because class returned a number instead of class string
            if propName:find('Class') then
                properties[propName] = tostring(NetBots(bh.TitleCase(self.name))[propName])
            else
                properties[propName] = NetBots(bh.TitleCase(self.name))[propName]()
            end
        elseif propSettings['Type'] == 'Spawn' then
            if propSettings['FromIDProperty'] then
                if bh.settings['Properties'][propSettings.FromIDProperty]['Type'] == 'NetBots' then
                    properties[propSettings.FromIDProperty] = NetBots(bh.TitleCase(self.name))[propSettings.FromIDProperty]()
                end
                properties[propName] = mq.TLO.Spawn(string.format('id %s', properties[propSettings['FromIDProperty']]))[propName]()
            else
                properties[propName] = charSpawnData[propName]()
                if type(properties[propName]) == 'number' then
                    properties[propName] = string.format("%.2f", properties[propName])
                end
            end
        end
    end

    if peerGroup ~= 'zone' then
        properties['BotInZone'] = properties['Me.ID'] ~= 0
    else
        properties['BotInZone'] = true
    end
    if properties['Me.Invis[1]'] == 'TRUE' then
        if type(properties['Me.Invis']) ~= 'number' then properties['Me.Invis'] = 0 end
        properties['Me.Invis'] = properties['Me.Invis'] + 1
    end
    if properties['Me.Invis[2]'] == 'TRUE' then
        if type(properties['Me.Invis']) ~= 'number' then properties['Me.Invis'] = 0 end
        properties['Me.Invis'] = properties['Me.Invis'] + 2
    end
    properties['lastUpdated'] = currTime
    if properties[bh.class_var] and not self.className then
        self.className = properties[bh.class_var]:lower()
    end
    self.properties = properties
end

local current_sort_specs = {}
local current_columns = {}
local function CompareWithSortSpecs(a, b)
    for n = 1, current_sort_specs.SpecsCount, 1 do
        -- Here we identify columns using the ColumnUserID value that we ourselves passed to TableSetupColumn()
        -- We could also choose to identify columns based on their index (sort_spec.ColumnIndex), which is simpler!
        local sort_spec = current_sort_specs:Specs(n)
        local delta = 0

        local columnName = current_columns[sort_spec.ColumnUserID]
        local column = bh.settings['Columns'][columnName]
        if not column then
            return a < b
        end
        local aVal = nil
        local bVal = nil
        if column['Name'] == 'Name' or not column['Properties'] or not column['Properties']['all'] then
            aVal = tostring(a)
            bVal = tostring(b)
        elseif characters[a].properties and characters[b].properties then
            aVal = tostring(characters[a].properties[column['Properties']['all']] or -1)
            bVal = tostring(characters[b].properties[column['Properties']['all']] or -1)
        else
            aVal = tostring(a)
            bVal = tostring(b)
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

function bh.Window:drawTableTab(columns, tabName)
    local flags = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Sortable, ImGuiTableFlags.MultiSortable,
            ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.ScrollY, ImGuiTableFlags.NoSavedSettings)
    if ImGui.BeginTable('##bhtable'..tabName..tostring(tableRandom), #columns, flags, 0, 0, 0.0) then
        for i, columnName in ipairs(columns) do
            local column = bh.settings['Columns'][columnName]
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
            if sort_specs.SpecsDirty or windowStates[self.Name].peersDirty then
                if #windowStates[self.Name].peers > 0 then
                    current_sort_specs = sort_specs
                    current_columns = columns
                    windowStates[self.Name].sortedPeers = bh.TableClone(windowStates[self.Name].peers)
                    table.sort(windowStates[self.Name].sortedPeers, CompareWithSortSpecs)
                    current_sort_specs = nil
                    current_columns = nil
                end
                sort_specs.SpecsDirty = false
                windowStates[self.Name].peersDirty = false
            end
        end

        -- Display data
        ImGui.TableHeadersRow()
        local clipper = ImGuiListClipper.new()
        if windowStates[self.Name].sortedPeers == nil then
            windowStates[self.Name].sortedPeers = bh.TableClone(windowStates[self.Name].peers)
        end
        clipper:Begin(#windowStates[self.Name].sortedPeers)
        while clipper:Step() do
            for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
                local clipName = windowStates[self.Name].sortedPeers[row_n+1]
                local char = characters[clipName]
                if char and char.properties then
                    ImGui.PushID(clipName)
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    for i,columnName in ipairs(columns) do
                        local column = bh.settings['Columns'][columnName]
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

function bh.Window:drawTabs()
    if ImGui.BeginTabBar('BOXHUDTABS##'..self.Name) then
        for _,tabName in ipairs(self.Tabs) do
            local tab = bh.GetTabByName(tabName)
            if ImGui.BeginTabItem(tab['Name']) then
                if tab['Columns'] and #tab['Columns'] > 0 then
                    self:drawTableTab(tab['Columns'], tab['Name'])
                    ImGui.EndTabItem()
                else
                    ImGui.Text('No columns defined for tab')
                    ImGui.EndTabItem()
                end
            end
        end

        -- Admin tab only allows resetting observers, so only show if dannet is being used
        if bh.IsUsingDanNet() then
            if ImGui.BeginTabItem('Admin') then
                ImGui.Text('DanNet Peer Group: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, windowStates[self.Name].peerGroup)
                ImGui.Text('Reset Observers for:')
                adminPeerSelected, clicked = ImGui.Combo("##combo", adminPeerSelected, windowStates[self.Name].peers, #windowStates[self.Name].peers, 5)
                ImGui.SameLine()
                if ImGui.Button('Reset') then
                    bh.print_msg('Resetting observed properties for: \ay'..windowStates[self.Name].peers[adminPeerSelected+1])
                    resetObserversName = windowStates[self.Name].peers[adminPeerSelected+1]
                end
                ImGui.EndTabItem()
            end
        end

        if ImGui.BeginTabItem('Configuration##'..self.Name) then
            windowStates[self.Name].configPanel:draw()
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
end

-- ImGui main function for rendering the UI window
local HUDGUI = function()
    local myname = mq.TLO.Me.CleanName()
    if not myname or myname == 'load' then return end
    if not openGUI then return end
    for _,window in pairs(bh.settings['Windows']) do
        local flags = 0
        if not window['TitleBar'] then flags = bit32.bor(flags, ImGuiWindowFlags.NoTitleBar) end
        if window['Transparency'] then flags = bit32.bor(flags, ImGuiWindowFlags.NoBackground) end
        if windowStates[window.Name] and windowStates[window.Name].peers then
            openGUI, shouldDrawGUI = ImGui.Begin('Box HUD##'..myname..window.Name, openGUI, flags)
            if shouldDrawGUI then
                if ImGui.GetWindowHeight() == 32 and ImGui.GetWindowWidth() == 32 then
                    ImGui.SetWindowSize(460, 177)
                end
                window:drawTabs()
            end
            ImGui.End()
        end
    end
end

local Admin = function(action, name)
    if action == nil then
        adminMode = not adminMode
        openGUI = not adminMode
        bh.print_msg('Setting \ayadminMode\ax = \ay'..tostring(adminMode))
    elseif action == 'anon' then
        anonymize = not anonymize
    elseif action  == 'reset' then
        if not adminMode then
            bh.print_err('\ayadminMode\ax must be enabled')
            return
        end
        if name == nil then
            bh.print_msg('Resetting observed properties for: \ayALL')
            for _,char in pairs(characters) do
                char:manageObservers(true)
                char:manageObservers(false)
            end
        else
            bh.print_msg('Resetting observed properties for: \ay'..name)
            characters[name]:manageObservers(true)
            characters[name]:manageObservers(false)
        end
    end
end

local Help = function()
    bh.print_msg('Available commands:')
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
    bh.print_msg('Version '..bh.version)
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
        if os.difftime(currTime, char.properties['lastUpdated']) > bh.stale_data_timeout then
            bh.print_msg('Removing stale toon data: \ay'..name)
            characters[name] = nil
        end
    end
end

local function SendCommand()
    mq.cmd(storedCommand)
    storedCommand = nil
end

function WindowState:refreshPeers()
    local windowSettings = bh.settings.Windows[self.name]
    if windowSettings.PeerGroup == 'zone' then
        self.peerGroup = bh.GetZonePeerGroup()
    elseif windowSettings.PeerGroup == 'group' then
        self.peerGroup = bh.GetGroupPeerGroup()
    elseif self.peerGroup ~= windowSettings.PeerGroup then
        self.peerGroup = windowSettings.PeerGroup
    end
    local t = {}
    if bh.peer_source == 'dannet' then
        t = bh.Split(DanNet.Peers(self.peerGroup)())
    else
        for i=1,NetBots.Counts() do
            table.insert(t, NetBots.Client.Arg(i)())
        end
    end

    if not self.peers or not bh.DoTablesMatch(self.peers, t) then
        self.peers = t
        self.peersDirty = true
    end
    for i,peerName in ipairs(self.peers) do
        if not characters[peerName] then
            characters[peerName] = Character(peerName,nil)
        end
    end
end

local function SetupWindowStates()
    for _,window in pairs(bh.settings['Windows']) do
        windowStates[window.Name] = WindowState(window.Name, window.PeerGroup or 'zone')
        windowStates[window.Name]:refreshPeers()
    end
end

local function CheckGameState()
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        bh.print_err('\arNot in game, stopping boxhud.\ax')
        openGUI = false
        shouldDrawGUI = false
        mq.imgui.destroy('BOXHUDUI')
        mq.exit()
    end
end

local function main()
    bh.LoadSettings(arg)
    bh.PluginCheck()
    SetupBindings()
    SetupWindowStates()
    mq.imgui.init('BOXHUDUI', HUDGUI)

    -- Initial setup of observers
    if bh.IsUsingDanNet() then
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
        local currTime = os.time(os.date("!*t"))
        for windowName,window in pairs(bh.settings['Windows']) do
            if not windowStates[windowName] then
                windowStates[windowName] = WindowState(windowName, window.PeerGroup or 'zone')
            end
            windowStates[windowName]:refreshPeers()
            if windowStates[windowName].peers then
                for _, charName in pairs(windowStates[windowName].peers) do
                    local char = characters[charName]
                    -- Ensure observers are set for the toon
                    if bh.IsUsingDanNet() then
                        if resetObserversName == char.name then
                            resetObserversName = nil
                            char:manageObservers(true)
                            char:manageObservers(false)
                        elseif not char:verifyObservers() then
                            char:manageObservers(false)
                        end
                    end
                    char:updateCharacterProperties(currTime, window['PeerGroup'])
                end
            end
        end
        CleanupStaleData(currTime)
        mq.delay(bh.refresh_interval)
    end
end

main()
