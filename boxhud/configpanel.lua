-- boxhud/configpanel.lua 2.1.0 -- aquietone
--- @type ImGui
require 'ImGui'
local bh = require('boxhud.utils')

local classes = {'all', 'melee', 'caster', 'hybrids', 'ranged', 'ber', 'brd', 
        'bst', 'clr', 'dru', 'enc', 'mag', 'mnk', 'nec', 'pal', 'shd', 'rng', 
        'rog', 'shm', 'war', 'wiz'}

local ConfigurationPanel = bh.class(function(c, name)
    c.name = name
    c.selected = false
    c.selectedItem = nil
    c.selectedItemType = nil
    c.newProperty = nil
    c.newColumn = nil
    c.newTab = nil
    c.newWindow = nil
end)

function ConfigurationPanel:clearSelection()
    self.selected = false
    self.selectedItem = nil
    self.selectedItemType = nil
end

function ConfigurationPanel:selectItem(item, itemType)
    self.selectedItem = item
    self.selectedItemType = itemType
end

local Input = bh.class(function(i)
    i.Name=''
    i.valid=true
    i.message=nil
    i.shouldDrawCombo = false
end)

local PropertyInput = bh.class(Input(), function(p)
    p.Type=1
    p.DependsOnName=''
    p.DependsOnValue=''
    p.FromIDProperty=''
end)

function PropertyInput:toProperty()
    local property = bh.Property({})
    property['Name'] = self.Name
    property['Type'] = 'Observed'
    if self.Type == 2 then
        property['Type'] = 'NetBots'
    elseif self.Type == 3 then
        property['Type'] = 'Spawn'
    end
    if self.DependsOnName ~= '' then
        property['DependsOnName'] = self.DependsOnName
    end
    if self.DependsOnValue ~= '' then
        property['DependsOnValue'] = self.DependsOnValue
    end
    if self.FromIDProperty ~= '' then
        property['FromIDProperty'] = self.FromIDProperty
    end
    return property
end

function PropertyInput:fromProperty(property)
    local o = PropertyInput()
    o.Name = property.Name
    if property['Type'] == 'Observed' then
        o.Type = 1
        o.DependsOnName = property['DependsOnName'] or ''
        o.DependsOnValue = property['DependsOnValue'] or ''
    elseif property['Type'] == 'Spawn' then
        o.Type = 3
        o.FromIDProperty = property['FromIDProperty'] or ''
    else
        o.Type = 2
    end
    return o
end

local ColumnInput = bh.class(Input(), function(c)
    c.Type=1
    c.Properties={[1]={[1]='',[2]=''}}
    c.PropertyCount=1
    c.Mappings={}
    c.MappingCount=0
    c.Thresholds={}
    c.ThresholdCount=0
    c.Percentage=false
    c.Ascending=true
    c.InZone=true
    c.Action=''
end)

function ColumnInput:toColumn()
    local column = bh.Column({Name=self.Name,Type='property'})
    if self.Type == 1 then
        column['Ascending']=self.Ascending
        column['InZone']=self.InZone
        column['Percentage']=self.Percentage
        column['Properties']={}
        for i,j in ipairs(self.Properties) do
            column['Properties'][j[1]] = j[2]
        end
        if self.MappingCount > 0 then
            column['Mappings']={}
        end
        for i,j in ipairs(self.Mappings) do
            column['Mappings'][j[1]] = j[2]
        end
        if self.ThresholdCount > 0 then
            column['Thresholds']={}
        end
        for i,j in ipairs(self.Thresholds) do
            column['Thresholds'][i] = tonumber(j)
        end
    elseif self.Type == 2 then
        column['Type'] = 'button'
        column['Action'] = self.Action
    end
    return column
end

function ColumnInput:fromColumn(column)
    local o = ColumnInput()
    o.Name = column['Name']
    if column['Type'] == 'property' then
        o.Type = 1
        o.Ascending = column['Ascending']
        o.InZone = column['InZone']
        o.Percentage = column['Percentage']
        o.PropertyCount = 0
        o.Properties = {}
        if column['Properties'] then
            for propKey,propValue in pairs(column['Properties']) do
                o.PropertyCount = o.PropertyCount + 1
                o.Properties[o.PropertyCount] = {[1]=propKey,[2]=propValue}
            end
        end
        o.MappingCount = 0
        o.Mappings = {}
        if column['Mappings'] then
            for mappingKey,mappingValue in pairs(column['Mappings']) do
                o.MappingCount = o.MappingCount + 1
                o.Mappings[o.MappingCount] = {[1]=mappingKey,[2]=mappingValue}
            end
        end
        o.ThresholdCount = 0
        o.Thresholds = {}
        if column['Thresholds'] then
            for thresholdIdx,thresholdValue in ipairs(column['Thresholds']) do
                o.ThresholdCount = o.ThresholdCount + 1
                o.Thresholds[thresholdIdx] = tostring(thresholdValue)
            end
        end
    else
        o.Type = 2
        o.Action = column['Action']
    end
    return o
