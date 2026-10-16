# Kehet's SoundClues

_(beta quality - may not be stable)_

A World of Warcraft addon that plays a sound when a member of your party or raid dies.

## Death alerts

When a group member dies, the addon prints their name in class color and their role to chat, for example `Thrall (Tank) has died!`. Each role has its own sound, so you can tell who died without looking:

- Tank death plays the quest failed sound.
- Healer death plays an angry wisp sound.
- DPS death, or a death with no assigned role, plays the character creation sound.

Feign Death does not trigger an alert.

## Healer drinking alert

When the healer in your group starts to drink, the addon plays Millhouse Manastorm's drinking line. The sound plays once per drink, and only when you are out of combat.

## Leave alert

When a player leaves your party or raid, or is removed from it, the addon prints their name in class color to chat, for example `Thrall has left the group.`, and plays the invite declined sound. Nothing plays when you leave the group yourself or the group disbands.

## Settings

Type `/sc` or `/soundclues` to open the settings window. You can also find the settings in Options > AddOns > Kehet's SoundClues.

You can turn each alert on or off:

- Death alert for tanks
- Death alert for healers
- Death alert for DPS
- Death alert for players with no assigned role
- Healer drinking alert
- Leave alert

All alerts are on by default.

The Messages group has the login message, the death messages and the leave messages in chat. Each message has these settings:

- Show: turn the message on or off.
- Show in: one or more of the chat windows, the error frame, the raid warning frame, the boss emote frame and the floating combat text. Parrot, MikScrollingBattleText, BigWigs and DBM outputs are listed while those addons are loaded.

Mute all messages turns all of them off. Answers to slash commands always print.

## Requirements

- World of Warcraft: Mists of Pandaria Classic
- The [Ace3](https://www.curseforge.com/wow/addons/ace3) addon

## License

Public domain (The Unlicense). See `LICENSE`.
