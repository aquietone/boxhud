local Character = require 'boxhud.classes.hud.character'
local WindowState = require 'boxhud.classes.hud.windowstate'
local utils = require 'boxhud.utils.utils'
local state = require 'boxhud.state'

--- @type mq
local mq = require 'mq'
local DanNet = mq.TLO.DanNet
local NetBots = mq.TLO.NetBots

function WindowState:refreshPeers()
    local windowSettings = state.Settings.Windows[self.Name]
    if windowSettings.PeerGroup == 'zone' then
        self.PeerGroup = utils.GetZonePeerGroup()
    elseif windowSettings.PeerGroup == 'group' then
        self.PeerGroup = utils.GetGroupPeerGroup()
    elseif self.PeerGroup ~= windowSettings.PeerGroup then
        self.PeerGroup = windowSettings.PeerGroup
    end
    local t = {}
    if utils.PeerSource == 'dannet' then
        t = utils.Split(DanNet.Peers(self.PeerGroup)())
    else
        for i=1,NetBots.Counts() do
            table.insert(t, NetBots.Client.Arg(i)())
        end
    end

    if not self.Peers or not utils.DoTablesMatch(self.Peers, t) then
        self.Peers = t
        self.PeersDirty = true
    end
    for _,peerName in ipairs(self.Peers) do
        if not state.Characters[peerName] then
            state.Characters[peerName] = Character(peerName,nil)
        end
    end
end
