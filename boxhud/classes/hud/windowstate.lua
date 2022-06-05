--[[
Internal runtime settings of a boxhud window, separate from the
static window settings stored in boxhud-settings.lua
--]]
local BaseClass = require 'boxhud.classes.base'
local ConfigurationPanel = require 'boxhud.classes.config.configurationpanel'
require 'boxhud.impl.configurationpanel'
local utils = require 'boxhud.utils.utils'

local WindowState = BaseClass(function(w, name, peerGroup)
    w.name = name
    if peerGroup == 'zone' then
        w.peerGroup = utils.GetZonePeerGroup()
    else
        w.peerGroup = peerGroup
    end
    w.peers = nil
    w.peersDirty = false
    w.sortedPeers = nil
    w.configPanel = ConfigurationPanel(name)
end)

return WindowState