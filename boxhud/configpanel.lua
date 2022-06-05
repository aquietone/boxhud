--- @type ImGui
require 'ImGui'
require('boxhud.utils')

local configpanel = {}

local showAddButtonPopup = false
local typeRadioPressed = true
local typeRadioValue = 1

-- new property fields
local newPropertyName = ''
local newPropertyType = ''
local newPropertyDependsOnName = ''
local newPropertyDependsOnValue = ''
local newPropertyFromIDProperty = ''

-- new column fields
local newColumnName = ''
local newColumnType = ''
local newColumnProperties = {[1]={[1]='',[2]=''}}
local newColumnPropCount = 1
local newColumnMappings = {[1]={[1]='',[2]=''}}
local newColumnMappingCount = 1
local newColumnThresholds = {[1]=''}
local newColumnThresholdCount = 1
local newColumnPercentage = false
local newColumnAscending = true
local newColumnInZone = true
local newColumnAction = ''

-- new tab fields
local newTabName = ''
local newTabColumns = {[1]=''}
local newTabColumnCount = 1

local selected = false
local selectedItem = nil
local selectedItemType = nil

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
                typeRadioValue = 1
                newPropertyName = ''
                newPropertyDependsOnName = ''
                newPropertyDependsOnValue = ''
                newPropertyFromIDProperty = ''
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
                newColumnName = ''
                typeRadioValue = 1
                newColumnAction = ''
                newColumnAscending = false
                newColumnInZone = true
                newColumnPercentage = false
                newColumnProperties = {[1]={[1]='',[2]=''}}
                newColumnPropCount = 1
                newColumnMappings = {[1]={[1]='',[2]=''}}
                newColumnMappingCount = 1
                newColumnThresholds = {[1]=''}
                newColumnThresholdCount = 1
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
                newTabName = ''
                newTabColumns = {[1]=''}
                newTabColumnCount = 1
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

local function LeftPaneWindow()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("left", 200, y-1, true) then
        DrawGeneralSettingsSelector()
        ImGui.Indent(-24)
        DrawPropertiesTreeSelector()
        DrawColumnTreeSelector()
        DrawTabTreeSelector()
        ImGui.Indent(24)
        ImGui.EndChild()
    end
end

local function DrawAddPropertyOptions()
    ImGui.TextColored(1, 0, 1, 1, "Add New Property")
    ImGui.Separator()
    ImGui.Text('Type: ')
    ImGui.SameLine()
    typeRadioValue, typeRadioPressed = ImGui.RadioButton("Observed", typeRadioValue, 1)
    ImGui.SameLine()
    typeRadioValue, typeRadioPressed = ImGui.RadioButton("NetBots", typeRadioValue, 2)
    ImGui.SameLine()
    typeRadioValue, typeRadioPressed = ImGui.RadioButton("Spawn", typeRadioValue, 3)
    
    ImGui.Text('Name: ')
    ImGui.SameLine()
    newPropertyName, selected = ImGui.InputText('##newpropname', newPropertyName, 32)

    if typeRadioValue == 1 then
        ImGui.Text('DependsOnName: ')
        ImGui.SameLine()
        newPropertyDependsOnName, selected = ImGui.InputText('##newpropdepname', newPropertyDependsOnName, 32)
        ImGui.Text('DependsOnValue: ')
        ImGui.SameLine()
        newPropertyDependsOnValue, selected = ImGui.InputText('##newpropdepvalue', newPropertyDependsOnValue, 32)
    elseif typeRadioValue == 3 then
        ImGui.Text('FromIDProperty: ')
        ImGui.SameLine()
        newPropertyFromIDProperty, selected = ImGui.InputText('##newpropfromid', newPropertyFromIDProperty, 32)
    end
    ImGui.Separator()
    if ImGui.Button('Save##newprop') then
        print(string.format('Add property: type=%d name=%s dependsonname=%s dependsonvalue=%s fromidproperty=%s',
                typeRadioValue, newPropertyName, newPropertyDependsOnName, newPropertyDependsOnValue, newPropertyFromIDProperty))
        typeRadioValue = 1
        newPropertyName = ''
        newPropertyDependsOnName = ''
        newPropertyDependsOnValue = ''
        newPropertyFromIDProperty = ''
        selectedItemType = nil
    end
end

