--- @type ImGui
require 'ImGui'
require('boxhud.utils')

local configpanel = {}

local configDirty = false

local typeRadioPressed = true
local typeRadioValue = 1

-- new property fields
local newPropertyName = ''
local newPropertyDependsOnName = ''
local newPropertyDependsOnValue = ''
local newPropertyFromIDProperty = ''

-- new column fields
local newColumnName = ''
local newColumnProperties = {[1]={[1]='',[2]=''}}
local newColumnPropCount = 1
local newColumnMappings = {}
local newColumnMappingCount = 1
local newColumnThresholds = {}
local newColumnThresholdCount = 0
local newColumnPercentage = false
local newColumnAscending = true
local newColumnInZone = true
local newColumnAction = ''

-- new tab fields
local newTabName = ''
local newTabColumns = {[1]='Name'}
local newTabColumnCount = 1

local selected = false
local selectedItem = nil
local selectedItemType = nil

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

local function ResetPropertyOptions()
    typeRadioValue = 1
    newPropertyName = ''
    newPropertyDependsOnName = ''
    newPropertyDependsOnValue = ''
    newPropertyFromIDProperty = ''
    invalidInput = false
    message = nil
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
                ResetPropertyOptions()
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

local function ResetColumnOptions()
    newColumnName = ''
    typeRadioValue = 1
    newColumnAction = ''
    newColumnAscending = false
    newColumnInZone = true
    newColumnPercentage = false
    newColumnProperties = {[1]={[1]='',[2]=''}}
    newColumnPropCount = 1
    newColumnMappings = {}
    newColumnMappingCount = 0
    newColumnThresholds = {}
    newColumnThresholdCount = 0
    invalidInput = false
    message = nil
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
                ResetColumnOptions()
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

local function ResetTabOptions()
    newTabName = ''
    newTabColumns = {[1]='Name'}
    newTabColumnCount = 1
    invalidInput = false
    message = nil
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
                ResetTabOptions()
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

local function BuildProperty()
    local property = {}
    property['Type'] = 'Observed'
    if typeRadioValue == 2 then
        property['Type'] = 'NetBots'
    elseif typeRadioValue == 3 then
        property['Type'] = 'Spawn'
    end
    if newPropertyDependsOnName ~= '' then
        property['DependsOnName'] = newPropertyDependsOnName
    end
    if newPropertyDependsOnValue ~= '' then
        property['DependsOnValue'] = newPropertyDependsOnValue
    end
    if newPropertyFromIDProperty ~= '' then
        property['FromIDProperty'] = newPropertyFromIDProperty
    end
    return property
end

local function DrawAddPropertyOptions()
    ImGui.TextColored(1, 0, 1, 1, "Add New Property")
    ImGui.Separator()
    ImGui.Text('Type: ')
    ImGui.SameLine()
    HelpMarker('The source of the property value.\n\'Observed\' will get the value using MQ2DanNet.\n\'NetBots\' will get the value using MQ2NetBots.\n\'Spawn\' will get the value from the Spawn TLO.')
    --ImGui.SameLine()
    typeRadioValue, typeRadioPressed = ImGui.RadioButton("Observed", typeRadioValue, 1)
    ImGui.SameLine()
    typeRadioValue, typeRadioPressed = ImGui.RadioButton("NetBots", typeRadioValue, 2)
    ImGui.SameLine()
    typeRadioValue, typeRadioPressed = ImGui.RadioButton("Spawn", typeRadioValue, 3)
    
    ImGui.Text('Name(*): ')
    ImGui.SameLine()
    HelpMarker('The data member this property should display. Examples:\nObserved: \'Me.PctHPs\'\nNetBots: \'PctHPs\'\nSpawn: \'Distance3D\'\n')
    newPropertyName, selected = ImGui.InputText('##newpropname', newPropertyName, 32)

    if typeRadioValue == 1 then
        ImGui.Text('DependsOnName: ')
        ImGui.SameLine()
        HelpMarker('Optional. The name of another property which this property depends on. This property will be ignored for a character if the property it depends on doesn\'t have the desired value.')
        newPropertyDependsOnName, selected = ImGui.InputText('##newpropdepname', newPropertyDependsOnName, 32)
        ImGui.Text('DependsOnValue: ')
        ImGui.SameLine()
        HelpMarker('Optional. The value of another property which this property depends on. This property will be ignored for a character if the property it depends on doesn\'t have the desired value.')
        newPropertyDependsOnValue, selected = ImGui.InputText('##newpropdepvalue', newPropertyDependsOnValue, 32)
    elseif typeRadioValue == 3 then
        ImGui.Text('FromIDProperty: ')
        ImGui.SameLine()
        HelpMarker('Optional. The name of another property to use as the ID in the Spawn search. The property MUST return a Spawn ID.')
        newPropertyFromIDProperty, selected = ImGui.InputText('##newpropfromid', newPropertyFromIDProperty, 32)
    end
    ImGui.Separator()
    if ImGui.Button('Save##newprop') then
        local property = BuildProperty()
        local ok = false
        ok, message = ValidateProperty(newPropertyName, property, -1)
        if ok then
            --print(string.format('Add property: type=%d name=%s dependsonname=%s dependsonvalue=%s fromidproperty=%s',
            --        typeRadioValue, newPropertyName, newPropertyDependsOnName, newPropertyDependsOnValue, newPropertyFromIDProperty))
            SETTINGS['Properties'][newPropertyName] = property
            ResetPropertyOptions()
            selectedItemType = nil
            configDirty = true
        else
            invalidInput = true
        end
    end
    if invalidInput then
        ImGui.SameLine()
        ImGui.PushTextWrapPos(300)
        ImGui.TextColored(1, 0, 0, 1, string.format('Invalid input! %s', message))
        ImGui.PopTextWrapPos()
    end
