-- boxhud/configpanel.lua 2.0.5 -- aquietone
--- @type ImGui
require 'ImGui'
require('boxhud.utils')

local newProperty = nil
local newColumn = nil
local newTab = nil

local classes = {'all', 'melee', 'caster', 'hybrids', 'ranged', 'ber', 'brd', 
        'bst', 'clr', 'dru', 'enc', 'mag', 'mnk', 'nec', 'pal', 'shd', 'rng', 
        'rog', 'shm', 'war', 'wiz'}

ConfigurationState = class(function(c)
    c.dirty = false
    c.selected = false
    c.selectedItem = nil
    c.selectedItemType = nil
end)

function ConfigurationState:setDirtyAndClearSelection()
    self.dirty = true
    self.selected = false
    self.selectedItem = nil
    self.selectedItemType = nil
end

function ConfigurationState:selectItem(item, itemType)
    self.selectedItem = item
    self.selectedItemType = itemType
end

ConfigUI = ConfigurationState()

Input = class(function(i)
    i.Name=''
    i.valid=true
    i.message=nil
    i.shouldDrawCombo = false
end)

PropertyInput = class(Input(), function(p)
    p.Type=1
    p.DependsOnName=''
    p.DependsOnValue=''
    p.FromIDProperty=''
end)

function PropertyInput:toProperty()
    local property = Property({})
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

ColumnInput = class(Input(), function(c)
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
    local column = Column({Name=self.Name,Type='property'})
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

TabInput = class(Input(), function(t)
    t.Columns = {[1]='Name'}
    t.ColumnCount = 1
end)

function TabInput:toTab()
    local tab = Tab({})
    tab.Name = self.Name
    tab.Columns = {}
    for idx,column in ipairs(self.Columns) do
        tab.Columns[idx] = column
    end
    tab.Columns = self.Columns
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

local function DrawGeneralSettingsSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 1, 1)
    ConfigUI.selected = ImGui.Selectable('General Settings', ConfigUI.selectedItemType == 'settings')
    ImGui.PopStyleColor(1)
    if ConfigUI.selected then
        ConfigUI:selectItem(nil, 'settings')
    end
end

local function DrawPropertiesTreeSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 1, 1)
    if ImGui.TreeNodeEx('Properties', ImGuiTreeNodeFlags.SpanFullWidth) then
        ImGui.PopStyleColor(1)
        ImGui.Indent(8)
        ConfigUI.selected = ImGui.Selectable('Add new property...', ConfigUI.selectedItemType == 'addnewproperty')
        if ConfigUI.selected then
            if ConfigUI.selectedItemType ~= 'addnewproperty' then
                newProperty = PropertyInput()
            end
            ConfigUI:selectItem(nil, 'addnewproperty')
        end
        for propName, propSettings in pairs(SETTINGS['Properties']) do
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            ConfigUI.selected = ImGui.Selectable(propName, ConfigUI.selectedItem == propName and ConfigUI.selectedItemType == 'property')
            if ConfigUI.selected then
                ConfigUI:selectItem(propName, 'property')
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.Indent(-8)
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if ConfigUI.selectedItemType == 'property' or ConfigUI.selectedItemType == 'addnewproperty' then
            ConfigUI:selectItem(nil, nil)
        end
    end
end

local function DrawColumnTreeSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 1, 1)
    if ImGui.TreeNodeEx('Columns', ImGuiTreeNodeFlags.SpanFullWidth) then
        ImGui.PopStyleColor(1)
        ImGui.Indent(8)
        ConfigUI.selected = ImGui.Selectable('Add new column...', ConfigUI.selectedItemType == 'addnewcolumn')
        if ConfigUI.selected then
            if ConfigUI.selectedItemType ~= 'addnewcolumn' then
                newColumn = ColumnInput()
            end
            ConfigUI:selectItem(nil, 'addnewcolumn')
        end
        for columnName, columnSettings in pairs(SETTINGS['Columns']) do
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            ConfigUI.selected = ImGui.Selectable(columnName, ConfigUI.selectedItem == columnName and ConfigUI.selectedItemType == 'column')
            if ConfigUI.selected then
                ConfigUI:selectItem(columnName, 'column')
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.Indent(-8)
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if ConfigUI.selectedItemType == 'column' or ConfigUI.selectedItemType == 'addnewcolumn' then
            ConfigUI:selectItem(nil, nil)
        end
    end
