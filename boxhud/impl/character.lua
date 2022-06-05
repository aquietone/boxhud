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
        local dependentValue = DanNet(self.Name).Observe(string.format('"%s"', propSettings['DependsOnName']))()
        if dependentValue then
            if not propSettings['Inverse'] and string.lower(propSettings['DependsOnValue']):find(string.lower(dependentValue)) ~= nil then
                -- The value of the dependent property matches
                return true
            elseif propSettings['Inverse'] and string.lower(propSettings['DependsOnValue']):find(string.lower(dependentValue)) == nil then
                return true
            end
        end
    end
    -- Do not observe the property
    return false
end

-- Return whether or not a property is observed for a toon
function Character:isObserverSet(propName)
    if not DanNet(self.Name)() or DanNet(self.Name).ObserveSet('"'..propName..'"')() then
        return true
    end
    return false
end

-- Return whether or not all expected observers are set for a toon 
function Character:verifyObservers()
    for propName, propSettings in pairs(state.Settings['Properties']) do
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
        for depPropName,depPropSettings in pairs(state.Settings['Properties']) do
            if depPropName == propSettings['DependsOnName'] then
                self:addObserver(depPropName, depPropSettings)
            end
        end
    end
    if self:shouldObserveProperty(propSettings) then
        -- Add the observation if it is not set
        if not DanNet(self.Name).ObserveSet(string.format('"%s"', propName))() then
            mq.cmdf('/dobserve %s -q "%s"', self.Name, propName)
        end
        local verifyStartTime = os.time(os.date("!*t"))
        while not self:isObserverSet(propName) do
            mq.delay(25)
            if os.difftime(os.time(os.date("!*t")), verifyStartTime) > 20 then
                print_err('Timed out waiting for observer to be added for \ay'..self.Name)
                print_err('Exiting the script.')
                mq.exit()
            end
        end
    end
end

function Character:removeObserver(propName)
    -- Drop the observation if it is set
    if DanNet(self.Name).ObserveSet(string.format('"%s"', propName))() then
        mq.cmdf('/dobserve %s -q "%s" -drop', self.Name, propName)
    end
    local verifyStartTime = os.time(os.date("!*t"))
    while self:isObserverSet(propName) do
        mq.delay(25)
        if os.difftime(os.time(os.date("!*t")), verifyStartTime) > 20 then
            print_err('Timed out waiting for observer to be removed for \ay'..self.Name)
            print_err('Exiting the script.')
            mq.exit()
        end
    end
end

-- Add or remove observers for the given toon
function Character:manageObservers(drop)
    if drop then
        for propName, propSettings in pairs(state.Settings['Properties']) do
            if propSettings['Type'] == 'Observed' then
                self:removeObserver(propName)
            end
        end
        print_msg('Removed observed properties for: \ay'..self.Name)
    else
        for propName, propSettings in pairs(state.Settings['Properties']) do
            if propSettings['Type'] == 'Observed' then
                self:addObserver(propName, propSettings)
            end
        end
        print_msg('Added observed properties for: \ay'..self.Name)
    end
end

