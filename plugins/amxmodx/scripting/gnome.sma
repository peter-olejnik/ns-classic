/*
* Plugin: Gnome Builder
*
* Features:
*	-> gnome model
*	-> speed, armor, health changes
*	-> double speed build/weld (-attack)
*	-> crazy knockback on hit
*	-> not allowed to pick/get HA/JP/heavy weapons
*	-> uses resized weapons
*	-> commander can gnome and ungnome people
*	-> cant move further than defined Commchair radius
*	-> gnome self-welding (look at feet and weld)
*	-> gnome cant go commander (only if only alive player he can)
*
* Author:
*	-> White Panther, Zamma
*
* Modeler:
*	-> Depot (ds^Depot)
*
* Tester:
*	-> Depot (ds^Depot), White Panther
*
* Credits:
*	-> -mE-		-	for teleport effect
*	-> esuna	-	for the pick model
*
* Usage:
*	COMMANDS:
*		- amx_gnome <on / off OR 1 / 0>		-> turns Gnome on and off
*		- amx_gnome_make <name>			-> specified player becomes gnome, no name = random player
*		- amx_ungnome				-> all Gnomes become normal players
*	CHAT:
*		- in chat say "/gnomeme" or "/gnome me" to become a gnome
*		- in chat say "/ungnomeme" or "/ungnome me" to become normal marine (only if the only player)
*		- if commander: say "/gnome <username>", player with username becomes gnome
*			say "/ungnome", player who is gnome will become normal marine
*	
*	CVARS:
*		- mp_gnome_damage_amplifier	-> damage multiplier for gnome weapons (default 3.0)
*		- mp_gnome_damage_pick_only	-> define if only pick gets damage multiplier (default on)
*		- mp_gnome_auto			-> defines if gnome if automatically created on countdown (default off)
*
* v0.3.3:
*	- initial release
*
* v0.4.2:
*	- fixed:
*		- possiblity of regaining normal speed after death
*		- "/ungnome" needed a name
*		- double weld/build working correctly (its double now not only a bit faster)
*		- new random gnome could have ha/jp/heavy weapons
*		- camera view is adjusted to gnome height
*		- getting resuply while being digested
*		- gnome could respawn with hmg/gl/shotty in combat
*	- added:
*		- welding people is now at double speed/damage too
*		- gnome cannot get out of commchair radius (you can increase with new Commchairs)
*		- gnome self-welding
*
* v0.5.1:
*	- fixed:
*		- acidrocket and spit have not done knockback
*		- parasite / spike / spore did knockback
*		- gnomes pick does more damage (default twice)
*		- med packs are now only picked up if needed
*		- when gnomed in ns games lmg is not dropped anymore
*	- added:
*		- gnome can only go Commander if he is the only player or the only marine alive
*			(if a marine spawns and gnome is not the only alive marine after 10 secs, he gets ejected)
*		- player can gnome/ungnome himself:
*			- in combat he can gnome anytime if there is no other gnome (but not ungnome, would be too unfair though)
*			- in ns he can gnome and ungnome if he is the only player
*		- a define to choose if only pick should make extra damage
*		- when gnome gets ungnomed, he will receive his old equipment (in ns only if not died)
*		- cvar for amplified damage and if only pick is allowed to use it
*			- "mp_gnome_damage_amplifier" (default 3.0) and "mp_gnome_damage_pick_only" (default on)
*
* v0.5.6b:
*	- fixed:
*		- gnome could respawn with hmg/gl/shotty in combat (again)
*		- when carrieng heavy weapon and got gnomed, no primary weapon existed
*		- when gnome got jetpack (with another plugin or cheats) his model changed to normal marine with jetpack
*	- added:
*		- cvar to enabled auto gnome or not (on round start and when gnome leaves)
*			- "mp_gnome_auto" (default off)
*		- support for MvM
*		- u can now disable and enable the plug (amx_gnome 1/0) (old amx_gnome is now amx_gnome_make)
*		- with the define "GNOME_MODEL_COLOR" you can specify the gnome color in normal ns and co maps (look a bit more down)
*	- changed:
*		- auto gnome disabled for default
*		- now there is only 1 model instead of 2 (or 3)
*
* v0.6.3b: (compatability for ExtraLevels2 Rework 0.7.8b or higher)
*	- fixed:
*		- gnome could do instant kill (when did welder-kill and attacked this enemy again (after respawn) without attacking/welding others)
*		- aliens could get resupply upgrade (it was not working on them though but could spam medpacks everywhere)
*		- main CC was seen as build even if destroyed, therefore gnome still had a range ( due to NS, it was only on the main CC )
*		- minor runtime errors (due to tasks)
*		- resupply now works on 32 players
*		- spit and acidrocket could do a pull instead of a knockback
*		- in MvM: when blue gnome exists, the red gnome wont work correctly
*		- gnome can be on alien team (only due to other plugins possible)
*		- player could lose upgrades after he gnomed in combat (armor powerups, motion tracking, ...)
*		- gnome could not do extra damage versus buildings
*		- gnome could get knockback when damaged by doors, water, ...
*	- added:
*		- ExtraLevels2 Rework compatability (+)
*	- changed:
*		- it is now a bit easier for gnome to weld self
*		- way of setting fov
*		- gnome does not have a CC-range in co maps anymore
*		- code improvements
*
* v0.6.4:
*	- added:
*		- define for NS 3.03 (marine armor has increased)
*	- changes:
*		- moved from pev/set_pev to entity_get/entity_set
*
* v0.6.6:
*	- fixed:
*		- runtime error when someone gnomed
*	- changed:
*		- code improvements
*
* v0.6.8:
*	- changed:
*		- way of checking if MvM combat is running
*		- fakemeta module not needed anymore
*		- fun module not needed anymore
*
* v0.7:
*	- fixed:
*		- exploit where player could get resupply for free when using any version of extralevels
*	- changed:
*		- server_frame is hooked with ent and support other plugins that uses the same system (speed improvement thx OneEyed)
*		- rewrote check if gnomoe is in CC range to improve speed
*
* v0.7.3:
*	- fixed:
*		- player was not able to gnome on NS classic
*		- bug where commander could only use the gnome command once
*		- when commander ungnomed someone wrong name was shown
*		- gnome could go commander even when not allowed (when he is not the only alive player in team)
*	- changed:
*		- adjusted jump height to his size (3 defines added for each coord)
*
* v0.7.4b:
*	- fixed:
*		- Gnome could not do any damage (since Amx Mod X 1.5x)
*
* v0.7.5:
*	- fixed:
*		- Gnome could not do any damage (finally done)
*		- only when using extralevels2 rework:
*			- gnome armor upgrade has not been reset
*
* v0.7.5b:
*	- fixed:
*		- fixed runtime error on NS maps since amx mod X 1.6
*
* v0.7.6:
*	- fixed:
*		- commander saw gnome with low health even if he had full
*		- pointing at gnome now displays correct health and armor percentage (before, gnome was always seen as damaged)
*		- gnome was able to ungnome even when more players have been in his team
*	- added:
*		- with amx_gnome_make and following a name will now gnome that specified player
*
* v0.7.7:
*	- fixed:
*		- due to NS 3.1:
*			- player saw Pick even when changing weapon
*			- going to readyroom will now correctly reset gnome
*		- gnome could lose his upgrades on CO
*
* v0.8.0: (compatability for ExtraLevels 3 1.2.4 or higher AND MvM_allinone 2.0.3 or higher / older ExtraLevels OR MvM_allinone versions will not work or possibly crash server)
*	- fixed:
*		- runtime error
*		- resupply is now acting as in NS 3.1.x and not 3.0
*		- when ungnomeing and old class was Jetpack or HA, then these items could be dropped and other players could pick them up
*		- players will no longer see that resupply can be purchased in popup menu
*		- cvar "mp_gnome_auto" was not working
*	- changed:
*		- new way of communication with ExtraLevels 3
*		- time commander has to wait before he can ungnome someone increased 30 -> 60 seconds
*		- improved method to recognize resupply
*		- entity_get/set_xxx replaced with pev/set_pev ( performance )
*		- removed support for NS 3.0.2 or lower ( not needed anymore )
*
* v0.8.1:
*	- fixed:
*		- aliens could lose their armor when being welded
*
* v0.8.2: (compatability for ExtraLevels 3 v1.3.0 / older ExtraLevels 3 versions will be buggy)
*	- fixed:
*		- runtime error when player ungnomed
*	- added:
*		- support for "Helper"
*	- changed:
*		- if ExtraLevels 3 is loaded gnome does not calculate player level on its own
*		- new message functions for better ExtraLevels 3 support
*
* v0.8.3:
*	- fixed:
*		- crash bug
*		- correct resupply effect is now used
*	- changed:
*		- some code tweaks
*
* v0.8.4:
*	- fixed:
*		- crash bug on round end (*)
*
* v0.8.5:
*	- fixed:
*		- player could get resupply without spending any point
*	- changed:
*		- back to normal server frame
*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fun>
#include <ns>

#define GNOME_HEALTH		80.0	// gnome health
#define GNOME_ARMOR		15.0	// gnome armor
#define GNOME_SPEED		150	// gnome speed
#define GNOME_FOV		100.0	// gnome field of view (angle)
#define GNOME_RANGE		4000.0	// how far a gnome can get from Commchair
#define GNOME_DMG_AMPLIFIER	3.0	// specify how much damage (comparing to normal) shall be done
					// (eg: 1.0 = normal damage , 1.5 = 50% more damage , 2.0 = 100% more damge)
#define GNOME_DMG_PICK_ONLY	1	// set to 0 to give other gnome weapons amplified damage too
#define GNOME_MODEL_COLOR	0	// set the gnome color in normal ns and co maps (0 = green / 1 = blue / 2 = red)

#define GNOME_JUMP_ADJUST_X	1.3	// Jump X coord will be decreased by factor 1.3 ( results in approximately 50%)
#define GNOME_JUMP_ADJUST_Y	1.3	// Jump Y coord will be decreased by factor 1.3 ( results in approximately 50%)
#define GNOME_JUMP_ADJUST_Z	1.3	// Jump Z coord will be decreased by factor 1.3 ( results in approximately 50%)

#define PUSH_ANGLE		45	// x,y from - to + , z from 0 to +
#define BOOST_START		1000	// min boost for random
#define BOOST_END		3000	// max boost for random

#define	MARINE			0
#define	MARINE2			1
#define	NOTEAM			2

// functions to communicate with Extra Levels 3
native EL_get_ammoadd( EL_id , EL_weapon_id )
native EL_who_is_gnome( EL_id , EL_gnome_num , EL_set , EL_speed )
native EL_get_level( id )

// ExtraLevels 3 compatibilities
new reinforced_ap[33]		// each players current "ExtraLevel2 Rework" ap upgrade
new gnome_ap_adds		// how much ap a gnome gets for each "ExtraLevel2 Rework" ap upgrade
new marine_armor_up, heavy_armor_up

// Gnome funcs
new Float:gnome_view[3] = {0.0, 0.0, 7.0}		// camera height standing
new Float:gnome_view_duck[3] = {0.0, 0.0, 8.0}		// camera height ducking
new Float:gnome_ap_upgrade_value

new gnome_id[3], Float:gnome_build_time[3], Float:gnome_range_orig[3][3], gnome_items[3][32], gnome_item_xtra[3], gnome_died[3], gnome_mask[3]
new old_ent_id[3], old_toucher[3], old_toucher_id[3], Float:attacker_vec[3][3]
new allow_comm_gnome[3], Float:gnome_weap_bas_damage[3][4]
new gnome_jumped[3]

new Float:ent_old_status[3], Float:ent_new_status[3], Float:ent_stat_change[3]
new Float:ent_old_hp[3], Float:ent_new_hp[3], Float:ent_hp_change[3]
new Float:ent_old_ap[3], Float:ent_new_ap[3], Float:ent_ap_change[3]

new running_combat, is_mvm_combat, mvm_allinone_loaded, extratralvl3_loaded, override, GNOMErunning = 1
new phasein_event, AmmoPickup_id, SetTech_id, max_player_num, max_entities
new resupply[33], fix_gnome_status[33]
new player_team[33] = {NOTEAM,...}
new Float:tried_comm_time[33]
new player_to_gnome
new current_weapon[33]

new CVAR_amplifier, CVAR_pickonly, CVAR_autognome

new plugin_author[] = "White Panther/Depot/Zamma"
new plugin_version[] = "0.8.5"

//////////////////// Client_PreThink globals ////////////////////
new cPT_gnome_num
new cPT_button
new cPT_aim_at_id, cPT_dummy
new cPT_ent_classname[33]
new Float:cPT_jump_vec[3]

//////////////////// pfn_touch globals ////////////////////
new PfnT_classname[33]

//////////////////// server_frame globals ////////////////////
new SF_a, SF_gnome_id
new Float:SF_gnome_cur_hp, Float:SF_max_ap, Float:SF_gnome_status, Float:SF_cur_orig[3], Float:SF_cur_angle[3]
new SF_nearest_cc, SF_aim_at_id, SF_dummy, SF_mode, SF_aim_at_ap_upgrade
new SF_selfwelding, SF_in_built
new Float:SF_max_hp, Float:SF_max_allowed_hp, Float:SF_max_allowed_ap
new SF_player_mask

new SF_ccid, SF_closest_cc, SF_found_correct_cc, SF_gnome_team_cc
new Float:SF_closest_cc_range, Float:SF_cc_range

//////////////////// Plugin Init + Forwards ////////////////////
public plugin_init( )
{
	register_plugin("Gnome Builder", plugin_version, plugin_author)
	register_cvar("gnome_version", plugin_version, FCVAR_SERVER)
	set_cvar_string("gnome_version", plugin_version)
	
	register_event("Countdown", "event_Countdown", "ab")
	register_event("Damage", "event_Damage", "b", "2!0")
	register_event("DeathMsg", "event_Death", "a")
	register_event("CurWeapon", "event_CurWeapon", "b")
	register_event("TeamInfo", "event_TeamInfo", "ab")
	register_event("HudText2", "event_HudText2", "b", "1=ReadyRoomMessage")
	
	register_forward(FM_PlayerPreThink, "client_PreThinkPost", 1)
	
	register_concmd("amx_gnome", "gnome_onoff", ADMIN_LEVEL_B, "on/off OR 1/0 to turn Gnome on and off")
	register_concmd("amx_gnome_make", "amx_gnome_make", ADMIN_LEVEL_B, "<name> : specified player becomes gnome, no name = random player")
	register_concmd("amx_ungnome", "amx_ungnome", ADMIN_LEVEL_B, "all Gnomes become normal players")
	register_message(get_user_msgid("StatusValue"), "editStatusValue")
	register_clcmd("say", "handle_say")
	register_clcmd("say_team", "handle_say")
	
	max_player_num = get_maxplayers()
	max_entities = get_global_int(GL_maxEntities)
	running_combat = ns_is_combat()
	phasein_event = precache_event(1, "events/PhaseIn.sc")
	AmmoPickup_id = get_user_msgid("AmmoPickup")
	SetTech_id = get_user_msgid("SetTech")
	
	new name[32], version[32], author[32], filename[32], status[32]
	for ( new i = 0; i < get_pluginsnum(); ++i )
	{
		get_plugin(i, filename, 31, name, 31, version, 31, author, 31, status, 31)
		if ( equali(filename, "mvm_allinone.amxx")
			&& ( equal(status, "running") || equal(status, "debug") ) )
				mvm_allinone_loaded = 1
		else if ( equali(filename, "extralevels3.amxx")
			&& ( equal(status, "running") || equal(status, "debug") ) )
				extratralvl3_loaded = 1
	}
	
	if ( ns_get_build("team_command", 0, 0) > 1 && running_combat )
		is_mvm_combat = 1
	
	new num_str[5]
	format(num_str, 4, "%f", GNOME_DMG_AMPLIFIER)
	CVAR_amplifier = register_cvar("mp_gnome_damage_amplifier", num_str)
	format(num_str, 4, "%i", GNOME_DMG_PICK_ONLY)
	CVAR_pickonly = register_cvar("mp_gnome_damage_pick_only", num_str)
	CVAR_autognome = register_cvar("mp_gnome_auto", "0")
	
	allow_comm_gnome[0] = 1
	allow_comm_gnome[1] = 1
	gnome_ap_upgrade_value = ( GNOME_ARMOR * 8 / 10 )
}

public plugin_natives( )
{
	register_native("GNOME_setget_armor", "GNOME_setget_armor_func")
	
	set_native_filter("native_filter")
}

public client_impulse( id , impulse )
{
	if ( !running_combat )
		return PLUGIN_CONTINUE
	
	if ( impulse == 0 )
		return PLUGIN_CONTINUE
		
	if ( !( CLASS_MARINE <= ns_get_class(id) <= CLASS_COMMANDER ) )
		return PLUGIN_CONTINUE
	
	// Resupply
	if ( impulse == 31 )
	{
		if ( !is_user_alive(id)
			|| resupply[id]
			|| !check_points_spend_or_level(id) )
			return PLUGIN_HANDLED
		
		ns_set_points(id, ns_get_points(id) + 1)
		resupply[id] = 1
		resupply_player(id, 1)
		new Userid[1]
		Userid[0] = id
		set_task(3.0, "resupply_timer", 2000 + id, Userid, 1, "b")
		
		if ( resupply[id] )
		{
			resupply_msg(id, 1)
		}
		
		return PLUGIN_HANDLED
	}
	
	if ( GNOMErunning
		&& ( id == gnome_id[0] || id == gnome_id[1] ) )
	{
		// HA, JP, Welder, Shotgun, HMG, GL
		if ( impulse == 38
			|| impulse == 39
			|| impulse == 62
			|| impulse == 64
			|| impulse == 65
			|| impulse == 66 )
			return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public client_connect( id )
{
	if ( !running_combat )
		return
	
	resupply[id] = 0
	remove_task(2000 + id)
}

public client_disconnect( id )
{
	// stop resupply task
	if ( running_combat )
	{
		resupply[id] = 0
		remove_task(2000 + id)
	}
	
	if ( !GNOMErunning )
		return
	
	new gnome_num = player_team[id]
	
	if ( id == gnome_id[gnome_num] )
	{
		free_gnome(id, gnome_num)
		set_task(0.1, "event_Countdown", 654321 + id)
	}
}

public client_changeclass( id , newclass , oldclass )
{
	if ( !is_user_connected(id) )
		return
	
	if ( running_combat )
	{
		if ( newclass == CLASS_UNKNOWN
			|| newclass == CLASS_NOTEAM )
		{	// Unknown or Noteam
			resupply[id] = 0
			remove_task(2000 + id)
		}else if ( newclass == CLASS_DEAD )		// Dead
			remove_task(2000 + id)
	}
	if ( !GNOMErunning )
		return
	
	new gnome_num = player_team[id]
	if ( id == gnome_id[gnome_num] )
	{
		switch ( newclass )
		{
			case CLASS_UNKNOWN, CLASS_NOTEAM:
			{	// Unknown or Noteam
				free_gnome(id, gnome_num, 1)
				set_task(0.1, "event_Countdown", 654321 + id)
			}
			case CLASS_DEAD:
			{	// Dead
				gnome_died[gnome_num] = 1
			}
			case CLASS_JETPACK:
			{
				set_gnome_model(id,gnome_num)
				set_pev(id, pev_body, 1)
			}
		}
	}
}

public client_changeteam( id , newteam , oldteam )
{
	if ( !GNOMErunning )
		return
	
	if ( newteam < 1
		|| newteam > 4 )
	{
		new gnome_num = player_team[id]
		if ( id == gnome_id[gnome_num] )
		{
			free_gnome(id, gnome_num, 1)
			set_task(0.1, "event_Countdown", 654321 + id)
		}
		player_team[id] = NOTEAM
		reinforced_ap[id] = 0
	}else
	{
		if ( resupply[id] )
		{
			resupply_msg(id, 0)
		}
	}
}

public plugin_precache( )
{
	precache_model("models/gnome/gnomeall.mdl")
	precache_model("models/p_welder_gnome.mdl")
	precache_model("models/p_pick.mdl")
	precache_model("models/v_pick.mdl")
	precache_model("models/p_hg_gnome.mdl")
	precache_model("models/p_mg_gnome.mdl")
}

public pfn_touch( iTouched , iToucher )
{
	if ( !GNOMErunning )
		return PLUGIN_CONTINUE
	
	if ( !iToucher
		|| !is_valid_ent(iTouched)
		|| iTouched <= max_player_num )
		return PLUGIN_CONTINUE
	
	new toucher_is_gnome = -1
	if ( iToucher == gnome_id[0] )
		toucher_is_gnome = 0
	else if ( iToucher == gnome_id[1] )
		toucher_is_gnome = 1
	
	if ( toucher_is_gnome == -1 )
		return PLUGIN_CONTINUE
	
	pev(iTouched, pev_classname, PfnT_classname, 32)
	if ( equal(PfnT_classname, "weapon_heavymachinegun")
		|| equal(PfnT_classname, "weapon_grenadegun")
		|| equal(PfnT_classname, "weapon_shotgun")
		//|| equal(PfnT_classname, "weapon_machinegun")
		|| equal(PfnT_classname, "weapon_mine")
		|| equal(PfnT_classname, "item_heavyarmor")
		|| equal(PfnT_classname, "item_jetpack")
		|| ( equal(PfnT_classname, "item_health")
			&& entity_get_float(iToucher, EV_FL_health) >= entity_get_float(iToucher, EV_FL_max_health) ) )
		return PLUGIN_HANDLED
	
	// get projectile player got hit by (Spit or Acidrocket)
	if ( !equal(PfnT_classname, "spitgunspit")
		&& !equal(PfnT_classname, "weapon_acidrocket") )
		return PLUGIN_CONTINUE
	
	old_toucher[toucher_is_gnome] = iTouched
	old_toucher_id[toucher_is_gnome] = pev(iTouched, pev_owner)
	pev(iTouched, pev_velocity, attacker_vec[toucher_is_gnome])
	
	return PLUGIN_CONTINUE
}

public client_spawn( id )
{
	if ( resupply[id] )
	{
		new Userid[1]
		Userid[0] = id
		remove_task(2000 + id)
		set_task(3.0, "resupply_timer", 2000 + id, Userid, 1, "b")
	}
	
	if ( !GNOMErunning )
		return
	
	new gnome_num = player_team[id]
	if ( !running_combat
		&& gnome_id[gnome_num]
		&& !check_if_allowed(gnome_num, 1) )
			set_task(10.0, "eject_gnome", 4000 + gnome_num)
	
	if ( id == gnome_id[gnome_num]
		&& is_user_alive(id) )
	{
		set_gnome_abilities2(id)
		set_task(0.1, "gnome_ability_timer", 3000 + gnome_num)
		set_task(0.1, "xtra_gnome_abilities", 3000 + 32 + gnome_num)
	}
}

public client_PreThink( id )
{
	if ( !GNOMErunning )
		return
	
	cPT_gnome_num = player_team[id]
	if ( id != gnome_id[cPT_gnome_num]
		|| !is_user_alive(id) )
		return
	
	cPT_button = pev(id, pev_button)
	if ( !running_combat
		&& cPT_button & IN_USE )
	{
		get_user_aiming(id, cPT_aim_at_id, cPT_dummy, 150)
		if ( is_valid_ent(cPT_aim_at_id) )
		{
			pev(cPT_aim_at_id, pev_classname, cPT_ent_classname, 32)
			if ( equal(cPT_ent_classname, "team_command")
				&& !check_if_allowed(cPT_gnome_num, 1) )
			{
				set_pev(id, pev_button, cPT_button & ~IN_USE)
				if ( get_gametime() - tried_comm_time[id] > 2.0 )
				{
					client_print(id, print_chat, "[GNOME] You cannot be the Commander (right now)")
					tried_comm_time[id] = get_gametime()
				}
			}
		}
	}
	
	if ( cPT_button & IN_JUMP )
	{
		if ( !(pev(id, pev_flags) & FL_ONGROUND)
			&& !gnome_jumped[cPT_gnome_num] )
		{
			gnome_jumped[cPT_gnome_num] = 1
			pev(id, pev_velocity, cPT_jump_vec)
			cPT_jump_vec[0] /= GNOME_JUMP_ADJUST_X
			cPT_jump_vec[1] /= GNOME_JUMP_ADJUST_Y
			cPT_jump_vec[2] /= GNOME_JUMP_ADJUST_Z
			set_pev(id, pev_velocity, cPT_jump_vec)
		}
	}else if ( pev(id, pev_flags) & FL_ONGROUND )
		gnome_jumped[cPT_gnome_num] = 0
}

public client_PreThinkPost( id )
{
	if ( !GNOMErunning )
		return
	
	if ( id != gnome_id[player_team[id]]
		|| !is_user_alive(id) )
		return
	
	// set view postion
	if ( pev(id, pev_button) & IN_DUCK )
		set_pev(id, pev_view_ofs, gnome_view_duck)
	else
		set_pev(id, pev_view_ofs, gnome_view)
}

public server_frame( )
{
	if ( !GNOMErunning )
		return
	
	for ( SF_a = 0; SF_a < is_mvm_combat + 1; ++SF_a )
	{
		SF_gnome_id = gnome_id[SF_a]
		if ( !SF_gnome_id
			|| !is_user_alive(SF_gnome_id) )
			continue
		
		// check current health and max_health
		set_pev(SF_gnome_id, pev_max_health, GNOME_HEALTH)
		
		pev(SF_gnome_id, pev_health, SF_gnome_cur_hp)
		if ( SF_gnome_cur_hp > GNOME_HEALTH )
			set_pev(SF_gnome_id, pev_health, GNOME_HEALTH)
		
		// check current armor
		SF_max_ap = gnome_ap_upgrade_value * check_armor_upgrade(SF_gnome_id) + GNOME_ARMOR		// 80% of GNOME_ARMOR * amount of armor upgrades + standard armor
		// ExtraLevels3 extra armor (gnome only 60% of default)
		SF_max_ap += reinforced_ap[SF_gnome_id] * gnome_ap_adds
		if ( entity_get_float(SF_gnome_id, EV_FL_armorvalue) > SF_max_ap )
			set_pev(SF_gnome_id, pev_armorvalue, SF_max_ap)
		
		// set gnome status (Health ring)
		SF_gnome_status = 1000.0 / entity_get_float(SF_gnome_id, EV_FL_max_health) * SF_gnome_cur_hp
		set_pev(SF_gnome_id, pev_fuser2, SF_gnome_status)
		
		if ( !running_combat
			&& pev(SF_gnome_id, pev_iuser3) != 2 )	// iuser3 => 2 => commander
		{	// check if gnome is in Commchair range
			pev(SF_gnome_id, pev_origin, SF_cur_orig)
			SF_nearest_cc = gnome_in_cc_range(SF_gnome_id)
			if ( SF_nearest_cc )
			{
				// gnome not in Commchair range so check if last position was the same as current, if not teleport gnome there
				if ( !is_same_vec(SF_cur_orig, gnome_range_orig[SF_a]) )
					entity_set_origin(SF_gnome_id, gnome_range_orig[SF_a])
				// gnome got teleported back and still not in Commchair range, so take him to nearest Commchair
				else
				{
					pev(SF_nearest_cc, pev_origin, SF_cur_orig)
					SF_cur_orig[2] += 40
					entity_set_origin(SF_gnome_id, SF_cur_orig)
				}
			}else if ( pev(SF_gnome_id, pev_flags) & FL_ONGROUND )
			{
				gnome_range_orig[SF_a][0] = SF_cur_orig[0]
				gnome_range_orig[SF_a][1] = SF_cur_orig[1]
				gnome_range_orig[SF_a][2] = SF_cur_orig[2]
			}
		}
		
		// get the building/player gnome is looking at
		get_user_aiming(SF_gnome_id, SF_aim_at_id, SF_dummy, 100)
		
		// check for self-welding
		SF_selfwelding = 0
		pev(SF_gnome_id, pev_angles, SF_cur_angle)
		if ( SF_cur_angle[0] < -26.0
			&& !is_valid_ent(SF_aim_at_id) )
		{
			SF_selfwelding = 1
			SF_aim_at_id = SF_gnome_id
		}
		
		// neither selfwelding nor having anything else in view
		if ( !is_valid_ent(SF_aim_at_id)
			&& !SF_selfwelding )
			continue
		
		SF_in_built = ns_get_mask(SF_aim_at_id, MASK_BUILDABLE)
		
		// check if same team, if enemy just skip
		if ( pev(SF_gnome_id, pev_team) != pev(SF_aim_at_id, pev_team) )
			continue
		
		if ( pev(SF_gnome_id, pev_button) & IN_USE && SF_in_built )
		{
			SF_mode = 1
		}else if ( pev(SF_gnome_id, pev_button) & IN_ATTACK
			&& get_user_weapon(SF_gnome_id, SF_dummy, SF_dummy) == WEAPON_WELDER )
		{
			if ( SF_selfwelding )
				SF_selfwelding = 2
			else if ( is_user_connected(SF_aim_at_id) )
				SF_mode = 3
			else
				SF_mode = 2
		}else
			continue
		
		// gnome is welding self
		if ( SF_selfwelding == 2 )
		{
			if ( get_gametime() - gnome_build_time[SF_a] < 0.7 )
				continue
			
			ent_ap_change[SF_a] = entity_get_float(SF_gnome_id, EV_FL_armorvalue) + 5.0
			if ( ent_ap_change[SF_a] > SF_max_ap )
				ent_ap_change[SF_a] = SF_max_ap
			
			set_pev(SF_gnome_id, pev_armorvalue, ent_ap_change[SF_a])
			
			gnome_build_time[SF_a] = get_gametime()
			
			continue
		}
		
		// if we looking at a new entity reset everything
		if ( old_ent_id[SF_a] != SF_aim_at_id )
		{
			ent_new_status[SF_a] = 0.0
			ent_old_status[SF_a] = 0.0
			ent_new_hp[SF_a] = 0.0
			ent_old_hp[SF_a] = 0.0
			gnome_build_time[SF_a] = 0.0
		}
		
		old_ent_id[SF_a] = SF_aim_at_id
		
		// if next check not reached, skip
		if ( get_gametime() - gnome_build_time[SF_a] <= 0.5 )
			continue
		
		// get max health to prevent giving more health than max is allowed
		pev(SF_aim_at_id, pev_max_health, SF_max_hp)
		// get current build status
		pev(SF_aim_at_id, pev_fuser1, ent_new_status[SF_a])
		// get current hp status
		pev(SF_aim_at_id, pev_health, ent_new_hp[SF_a])
		switch ( SF_mode )
		{
			case 1:
			{	// building structure
				if ( ent_new_status[SF_a] != 1000.0
					&& ent_old_status[SF_a] > 0.0
					&& ent_new_status[SF_a] > ent_old_status[SF_a] )
				{
					ent_stat_change[SF_a] = ent_new_status[SF_a] * 2 - ent_old_status[SF_a]		// get the difference between old and new build status
					
					// dont finish the building with double speed
					if ( ent_stat_change[SF_a] >= 1000.0 )
						ent_stat_change[SF_a] = 999.0
					
					set_pev(SF_aim_at_id, pev_fuser1, ent_stat_change[SF_a])		// set new build status
					ent_old_status[SF_a] = ent_stat_change[SF_a]
					
					ent_hp_change[SF_a] = ent_new_hp[SF_a] * 2 - ent_old_hp[SF_a]		// get the difference between old and new build hp
					
					// dont give more hp than allowed
					if ( ent_hp_change[SF_a] > SF_max_hp )
						ent_hp_change[SF_a] = SF_max_hp - 1.0
					
					set_pev(SF_aim_at_id, pev_health, ent_hp_change[SF_a])		// set new build hp
					ent_old_hp[SF_a] = ent_hp_change[SF_a]
				}else
				{
					ent_old_status[SF_a] = ent_new_status[SF_a]
					ent_old_hp[SF_a] = ent_new_hp[SF_a]
				}
			}
			case 2:
			{	// welding structure
				if ( ent_new_hp[SF_a] != SF_max_hp
					&& ent_new_hp[SF_a] > ent_old_hp[SF_a]
					&& ent_old_hp[SF_a] > 0.0 )
				{
					ent_hp_change[SF_a] = ent_new_hp[SF_a] * 2 - ent_old_hp[SF_a]
					
					// check for unfinished structures
					if ( SF_in_built )
					{
						// dont give more hp than allowed
						SF_max_allowed_hp = SF_max_hp / 1000.0 * ent_new_status[SF_a]
						if ( ent_hp_change[SF_a] > SF_max_allowed_hp )
							ent_hp_change[SF_a] = SF_max_allowed_hp
					}else if ( ent_hp_change[SF_a] > SF_max_hp )
						ent_hp_change[SF_a] = SF_max_hp - 1.0
					
					set_pev(SF_aim_at_id, pev_health, ent_hp_change[SF_a])
					ent_old_hp[SF_a] = ent_hp_change[SF_a]
				}else
					ent_old_hp[SF_a] = ent_new_hp[SF_a]
			}
			case 3:
			{	// welding teammate
				pev(SF_aim_at_id, pev_armorvalue, ent_new_ap[SF_a])
				if ( ent_new_ap[SF_a] > ent_old_ap[SF_a]
					&& ent_old_ap[SF_a] > 0.0 )
				{
					SF_aim_at_ap_upgrade = check_armor_upgrade(SF_aim_at_id)
					ent_ap_change[SF_a] = ent_new_ap[SF_a] * 2 - ent_old_ap[SF_a]
					
					// Base + Adv Armor
					if ( ns_get_class(SF_aim_at_id) == CLASS_HEAVY )
						SF_max_allowed_ap = ( 200.0 + ( SF_aim_at_ap_upgrade * 30.0 ) ) + ( reinforced_ap[SF_aim_at_id] * heavy_armor_up )
					else
						SF_max_allowed_ap = ( 30.0 + ( SF_aim_at_ap_upgrade * 20.0 ) ) + ( reinforced_ap[SF_aim_at_id] * marine_armor_up )
					
					if ( ent_ap_change[SF_a] > SF_max_allowed_ap )
						ent_ap_change[SF_a] = SF_max_allowed_ap
					
					set_pev(SF_aim_at_id, pev_armorvalue, ent_ap_change[SF_a])
					ent_old_ap[SF_a] = ent_ap_change[SF_a]
				}else
					ent_old_ap[SF_a] = ent_new_ap[SF_a]
			}
		}
		gnome_build_time[SF_a] = get_gametime()
	}
}

//////////////////// Gnome ////////////////////
public gnome_onoff( id , level , cid )
{
	gnome_view[2] -= 1.0
	if ( gnome_view[2] < 2.0 )
		gnome_view[2] = 11.0
	if ( !cmd_access(id, level, cid, 2) )
		return PLUGIN_HANDLED
	
	new onoff[5]
	read_argv(1, onoff, 4)
	if ( equal(onoff, "on") || equal(onoff, "1") )
	{
		if ( GNOMErunning == 1 )
		{
			console_print(id, "Gnome already enabled")
		}else
		{
			GNOMErunning = 1
			console_print(id, "Gnome enabled")
		}
	}
	else if ( equal(onoff, "off") || equal(onoff, "0") )
	{
		if ( GNOMErunning == 0 )
		{
			console_print(id, "Gnome already disabled")
		}else
		{
			GNOMErunning = 0
			if ( gnome_id[0] )
				free_gnome(gnome_id[0], 0)
			if ( gnome_id[1] )
				free_gnome(gnome_id[1], 1)
			console_print(id, "Gnome disabled")
		}
	}
	return PLUGIN_HANDLED
}

public amx_gnome_make( id , level , cid )
{
	if ( !cmd_access (id, level, cid, 1) )
		return PLUGIN_HANDLED
	
	if ( !GNOMErunning )
		return PLUGIN_HANDLED
	
	if ( read_argc() )
	{
		new name[32]
		read_argv(1, name, 31)
		
		player_to_gnome = find_player("bl", name)
		if ( player_to_gnome )
		{
			if ( player_to_gnome != find_player("blj", name) )
			{
				console_print(id, "%L", id, "MORE_CL_MATCHT")
				return PLUGIN_HANDLED
			}
		}else if ( ( player_to_gnome = find_player("c", name) ) == 0 && name[0] == '#' && name[1] )
			player_to_gnome = find_player("k", str_to_num(name[1]))
		
		if ( !is_user_connected(player_to_gnome) )
			player_to_gnome = 0
	}
	
	override = 1
	event_Countdown()
	
	return PLUGIN_HANDLED
}

public amx_ungnome( id , level , cid )
{
	if ( !cmd_access (id, level, cid, 1) )
		return PLUGIN_HANDLED
	
	if ( !GNOMErunning )
		return PLUGIN_HANDLED
	
	if ( gnome_id[0] )
		free_gnome(gnome_id[0], 0)
	if ( gnome_id[1] )
		free_gnome(gnome_id[1], 1)
	
	return PLUGIN_HANDLED
}

public editStatusValue( dummy , dummy2 , receiver )
{
	if ( !is_user_connected(receiver) )
		return PLUGIN_CONTINUE
	
	new gnome_num = player_team[receiver]
	new arg1_int = get_msg_arg_int(1)
	
	if ( arg1_int == 1 )
	{
		if ( get_msg_arg_int(2) == gnome_id[gnome_num] )
			fix_gnome_status[receiver] = gnome_id[gnome_num]
		else
			fix_gnome_status[receiver] = 0
	}else if ( fix_gnome_status[receiver] )
	{
		if ( arg1_int == 2 )
		{
			set_msg_arg_int(2, ARG_SHORT, floatround( 100.0 / GNOME_HEALTH * entity_get_float(gnome_id[gnome_num], EV_FL_health) ))
		}else if ( arg1_int == 3 )
		{
			new Float:max_ap = gnome_ap_upgrade_value * check_armor_upgrade(gnome_id[gnome_num]) + GNOME_ARMOR		// 80% of GNOME_ARMOR * amount of armor upgrades + standard armor
			set_msg_arg_int(2, ARG_SHORT, floatround( 100.0 / max_ap * entity_get_float(gnome_id[gnome_num], EV_FL_armorvalue) ))
		}
	}
	
	return PLUGIN_CONTINUE
}

public event_HudText2( id )
{
	new gnome_num = player_team[id]
	if ( id == gnome_id[gnome_num] )
	{
		free_gnome(id, gnome_num, 1)
		set_task(0.1, "event_Countdown", 654321 + id)
	}
	
	player_team[id] = NOTEAM
	reinforced_ap[id] = 0
	
	// reset Resupply upgrade
	if ( resupply[id] )
	{
		resupply_msg(id, 0)
	}
	
	return PLUGIN_CONTINUE
}
	
public event_Countdown( )
{
	new marines[2][32], marine_num[2]
	marine_num[0] = -1
	marine_num[1] = -1
	
	new i
	new gnome_num
	for ( i = 1; i <= max_player_num; ++i )
	{
		if ( !is_user_connected(i) )
			continue
		
		gnome_num = player_team[i]
		if ( 0 <= gnome_num <= 1 )
		{
			++marine_num[gnome_num]
			marines[gnome_num][marine_num[gnome_num]] = i
		}
	}
	
	for ( i = 0; i < is_mvm_combat + 1; ++i )
	{
		if ( gnome_id[i] )
		{
			set_gnome_model(gnome_id[i], player_team[gnome_id[i]])
			continue
		}
		
		if ( ( marine_num[i] > 0
				&& get_pcvar_num(CVAR_autognome) )
			|| ( override
				&& marine_num[i] != -1 ) )
		{
			if ( player_to_gnome
				&& player_team[player_to_gnome] == i )
			{
				make_gnome(player_to_gnome, i)
				player_to_gnome = 0
			}else
				make_gnome(marines[i][random(marine_num[i] + 1)], i)
		}
	}
	
	override = 0
	
	return PLUGIN_HANDLED
}

public event_Damage( id )
{
	if ( !GNOMErunning
		|| is_mvm_combat )
		return
	
	new attacker_weapon_id = pev(id, pev_dmg_inflictor)
	new gnome_num = player_team[id]
	
	if ( !is_valid_ent(attacker_weapon_id)
		&& ( attacker_weapon_id != old_toucher[gnome_num]
			|| !attacker_weapon_id ) )
		return
	
	new attacker, temp_toucher = -1
	if ( attacker_weapon_id == old_toucher[gnome_num] )
	{
		attacker = old_toucher_id[gnome_num]
		temp_toucher = old_toucher[gnome_num]
		
		// reset touchers for next hit
		old_toucher_id[gnome_num] = 0
		old_toucher[gnome_num] = 0
	}else
	{
		new attacker_weapon[51]
		pev(attacker_weapon_id, pev_classname, attacker_weapon, 50)
		
		// no knockback from parasite, spore and spikes
		if ( equal(attacker_weapon, "weapon_parasite")
			|| equal(attacker_weapon, "sporegunprojectile")
			|| equal(attacker_weapon, "weapon_spikegun") )
			return
		
		attacker = pev(attacker_weapon_id, pev_owner)
	}
	// gnome got dmg
	if ( ( id == gnome_id[0] || id == gnome_id[1] )
		&& entity_get_float(id, EV_FL_health) >= 1.0 )
	{
		if ( attacker_weapon_id == temp_toucher )
			knockback_gnome(id, attacker, gnome_num, 1)
		else if ( is_user_connected(attacker) )
			knockback_gnome(id, attacker, gnome_num)
	}
}

public event_Death( )
{
	new victim = read_data(2)
	if ( !is_user_connected(victim) )
		return
	
	if ( victim == old_ent_id[0] )
		old_ent_id[0] = 0
	else if ( victim == old_ent_id[1] )
		old_ent_id[1] = 0
}

public event_CurWeapon( id )
{
	// 6 = change to weapon, 4 = change from weapon
	if ( read_data(1) != 6 )
		return
	
	current_weapon[id] = read_data(2)
	
	if ( !GNOMErunning )	// this check must be after setting the current weapon
		return
	
	// no gnome at all
	if ( id != gnome_id[0]
		&& id != gnome_id[1] )
		return
	
	new wpn_id = current_weapon[id]
	switch ( wpn_id )
	{
		case WEAPON_WELDER:
		{
			set_pev(id, pev_weaponmodel, engfunc(EngFunc_AllocString, "models/p_welder_gnome.mdl"))
		}
		case WEAPON_KNIFE:
		{
			set_pev(id, pev_viewmodel, engfunc(EngFunc_AllocString, "models/v_pick.mdl"))
			set_pev(id, pev_weaponmodel, engfunc(EngFunc_AllocString, "models/p_pick.mdl"))
		}
		case WEAPON_PISTOL:
		{
			set_pev(id, pev_weaponmodel, engfunc(EngFunc_AllocString, "models/p_hg_gnome.mdl"))
		}
		case WEAPON_LMG:
		{
			set_pev(id, pev_weaponmodel, engfunc(EngFunc_AllocString, "models/p_mg_gnome.mdl"))
		}
	}
}

public event_TeamInfo( )
{
	new teamname[32], id = read_data(1)
	read_data(2, teamname, 31)
	if ( equal(teamname, "marine1team") )
		player_team[id] = MARINE
	else if ( equal(teamname, "marine2team") )
		player_team[id] = MARINE2
}

public handle_say( id )
{
	if ( !GNOMErunning )
		return PLUGIN_CONTINUE
	
	new gnome_num = player_team[id]
	if ( gnome_num == NOTEAM )
		return PLUGIN_CONTINUE
	
	new Speech[65]
	read_args(Speech, 64)
	remove_quotes(Speech)
	if ( ns_get_class(id) == CLASS_COMMANDER )
	{	// commander
		if ( equal(Speech, "/gnome", 6) )
		{
			if ( allow_comm_gnome[gnome_num] )
			{
				replace(Speech, 64, "/gnome ", "")
				
				new target_id = cmd_target(id, Speech, 0)
			 	if ( !target_id || target_id == id )
			 		return PLUGIN_HANDLED
			 	
			 	if ( pev(target_id, pev_team) != pev(id, pev_team) )
			 		return PLUGIN_HANDLED
			 	
		 		if ( gnome_id[gnome_num] )
		 			free_gnome(gnome_id[gnome_num], gnome_num)
		 		
		 		make_gnome(target_id, gnome_num)
		 		allow_comm_gnome[gnome_num] = 0
		 		
		 		new user_name[33]
				get_user_name(target_id, user_name, 32)
				client_print(id, print_chat, "[GNOME] %s has been turned into the Gnome", user_name)
		 		
		 		set_task(60.0, "change_comm_gnome", 4000 + 32 + gnome_num)
			}
		 	return PLUGIN_HANDLED
		}else if ( equal(Speech, "/ungnome", 8) )
		{
			if ( !gnome_id[gnome_num]
				|| pev(gnome_id[gnome_num], pev_team) != pev(id, pev_team) )
				return PLUGIN_HANDLED
			
			new user_name[33]
			get_user_name(gnome_id[gnome_num], user_name, 32)
			client_print(id, print_chat, "[GNOME] %s has been ungnomed", user_name)
			free_gnome(gnome_id[gnome_num], gnome_num)
			
			return PLUGIN_HANDLED
		}
		
	}else
	{
		new temp
		if ( equal(Speech, "/gnome me")
			|| equal(Speech, "/gnomeme")
			|| ( temp = equal(Speech, "/gnome ayb") ) )
		{
			if ( !gnome_id[gnome_num] )
			{
				make_gnome(id, gnome_num)
				if ( temp )
					client_cmd(id, "say ^"For great justice.^"")
			}else
				client_print(id, print_chat, "[GNOME] You cannot gnome, there is already a Gnome")
			return PLUGIN_HANDLED
		}else if ( equal(Speech, "/ungnome me")
			|| equal(Speech, "/ungnomeme") )
		{
			if ( id == gnome_id[gnome_num] )
			{
				if ( check_if_allowed(gnome_num) )
					free_gnome(id, gnome_num)
			}else
				client_print(id, print_chat, "[GNOME] You cannot ungnome, you are not the Gnome")
			return PLUGIN_HANDLED
		}
	}
	
	return PLUGIN_CONTINUE
}

//////////////////// Additional Functions ////////////////////
make_gnome( id , gnome_number )
{
	gnome_id[gnome_number] = id
	gnome_mask[gnome_number] = pev(id, pev_iuser4)
	
	// set new field of view
	ns_set_fov(id, GNOME_FOV)
	
	get_items(id, gnome_number)
	set_gnome_abilities(id, gnome_number)
	set_gnome_abilities2(id)
	set_task(0.1, "xtra_gnome_abilities", 3000 + 32 + gnome_number + 32)
	
	// updade ExtraLevels 3
	if ( extratralvl3_loaded )
		EL_who_is_gnome(id, gnome_number, 1 , - 206 + GNOME_SPEED)
}

free_gnome( id , gnome_number , no_team = 0 )
{
	gnome_id[gnome_number] = 0
	
	// reset field of view
	ns_set_fov(id, 0.0)
	remove_task(3000 + gnome_number)		// gnome_ability_timer
	remove_task(3032 + gnome_number)		// xtra_gnome_abilities
	remove_task(3064 + gnome_number)		// xtra_gnome_abilities (same as other but only started when gnome is made)
	remove_task(4000 + gnome_number)		// eject_gnome
	
	ns_set_speedchange(id, 0)
	ns_set_player_model(id)
	if ( entity_get_float(id, EV_FL_health) >= GNOME_HEALTH )
		set_pev(id, pev_health, 100.0)
	set_pev(id, pev_max_health, 100.0)
	
	new armor_level = check_armor_upgrade(id)
	if ( entity_get_float(id, EV_FL_armorvalue) >= ( gnome_ap_upgrade_value * armor_level + GNOME_ARMOR ) )
		set_pev(id, pev_armorvalue, 30.0 + armor_level * 20.0)
	
	// updade ExtraLevels 3
	if ( extratralvl3_loaded )
		EL_who_is_gnome(id, gnome_number, 0 , - 206 + GNOME_SPEED)
	
	if ( !no_team )
	{
		regive_items(id, gnome_number)
		
		// set the players model to correct color
		if ( mvm_allinone_loaded
			&& is_mvm_combat )
		{
			if( ns_get_class(id) == CLASS_HEAVY )
				ns_set_player_model(id, "models/player/heavy/heavy_color.mdl")
			else
				ns_set_player_model(id, "models/player/soldier/soldier_color.mdl")
			
			if ( gnome_number == 1 )
				set_pev(id, pev_skin, 1)
		}
	}
	
	for ( new player = 1; player <= max_player_num; ++player )
	{
		if ( fix_gnome_status[player] == id )
			fix_gnome_status[player] = 0
	}
}

set_gnome_abilities( id , gnome_number )
{
	set_pev(id, pev_max_health, GNOME_HEALTH)		// set max health
	
	// drop good weapons and give LMG
	regive_items(id, gnome_number, {16, 17, 20}, 3, {15, 18}, 2)
}

set_gnome_abilities2( id )
{
	// remove HA and JP
	if ( pev(id, pev_iuser4) & MASK_HEAVYARMOR )
	{
		set_pev(id, pev_iuser3, 1)	// normal marine
		set_pev(id, pev_iuser4, pev(id, pev_iuser4) & ~MASK_HEAVYARMOR )
	}
	if ( pev(id, pev_iuser4) & MASK_JETPACK )
	{
		set_pev(id, pev_iuser3, 1)	// normal marine
		set_pev(id, pev_iuser4, pev(id, pev_iuser4) & ~MASK_JETPACK )
	}
}

set_gnome_model( id , gnome_number )
{
	ns_set_player_model(id, "models/gnome/gnomeall.mdl")
	if ( is_mvm_combat )
		set_pev(id, pev_skin, gnome_number + 1)
	else
		set_pev(id, pev_skin, GNOME_MODEL_COLOR)
}

knockback_gnome( id , attacker , gnome_number , projectile = 0 )
{
	new Float:attacker_ang[3]
	new booster = random_num(BOOST_START, BOOST_END)
	if ( !projectile )
		velocity_by_aim(attacker, 1, attacker_vec[gnome_number])
	
	vector_to_angle(attacker_vec[gnome_number], attacker_ang)
	
	attacker_ang[0] += random_num(-PUSH_ANGLE, PUSH_ANGLE)
	attacker_ang[1] += random_num(-PUSH_ANGLE, PUSH_ANGLE)
	attacker_ang[2] += random_num(0, PUSH_ANGLE)
	
	angle_vector(attacker_ang, 1, attacker_vec[gnome_number])
	
	attacker_vec[gnome_number][0] *= booster
	attacker_vec[gnome_number][1] *= booster
	attacker_vec[gnome_number][2] *= booster
	
	set_user_velocity(id, attacker_vec[gnome_number])
}

gnome_in_cc_range( id , bring_to_cc = 0 )
{
	SF_ccid = -1
	SF_gnome_team_cc = pev(id, pev_team)
	while( ( SF_ccid = find_ent_by_class(SF_ccid, "team_command") ) > 0 )
	{
		if ( ( pev(SF_ccid, pev_effects) & EF_NODRAW )			// no draw
			|| ns_get_mask(SF_ccid, 4)				// inbuild mask
			|| SF_gnome_team_cc != pev(SF_ccid, pev_team) )
			continue
		
		SF_found_correct_cc = 1
		SF_cc_range = entity_range(SF_ccid, id)
		
		if( SF_cc_range <= GNOME_RANGE )
			return 0
		
		if ( !bring_to_cc
			|| SF_closest_cc_range <= SF_cc_range )
			continue
		
		SF_closest_cc = SF_ccid
		SF_closest_cc_range = SF_cc_range
	}
	
	if ( !SF_found_correct_cc )	// no CC found, so he is free
		return 0
	
	return SF_closest_cc
}

check_if_allowed( gnome_number , check_for_comm = 0 )
{	// check if gnome is allowed to go commander
	new marine_num, marine_alive_num
	new gnome_team = player_team[gnome_id[gnome_number]]
	
	for ( new a = 1; a <= max_player_num; ++a )
	{
		if ( !is_user_connected(a)
			|| player_team[a] != gnome_team )
			continue
		
		++marine_num
		if ( is_user_alive(a) )
			++marine_alive_num
	}
	
	// check if gnome is the only alive player, allow to be comm
	if ( check_for_comm
		&& marine_alive_num < 2 )
		return 1
	
	// check if gnome is the only player
	if ( marine_num < 2 )
		return 1
	
	return 0
}

resupply_player( id , init )
{
	if ( ns_get_mask(id, MASK_DIGESTING) )
		return
	
	new Float:max_health, Float:cur_health
	pev(id, pev_max_health, max_health)
	pev(id, pev_health, cur_health)
	if ( cur_health < max_health ){
		cur_health += 50.0
		if ( cur_health > max_health )
			cur_health = max_health
		
		set_pev(id, pev_health, cur_health)
		
		teleport_effect(id)
	}else
	{
		new ammo_reserve	//, dummy
		//new weap_id = get_user_weapon(id, dummy, ammo_reserve)
		new weap_id = current_weapon[id]
		ammo_reserve = ns_get_weap_reserve(id, weap_id)
		
		new ammoadd_extralev, ammo_to_add, picked_ammo_id
		if ( extratralvl3_loaded )
			ammoadd_extralev = EL_get_ammoadd(id, weap_id)
		
		switch ( weap_id )
		{
			case WEAPON_PISTOL:
			{	// Pistol
				if ( ammo_reserve < 10 + ammoadd_extralev
					|| init )
				{
					ammo_reserve += ( ammo_to_add = 10 )
					if ( ammo_reserve > 30 )
						ammo_reserve = 30
					ns_set_weap_reserve(id, weap_id, ammo_reserve)
					teleport_effect(id)
					picked_ammo_id = 3
				}
			}
			case WEAPON_LMG:
			{	// LMG
				if ( ammo_reserve < 50 + ammoadd_extralev
					|| init )
				{
					ammo_reserve += ( ammo_to_add = 50 )
					if ( ammo_reserve > 250 )
						ammo_reserve = 250
					ns_set_weap_reserve(id, weap_id, ammo_reserve)
					teleport_effect(id)
					picked_ammo_id = 2
				}
			}
			case WEAPON_SHOTGUN:
			{	// Shotgun
				if ( ammo_reserve < 8 + ammoadd_extralev
					|| init )
				{
					ammo_reserve += ( ammo_to_add = 8 )
					if ( ammo_reserve > 40 )
						ammo_reserve = 40
					ns_set_weap_reserve(id, weap_id, ammo_reserve)
					teleport_effect(id)
					picked_ammo_id = 4
				}
			}
			case WEAPON_HMG:
			{	// HMG
				if ( ammo_reserve < 125 + ammoadd_extralev
					|| init )
				{
					ammo_reserve += ( ammo_to_add = 125 )
					if ( ammo_reserve > 250 )
						ammo_reserve = 250
					ns_set_weap_reserve(id, weap_id, ammo_reserve)
					teleport_effect(id)
					picked_ammo_id = 5
				}
			}
			case WEAPON_GRENADE_GUN:
			{	// GL
				if ( ammo_reserve < 4 + ammoadd_extralev
					|| init )
				{
					ammo_reserve += ( ammo_to_add = 4 )
					if ( ammo_reserve > 30 )
						ammo_reserve = 30
					ns_set_weap_reserve(id, weap_id, ammo_reserve)
					teleport_effect(id)
					picked_ammo_id = 6
				}
			}
		}
		if ( picked_ammo_id )
		{
			emessage_begin(MSG_ONE, AmmoPickup_id, {0, 0, 0}, id)
			ewrite_byte(picked_ammo_id)
			ewrite_byte(ammo_to_add)
			emessage_end()
		}
	}
}

check_points_spend_or_level( id , level_check = 0 )
{
	new player_level = 1
	new cur_point_spend = ns_get_points(id)
	if ( extratralvl3_loaded )
		player_level = EL_get_level(id)
	else
	{
		new cur_xp = floatround(ns_get_exp(id))
		new temp_xp, xp_to_next_lvl = 100
		while ( cur_xp > ( temp_xp + xp_to_next_lvl ) )
		{
			temp_xp += xp_to_next_lvl
			xp_to_next_lvl += 50
			++player_level
		}
	}
	
	if ( level_check )
		return ( player_level - 1 )
	
	if ( player_level <= 10 )
	{
		if ( player_level - cur_point_spend > 1 )
			return 1
	}else if ( cur_point_spend < 9 )
		return 1
	
	return 0
}

teleport_effect( id )
{
	new Float:origin[3]
	pev(id, pev_origin, origin)
	playback_event(0, id, phasein_event, 0.0, origin, Float:{0.0, 0.0, 0.0}, 0.0, 0.0, 0, 0, 0, 0)
}

get_items( id , gnome_number )
{
	gnome_died[gnome_number] = 0
	new weapon_num
	get_user_weapons(id, gnome_items[gnome_number], weapon_num)
	
	new class = ns_get_class(id)
	if ( class == CLASS_HEAVY )
		gnome_item_xtra[gnome_number] = 1
	else if ( class == CLASS_JETPACK )
		gnome_item_xtra[gnome_number] = 2
}

regive_items( id , gnome_number , bad_weapons[] = "" , bad_num = 0 , good_weapons[] = "" , good_num = 0 )
{
	// if ns and gnome died dont allow to regive him old equipment
	if ( !bad_num				// bad weapons strin empty
		&& !good_num			// good weapons strin empty
		&& !running_combat
		&& gnome_died[gnome_number] )	// gnome died while being gnome
		return
	
	new weapon_list[32], weapon_num
	get_user_weapons(id, weapon_list, weapon_num)
	strip_user_weapons(id)
	
	new i, j
	new weapon_name[33]
	// regive weapons without the bad ones
	if ( bad_num )
	{
		new found
		for ( i = 0; i < weapon_num; ++i )
		{
			found = 0
			for ( j = 0; j < bad_num; ++j )
			{
				if ( weapon_list[i] != bad_weapons[j] )
					continue
				
				bad_weapons[j] = bad_weapons[bad_num - 1]
				--bad_num
				found = 1
			}
			if ( !found )
			{
				get_weaponname(weapon_list[i], weapon_name, 32)
				ns_give_item(id, weapon_name)
			}
		}
	}
	// and optionally give extra weapons
	if ( good_num )
	{
		for ( i = 0; i < good_num; ++i )
		{
			get_weaponname(good_weapons[i], weapon_name, 32)
			ns_give_item(id, weapon_name)
		}
	// regive all gnome weapons and items
	}else if ( !bad_num && !good_num )
	{
		new gnome_num = player_team[id]
		for ( i = 0; i < strlen(gnome_items[gnome_num]); ++i )
		{
			get_weaponname(gnome_items[gnome_num][i], weapon_name, 32)
			ns_give_item(id, weapon_name)
		}
		new iuser4 = pev(id, pev_iuser4)
		
		if ( gnome_item_xtra[gnome_num] == 1
			&& !( iuser4 & MASK_HEAVYARMOR ) )
			set_pev(id, pev_iuser4, iuser4 + MASK_HEAVYARMOR)
		else if ( gnome_item_xtra[gnome_num] == 2
			&& !( iuser4 & MASK_JETPACK ) )
			set_pev(id, pev_iuser4, iuser4 + MASK_JETPACK)
		
		for ( i = 0; i < 32; ++i )
			gnome_items[gnome_num][i] = 0
		
		gnome_item_xtra[gnome_num] = 0
	}
}

check_armor_upgrade( id )
{
	SF_player_mask = pev(id, pev_iuser4)
	
	return ( SF_player_mask & MASK_ARMOR3 ) ? 3
		: ( ( SF_player_mask & MASK_ARMOR2 ) ? 2
		: ( ( SF_player_mask & MASK_ARMOR1 ) ? 1
		: 0 ) )
}

gnome_weapon_damge( id , gnome_number )
{
	new Float:damge_aplify = get_pcvar_float(CVAR_amplifier), pick_only = get_pcvar_num(CVAR_pickonly)
	new ent_classname[33]
	new weap_mode
	for ( new ent_id = max_player_num + 1; ent_id <= max_entities; ++ent_id )
	{
		if ( !is_valid_ent(ent_id)
			|| pev(ent_id, pev_iuser3) != 15 ) // 15 = AVH_USER3_MARINEITEM
			continue
		
		pev(ent_id, pev_classname, ent_classname, 32)
		if ( pev(ent_id, pev_owner) != id )
			continue
		
		weap_mode = -1
		if ( equal(ent_classname, "weapon_knife") )
		{
			weap_mode = 0
		}else if ( !pick_only )
		{
			if ( equal(ent_classname, "weapon_machinegun") )
				weap_mode = 1
			else if ( equal(ent_classname, "weapon_pistol") )
				weap_mode = 2
			else if ( equal(ent_classname, "weapon_welder") )
				weap_mode = 3
		}
		if ( weap_mode != -1 )
		{
			gnome_weap_bas_damage[gnome_number][weap_mode] = ns_get_weap_dmg(ent_id)
			ns_set_weap_dmg(ent_id, gnome_weap_bas_damage[gnome_number][weap_mode] * damge_aplify)
		}
	}
}

is_same_vec( Float:vec1[3] , Float:vec2[3] )
{
	if ( vec1[0] == vec2[0]
		&& vec1[1] == vec2[1]
		&& vec1[2] == vec2[2] )
		return 1
	
	return 0
}

resupply_msg( id , on )
{
	emessage_begin(MSG_ONE, SetTech_id, {0, 0, 0}, id)
	ewrite_byte(31)
	ewrite_byte(70)
	ewrite_byte(0)
	ewrite_byte(0)
	ewrite_short(1)
	ewrite_short(0)
	if ( on )
	{
		ewrite_byte(4)
	}
	else
	{
		resupply[id] = 0
		ewrite_byte(2)
	}
	emessage_end()
}

//////////////////// Timer Functions ////////////////////
public gnome_ability_timer( timerid_gnomenum )
{
	new id = gnome_id[timerid_gnomenum - 3000]
	if ( is_user_connected(id) )
		set_gnome_abilities(id, timerid_gnomenum - 3000)
}

public xtra_gnome_abilities( timerid_gnomenum )
{
	new id, check_mask_set, gnome_num
	if ( timerid_gnomenum - 3032 > 2 )
	{	// special check
		check_mask_set = 1
		gnome_num = timerid_gnomenum - 3064
	}else
		gnome_num = timerid_gnomenum - 3032
	
	id = gnome_id[gnome_num]
	
	set_gnome_model(id, gnome_num)
	
	if ( !is_user_connected(id) )
		return
	
	ns_set_speedchange(id, - 206 + GNOME_SPEED )	// set speed: - default = 0 -> + GNOME_SPEED = GNOME_SPEED
	gnome_weapon_damge(id, gnome_num)		// set the gnomes weapon damage
	if ( check_mask_set )
		set_pev(id, pev_iuser4, gnome_mask[timerid_gnomenum - 3064] & ~MASK_HEAVYARMOR & ~MASK_JETPACK)	// give rest but not heavy or jetpack
}

public resupply_timer( userid[] )
{
	new id = userid[0]
	if ( is_user_connected(id)
		&& is_user_alive(id) )
		resupply_player(id, 0)
}

public change_comm_gnome( timerid_gnomenum )
{
	new gnomenum = gnome_id[timerid_gnomenum - 4032]
	allow_comm_gnome[gnomenum] = 1
}

public eject_gnome( timerid_gnomenum )
{
	new gnome_num = timerid_gnomenum - 4000
	new id = gnome_id[gnome_num]
	if ( is_user_connected(id)
		&& ns_get_class(id) == CLASS_COMMANDER
		&& !check_if_allowed(gnome_num, 1) )
		client_cmd(id, "stopcommandermode")
}

//////////////////// These functions are called by other plugins to get/set variables ////////////////////

public client_help( id )
{
	help_add("Information", "One player of each Marine Team can become a Gnome")
	help_add("Usage", "Type in chat:^n/gnomeme or /gnome me -> Become a Gnome^n/ungnomeme or /ungnome me -> Get back to normal ( if you are the only player )")
	help_add("Abilities", "A Gnome is slower and weaker than normal. But can build and weld twice as fast.^nHis knife is a pick with increased damage and if Gnome gets hit he will get a knockback.")
}

public client_advertise( id )
{
	return PLUGIN_CONTINUE
}

stock bool:help_add( caption[] , content[] )
{
	new plugin = is_plugin_loaded("Helper")
	if ( plugin == -1 )
		return false
	
	new func = get_func_id("help_add", plugin)
	if ( func == -1 )
		return false
	
	if ( callfunc_begin_i(func, plugin) != 1)
		return false
	
	callfunc_push_str(caption)
	callfunc_push_str(content)
	return callfunc_end() ? true : false
}

//////////////////// This function is called by ExtraLevels 3 to update the reinforced armor status ////////////////////
public GNOME_setget_armor_func( temp_id , num )
{
	new id = get_param(1)
	reinforced_ap[id] = get_param(2)
	marine_armor_up = get_param(3)
	heavy_armor_up = get_param(4)
	// ExtraLevels 3 extra armor (gnome only 60% of default)
	gnome_ap_adds = marine_armor_up * 6 / 10
	
	new Float:gnome_base_ap = gnome_ap_upgrade_value * 3 + GNOME_ARMOR
	set_param_byref(5, floatround(gnome_base_ap))
	set_param_byref(6, floatround(gnome_base_ap + gnome_ap_adds * reinforced_ap[id]))
}

//////////////////// Thise function prevents Gnome from not starting without ExtraLevels 3 ////////////////////
public native_filter( const name[] , index , trap )
{
	if ( !trap )
		return PLUGIN_HANDLED
	
	return PLUGIN_CONTINUE
}
