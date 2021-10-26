--[[
Stores all information about a given character to be displayed
in a boxhud window.
--]]
local BaseClass = require 'boxhud.classes.base'

local Character = BaseClass(function(b, name, className)
    b.name = name
    b.className = className
    b.properties = nil
end)

return Character