end

local function DrawTabTreeSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 1, 1)
    if ImGui.TreeNodeEx('Tabs', ImGuiTreeNodeFlags.SpanFullWidth) then
        ImGui.PopStyleColor(1)
        ImGui.Indent(8)
        ConfigUI.selected = ImGui.Selectable('Add new tab...', ConfigUI.selectedItemType == 'addnewtab')
        if ConfigUI.selected then
            if ConfigUI.selectedItemType ~= 'addnewtab' then
                newTab = TabInput()
            end
            ConfigUI:selectItem(nil, 'addnewtab')
        end
        for tabIdx, tab in pairs(SETTINGS['Tabs']) do
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            ConfigUI.selected = ImGui.Selectable(tab['Name'], ConfigUI.selectedItem == tabIdx and ConfigUI.selectedItemType == 'tab')
            if ConfigUI.selected then
                ConfigUI:selectItem(tabIdx, 'tab')
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.Indent(-8)
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if ConfigUI.selectedItemType == 'tab' or ConfigUI.selectedItemType == 'addnewtab' then
            ConfigUI:selectItem(nil, nil)
        end
    end
end

local function DrawAboutSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 1, 1)
    ConfigUI.selected = ImGui.Selectable('About', ConfigUI.selectedItemType == 'about')
    ImGui.PopStyleColor(1)
    if ConfigUI.selected then
        ConfigUI:selectItem(nil, 'about')
    end
end

local function DrawSaveChangesSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 1, 1)
    ConfigUI.selected = ImGui.Selectable('Save Configuration', ConfigUI.selectedItemType == 'savechanges')
    ImGui.PopStyleColor(1)
    if ConfigUI.selected then
        ConfigUI:selectItem(nil, 'savechanges')
    end
end

local function LeftPaneWindow()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("left", 200, y-1, true) then
        DrawSaveChangesSelector()
        DrawGeneralSettingsSelector()
        ImGui.Indent(-24)
        DrawPropertiesTreeSelector()
        DrawColumnTreeSelector()
        DrawTabTreeSelector()
        ImGui.Indent(24)
        DrawAboutSelector()
        ImGui.EndChild()
    end
end

function PropertyInput:draw(width)
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
    
    ImGui.Text('Name(*): ')
    ImGui.SameLine()
    HelpMarker('The data member this property should display. Examples:\nObserved: \'Me.PctHPs\'\nNetBots: \'PctHPs\'\nSpawn: \'Distance3D\'\n')
    self.Name, ConfigUI.selected = ImGui.InputText('##newpropname', self.Name, ImGuiInputTextFlags.EnterReturnsTrue)

    if self.Type == 1 then
        ImGui.Text('DependsOnName: ')
        ImGui.SameLine()
        HelpMarker('Optional. The name of another property which this property depends on. This property will be ignored for a character if the property it depends on doesn\'t have the desired value.')
        self.DependsOnName, ConfigUI.selected = ImGui.InputText('##newpropdepname', self.DependsOnName, ImGuiInputTextFlags.EnterReturnsTrue)
        ImGui.Text('DependsOnValue: ')
        ImGui.SameLine()
        HelpMarker('Optional. The value of another property which this property depends on. This property will be ignored for a character if the property it depends on doesn\'t have the desired value.')
        self.DependsOnValue, ConfigUI.selected = ImGui.InputText('##newpropdepvalue', self.DependsOnValue, ImGuiInputTextFlags.EnterReturnsTrue)
    elseif self.Type == 3 then
        ImGui.Text('FromIDProperty: ')
        ImGui.SameLine()
        HelpMarker('Optional. The name of another property to use as the ID in the Spawn search. The property MUST return a Spawn ID.')
        self.FromIDProperty, ConfigUI.selected = ImGui.InputText('##newpropfromid', self.FromIDProperty, ImGuiInputTextFlags.EnterReturnsTrue)
    end
    ImGui.Separator()
    if ImGui.Button('Apply##newprop') then
        local property = self:toProperty()
        local ok = false
        ok, self.message = property:validate()
        if ok then
            SETTINGS['Properties'][self.Name] = property
            ConfigUI:setDirtyAndClearSelection()
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