function Character:dannetAdminAction()
    if state.AdminPeerAction == 'reset' then
        self:manageObservers(true)
        self:manageObservers(false)
    elseif state.AdminPeerAction == 'check' then
        local obsSet = self:isObserverSet(state.AdminPeerItem)
        print_msg(string.format('Observer set for \ay%s\ax: \ay%s\ax', state.AdminPeerItem, tostring(obsSet)))
    elseif state.AdminPeerAction == 'drop' then
        self:removeObserver(state.AdminPeerItem)
    end
    state.AdminPeerName = nil
    state.AdminPeerAction = nil
    state.AdminPeerItem = ''
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
    local col = state.Settings['Colors']['Default']
    if thresholds ~= nil then
        local valueNum = tonumber(value)
        if valueNum == nil then
            return
        end
        if #thresholds == 1 then
            if valueNum >= thresholds[1] then
                if ascending then
                    col = state.Settings['Colors']['High']
                else -- red if above
                    col = state.Settings['Colors']['Low']
                end
            else
                if ascending then
                    col = state.Settings['Colors']['Low']
                else -- green if below
                    col = state.Settings['Colors']['High']
                end
            end
        elseif #thresholds == 2 then
            if valueNum >= thresholds[2] then
                if ascending then
                    col = state.Settings['Colors']['High']
                else
                    col = state.Settings['Colors']['Low']
                end
            elseif valueNum >= thresholds[1] and valueNum < thresholds[2] then
                col = state.Settings['Colors']['Medium']
            else
                if ascending then
                    col = state.Settings['Colors']['Low']
                else
                    col = state.Settings['Colors']['High']
                end
            end
        end
    end
    if value:lower() == 'true' then
        col = state.Settings['Colors']['True']
    elseif value:lower() == 'false' then
        col = state.Settings['Colors']['False']
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
        mq.cmdf(action, self.Name)
    end
end

function Character:getDisplayName()
    if state.Anonymize then
        if self.ClassName then
            return string.upper(self.ClassName)
        else
            return 'UNKNOWN'
        end
    else
        return utils.TitleCase(self.Name)
    end
end

function Character:drawContextMenu()
    if ImGui.BeginPopupContextItem("##popup"..self.Name) then
        self:drawCmdButton('Target##'..self.Name, '/target %s')
        ImGui.SameLine()
        self:drawCmdButton('Nav To##'..self.Name, '/nav spawn %s')
        ImGui.SameLine()
        self:drawCmdButton('Come To Me##'..self.Name, '/dex %s /nav id ${Me.ID}')
        
        self:drawCmdButton('G Inv##'..self.Name, '/invite %s')
        ImGui.SameLine()
        self:drawCmdButton('R Inv##'..self.Name, '/raidinvite %s')
        ImGui.SameLine()
        self:drawCmdButton('DZAdd##'..self.Name, '/dzadd %s')
        ImGui.SameLine()
        self:drawCmdButton('TAdd##'..self.Name, '/taskadd %s')
        
        if ImGui.SmallButton("Reset Obs##"..self.Name) then
            print_msg('Resetting observed properties for: \ay'..self.Name)
            ImGui.CloseCurrentPopup()
            state.AdminPeerAction = 'reset'
            state.AdminPeerName = self.Name
        end
        ImGui.Text('Send Command to '..self:getDisplayName()..': ')
        local textInput = ""
        textInput, selected = ImGui.InputText("##input"..self.Name, textInput, ImGuiInputTextFlags.EnterReturnsTrue)
        if selected then
            print_msg('Sending command: \ag/dex '..self:getDisplayName()..' '..textInput)
            ImGui.CloseCurrentPopup()
            mq.cmdf('/dex %s %s', self.Name, textInput)
        end
        ImGui.EndPopup()
    end
end

function Character:drawNameButton()
    local buttonText = self:getDisplayName()
    local col = nil
    if self.Properties['BotInZone'] then
        if self.Properties['Me.Invis'] == true then -- Me.Invis* isn't observed, just getting ANY invis from spawn data
            col = state.Settings['Colors']['Invis'] or {0.26, 0.98, 0.98}
            buttonText = '('..self:getDisplayName()..')'
        elseif self.Properties['Me.Invis'] == 1 then -- Me.Invis[1] is observed and toon has regular invis
            col = state.Settings['Colors']['Invis'] or {0.26, 0.98, 0.98}
            buttonText = '('..self:getDisplayName()..')'
        elseif self.Properties['Me.Invis'] == 2 then -- Me.Invis[2] is observed and toon  has ivu
            col = state.Settings['Colors']['IVU'] or {0.95, 0.98, 0.26}
            buttonText = '('..self:getDisplayName()..')'
        elseif self.Properties['Me.Invis'] == 3 then -- Me.Invis[1,2] is observed and toon has double invis
            col = state.Settings['Colors']['DoubleInvis'] or {0.68, 0.98, 0.98}
            buttonText = '('..self:getDisplayName()..')'
        else -- toon has no invis
            col = state.Settings['Colors']['InZone'] or {0,1,0}
        end
    else
        col = state.Settings['Colors']['NotInZone'] or {1,0,0}
    end
    ImGui.PushStyleColor(ImGuiCol.Text, col[1], col[2], col[3], 1)

    if ImGui.SmallButton(buttonText..'##'..self.Name) then
        mq.cmdf('/squelch /dex %s /foreground', self.Name)
    end
    ImGui.PopStyleColor(1)
    self:drawContextMenu()
