--[[
Settings file for boxhud.lua script.

- PeerSource:           The source plugin to retrieve peers from. Either:
                          - dannet
                          - netbots

- DanNetPeerGroup:      DanNet group to load peer data from. Options:
  PeerGroup(deprecated)   - all: The All peer group
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
                          - Type: (string)        The type of the column data. May be either:
                                                    - property: content is from an observed or spawn property
                                                    - button: content is a button with user defined action
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
                          - Ascending: (boolean)  Set to true if higher value is better (green)
                                                  For example, PctHPs Ascending=true so 100% hp is green
                          - Inzone: (boolean)     Only use this property when BotInZone == true
                          - Action: (string)      The command to execute if the column type is button

- ObservedProperties:   List of properties to create observations for
                        Properties:
                          - Name: (string)
                          - DependsOnName: (string)  Name of observed property used to check whether this
                                                     observer should be added
                          - DependsOnValue: (string) Acceptable values of the depended upon property
                                                     for this observer to be added

- SpawnProperties:      List of Spawn properties which are based on spawn data of the observed Me.ID
                        Properties:
                          - Name: (string)        Name of the Spawn property
                          - FromIDProperty: (string) Name of ID property to use for spawn search

- NetBotsProperties:    List of NetBots properties to grab
                        Incase ya still want to use some info from MQ2NetBots instead of DanNet

--]]