function Property:references(draw)
    local refFound = false
    for columnName,column in pairs(SETTINGS['Columns']) do
        if column['Properties'] then
            for propKey,propValue in pairs(column['Properties']) do
                if propValue == self.Name then
                    refFound = true
                    if draw then
                        ImGui.TextColored(0, 1, 1, 1, 'Column: ')
                        ImGui.SameLine()
                        ImGui.TextColored(0, 1, 0, 1, columnName)
                        ImGui.SameLine()
                        ImGui.TextColored(0, 1, 1, 1, ' Property Key: ')
                        ImGui.SameLine()
                        ImGui.TextColored(0, 1, 0, 1, propKey)
                    end
                end
            end
        end
    end
    for propNameIter,property in pairs(SETTINGS['Properties']) do
        if property['DependsOnName'] == self.Name then
            refFound = true
            if draw then
                ImGui.TextColored(0, 1, 1, 1, 'Property: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, propNameIter)
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 1, 1, ' DependsOnName: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, self.Name)
            end
        elseif property['FromIDProperty'] == self.Name then
            refFound = true
            if draw then
                ImGui.TextColored(0, 1, 1, 1, 'Property: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, propNameIter)
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 1, 1, ' FromIDProperty: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, self.Name)
            end
        end
    end
    return refFound
end

function Property:draw()
    ImGui.TextColored(1, 0, 1, 1, self.Name)
    ImGui.Separator()
    if self.Name ~= 'Me.Class.ShortName' then
        if ImGui.SmallButton('Edit##'..self.Name) then
            newProperty = PropertyInput:fromProperty(self)
            ConfigUI:selectItem(nil, 'addnewproperty')
        end
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..self.Name) then
            if not self:references(false) then
                SETTINGS['Properties'][self.Name] = nil
                ConfigUI:setDirtyAndClearSelection()
            end
        end
    end
    ImGui.Text('Type: ')
    ImGui.SameLine()
    ImGui.TextColored(0, 1, 0, 1, self.Type)
    if self.DependsOnName then
        ImGui.Text('DependsOnName: ')
        ImGui.SameLine()
        ImGui.TextColored(0, 1, 0, 1, self.DependsOnName)
    end
    if self.DependsOnValue then
        ImGui.Text('DependsOnValue: ')
        ImGui.SameLine()
        ImGui.TextColored(0, 1, 0, 1, self.DependsOnValue)
    end
    if self.FromIDProperty then
        ImGui.Text('FromIDProperty: ')
        ImGui.SameLine()
        ImGui.TextColored(0, 1, 0, 1, self.FromIDProperty)
    end
    ImGui.Separator()
    ImGui.Text('References:')
    ImGui.Indent(10)
    self:references(true)
    ImGui.Indent(-10)
end

function ColumnInput:draw(width)
    ImGui.TextColored(1, 0, 1, 1, "Add New Column")
    ImGui.Separator()
    ImGui.Text('Type: ')
    ImGui.SameLine()
    HelpMarker('Choose whether the column will display property values or buttons.')
    self.Type,_ = ImGui.RadioButton("Property", self.Type, 1)
    ImGui.SameLine()
    self.Type,_ = ImGui.RadioButton("Button", self.Type, 2)

    ImGui.Text('Name(*): ')
    ImGui.SameLine()
    HelpMarker('The name of the column which will appear in the table column header.')
    self.Name, ConfigUI.selected = ImGui.InputText('##newcolumnname', self.Name, ImGuiInputTextFlags.EnterReturnsTrue)

    if self.Type == 1 then
        ImGui.Text('Properties(*): ')
        ImGui.SameLine()
        HelpMarker('The property values which will be displayed in this column. The column can display different properties for different classes.')
        for propIdx, propName in ipairs(self.Properties) do
            if self.Properties[propIdx] ~= nil then
                ImGui.PushItemWidth(80)
                self.shouldDrawCombo = ImGui.BeginCombo("##colpropcombo1"..propIdx, self.Properties[propIdx][1])
                if self.shouldDrawCombo then
                    for _,class in pairs(classes) do
                        ConfigUI.selected = ImGui.Selectable(class, self.Properties[propIdx][1] == class)
                        if ConfigUI.selected then
                            self.Properties[propIdx][1] = class
                        end
                    end
                    ImGui.EndCombo()
                end
                ImGui.PopItemWidth()
                ImGui.SameLine()
                ImGui.PushItemWidth(160)
                self.shouldDrawCombo = ImGui.BeginCombo("##colpropcombo2"..propIdx, self.Properties[propIdx][2])
                if self.shouldDrawCombo then
                    for cpropname,_ in pairs(SETTINGS['Properties']) do
                        ConfigUI.selected = ImGui.Selectable(cpropname, self.Properties[propIdx][2] == cpropname)
                        if ConfigUI.selected then
                            self.Properties[propIdx][2] = cpropname
                        end
                    end
                    ImGui.EndCombo()
                end
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
                self.Mappings[mappingIdx][1], ConfigUI.selected = ImGui.InputText('##newcolmappings1-'..tostring(mappingIdx), self.Mappings[mappingIdx][1], ImGuiInputTextFlags.EnterReturnsTrue)
                ImGui.SameLine()
                self.Mappings[mappingIdx][2], ConfigUI.selected = ImGui.InputText('##newcolmappings2-'..tostring(mappingIdx), self.Mappings[mappingIdx][2], ImGuiInputTextFlags.EnterReturnsTrue)
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
                self.Thresholds[thresholdIdx], ConfigUI.selected = ImGui.InputText('##newcolthresholds'..tostring(thresholdIdx), self.Thresholds[thresholdIdx], ImGuiInputTextFlags.EnterReturnsTrue)
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

        ImGui.Text('Percentage: ')
        ImGui.SameLine()
        HelpMarker('Check this box if the values displayed in this column are percents.')
        self.Percentage, pressed = ImGui.Checkbox('##newcolumnpercent', self.Percentage)
        ImGui.Text('Ascending: ')
        ImGui.SameLine()
        HelpMarker('Check this box if higher values are \'better\', i.e. 100%% HP is better than 10%%.')
        self.Ascending, pressed = ImGui.Checkbox('##newcolumnascending', self.Ascending)
        ImGui.Text('InZone: ')
        ImGui.SameLine()
        HelpMarker('Check this box if this column should only display values for characters in the same zone.')
        self.InZone, pressed = ImGui.Checkbox('##newcolumninzone', self.InZone)
    elseif self.Type == 2 then
        ImGui.Text('Action(*): ')
        ImGui.SameLine()
        HelpMarker('The action to take on left click. The string \'#botName#\' will be replaced with the character name from the row of the button.\nExample: \'/dex #botName# /mqp\'')
        self.Action, ConfigUI.selected = ImGui.InputText('##newcolumnaction', self.Action, ImGuiInputTextFlags.EnterReturnsTrue)
    end
    ImGui.Separator()
    if ImGui.Button('Apply##newcolumn') then
        local column = self:toColumn()
        ok, self.message = column:validate()
        if ok then
            SETTINGS['Columns'][self.Name] = column
            ConfigUI:setDirtyAndClearSelection()
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

function Column:references(draw)
    local refFound = false
    for _,tab in pairs(SETTINGS['Tabs']) do
        if tab['Columns'] then
            for _,columnNameIter in pairs(tab['Columns']) do
                if self.Name == columnNameIter then
                    refFound = true
                    if draw then
                        ImGui.TextColored(0, 1, 1, 1, 'Tab: ')
                        ImGui.SameLine()
                        ImGui.TextColored(0, 1, 0, 1, tab['Name'])
                    end
                end
            end
        end
    end
    return refFound
end

function Column:draw()
    ImGui.TextColored(1, 0, 1, 1, self.Name)
    ImGui.Separator()
    if self.Name ~= 'Name' then
        if ImGui.SmallButton('Edit##'..self.Name) then
            newColumn = ColumnInput:fromColumn(self)
            ConfigUI:selectItem(nil, 'addnewcolumn')
        end
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..self.Name) then
            if not self:references(false) then
                SETTINGS['Columns'][self.Name] = nil
                ConfigUI:setDirtyAndClearSelection()
            end
        end
    end
    ImGui.Text('Type: ')
    ImGui.SameLine()
    ImGui.TextColored(0, 1, 0, 1, self.Type)
    
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
            ImGui.Text('Percentage: ')
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, tostring(self.Percentage))
        end
        if self.Ascending then
            ImGui.Text('Ascending: ')
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, tostring(self.Ascending))
        end
        if self.InZone then
            ImGui.Text('InZone: ')
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, tostring(self.InZone))
        end
    elseif self.Type == 'button' then
        if self.Action then
            ImGui.Text('Action: ')
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, self.Action)
        end
    end
    ImGui.Separator()
    ImGui.Text('References:')
    ImGui.Indent(10)
    self:references(true)
    ImGui.Indent(-10)