end

local function PropertyReferences(propName, draw)
    local refFound = false
    for columnName,column in pairs(SETTINGS['Columns']) do
        if column['Properties'] then
            for propKey,propValue in pairs(column['Properties']) do
                if propValue == propName then
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
        if property['DependsOnName'] == propName then
            refFound = true
            if draw then
                ImGui.TextColored(0, 1, 1, 1, 'Property: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, propNameIter)
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 1, 1, ' DependsOnName: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, propName)
            end
        elseif property['FromIDProperty'] == propName then
            refFound = true
            if draw then
                ImGui.TextColored(0, 1, 1, 1, 'Property: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, propNameIter)
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 1, 1, ' FromIDProperty: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, propName)
            end
        end
    end
    return refFound
end

local function DrawPropertySettings()
    local propSettings = SETTINGS['Properties'][selectedItem]
    if propSettings ~= nil then
        ImGui.TextColored(1, 0, 1, 1, selectedItem)
        ImGui.Separator()
        if ImGui.SmallButton('Edit##'..selectedItem) then
            if selectedItem ~= 'Me.Class.ShortName' then
                newPropertyName = selectedItem
                if propSettings['Type'] == 'Observed' then
                    typeRadioValue = 1
                    newPropertyDependsOnName = ''
                    newPropertyDependsOnValue = ''
                elseif propSettings['Type'] == 'Spawn' then
                    typeRadioValue = 3
                    newPropertyFromIDProperty = ''
                else
                    typeRadioValue = 2
                end
                selectedItemType = 'addnewproperty'
            end
        end
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..selectedItem) then
            if selectedItem ~= 'Me.Class.ShortName' then -- do not allow deleting class
                -- TODO: ref check
                if not PropertyReferences(selectedItem, false) then
                    SETTINGS['Properties'][selectedItem] = nil
                    selectedItemType = nil
                    selectedItem = nil
                    configDirty = true
                end
            end
        end
        ImGui.Text('Type: ')
        ImGui.SameLine()
        ImGui.TextColored(0, 1, 0, 1, propSettings['Type'])
        if propSettings['DependsOnName'] then
            ImGui.Text('DependsOnName: ')
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, propSettings['DependsOnName'])
        end
        if propSettings['DependsOnValue'] then
            ImGui.Text('DependsOnValue: ')
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, propSettings['DependsOnValue'])
        end
        if propSettings['FromIDProperty'] then
            ImGui.Text('FromIDProperty: ')
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, propSettings['FromIDProperty'])
        end
        ImGui.Separator()
        ImGui.Text('References:')
        ImGui.Indent(10)
        PropertyReferences(selectedItem, true)
        ImGui.Indent(-10)
    end
end

local classes = {'all', 'melee', 'caster', 'hybrids', 'ranged', 'ber', 'brd', 
        'bst', 'clr', 'dru', 'enc', 'mag', 'mnk', 'nec', 'pal', 'shd', 'rng', 
        'rog', 'shm', 'war', 'wiz'}

