/*
 * Shows upgrades that are currently being upgraded in HUD
 *
 * Author: joojamoi
 *
 * Version history:
 * 0.1:
 *	- Initial version.
 *
 * 0.2:
 *	Fixed bugs:
 *		- Recycling buildings incorrectly shown building is upgrading something.
 *		- Increased hud message time from 10 to 120 to reduce blinking.
 *		- Now it sets empty hud message if player turns off upgrades.
 *
 * 1.0
 *	Added features:
 *		- Shows remaining time until upgrade is complete.
 *		- Info message.
 *
 * 1.0.1
 *	- Small bugfixes
 *
 * 1.0.2
 *      - Removed engine-include and replaced it with fakemeta.
 */

#include <amxmodx>
#include <ns>
#include <fakemeta>

#define PLUGIN_NAME "Upgrade status"
#define PLUGIN_VERSION "1.0.2"

// Are current upgrades shown on default
#define DEFAULT_VALUE true

// Shall we display the info message when player joins marines?
#define SHOW_INFO true

// Update interval (in seconds)
#define UPDATE_INTERVAL 0.5


// How many upgrades are shown at most
#define MAX_UPGRADES_TO_SHOW 5

// HUD-message color
#define R 50
#define G 150
#define B 50

// Who wants to see upgrades on their screen?
new bool:wantsUpgrades[33]

// Who has already seen the info message this round?
new bool:infoShown[33]

public plugin_init() {
	register_plugin(PLUGIN_NAME,PLUGIN_VERSION,"joojamoi")
	if ( !ns_is_combat() && !is_mvm()) {
		reset()
		register_clcmd("say_team /upgradeson", "upgradeson")
		register_clcmd("say /upgradeson", "upgradeson")
		register_clcmd("say_team /upgradesoff", "upgradesoff")
		register_clcmd("say /upgradesoff", "upgradesoff")
		register_event("TeamInfo", "event_teaminfo", "ab")
		set_task(UPDATE_INTERVAL, "showUpgrades", 121212, "", _, "b")
	}
}


/*
 * entity_get_int(id, EV_INT_iuser2) holds information about the current upgrade.
 * Upgrade ids are listed in showUpgrades-function (for example id 33 is for motion tracking).
 * Looks like this value isn't reset to 0 when the upgrade is finished.
 * 
 * entity_get_int(id, EV_INT_iuser4) contains many boolean flags that are masked by a player
 * mask constants enum.
 *
 * entity_get_int(id, EV_FL_fuser1) contains plenty of different information:
 *
 * If structure is still unbuilt, it contains value how much of it has been built.
 * This value is between 0.0 (= 0% finished) and 1000.0 (= 100% finished).
 *
 * If structure is upgrading something, it contains value of how complete the upgrade is.
 * This value is between 2000.0 (= 0% finished) and 3000.0 (= 100% finished).
 *
 * If structure is being recycled, it contains the progress of recycling.
 * This value is between 2000.0 (= 0% finished) and 3000.0 (= 100% finished).
 */


const BUILDING_TYPE_COUNT = 8;

new BUILDING_TYPES[BUILDING_TYPE_COUNT][] = {
	"team_armslab",
	"team_observatory",
	"team_armory",
	"team_advarmory",
	"team_turretfactory",
	"team_advturretfactory",
	"resourcetower",
	"team_prototypelab"
}

