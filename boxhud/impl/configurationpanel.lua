local helpers = require 'boxhud.utils.uihelpers'
local utils = require 'boxhud.utils.utils'
local PropertyInput = require 'boxhud.classes.inputs.propertyinput'
local ColumnInput = require 'boxhud.classes.inputs.columninput'
local TabInput = require  'boxhud.classes.inputs.tabinput'
local WindowInput = require 'boxhud.classes.inputs.windowinput'
local ConfigurationPanel = require 'boxhud.classes.config.configurationpanel'
local state = require 'boxhud.state'
local settings = require 'boxhud.settings.settings'

function ConfigurationPanel:drawDisplaySettingsSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
    self.Selected = ImGui.Selectable('Display Settings', self.SelectedItemType == 'displaysettings')
    ImGui.PopStyleColor(1)
    if self.Selected then
        self:selectItem(nil, 'displaysettings')
    end
end

function ConfigurationPanel:drawPropertiesTreeSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
    if ImGui.TreeNodeEx('Properties', ImGuiTreeNodeFlags.SpanFullWidth) then
        ImGui.PopStyleColor(1)
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        self.Selected = ImGui.Selectable('Add new property...', self.SelectedItemType == 'addnewproperty')
        if self.Selected then
            if self.SelectedItemType ~= 'addnewproperty' then
                self.NewProperty = PropertyInput()
            end
            self:selectItem(nil, 'addnewproperty')
        end
        for propName, propSettings in pairs(state.Settings['Properties']) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            self.Selected = ImGui.Selectable(propName, self.SelectedItem == propName and self.SelectedItemType == 'property')
            if self.Selected then
                self:selectItem(propName, 'property')
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if self.SelectedItemType == 'property' or self.SelectedItemType == 'addnewproperty' then
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
        self.Selected = ImGui.Selectable('Add new column...', self.SelectedItemType == 'addnewcolumn')
        if self.Selected then
            if self.SelectedItemType ~= 'addnewcolumn' then
                self.NewColumn = ColumnInput()
            end
            self:selectItem(nil, 'addnewcolumn')
        end
        for columnName, columnSettings in pairs(state.Settings['Columns']) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            self.Selected = ImGui.Selectable(columnName, self.SelectedItem == columnName and self.SelectedItemType == 'column')
            if self.Selected then
                self:selectItem(columnName, 'column')
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if self.SelectedItemType == 'column' or self.SelectedItemType == 'addnewcolumn' then
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
        self.Selected = ImGui.Selectable('Add new tab...', self.SelectedItemType == 'addnewtab')
        if self.Selected then
            if self.SelectedItemType ~= 'addnewtab' then
                self.NewTab = TabInput()
            end
            self:selectItem(nil, 'addnewtab')
        end
        for tabIdx, tab in pairs(state.Settings['Tabs']) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            self.Selected = ImGui.Selectable(tab['Name'], self.SelectedItem == tabIdx and self.SelectedItemType == 'tab')
            if self.Selected then
                self:selectItem(tabIdx, 'tab')
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if self.SelectedItemType == 'tab' or self.SelectedItemType == 'addnewtab' then
            self:selectItem(nil, nil)
        end
    end
end

function ConfigurationPanel:drawWindowTreeSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
    if ImGui.TreeNodeEx('Windows', ImGuiTreeNodeFlags.SpanAvailWidth) then
        ImGui.PopStyleColor(1)
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        self.Selected = ImGui.Selectable('Add new window...', self.SelectedItemType == 'addnewwindow')
        if self.Selected then
            if self.SelectedItemType ~= 'addnewwindow' then
                self.NewWindow = WindowInput()
            end
            self:selectItem(nil, 'addnewwindow')
        end
        for windowName, _ in pairs(state.Settings['Windows']) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
            self.Selected = ImGui.Selectable(windowName, self.SelectedItem == windowName and self.SelectedItemType == 'window')
            if self.Selected then
                self:selectItem(windowName, 'window')
            end
            ImGui.PopStyleColor(1)
        end
        ImGui.TreePop()
    else
        ImGui.PopStyleColor(1)
        if self.SelectedItemType == 'window' or self.SelectedItemType == 'addnewwindow' then
            self:selectItem(nil, nil)
        end
    end
end

function ConfigurationPanel:drawAboutSelector()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 1, 1)
    self.Selected = ImGui.Selectable('About', self.SelectedItemType == 'about')
    ImGui.PopStyleColor(1)
    if self.Selected then
        self:selectItem(nil, 'about')
    end
end

