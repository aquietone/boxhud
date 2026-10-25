# boxhud

A Lua / ImGui boxing HUD for EverQuest.

# Requirements

- MQ
- MQ2Lua
- Either or both of:
  - MQ2DanNet (to use DanNet peers/observers)
  - MQ2EQBC+MQ2NetBots (to use netbots data)

# Installation

Add the `boxhud` folder to the `lua` folder of your MQ directory, or wherever your configured lua path may be.
On first start, you will be prompted to download `lfs.dll` from the MQ luarocks server if it is not already present.

# Usage

Run the script with:

```
/lua run boxhud
```

Stop the script with:
```
/boxhudend
```
or
```
/lua stop boxhud
```

Toggle the window with:

```
/boxhud
```

If a window was closed with its own close button, running `/boxhud` again brings all of the windows back.

Show help output, or the running version:

```
/bhhelp
/bhversion
```

Admin commands. Admin mode hides the window, so it does not error while observers are being reset:

```
/bhadmin                  -- toggle admin mode
/bhadmin reset all        -- reset the DanNet observers for all toons
/bhadmin reset <name>     -- reset the DanNet observers for one toon (name is not case sensitive)
/bhadmin anon             -- toggle showing class names instead of character names
```

# Overview

BoxHUD provides an alternative to a similar [MQ2NetBots/MQ2HUD based HUD](MQ2HUD/README.md). Instead, it uses observed properties from MQ2DanNet to watch various bits of information about all your peers. It is also still possible to use MQ2NetBots values if desired.

The default settings provided Includes the following properties:

General tab:
- Name -- in green if in same zone as the character running the script, in ( ) if invis, in red if not in same zone
- HP% -- with % threshold based coloring, red < 35, yellow < 70, green > 70
- Mana% -- with % threshold based coloring, red < 35, yellow < 70, green > 70.
- Endurance% -- with % threshold based coloring, red < 35, yellow < 70, green > 70.
- Distance -- if character is in same zone, displays distance away from the character, green if dist < 100, yellow < 200, red > 200
- Target -- if character is in same zone, name of their target
- Spell/Disc -- name of spell currently being cast or current running disc

Macro tab:
- Macro Name -- the name of the currently running macro
- Paused -- shows PAUSED if the currently running macro is paused
- Pause macro button -- sends `/dex name /mqp` to the character
- End macro button -- sends `/dex name /end` to the character

XP tab:
- Exp% -- current level experience percentage
- AA Unspent -- current number of unspent AAs

Additionally, the character names are buttons with the following function:
- Left click -- Brings the character to the foreground with `/dex toonname /foreground`.
- Right click -- Opens a context menu with some helpful buttons specific to the selected toon. Also includes a `Send Command` text input which will do `/dex toonname <text input>`

These button actions are more just to play around with the capabilities provided by lua and ImGui. 

Example:

![](images/example-tab1.png)

![](images/example-tab2.png)

![](images/example-tab3.png)

Context menu on Name column:  
![](images/example-popup.png)

Context menu on table:  
![](images/example-tablemenu.png)

Hide columns using the table menu:  
![](images/example-tablehide.png)

Click and drag headers to rearrange table columns:  
![](images/example-tablerearrange.png)

Configuration:  
![](images/example-add-observed.png)

![](images/example-add-column.png)

![](images/example-add-tab.png)

![](images/example-general-settings.png)

![](images/example-save-pending.png)

![](images/example-save-none.png)

![](images/example-height-tall.png)

![](images/example-height-short.png)

The script takes a few seconds to start up as it waits for the DanNet observers to be ready.
Characters which log off or for some reason stop being available will go stale and be removed from the table after 30 seconds.

# Configuration
The configuration is stored in a separate Lua file.

By default, `boxhud-settings.lua` is included with the script, in `boxhud/settings`. Upon startup, if there is no settings file for the character yet, it will be copied to a character specific file `boxhud-settings-charactername.lua` in the **config** folder of your MQ directory.
An existing `boxhud-settings-charactername.lua` will always take precedence over `boxhud-settings.lua`.
A settings filename can also be provided when starting the script like `lua run boxhud boxhud-settings.lua`. That file is also looked up in the config folder.

Boxhud configuration is broken up into 4 main sections: Properties, Columns, Tabs and Windows.

- Properties define what data you want to watch in the HUD. These can include DanNet observed properties, NetBots properties and Spawn properties.
- Columns define the display settings for a given property, such as whether it should only show for toons in the same zone as you, or whether it is a percentage value. They can also be used to define value mappings to display different text based on the value returned for a property.
- Tabs define a group of columns to be displayed together.
- Windows define individual ImGui windows to display, which allows for having separate groups of characters displayed in separate windows.

## Properties
There are 3 types of properties: Observed, NetBots and Spawn.

### Observed properties

```
  Properties = {
    ['Me.PctHPs'] = { 
      ['Name']='Me.PctHPs',
      ['Type']='Observed'
    }
  }
```

Observed properties define a property for which a DanNet observer should be created for each toon, to monitor the value of that property from each toon.