end

function TabInput:draw(width)
    ImGui.TextColored(1, 0, 1, 1, "Add New Tab")
    ImGui.Separator()
    ImGui.Text('Name(*): ')
    ImGui.SameLine()
    HelpMarker('The name of the tab which will be displayed in the Tab bar.')
    self.Name, ConfigUI.selected = ImGui.InputText('##newtabname', self.Name, ImGuiInputTextFlags.EnterReturnsTrue)
    ImGui.Text('Columns: ')
    ImGui.SameLine()
    HelpMarker('The list of columns which will be displayed in the tab.')
    for columnIdx, columnName in ipairs(self.Columns) do
        if self.Columns[columnIdx] ~= nil then
            self.shouldDrawCombo = ImGui.BeginCombo("##columncombo"..columnIdx, self.Columns[columnIdx])
            if self.shouldDrawCombo then
                for column,_ in pairs(SETTINGS['Columns']) do
                    ConfigUI.selected = ImGui.Selectable(column, self.Columns[columnIdx] == column)
                    if ConfigUI.selected then
                        self.Columns[columnIdx] = column
                    end
                end
                ImGui.EndCombo()
            end
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
    if ImGui.Button('Apply##newtab') then
        local ok = false
        local tab = self:toTab()
        ok, self.message = tab:validate()
        if ok then
            local foundExisting = false
            for tabIdx,existingTab in ipairs(SETTINGS['Tabs']) do
                if existingTab['Name'] == self.Name then
                    -- replace existing tab
                    existingTab['Columns'] = self.Columns
                    foundExisting = true
                end
            end
            if not foundExisting then
                table.insert(SETTINGS['Tabs'], tab)
            end
            ConfigUI:setDirtyAndClearSelection()
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