return {
    PeerSource = 'dannet',
    DanNetPeerGroup = 'zone',

    RefreshInterval = 250,

    StaleDataTimeout = 30,

    -- Global columns to display on all tabs
    Columns = {
        { 
            Name='Name',
            Type='property',
            Properties=nil, 
            Thresholds=nil, 
            Percentage=false, 
            InZone=false
        }
    },

    Tabs = {
        {
            Name='General',
            Columns={
                { 
                    Name='HP%', 
                    Type='property',
                    Properties={all='Me.PctHPs'}, 
                    Thresholds={35,70}, 
                    Percentage=true, 
                    Ascending=true,
                    InZone=false
                },
                { 
                    Name='MP%', 
                    Type='property',
                    Properties={all='Me.PctMana'}, 
                    Thresholds={35,70}, 
                    Percentage=true, 
                    Ascending=true,
                    InZone=false
                },
                { 
                    Name='EP%', 
                    Type='property',
                    Properties={all='Me.PctEndurance'}, 
                    Thresholds={35,70}, 
                    Percentage=true,
                    Ascending=true,
                    InZone=false
                },
                { 
                    Name='Distance', 
                    Type='property',
                    Properties={all='Distance3D'}, 
                    Thresholds={100,200}, 
                    Percentage=false, 
                    Ascending=false,
                    InZone=true
                },
                { 
                    Name='Target', 
                    Type='property',
                    Properties={all='Target.CleanName'}, 
                    Thresholds=nil, 
                    Percentage=false, 
                    InZone=true
                },
                { 
                    Name='Spell/Disc', 
                    Type='property',
                    Properties={
                        all='Me.Casting.Name',
                        melee='Me.ActiveDisc.Name'
                    }, 
                    Thresholds=nil, 
                    Percentage=false, 
                    InZone=false
                }
            }
        },
        {
            Name='Macros',
            Columns = {
                {
                    Name='Macro',
                    Type='property',
                    Properties={
                        all='Macro.Name'
                    },
                    Thresholds=nil,
                    Percentage=false,
                    InZone=false
                },
                {
                    Name='Paused',
                    Type='property',
                    Properties={
                        all='Macro.Paused'
                    },
                    Mappings={
                        TRUE='PAUSED',
                        FALSE=''
                    },
                    Thresholds=nil,
                    Percentage=false,
                    InZone=false
                },
                {
                    Name='Pause',
                    Type='button',
                    Action='/dex #botName# /mqp'
                },
                {
                    Name='End',
                    Type='button',
                    Action='/dex #botName# /end'
                }
                --[[
                {
                    Name='Macro',
                    Type='property',
                    Properties={
                        all='Macro.Name',
                        war='CWTN.Mode',
                        ber='CWTN.Mode',
                        bst='CWTN.Mode',
                        shd='CWTN.Mode',
                        clr='CWTN.Mode',
                        shm='CWTN.Mode',
                        rog='CWTN.Mode'
                    },
                    Thresholds=nil,
                    Percentage=false,
                    InZone=false
                },
                {
                    Name='Paused',
                    Type='property',
                    Properties={
                        all='Macro.Paused',
                        war='CWTN.Paused',
                        ber='CWTN.Paused',
                        bst='CWTN.Paused',
                        shd='CWTN.Paused',
                        clr='CWTN.Paused',
                        shm='CWTN.Paused',
                        rog='CWTN.Paused'
                    },
                    Mappings={
                        TRUE='PAUSED',
                        FALSE=''
                    },
                    Thresholds=nil,
                    Percentage=false,
                    InZone=false
                },
                --]]
            }
        },
        {
            Name='XP',
            Columns = {
                {
                    Name='Exp%',
                    Type='property',
                    Properties={
                        all='Me.PctExp'
                    },
                    Thresholds={33,66},
                    Percentage=true,
                    Ascending=true,
                    InZone=false
                },
                {
                    Name='AA Unspent',
                    Type='property',
                    Properties={
                        all='Me.AAPoints'
                    },
                    Thresholds={50,100},
                    Percentage=false,
                    Ascending=false,
                    InZone=false
                }
            }
        }
        --[[
        {
            Name='Examples',
            Columns = {
                { 
                    Name='CombatState', 
                    Type='property',
                    Properties={
                        all='Me.CombatState'
                    }, 
                    Thresholds=nil, 
                    Percentage=false, 
                    InZone=false
                },
                { 
                    Name='Junk Drink', 
                    Type='property',
                    Properties={
                        all='FindItemCount[=Water Flask]'
                    }, 
                    Thresholds=nil, 
                    Percentage=false, 
                    InZone=false
                },
                { 
                    Name='IVU', 
                    Type='property',
                    Properties={
                        all='Me.Invis[UNDEAD]'
                    }, 
                    Thresholds=nil, 
                    Percentage=false, 
                    InZone=false
                }
            }
        }
        --]]
        --[[
        {
            Name='NetBotsExamples',
            Columns = {
                { 
                    Name='InZone', 
                    Type='property',
                    Properties={
                        all='InZone'
                    }, 
                    Thresholds=nil, 
                    Percentage=false, 
                    InZone=false
                },
                { 
                    Name='Casting', 
                    Type='property',
                    Properties={
                        all='Casting'
                    }, 
                    Thresholds=nil, 
                    Percentage=false, 
                    InZone=false
                },
                { 
                    Name='Invis', 
                    Type='property',
                    Properties={
                        all='Invis'
                    }, 
                    Thresholds=nil, 
                    Percentage=false, 
                    InZone=false
                }
            }
        }
        --]]
    },

    ObservedProperties = {
        -- Column specific
        {Name='Me.Class.ShortName'},
        {Name='Me.PctHPs'},
        {Name='Me.PctMana'},
        {Name='Me.PctEndurance'},
        {Name='Me.Casting.Name'},
        {Name='Me.ActiveDisc.Name'},
        {Name='Target.CleanName'},
        {Name='Macro.Name'},
        {Name='Macro.Paused'},
        {Name='Me.PctExp'},
        {Name='Me.AAPoints'}
        -- Other example properties
        --{
        --    Name='CWTN.Paused', 
        --    DependsOnName='Me.Class.ShortName', 
        --    DependsOnValue='MNK,ROG,WAR,SHD,MAG,ENC,CLR,BST,SHM'
        --},
        --{
        --    Name='CWTN.Mode', 
        --    DependsOnName='Me.Class.ShortName', 
        --    DependsOnValue='MNK,ROG,WAR,SHD,MAG,ENC,CLR,BST,SHM'
        --}
        --{Name='Me.CombatState'}
        --{Name='FindItemCount[=Water Flask]'}
        --{Name='Me.Invis[UNDEAD]'}
    },

    SpawnProperties = {
        {Name='Distance3D'}
    },

    NetBotsProperties = {
        -- Example netbots properties
        --{Name='TargetID'},
        --{Name='InZone'},
        --{Name='Casting'},
        --{Name='Invis'}
    }
}