local function BuildColumn()
    local column = {
        Type='property'
    }
    if typeRadioValue == 1 then
        column['Ascending']=newColumnAscending
        column['InZone']=newColumnInZone
        column['Percentage']=newColumnPercentage
        column['Properties']={}
        if newColumnMappingCount > 0 then
            column['Mappings']={}
        end
        for i,j in ipairs(newColumnProperties) do
            column['Properties'][j[1]] = j[2]
        end
        for i,j in ipairs(newColumnMappings) do
            column['Mappings'][j[1]] = j[2]
        end
        if newColumnThresholdCount > 0 then
            column['Thresholds']={}
        end
        for i,j in ipairs(newColumnThresholds) do
            column['Thresholds'][i] = tonumber(j)
        end
    elseif typeRadioValue == 2 then
        column['Type'] = 'button'
        column['Action'] = newColumnAction
    end
    return column
end

local function DrawAddColumnOptions()
    ImGui.TextColored(1, 0, 1, 1, "Add New Column")
    ImGui.Separator()
    ImGui.Text('Type: ')
    ImGui.SameLine()
    HelpMarker('Choose whether the column will display property values or buttons.')
    typeRadioValue, typeRadioPressed = ImGui.RadioButton("Property", typeRadioValue, 1)
    ImGui.SameLine()
    typeRadioValue, typeRadioPressed = ImGui.RadioButton("Button", typeRadioValue, 2)

    ImGui.Text('Name(*): ')
    ImGui.SameLine()
    HelpMarker('The name of the column which will appear in the table column header.')
    newColumnName, selected = ImGui.InputText('##newcolumnname', newColumnName, 32)
        
    if typeRadioValue == 1 then
        ImGui.Text('Properties(*): ')
        ImGui.SameLine()
        HelpMarker('The property values which will be displayed in this column. The column can display different properties for different classes.')
        for propIdx, propName in ipairs(newColumnProperties) do
            if newColumnProperties[propIdx] ~= nil then
                ImGui.PushItemWidth(80)
                shouldDrawCombo = ImGui.BeginCombo("##colpropcombo1"..propIdx, newColumnProperties[propIdx][1])
                if shouldDrawCombo then
                    for _,class in pairs(classes) do
                        selected = ImGui.Selectable(class, newColumnProperties[propIdx][1] == class)
                        if selected then
                            newColumnProperties[propIdx][1] = class
                        end
                    end
                    ImGui.EndCombo()
                end
                ImGui.PopItemWidth()
                ImGui.SameLine()
                ImGui.PushItemWidth(160)
                shouldDrawCombo = ImGui.BeginCombo("##colpropcombo2"..propIdx, newColumnProperties[propIdx][2])
                if shouldDrawCombo then
                    for cpropname,_ in pairs(SETTINGS['Properties']) do
                        selected = ImGui.Selectable(cpropname, newColumnProperties[propIdx][2] == cpropname)
                        if selected then
                            newColumnProperties[propIdx][2] = cpropname
                        end
                    end
                    ImGui.EndCombo()
                end
                ImGui.PopItemWidth()
                ImGui.SameLine()
                if ImGui.Button('X##deleteRow'..propIdx) then
                    local propIter = propIdx
                    for prop = propIdx+1, #newColumnProperties do
                        newColumnProperties[propIter] = newColumnProperties[prop]
                        propIter = propIter+1
                    end
                    newColumnProperties[propIter] = nil
                    newColumnPropCount = newColumnPropCount - 1
                end
            end
        end
        if ImGui.Button('+##properties') then
            newColumnPropCount = newColumnPropCount + 1
            newColumnProperties[newColumnPropCount] = {[1]='',[2]=''}
        end
        
        ImGui.Text('Mappings: ')
        ImGui.SameLine()
        HelpMarker('Optional. Define mappings from raw property values to values that should be displayed.\nExample: Map \'TRUE\' to \'Paused\' for \'Macro.Paused\'.')
        for mappingIdx, mappingName in ipairs(newColumnMappings) do
            if newColumnMappings[mappingIdx] ~= nil then
                ImGui.PushItemWidth(100)
                newColumnMappings[mappingIdx][1], selected = ImGui.InputText('##newcolmappings1-'..tostring(mappingIdx), newColumnMappings[mappingIdx][1], 32)
                ImGui.SameLine()
                newColumnMappings[mappingIdx][2], selected = ImGui.InputText('##newcolmappings2-'..tostring(mappingIdx), newColumnMappings[mappingIdx][2], 32)
                ImGui.SameLine()
                if ImGui.Button('X##deleteMappingRow'..mappingIdx) then
                    local mappingIter = mappingIdx
                    for mapping = mappingIdx+1, #newColumnMappings do
                        newColumnMappings[mappingIter] = newColumnMappings[mapping]
                        mappingIter = mappingIter+1
                    end
                    newColumnMappings[mappingIter] = nil
                    newColumnMappingCount = newColumnMappingCount - 1
                end
                ImGui.PopItemWidth()
            end
        end
        if ImGui.Button('+##mappings') then
            newColumnMappingCount = newColumnMappingCount + 1
            newColumnMappings[newColumnMappingCount] = {[1]='',[2]=''}
        end

        ImGui.Text('Thresholds: ')
        ImGui.SameLine()
        HelpMarker('Optional. Set up to (2) numbers, in increasing order, for column text color thresholds.\nExample: Set Me.PctHPs thresholds to 35, 70 so that values below 35 will be red, between 35-70 will be yellow, and above 70 will be green.')
        for thresholdIdx, thresholdValue in ipairs(newColumnThresholds) do
            if newColumnThresholds[thresholdIdx] ~= nil then
                ImGui.PushItemWidth(80)
                newColumnThresholds[thresholdIdx], selected = ImGui.InputText('##newcolthresholds'..tostring(thresholdIdx), newColumnThresholds[thresholdIdx], 32)
                ImGui.PopItemWidth()
                ImGui.SameLine()
                if ImGui.Button('X##deleteThresholdRow'..thresholdIdx) then
                    local thresholdIter = thresholdIdx
                    for threshold = thresholdIdx+1, #newColumnThresholds do
                        newColumnThresholds[thresholdIter] = newColumnThresholds[threshold]
                        thresholdIter = thresholdIter+1
                    end
                    newColumnThresholds[thresholdIter] = nil
                    newColumnThresholdCount = newColumnThresholdCount - 1
                end
            end
        end
        if newColumnThresholdCount < 2 then
            if ImGui.Button('+##thresholds') then
                newColumnThresholdCount = newColumnThresholdCount + 1
                newColumnThresholds[newColumnThresholdCount] = ''
            end
        end

        ImGui.Text('Percentage: ')
        ImGui.SameLine()
        HelpMarker('Check this box if the values displayed in this column are percents.')
        newColumnPercentage, pressed = ImGui.Checkbox('##newcolumnpercent', newColumnPercentage)
        ImGui.Text('Ascending: ')
        ImGui.SameLine()
        HelpMarker('Check this box if higher values are \'better\', i.e. 100%% HP is better than 10%%.')
        newColumnAscending, pressed = ImGui.Checkbox('##newcolumnascending', newColumnAscending)
        ImGui.Text('InZone: ')
        ImGui.SameLine()
        HelpMarker('Check this box if this column should only display values for characters in the same zone.')
        newColumnInZone, pressed = ImGui.Checkbox('##newcolumninzone', newColumnInZone)
    elseif typeRadioValue == 2 then
        ImGui.Text('Action(*): ')
        ImGui.SameLine()
        HelpMarker('The action to take on left click. The string \'#botName#\' will be replaced with the character name from the row of the button.\nExample: \'/dex #botName# /mqp\'')
        newColumnAction, selected = ImGui.InputText('##newcolumnaction', newColumnAction, 32)
    end
    ImGui.Separator()
    if ImGui.Button('Save##newcolumn') then
        local column = BuildColumn()
        ok, message = ValidateColumn(newColumnName, column)
        if ok then
            --[[
            print(string.format('Add column: name=%s type=%d percentage=%s ascending=%s inzone=%s action=%s', 
                    newColumnName, typeRadioValue, newColumnPercentage, newColumnAscending, newColumnInZone, newColumnAction))
            for i,j in ipairs(newColumnProperties) do
                print(string.format('Column Property %s: %s', j[1], j[2]))
            end
            for i,j in ipairs(newColumnMappings) do
                print(string.format('Column Mapping %s: %s', j[1], j[2]))
            end
            for i,j in ipairs(newColumnThresholds) do
                print(string.format('Column Threshold %d: %s', i, j))
            end
            --]]
            SETTINGS['Columns'][newColumnName] = column
            selectedItemType = nil
            ResetColumnOptions()
            configDirty = true
        else
            invalidInput = true
        end
    end
    if invalidInput then
        ImGui.SameLine()
        ImGui.PushTextWrapPos(300)
        ImGui.TextColored(1, 0, 0, 1, string.format('Invalid input! %s', message))
        ImGui.PopTextWrapPos()
    end
