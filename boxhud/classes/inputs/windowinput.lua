--[[
The WindowInput class holds the inputs for creating a new Window
--]]
local BaseClass = require 'boxhud.classes.base'
local Input = require 'boxhud.classes.inputs.input'

local WindowInput = BaseClass(Input(), function(w)
    w.PeerGroup = ''
    w.newPeerGroupSelection = nil
    w.Tabs = {}
    w.TabCount = 0
end)

return WindowInput