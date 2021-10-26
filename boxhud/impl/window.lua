local Window = require 'boxhud.classes.config.window'
local WindowInput = require 'boxhud.classes.inputs.windowinput'
require 'boxhud.impl.windowstate'
local helpers = require 'boxhud.utils.uihelpers'
local utils = require 'boxhud.utils.utils'
local state = require 'boxhud.state'
local settings = require 'boxhud.settings.settings'
require 'ImGui'

local adminPeerSelected = 0
math.randomseed(os.time())
local tableRandom = math.random(1,100)

local current_sort_specs = {}
local current_columns = {}
local function CompareWithSortSpecs(a, b)
    for n = 1, current_sort_specs.SpecsCount, 1 do
        -- Here we identify columns using the ColumnUserID value that we ourselves passed to TableSetupColumn()
        -- We could also choose to identify columns based on their index (sort_spec.ColumnIndex), which is simpler!
        local sort_spec = current_sort_specs:Specs(n)
        local delta = 0

        local columnName = current_columns[sort_spec.ColumnUserID]
        local column = state.settings['Columns'][columnName]
        if not column then
            return a < b
        end
        local aVal = nil
        local bVal = nil
        if column['Name'] == 'Name' or not column['Properties'] or not column['Properties']['all'] then
            aVal = tostring(a)
            bVal = tostring(b)
        elseif state.characters[a].properties and state.characters[b].properties then
            aVal = tostring(state.characters[a].properties[column['Properties']['all']] or -1)
            bVal = tostring(state.characters[b].properties[column['Properties']['all']] or -1)
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

