/*
 *   Name: combat_buildings
 *   Updated by: NeoMatrix99.j2
 *   Original Author: #endgame
 *   Version: Theta 5
 *   Plugin Type: AMXX Plugin
 *
 *   Allows the construction of buildings in combat
 *   for both teams. (Must be gorge for alien buildings)
 *   (Must have welder for marine buildings -- This is configurable.)
 *
 *   Commands Provided:
 *   "say_team /buildmenu"
 *   "say /buildmenu"
 *   "say_team buildmenu"
 *   "say buildmenu"
 *   All structures cost 1 level.
 *
 *   Structures Buildable:
 *
 *   Alien:
 *   Defense Chambers
 *   Movement Chambers
 *   Sensory Chambers
 *   Offense Chambers
 *
 *   Marine:
 *   Turret Factory
 *   Sentry Turret
 *   Observatory
 *   Phase Gate
 *   
 *   Thanks To:
 *   Mayhem for providing fixes for cleaning up structures when a player
 *   disconnects or goes to the readyroom and for providing a pseudocode
 *   shell for what became pulse_buildings.
 *
 *   Cheeserm! for extralevels2, which helped me understand menus and handling XP.
 *
 *   Zodiac Mindwarp and the richnet.tv forum regulars for balance help, a server
 *   to test on and constant spam to keep me working.
 *
 *   9 iI IN C IH G IL O C IK of richnet.tv for the first batch of MvM models.
 *
 *   RazorZero of ModNS.org for the per player building limit code.
 *
 *   The buildings spawn on top of you, but you can walk out and the'll fall.
 *   The buildings don't make any special noises or visual effects
 *   when you create them.
 *   
 *   Tested on Windows + Linux Servers using latest Metamod (as of 6/13/08) and Amxmodx 1.8
 *
 */

/* Version History
 * Theta 5 - Jan 6, 2008
 * - Fixed major build exploit and other bugs as a result of this exploit:
 * --o Fixed builders getting points on team rejoin
 * --o Fixed "ghost structures" problem ie. structures that remained behind when someone left the team. They also killed with no name as the attacker (in console says player suicided).
 * - Fixed menu being openable while in ready room.
 * - Fixed marines seeing alien menu.
 * - Removed MvM support.
 * - Changed method of level detection to match Extra Levels 3 defaults. Custom EL3 xp support coming soon.
 * - Added mines to list of things admins can remove.
 *
 * Theta 4 - 26/Feb/2007
 * - Fix stupid bug in pulse_buildings.
 *
 * Theta 3 - 4/Feb/2007
 * - Checks for enough space before dropping the building with trace_hull. No more gorging in vents
 *   and dropping magical sinking chambers.
 *
 * Theta 2 - 2/Feb/2007
 * - Rewrote a couple of functions to prevent compiler warnings.
 *
 * Theta 1 - 28/Jan/2007
 * - Can integrate with mE's "Helper" plugin. This is disabled by default and needs to be enabled
 *   via #define.
 *
 * Eta 5 - 26/Jan/2007
 * - Worked around a bug in ns_get_build - TFs were being electrified before being built.
 *
 * Eta 4 - 26/Jan/2007
 * - Support for siege cannons now included. All turret factories are converted into advanced turret
 *   factories automatically.
 *
 * Eta 2 - 1/Jan/2007
 * - Added support for dual-skinned MvM models.
 * - Removed the message crediting 9 iI IN C IH G IL O C IK because the new-style models
 *   are from WP's mvm_allinone. It is possible to fall back to the old models by setting a #define.
 *
 * Eta 1 - 27/Dec/2006
 * - Fixed handling of orphaned and pre-placed buildings so as to avoid conflicts
 *   with the anti readyroom crash plugin
 *
 * Zeta 8 - 03/Mar/2006
 * - Fixed pre-placed buildings from being removed
 *   in maps such as co_volcanodrop_r1.
 *
 * Zeta 7 - 26/Jan/2006
 * - Swapped options 7 and 9 in the build menu, so recycle is back on option 9.
 * - Typo corrected in build menu.
 *
 * Zeta 6 - 23/Jan/2006
 * - Added new recycling behaviour.
 *   o 'Recycle Last' will remove the last building a player placed.
 *   o 'Recycle All' will remove all buildings a player placed.
 * - The new recycle commands have their own shortcut console commands:
 *   'recycle_last' and 'recycle_all'.
 *
 * Zeta 5 - 15/Jan/2006
 * - Fixed a bug where F4 would cause a player to lose all their buildings.
 *
 * Zeta 4 - 21/Dec/2005
 * - Fixed a bug where this plugin would mess with classic mode.
 *
 * Zeta 3 - 12/Dec/2005
 * - Fixed a bug where per-player building limits failed to work.
 *
 * Zeta 2 - 9/Dec/2005
 * - Fixed a bug where the marine player could build structures without a
 *   welder.
 *
 * Zeta 1 - 21/Sep/2005
 * - It is now possible to set structure limits per player, rather than per team.
 *   Thanks to RazorZero of ModNS.org
 *
 * Epsilon 6 - 7/Sep/2005
 * - The "<player> dropped <building>" messages now display correctly.
 *
 * Epsilon 5 - 6/Sep/2005
 * - admin_probe now returns names like "Turret Factory" instead of entity names
 *   like "team_turretfactory"
 * - When limited buildings are on, each person will be informed when a teammate drops
 *   a building, with the number remaining displayed.
 * - Structure limit defaults tweaked.
 *
 * Epsilon 4 - 6/Sep/2005
 * - New #define option - CBUILD_ENFORCE_LIMITS - enables limit checking.
 * - New limits for structures by cvar.
 *
 * Epsilon 3 - 5/Sep/2005
 * - Observatory CVar was missing, now added.
 *
 * Epsilon 2 - 4/Sep/2005
 * - Exports cb_version for the benefit of server browsers.
 * - Almost all config is now with CVars instead of #defines.
 * - Disabled exploit where digesting marines could build. Thakns to RazorZero of ModNS.org
 *
 * Epsilon 1 - 28/Jul/2005
 * - This version is derived from Gamma 5, to hopefully be stable.
 * - MvM Support, Take 2.
 *
 * Delta 3 - 9/Jul/2005
 * - Changed MvM detection method, to hopefully be more stable.
 *
 * Delta 2 - 1/Jul/2005
 * - Precached additional models required for mvm:
 * "models/marinevsmarine/b_turretfactoryblueT.mdl"
 * "models/marinevsmarine/b_turretfactoryredT.mdl"
 * "models/marinevsmarine/b_sentryblueT.mdl"
 * "models/marinevsmarine/b_sentryredT.mdl"
 * "models/marinevsmarine/b_observatoryblueT.mdl"
 * "models/marinevsmarine/b_observatoryredT.mdl"
 *
 * Delta 1 - 1/Jul/2005
 * - mvm is now supported! Additional models courtesy of 9 iI IN C IH G IL O C IK
 * of richnet.tv
 * Additional model files expected are:
 * "models/marinevsmarine/b_turretfactoryblue.mdl"
 * "models/marinevsmarine/b_turretfactoryred.mdl"
 * "models/marinevsmarine/b_sentryblue.mdl"
 * "models/marinevsmarine/b_sentryred.mdl"
 * "models/marinevsmarine/b_observatoryblue.mdl"
 * "models/marinevsmarine/b_observatoryred.mdl"
 * "models/marinevsmarine/b_phasegateblue.mdl"
 * "models/marinevsmarine/b_phasegatered.mdl"
 * - The mvm support only recolours the additional bulidings. All other mvm is
 *   assumed to be handled by another plugin, like White Panther's mvm_allinone.
 * - If the game is mvm, an extra credit message is displayed for 9 iI IN C IH.
 *
 * Gamma 5 - 25/Jun/2005
 * - Moved the welcome message to an ns_popup rather than a client_print(id,
 *   print_chat,...), because so many plugins spam on print_chat on join.
 * - Added admin_probe - see who built the structure.
 * - Renamed CBUILD_ADMIN_RECYCLE_LEVEL to CBUILD_ADMIN_COMMAND_LEVEL to better
 *   reflect its purpose.
 *
 * Gamma 4
 * - Players can now recycle buildings by looking at them, then activating
 *   recycle on the build menu or console command "recycle".
 * - Build menu now has console command "buildmenu" in addition to the
 *   say_team version.
 * - Buildings are now destroyed properly (i.e. Phasegates don't leave that
 *   annoying glow and hum when the person who built them quits).
 * - Admins can recycle any building that this plugin can drop. Console
 *   command is admin_recycle, and its level is configurable by #define.
 * - Marines now need a welder to build things (can be disabled by #define).
 * - Marines can call in scans either by the buildmenu or by console command
 *   "scan". To do this, the marine needs to have bought the scan upgrade,
 *   and the team must have built an observatory.
 * - Scan spam is limited by a timer.
 * - Headroom checking was removed, I can't see why it caused such problems.
 *
 * Gamma 2,3
 * - Lost the exact changelog, all changes in these versions made it into
 *   the Gamma 4 version.
 *
 * Gamma++:
 * - Fixed the "telefrag the cc" bug, along with blocking building in
 *   places with very little headroom.
 *
 * Gamma:
 * - Fixed a bug where having the buildmenu open when you died let you
 *   drop alien buildings onto the person you were spectating.
 *
 * Beta:
 * - Fixed a bug where disabling electrified TFs cause the code to not compile.
 * - Electrified TFs electrify after they finish building.
 *
 * Alpha:
 * - Initial release.
 */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <ns>