Observing properties which are not defined on a toon can impact running macros. To avoid this, there are some optional settings which can be added to Observed property definitions to define conditions for when to create the observer for a given toon.

```
  Properties = {
    ['CWTN.Mode'] = {
      ['Name']='CWTN.Mode',
      ['Type']='Observed',
      ['DependsOnName']='Me.Class.ShortName',
      ['DependsOnValue']='MNK,ROG,WAR,SHD,MAG,ENC,CLR,BST,SHM'
    }
  }
```

The example above would observe `CWTN.Mode` only on toons whose class is listed in `DependsOnValue`, which are the classes that have CWTN plugins available.

`DependsOnValue` is a comma separated list, matched as plain text and ignoring case. Add `['Inverse']=true` to do the opposite, and observe the property only on toons whose value is **not** in the list.

If an observer cannot be set for a toon, that toon's cell shows `ERR`, a message is printed, and boxhud tries again after 30 seconds. Using `Reset Obs` from the right click menu, the Admin tab, or `/bhadmin reset` retries right away.

### NetBots properties

```
  Properties = {
    ['PctMana'] = {
      ['Name']='PctMana',
      ['Type']='NetBots'
    }
  }
```

NetBots properties define a property to get from NetBots for each toon.

### Spawn properties

```
  Properties = {
    ['Distance3D'] = { Type='Spawn' }
  }
```

Spawn properties define a property to read from the Spawn data for each toon. These will only work for toons that are in the same zone as only they would have Spawn data available.

### Properties summary

All 3 types of properties can be mixed together, provided they have unique names. Combining the 3 example properties above, we would have:

```
  Properties = {
    ['Me.PctHPs'] = { Name='Me.PctHPs', Type='Observed' },
    ['PctMana'] = { Name='PctMana', Type='NetBots' },
    ['Distance3D'] = { Name='Distance3D', Type='Spawn' },
    ['CWTN.Mode'] = {
      Name='CWTN.Mode',
      Type='Observed',
      DependsOnName='Me.Class.ShortName',
      DependsOnValue='MNK,ROG,WAR,SHD,MAG,ENC,CLR,BST,SHM'
    }
  }
```

## Columns
Columns can have two types, `property` or `button`.

### Property Columns
Each property column includes several settings, for example:

```
        ['MP%'] = {
            Type='property'
            Properties={caster='Me.PctMana'},
            Thresholds={35,70},
            Percentage=true,
            Ascending=true,
            InZone=false
        },
```

Each column lists the property or properties which it uses to populate its data.
More details on each setting can be found in the provided `boxhud-settings.lua`.
Note that the `Name` column is treated as a special case.

### Button Columns
Each button column specifies the command to run on click, for example:

```
        {
            Name='Pause',
            Type='button',
            Action='/dex #botName# /mqp'
        },
```

The button `Action` supports replacement of the string `#botName#` with the name of the character in the row where the button exists.

## Tabs
Each tab includes a name and list of columns to be included in that tab, for example:

```
    {
        Name='General',
        Columns={
            {
                'HP%',
                'MP%',
                ...
            }
        }
    },
```

## Windows
Windows include a name and a list of tabs to be shown on the window.

```
    ['default'] = {
        Name='default',
        PeerGroup='zone',
        Tabs={
            'General'
        }
    }
```

`PeerGroup` (MQ2DanNet only) chooses which toons the window shows. It can be:
- `all` -- the DanNet all peer group
- `zone` -- the peer group for the current zone
- `group` -- the DanNet peer group of the EQ group of the character running the script
- any other value is used as the name of a DanNet peer group. Use `/dnet info` to list the groups.

Windows can be added, edited and deleted from the config tab.

### Keeping characters of the same group together
To sort characters by their EQ group, observe `Group.Leader`, add a column for it, and add that column to a tab. Clicking the column header sorts by it, and rows with the same group leader stay together:

```
  Properties = {
    ['Group.Leader'] = { Name='Group.Leader', Type='Observed' }
  }
  Columns = {
    ['Group'] = {
      Name='Group',
      Type='property',
      Properties={all='Group.Leader'},
      InZone=false
    }
  }
```

Some other configuration options include:

## PeerSource
This can be set to **dannet** or **netbots** to specify whether the list of peers to display in the HUD should come from **MQ2DanNet** or **MQ2NetBots**.

## DanNetPeerGroup
This can be set to **all**, **zone** or **group**, or the name of a DanNet peer group. It is used as the peer group of the default window, and each window can also set its own `PeerGroup`.
**Default**: zone

## RefreshInterval
Configure the delay for polling observed properties. Used in `mq.delay()` call.
**Default**: 250 (0.25 seconds)

## StaleDataTimeout
Configure the time in seconds before stale entries are removed from the displayed data.
**Default**: 60 (the provided `boxhud-settings.lua` sets it to 30)

# Extra notes:
- I'm far from (read: not at all) a Lua expert, so don't be too surprised if any Lua best practices haven't been followed here or things could be done in much more clean ways.
- I'm open to suggestions / improvements :)
- This is mostly just written as me wanting to explore some of the possibilities provided by the new Lua support
- This is still very much a work in progress
