version=1.0.0

# Convergence Paladin Bot Command Guide

### Start Script
- Command: `/lua run ConvPAL`
- Description: Starts the Lua script Convergence Paladin.

## General Bot Commands
These commands control general bot functionality, allowing you to start, stop, or save configurations.

### Toggle Bot On/Off
- Command: `/ConvPAL Bot on/off`
- Description: Enables or disables the bot for automated functions.

### Toggle Exit
- Command: `/ConvPAL Exit`
- Description: Closes the bot and script.

### Save Settings
- Command: `/ConvPAL Save`
- Description: Saves the current settings, preserving any configuration changes.

---

## Camp and Navigation
These commands control camping behavior and movement options.

### Set Camp Location
- Command: `/ConvPAL CampHere on/off/<distance>`
- Description: Sets the current location as the designated camp location, enables or disables return to camp, or sets a camp distance.
- Usage: `/ConvPAL CampHere 50` sets a 50-unit radius camp.

### Toggle Chase Mode
- Command: `/ConvPAL Chase <target> <distance>` or `/ConvPAL Chase on/off`
- Description: Sets a target and distance for the bot to chase, or toggles chase mode.
- Example: `/ConvPAL Chase John 30` will set the character John as the chase target at a distance of 30.
- Example: `/ConvPAL Chase off` will turn chasing off.

---

## Combat and Assist Commands
These commands control combat behaviors, including melee assistance and target positioning.

### Set Assist Mode
- Command: `/ConvPAL Assist on/off` or `/ConvPAL Assist <range> <percent>`
- Description: Toggles assist mode on or off, or configures assist mode with a specified range and health percentage threshold.
- Examples:
  - `/ConvPAL Assist on`: Enables assist mode.
  - `/ConvPAL Assist off`: Disables assist mode.
  - `/ConvPAL Assist 50 75`: Sets assist range to 50 and assist health threshold to 75%.

### Set Tank Mode
- Command: `/ConvPAL Tank on/off` or `/ConvPAL TankRange <range>`
- Description: Toggles tank mode on or off, or defines the tank's engagement range.
- Examples:
  - `/ConvPAL Tank on`: Enables tank mode.
  - `/ConvPAL Tank off`: Disables tank mode.
  - `/ConvPAL TankRange 30`: Sets the tank range to 30.

### Set Buffs On
- Command: `/ConvPAL BuffsOn on/off`
- Description: Enables or disables buffs.

### Toggle Sit to Meditate
- Command: `/ConvPAL SitMed on/off`
- Description: Enables or disables sitting to meditate.

### Set Stick Position (Front/Behind)
- Command: `/ConvPAL Melee front/behind <distance>`
- Description: Configures the bot to stick to the front or back of the target and specifies a stick distance.
- Example: `/ConvPAL Melee front 10`

### Set Switch With Main Assist
- Command: `/ConvPAL SwitchWithMA on/off`
- Description: Enables or disables switching targets with the main assist.

---

## Pulling and Mob Control
These commands manage mob pulling and control within the camp area.

### Tank Ignore List Control
- Command: `/ConvPAL TankIgnore zone/global add/remove`
- Description: Adds or removes the target to/from the tank ignore list, either zone-specific or global.