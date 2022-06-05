--[[
Settings file for boxhud.lua script.

- PeerGroup:            DanNet group to load peer data from. Options:
                          - all: The All peer group
                          - zone: The zone_servername_zonename peer group
                        
- RefreshInterval:      Interval to poll observed data (separate from ImGui refresh rate)

- StaleDataTimeout:     Number of seconds before removing stale observed data

- Columns:              Describe the input to each column to be displayed. Fields:
                          - name: (string)        Name of the column
                          - properties: (table)   Table of properties for this column
                                                  Valid keys:
                                                    - all: read this property name for all classes
                                                    - caster: read this property name for caster classes
                                                    - melee: read this property name for melee classes
                                                  caster and melee properties take precedence over all
                          - thresholds: (array)   1 threshold value for red/green coloring, or
                                                  2 threshold values for red/yellow/green coloring
                          - percentage: (boolean) Is the property value a percentage
                          - inzone: (boolean)     Only use this property when BotInZone == true
                          - width: (number)       Column width

- ObservedProperties:   List of properties to create observations for

- SpawnProperties:      List of Spawn properties which are based on spawn data of the observed Me.ID

--]]

return {
    PeerGroup = 'zone',

    RefreshInterval = 250,

    StaleDataTimeout = 60,

    Columns = {
        { 
            Name='Name', 
            Properties=nil, 
            Thresholds=nil, 
            Percentage=false, 
            InZone=false, 
            Width=75 
        },
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
            Properties={caster='Me.PctMana',melee='Me.PctEndurance'}, 
            Thresholds={35,70}, 
            Percentage=true, 
            InZone=false, 
            Width=40 
        },
        --[[
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
        --]]
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
        --[[
        { 
            Name='CombatState', 
            Properties={
                all='Me.CombatState'
            }, 
            Thresholds=nil, 
            Percentage=false, 
            InZone=false, 
            Width=100 
        }
        --]]
    },

    ObservedProperties = {
        -- Mandatory
        {Name='Zone.ID'},
        {Name='Me.ID'},
        {Name='Me.Class'},
        {Name='Me.Invis'},
        -- Column specific
        {Name='Me.PctHPs'},
        {Name='Me.PctMana'},
        {Name='Me.PctEndurance'},
        {Name='Me.Casting.Name'},
        {Name='Me.ActiveDisc.Name'},
        {Name='Target.CleanName'}
        --{Name='Me.CombatState'}
    },

    SpawnProperties = {
        {Name='Distance3D'}
    }
}