#define CBUILD_VERSION "Theta 5"

#define MARINE 1
#define ALIEN 2

#define MENU_KEYS MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0

// Compile time options

// Set to 0 to use default helper output
// Set to 1 to use the "Helper" plugin! (recommended)
// Note that it is HELPER and not CBUILD_HELPER as per mE's suggested standard
#define HELPER 1

// Set to 0 to have buildings drop as normal.
// Set to 1 to have alien buildings be placed via sticky chambers
#define CBUILD_STICKY_CHAMBERS 1

// Set to 0 to disable
// Set to 1 to enforce per-team structure limits.
// Set to 2 to enforce per-player structure limits.
#define CBUILD_ENFORCE_LIMITS 1

/* Required level to use the admin commands:
 * amx_recycle and amx_probe
 */
#define CBUILD_ADMIN_COMMAND_LEVEL ADMIN_KICK

// How often to allow people to scan
#define CBUILD_SCAN_RATE 10.0

// END OF Compile time options.
// Build limits and the like (anything below this line) is configured with
// a CVAR.

// CVAR related defs
#define CBUILD_VERSION_CVAR "cb_version"

// CVARs for creating buildings: 1 is enable, 0 is disable.
#define CBUILD_DC "cb_dc"
#define CBUILD_MC "cb_mc"
#define CBUILD_SC "cb_sc"
#define CBUILD_OC "cb_oc"

#define CBUILD_TF "cb_tf"
#define CBUILD_ETF "cb_etf" // Electric
#define CBUILD_SIEGE "cb_siege"
#define CBUILD_TURRET "cb_turret"
#define CBUILD_OBS "cb_obs"
#define CBUILD_PG "cb_pg"

// Do marines need welder to build things 1 = yes, 0 = no
#define CBUILD_MARINES_NEED_WELDER "cb_welders"

// How many times the information message will be shown
// The message is shown once per spawn
#define CBUILD_HELPMESSAGECOUNT "cb_help"

// Configure the spacing limits between buildings
#define CBUILD_DC_SPACING "cb_dc_space"
#define CBUILD_MC_SPACING "cb_mc_space"
#define CBUILD_SC_SPACING "cb_sc_space"
#define CBUILD_OC_SPACING "cb_oc_space"
#define CBUILD_TF_SPACING "cb_tf_space"
#define CBUILD_TURRET_SPACING "cb_turret_space"
#define CBUILD_SIEGE_SPACING "cb_siege_space"
#define CBUILD_OBS_SPACING "cb_obs_space"
#define CBUILD_PG_SPACING "cb_pg_space"
#define CBUILD_CC_SPACING "cb_cc_space"
#define CBUILD_ARM_SPACING "cb_arm_space"
#define CBUILD_HIVE_SPACING "cb_hive_space"

// Building limit
#if CBUILD_ENFORCE_LIMITS != 0
	#define CBUILD_DC_LIMIT "cb_dc_limit"
	#define CBUILD_MC_LIMIT "cb_mc_limit"
	#define CBUILD_SC_LIMIT "cb_sc_limit"
	#define CBUILD_OC_LIMIT "cb_oc_limit"

	#define CBUILD_TF_LIMIT "cb_tf_limit"
	#define CBUILD_TURRET_LIMIT "cb_turret_limit"
	#define CBUILD_SIEGE_LIMIT "cb_siege_limit"
	#define CBUILD_OBS_LIMIT "cb_obs_limit"
	#define CBUILD_PG_LIMIT "cb_pg_limit"
#endif

// DO NOT CHANGE - Bits for upgrades bought
#define CBUILD_SCAN 1
#define CBUILD_RECENT_SCAN 2
#define CBUILD_WELDER 4

// How fast to press F4 to go to the readyroom
#define CBUILD_F4_TIMER 2.0

#if CBUILD_STICKY_CHAMBERS == 1
#include <stickychambers>
#endif

#if HELPER == 1
	#include <helper>
#endif

#pragma semicolon 1
#pragma	tabsize		0

new g_structs[33] = 0;
new g_seenHelp[33] = 0;
new g_upgrades[33] = 0; // Bitmask to store bought upgrades
new g_f4ing[33] = 0;
new g_lastBuilding[33] = 0;
new g_maxPlayers;