end

local function ColumnReferences(columnName, draw)
    local refFound = false
    for _,tab in pairs(SETTINGS['Tabs']) do
        if tab['Columns'] then
            for _,columnNameIter in pairs(tab['Columns']) do
                if columnName == columnNameIter then
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
    local columnSettings = SETTINGS['Columns'][selectedItem]
    if columnSettings ~= nil then
        ImGui.TextColored(1, 0, 1, 1, selectedItem)
        ImGui.Separator()
        if ImGui.SmallButton('Edit##'..selectedItem) then
            if selectedItem ~= 'Name' then
                newColumnName = selectedItem
                if columnSettings['Type'] == 'property' then
                    typeRadioValue = 1
                    newColumnAscending = columnSettings['Ascending']
                    newColumnInZone = columnSettings['InZone']
                    newColumnPercentage = columnSettings['Percentage']
                    newColumnPropCount = 0
                    newColumnProperties = {}
                    if columnSettings['Properties'] then
                        for propKey,propValue in pairs(columnSettings['Properties']) do
                            newColumnPropCount = newColumnPropCount + 1
                            newColumnProperties[newColumnPropCount] = {[1]=propKey,[2]=propValue}
                        end
                    end
                    newColumnMappingCount = 0
                    newColumnMappings = {}
                    if columnSettings['Mappings'] then
                        for mappingKey,mappingValue in pairs(columnSettings['Mappings']) do
                            newColumnMappingCount = newColumnMappingCount + 1
                            newColumnMappings[newColumnMappingCount] = {[1]=mappingKey,[2]=mappingValue}
                        end
                    end
                    newColumnThresholdCount = 0
                    newColumnThresholds = {}
                    if columnSettings['Thresholds'] then
                        for thresholdIdx,thresholdValue in ipairs(columnSettings['Thresholds']) do
                            newColumnThresholdCount = newColumnThresholdCount + 1
                            newColumnThresholds[thresholdIdx] = tostring(thresholdValue)
                        end
                    end
                else
                    typeRadioValue = 2
                    newColumnAction = columnSettings['Action']
                end
                selectedItemType = 'addnewcolumn'
            end
        end
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..selectedItem) then
            if selectedItem ~= 'Name' then -- Don't allow deleting name column
                -- TODO: ref check
                if not ColumnReferences(selectedItem, false) then
                    SETTINGS['Columns'][selectedItem] = nil
                    selectedItemType = nil
                    selectedItem = nil
                    configDirty = true
                end
            end
        end
        ImGui.Text('Type: ')
        ImGui.SameLine()
        ImGui.TextColored(0, 1, 0, 1, columnSettings['Type'])
        
        if columnSettings['Type'] == 'property' then
            ImGui.Text('Properties: ')
            if columnSettings['Properties'] then
                ImGui.Indent(10)
                for i,j in pairs(columnSettings['Properties']) do
                    ImGui.TextColored(0, 1, 1, 1, i..': ')
                    ImGui.SameLine()
                    ImGui.TextColored(0, 1, 0, 1, j)
                end
                ImGui.Indent(-10)
            end
            ImGui.Text('Thresholds: ')
            if columnSettings['Thresholds'] then
                ImGui.Indent(10)
                for i,j in ipairs(columnSettings['Thresholds']) do
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
            if columnSettings['Mappings'] then
                ImGui.Indent(10)
                for i,j in pairs(columnSettings['Mappings']) do
                    ImGui.TextColored(0, 1, 1, 1, i..': ')
                    ImGui.SameLine()
                    ImGui.TextColored(0, 1, 0, 1, j)
                end
                ImGui.Indent(-10)
            else
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, 'None')
            end
            if columnSettings['Percentage'] then
                ImGui.Text('Percentage: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, tostring(columnSettings['Percentage']))
            end
            if columnSettings['Ascending'] then
                ImGui.Text('Ascending: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, tostring(columnSettings['Ascending']))
            end
            if columnSettings['InZone'] then
                ImGui.Text('InZone: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, tostring(columnSettings['InZone']))
            end
        elseif columnSettings['Type'] == 'button' then
            if columnSettings['Action'] then
                ImGui.Text('Action: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, columnSettings['Action'])
            end
        end
        ImGui.Separator()
        ImGui.Text('References:')
        ImGui.Indent(10)
        ColumnReferences(selectedItem, true)
        ImGui.Indent(-10)
    end
end

local shouldDrawCombo = false
local function DrawAddTabOptions()
    ImGui.TextColored(1, 0, 1, 1, "Add New Tab")
    ImGui.Separator()
    ImGui.Text('Name(*): ')
    ImGui.SameLine()
    HelpMarker('The name of the tab which will be displayed in the Tab bar.')
    newTabName, selected = ImGui.InputText('##newtabname', newTabName, 32)
    ImGui.Text('Columns: ')
    ImGui.SameLine()
    HelpMarker('The list of columns which will be displayed in the tab.')
    for columnIdx, columnName in ipairs(newTabColumns) do
        if newTabColumns[columnIdx] ~= nil then
            shouldDrawCombo = ImGui.BeginCombo("##columncombo"..columnIdx, newTabColumns[columnIdx])
            if shouldDrawCombo then
                for column,_ in pairs(SETTINGS['Columns']) do
                    selected = ImGui.Selectable(column, newTabColumns[columnIdx] == column)
                    if selected then
                        newTabColumns[columnIdx] = column
                    end
                end
                ImGui.EndCombo()
            end
            ImGui.SameLine()
            if ImGui.Button('X##deleteRow'..columnIdx) then
                local columnIter = columnIdx
                for columns = columnIdx+1, #newTabColumns do
                    newTabColumns[columnIter] = newTabColumns[columns]
                    columnIter = columnIter+1
                end
                newTabColumns[columnIter] = nil
                newTabColumnCount = newTabColumnCount - 1
            end
        end
    end
    if ImGui.Button('+') then
        newTabColumnCount = newTabColumnCount + 1
        newTabColumns[newTabColumnCount] = ''
    end
    ImGui.Separator()
    if ImGui.Button('Save##newtab') then
        local ok = false
        local tab = {Name=newTabName,Columns=newTabColumns}
        ok, message = ValidateTab(tab, #SETTINGS['Tabs']+1)
        if ok then
            --[[
            print(string.format('Add tab: name=%s', newTabName))
            for i,j in ipairs(newTabColumns) do
                print(string.format('Column %s: %s', i, j))
            end
            --]]
            local foundExisting = false
            for tabIdx,existingTab in ipairs(SETTINGS['Tabs']) do
                if existingTab['Name'] == newTabName then
                    -- replace existing tab
                    existingTab['Columns'] = newTabColumns
                    foundExisting = true
                end
            end
            if not foundExisting then
                table.insert(SETTINGS['Tabs'], tab)
            end
            ResetTabOptions()
            selectedItemType = nil
            configDirty = true
        else
            invalidInput = true
        end
    end
    if invalidInput then
        ImGui.SameLine()
        ImGui.PushTextWrapPos(300)
        ImGui.TextColored(1, 0, 0, 1, string.format('Invalid input! %s', message))
        ImGui.PopTextWrapPos()
    end
end

local function DrawTabSettings()
    local tab = SETTINGS['Tabs'][selectedItem]
    if tab then
        ImGui.TextColored(1, 0, 1, 1, tab['Name'])
        ImGui.Separator()
        if ImGui.SmallButton('Edit##'..tab['Name']) then
            newTabName = tab['Name']
            newTabColumns = tab['Columns']
            newTabColumnCount = #tab['Columns']
            selectedItemType = 'addnewtab'
        end
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..tab['Name']) then
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
        if tab['Columns'] then
            for columnIdx,column in ipairs(tab['Columns']) do
                ImGui.Text(string.format('%d: ', columnIdx))
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, column)
            end
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

local function RightPaneWindow()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("right", x, y-1, true) then
        if selectedItemType == 'settings' then
            DrawGeneralSettings()
        elseif selectedItemType == 'addnewproperty' then
            DrawAddPropertyOptions()
        elseif selectedItemType == 'addnewcolumn' then
            DrawAddColumnOptions()
        elseif selectedItemType == 'addnewtab' then
            DrawAddTabOptions()
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