local function DrawPropertySettings()
    ImGui.TextColored(1, 0, 1, 1, selectedItem)
    ImGui.Separator()
    if ImGui.SmallButton('Edit##'..selectedItem) then

    end
    ImGui.SameLine()
    if ImGui.SmallButton('Delete##'..selectedItem) then

    end
    local propSettings = SETTINGS['Properties'][selectedItem]
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
        ImGui.Text('DependsOnValue: ')
        ImGui.SameLine()
        ImGui.TextColored(0, 1, 0, 1, propSettings['FromIDProperty'])
    end
end

local function DrawAddColumnOptions()
    ImGui.TextColored(1, 0, 1, 1, "Add New Column")
    ImGui.Separator()
    ImGui.Text('Type: ')
    ImGui.SameLine()
    typeRadioValue, typeRadioPressed = ImGui.RadioButton("Property", typeRadioValue, 1)
    ImGui.SameLine()
    typeRadioValue, typeRadioPressed = ImGui.RadioButton("Button", typeRadioValue, 2)

    ImGui.Text('Name: ')
    ImGui.SameLine()
    newColumnName, selected = ImGui.InputText('##newcolumnname', newColumnName, 32)
        
    if typeRadioValue == 1 then
        ImGui.Text('Properties: ')
        for propIdx, propName in ipairs(newColumnProperties) do
            if newColumnProperties[propIdx] ~= nil then
                ImGui.PushItemWidth(80)
                newColumnProperties[propIdx][1], selected = ImGui.InputText('##newcolprops1-'..tostring(propIdx), newColumnProperties[propIdx][1], 32)
                ImGui.SameLine()
                newColumnProperties[propIdx][2], selected = ImGui.InputText('##newcolprops2-'..tostring(propIdx), newColumnProperties[propIdx][2], 32)
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
        for mappingIdx, mappingName in ipairs(newColumnMappings) do
            if newColumnMappings[mappingIdx] ~= nil then
                ImGui.PushItemWidth(80)
                newColumnMappings[mappingIdx][1], selected = ImGui.InputText('##newcolmappings1-'..tostring(mappingIdx), newColumnMappings[mappingIdx][1], 32)
                ImGui.SameLine()
                newColumnMappings[mappingIdx][2], selected = ImGui.InputText('##newcolmappings2-'..tostring(mappingIdx), newColumnMappings[mappingIdx][2], 32)
                ImGui.PopItemWidth()
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
            end
        end
        if ImGui.Button('+##mappings') then
            newColumnMappingCount = newColumnMappingCount + 1
            newColumnMappings[newColumnMappingCount] = {[1]='',[2]=''}
        end

        ImGui.Text('Thresholds: ')
        for thresholdIdx, thresholdValue in ipairs(newColumnThresholds) do
            if newColumnThresholds[thresholdIdx] ~= nil then
                ImGui.PushItemWidth(80)
                newColumnThresholds[thresholdIdx], selected = ImGui.InputText('##newcolthresholds1-'..tostring(thresholdIdx), newColumnThresholds[thresholdIdx], 32)
                ImGui.SameLine()
                newColumnThresholds[thresholdIdx], selected = ImGui.InputText('##newcolthresholds2-'..tostring(thresholdIdx), newColumnThresholds[thresholdIdx], 32)
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
        if ImGui.Button('+##thresholds') then
            newColumnThresholdCount = newColumnThresholdCount + 1
            newColumnThresholds[newColumnThresholdCount] = ''
        end

        ImGui.Text('Percentage: ')
        ImGui.SameLine()
        newColumnPercentage, pressed = ImGui.Checkbox('##newcolumnpercent', newColumnPercentage)
        ImGui.Text('Ascending: ')
        ImGui.SameLine()
        newColumnAscending, pressed = ImGui.Checkbox('##newcolumnascending', newColumnAscending)
        ImGui.Text('InZone: ')
        ImGui.SameLine()
        newColumnInZone, pressed = ImGui.Checkbox('##newcolumninzone', newColumnInZone)
    elseif typeRadioValue == 2 then
        ImGui.Text('Action: ')
        ImGui.SameLine()
        newColumnAction, selected = ImGui.InputText('##newcolumnaction', newColumnAction, 32)
    end
    ImGui.Separator()
    if ImGui.Button('Save##newcolumn') then
        print(string.format('Add column: name=%s type=%d percentage=%s ascending=%s inzone=%s action=%s', 
                newColumnName, typeRadioValue, newColumnPercentage, newColumnAscending, newColumnInZone, newColumnAction))
        for i,j in ipairs(newColumnProperties) do
            print(string.format('Column Property %s: %s', j[1], j[2]))
        end
        for i,j in ipairs(newColumnMappings) do
            print(string.format('Column Mapping %s: %s', j[1], j[2]))
        end
        selectedItemType = nil
        typeRadioValue = 1
        newColumnName = ''
        newColumnProperties = {[1]={[1]='',[2]=''}}
        newColumnPropCount = 1
        newColumnMappings = {[1]={[1]='',[2]=''}}
        newColumnMappingCount = 1
        newColumnThresholds = {[1]=''}
        newColumnThresholdCount = 1
        newColumnAction = ''
    end