end

local TabInput = bh.class(Input(), function(t)
    t.Columns = {[1]='Name'}
    t.ColumnCount = 1
end)

function TabInput:toTab()
    local tab = bh.Tab({})
    tab.Name = self.Name
    tab.Columns = {}
    for idx,column in ipairs(self.Columns) do
        tab.Columns[idx] = column
    end
    return tab
end

function TabInput:fromTab(tab)
    local o = TabInput()
    o.Name = tab['Name']
    o.Columns = {}
    for idx,column in ipairs(tab.Columns) do
        o.Columns[idx] = column
    end
    o.ColumnCount = #tab['Columns']
    return o
end

local WindowInput = bh.class(Input(), function(w)
    w.PeerGroup = ''
    w.Tabs = {}
    w.TabCount = 0
end)

function WindowInput:toWindow()
    local window  = bh.Window({})
    window.Name = self.Name
    window.PeerGroup = self.PeerGroup
    window.Tabs = {}
    for idx,tab in ipairs(self.Tabs) do
        window.Tabs[idx] = tab
    end
    return window
end

function WindowInput:fromWindow(window)
    local o = WindowInput()
    o.Name = window.Name
    o.PeerGroup = window.PeerGroup
    for idx,tab in ipairs(window.Tabs) do
        o.Tabs[idx] = tab
    end
    o.TabCount = #window['Tabs']
    return o
end

local function HelpMarker(desc)
    ImGui.TextDisabled('(?)')
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
        ImGui.Text(desc)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

local function DrawLabelAndTextInput(textLabel, inputLabel, resultVar, helpText)
    ImGui.Text(textLabel)
    ImGui.SameLine()
    HelpMarker(helpText)
    resultVar,_ = ImGui.InputText(inputLabel, resultVar, ImGuiInputTextFlags.EnterReturnsTrue)
    return resultVar
end

local function DrawLabelAndTextValue(label, value)
    ImGui.Text(label)
    ImGui.SameLine()
    ImGui.TextColored(0, 1, 0, 1, tostring(value))
end

local function DrawComboBox(label, resultvar, options, bykey)
    if ImGui.BeginCombo(label, resultvar) then
        for i,j in pairs(options) do
            if bykey then
                if ImGui.Selectable(i, i == resultvar) then
                    resultvar = i
                end
            else
                if ImGui.Selectable(j, j == resultvar) then
                    resultvar = j
                end
            end
        end
        ImGui.EndCombo()
    end
    return resultvar
end

local function DrawCheckBox(labelText, idText, resultVar, helpText)
    ImGui.Text(labelText)
    ImGui.SameLine()
    HelpMarker(helpText)
    resultVar,_ = ImGui.Checkbox(idText, resultVar)
    return resultVar
end

local function DrawColorEditor(label, resultVar)
    local col, used = ImGui.ColorEdit3(label, resultVar, ImGuiColorEditFlags.NoInputs)
    if col then
        resultVar = col
    end
    return resultVar
end

local function DrawReferenceText(label1, value1, label2, value2)
    ImGui.TextColored(0, 1, 1, 1, label1)
    ImGui.SameLine()
    ImGui.TextColored(0, 1, 0, 1, value1)
    if label2 then
        ImGui.SameLine()
        ImGui.TextColored(0, 1, 1, 1, label2)
        ImGui.SameLine()
        ImGui.TextColored(0, 1, 0, 1, value2)
    end
end

function ConfigurationPanel:drawGeneralSettingsSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
    self.selected = ImGui.Selectable('General Settings', self.selectedItemType == 'settings')
    ImGui.PopStyleColor(1)
    if self.selected then
        self:selectItem(nil, 'settings')
    end
end

function ConfigurationPanel:drawPropertiesTreeSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
    if ImGui.TreeNodeEx('Properties', ImGuiTreeNodeFlags.SpanFullWidth) then
        ImGui.PopStyleColor(1)
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        self.selected = ImGui.Selectable('Add new property...', self.selectedItemType == 'addnewproperty')
        if self.selected then
            if self.selectedItemType ~= 'addnewproperty' then
                self.newProperty = PropertyInput()
            end
            self:selectItem(nil, 'addnewproperty')
        end
        for propName, propSettings in pairs(bh.settings['Properties']) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            self.selected = ImGui.Selectable(propName, self.selectedItem == propName and self.selectedItemType == 'property')
            if self.selected then
                self:selectItem(propName, 'property')
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if self.selectedItemType == 'property' or self.selectedItemType == 'addnewproperty' then
            self:selectItem(nil, nil)
        end
    end