#if HELPER == 0
	new g_welcomeMessage[180];
	new g_welderMessage[] = "Marines need welders to build.";
	new g_builtWelcomeMessage = 0;
#endif

new g_co = 0;


public plugin_init()
{
	register_plugin("combat_buildings", CBUILD_VERSION, "#endgame / NeoMatrix99.j2");
	register_cvar(CBUILD_VERSION_CVAR, CBUILD_VERSION, FCVAR_SERVER);
	g_co = ns_is_combat();
	if (g_co)
	{
		register_cvar(CBUILD_DC, "1", FCVAR_SERVER);
		register_cvar(CBUILD_MC, "1", FCVAR_SERVER);
		register_cvar(CBUILD_SC, "1", FCVAR_SERVER);
		register_cvar(CBUILD_OC, "1", FCVAR_SERVER);
		register_cvar(CBUILD_TF, "1", FCVAR_SERVER);
		register_cvar(CBUILD_ETF, "1", FCVAR_SERVER);
		register_cvar(CBUILD_TURRET, "1", FCVAR_SERVER);
		register_cvar(CBUILD_SIEGE, "0", FCVAR_SERVER);
		register_cvar(CBUILD_OBS, "1", FCVAR_SERVER);
		register_cvar(CBUILD_PG, "1", FCVAR_SERVER);
		    
		register_cvar(CBUILD_DC_SPACING, "75", FCVAR_SERVER);
		register_cvar(CBUILD_MC_SPACING, "75", FCVAR_SERVER);
		register_cvar(CBUILD_SC_SPACING, "75", FCVAR_SERVER);
		register_cvar(CBUILD_OC_SPACING, "85", FCVAR_SERVER);
		register_cvar(CBUILD_TF_SPACING, "90", FCVAR_SERVER);
		register_cvar(CBUILD_TURRET_SPACING, "85", FCVAR_SERVER);
		register_cvar(CBUILD_SIEGE_SPACING, "75", FCVAR_SERVER);
		register_cvar(CBUILD_OBS_SPACING, "90", FCVAR_SERVER);
		register_cvar(CBUILD_PG_SPACING, "100", FCVAR_SERVER);
		register_cvar(CBUILD_CC_SPACING, "100", FCVAR_SERVER);
		register_cvar(CBUILD_ARM_SPACING, "100", FCVAR_SERVER);
		register_cvar(CBUILD_HIVE_SPACING, "100", FCVAR_SERVER);
	    
		#if CBUILD_ENFORCE_LIMITS != 0
			register_cvar(CBUILD_DC_LIMIT, "3", FCVAR_SERVER);
			register_cvar(CBUILD_MC_LIMIT, "3", FCVAR_SERVER);
			register_cvar(CBUILD_SC_LIMIT, "4", FCVAR_SERVER);
			register_cvar(CBUILD_OC_LIMIT, "12", FCVAR_SERVER);
			register_cvar(CBUILD_TF_LIMIT, "4", FCVAR_SERVER);
			register_cvar(CBUILD_TURRET_LIMIT, "12", FCVAR_SERVER);
			register_cvar(CBUILD_SIEGE_LIMIT, "0", FCVAR_SERVER);
			register_cvar(CBUILD_OBS_LIMIT, "3", FCVAR_SERVER);
			register_cvar(CBUILD_PG_LIMIT, "3", FCVAR_SERVER);
		#endif

		register_cvar(CBUILD_MARINES_NEED_WELDER, "1", FCVAR_SERVER);
		register_cvar(CBUILD_HELPMESSAGECOUNT, "2", FCVAR_SERVER);

		new cc = -1;
		new count;
		while((cc = find_ent_by_class(cc,"team_command")) > 0)
			count++;
		register_clcmd("say_team /buildmenu", "buildMenu", ADMIN_ALL, "Building Menu");
		register_clcmd("say /buildmenu", "buildMenu", ADMIN_ALL, "Building Menu");
		register_clcmd("say_team buildmenu", "buildMenu", ADMIN_ALL, "Building Menu");
		register_clcmd("say buildmenu", "buildMenu", ADMIN_ALL, "Building Menu");
		register_clcmd("buildmenu", "buildMenu", ADMIN_ALL, "Building Menu");
		register_clcmd("recycle", "recycle", ADMIN_ALL, "Recycle");
		register_clcmd("recycle_last", "recycleLast", ADMIN_ALL, "Recycle Last");
		register_clcmd("recycle_all", "removeOwnedStructs", ADMIN_ALL, "Recycle All");
		register_clcmd("readyroom", "f4", ADMIN_ALL, "Ready Room");
		register_clcmd("scan", "callScan", ADMIN_ALL, "Call in a scan");
		register_concmd("amx_recycle", "adminRecycle", CBUILD_ADMIN_COMMAND_LEVEL, "Admin Recycle");
		register_concmd("amx_probe", "adminProbe", CBUILD_ADMIN_COMMAND_LEVEL, "Admin Building Probe");
		register_event("Countdown", "setup_tasks", "a");
		register_event("ResetHUD", "playerSpawned", "b");
		register_impulse(5, "cleanup");
		register_impulse(53, "buyScan");
		register_impulse(62, "buyWelder");
		register_menucmd(register_menuid("Build what?"), MENU_KEYS, "processBuilding");
		for(new i = 0 ; i < 33 ; i++)
		{
			g_structs[i] = 0;
			g_seenHelp[i] = 0;
			g_upgrades[i] = 0;
		}
	}
}

public client_changeteam( id , newteam , oldteam )
{
	if (ns_is_combat())
	{
		if (floatcmp(Float:oldteam, Float:1)|| floatcmp(Float:oldteam, Float:2))
		{
			if ( newteam != oldteam )
			{
				resetserverbuild(id);
				g_structs[id] = 0;
				g_upgrades[id] = 0;
				g_f4ing[id] = 0;
				g_lastBuilding[id] = 0;
				cleanup(id);
			}
			return PLUGIN_HANDLED;
		}
		else
			return PLUGIN_HANDLED;
	}
	return PLUGIN_HANDLED;
}

public f4(id)
{
	if(g_f4ing[id])
		cleanup(id);
	else
	{
		new params[1];
		params[0] = id;
		g_f4ing[id] = 1;
		set_task(CBUILD_F4_TIMER, "abortf4", 0, params, 1);
	}
}

public abortf4(params[], id)
{
	new player = params[0];
	g_f4ing[player] = 0;
}

/* Thanks to mvm_allinone (i.e. White Panther)
 * doing the precache with fakemeta is his thing.
 */


public setup_tasks()
{
	set_task(1.0, "pulse_buildings", 0, "", 0, "b");
	set_task(CBUILD_SCAN_RATE, "pulse_scans", 0, "", 0, "b");
	g_maxPlayers = get_maxplayers();
}