end

local function DrawColumnSettings()
    local columnSettings = SETTINGS['Columns'][selectedItem]
    if columnSettings ~= nil then
        ImGui.TextColored(1, 0, 1, 1, selectedItem)
        ImGui.Separator()
        if ImGui.SmallButton('Edit##'..selectedItem) then

        end
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..selectedItem) then

        end
        ImGui.Text('Type: ')
        ImGui.SameLine()
        ImGui.TextColored(0, 1, 0, 1, columnSettings['Type'])
        if columnSettings['Properties'] then
        end
        if columnSettings['Thresholds'] then
        end
        if columnSettings['Mappings'] then
        end
        if columnSettings['Percentage'] then
            ImGui.Text('Percentage: ')
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, columnSettings['Percentage'])
        end
        if columnSettings['Ascending'] then
            ImGui.Text('Ascending: ')
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, columnSettings['Ascending'])
        end
        if columnSettings['InZone'] then
            ImGui.Text('InZone: ')
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, columnSettings['InZone'])
        end
        if columnSettings['Action'] then
            ImGui.Text('Action: ')
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, columnSettings['Action'])
        end
    end
end

local function DrawAddTabOptions()
    ImGui.TextColored(1, 0, 1, 1, "Add New Tab")
    ImGui.Separator()
    ImGui.Text('Name: ')
    ImGui.SameLine()
    newTabName, selected = ImGui.InputText('##newtabname', newTabName, 32)
    ImGui.Text('Columns: ')
    for columnIdx, columnName in ipairs(newTabColumns) do
        if newTabColumns[columnIdx] ~= nil then
            newTabColumns[columnIdx], selected = ImGui.InputText('##newtabcolumns'..tostring(columnIdx), newTabColumns[columnIdx], 32)
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
        print(string.format('Add tab: name=%s', newTabName))
        for i,j in ipairs(newTabColumns) do
            print(string.format('Column %s: %s', i, j))
        end
        newTabName = ''
        newTabColumns = {[1]=''}
        newTabColumnCount = 1
        selectedItemType = nil
    end
end

local function DrawTabSettings()
    local tab = SETTINGS['Tabs'][selectedItem]
    if tab then
        ImGui.TextColored(1, 0, 1, 1, tab['Name'])
        ImGui.Separator()
        ImGui.Text('Columns:')
        if tab['Columns'] then
            for columnIdx,column in pairs(tab['Columns']) do
                ImGui.Text(string.format('%d: ', columnIdx))
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, column)
            end
        end
        if ImGui.SmallButton('Edit##'..tab['Name']) then

        end
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..tab['Name']) then

        end
    end
end

local function RightPaneWindow()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("right", x, y-1, true) then
        if selectedItemType == 'settings' then
            ImGui.TextColored(1, 0, 1, 1, 'General Settings')
            ImGui.Separator()
            ImGui.Text('Peer Source: ')
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, SETTINGS['PeerSource'])
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
        end
        ImGui.EndChild()
    end
end

function ConfigurationTab()
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 6, 6)
    LeftPaneWindow()
    --ImGui.PopStyleVar()
    ImGui.SameLine()
    --ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 6, 6)
    RightPaneWindow()
    ImGui.PopStyleVar()
end

return configpanel