end

function ConfigurationPanel:drawColumnTreeSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
    if ImGui.TreeNodeEx('Columns', ImGuiTreeNodeFlags.SpanFullWidth) then
        ImGui.PopStyleColor(1)
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        self.selected = ImGui.Selectable('Add new column...', self.selectedItemType == 'addnewcolumn')
        if self.selected then
            if self.selectedItemType ~= 'addnewcolumn' then
                self.newColumn = ColumnInput()
            end
            self:selectItem(nil, 'addnewcolumn')
        end
        for columnName, columnSettings in pairs(bh.settings['Columns']) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            self.selected = ImGui.Selectable(columnName, self.selectedItem == columnName and self.selectedItemType == 'column')
            if self.selected then
                self:selectItem(columnName, 'column')
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if self.selectedItemType == 'column' or self.selectedItemType == 'addnewcolumn' then
            self:selectItem(nil, nil)
        end
    end
end

function ConfigurationPanel:drawTabTreeSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
    if ImGui.TreeNodeEx('Tabs', ImGuiTreeNodeFlags.SpanFullWidth) then
        ImGui.PopStyleColor(1)
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        self.selected = ImGui.Selectable('Add new tab...', self.selectedItemType == 'addnewtab')
        if self.selected then
            if self.selectedItemType ~= 'addnewtab' then
                self.newTab = TabInput()
            end
            self:selectItem(nil, 'addnewtab')
        end
        for tabIdx, tab in pairs(bh.settings['Tabs']) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            self.selected = ImGui.Selectable(tab['Name'], self.selectedItem == tabIdx and self.selectedItemType == 'tab')
            if self.selected then
                self:selectItem(tabIdx, 'tab')
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if self.selectedItemType == 'tab' or self.selectedItemType == 'addnewtab' then
            self:selectItem(nil, nil)
        end
    end
end

function ConfigurationPanel:drawWindowTreeSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
    if ImGui.TreeNodeEx('Windows', ImGuiTreeNodeFlags.SpanFullWidth) then
        ImGui.PopStyleColor(1)
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        self.selected = ImGui.Selectable('Add new window...', self.selectedItemType == 'addnewwindow')
        if self.selected then
            if self.selectedItemType ~= 'addnewwindow' then
                self.newWindow = WindowInput()
            end
            self:selectItem(nil, 'addnewwindow')
        end
        for windowName, window in pairs(bh.settings['Windows']) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            self.selected = ImGui.Selectable(windowName, self.selectedItem == windowName and self.selectedItemType == 'window')
            if self.selected then
                self:selectItem(windowName, 'window')
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if self.selectedItemType == 'window' or self.selectedItemType == 'addnewwindow' then
            self:selectItem(nil, nil)
        end
    end
end

function ConfigurationPanel:drawAboutSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
    self.selected = ImGui.Selectable('About', self.selectedItemType == 'about')
    ImGui.PopStyleColor(1)
    if self.selected then
        self:selectItem(nil, 'about')
    end
end

function ConfigurationPanel:drawLeftPaneWindow()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("left", 200, y-1, true) then
        local flags = bit32.bor(ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.ScrollY)
        if ImGui.BeginTable('##configmenu'..self.name, 1, flags, 0, 0, 0.0) then
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            self:drawGeneralSettingsSelector()
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            self:drawPropertiesTreeSelector()
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            self:drawColumnTreeSelector()
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            self:drawTabTreeSelector()
            if bh.peer_source == 'dannet' then
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                self:drawWindowTreeSelector()
            end
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            self:drawAboutSelector()
            
            ImGui.EndTable()
        end
        ImGui.EndChild()
    end
end

