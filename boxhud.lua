--[[
boxhud.lua 2.2.0 -- aquietone
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
require 'boxhud.impl.window'
require 'boxhud.impl.windowstate'
require 'boxhud.impl.character'

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
    local myname = mq.TLO.Me.CleanName()
    if not myname or myname == 'load' then return end
    if not openGUI then return end
    for _,window in pairs(state.settings['Windows']) do
        local flags = 0
        if not window['TitleBar'] then flags = bit32.bor(flags, ImGuiWindowFlags.NoTitleBar) end
        if window['Transparency'] then flags = bit32.bor(flags, ImGuiWindowFlags.NoBackground) end
        if state.windowStates[window.Name] and state.windowStates[window.Name].peers then
            openGUI, shouldDrawGUI = ImGui.Begin('Box HUD##'..myname..window.Name, openGUI, flags)
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
        state.anonymize = not state.anonymize
    elseif action  == 'reset' then
        if not adminMode then
            print_err('\ayadminMode\ax must be enabled')
            return
        end
        if name == nil then
            print_msg('Resetting observed properties for: \ayALL')
            for _,char in pairs(state.characters) do
                char:manageObservers(true)
                char:manageObservers(false)
            end
        else
            print_msg('Resetting observed properties for: \ay'..name)
            state.characters[name]:manageObservers(true)
            state.characters[name]:manageObservers(false)
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
    print_msg('Version '..utils.version)
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
    for name, char in pairs(state.characters) do
        if os.difftime(currTime, char.properties['lastUpdated']) > utils.stale_data_timeout then
            print_msg('Removing stale toon data: \ay'..name)
            state.characters[name] = nil
        end
    end
end

local function SendCommand()
    mq.cmd(state.storedCommand)
    state.storedCommand = nil
end

local function SetupWindowStates()
    for _,window in pairs(state.settings['Windows']) do
        state.windowStates[window.Name] = WindowState(window.Name, window.PeerGroup or 'zone')
        state.windowStates[window.Name]:refreshPeers()
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
    if utils.IsUsingDanNet() then
        for _, char in pairs(state.characters) do
            char:manageObservers(false)
        end
    end

    -- Main run loop to populate observed property data of toons
    while not terminate do
        CheckGameState()
        if state.storedCommand then
            SendCommand()
        end
        local currTime = os.time(os.date("!*t"))
        for windowName,window in pairs(state.settings['Windows']) do
            if not state.windowStates[windowName] then
                state.windowStates[windowName] = WindowState(windowName, window.PeerGroup or 'zone')
            end
            state.windowStates[windowName]:refreshPeers()
            if state.windowStates[windowName].peers then
                for _, charName in pairs(state.windowStates[windowName].peers) do
                    local char = state.characters[charName]
                    -- Ensure observers are set for the toon
                    if utils.IsUsingDanNet() then
                        if state.resetObserversName == char.name then
                            state.resetObserversName = nil
                            char:manageObservers(true)
                            char:manageObservers(false)
                        elseif not char:verifyObservers() then
                            char:manageObservers(false)
                        end
                    end
                    char:updateCharacterProperties(currTime, window['PeerGroup'])
                end
            end
        end
        CleanupStaleData(currTime)
        mq.delay(utils.refresh_interval)
    end
end

main()
