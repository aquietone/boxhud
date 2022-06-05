--[[
The ConfigurationPanel class stores the runtime settings of the configuration tab,
including what is selected, and the input objects for creating new configurations.
--]]
local BaseClass = require 'boxhud.classes.base'

local ConfigurationPanel = BaseClass(function(c, name)
    c.name = name
    c.selected = false
    c.selectedItem = nil
    c.selectedItemType = nil
    c.newProperty = nil
    c.newColumn = nil
    c.newTab = nil
    c.newWindow = nil
    c.lpanesize = 200
    c.baselpanesize = 200
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

return ConfigurationPanel