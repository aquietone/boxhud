local helpers = require 'boxhud.utils.uihelpers'
local utils = require 'boxhud.utils.utils'
local PropertyInput = require 'boxhud.classes.inputs.propertyinput'
local ColumnInput = require 'boxhud.classes.inputs.columninput'
local TabInput = require  'boxhud.classes.inputs.tabinput'
local WindowInput = require 'boxhud.classes.inputs.windowinput'
local ConfigurationPanel = require 'boxhud.classes.config.configurationpanel'
local state = require 'boxhud.state'
local settings = require 'boxhud.settings.settings'
require 'boxhud.impl.property'
require 'boxhud.impl.column'
require 'boxhud.impl.tab'
--- @type ImGui
require 'ImGui'

function ConfigurationPanel:drawDisplaySettingsSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
    self.selected = ImGui.Selectable('Display Settings', self.selectedItemType == 'displaysettings')
    ImGui.PopStyleColor(1)
    if self.selected then
        self:selectItem(nil, 'displaysettings')
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
        for propName, propSettings in pairs(state.settings['Properties']) do
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
        for columnName, columnSettings in pairs(state.settings['Columns']) do
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
        for tabIdx, tab in pairs(state.settings['Tabs']) do
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
        for windowName, window in pairs(state.settings['Windows']) do
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
    if ImGui.BeginChild("left", self.lpanesize, y-1, true) then
        local flags = bit32.bor(ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.ScrollY)
        if ImGui.BeginTable('##configmenu'..self.name, 1, flags, 0, 0, 0.0) then
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            self:drawDisplaySettingsSelector()
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            self:drawPropertiesTreeSelector()
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            self:drawColumnTreeSelector()
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            self:drawTabTreeSelector()
            if utils.peer_source == 'dannet' then
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                self:drawWindowTreeSelector()
            end
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            self:drawAboutSelector()
            
            ImGui.EndTable()
        end
    end
    ImGui.EndChild()
end

function ConfigurationPanel:drawDisplaySettings()
    ImGui.TextColored(1, 0, 1, 1, 'Window Settings')
    ImGui.Separator()
    state.settings.Windows[self.name].Transparency = helpers.DrawCheckBox('Transparent Window: ', '##transparency', state.settings.Windows[self.name].Transparency, 'Check this box to toggle transparency of the window.')
    state.settings.Windows[self.name].TitleBar = helpers.DrawCheckBox('Show Title Bar: ', '##titlebar', state.settings.Windows[self.name].TitleBar, 'Check this box to toggle showing the title bar.')
    ImGui.Separator()
    ImGui.Text('Column Text Colors:')
    state.settings['Colors']['Default'] = helpers.DrawColorEditor("Default Color", state.settings['Colors']['Default'])
    ImGui.SameLine()
    ImGui.SetCursorPosX(175)
    state.settings['Colors']['InZone'] = helpers.DrawColorEditor("Character names in zone", state.settings['Colors']['InZone'])
    state.settings['Colors']['Low'] = helpers.DrawColorEditor("Below Threshold", state.settings['Colors']['Low'])
    ImGui.SameLine()
    ImGui.SetCursorPosX(175)
    state.settings['Colors']['Invis'] = helpers.DrawColorEditor("Invis characters in zone", state.settings['Colors']['Invis'])
    state.settings['Colors']['Medium'] = helpers.DrawColorEditor("Medium Threshold", state.settings['Colors']['Medium'])
    ImGui.SameLine()
    ImGui.SetCursorPosX(175)
    state.settings['Colors']['IVU'] = helpers.DrawColorEditor("IVU characters in zone", state.settings['Colors']['IVU'])
    state.settings['Colors']['High'] = helpers.DrawColorEditor("Above Threshold", state.settings['Colors']['High'])
    ImGui.SameLine()
    ImGui.SetCursorPosX(175)
    state.settings['Colors']['DoubleInvis'] = helpers.DrawColorEditor("Double Invis characters in zone", state.settings['Colors']['DoubleInvis'])
    state.settings['Colors']['True'] = helpers.DrawColorEditor("True values", state.settings['Colors']['True'])
    ImGui.SameLine()
    ImGui.SetCursorPosX(175)
    state.settings['Colors']['NotInZone'] = helpers.DrawColorEditor("Characters not in zone", state.settings['Colors']['NotInZone'])
    state.settings['Colors']['False'] = helpers.DrawColorEditor("False values", state.settings['Colors']['False'])
    ImGui.Separator()
    if ImGui.Button('Save##displaysettings') then
        settings.SaveSettings()
        self:clearSelection()
    end
end

function ConfigurationPanel:drawAbout()
    ImGui.TextColored(1, 0, 1, 1, 'About')
    ImGui.Separator()
    helpers.DrawLabelAndTextValue('Version: ', utils.version)
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
        if self.selectedItemType == 'displaysettings' then
            self:drawDisplaySettings()
        elseif self.selectedItemType == 'addnewproperty' then
            self.newProperty:draw(x, self)
        elseif self.selectedItemType == 'addnewcolumn' then
            self.newColumn:draw(x, self)
        elseif self.selectedItemType == 'addnewtab' then
            self.newTab:draw(x, self)
        elseif self.selectedItemType == 'addnewwindow' then
            self.newWindow:draw(x, self)
        elseif self.selectedItemType == 'property' then
            local property = state.settings['Properties'][self.selectedItem]
            if property then
                property:draw(self)
            end
        elseif self.selectedItemType == 'column' then
            local column = state.settings['Columns'][self.selectedItem]
            if column ~= nil then
                column:draw(self)
            end
        elseif self.selectedItemType == 'tab' then
            local tab = state.settings['Tabs'][self.selectedItem]
            if tab then
                tab:draw(self)
            end
        elseif self.selectedItemType == 'window' then
            local window = state.settings['Windows'][self.selectedItem]
            if window then
                window:draw(self)
            end
        elseif self.selectedItemType == 'about' then
            self:drawAbout()
        else
            self:drawInfo(x)
        end
    end
    ImGui.EndChild()
end

function ConfigurationPanel:drawSplitter(thickness, size0, min_size0)
    local x,y = ImGui.GetCursorPos()
    local delta = 0
    ImGui.SetCursorPosX(x + size0)
    
    ImGui.PushStyleColor(ImGuiCol.Button, 0, 0, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0, 0, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.6, 0.6, 0.1)
    ImGui.Button('##splitter', thickness, -1)
    ImGui.PopStyleColor(3)

    ImGui.SetItemAllowOverlap()

    if ImGui.IsItemActive() then
        delta,_ = ImGui.GetMouseDragDelta()
        
        if delta < min_size0 - size0 then
            delta = min_size0 - size0
        end
        if delta > 275 - size0 then
            delta = 275 - size0
        end

        size0 = size0 + delta
        self.lpanesize = size0
    else
        self.baselpanesize = self.lpanesize
    end
    ImGui.SetCursorPosX(x)
    ImGui.SetCursorPosY(y)
end

function ConfigurationPanel:draw()
    self:drawSplitter(8, self.baselpanesize, 135)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 6, 6)
    self:drawLeftPaneWindow()
    ImGui.PopStyleVar()
    ImGui.SameLine()
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 6, 6)
    self:drawRightPaneWindow()
    ImGui.PopStyleVar()
end