end

function Character:drawColumnProperty(column)
    if not column['InZone'] or (column['InZone'] and self.Properties['BotInZone']) then
        local value = 'NULL'
        if column['Properties'][self.ClassName] then
            value = self.Properties[column['Properties'][self.ClassName]]
        elseif column['Properties']['ranged'] and ranged[self.ClassName] then
            value = self.Properties[column['Properties']['ranged']]
        elseif column['Properties']['hybrids'] and hybrids[self.ClassName] then
            value = self.Properties[column['Properties']['hybrids']]
        elseif column['Properties']['caster'] and casters[self.ClassName] then
            value = self.Properties[column['Properties']['caster']]
        elseif column['Properties']['melee'] and melee[self.ClassName] then
            value = self.Properties[column['Properties']['melee']]
        end
        if (value == 'NULL' or value == '') and column['Properties']['all'] then
            value = self.Properties[column['Properties']['all']]
        end
        local thresholds = column['Thresholds']
        if value and value ~= 'NULL' then
            if column['Mappings'] and column['Mappings'][value] then
                value = column['Mappings'][value]
            end
            SetText(tostring(value), thresholds, column['Ascending'], column['Percentage'])
        end
    end
end

function Character:drawColumnButton(columnName, columnAction)
    if ImGui.SmallButton(columnName..'##'..self.Name) then
        if self.Name == mq.TLO.Me.Name():lower() and columnAction:find('/dex #botName# ') ~= -1 then
            state.StoredCommand = columnAction:gsub('/dex #botName# ', '')
        else
            state.StoredCommand = columnAction:gsub('#botName#', self.Name)
        end
        print_msg('Run command: \ag'..state.StoredCommand)
    end
end

function Character:updateCharacterProperties(currTime, peerGroup)
    local properties = {}
    local charSpawnData = mq.TLO.Spawn('='..self.Name)
    properties['Me.ID'] = charSpawnData.ID()
    properties['Me.Invis'] = charSpawnData.Invis()

    -- Fill in data from this toons observed properties
    for propName, propSettings in pairs(state.Settings['Properties']) do
        if propSettings['Type'] == 'Observed' then
            if self:shouldObserveProperty(propSettings) then
                properties[propName] = DanNet(self.Name).Observe('"'..propName..'"')()
            else
                properties[propName] = ''
            end
        elseif propSettings['Type'] == 'NetBots' then
            -- tostring instead of ending with () because class returned a number instead of class string
            if propName:find('Class') then
                properties[propName] = tostring(NetBots(utils.TitleCase(self.Name))[propName])
            else
                properties[propName] = NetBots(utils.TitleCase(self.Name))[propName]()
            end
        elseif propSettings['Type'] == 'Spawn' then
            if propSettings['FromIDProperty'] then
                if state.Settings['Properties'][propSettings.FromIDProperty]['Type'] == 'NetBots' then
                    properties[propSettings.FromIDProperty] = NetBots(utils.TitleCase(self.Name))[propSettings.FromIDProperty]()
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
    if properties[state.ClassVar] and not self.ClassName then
        self.ClassName = properties[state.ClassVar]:lower()
    end
    self.Properties = properties
end