--- @type ImGui
require 'ImGui'
require('boxhud.utils')

local configpanel = {}

PropertyInput = class(function(p)
    p.Name=''
    p.Type=1
    p.DependsOnName=''
    p.DependsOnValue=''
    p.FromIDProperty=''
    p.valid=true
    p.message=nil
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

local newProperty = nil

ColumnInput = class(function(c)
    c.Name=''
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
    c.valid=true
    c.message=nil
end)

function ColumnInput:toColumn()
    local column = Column({Name=self.Name,Type='property'})
    if self.Type == 1 then
        column['Ascending']=self.Ascending
        column['InZone']=self.InZone
        column['Percentage']=self.Percentage
        column['Properties']={}
        if self.MappingCount > 0 then
            column['Mappings']={}
        end
        for i,j in ipairs(self.Properties) do
            column['Properties'][j[1]] = j[2]
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

local newColumn = nil

TabInput = class(function(t)
    t.Name = ''
    t.Columns = {[1]='Name'}
    t.ColumnCount = 1
    t.valid = true
    t.message = nil
end)

function TabInput:toTab()
    local tab = Tab({})
    tab.Name = self.Name
    tab.Columns = self.Columns
    return tab
end

function TabInput:fromTab(tab)
    local o = TabInput()
    o.Name = tab['Name']
    o.ColumnCount = #tab['Columns']
    return o
end

local newTab = nil

local selected = false
local selectedItem = nil
local selectedItemType = nil

local configDirty = false
local invalidInput = false
local message = nil

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
    selected = ImGui.Selectable('General Settings', selectedItemType == 'settings')
    ImGui.PopStyleColor(1)
    if selected then
        selectedItem = nil
        selectedItemType = 'settings'
    end
end

local function DrawPropertiesTreeSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 1, 1)
    if ImGui.TreeNodeEx('Properties', ImGuiTreeNodeFlags.SpanFullWidth) then
        ImGui.PopStyleColor(1)
        ImGui.Indent(8)
        selected = ImGui.Selectable('Add new property...', selectedItemType == 'addnewproperty')
        if selected then
            selectedItem = nil
            if selectedItemType ~= 'addnewproperty' then
                newProperty = PropertyInput()
            end
            selectedItemType = 'addnewproperty'
        end
        for propName, propSettings in pairs(SETTINGS['Properties']) do
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            selected = ImGui.Selectable(propName, selectedItem == propName and selectedItemType == 'property')
            if selected then
                selectedItem = propName
                selectedItemType = 'property'
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.Indent(-8)
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if selectedItemType == 'property' or selectedItemType == 'addnewproperty' then
            selectedItem = nil
            selectedItemType = nil
        end
    end
end

local function DrawColumnTreeSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 1, 1)
    if ImGui.TreeNodeEx('Columns', ImGuiTreeNodeFlags.SpanFullWidth) then
        ImGui.PopStyleColor(1)
        ImGui.Indent(8)
        selected = ImGui.Selectable('Add new column...', selectedItemType == 'addnewcolumn')
        if selected then
            selectedItem = nil
            if selectedItemType ~= 'addnewcolumn' then
                newColumn = ColumnInput()
            end
            selectedItemType = 'addnewcolumn'
        end
        for columnName, columnSettings in pairs(SETTINGS['Columns']) do
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            selected = ImGui.Selectable(columnName, selectedItem == columnName and selectedItemType == 'column')
            if selected then
                selectedItem = columnName
                selectedItemType = 'column'
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.Indent(-8)
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if selectedItemType == 'column' or selectedItemType == 'addnewcolumn' then
            selectedItem = nil
            selectedItemType = nil
        end
    end
end

local function DrawTabTreeSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 1, 1)
    if ImGui.TreeNodeEx('Tabs', ImGuiTreeNodeFlags.SpanFullWidth) then
        ImGui.PopStyleColor(1)
        ImGui.Indent(8)
        selected = ImGui.Selectable('Add new tab...', selectedItemType == 'addnewtab')
        if selected then
            selectedItem = nil
            if selectedItemType ~= 'addnewtab' then
                newTab = TabInput()
            end
            selectedItemType = 'addnewtab'
        end
        for tabIdx, tab in pairs(SETTINGS['Tabs']) do
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            selected = ImGui.Selectable(tab['Name'], selectedItem == tabIdx and selectedItemType == 'tab')
            if selected then
                selectedItem = tabIdx
                selectedItemType = 'tab'
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.Indent(-8)
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if selectedItemType == 'tab' or selectedItemType == 'addnewtab' then
            selectedItem = nil
            selectedItemType = nil
        end
    end
end

local function DrawAboutSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 1, 1)
    selected = ImGui.Selectable('About', selectedItemType == 'about')
    ImGui.PopStyleColor(1)
    if selected then
        selectedItem = nil
        selectedItemType = 'about'
    end
end