function ConfigurationPanel:drawLeftPaneWindow()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("left", self.LeftPaneSize, y-1, true) then
        local flags = bit32.bor(ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.ScrollY)
        if ImGui.BeginTable('##configmenu'..self.Name, 1, flags, 0, 0, 0.0) then
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
            if state.PeerSource == 'dannet' then
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
    state.Settings.Windows[self.Name].Transparency = helpers.DrawCheckBox('Transparent Window: ', '##transparency', state.Settings.Windows[self.Name].Transparency, 'Check this box to toggle transparency of the window.')
    state.Settings.Windows[self.Name].TitleBar = helpers.DrawCheckBox('Show Title Bar: ', '##titlebar', state.Settings.Windows[self.Name].TitleBar, 'Check this box to toggle showing the title bar.')
    ImGui.Separator()
    ImGui.Text('Column Text Colors:')
    state.Settings['Colors']['Default'] = helpers.DrawColorEditor("Default Color", state.Settings['Colors']['Default'])
    ImGui.SameLine()
    ImGui.SetCursorPosX(175)
    state.Settings['Colors']['InZone'] = helpers.DrawColorEditor("Character names in zone", state.Settings['Colors']['InZone'])
    state.Settings['Colors']['Low'] = helpers.DrawColorEditor("Below Threshold", state.Settings['Colors']['Low'])
    ImGui.SameLine()
    ImGui.SetCursorPosX(175)
    state.Settings['Colors']['Invis'] = helpers.DrawColorEditor("Invis characters in zone", state.Settings['Colors']['Invis'])
    state.Settings['Colors']['Medium'] = helpers.DrawColorEditor("Medium Threshold", state.Settings['Colors']['Medium'])
    ImGui.SameLine()
    ImGui.SetCursorPosX(175)
    state.Settings['Colors']['IVU'] = helpers.DrawColorEditor("IVU characters in zone", state.Settings['Colors']['IVU'])
    state.Settings['Colors']['High'] = helpers.DrawColorEditor("Above Threshold", state.Settings['Colors']['High'])
    ImGui.SameLine()
    ImGui.SetCursorPosX(175)
    state.Settings['Colors']['DoubleInvis'] = helpers.DrawColorEditor("Double Invis characters in zone", state.Settings['Colors']['DoubleInvis'])
    state.Settings['Colors']['True'] = helpers.DrawColorEditor("True values", state.Settings['Colors']['True'])
    ImGui.SameLine()
    ImGui.SetCursorPosX(175)
    state.Settings['Colors']['NotInZone'] = helpers.DrawColorEditor("Characters not in zone", state.Settings['Colors']['NotInZone'])
    state.Settings['Colors']['False'] = helpers.DrawColorEditor("False values", state.Settings['Colors']['False'])
    ImGui.Separator()
    if ImGui.Button('Save##displaysettings') then
        settings.SaveSettings()
        self:clearSelection()
    end
end

function ConfigurationPanel:drawAbout()
    ImGui.TextColored(1, 0, 1, 1, 'About')
    ImGui.Separator()
    helpers.DrawLabelAndTextValue('Version: ', state.Version)
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
        if self.SelectedItemType == 'displaysettings' then
            self:drawDisplaySettings()
        elseif self.SelectedItemType == 'addnewproperty' then
            self.NewProperty:draw(x, self)
        elseif self.SelectedItemType == 'addnewcolumn' then
            self.NewColumn:draw(x, self)
        elseif self.SelectedItemType == 'addnewtab' then
            self.NewTab:draw(x, self)
        elseif self.SelectedItemType == 'addnewwindow' then
            self.NewWindow:draw(x, self)
        elseif self.SelectedItemType == 'property' then
            local property = state.Settings['Properties'][self.SelectedItem]
            if property then
                property:draw(self)
            end
        elseif self.SelectedItemType == 'column' then
            local column = state.Settings['Columns'][self.SelectedItem]
            if column ~= nil then
                column:draw(self)
            end
        elseif self.SelectedItemType == 'tab' then
            local tab = state.Settings['Tabs'][self.SelectedItem]
            if tab then
                tab:draw(self)
            end
        elseif self.SelectedItemType == 'window' then
            local window = state.Settings['Windows'][self.SelectedItem]
            if window then
                window:draw(self)
            end
        elseif self.SelectedItemType == 'about' then
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
        self.LeftPaneSize = size0
    else
        self.BaseLeftPaneSize = self.LeftPaneSize
    end
    ImGui.SetCursorPosX(x)
    ImGui.SetCursorPosY(y)
end

function ConfigurationPanel:draw()
    self:drawSplitter(8, self.BaseLeftPaneSize, 135)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 6, 6)
    self:drawLeftPaneWindow()
    ImGui.PopStyleVar()
    ImGui.SameLine()
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 6, 6)
    self:drawRightPaneWindow()
    ImGui.PopStyleVar()
end