--[[
            if ImGui.BeginTabBar('BOXHUDSETTINGSTABS') then                
                if ImGui.BeginTabItem('Properties') then
                    if ImGui.Button('Add Property') then
                        showAddButtonPopup = true
                        typeRadioValue = 1
                        newPropertyName = ''
                        newPropertyDependsOnName = ''
                        newPropertyDependsOnValue = ''
                        newPropertyFromIDProperty = ''
                        ImGui.OpenPopup('##AddPropertyPopup')
                    end
                    if showAddButtonPopup then
                        if ImGui.BeginPopup('##AddPropertyPopup') then
                            ImGui.TextColored(1, 0, 1, 1, "Add New Property")
                            ImGui.Separator()
                            ImGui.Text('Type: ')
                            ImGui.SameLine()
                            typeRadioValue, typeRadioPressed = ImGui.RadioButton("Observed", typeRadioValue, 1)
                            ImGui.SameLine()
                            typeRadioValue, typeRadioPressed = ImGui.RadioButton("NetBots", typeRadioValue, 2)
                            ImGui.SameLine()
                            typeRadioValue, typeRadioPressed = ImGui.RadioButton("Spawn", typeRadioValue, 3)
                            
                            ImGui.Text('Name: ')
                            ImGui.SameLine()
                            newPropertyName, selected = ImGui.InputText('##newpropname', newPropertyName, 32)

                            if typeRadioValue == 1 then
                                ImGui.Text('DependsOnName: ')
                                ImGui.SameLine()
                                newPropertyDependsOnName, selected = ImGui.InputText('##newpropdepname', newPropertyDependsOnName, 32)
                                ImGui.Text('DependsOnValue: ')
                                ImGui.SameLine()
                                newPropertyDependsOnValue, selected = ImGui.InputText('##newpropdepvalue', newPropertyDependsOnValue, 32)
                            elseif typeRadioValue == 3 then
                                ImGui.Text('FromIDProperty: ')
                                ImGui.SameLine()
                                newPropertyFromIDProperty, selected = ImGui.InputText('##newpropfromid', newPropertyFromIDProperty, 32)
                            end
                            ImGui.Separator()
                            if ImGui.Button('Save##newprop') then
                                showAddButtonPopup = false
                                ImGui.CloseCurrentPopup()
                                print(string.format('Add property: type=%d name=%s dependsonname=%s dependsonvalue=%s fromidproperty=%s',
                                        typeRadioValue, newPropertyName, newPropertyDependsOnName, newPropertyDependsOnValue, newPropertyFromIDProperty))
                                typeRadioValue = 1
                                newPropertyName = ''
                                newPropertyDependsOnName = ''
                                newPropertyDependsOnValue = ''
                                newPropertyFromIDProperty = ''
                            end
                            ImGui.EndPopup()
                        end
                    end
                    for propName, propSettings in pairs(SETTINGS['Properties']) do
                        ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
                        if ImGui.TreeNode(propName..'##PropertyTree') then
                            ImGui.PopStyleColor(1)
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
                                ImGui.Text('DependsOnValue: ')
                                ImGui.SameLine()
                                ImGui.TextColored(0, 1, 0, 1, propSettings['FromIDProperty'])
                            end
                            if ImGui.SmallButton('Edit##'..propName) then

                            end
                            ImGui.SameLine()
                            if ImGui.SmallButton('Delete##'..propName) then

                            end
                            ImGui.TreePop()
                        else
                            ImGui.PopStyleColor(1)
                        end
                    end
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem('Columns') then
                    if ImGui.Button('Add Column') then
                        showAddButtonPopup = true
                        ImGui.OpenPopup('##AddColumnPopup')
                    end
                    if showAddButtonPopup then
                        if ImGui.BeginPopup('##AddColumnPopup') then
                            ImGui.TextColored(1, 0, 1, 1, "Add New Column")
                            ImGui.Separator()
                            ImGui.Text('Type: ')
                            ImGui.SameLine()
                            typeRadioValue, typeRadioPressed = ImGui.RadioButton("Property", typeRadioValue, 1)
                            ImGui.SameLine()
                            typeRadioValue, typeRadioPressed = ImGui.RadioButton("Button", typeRadioValue, 2)

                            ImGui.Text('Name: ')
                            ImGui.SameLine()
                            newPropertyName, selected = ImGui.InputText('##newcolumnname', newColumnName, 32)
                            
                            ImGui.Text('Properties: ')
                            ImGui.SameLine()
                            ImGui.Text('placeholder')
                            ImGui.Text('Mappings: ')
                            ImGui.SameLine()
                            ImGui.Text('placeholder')
                            ImGui.Text('Thresholds: ')
                            ImGui.SameLine()
                            ImGui.Text('placeholder')
                            ImGui.Text('Percentage: ')
                            ImGui.SameLine()
                            ImGui.Text('placeholder')
                            ImGui.Text('InZone: ')
                            ImGui.SameLine()
                            ImGui.Text('placeholder')
                            ImGui.Text('Action: ')
                            ImGui.SameLine()
                            ImGui.Text('placeholder')
                            --newPropertyDependsOnName, selected = ImGui.InputText('##newpropdepname', newPropertyDependsOnName, 32)
                            --newPropertyDependsOnValue, selected = ImGui.InputText('##newpropdepvalue', newPropertyDependsOnValue, 32)
                            --newPropertyFromIDProperty, selected = ImGui.InputText('##newpropfromid', newPropertyFromIDProperty, 32)
                            ImGui.Separator()
                            if ImGui.Button('Save##newcolumn') then
                                showAddButtonPopup = false
                                ImGui.CloseCurrentPopup()
                            end
                            ImGui.EndPopup()
                        end
                    end
                    for columnName, columnSettings in pairs(SETTINGS['Columns']) do
                        ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
                        if ImGui.TreeNode(columnName..'##ColumnTree') then
                            ImGui.PopStyleColor(1)
                            ImGui.Text('Type: ')
                            ImGui.SameLine()
                            ImGui.TextColored(0, 1, 0, 1, columnSettings['Type'])
                            if columnSettings['Properties'] then
                            end
                            if columnSettings['Thresholds'] then
                            end
                            if columnSettings['Mappings'] then
                            end
                            if columnSettings['Percentage'] then
                                ImGui.Text('Percentage: ')
                                ImGui.SameLine()
                                ImGui.TextColored(0, 1, 0, 1, columnSettings['Percentage'])
                            end
                            if columnSettings['Ascending'] then
                                ImGui.Text('Ascending: ')
                                ImGui.SameLine()
                                ImGui.TextColored(0, 1, 0, 1, columnSettings['Ascending'])
                            end
                            if columnSettings['InZone'] then
                                ImGui.Text('InZone: ')
                                ImGui.SameLine()
                                ImGui.TextColored(0, 1, 0, 1, columnSettings['InZone'])
                            end
                            if columnSettings['Action'] then
                                ImGui.Text('Action: ')
                                ImGui.SameLine()
                                ImGui.TextColored(0, 1, 0, 1, columnSettings['Action'])
                            end
                            if ImGui.SmallButton('Edit##'..columnName) then

                            end
                            ImGui.SameLine()
                            if ImGui.SmallButton('Delete##'..columnName) then

                            end
                            ImGui.TreePop()
                        else
                            ImGui.PopStyleColor(1)
                        end
                    end
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem('Tabs') then
                    if ImGui.Button('Add Tab') then
                        newTabName = ''
                        newTabColumns = {[1]=''}
                        newTabColumnCount = 1
                        showAddButtonPopup = true
                        ImGui.OpenPopup('##AddTabPopup')
                    end
                    if showAddButtonPopup then
                        if ImGui.BeginPopup('##AddTabPopup') then
                            ImGui.TextColored(1, 0, 1, 1, "Add New Tab")
                            ImGui.Separator()
                            ImGui.Text('Name: ')
                            ImGui.SameLine()
                            newTabName, selected = ImGui.InputText('##newtabname', newTabName, 32)
                            ImGui.Text('Columns: ')
                            for columnIdx, columnName in ipairs(newTabColumns) do
                                if newTabColumns[columnIdx] ~= nil then
                                    newTabColumns[columnIdx], selected = ImGui.InputText('##newtabcolumns'..tostring(columnIdx), newTabColumns[columnIdx], 32)
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
                                showAddButtonPopup = false
                                ImGui.CloseCurrentPopup()
                                print(string.format('Add tab: name=%s', newTabName))
                                for i,j in pairs(newTabColumns) do
                                    print(string.format('Column %s: %s', i, j))
                                end
                                newTabName = ''
                                newTabColumns = {[1]=''}
                                newTabColumnCount = 1
                            end
                            ImGui.EndPopup()
                        end
                    end
                    for _, tab in pairs(SETTINGS['Tabs']) do
                        ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
                        if ImGui.TreeNode(tab['Name']..'##TabTree') then
                            ImGui.PopStyleColor(1)
                            ImGui.Text('Columns:')
                            if tab['Columns'] then
                                for columnIdx,column in pairs(tab['Columns']) do
                                    ImGui.Text(string.format('%d: ', columnIdx))
                                    ImGui.SameLine()
                                    ImGui.TextColored(0, 1, 0, 1, column)
                                end
                            end
                            if ImGui.SmallButton('Edit##'..tab['Name']) then

                            end
                            ImGui.SameLine()
                            if ImGui.SmallButton('Delete##'..tab['Name']) then

                            end
                            ImGui.TreePop()
                        else
                            ImGui.PopStyleColor(1)
                        end
                    end
                    ImGui.EndTabItem()
                end
                ImGui.EndTabBar()
            end
            ImGui.EndTabItem()
--]]