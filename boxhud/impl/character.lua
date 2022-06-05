local Character = require 'boxhud.classes.hud.character'
local utils = require 'boxhud.utils.utils'
local state = require 'boxhud.state'

--- @type mq
local mq = require 'mq'
local DanNet = mq.TLO.DanNet
local NetBots = mq.TLO.NetBots

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
function Character:isObserverSet(propName)
    if not DanNet(self.name)() or DanNet(self.name).ObserveSet('"'..propName..'"')() then
        return true
    end
    return false
end

-- Return whether or not all expected observers are set for a toon 
function Character:verifyObservers()
    for propName, propSettings in pairs(state.settings['Properties']) do
        if propSettings['Type'] == 'Observed' and self:shouldObserveProperty(propSettings) then
            if not self:isObserverSet(propName) then
                return false
            end
        end
    end
    return true
end

function Character:addObserver(propName, propSettings)
    if propSettings['DependsOnName'] then
        for depPropName,depPropSettings in pairs(state.settings['Properties']) do
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
        while not self:isObserverSet(propName) do
            mq.delay(25)
            if os.difftime(os.time(os.date("!*t")), verifyStartTime) > 20 then
                print_err('Timed out waiting for observer to be added for \ay'..self.name)
                print_err('Exiting the script.')
                mq.exit()
            end
        end
    end
end

function Character:removeObserver(propName)
    -- Drop the observation if it is set
    if DanNet(self.name).ObserveSet(string.format('"%s"', propName))() then
        mq.cmdf('/dobserve %s -q "%s" -drop', self.name, propName)
    end
    local verifyStartTime = os.time(os.date("!*t"))
    while self:isObserverSet(propName) do
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
        for propName, propSettings in pairs(state.settings['Properties']) do
            if propSettings['Type'] == 'Observed' then
                self:removeObserver(propName)
            end
        end
        print_msg('Removed observed properties for: \ay'..self.name)
    else
        for propName, propSettings in pairs(state.settings['Properties']) do
            if propSettings['Type'] == 'Observed' then
                self:addObserver(propName, propSettings)
            end
        end
        print_msg('Added observed properties for: \ay'..self.name)
    end
end

-- lists of classes to check against for things like displaying mana % versus endurance %
local casters = utils.Set { 'cleric', 'clr', 'druid', 'dru', 'shaman', 'shm', 'enchanter',
                      'enc', 'magician', 'mag', 'necromancer', 'nec', 'wizard', 'wiz' }
-- melee, hybrid, ranged overlap for compatibility.
-- hybrids is checked before melee as it is a more specific subset of classes
local melee = utils.Set { 'rogue', 'rog', 'monk', 'mnk', 'berserker', 'ber', 'warrior', 'war',
                    'bard', 'brd', 'ranger', 'rng', 'beastlord', 'bst', 'shadow knight',
                    'shd', 'paladin', 'pal' }
local hybrids = utils.Set { 'bard', 'brd', 'ranger', 'rng', 'beastlord', 'bst', 'shadow knight',
                      'shd', 'paladin', 'pal' }
local ranged = utils.Set { 'ranger', 'rng' }