public plugin_precache()
{
	precache_generic("models/ba_defense.mdl");
	precache_generic("models/ba_defenset.mdl");

	precache_generic("models/ba_movement.mdl");
	precache_generic("models/ba_movementt.mdl");

	precache_generic("models/ba_sensory.mdl");
	precache_generic("models/ba_sensoryt.mdl");

	precache_generic("models/ba_offense.mdl");
	precache_generic("models/ba_offenset.mdl");

	precache_generic("models/b_turretfactory.mdl");
	precache_generic("models/b_turretfactoryt.mdl");

	precache_generic("models/b_siege.mdl");
	precache_generic("models/b_sieget.mdl");
	  
	precache_generic("models/b_sentry.mdl");
	precache_generic("models/b_sentryt.mdl");

	precache_generic("models/b_observatory.mdl");
	precache_generic("models/b_observatoryt.mdl");

	precache_generic("models/b_phasegate.mdl");
}

// Get the team for a player
get_team(id)
{
	new class = ns_get_class(id);
	if((class == CLASS_MARINE) || (class == CLASS_JETPACK) || (class == CLASS_HEAVY))
		return MARINE;
	if ((class == CLASS_SKULK || class == CLASS_GORGE || class == CLASS_LERK || class == CLASS_FADE || class == CLASS_ONOS || class == CLASS_GESTATE))
		return ALIEN;
	return 0;
		
}

// Destroy a building
destroy_building(bldg)
{
	fakedamage(bldg, "worldspawn", 3000.0, 1);
	
}

// Test for enough points
enough_points(id)
{
	new points = ns_get_points(id);
	new Float:xp = ns_get_exp(id);
	new currentlevel = (floatround(floatsqroot(xp / 25 + 2.21) - 1));
	new pointstospend = ((currentlevel - 1) - points);
	
	if ( currentlevel > 10 )
		pointstospend = (pointstospend - (currentlevel - 10));
	
	if (pointstospend > 0)
		return 1;
	return 0;
}

// a do_nothing style function
null()
{
	return;
}

// Building distance check
// Given a player id, check all buildings of a classname
// if any are within dist, return 0
// else return 1
bdc(id, class[], Float:dist)
{
	new i;
	new tempEnt;
	new entCount = 0;
	entCount = ns_get_build(class, 0);
	for(i = 1 ; i <= entCount ; i++)
	{
		tempEnt = ns_get_build(class, 0, i);
		if(get_entity_distance(id, tempEnt) < dist)
			return 0;
	}
	return 1;
}

// Main building spacing function
// Call bdc a lot, return 0 if any of them do
// else return 1 (i.e. 1 means OK to build)
building_distance_check(id)
{
	// Alien Buildable
	new dcOK = bdc(id, "defensechamber", get_cvar_float(CBUILD_DC_SPACING));
	if(dcOK == 0) return 0;
	new mcOK = bdc(id, "movementchamber", get_cvar_float(CBUILD_MC_SPACING));
	if(mcOK == 0) return 0;
	new scOK = bdc(id, "sensorychamber", get_cvar_float(CBUILD_SC_SPACING));
	if(scOK == 0) return 0;
	new ocOK = bdc(id, "offensechamber", get_cvar_float(CBUILD_OC_SPACING));
	if(ocOK == 0) return 0;

	// Marine Buildable
	new tfOK = bdc(id, "team_turretfactory", get_cvar_float(CBUILD_TF_SPACING));
	if(tfOK == 0) return 0;
	new atfOK = bdc(id, "team_advturretfactory", get_cvar_float(CBUILD_TF_SPACING));
	if(atfOK == 0) return 0;
	new stOK = bdc(id, "turret", get_cvar_float(CBUILD_TURRET_SPACING));
	if(stOK == 0) return 0;
	new siegeOK = bdc(id, "siegeturret", get_cvar_float(CBUILD_SIEGE_SPACING));
	if(siegeOK == 0) return 0;
	new obsOK = bdc(id, "team_observatory", get_cvar_float(CBUILD_OBS_SPACING));
	if(obsOK == 0) return 0;
	new pgOK = bdc(id, "phasegate", get_cvar_float(CBUILD_PG_SPACING));
	if(pgOK == 0) return 0;

	// Pre Placed
	new ccOK = bdc(id, "team_command", get_cvar_float(CBUILD_CC_SPACING));
	if(ccOK == 0) return 0;
	new armOK = bdc(id, "team_armory", get_cvar_float(CBUILD_ARM_SPACING));
	if(armOK == 0) return 0;
	new hiveOK = bdc(id, "team_hive", get_cvar_float(CBUILD_HIVE_SPACING));
	if(hiveOK == 0) return 0;

	return 1;
}

// Test if near a TF
near_a_tf(id)
{
	new i;
	new tempTF;
	new TFTeam;
	new team = pev(id, pev_team);
	new TFCount = 0;
	TFCount = ns_get_build("team_turretfactory");
	for(i = 1 ; i <= TFCount ; i++)
	{
		tempTF = ns_get_build("team_turretfactory", 1, i);
		TFTeam = pev(tempTF, pev_team);
		if(TFTeam == team)
			if(get_entity_distance(id, tempTF) < 300)
				return 1;
	}
	TFCount = ns_get_build("team_advturretfactory");
	for(i = 1 ; i <= TFCount ; i++)
	{
		tempTF = ns_get_build("team_advturretfactory", 1, i);
		TFTeam = pev(tempTF, pev_team);
		if(TFTeam == team)
			if(get_entity_distance(id, tempTF) < 300)
				return 1;
	}
	return 0;
}

// Test if a team has a functioning observatory
team_has_obs(id)
{
	new i;
	new tempObs;
	new ObsTeam;
	new team = pev(id, pev_team);
	new ObsCount = 0;
	ObsCount = ns_get_build("team_observatory");
	for(i = 1 ; i <= ObsCount ; i++)
	{
		tempObs = ns_get_build("team_observatory", 1, i);
		ObsTeam = pev(tempObs, pev_team);
		if(ObsTeam == team)
			return 1;
	}
	return 0;
}

// Get a real name from the building entity name.
get_building_name(classname[], buildingname[], len)
{
	if(equal(classname, "defensechamber"))
		copy(buildingname, len, "Defense Chamber");
	else if(equal(classname, "movementchamber"))
		copy(buildingname, len, "Movement Chamber");
	else if(equal(classname, "sensorychamber"))
		copy(buildingname, len, "Sensory Chamber");
	else if(equal(classname, "offensechamber"))
		copy(buildingname, len, "Offense Chamber");
	else if(equal(classname, "team_turretfactory"))
		copy(buildingname, len, "Turret Factory");
	else if(equal(classname, "team_advturretfactory"))
		copy(buildingname, len, "Advanced Turret Factory");
	else if(equal(classname, "turret"))
		copy(buildingname, len, "Sentry Turret");
	else if(equal(classname, "siegeturret"))
		copy(buildingname, len, "Siege Cannon");
	else if(equal(classname, "team_observatory"))
		copy(buildingname, len, "Observatory");
	else if(equal(classname, "phasegate"))
		copy(buildingname, len, "Phase Gate");
	else null(); // WTF? Should never get here.
}

