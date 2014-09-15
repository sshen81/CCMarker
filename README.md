CCMarker
========

CCMarker is a World of Warcraft AddOn that allows party leaders to easily set crowd
control raid icons on targets. It takes into account creature types and party composition
to automatically prioritize crowd control when targeting enemy units. Players are assigned
a specific raid icon and crowd control spell. When CCMarker is enabled, the player simply
selects targets and they will automatically be marked with a raid icon for crowd control
using the best spell/skill available within the party.

## Usage
1. Enable marking by clicking on the CCMarker button or using the "/ccmarker mark" command. When marking is enabled, it will turn green.
2. Begin selecting targets
3. When targetting is completed, disable marking by clicking on the CCMarker button or using the "/ccmarker mark" command
4. Inform your party of their targets & spells using the "/ccmarker targets" command.

## Example
The party contains a warrior, mage, warlock and shaman. Enemy group consists of 2 humanoids and 2 elementals.

The party leader turns on CCMarker and begins targeting enemy units.

CCMarker will automatically assess the party makeup and determine the correct order of
crowd control to be used based on the target enemy type. So, in this scenario, the first
elemental targeted will be marked for banish by the warlock since this is the most powerful
elemental target crowd control spell available. The second elemental targeted will be marked
for bind by the shaman. Finally, the first humanoid targeted will be marked for polymorph
by the mage.

## Commands
* /ccmarker - displays help information
* /ccmarker mark - turns on/off automatic marking
* /ccmarker targets - sends the party's target icon list over chat channel
* /ccmarker show - turns on/off the display of the CCMarker button
* /ccmarker repentance on|off - enables/disables Paladin's Repentance as an available CC spell since it may not be available depending on the class talent tree
* /ccmarker wyvern on|off - enables/disables Hunter's Wyvern Sting as an available CC spell since it may not be available depending on the class talent tree

## Installation
Extract the CCMarker folder in your ../World of Warcraft/Interface/Addons/ folder.