function PropertyInput:draw(width, configPanel)
    ImGui.TextColored(1, 0, 1, 1, "Add New Property")
    ImGui.Separator()
    ImGui.Text('Type: ')
    ImGui.SameLine()
    HelpMarker('The source of the property value.\n\'Observed\' will get the value using MQ2DanNet.\n\'NetBots\' will get the value using MQ2NetBots.\n\'Spawn\' will get the value from the Spawn TLO.')
    self.Type,_ = ImGui.RadioButton("Observed", self.Type, 1)
    ImGui.SameLine()
    self.Type,_ = ImGui.RadioButton("NetBots", self.Type, 2)
    ImGui.SameLine()
    self.Type,_ = ImGui.RadioButton("Spawn", self.Type, 3)
    
    self.Name = DrawLabelAndTextInput('Name(*): ', '##newpropname', self.Name, 'The data member this property should display. Examples:\nObserved: \'Me.PctHPs\'\nNetBots: \'PctHPs\'\nSpawn: \'Distance3D\'\n')

    if self.Type == 1 then
        self.DependsOnName = DrawLabelAndTextInput('DependsOnName: ', '##newpropdepname', self.DependsOnName, 'Optional. The name of another property which this property depends on. This property will be ignored for a character if the property it depends on doesn\'t have the desired value.')
        self.DependsOnValue = DrawLabelAndTextInput('DependsOnValue: ', '##newpropdepvalue', self.DependsOnValue, 'Optional. The value of another property which this property depends on. This property will be ignored for a character if the property it depends on doesn\'t have the desired value.')
    elseif self.Type == 3 then
        self.FromIDProperty = DrawLabelAndTextInput('FromIDProperty: ', '##newpropfromid', self.FromIDProperty, 'Optional. The name of another property to use as the ID in the Spawn search. The property MUST return a Spawn ID.')
    end
    ImGui.Separator()
    if ImGui.Button('Save##newprop'..configPanel.name) then
        local property = self:toProperty()
        local ok = false
        ok, self.message = property:validate()
        if ok then
            bh.settings['Properties'][self.Name] = property
            bh.SaveSettings()
            configPanel:clearSelection()
        else
            self.valid = false
        end
    end
    if not self.valid then
        ImGui.SameLine()
        ImGui.PushTextWrapPos(width-10)
        ImGui.TextColored(1, 0, 0, 1, string.format('Invalid input! %s', self.message))
        ImGui.PopTextWrapPos()
    end
end

function bh.Property:references(draw)
    local refFound = false
    for columnName,column in pairs(bh.settings['Columns']) do
        if column['Properties'] then
            for propKey,propValue in pairs(column['Properties']) do
                if propValue == self.Name then
                    refFound = true
                    if draw then
                        DrawReferenceText('Column: ', columnName, ' Property Key: ', propKey)
                    end
                end
            end
        end
    end
    for propNameIter,property in pairs(bh.settings['Properties']) do
        if property['DependsOnName'] == self.Name then
            refFound = true
            if draw then
                DrawReferenceText('Property: ', propNameIter, ' DependsOnName: ', self.Name)
            end
        elseif property['FromIDProperty'] == self.Name then
            refFound = true
            if draw then
                DrawReferenceText('Property: ', propNameIter, ' FromIDProperty: ', self.Name)
            end
        end
    end
    return refFound
end

function bh.Property:draw(configPanel)
    ImGui.TextColored(1, 0, 1, 1, self.Name)
    ImGui.Separator()
    if self.Name ~= 'Me.Class.ShortName' then
        if ImGui.SmallButton('Edit##'..self.Name) then
            configPanel.newProperty = PropertyInput:fromProperty(self)
            configPanel:selectItem(nil, 'addnewproperty')
        end
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..self.Name) then
            if not self:references(false) then
                bh.settings['Properties'][self.Name] = nil
                bh.SaveSettings()
                configPanel:clearSelection()
            end
        end
    end
    DrawLabelAndTextValue('Type: ', self.Type)
    if self.DependsOnName then
        DrawLabelAndTextValue('DependsOnName: ', self.DependsOnName)
    end
    if self.DependsOnValue then
        DrawLabelAndTextValue('DependsOnValue: ', self.DependsOnValue)
    end
    if self.FromIDProperty then
        DrawLabelAndTextValue('FromIDProperty: ', self.FromIDProperty)
    end
    ImGui.Separator()
    ImGui.Text('References:')
    ImGui.Indent(10)
    self:references(true)
    ImGui.Indent(-10)
end