#if CBUILD_ENFORCE_LIMITS != 0
	// Get the appropriate building limit cvar
	// from the classname. Len is the maximum number of
	// chars to copy into cvarname (overrun protection)
	get_limit_cvar(classname[], cvarname[], len)
	{
		if(equal(classname, "defensechamber"))
			copy(cvarname, len, CBUILD_DC_LIMIT);
		else if(equal(classname, "movementchamber"))
			copy(cvarname, len, CBUILD_MC_LIMIT);
		else if(equal(classname, "sensorychamber"))
			copy(cvarname, len, CBUILD_SC_LIMIT);
		else if(equal(classname, "offensechamber"))
			copy(cvarname, len, CBUILD_OC_LIMIT);
		else if(equal(classname, "team_turretfactory"))
			copy(cvarname, len, CBUILD_TF_LIMIT);
		else if(equal(classname, "turret"))
			copy(cvarname, len, CBUILD_TURRET_LIMIT);
		else if(equal(classname, "siegeturret"))
			copy(cvarname, len, CBUILD_SIEGE_LIMIT);
		else if(equal(classname, "team_observatory"))
			copy(cvarname, len, CBUILD_OBS_LIMIT);
		else if(equal(classname, "phasegate"))
			copy(cvarname, len, CBUILD_PG_LIMIT);
		else null(); // WTF? Should never get here.
	}
#endif

#if CBUILD_ENFORCE_LIMITS == 1
	// Count structures built by a team
	// Return the number of buildings left if we're allowed to build else 0
	building_limit_ok(player, classname[])
	{
		new team = pev(player, pev_team);
		new count = ns_get_build(classname, 0, 0);
		new buildingCount = 0;
		new tempEnt;
		new cvar[64];
		new limit;
		for(new i = 1 ; i <= count ; i++)
		{
			tempEnt = ns_get_build(classname, 0, i);
			if(pev(tempEnt, pev_team) == team)
				buildingCount++;
		}
		if(equal(classname, "team_turretfactory")){
			count = ns_get_build("team_advturretfactory", 0, 0);	
			for(new i = 1 ; i <= count ; i++)
			{
				tempEnt = ns_get_build("team_advturretfactory", 0, i);
				if(pev(tempEnt, pev_team) == team)
					buildingCount++;
			}
		}
		get_limit_cvar(classname, cvar, 63);
		limit = get_cvar_num(cvar);
		if(limit > buildingCount)
			return (limit - buildingCount);
		return 0;
	}

	// Send out a message to everyone on the same team as id
	send_to_team(id, msg[])
	{
		new team = pev(id, pev_team);
		
		for(new i = 1 ; i <= g_maxPlayers ; i++)
		{
			if(!is_user_connected(i)) continue;
			else
				if(pev(i, pev_team) == team)
					client_print(i, print_chat, msg);
		}
	}
#endif

#if CBUILD_ENFORCE_LIMITS == 2
	// Count structures built by a player
	// Return amount of structures left if we're allowed to build else 0
	building_limit_ok(player, classname[])
	{
		new count = ns_get_build(classname, 0, 0);
		new buildingCount = 0;
		new tempEnt;
		new cvar[64];
		new limit;
		for(new i = 1; i <= count; i++)
		{
			tempEnt = ns_get_build(classname, 0, i);
			if(ns_get_struct_owner(tempEnt) == player)
				buildingCount++;
		}
		if(equal(classname, "team_turretfactory"))
		{
			count = ns_get_build("team_advturretfactory", 0, 0);
			for(new i = 1; i <= count; i++){
			tempEnt = ns_get_build("team_advturretfactory", 0, i);
			if(ns_get_struct_owner(tempEnt) == player)
				buildingCount++;
			}    
		}
		get_limit_cvar(classname, cvar, 63);
		limit = get_cvar_num(cvar);
		if(limit > buildingCount)
			return (limit - buildingCount);
		return 0;
	}
#endif

// Check all the building conditions,
// and actually create the building.
public make_building(id, name[])
{
	if(!is_user_alive(id))
		client_print(id, print_chat, "[Combat_Buildings] You can't build while dead. Sorry.");
	else
	{
		if(enough_points(id))
		{
			if(building_distance_check(id))
			{
				new Float:origin[3];
				entity_get_vector(id, EV_VEC_origin,origin);
				origin[2] += 36;
				// trace_hull call: 1 is human_hull. See if the buliding will fit.
				#if CBUILD_STICKY_CHAMBERS == 1
					if(get_team(id) != ALIEN) // Sticky chambers does its own sanity checking.
				#endif
				if(trace_hull(origin, 1, 1, 1))
				{
					client_print(id, print_chat, "[Combat_Buildings] Not enough room to build here. Sorry.");
					return;
				}
				if((get_team(id) == ALIEN) && (ns_get_class(id) != CLASS_GORGE))
				{
					client_print(id, print_chat, "[Combat_Buildings] You must be a gorge to build things. Sorry.");
					return;
				}
				if(get_cvar_num(CBUILD_MARINES_NEED_WELDER) == 1)
					if((get_team(id) == MARINE) && (!((g_upgrades[id] & CBUILD_WELDER) == CBUILD_WELDER)))
					{
						client_print(id, print_chat, "[Combat_Buildings] You need a welder to build things. Sorry.");
						return;
					}
				// Can't build while being digested. Thanks to RazorZero at ModNS.org
				// This assumes that only gorges can build, and gorges can never get devour.
				// (meaning no changes will be required if/when AvA becomes a reality)
				// (some random server plugins can make this possible)
				if(ns_get_mask(id, MASK_DIGESTING))
				{
					client_print(id, print_chat, "[Combat_Buildings] You can't build while being digested. Sorry.");
					return;
				}
				
				// Server limits
				
				#if CBUILD_ENFORCE_LIMITS != 0
					new buildingsLeft = building_limit_ok(id, name);
					new message[151];
					new player[51];
					new building[51];
					
					if(buildingsLeft == 0)
					{
						client_print(id, print_chat, "[Combat_Buildings] Cannot build due to administrator-set limit. Sorry.");
						return;
					}
					else
					{
						get_user_name(id, player, 50);
						get_building_name(name, building, 50);
						format(message, 150, "[Combat_Buildings] %s dropped %s. %d left.", player, building, buildingsLeft - 1);
					}
				#endif
				new ent;
				#if CBUILD_STICKY_CHAMBERS == 1
				if(get_team(id) == ALIEN){
					if(equal(name, "offensechamber")) ent = SC_CreateChamber(id, IMPULSE_OC);
					else if(equal(name, "defensechamber")) ent = SC_CreateChamber(id, IMPULSE_DC);
					else if(equal(name, "sensorychamber")) ent = SC_CreateChamber(id, IMPULSE_SC);
					else if(equal(name, "movementchamber")) ent = SC_CreateChamber(id, IMPULSE_MC);
					else null();
				}else{
				#endif
				new team = pev(id, pev_team);
				ent = create_entity(name);
				entity_set_origin(ent,origin);
				DispatchSpawn(ent);
				set_pev(ent,pev_team,team); // Use pev(id, pev_team) to get the team and not get_team(id) so MvM works.
				if(equal(name, "team_turretfactory"))
				{
					set_pev(ent, pev_classname, "team_advturretfactory");
					set_pev(ent, pev_iuser3, 49); // 49 is the iuser3 for adv. tf.
				}
				ns_set_struct_owner(ent, id);
				
				#if CBUILD_STICKY_CHAMBERS == 1
				}
				#endif
				if(ent)
				{
					g_lastBuilding[id] = ent;
					g_structs[id]++;
					ns_set_points(id, ns_get_points(id) + 1);
					#if CBUILD_ENFORCE_LIMITS == 1
						send_to_team(id, message);
					#endif
					#if CBUILD_ENFORCE_LIMITS == 2
						client_print(id, print_chat, message);
					#endif
				}
			}
			else
				client_print(id, print_chat, "[Combat_Buildings] Can't build so close to existing structures. Sorry.");
		}
		else
			client_print(id, print_chat, "[Combat_Buildings] You need a point to spend on the structure. Build aborted. Sorry.");
	}
}