local function DrawSaveChangesSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 1, 1)
    selected = ImGui.Selectable('Save Configuration', selectedItemType == 'savechanges')
    ImGui.PopStyleColor(1)
    if selected then
        selectedItem = nil
        selectedItemType = 'savechanges'
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
    self.Name, selected = ImGui.InputText('##newpropname', self.Name, 32)

    if self.Type == 1 then
        ImGui.Text('DependsOnName: ')
        ImGui.SameLine()
        HelpMarker('Optional. The name of another property which this property depends on. This property will be ignored for a character if the property it depends on doesn\'t have the desired value.')
        self.DependsOnName, selected = ImGui.InputText('##newpropdepname', self.DependsOnName, 32)
        ImGui.Text('DependsOnValue: ')
        ImGui.SameLine()
        HelpMarker('Optional. The value of another property which this property depends on. This property will be ignored for a character if the property it depends on doesn\'t have the desired value.')
        self.DependsOnValue, selected = ImGui.InputText('##newpropdepvalue', self.DependsOnValue, 32)
    elseif self.Type == 3 then
        ImGui.Text('FromIDProperty: ')
        ImGui.SameLine()
        HelpMarker('Optional. The name of another property to use as the ID in the Spawn search. The property MUST return a Spawn ID.')
        self.FromIDProperty, selected = ImGui.InputText('##newpropfromid', self.FromIDProperty, 32)
    end
    ImGui.Separator()
    if ImGui.Button('Save##newprop') then
        local property = self:toProperty()
        local ok = false
        ok, self.message = property:validate()
        if ok then
            SETTINGS['Properties'][self.Name] = property
            selectedItemType = nil
            configDirty = true
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
            selectedItemType = 'addnewproperty'
        end
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..self.Name) then
            if not self:references(false) then
                SETTINGS['Properties'][self.Name] = nil
                selectedItemType = nil
                selectedItem = nil
                configDirty = true
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

local function DrawPropertySettings()
    local property = Property(SETTINGS['Properties'][selectedItem])
    if property then
        property:draw()
    end
end

local classes = {'all', 'melee', 'caster', 'hybrids', 'ranged', 'ber', 'brd', 
        'bst', 'clr', 'dru', 'enc', 'mag', 'mnk', 'nec', 'pal', 'shd', 'rng', 
        'rog', 'shm', 'war', 'wiz'}

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
    self.Name, selected = ImGui.InputText('##newcolumnname', self.Name, 32)
        
    if self.Type == 1 then
        ImGui.Text('Properties(*): ')
        ImGui.SameLine()
        HelpMarker('The property values which will be displayed in this column. The column can display different properties for different classes.')
        for propIdx, propName in ipairs(self.Properties) do
            if self.Properties[propIdx] ~= nil then
                ImGui.PushItemWidth(80)
                shouldDrawCombo = ImGui.BeginCombo("##colpropcombo1"..propIdx, self.Properties[propIdx][1])
                if shouldDrawCombo then
                    for _,class in pairs(classes) do
                        selected = ImGui.Selectable(class, self.Properties[propIdx][1] == class)
                        if selected then
                            self.Properties[propIdx][1] = class
                        end
                    end
                    ImGui.EndCombo()
                end
                ImGui.PopItemWidth()
                ImGui.SameLine()
                ImGui.PushItemWidth(160)
                shouldDrawCombo = ImGui.BeginCombo("##colpropcombo2"..propIdx, self.Properties[propIdx][2])
                if shouldDrawCombo then
                    for cpropname,_ in pairs(SETTINGS['Properties']) do
                        selected = ImGui.Selectable(cpropname, self.Properties[propIdx][2] == cpropname)
                        if selected then
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
                self.Mappings[mappingIdx][1], selected = ImGui.InputText('##newcolmappings1-'..tostring(mappingIdx), self.Mappings[mappingIdx][1], 32)
                ImGui.SameLine()
                self.Mappings[mappingIdx][2], selected = ImGui.InputText('##newcolmappings2-'..tostring(mappingIdx), self.Mappings[mappingIdx][2], 32)
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
                self.Thresholds[thresholdIdx], selected = ImGui.InputText('##newcolthresholds'..tostring(thresholdIdx), self.Thresholds[thresholdIdx], 32)
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
    elseif typeRadioValue == 2 then
        ImGui.Text('Action(*): ')
        ImGui.SameLine()
        HelpMarker('The action to take on left click. The string \'#botName#\' will be replaced with the character name from the row of the button.\nExample: \'/dex #botName# /mqp\'')
        self.Action, selected = ImGui.InputText('##newcolumnaction', self.Action, 32)
    end
    ImGui.Separator()
    if ImGui.Button('Save##newcolumn') then
        local column = self:toColumn()
        ok, self.message = column:validate()
        if ok then
            SETTINGS['Columns'][self.Name] = column
            selectedItemType = nil
            configDirty = true
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

local function DrawColumnSettings()
    local column = Column(SETTINGS['Columns'][selectedItem])
    if column ~= nil then
        column:draw()
    end
end

function Column:draw()
    ImGui.TextColored(1, 0, 1, 1, self.Name)
    ImGui.Separator()
    if self.Name ~= 'Name' then
        if ImGui.SmallButton('Edit##'..self.Name) then
            newColumn = ColumnInput:fromColumn(self)
            selectedItemType = 'addnewcolumn'
        end
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..self.Name) then
            if not self:references(false) then
                SETTINGS['Columns'][self.Name] = nil
                selectedItemType = nil
                selectedItem = nil
                configDirty = true
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