function Tab:draw()
    ImGui.TextColored(1, 0, 1, 1, self.Name)
    ImGui.Separator()
    if ImGui.SmallButton('Edit##'..self.Name) then
        newTab = TabInput:fromTab(self)
        ConfigUI:selectItem(nil, 'addnewtab')
    end
    ImGui.SameLine()
    if ImGui.SmallButton('Delete##'..self.Name) then
        local tabIter = ConfigUI.selectedItem
        for tabIdx = tabIter+1, #SETTINGS['Tabs'] do
            SETTINGS['Tabs'][tabIter] = SETTINGS['Tabs'][tabIdx]
            tabIter = tabIter+1
        end
        SETTINGS['Tabs'][tabIter] = nil
        ConfigUI:setDirtyAndClearSelection()
    end
    ImGui.Text('Columns:')
    if self.Columns then
        for columnIdx,column in ipairs(self.Columns) do
            ImGui.Text(string.format('%d: ', columnIdx))
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, column)
        end
    end
end

local function DrawGeneralSettings()
    ImGui.TextColored(1, 0, 1, 1, 'General Settings')
    ImGui.Separator()
    ImGui.Text('Peer Source: ')
    ImGui.SameLine()
    ImGui.TextColored(0, 1, 0, 1, SETTINGS['PeerSource'])
    ImGui.Text('DanNet Peer Group: ')
    ImGui.SameLine()
    ImGui.TextColored(0, 1, 0, 1, SETTINGS['DanNetPeerGroup'])
    ImGui.Separator()
    ImGui.Text('Refresh Interval: ')
    ImGui.SameLine()
    ImGui.TextColored(0, 1, 0, 1, SETTINGS['RefreshInterval'])
    ImGui.Text('Stale Data Timeout: ')
    ImGui.SameLine()
    ImGui.TextColored(0, 1, 0, 1, SETTINGS['StaleDataTimeout'])
    ImGui.Separator()
    ImGui.Text('Column Text Colors:')
    local col, used = ImGui.ColorEdit3("Default Color", SETTINGS['Colors']['Default'], ImGuiColorEditFlags.NoInputs)
    if col then
        if col[1] ~= SETTINGS['Colors']['Default'][1] and col[2] ~= SETTINGS['Colors']['Default'][2] and col[3] ~= SETTINGS['Colors']['Default'][3] then
            SETTINGS['Colors']['Default'] = col
        end
    end
    col, used = ImGui.ColorEdit3("Low threshold color", SETTINGS['Colors']['Low'], ImGuiColorEditFlags.NoInputs)
    if col then
        SETTINGS['Colors']['Low'] = col
    end
    col, used = ImGui.ColorEdit3("Medium threshold color", SETTINGS['Colors']['Medium'], ImGuiColorEditFlags.NoInputs)
    if col then
        SETTINGS['Colors']['Medium'] = col
    end
    col, used = ImGui.ColorEdit3("High threshold color", SETTINGS['Colors']['High'], ImGuiColorEditFlags.NoInputs)
    if col then
        SETTINGS['Colors']['High'] = col
    end
    col, used = ImGui.ColorEdit3("Name in zone color", SETTINGS['Colors']['InZone'], ImGuiColorEditFlags.NoInputs)
    if col then
        SETTINGS['Colors']['InZone'] = col
    end
    col, used = ImGui.ColorEdit3("Name invis color", SETTINGS['Colors']['Invis'], ImGuiColorEditFlags.NoInputs)
    if col then
        SETTINGS['Colors']['Invis'] = col
    end
    col, used = ImGui.ColorEdit3("Name not in zone color", SETTINGS['Colors']['NotInZone'], ImGuiColorEditFlags.NoInputs)
    if col then
        SETTINGS['Colors']['NotInZone'] = col
    end
    ImGui.Separator()
    if ImGui.Button('Apply##general') then
        ConfigUI:setDirtyAndClearSelection()
    end