local function SetText(value, thresholds, ascending, percentage)
    local col = state.settings['Colors']['Default']
    if thresholds ~= nil then
        local valueNum = tonumber(value)
        if valueNum == nil then
            return
        end
        if #thresholds == 1 then
            if valueNum >= thresholds[1] then
                if ascending then
                    col = state.settings['Colors']['High']
                else -- red if above
                    col = state.settings['Colors']['Low']
                end
            else
                if ascending then
                    col = state.settings['Colors']['Low']
                else -- green if below
                    col = state.settings['Colors']['High']
                end
            end
        elseif #thresholds == 2 then
            if valueNum >= thresholds[2] then
                if ascending then
                    col = state.settings['Colors']['High']
                else
                    col = state.settings['Colors']['Low']
                end
            elseif valueNum >= thresholds[1] and valueNum < thresholds[2] then
                col = state.settings['Colors']['Medium']
            else
                if ascending then
                    col = state.settings['Colors']['Low']
                else
                    col = state.settings['Colors']['High']
                end
            end
        end
    end
    if value:lower() == 'true' then
        col = state.settings['Colors']['True']
    elseif value:lower() == 'false' then
        col = state.settings['Colors']['False']
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
    if state.anonymize then
        if self.className then
            return string.upper(self.className)
        else
            return 'UNKNOWN'
        end
    else
        return utils.TitleCase(self.name)
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
            print_msg('Resetting observed properties for: \ay'..self.name)
            ImGui.CloseCurrentPopup()
            state.resetObserversName = self.name
        end
        ImGui.Text('Send Command to '..self:getDisplayName()..': ')
        local textInput = ""
        textInput, selected = ImGui.InputText("##input"..self.name, textInput, ImGuiInputTextFlags.EnterReturnsTrue)
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
        if self.properties['Me.Invis'] == true then -- Me.Invis* isn't observed, just getting ANY invis from spawn data
            col = state.settings['Colors']['Invis'] or {0.26, 0.98, 0.98}
            buttonText = '('..self:getDisplayName()..')'
        elseif self.properties['Me.Invis'] == 1 then -- Me.Invis[1] is observed and toon has regular invis
            col = state.settings['Colors']['Invis'] or {0.26, 0.98, 0.98}
            buttonText = '('..self:getDisplayName()..')'
        elseif self.properties['Me.Invis'] == 2 then -- Me.Invis[2] is observed and toon  has ivu
            col = state.settings['Colors']['IVU'] or {0.95, 0.98, 0.26}
            buttonText = '('..self:getDisplayName()..')'
        elseif self.properties['Me.Invis'] == 3 then -- Me.Invis[1,2] is observed and toon has double invis
            col = state.settings['Colors']['DoubleInvis'] or {0.68, 0.98, 0.98}
            buttonText = '('..self:getDisplayName()..')'
        else -- toon has no invis
            col = state.settings['Colors']['InZone'] or {0,1,0}
        end
    else
        col = state.settings['Colors']['NotInZone'] or {1,0,0}
    end
    ImGui.PushStyleColor(ImGuiCol.Text, col[1], col[2], col[3], 1)

    if ImGui.SmallButton(buttonText..'##'..self.name) then
        state.storedCommand = string.format('/squelch /dex %s /foreground', self.name)
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
        print_msg('Run command: \ag'..storedCommand)
    end
end

function Character:updateCharacterProperties(currTime, peerGroup)
    local properties = {}
    local charSpawnData = mq.TLO.Spawn('='..self.name)
    properties['Me.ID'] = charSpawnData.ID()
    properties['Me.Invis'] = charSpawnData.Invis()

    -- Fill in data from this toons observed properties
    for propName, propSettings in pairs(state.settings['Properties']) do
        if propSettings['Type'] == 'Observed' then
            if self:shouldObserveProperty(propSettings) then
                properties[propName] = DanNet(self.name).Observe('"'..propName..'"')()
            else
                properties[propName] = ''
            end
        elseif propSettings['Type'] == 'NetBots' then
            -- tostring instead of ending with () because class returned a number instead of class string
            if propName:find('Class') then
                properties[propName] = tostring(NetBots(utils.TitleCase(self.name))[propName])
            else
                properties[propName] = NetBots(utils.TitleCase(self.name))[propName]()
            end
        elseif propSettings['Type'] == 'Spawn' then
            if propSettings['FromIDProperty'] then
                if state.settings['Properties'][propSettings.FromIDProperty]['Type'] == 'NetBots' then
                    properties[propSettings.FromIDProperty] = NetBots(utils.TitleCase(self.name))[propSettings.FromIDProperty]()
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
    if properties[utils.class_var] and not self.className then
        self.className = properties[utils.class_var]:lower()
    end
    self.properties = properties
end