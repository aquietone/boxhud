--[[
The Input class provides common properties to all input classes
--]]
local BaseClass = require 'boxhud.classes.base'

local Input = BaseClass(function(i)
    i.Name=''
    i.Valid=true
    i.Message=nil
end)

return Input