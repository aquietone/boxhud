--[[
The TabInput class holds the inputs for creating a new Tab
--]]
local BaseClass = require 'boxhud.classes.base'
local Input = require 'boxhud.classes.inputs.input'
require 'ImGui'

local TabInput = BaseClass(Input(), function(t)
    t.Columns = {[1]='Name'}
    t.ColumnCount = 1
end)

return TabInput