function ColumnInput:draw(width, configPanel)
    ImGui.TextColored(1, 0, 1, 1, "Add New Column")
    ImGui.Separator()
    ImGui.Text('Type: ')
    ImGui.SameLine()
    HelpMarker('Choose whether the column will display property values or buttons.')
    self.Type,_ = ImGui.RadioButton("Property", self.Type, 1)
    ImGui.SameLine()
    self.Type,_ = ImGui.RadioButton("Button", self.Type, 2)

    self.Name = DrawLabelAndTextInput('Name(*): ', '##newcolumnname', self.Name, 'The name of the column which will appear in the table column header.')

    if self.Type == 1 then
        ImGui.Text('Properties(*): ')
        ImGui.SameLine()
        HelpMarker('The property values which will be displayed in this column. The column can display different properties for different classes.')
        for propIdx, propName in ipairs(self.Properties) do
            if self.Properties[propIdx] ~= nil then
                ImGui.PushItemWidth(80)
                self.Properties[propIdx][1] = DrawComboBox("##colpropcombo1"..propIdx, self.Properties[propIdx][1], classes, false)
                ImGui.PopItemWidth()
                ImGui.SameLine()
                ImGui.PushItemWidth(160)
                self.Properties[propIdx][2] = DrawComboBox("##colpropcombo2"..propIdx, self.Properties[propIdx][2], bh.settings['Properties'], true)
                ImGui.PopItemWidth()
                ImGui.SameLine()
                if ImGui.Button('X##deleteRow'..propIdx) then
                    local propIter = propIdx
                    for prop = propIdx+1, #self.Properties do
                        self.Properties[propIter] = self.Properties[prop]
                        propIter = propIter+1
                    end
                    self.Properties[propIter] = nil
                    self.PropertyCount = self.PropertyCount - 1
                end
            end
        end
        if ImGui.Button('+##properties') then
            self.PropertyCount = self.PropertyCount + 1
            self.Properties[self.PropertyCount] = {[1]='',[2]=''}
        end
        
        ImGui.Text('Mappings: ')
        ImGui.SameLine()
        HelpMarker('Optional. Define mappings from raw property values to values that should be displayed.\nExample: Map \'TRUE\' to \'Paused\' for \'Macro.Paused\'.')
        for mappingIdx, mappingName in ipairs(self.Mappings) do
            if self.Mappings[mappingIdx] ~= nil then
                ImGui.PushItemWidth(100)
                self.Mappings[mappingIdx][1], configPanel.selected = ImGui.InputText('##newcolmappings1-'..tostring(mappingIdx), self.Mappings[mappingIdx][1], ImGuiInputTextFlags.EnterReturnsTrue)
                ImGui.SameLine()
                self.Mappings[mappingIdx][2], configPanel.selected = ImGui.InputText('##newcolmappings2-'..tostring(mappingIdx), self.Mappings[mappingIdx][2], ImGuiInputTextFlags.EnterReturnsTrue)
                ImGui.SameLine()
                if ImGui.Button('X##deleteMappingRow'..mappingIdx) then
                    local mappingIter = mappingIdx
                    for mapping = mappingIdx+1, #self.Mappings do
                        self.Mappings[mappingIter] = self.Mappings[mapping]
                        mappingIter = mappingIter+1
                    end
                    self.Mappings[mappingIter] = nil
                    self.MappingCount = self.MappingCount - 1
                end
                ImGui.PopItemWidth()
            end
        end
        if ImGui.Button('+##mappings') then
            self.MappingCount = self.MappingCount + 1
            self.Mappings[self.MappingCount] = {[1]='',[2]=''}
        end

        ImGui.Text('Thresholds: ')
        ImGui.SameLine()
        HelpMarker('Optional. Set up to (2) numbers, in increasing order, for column text color thresholds.\nExample: Set Me.PctHPs thresholds to 35, 70 so that values below 35 will be red, between 35-70 will be yellow, and above 70 will be green.')
        for thresholdIdx, thresholdValue in ipairs(self.Thresholds) do
            if self.Thresholds[thresholdIdx] ~= nil then
                ImGui.PushItemWidth(80)
                self.Thresholds[thresholdIdx], configPanel.selected = ImGui.InputText('##newcolthresholds'..tostring(thresholdIdx), self.Thresholds[thresholdIdx], ImGuiInputTextFlags.EnterReturnsTrue)
                ImGui.PopItemWidth()
                ImGui.SameLine()
                if ImGui.Button('X##deleteThresholdRow'..thresholdIdx) then
                    local thresholdIter = thresholdIdx
                    for threshold = thresholdIdx+1, #self.Thresholds do
                        self.Thresholds[thresholdIter] = self.Thresholds[threshold]
                        thresholdIter = thresholdIter+1
                    end
                    self.Thresholds[thresholdIter] = nil
                    self.ThresholdCount = self.ThresholdCount - 1
                end
            end
        end
        if self.ThresholdCount < 2 then
            if ImGui.Button('+##thresholds') then
                self.ThresholdCount = self.ThresholdCount + 1
                self.Thresholds[self.ThresholdCount] = ''
            end
        end

        self.Percentage = DrawCheckBox('Percentage: ', '##newcolumnpercent', self.Percentage, 'Check this box if the values displayed in this column are percents.')
        self.Ascending = DrawCheckBox('Ascending: ', '##newcolumnascending', self.Ascending, 'Check this box if higher values are \'better\', i.e. 100%% HP is better than 10%%.')
        self.InZone = DrawCheckBox('InZone: ', '##newcolumninzone', self.InZone, 'Check this box if this column should only display values for characters in the same zone.')
    elseif self.Type == 2 then
        self.Action = DrawLabelAndTextInput('Action(*): ', '##newcolumnaction', self.Action, 'The action to take on left click. The string \'#botName#\' will be replaced with the character name from the row of the button.\nExample: \'/dex #botName# /mqp\'')
    end
    ImGui.Separator()
    if ImGui.Button('Save##newcolumn'..configPanel.name) then
        local column = self:toColumn()
        ok, self.message = column:validate()
        if ok then
            bh.settings['Columns'][self.Name] = column
            bh.SaveSettings()
            configPanel:clearSelection()
        else
            self.valid = false
        end
    end
    if not self.valid then
        ImGui.SameLine()
        ImGui.PushTextWrapPos(width-10)
        ImGui.TextColored(1, 0, 0, 1, string.format('Invalid input! %s', self.message))
        ImGui.PopTextWrapPos()
    end