end

local function DrawAbout()
    ImGui.TextColored(1, 0, 1, 1, 'About')
    ImGui.Separator()
    ImGui.Text('Version: ')
    ImGui.SameLine()
    ImGui.TextColored(0, 1, 0, 1, VERSION)
end

local function DrawSaveChanges()
    if ConfigUI.dirty then
        ImGui.TextColored(1, 0, 0, 1, 'Are you sure you wish to save your changes?')
        if ImGui.Button('Yes') then
            print_msg('Saving configuration')
            if SaveSettings() then
                ConfigUI.dirty = false
            end
        end
    else
        ImGui.Text('No pending changes.')
    end
end

local function DrawInfo(x)
    ImGui.PushTextWrapPos(x-10)
    if ConfigUI.dirty then
        ImGui.TextColored(1, 0, 0, 1, 'Configuration changes will not be persisted until you click \'Save Configuration\' on the left menu.')
        ImGui.Separator()
    end
    ImGui.Text('To get started with configuring boxhud, select an item from the menu on the left.')
    ImGui.Text('Properties define the data members which will be either observed with MQ2DanNet, read from MQ2NetBots or read from Spawn data.')
    ImGui.Text('Columns define how specific properties should be displayed.')
    ImGui.Text('Tabs define groupings of columns and will appear in the top tab bar.')
    ImGui.Text('Configuration changes take effect immediately. However, changes won\'t be persisted unless you click \'Save Configuration\'.')
    ImGui.PopTextWrapPos()
end

local function RightPaneWindow()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("right", x, y-1, true) then
        if ConfigUI.selectedItemType == 'settings' then
            DrawGeneralSettings()
        elseif ConfigUI.selectedItemType == 'addnewproperty' then
            newProperty:draw(x)
        elseif ConfigUI.selectedItemType == 'addnewcolumn' then
            newColumn:draw(x)
        elseif ConfigUI.selectedItemType == 'addnewtab' then
            newTab:draw(x)
        elseif ConfigUI.selectedItemType == 'property' then
            local property = SETTINGS['Properties'][ConfigUI.selectedItem]
            if property then
                property:draw()
            end
        elseif ConfigUI.selectedItemType == 'column' then
            local column = SETTINGS['Columns'][ConfigUI.selectedItem]
            if column ~= nil then
                column:draw()
            end
        elseif ConfigUI.selectedItemType == 'tab' then
            local tab = SETTINGS['Tabs'][ConfigUI.selectedItem]
            if tab then
                tab:draw()
            end
        elseif ConfigUI.selectedItemType == 'about' then
            DrawAbout()
        elseif ConfigUI.selectedItemType == 'savechanges' then
            DrawSaveChanges()
        else
            DrawInfo(x)
        end
        ImGui.EndChild()
    end
end

function ConfigurationTab()
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 6, 6)
    LeftPaneWindow()
    ImGui.SameLine()
    RightPaneWindow()
    ImGui.PopStyleVar()
end