// Recycle (i.e. destroy) a building
public recycle(id)
{
	new target;
	new dummy;
	get_user_aiming(id, target, dummy);
	if(is_valid_ent(target))
		if(ns_get_struct_owner(target) == id)
			destroy_building(target);
		else
			client_print(id, print_chat, "[Combat_Buildings] You can only recycle your own buildings.");
	else
		client_print(id, print_chat, "[Combat_Buildings] Look at a building to recycle, then activate the recycle option.");
	return PLUGIN_HANDLED;
}

public is_combat_building(entName[])
{
	return (equal(entName, "team_turretfactory")||
		equal(entName, "team_advturretfactory")||
		equal(entName, "turret")||
		equal(entName, "siegeturret")||
		equal(entName, "team_observatory")||
		equal(entName, "phasegate")||
		equal(entName, "defensechamber")||
		equal(entName, "movementchamber")||
		equal(entName, "sensorychamber")||
		equal(entName, "offensechamber")||
		equal(entName, "item_mine"));
}

// Admin Recycle
public adminRecycle(id, level, cid)
{
	new target;
	new dummy;
	new entName[51];
	if(cmd_access(id, level, cid, 1))
	{
		get_user_aiming(id, target, dummy);
		if(is_valid_ent(target))
		{
			entity_get_string(target, EV_SZ_classname, entName, 50);
			// We don't want them recycling, say, other players
			if(is_combat_building(entName))
				destroy_building(target);
			else
				client_print(id, print_chat, "[Combat_Buildings] You can only recycle deployable buildings.");
		}
		else
			client_print(id, print_chat, "[Combat_Buildings] Look at a building to recycle, then activate the admin recycle option.");
	}
	else
		client_print(id, print_chat, "[Combat_Buildings] Don't try to admin-recycle unless you have access.");
	return PLUGIN_HANDLED;
}

public adminProbe(id, level, cid)
{
	new target;
	new dummy;
	new entName[51];
	new builderID;
	new builder[51];
	new buildingName[51];
	new probe[150];
	if(cmd_access(id, level, cid, 1))
	{
		get_user_aiming(id, target, dummy);
		if(is_valid_ent(target))
		{
			entity_get_string(target, EV_SZ_classname, entName, 50);
			if(is_combat_building(entName))
			{ // Can only probe the bulidables.
				builderID = ns_get_struct_owner(target);
				get_user_name(builderID, builder, 50);
				get_building_name(entName, buildingName, 50);
				format(probe, 149, "Probe Result: Building: %s Builder: %s", buildingName, builder);
				client_print(id, print_chat, probe);
			}
		}
	}
	return PLUGIN_HANDLED;
}

public callScan(id)
{
	if(get_team(id) != MARINE)
		return PLUGIN_HANDLED;
	if(team_has_obs(id))
		if((g_upgrades[id] & CBUILD_SCAN) == CBUILD_SCAN)
			if(!((g_upgrades[id] & CBUILD_RECENT_SCAN) == CBUILD_RECENT_SCAN))
			{
				new Float:origin[3];
				entity_get_vector(id, EV_VEC_origin,origin);
				origin[2] -= 20;
				new ent = create_entity("scan");
				entity_set_origin(ent,origin);
				set_pev(ent, pev_team, pev(id, pev_team));
				DispatchSpawn(ent);
				g_upgrades[id] = g_upgrades[id] | CBUILD_RECENT_SCAN;
				return PLUGIN_HANDLED;
			}
			else
				client_print(id, print_chat, "[Combat_Buildings] Cannot call in scans so frequently.");
		else
			client_print(id, print_chat, "[Combat_Buildings] Cannot call in scans without purchasing the upgrade.");
	else
		client_print(id, print_chat, "[Combat_Buildings] Cannot call in scans without a functioning observatory.");
	return PLUGIN_HANDLED;
}

// Remove all structs of class name owned by id
public removeStructsOfTypeOwnedBy(id, name[])
{
	new count = ns_get_build(name, 0, 0);
	new i;
	new tempEnt;
	
	for(i = 1 ; i <= count ; i++)
	{
		tempEnt = ns_get_build(name, 0, i);
		if(ns_get_struct_owner(tempEnt) == id)
			destroy_building(tempEnt);
	}
}

// Remove all structures owned by a player id
public removeOwnedStructs(id)
{
	removeStructsOfTypeOwnedBy(id, "defensechamber");
	removeStructsOfTypeOwnedBy(id, "movementchamber");
	removeStructsOfTypeOwnedBy(id, "sensorychamber");
	removeStructsOfTypeOwnedBy(id, "offensechamber");
	removeStructsOfTypeOwnedBy(id, "team_turretfactory");
	removeStructsOfTypeOwnedBy(id, "team_advturretfactory");
	removeStructsOfTypeOwnedBy(id, "turret");
	removeStructsOfTypeOwnedBy(id, "siegeturret");
	removeStructsOfTypeOwnedBy(id, "team_observatory");
	removeStructsOfTypeOwnedBy(id, "phasegate");
	g_lastBuilding[id] = 0;
	return PLUGIN_HANDLED;
}