local shouldDrawCombo = false
local function DrawAddTabOptions(x)
    ImGui.TextColored(1, 0, 1, 1, "Add New Tab")
    ImGui.Separator()
    ImGui.Text('Name(*): ')
    ImGui.SameLine()
    HelpMarker('The name of the tab which will be displayed in the Tab bar.')
    newTab.Name, selected = ImGui.InputText('##newtabname', newTab.Name, 32)
    ImGui.Text('Columns: ')
    ImGui.SameLine()
    HelpMarker('The list of columns which will be displayed in the tab.')
    for columnIdx, columnName in ipairs(newTab.Columns) do
        if newTab.Columns[columnIdx] ~= nil then
            shouldDrawCombo = ImGui.BeginCombo("##columncombo"..columnIdx, newTab.Columns[columnIdx])
            if shouldDrawCombo then
                for column,_ in pairs(SETTINGS['Columns']) do
                    selected = ImGui.Selectable(column, newTab.Columns[columnIdx] == column)
                    if selected then
                        newTab.Columns[columnIdx] = column
                    end
                end
                ImGui.EndCombo()
            end
            ImGui.SameLine()
            if ImGui.Button('X##deleteRow'..columnIdx) then
                local columnIter = columnIdx
                for columns = columnIdx+1, #newTab.Columns do
                    newTab.Columns[columnIter] = newTab.Columns[columns]
                    columnIter = columnIter+1
                end
                newTab.Columns[columnIter] = nil
                newTab.ColumnCount = newTab.ColumnCount - 1
            end
        end
    end
    if ImGui.Button('+') then
        newTab.ColumnCount = newTab.ColumnCount + 1
        newTab.Columns[newTab.ColumnCount] = ''
    end
    ImGui.Separator()
    if ImGui.Button('Save##newtab') then
        local ok = false
        local tab = newTab:toTab()
        ok, message = tab:validate()
        if ok then
            local foundExisting = false
            for tabIdx,existingTab in ipairs(SETTINGS['Tabs']) do
                if existingTab['Name'] == newTab.Name then
                    -- replace existing tab
                    existingTab['Columns'] = newTab.Columns
                    foundExisting = true
                end
            end
            if not foundExisting then
                table.insert(SETTINGS['Tabs'], tab)
            end
            selectedItemType = nil
            configDirty = true
        else
            newTab.valid = false
        end
    end
    if not newTab.valid then
        ImGui.SameLine()
        ImGui.PushTextWrapPos(x-10)
        ImGui.TextColored(1, 0, 0, 1, string.format('Invalid input! %s', newTab.message))
        ImGui.PopTextWrapPos()
    end
end

local function DrawTabSettings()
    local tab = Tab(SETTINGS['Tabs'][selectedItem])
    if tab then
        tab:draw()
    end
end

function Tab:draw()
    ImGui.TextColored(1, 0, 1, 1, self.Name)
    ImGui.Separator()
    if ImGui.SmallButton('Edit##'..self.Name) then
        newTab = TabInput:fromTab(self)
        selectedItemType = 'addnewtab'
    end
    ImGui.SameLine()
    if ImGui.SmallButton('Delete##'..self.Name) then
        local i = 1
        local tabIter = selectedItem
        for tabIdx = tabIter+1, #SETTINGS['Tabs'] do
            SETTINGS['Tabs'][tabIter] = SETTINGS['Tabs'][tabIdx]
            tabIter = tabIter+1
        end
        SETTINGS['Tabs'][tabIter] = nil
        selectedItemType = nil
        selectedItem = nil
        configDirty = true
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
end

local function DrawAbout()
    ImGui.TextColored(1, 0, 1, 1, 'About')
    ImGui.Separator()
    ImGui.Text('Version: ')
    ImGui.SameLine()
    ImGui.TextColored(0, 1, 0, 1, VERSION)
end

local saved = false
local function DrawSaveChanges()
    if configDirty then
        ImGui.TextColored(1, 0, 0, 1, 'Are you sure you wish to save your changes?')
        if ImGui.Button('Yes') then
            print_msg('Saving configuration')
            saved = SaveSettings()
        end
        if saved then
            configDirty = false
        end
    else
        ImGui.Text('No pending changes.')
    end
end

local function DrawInfo(x)
    ImGui.PushTextWrapPos(x-10)
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
        if selectedItemType == 'settings' then
            DrawGeneralSettings()
        elseif selectedItemType == 'addnewproperty' then
            newProperty:draw(x)
        elseif selectedItemType == 'addnewcolumn' then
            newColumn:draw(x)
        elseif selectedItemType == 'addnewtab' then
            DrawAddTabOptions(x)
        elseif selectedItemType == 'property' then
            DrawPropertySettings()
        elseif selectedItemType == 'column' then
            DrawColumnSettings()
        elseif selectedItemType == 'tab' then
            DrawTabSettings()
        elseif selectedItemType == 'about' then
            DrawAbout()
        elseif selectedItemType == 'savechanges' then
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

return configpanel
