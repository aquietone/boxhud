--[[
Internal runtime settings of a boxhud window, separate from the
static window settings stored in boxhud-settings.lua
--]]
local BaseClass = require 'boxhud.classes.base'

local WindowState = BaseClass(function(w, name, peerGroup, configPanel)
    w.name = name
    w.peerGroup = peerGroup
    w.peers = nil
    w.peersDirty = false
    w.sortedPeers = nil
    w.configPanel = configPanel
end)

return WindowState