end

function bh.Column:references(draw)
    local refFound = false
    for _,tab in pairs(bh.settings['Tabs']) do
        if tab['Columns'] then
            for _,columnNameIter in pairs(tab['Columns']) do
                if self.Name == columnNameIter then
                    refFound = true
                    if draw then
                        DrawReferenceText('Tab: ', tab['Name'], nil, nil)
                    end
                end
            end
        end
    end
    return refFound
end

function bh.Column:draw(configPanel)
    ImGui.TextColored(1, 0, 1, 1, self.Name)
    ImGui.Separator()
    if self.Name ~= 'Name' then
        if ImGui.SmallButton('Edit##'..self.Name) then
            configPanel.newColumn = ColumnInput:fromColumn(self)
            configPanel:selectItem(nil, 'addnewcolumn')
        end
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..self.Name) then
            if not self:references(false) then
                bh.settings['Columns'][self.Name] = nil
                bh.SaveSettings()
                configPanel:clearSelection()
            end
        end
    end
    DrawLabelAndTextValue('Type: ', self.Type)
    
    if self.Type == 'property' then
        ImGui.Text('Properties: ')
        if self.Properties then
            ImGui.Indent(10)
            for i,j in pairs(self.Properties) do
                ImGui.TextColored(0, 1, 1, 1, i..': ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, j)
            end
            ImGui.Indent(-10)
        end
        ImGui.Text('Thresholds: ')
        if self.Thresholds then
            ImGui.Indent(10)
            for i,j in ipairs(self.Thresholds) do
                ImGui.TextColored(0, 1, 1, 1, tostring(i)..': ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, tostring(j))
            end
            ImGui.Indent(-10)
        else
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, 'None')
        end
        ImGui.Text('Mappings: ')
        if self.Mappings then
            ImGui.Indent(10)
            for i,j in pairs(self.Mappings) do
                ImGui.TextColored(0, 1, 1, 1, i..': ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, j)
            end
            ImGui.Indent(-10)
        else
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, 'None')
        end
        if self.Percentage then
            DrawLabelAndTextValue('Percentage: ', tostring(self.Percentage))
        end
        if self.Ascending then
            DrawLabelAndTextValue('Ascending: ', tostring(self.Ascending))
        end
        if self.InZone then
            DrawLabelAndTextValue('InZone: ', tostring(self.InZone))
        end
    elseif self.Type == 'button' then
        if self.Action then
            DrawLabelAndTextValue('Action: ', self.Action)
        end
    end
    ImGui.Separator()
    ImGui.Text('References:')
    ImGui.Indent(10)
    self:references(true)
    ImGui.Indent(-10)
end

function TabInput:draw(width, configPanel)
    ImGui.TextColored(1, 0, 1, 1, "Add New Tab")
    ImGui.Separator()
    self.Name = DrawLabelAndTextInput('Name(*): ', '##newtabname', self.Name, 'The name of the tab which will be displayed in the Tab bar.')
    ImGui.Text('Columns: ')
    ImGui.SameLine()
    HelpMarker('The list of columns which will be displayed in the tab.')
    for columnIdx, columnName in ipairs(self.Columns) do
        if self.Columns[columnIdx] ~= nil then
            self.Columns[columnIdx] = DrawComboBox("##columncombo"..columnIdx, self.Columns[columnIdx], bh.settings['Columns'], true)
            ImGui.SameLine()
            if ImGui.Button('X##deleteRow'..columnIdx) then
                local columnIter = columnIdx
                for columns = columnIdx+1, #self.Columns do
                    self.Columns[columnIter] = self.Columns[columns]
                    columnIter = columnIter+1
                end
                self.Columns[columnIter] = nil
                self.ColumnCount = self.ColumnCount - 1
            end
        end
    end
    if ImGui.Button('+') then
        self.ColumnCount = self.ColumnCount + 1
        self.Columns[self.ColumnCount] = ''
    end
    ImGui.Separator()
    if ImGui.Button('Save##newtab'..configPanel.name) then
        local ok = false
        local tab = self:toTab()
        ok, self.message = tab:validate()
        if ok then
            local foundExisting = false
            for tabIdx,existingTab in ipairs(bh.settings['Tabs']) do
                if existingTab['Name'] == self.Name then
                    -- replace existing tab
                    existingTab['Columns'] = self.Columns
                    foundExisting = true
                end
            end
            if not foundExisting then
                table.insert(bh.settings['Tabs'], tab)
            end
            bh.SaveSettings()
            configPanel:clearSelection()
        else
            self.valid = false
        end
    end
    if not self.valid then
        ImGui.SameLine()
        ImGui.PushTextWrapPos(width-10)
        ImGui.TextColored(1, 0, 0, 1, string.format('Invalid input! %s', self.message))
        ImGui.PopTextWrapPos()
    end
end

function bh.Tab:references(draw)
    local refFound = false
    for _,window in pairs(bh.settings['Windows']) do
        if window['Tabs'] then
            for _,tabNameIter in pairs(window['Tabs']) do
                if self.Name == tabNameIter then
                    refFound = true
                    if draw then
                        DrawReferenceText('Window: ', window['Name'], nil, nil)
                    end
                end
            end
        end
    end
    return refFound
end

function bh.Tab:draw(configPanel)
    ImGui.TextColored(1, 0, 1, 1, self.Name)
    ImGui.Separator()
    if ImGui.SmallButton('Edit##'..self.Name) then
        configPanel.newTab = TabInput:fromTab(self)
        configPanel:selectItem(nil, 'addnewtab')
    end
    ImGui.SameLine()
    if ImGui.SmallButton('Delete##'..self.Name) then
        if not self:references(false) then
            local tabIter = configPanel.selectedItem
            for tabIdx = tabIter+1, #bh.settings['Tabs'] do
                bh.settings['Tabs'][tabIter] = bh.settings['Tabs'][tabIdx]
                tabIter = tabIter+1
            end
            bh.settings['Tabs'][tabIter] = nil
            bh.SaveSettings()
            configPanel:clearSelection()
        end
    end
    ImGui.Text('Columns:')
    if self.Columns then
        for columnIdx,column in ipairs(self.Columns) do
            ImGui.Text(string.format('%d: ', columnIdx))
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, column)
        end
    end
    ImGui.Separator()
    ImGui.Text('References:')
    ImGui.Indent(10)
    self:references(true)
    ImGui.Indent(-10)
