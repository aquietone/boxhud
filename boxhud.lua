--[[
boxhud.lua 2.3.1 -- aquietone
https://www.redguides.com/community/resources/boxhud-lua-requires-mqnext-and-mq2lua.2088/

Recreates the traditional MQ2NetBots/MQ2HUD based HUD with a DanNet observer
based lua/ImGui UI.

The tabs, columns and contents are all customizable through the included
boxhud-settings.lua file or individual characters boxhud-settings-name.lua files.
See boxhud-settings.lua for more information on configuration options.

The provided boxhud-settings.lua includes some tabs and columns to get started.

Individual character settings files will always take precedence over the default
settings file.
A specific settings file to use can also be passed in as an argument to the script.

Usage:  /lua run boxhud [settings.lua]
        /boxhud    - toggle the UI window
        /boxhudend - end the script
        /bhadmin   - toggle admin mode. Only purpose is to hide the UI so it
                    doesn't error when resetting observers.
        /bhadmin reset toonname - Reset observed properties for the specified toon.
        /bhadmin anon - toggle showing names or class names in the Name column
        /bhhelp    - Display help output
        /bhversion - Display the running version
--]]
--- @type mq
local mq = require 'mq'
--- @type ImGui
require 'ImGui'
local WindowState = require 'boxhud.classes.hud.windowstate'
local ConfigurationPanel = require 'boxhud.classes.config.configurationpanel'
require 'boxhud.impl.window'
require 'boxhud.impl.windowstate'
require 'boxhud.impl.character'
require 'boxhud.impl.property'
require 'boxhud.impl.column'
require 'boxhud.impl.tab'
require 'boxhud.impl.configurationpanel'

local utils = require 'boxhud.utils.utils'
local settings = require 'boxhud.settings.settings'
local state = require 'boxhud.state'

local arg = {...}

-- GUI Control variables
local openGUI = true
local shouldDrawGUI = true
local terminate = false

-- Stores all live observed toon information that will be displayed
local adminMode = false

-- ImGui main function for rendering the UI window
local HUDGUI = function()
    if not openGUI then return end
    for _,window in pairs(state.Settings['Windows']) do
        local flags = 0
        if not window['TitleBar'] then flags = ImGuiWindowFlags.NoTitleBar end
        if window['Transparency'] then flags = bit32.bor(flags, ImGuiWindowFlags.NoBackground) end
        if state.WindowStates[window.Name] and state.WindowStates[window.Name].Peers then
            openGUI, shouldDrawGUI = ImGui.Begin('Box HUD##'..state.MyName..window.Name, openGUI, flags)
            if shouldDrawGUI then
                if ImGui.GetWindowHeight() == 32 and ImGui.GetWindowWidth() == 32 then
                    ImGui.SetWindowSize(460, 177)
                end
                window:drawTabs()
            end
            ImGui.End()
        end
    end
end

local Admin = function(action, name)
    if action == nil then
        adminMode = not adminMode
        openGUI = not adminMode
        print_msg('Setting \ayadminMode\ax = \ay'..tostring(adminMode))
    elseif action == 'anon' then
        state.Anonymize = not state.Anonymize
    elseif action  == 'reset' then
        if not adminMode then
            print_err('\ayadminMode\ax must be enabled')
            return
        end
        if name == nil then
            print_msg('Resetting observed properties for: \ayALL')
            for _,char in pairs(state.Characters) do
                char:manageObservers(true)
                char:manageObservers(false)
            end
        else
            print_msg('Resetting observed properties for: \ay'..name)
            state.Characters[name]:manageObservers(true)
            state.Characters[name]:manageObservers(false)
        end
    end
end

local Help = function()
    print_msg('Available commands:')
    print('\ao    /bhhelp\a-w -- Displays this help output')
    print('\ao    /bhversion\a-w -- Displays the version')
    print('\ao    /boxhud\a-w -- Toggle the display')
    print('\ao    /boxhudend\a-w -- End the script')
    print('\ao    /bhadmin\a-w -- Enable admin mode')
    print('\ao    /bhadmin anon\a-w -- Enable anon mode')
    print('\ao    /bhadmin reset all\a-w -- Reset DanNet Observed Properties for all toons')
    print('\ao    /bhadmin reset <name>\a-w -- Reset DanNet Observed Properties for <name>')
end

local ShowVersion = function()
    print_msg('Version '..state.Version)
end

local function SetupBindings()
    mq.bind('/bhversion', ShowVersion)
    mq.bind('/bhhelp', Help)
    mq.bind('/boxhud', function()
        openGUI = not openGUI
    end)
    mq.bind('/boxhudend', function()
        mq.imgui.destroy('BOXHUDUI')
        shouldDrawGUI = false
        terminate = true
    end)
    mq.bind('/bhadmin', Admin)
end

local function CleanupStaleData(currTime)
    for name, char in pairs(state.Characters) do
        if os.difftime(currTime, char.Properties['lastUpdated']) > state.StaleDataTimeout then
            print_msg('Removing stale toon data: \ay'..name)
            state.Characters[name] = nil
        end
    end
end

local function SendCommand()
    mq.cmd(state.StoredCommand)
    state.StoredCommand = nil
end

local function SetupWindowStates()
    for _,window in pairs(state.Settings['Windows']) do
        state.WindowStates[window.Name] = WindowState(window.Name, window.PeerGroup or utils.GetZonePeerGroup(), ConfigurationPanel(window.Name))
        state.WindowStates[window.Name]:refreshPeers()
    end
end

local function CheckGameState()
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        print_err('\arNot in game, stopping boxhud.\ax')
        openGUI = false
        shouldDrawGUI = false
        mq.imgui.destroy('BOXHUDUI')
        mq.exit()
    end
end

local function main()
    settings.LoadSettings(arg)
    utils.PluginCheck()
    SetupBindings()
    SetupWindowStates()
    mq.imgui.init('BOXHUDUI', HUDGUI)

    -- Initial setup of observers
    if state.IsUsingDanNet then
        for _, char in pairs(state.Characters) do
            char:manageObservers(false)
        end
    end

    -- Main run loop to populate observed property data of toons
    while not terminate do
        CheckGameState()
        if state.StoredCommand then
            SendCommand()
        end
        local currTime = os.time(os.date("!*t"))
        for windowName,window in pairs(state.Settings['Windows']) do
            if not state.WindowStates[windowName] then
                state.WindowStates[windowName] = WindowState(windowName, window.PeerGroup or utils.GetZonePeerGroup(), ConfigurationPanel(windowName))
            end
            state.WindowStates[windowName]:refreshPeers()
            if state.WindowStates[windowName].Peers then
                for _, charName in pairs(state.WindowStates[windowName].Peers) do
                    local char = state.Characters[charName]
                    -- Ensure observers are set for the toon
                    if state.IsUsingDanNet then
                        if state.AdminPeerName == char.Name then
                            char:dannetAdminAction()
                        elseif not char:verifyObservers() then
                            char:manageObservers(false)
                        end
                    end
                    char:updateCharacterProperties(currTime, window['PeerGroup'])
                end
            end
        end
        CleanupStaleData(currTime)
        mq.delay(state.RefreshInterval)
    end
end

main()
