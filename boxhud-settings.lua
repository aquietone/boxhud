--[[
Settings file for boxhud.lua script.

- PeerGroup:            DanNet group to load peer data from. Options:
                          - all: The All peer group
                          - zone: The zone_servername_zonename peer group
                        
- RefreshInterval:      Interval to poll observed data (separate from ImGui refresh rate)

- StaleDataTimeout:     Number of seconds before removing stale observed data.
                        This applies to toons which have left the peer group (zoned, logged, etc.)

- Tabs:                 Describe the input to each tab to be displayed. 
                        Properties:
                          - Name: (string)        Name of the tab
                          - Columns: (table)      Columns to display on the tab

- Columns:              Describe the input to each column to be displayed. 
                        Columns defined in the top level Columns setting will appear on all tabs.
                        Columns defined within a specific tab will appear only on that tab.
                        Properties:
                          - Name: (string)        Name of the column
                          - Properties: (table)   Table of properties for this column
                                                  Valid keys:
                                                    - all: read this property name for all classes
                                                    - caster: read this property name for caster classes
                                                    - melee: read this property name for melee classes
                                                  caster and melee properties take precedence over all
                          - Mappings: (table)     Map one value to another. For example, Macro.Paused
                                                  returns TRUE or FALSE, so this could be used to map
                                                  those to PAUSED and "". 
                                                  Does not apply to percentage values.
                          - Thresholds: (array)   1 threshold value for red/green coloring, or
                                                  2 threshold values for red/yellow/green coloring
                          - Percentage: (boolean) Is the property value a percentage
                          - Inzone: (boolean)     Only use this property when BotInZone == true
                          - Width: (number)       Column width

- ObservedProperties:   List of properties to create observations for

- SpawnProperties:      List of Spawn properties which are based on spawn data of the observed Me.ID

--]]

return {
    PeerGroup = 'zone',

    RefreshInterval = 250,

    StaleDataTimeout = 30,

    -- Global columns to display on all tabs
    Columns = {
        { 
            Name='Name', 
            Properties=nil, 
            Thresholds=nil, 
            Percentage=false, 
            InZone=false, 
            Width=80
        }
    },

    Tabs = {
        {
            Name='General',
            Columns={
                { 
                    Name='HP%', 
                    Properties={all='Me.PctHPs'}, 
                    Thresholds={35,70}, 
                    Percentage=true, 
                    InZone=false, 
                    Width=40 
                },
                { 
                    Name='MP%', 
                    Properties={all='Me.PctMana'}, 
                    Thresholds={35,70}, 
                    Percentage=true, 
                    InZone=false, 
                    Width=40 
                },
                { 
                    Name='EP%', 
                    Properties={all='Me.PctEndurance'}, 
                    Thresholds={35,70}, 
                    Percentage=true, 
                    InZone=false, 
                    Width=40 
                },
                { 
                    Name='Distance', 
                    Properties={all='Distance3D'}, 
                    Thresholds={100,200}, 
                    Percentage=false, 
                    InZone=true, 
                    Width=60 
                },
                { 
                    Name='Target', 
                    Properties={all='Target.CleanName'}, 
                    Thresholds=nil, 
                    Percentage=false, 
                    InZone=true, 
                    Width=125 
                },
                --[[
                { 
                    Name='CombatState', 
                    Properties={
                        all='Me.CombatState'
                    }, 
                    Thresholds=nil, 
                    Percentage=false, 
                    InZone=false, 
                    Width=70 
                },
                --]]
                { 
                    Name='Spell/Disc', 
                    Properties={
                        all='Me.Casting.Name',
                        melee='Me.ActiveDisc.Name'
                    }, 
                    Thresholds=nil, 
                    Percentage=false, 
                    InZone=false, 
                    Width=125
                }
            }
        },
        {
            Name='Macros',
            Columns = {
                {
                    Name='Macro',
                    Properties={
                        all='Macro.Name'
                    },
                    Thresholds=nil,
                    Percentage=false,
                    InZone=false,
                    Width=120
                },
                {
                    Name='Paused',
                    Properties={
                        all='Macro.Paused'
                    },
                    Mappings={
                        TRUE='PAUSED',
                        FALSE=''
                    },
                    Thresholds=nil,
                    Percentage=false,
                    InZone=false,
                    Width=60
                }
            }
        },
        {
            Name='XP',
            Columns = {
                {
                    Name='Exp (out of 10,000)',
                    Properties={
                        all='Me.EXP'
                    },
                    Thresholds=nil,
                    Percentage=false,
                    InZone=false,
                    Width=120
                },
                {
                    Name='AA Unspent',
                    Properties={
                        all='Me.AAPoints'
                    },
                    Thresholds=nil,
                    Percentage=false,
                    InZone=false,
                    Width=80
                }
            }
        }
    },

    ObservedProperties = {
        -- Mandatory
        {Name='Me.Class'},
        -- Column specific
        {Name='Me.PctHPs'},
        {Name='Me.PctMana'},
        {Name='Me.PctEndurance'},
        {Name='Me.Casting.Name'},
        {Name='Me.ActiveDisc.Name'},
        {Name='Target.CleanName'},
        {Name='Macro.Name'},
        {Name='Macro.Paused'},
        {Name='Me.Exp'},
        {Name='Me.AAPoints'}
        --{Name='Me.CombatState'}
    },

    SpawnProperties = {
        {Name='Distance3D'}
    }
}
