--[[
Internal runtime settings of a boxhud window, separate from the
static window settings stored in boxhud-settings.lua
--]]
local BaseClass = require 'boxhud.classes.base'

local WindowState = BaseClass(function(w, name, peerGroup, configPanel)
    w.Name = name
    w.PeerGroup = peerGroup
    w.Peers = nil
    w.PeersDirty = false
    w.SortedPeers = nil
    w.ConfigPanel = configPanel
end)

return WindowState