public resetserverbuild(id)
{
	new serverid = -1;
	removeStructsOfTypeOwnedBy(serverid, "defensechamber");
	removeStructsOfTypeOwnedBy(serverid, "movementchamber");
	removeStructsOfTypeOwnedBy(serverid, "sensorychamber");
	removeStructsOfTypeOwnedBy(serverid, "offensechamber");
	removeStructsOfTypeOwnedBy(serverid, "team_turretfactory");
	removeStructsOfTypeOwnedBy(serverid, "team_advturretfactory");
	removeStructsOfTypeOwnedBy(serverid, "turret");
	removeStructsOfTypeOwnedBy(serverid, "siegeturret");
	removeStructsOfTypeOwnedBy(serverid, "team_observatory");
	removeStructsOfTypeOwnedBy(serverid, "phasegate");
	return PLUGIN_HANDLED;
}

public cleanup(id)
{
	g_structs[id] = 0;
	g_upgrades[id] = 0;
	g_f4ing[id] = 0;
	g_lastBuilding[id] = 0;
	removeOwnedStructs(id);
	return PLUGIN_CONTINUE;
}

// Count all structures owned by if with name name
public countStructsOfTypeOwnedBy(id, name[])
{
	new count = ns_get_build(name, 0, 0);
	new i;
	new tempEnt;
	new personalCount = 0;
	for(i = 1 ; i <= count ; i++){
		tempEnt = ns_get_build(name, 0, i);
		if(ns_get_struct_owner(tempEnt) == id)
			personalCount++;
	}
	return personalCount;
}

// Clean up a mess after a DC
public client_disconnect(id)
{
	if(g_co)
	{
		g_seenHelp[id] = 0;
		cleanup(id);
	}
}

// Count all stuctures owned by a player ID
public countOwnedStructs(id)
{
	return countStructsOfTypeOwnedBy(id, "defensechamber") +
		countStructsOfTypeOwnedBy(id, "movementchamber") +
		countStructsOfTypeOwnedBy(id, "sensorychamber") +
		countStructsOfTypeOwnedBy(id, "offensechamber") +
		countStructsOfTypeOwnedBy(id, "team_turretfactory") +
		countStructsOfTypeOwnedBy(id, "team_advturretfactory") +
		countStructsOfTypeOwnedBy(id, "turret") +
		countStructsOfTypeOwnedBy(id, "siegeturret") +
		countStructsOfTypeOwnedBy(id, "team_observatory") +
		countStructsOfTypeOwnedBy(id, "phasegate");
}

public removeBuildingsNearCC()
{
	new tempPG;
	new PGCount = 0;
	new tempCC;
	new CCCount = 0;
	new tempTF;
	new TFCount = 0;
	new tempATF;
	new ATFCount = 0;
	new i;
	new j;
	CCCount = ns_get_build("team_command", 0);
	PGCount = ns_get_build("phasegate", 0);
	TFCount = ns_get_build("team_turretfactory", 0);
	ATFCount = ns_get_build("team_advturretfactory", 0);
	for(i = 1 ; i <= CCCount ; i++)
	{
		tempCC = ns_get_build("team_command", 0, i);
		for(j = 1 ; j <= PGCount ; j++)
		{
			tempPG = ns_get_build("phasegate", 0, j);
			if(get_entity_distance(tempPG, tempCC) <= get_cvar_float(CBUILD_CC_SPACING))
				destroy_building(tempPG);
		}
		for(j = 1 ; j <= TFCount ; j++)
		{
			tempTF = ns_get_build("team_turretfactory", 0, j);
			if(get_entity_distance(tempTF, tempCC) <= get_cvar_float(CBUILD_CC_SPACING))
				destroy_building(tempTF);
		}
		for(j = 1 ; j <= ATFCount ; j++)
		{
			tempATF = ns_get_build("team_advturretfactory", 0, j);
			if(get_entity_distance(tempATF, tempCC) <= get_cvar_float(CBUILD_CC_SPACING))
				destroy_building(tempATF);
		}
	}
}

public buyScan(id)
{
	if((get_team(id) == MARINE) && (enough_points(id)))
		g_upgrades[id] = g_upgrades[id] | CBUILD_SCAN;
	return PLUGIN_CONTINUE;
}

public buyWelder(id)
{
	if((get_team(id) == MARINE) && (enough_points(id)))
		g_upgrades[id] = g_upgrades[id] | CBUILD_WELDER;
	return PLUGIN_CONTINUE;
}

// General maintanance: Electrify any recently completed
// TFs, refund any points from buildings that have been
// destroyed/recycled, and kill any PGs/TFs near the CC.
public pulse_buildings(id)
{
	new count = 0;
	new i;

	removeBuildingsNearCC();

	// Electric TF
	if(get_cvar_num(CBUILD_ETF) == 1){
		new j;
		new tempTF;
		new TFCount;
		TFCount = ns_get_build("team_turretfactory");
		for(j = 1 ; j <= TFCount ; j++)
		{
			tempTF = ns_get_build("team_turretfactory", 1, j);
			set_pev(tempTF, pev_classname, "team_advturretfactory");
			set_pev(tempTF, pev_iuser3, 49); // 49 is the iuser3 for adv. tf.
		}
		TFCount = ns_get_build("team_advturretfactory");
		for(j = 1 ; j <= TFCount ; j++)
		{
			tempTF = ns_get_build("team_advturretfactory", 1, j);
			if(pev(tempTF, pev_fuser1) == 1000) // Hack to check for fully built, adv. TFs seem to always be built.
				set_pev(tempTF, pev_iuser4, pev(tempTF, pev_iuser4)|MASK_ELECTRICITY);
		}
	}

	for(i = 1 ; i <= g_maxPlayers ; i++)
	{
		if(!is_user_connected(i)) continue;
		
		count = countOwnedStructs(i);

		if(count < g_structs[i])
		{
			ns_set_points(i, ns_get_points(i) - g_structs[i] + count);
			g_structs[i] = count;
		}
	}
	return PLUGIN_CONTINUE;
}

public pulse_scans(id)
{
	new i;
	for(i = 1 ; i <= g_maxPlayers ; i++)
		g_upgrades[i] = g_upgrades[i] & ~CBUILD_RECENT_SCAN;
}

// Once a player spawns, show them help
// if they haven't seen it enough
public playerSpawned(id)
{
	#if HELPER == 0
		if(g_seenHelp[id] < get_cvar_num(CBUILD_HELPMESSAGECOUNT))
		{
			g_seenHelp[id]++;
			if(g_builtWelcomeMessage == 0)
			{
				format(g_welcomeMessage, 179, "Server is running Combat_Buildings by #endgame (Version: %s). Say /buildmenu to get the build menu. Aliens must be gorge to build. %s", CBUILD_VERSION, (get_cvar_num(CBUILD_MARINES_NEED_WELDER) == 1 ? g_welderMessage : ""));
				g_builtWelcomeMessage = 1;
			}
			ns_popup(id, g_welcomeMessage);
		#if CBUILD_ENFORCE_LIMITS == 1
			client_print(id, print_chat, "[Combat_Buildings] Per-Team building limits imposed.");
		#endif
		#if CBUILD_ENFORCE_LIMITS == 2
			client_print(id, print_chat, "[Combat_Buildings] Per-Player builing limits imposed. Code by RazorZero of ModNS.org");
		#endif
		}
	#endif
}

