local Character = require 'boxhud.classes.hud.character'
local WindowState = require 'boxhud.classes.hud.windowstate'
local utils = require 'boxhud.utils.utils'
local state = require 'boxhud.state'

--- @type mq
local mq = require 'mq'
local DanNet = mq.TLO.DanNet
local NetBots = mq.TLO.NetBots

function WindowState:refreshPeers()
    local windowSettings = state.settings.Windows[self.name]
    if windowSettings.PeerGroup == 'zone' then
        self.peerGroup = utils.GetZonePeerGroup()
    elseif windowSettings.PeerGroup == 'group' then
        self.peerGroup = utils.GetGroupPeerGroup()
    elseif self.peerGroup ~= windowSettings.PeerGroup then
        self.peerGroup = windowSettings.PeerGroup
    end
    local t = {}
    if utils.peer_source == 'dannet' then
        t = utils.Split(DanNet.Peers(self.peerGroup)())
    else
        for i=1,NetBots.Counts() do
            table.insert(t, NetBots.Client.Arg(i)())
        end
    end

    if not self.peers or not utils.DoTablesMatch(self.peers, t) then
        self.peers = t
        self.peersDirty = true
    end
    for _,peerName in ipairs(self.peers) do
        if not state.characters[peerName] then
            state.characters[peerName] = Character(peerName,nil)
        end
    end
end