end

function WindowInput:draw(width, configPanel)
    ImGui.TextColored(1, 0, 1, 1, "Add New Window")
    ImGui.Separator()
    self.Name = DrawLabelAndTextInput('Name(*): ', '##newwindowname', self.Name, 'The name of the window to be added.')
    self.PeerGroup = DrawLabelAndTextInput('PeerGroup(*): ', '##newwindowpg', self.PeerGroup, 'The DanNet Peer Group the new window should use.')

    ImGui.Text('Tabs: ')
    ImGui.SameLine()
    HelpMarker('The list of tabs which will be displayed in the window.')
    for tabIdx, tabName in ipairs(self.Tabs) do
        if self.Tabs[tabIdx] ~= nil then
            local tabNameList = {}
            for _,tab in ipairs(bh.settings['Tabs']) do
                table.insert(tabNameList, tab['Name'])
            end
            self.Tabs[tabIdx] = DrawComboBox("##tabcombo"..tabIdx, self.Tabs[tabIdx], tabNameList, false)
            ImGui.SameLine()
            if ImGui.Button('X##deleteRow'..tabIdx) then
                local tabIter = tabIdx
                for tabs = tabIdx+1, #self.Tabs do
                    self.Tabs[tabIter] = self.Tabs[tabs]
                    tabIter = tabIter+1
                end
                self.Tabs[tabIter] = nil
                self.TabCount = self.TabCount - 1
            end
        end
    end
    if ImGui.Button('+') then
        self.TabCount = self.TabCount + 1
        self.Tabs[self.TabCount] = ''
    end

    ImGui.Separator()
    if ImGui.Button('Save##newwindow'..configPanel.name) then
        local ok = false
        local window = self:toWindow()
        ok, self.message = window:validate()
        if ok then
            bh.settings['Windows'][self.Name] = window
            bh.SaveSettings()
            configPanel:clearSelection()
        else
            self.valid = false
        end
    end
    if not self.valid then
        ImGui.SameLine()
        ImGui.PushTextWrapPos(width-10)
        ImGui.TextColored(1, 0, 0, 1, string.format('Invalid input! %s', self.message))
        ImGui.PopTextWrapPos()
    end
end

function bh.Window:draw(configPanel)
    ImGui.TextColored(1, 0, 1, 1, self.Name)
    ImGui.Separator()
    if ImGui.SmallButton('Edit##'..self.Name) then
        configPanel.newWindow = WindowInput:fromWindow(self)
        configPanel:selectItem(nil, 'addnewwindow')
    end
    if bh.TableLength(bh.settings['Windows']) > 1 then
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..self.Name) then
            bh.settings['Windows'][self.Name] = nil
            bh.SaveSettings()
            configPanel:clearSelection()
        end
    end
    DrawLabelAndTextValue('Peer Group: ', self.PeerGroup)
    ImGui.Text('Tabs:')
    if self.Tabs then
        for tabIdx,tab in ipairs(self.Tabs) do
            ImGui.Text(string.format('%d: ', tabIdx))
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, tab)
        end
    end