function Window:drawTableTab(columns, tabName)
    local flags = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Sortable, ImGuiTableFlags.MultiSortable,
            ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.ScrollY, ImGuiTableFlags.NoSavedSettings)
    if ImGui.BeginTable('##bhtable'..tabName..tostring(tableRandom), #columns, flags, 0, 0, 0.0) then
        for i, columnName in ipairs(columns) do
            local column = state.settings['Columns'][columnName]
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
            if sort_specs.SpecsDirty or state.windowStates[self.Name].peersDirty then
                if #state.windowStates[self.Name].peers > 0 then
                    current_sort_specs = sort_specs
                    current_columns = columns
                    state.windowStates[self.Name].sortedPeers = utils.TableClone(state.windowStates[self.Name].peers)
                    table.sort(state.windowStates[self.Name].sortedPeers, CompareWithSortSpecs)
                    current_sort_specs = nil
                    current_columns = nil
                end
                sort_specs.SpecsDirty = false
                state.windowStates[self.Name].peersDirty = false
            end
        end

        -- Display data
        ImGui.TableHeadersRow()
        local clipper = ImGuiListClipper.new()
        if state.windowStates[self.Name].sortedPeers == nil then
            state.windowStates[self.Name].sortedPeers = utils.TableClone(state.windowStates[self.Name].peers)
        end
        clipper:Begin(#state.windowStates[self.Name].sortedPeers)
        while clipper:Step() do
            for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
                local clipName = state.windowStates[self.Name].sortedPeers[row_n+1]
                local char = state.characters[clipName]
                if char and char.properties then
                    ImGui.PushID(clipName)
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    for i,columnName in ipairs(columns) do
                        local column = state.settings['Columns'][columnName]
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

function Window:drawTabs()
    if ImGui.BeginTabBar('BOXHUDTABS##'..self.Name) then
        for _,tabName in ipairs(self.Tabs) do
            local tab = utils.GetTabByName(tabName)
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
        if utils.IsUsingDanNet() then
            if ImGui.BeginTabItem('Admin') then
                ImGui.Text('DanNet Peer Group: ')
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, state.windowStates[self.Name].peerGroup)
                ImGui.Text('Reset Observers for:')
                adminPeerSelected, clicked = ImGui.Combo("##combo", adminPeerSelected, state.windowStates[self.Name].peers, #state.windowStates[self.Name].peers, 5)
                ImGui.SameLine()
                if ImGui.Button('Reset') then
                    print_msg('Resetting observed properties for: \ay'..state.windowStates[self.Name].peers[adminPeerSelected+1])
                    state.resetObserversName = state.windowStates[self.Name].peers[adminPeerSelected+1]
                end
                ImGui.EndTabItem()
            end
        end

        if ImGui.BeginTabItem('Configuration##'..self.Name) then
            state.windowStates[self.Name].configPanel:draw()
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
end

local function TableLength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function WindowInput:toWindow()
    local window  = Window({})
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
    if window.PeerGroup ~= 'all' and window.PeerGroup ~= 'zone' and window.PeerGroup ~= 'group' then
        o.PeerGroup = window.PeerGroup
        o.newPeerGroupSelection = 'other'
    else
        o.newPeerGroupSelection = window.PeerGroup
    end
    for idx,tab in ipairs(window.Tabs) do
        o.Tabs[idx] = tab
    end
    o.TabCount = #window['Tabs']
    return o
end

function WindowInput:draw(width, configPanel)
    ImGui.TextColored(1, 0, 1, 1, "Add New Window")
    ImGui.Separator()
    self.Name = helpers.DrawLabelAndTextInput('Name(*): ', '##newwindowname', self.Name, 'The name of the window to be added.')
    if state.settings['PeerSource'] == 'dannet' then
        if not self.newPeerGroupSelection then self.newPeerGroupSelection = 'all' end
        self.newPeerGroupSelection = helpers.DrawComboBox('Peer Group', self.newPeerGroupSelection, { 'all', 'group', 'zone', 'other' }, false)
        if self.newPeerGroupSelection == 'other' then
            self.PeerGroup = helpers.DrawLabelAndTextInput('Enter a peer group name:', '##peergroup', self.PeerGroup, 'The DanNet Peer Group to source peers from. For a list of groups, use "/dnet info".')
        else
            self.PeerGroup = self.newPeerGroupSelection
        end
    end

    ImGui.Text('Tabs: ')
    ImGui.SameLine()
    helpers.HelpMarker('The list of tabs which will be displayed in the window.')
    for tabIdx, tabName in ipairs(self.Tabs) do
        if self.Tabs[tabIdx] ~= nil then
            local tabNameList = {}
            for _,tab in ipairs(state.settings['Tabs']) do
                table.insert(tabNameList, tab['Name'])
            end
            self.Tabs[tabIdx] = helpers.DrawComboBox("##tabcombo"..tabIdx, self.Tabs[tabIdx], tabNameList, false)
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
            if state.settings.Windows[self.Name] then
                state.settings.Windows[self.Name].Tabs = window.Tabs
                state.settings.Windows[self.Name].PeerGroup = window.PeerGroup
            else
                state.settings.Windows[self.Name] = window
            end
            settings.SaveSettings()
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

function Window:draw(configPanel)
    ImGui.TextColored(1, 0, 1, 1, self.Name)
    ImGui.Separator()
    if ImGui.SmallButton('Edit##'..self.Name) then
        configPanel.newWindow = WindowInput:fromWindow(self)
        configPanel:selectItem(nil, 'addnewwindow')
    end
    if TableLength(state.settings['Windows']) > 1 then
        ImGui.SameLine()
        if ImGui.SmallButton('Delete##'..self.Name) then
            state.settings['Windows'][self.Name] = nil
            settings.SaveSettings()
            configPanel:clearSelection()
        end
    end
    helpers.DrawLabelAndTextValue('Peer Group: ', self.PeerGroup)
    ImGui.Text('Tabs:')
    if self.Tabs then
        for tabIdx,tab in ipairs(self.Tabs) do
            ImGui.Text(string.format('%d: ', tabIdx))
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 0, 1, tab)
        end
    end
end