#if HELPER == 1
	public client_help(id)
	{
		if(g_co)
		{
			new str[256];
			new marine_build[] = "^nMarines need welders to build.";
			if(get_cvar_num(CBUILD_MARINES_NEED_WELDER) == 0)
				copy(marine_build, 1, "");
			#if CBUILD_ENFORCE_LIMITS == 0
				new limit[] = "";
			#endif
			#if CBUILD_ENFORCE_LIMITS == 1
				new limit[] = "^nPer-team building limits are in force.";
			#endif
			#if CBUILD_ENFORCE_LIMITS == 2
				new limit[] = "^nPer-player building limits are in force.";
			#endif
			format(str, 255, "Players can build buildings on combat maps.^nAliens must be gorge to build.%s%s", marine_build, limit);
			help_add("Information", str);
			help_add("Usage", "Say ^"/buildmenu^" to bring up the building menu.^nConsole commands: ^"scan^", ^"recycle^", ^"recycle_last^", ^"recycle_all^"^nAdmin commands: ^"admin_recycle^", ^"admin_probe^"");
			return PLUGIN_CONTINUE;
		}
		return PLUGIN_HANDLED;
	}

	public client_advertise(id)
	{
		if(g_co)
			return PLUGIN_CONTINUE;
		return PLUGIN_HANDLED;
	}
#endif

// Show the building menu.
// All validity tests are done in make_building (Alien gorge etc.)
public buildMenu(id)
{
	if(!is_user_alive(id))
		client_print(id, print_chat, "[Combat_Buildings] You can't build while dead. Sorry.");
	else{
		new menuText[192];
		if(get_team(id) == MARINE)
		{
			format(menuText, 191, "Build what?^n1. Turret Factory^n2. Sentry Turret^n3. Siege Cannon^n4. Observatory^n5. Phase Gate^n^n6. Call in a scan^n7. Recycle All^n8. Recycle Last^n9. Recycle^n0. Abort");
			show_menu(id, MENU_KEYS, menuText);
		}
		else if(get_team(id) == ALIEN)
		{
			format(menuText, 191, "Build what?^n1. Defense Chamber^n2. Movement Chamber^n3. Sensory Chamber^n4. Offense Chamber^n^n7. Recycle All^n8. Recycle Last^n9. Recycle^n0. Abort");
			show_menu(id, MENU_KEYS, menuText);
		}
	}
	return PLUGIN_HANDLED;
}

// Check that they're not dead.
// If not, check their team and call the appropriate make_building call.
public processBuilding(id, key)
{
	if(get_team(id) == MARINE)
		switch(key)
		{
			case 0: // TF
				if(get_cvar_num(CBUILD_TF) == 1)
					make_building(id, "team_turretfactory");
				else
					client_print(id, print_chat, "[Combat_Buildings] Turret Factories have been disabled by the administrator. Sorry.");
			case 1: // Sentry Turret
				if(near_a_tf(id) == 1)
				{
					if(get_cvar_num(CBUILD_TURRET) == 1)
						make_building(id, "turret");
					else
						client_print(id, print_chat, "[Combat_Buildings] Sentry Guns have been disabled by the administrator. Sorry.");
				}
				else
					client_print(id, print_chat, "[Combat_Buildings] You need to be near a TF to build turrets. Sorry.");
			case 2: // Siege Cannon
				if(near_a_tf(id) == 1)
				{
					if(get_cvar_num(CBUILD_SIEGE) == 1)
						make_building(id, "siegeturret");
					else
						client_print(id, print_chat, "[Combat_Buildings] Siege Cannons have been disabled by the administrator. Sorry.");
				}else
					client_print(id, print_chat, "[Combat_Buildings] You need to be near a TF to build turrets. Sorry.");
			case 3: // Observatory
				if(get_cvar_num(CBUILD_OBS) == 1)
					make_building(id, "team_observatory");
				else
					client_print(id, print_chat, "[Combat_Buildings] Observatories have been disabled by the administrator. Sorry.");
			case 4: // PG
				if(get_cvar_num(CBUILD_PG) == 1)
					make_building(id, "phasegate");
				else
					client_print(id, print_chat, "[Combat_Buildings] Phase Gates have been disabled by the administrator. Sorry.");
			case 5: // Call in scan
				callScan(id);
			case 6: // Recycle All
				removeOwnedStructs(id);
			case 7: // Recycle Last
				recycleLast(id);
			case 8: // Recycle
				recycle(id);
			case 9: // Cancel
				client_print(id, print_chat, "[Combat_Buildings] Build aborted.");
		}
	else
		switch(key)
		{
			case 0: // DC
			if(get_cvar_num(CBUILD_DC) == 1)
				make_building(id, "defensechamber");
			else
				client_print(id, print_chat, "[Combat_Buildings] Defense Chambers have been disabled by the administrator. Sorry.");
			case 1: // MC
			if(get_cvar_num(CBUILD_MC) == 1)
				make_building(id, "movementchamber");
			else
				client_print(id, print_chat, "[Combat_Buildings] Movement Chambers have been disabled by the administrator. Sorry.");
			case 2: // SC
			if(get_cvar_num(CBUILD_SC) == 1)
				make_building(id, "sensorychamber");
			else
				client_print(id, print_chat, "[Combat_Buildings] Sensory Chambers have been disabled by the administrator. Sorry.");
			case 3: // OC
			if(get_cvar_num(CBUILD_OC) == 1)
				make_building(id, "offensechamber");
			else
				client_print(id, print_chat, "[Combat_Buildings] Offense Chambers have been disabled by the administrator. Sorry.");
			case 4: // Obs
			null();
			case 5: // Scans
			null();
			case 6: // Recycle All
			removeOwnedStructs(id);
			case 7: // Recycle Last
			recycleLast(id);
			case 8: // Recycle
			recycle(id);
			case 9: // Cancel
			client_print(id, print_chat, "[Combat_Buildings] Build aborted.");
		}
}

// Delete the last building a player dropped
public recycleLast(id)
{
	new building = g_lastBuilding[id];
	if(building == 0)
	{
		client_print(id, print_chat, "[Combat_Buildings] You have no buildings, or you've recycled your latest already.");
		return PLUGIN_HANDLED;
	}

	if(!is_valid_ent(building))
	{
		client_print(id, print_chat, "[Combat_buildings] Can't find your latest building.");
		return PLUGIN_HANDLED;
	}

	if(ns_get_struct_owner(building) == id)
		destroy_building(building);

	g_lastBuilding[id] = 0;

	return PLUGIN_HANDLED;
}