end

function ConfigurationPanel:drawGeneralSettings()
    ImGui.TextColored(1, 0, 1, 1, 'General Settings')
    ImGui.Separator()
    DrawLabelAndTextValue('Peer Source: ', bh.settings['PeerSource'])
    DrawLabelAndTextValue('DanNet Peer Group: ', bh.settings['DanNetPeerGroup'])
    DrawLabelAndTextValue('Refresh Interval: ', bh.refresh_interval)
    DrawLabelAndTextValue('Stale Data Timeout: ', bh.stale_data_timeout)
    ImGui.Separator()
    bh.settings.Windows[self.name].Transparency = DrawCheckBox('Transparent Window: ', '##transparency', bh.settings.Windows[self.name].Transparency, 'Check this box to toggle transparency of the window.')
    ImGui.Separator()
    ImGui.Text('Column Text Colors:')
    bh.settings['Colors']['Default'] = DrawColorEditor("Default Color", bh.settings['Colors']['Default'])
    bh.settings['Colors']['Low'] = DrawColorEditor("Below Threshold", bh.settings['Colors']['Low'])
    bh.settings['Colors']['Medium'] = DrawColorEditor("Medium Threshold", bh.settings['Colors']['Medium'])
    bh.settings['Colors']['High'] = DrawColorEditor("Above Threshold", bh.settings['Colors']['High'])
    bh.settings['Colors']['True'] = DrawColorEditor("True values", bh.settings['Colors']['True'])
    bh.settings['Colors']['False'] = DrawColorEditor("False values", bh.settings['Colors']['False'])
    bh.settings['Colors']['InZone'] = DrawColorEditor("Character names in zone", bh.settings['Colors']['InZone'])
    bh.settings['Colors']['Invis'] = DrawColorEditor("Invis characters in zone", bh.settings['Colors']['Invis'])
    bh.settings['Colors']['NotInZone'] = DrawColorEditor("Characters not in zone", bh.settings['Colors']['NotInZone'])
    ImGui.Separator()
    if ImGui.Button('Save##general') then
        bh.SaveSettings()
        self:clearSelection()
    end
end

function ConfigurationPanel:drawAbout()
    ImGui.TextColored(1, 0, 1, 1, 'About')
    ImGui.Separator()
    DrawLabelAndTextValue('Version: ', bh.version)
end

function ConfigurationPanel:drawInfo(width)
    ImGui.PushTextWrapPos(width-17)
    ImGui.Text('To get started with configuring boxhud, select an item from the menu on the left.')
    ImGui.Text('Properties define the data members which will be either observed with MQ2DanNet, read from MQ2NetBots or read from Spawn data.')
    ImGui.Text('Columns define how specific properties should be displayed.')
    ImGui.Text('Tabs define groupings of columns and will appear in the top tab bar.')
    ImGui.Text('Windows define separate instances of the boxhud window to be displayed for different peer groups. (MQ2DanNet only)')
    ImGui.PopTextWrapPos()
end

function ConfigurationPanel:drawRightPaneWindow()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("right", x, y-1, true) then
        if self.selectedItemType == 'settings' then
            self:drawGeneralSettings()
        elseif self.selectedItemType == 'addnewproperty' then
            self.newProperty:draw(x, self)
        elseif self.selectedItemType == 'addnewcolumn' then
            self.newColumn:draw(x, self)
        elseif self.selectedItemType == 'addnewtab' then
            self.newTab:draw(x, self)
        elseif self.selectedItemType == 'addnewwindow' then
            self.newWindow:draw(x, self)
        elseif self.selectedItemType == 'property' then
            local property = bh.settings['Properties'][self.selectedItem]
            if property then
                property:draw(self)
            end
        elseif self.selectedItemType == 'column' then
            local column = bh.settings['Columns'][self.selectedItem]
            if column ~= nil then
                column:draw(self)
            end
        elseif self.selectedItemType == 'tab' then
            local tab = bh.settings['Tabs'][self.selectedItem]
            if tab then
                tab:draw(self)
            end
        elseif self.selectedItemType == 'window' then
            local window = bh.settings['Windows'][self.selectedItem]
            if window then
                window:draw(self)
            end
        elseif self.selectedItemType == 'about' then
            self:drawAbout()
        else
            self:drawInfo(x)
        end
        ImGui.EndChild()
    end
end

function ConfigurationPanel:draw()
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 6, 6)
    self:drawLeftPaneWindow()
    ImGui.SameLine()
    self:drawRightPaneWindow()
    ImGui.PopStyleVar()
end

return ConfigurationPanel