public showUpgrades() {
	const MAX_SLOTS = MAX_UPGRADES_TO_SHOW
	new labels[MAX_SLOTS][32]
	new times[MAX_SLOTS]
	new Float:upgradeStates[MAX_SLOTS]
	new currentSlot = 0
	// Iterate over all different building types
	for (new i = 0; i < BUILDING_TYPE_COUNT; ++i) {
		// Find out how many structures of that type exists, iterate over all of them
		new buildcount = ns_get_build(BUILDING_TYPES[i], 0)
		for (new j = 1; j <= buildcount; ++j) {
			// Get entity id of the structure
			new id = ns_get_build(BUILDING_TYPES[i], 0, j)
			
			// Ongoing upgrade can be found from EV_INT_iuser2
			// (this does not reset after upgrade is finished, though)
			new upgradeId = pev(id, pev_iuser2)
			// Generic information about the entity can be found from EV_INT_iuser4
			// This is masked by a player mask constants enum
			new entityInfo = pev(id, pev_iuser4)
			
			new bool:isRecycling = (entityInfo & MASK_RECYCLING) == MASK_RECYCLING
			
			
			// Upgrade's current state can be found from EV_FL_fuser1.
			// Value of 2000.0 means it's 0% done, 3000.0 means it's 100% done.
			// If value is not between 2000.0 and 3000.0, it's not upgrading.
			new Float:upgradeState = (pev(id, pev_fuser1) - 2000.0) / 10.0
			
			if (upgradeState > 0.0 && upgradeState < 100.0 && upgradeId > 0 && !isRecycling) {
				new label[32]
				switch (upgradeId) {
					case 20: { 
						copy(label, 31, "Armor upgrade 1")
						times[currentSlot] = 60
					} case 21: {
						copy(label, 31, "Armor upgrade 2")
						times[currentSlot] = 90
					} case 22: {
						copy(label, 31, "Armor upgrade 3")
						times[currentSlot] = 120
					} case 23: {
						copy(label, 31, "Weapon upgrade 1") 
						times[currentSlot] = 60
					} case 24: {
						copy(label, 31, "Weapon upgrade 2")
						times[currentSlot] = 90
					} case 25: {
						copy(label, 31, "Weapon upgrade 3")
						times[currentSlot] = 120
					} case 47: {
						copy(label, 31, "Catalyst")
						times[currentSlot] = 40
					} case 30: {
						copy(label, 31, "Distress beacon")
						times[currentSlot] = 3
					} case 33: {
						copy(label, 31, "Motion tracking")
						times[currentSlot] = 100
					} case 34: {
						copy(label, 31, "Phase tech")
						times[currentSlot] = 45
					} case 37: {
						copy(label, 31, "Hand grenades")
						times[currentSlot] = 45
					} case 49: {
						copy(label, 31, "Advanced armory")
						times[currentSlot] = 160
					} case 26: {
						copy(label, 31, "Adv. turretfactory")
						times[currentSlot] = 15
					} case 36: {
						copy(label, 31, "Electrical defence")
						times[currentSlot] = 30
					} case 28: {
						copy(label, 31, "Jetpack")
						times[currentSlot] = 75
					} case 29: {
						copy(label, 31, "Heavy armor")
						times[currentSlot] = 110
					} default: {
						format(label, 31, "Unknown upgrade: (id = %i)", upgradeId)
						times[currentSlot] = 0
					}
				}
				
				copy(labels[currentSlot], 31, label)
				upgradeStates[currentSlot] = upgradeState
				++currentSlot
			}
			
			
			if (currentSlot == MAX_SLOTS)
				break
		}
		if (currentSlot == MAX_SLOTS)
			break
	}
	
	const MESSAGELENGTH = (32 + 15)*MAX_SLOTS
	new message[MESSAGELENGTH + 1]
	for (new i = 0; i < currentSlot; ++i) {
		new time = floatround(times[i] * (1.0 - upgradeStates[i] / 100.0), floatround_floor)
		format(message, MESSAGELENGTH, "%s%s: %.1f%%%% (%is)^n", message, labels[i], upgradeStates[i], time)
	}
	
	for ( new i = 1; i <= get_maxplayers(); i++ ) {
		if ( pev(i, pev_team) == 1 && is_user_connected(i) && wantsUpgrades[i]) {
			set_hudmessage(R, G, B, 0.03, 0.70, 0, 6.0, 120.0)
			show_hudmessage(i, message)
		}
	}
}

/*
 * Resets information about who wants to see upgrades
 */
public reset() {
	for (new i = 1; i <= 32; ++i) {
		wantsUpgrades[i] = DEFAULT_VALUE
		infoShown[i] = false
	}
}

/*
 * This is called when player says /upgradeson
 */
public upgradeson(id) {
	wantsUpgrades[id] = true
	return PLUGIN_HANDLED
}

/*
 * This is called when player says /upgradesoff
 */
public upgradesoff(id) {
	if (wantsUpgrades[id]) {
		set_hudmessage(R, G, B, 0.03, 0.70, 0, 6.0, 1.0)
		show_hudmessage(id, "")
	}
	
	wantsUpgrades[id] = false
	return PLUGIN_HANDLED
}

/*
 * This is called when a player disconnects
 */
public client_disconnect(id) {
	wantsUpgrades[id] = DEFAULT_VALUE
	infoShown[id] = false
}

/*
 * This is called when a player joins in a team.
 */
public event_teaminfo() {
	new teamname[32], id = read_data(1)
	read_data(2, teamname, 31)
	if ( SHOW_INFO && !infoShown[id] && equal(teamname, "marine", 6) )
		show_info(id)
}

/*
 * Shows info message to a given player.
 */
public show_info(id) {
	client_print(id, print_chat, "[Upgrade status] say /upgradeson to show or /upgradesoff to hide currently coming upgrades.")
	infoShown[id] = true
}

/*
 * Tells if this game is Marine vs. Marine or not
 */
public is_mvm() {
	new checkcc = ns_get_build("team_command",0, 0)
	if(checkcc > 1) {
		return 1
	} else {
 		return 0
 	}
 	
 	// Compiler didn't believe that if-else statement returns a value in all
 	// cases... Fixing compiler warning.
 	return 0
}
