/***************************************************************************************************
*
* NSVIP: A game mode modification for Natural Selection.
* 
* This is a "Protect the VIP" type of game play mode.
* 
* The VIP's goal is to knife the hive for a score. 
* The Alien's goal is to kill the VIP for a score.
* The Marine's goal is to protect the VIP.
*
* After each round a random VIP is selected from the Marine team. 
*
* The plugin auto-enables if the map name contains "_vip_"
* otherwise it can be enabled on any CO map with the command "amx_startvip"
*
* The total match points can be adjusted during the game with the 
* command "vipscore" followed by a number (Example vipscore 20)
*
*
* --------------------------------------------------------------------------------------------------
* Ver 1.0 Stable version
* Ver 0.8 Added round reset of all players through readyroom. 
* Ver 0.7 Added function to freeze all players at round start while VIP is selected.
* Ver 0.6 Initial release.
* --------------------------------------------------------------------------------------------------
*
* 
*   *************************
*   *     The VIP model     *
*   *      is from the      *	
*   *  Jin Roh Pack v1.0b   * <------ Great model!
*   * for Natural Selection *
*   *  by Obst & Gemuese    *
*   *************************
*
* Last modified: 4/29/10 (or later)
*/


//***[ NSVIP ]**************************************************************************************

#include <amxmodx>
#include <amxmisc>
#include <ns>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>


//***[ Settings ]***********************************************************************************

#define VIP_MODEL	"models/player/soldier/vip_soldier.mdl" 
#define VIP_KNIFE	"models/vip_v_kn.mdl" 
#define VIP_WEAPON	"models/vip_p_kn.mdl"
#define DEFAULT_KNIFE	"models/v_kn.mdl"
#define DEFAULT_WEAPON	"models/p_kn.mdl"

#define VIP_SPEED	-70 	// Relative to normal speed

#define ALIEN_EXP	451.0	//remember the decimal!
#define MARINE_EXP	451.0	//remember the decimal!

#define MARINE_POINTS	2	//Point(s) award for score
#define ALIEN_POINTS	1	//Point(s) award for score


//***[ Initialization ]*****************************************************************************

new g_vip_enabled[3]//"YES" = run in VIP mode \ "OFF" = don't run in VIP mode
new g_vip_id, 
g_marine_score, 
g_alien_score, 
g_timer, 
g_vip_game_mode,
g_vip_round_on, 
g_score_to_win = 10

public plugin_precache()
{ 
	new mapname[64]
	get_mapname(mapname,63)
	if ( containi(mapname, "_vip_")  != -1  )
	{
		set_cvar_string( "g_vip_enabled", "YES" )
		g_vip_game_mode = 1
	}
	get_cvar_string( "g_vip_enabled", g_vip_enabled, 3 )	
	if (( equal( g_vip_enabled, "YES" ) )||(g_vip_game_mode == 1))
	{
		precache_model( VIP_MODEL )
		precache_model( VIP_KNIFE )
		precache_model( VIP_WEAPON )
	}
	return PLUGIN_CONTINUE
}

public plugin_init()
{
	register_cvar( "g_vip_enabled", "" ) //Check if VIP game mode is on
	get_cvar_string( "g_vip_enabled", g_vip_enabled, 3 )
	if ( equal( g_vip_enabled, "YES" ) )
	{
		g_vip_game_mode = 1 
		register_plugin( "NSVIP (on)", "1.0", "TinCan" )
		register_forward( FM_CmdStart, "fwd_CmdStart" ) 
		RegisterHam( Ham_TakeDamage, "team_hive","hive_damage" )
		RegisterHam( Ham_TakeDamage, "team_command", "cc_damage" )
		RegisterHam(Ham_TakeDamage, "player", "player_hurt")
		RegisterHam( Ham_Killed, "player", "player_killed" )
		register_message(get_user_msgid("TextMsg"), "hook_TextMsg")
		register_concmd("vipscore", "vipscore", ADMIN_MENU, "Sets the match points total for VIP mode")
		set_task( Float:0.1, "pause_plugins" )
		set_task( Float:2.5, "show_score" )
		set_task( Float:2.5, "instructions" )
	}
	else
	{
		g_vip_game_mode = 0 	
		register_plugin( "NSVIP (off)", "1.0", "TinCan" )
		register_concmd( "amx_startvip", "start_vip_mode", ADMIN_MENU, " Starts a new round on CO maps in VIP mode." )		
	}
}


//***[ Start VIP Mode ]*****************************************************************************

public start_vip_mode( id, level, cid )
{
	if( ! cmd_access( id, level, cid, 1 ) )
		return PLUGIN_HANDLED
   	if(! ns_is_combat() ) // Check if it is a combat map 
	{
		console_print( id, "VIP mode only works on combat maps." )
		return PLUGIN_HANDLED
	}		
	g_timer = 10
	restart_map
	return PLUGIN_HANDLED
}

public restart_map()
{
	if( g_timer > 0 )
	{
		new message[128]
		formatex( message, 127, "Restarting map for VIP match in %d seconds.",g_timer )
		set_hudmessage( 200, 50, 20, -1.0, 0.35, 0, 6.0, 6.0, 0.1, 0.2, -1 )
		show_hudmessage( 0, message )   
		g_timer--
		set_task(  Float:1.0,"restart_map" ) // This shows a counter
	}
	else
	{
		new message[128]
		formatex( message, 127, "Restarting map for VIP match" )
		set_hudmessage( 200, 50, 20, -1.0, 0.35, 0, 6.0, 1.0, 0.1, 0.2, -1 )
		show_hudmessage( 0, message ) 
		set_cvar_string( "g_vip_enabled", "YES" )
		set_task(  Float:1.0,"call_change_level" ) // This shows a counter
	}
}

public call_change_level()
{
	new mapname[64]
	get_mapname(mapname,63)
	server_cmd("changelevel %s", mapname)	
}


//***[ VIP Mode ]***********************************************************************************

public pause_plugins()
{
	
	// pause some metamod stuff - I Plan to add code to allow these to be listed in ini file also
	server_cmd ( "pause rcbot_mm.dll")
	server_cmd ( "pause whichbot.dll")
	server_cmd ( "pause awards_mm.dll")
	
	// Check ini file for list of plugins to pause
	new filename[256]
	get_configsdir( filename, 255 )
	format( filename, 255, "%s/pause4vip.ini", filename )
	if( ! file_exists( filename ) )
	{
		write_file( filename, "; [NSVIP] List any plugins that should be paused while VIP mod is running.")    
	}   	
	new file = fopen(filename, "rt")
	if( file_exists(filename) )
	{
		new data[64]
		while( !feof(file) )
		{
			fgets(file, data, 63)
			trim(data)
			pause("ac", data)
		}
	}
	fclose(file);
}

public vipscore(id, level, cid) //vipscore: realtime adjustment of score needed to win the game.
{
	if (!cmd_access(id, level, cid, 2)) 
		return PLUGIN_HANDLED
	new arg[25]
	read_argv(1, arg, 24)
	g_score_to_win = str_to_num(arg)
	return PLUGIN_HANDLED
}

public round_start()
{
	if (g_vip_game_mode == 0)
		return PLUGIN_HANDLED
	set_cvar_string( "g_vip_enabled", "OFF" ) //Turn the restart map in VIP mode flag off 
	set_cvar_num( "sv_alltalk", 0 ) //Ensure all talk is off
	g_marine_score = 0 //Reset the score for Marines
	g_alien_score = 0 //reset the score for Aliens

	//Make Hive & CC glow
	new command = find_ent_by_class( 1, "team_command" )
	new hive = find_ent_by_class( 1, "team_hive" )
	set_rendering( command, kRenderFxGlowShell, 0, 170, 255, kRenderNormal, 16 )
	set_rendering( hive, kRenderFxGlowShell, 0, 170, 255, kRenderNormal, 16 )	
	
	wait_for_all_spawn
	return PLUGIN_CONTINUE
}

public start_round()
{
	// Here is where I attempt spread out the events
	// that are about to unfold on the time scale,
	// for every player, and it really pisses me off
	// that it is such a struggle to reset all players
	// in NS at one time.	 ........................
	new counter = 0
	new batchtimer = 1
	for (new i = 1; i <= get_maxplayers(); i++)
	{
		if (!is_valid_ent(i))
		{
			continue
		}
		if( entity_get_int( i,EV_INT_team ) == 1 || entity_get_int( i,EV_INT_team ) == 2 )
  
		{
			
			if (counter >= 2)
				{
					batchtimer ++
					counter =0
				}
			set_task( Float:(batchtimer/10.0), "reset_player_through_readyroom", i )
			counter ++
		}
	}
	set_task( Float:((batchtimer/10.0) + 4.0), "wait_for_all_spawn")
}

public wait_for_all_spawn()
{
	new check_if_alive = 0
	for( new i = 1; i < get_maxplayers(); i++ )
	{
		if( entity_get_int( i,EV_INT_team ) == 1 && (!is_user_alive( i )) )//Add to marine random"izer" array
		{
			check_if_alive = 1
		}	
	}
	if (check_if_alive != 0)
	{
		set_task( Float:0.5, "wait_for_all_spawn" )
	}
	else
	{
		server_cmd("mp_limitteams 1")
		for( new i = 1; i < get_maxplayers(); i++ ) 
		{
			if( entity_get_int( i,EV_INT_team ) == 2 )
			{
				ns_set_exp( i, ALIEN_EXP ) 
			}
			if( entity_get_int( i,EV_INT_team ) == 1 )
			{
				ns_set_exp( i, MARINE_EXP ) 
			}
		}

		for( new i = 1; i < get_maxplayers(); i++ ) 
		{
			ns_set_speedchange( i )
		}	
		set_task( Float:0.1, "pick_vip")
	}
}

public pick_vip()
{
	new marinecount, marineid[33]
	for( new i = 1; i < get_maxplayers(); i++ ) 
	{
		if( entity_get_int( i,EV_INT_team ) == 1 )//Add to marine random"izer" array
		{
			marineid[marinecount] = i
			marinecount++
		}
	}
	g_vip_id = marineid[random( marinecount )] //Pick a random live Marine
	set_task( Float:0.1, "set_vip" )
	set_task( Float:5.0, "roundstart_message") 
}

public fwd_CmdStart( id, uc_handle, seed ) 
{
	if (g_vip_game_mode == 0)
		return PLUGIN_HANDLED
		
	//Force knife on the VIP
	if( ! is_user_alive( id ) ) 
		return FMRES_IGNORED
    	if( g_vip_round_on == 0) 
		return FMRES_IGNORED 
	if( g_vip_id == id )
	{
		engclient_cmd( id,"weapon_knife" )  
		set_pev( id, pev_viewmodel, engfunc(EngFunc_AllocString, VIP_KNIFE ) )
		set_pev( id, pev_weaponmodel, engfunc(EngFunc_AllocString, VIP_WEAPON ) )
	}
	return FMRES_HANDLED 
}

public hook_TextMsg(msgid, msgdest, msgargs) 
{
	if ( g_vip_round_on == 0 ) //block text messages during readyroom reset
	{
		new message[32]
		get_msg_arg_string(2, message, 31) // Get text message         
		if (containi(message, "has joined")) // If text message contains "has joined" then block the message (Thanks to Asmodee)            
			return PLUGIN_HANDLED // Blocks message
	}
	return PLUGIN_CONTINUE // Let other TextMsg messages go through 
}


public player_hurt( id, id_inflictor, id_attacker, Float:Damage, bitsDamageType )
{
	if (id_attacker == g_vip_id)
		{
			SetHamParamFloat( 4, (Float:Damage * 3.0 ) )
			return HAM_HANDLED
		}
	return HAM_IGNORED	
}

public cc_damage( this, inflictor, idattacker, Float:damage, damagebits )
{ 
	if (g_vip_game_mode == 0)
		return PLUGIN_HANDLED
	return HAM_SUPERCEDE //Prevent damage to the CC
}  

public hive_damage( this, inflictor, idattacker, Float:damage, damagebits )
{ 
	if (g_vip_game_mode == 0)
		return PLUGIN_HANDLED
	
	//Watch to see if VIP uses knife on hive
	if( ! pev_valid(this) ) 
		return HAM_IGNORED
	new targetname[32]
	pev( this, pev_targetname, targetname, 31 )
	
	if( ! (idattacker == g_vip_id) )
		return HAM_SUPERCEDE //Preventing damage to the hive for any other player with HAM_SUPERCEDE
	
    	if( g_vip_round_on == 1) //Check if round is in progress
	{	
		//VIP knifed the hive for a score
		g_marine_score += MARINE_POINTS
		display_marine_point //
		end_round
	}
	return HAM_IGNORED	
}

public end_round ()
{	
	g_vip_round_on = 0 // Round is over 
	client_cmd( 0, "spk sound/ambience/alarmloop.wav" )
	set_lights( "c" ) 
	set_task( Float:0.2, "light_blink_timer")

	
	reset_vip	
	if(( g_marine_score >= g_score_to_win ) || ( g_alien_score >= g_score_to_win ))
	{
		end_match
		return PLUGIN_CONTINUE
	}
	set_task( Float:2.0, "start_round" )
	return PLUGIN_CONTINUE
}

public light_blink_timer ()
{
	set_lights( "#OFF" )
}

public player_killed( iVictim, iAttacker, shouldgib )
{ 
	if (g_vip_game_mode == 0)
		return PLUGIN_HANDLED
	set_task(  Float:1.0, "prevent_exp" )
	//Watch to see if VIP was killed
	if(iVictim == g_vip_id ) 
	{
		//VIP has been killed!
		g_alien_score += ALIEN_POINTS			
		display_alien_point //
		end_round
	}
	return PLUGIN_CONTINUE  
}

public prevent_exp()
{
	for( new i = 1; i < get_maxplayers(); i++ )
	{
		if( entity_get_int( i,EV_INT_team ) == 1 )
		{
			if ( ns_get_exp( i ) > MARINE_EXP )
			{
				ns_set_exp( i, MARINE_EXP )
				
			}
		}
		
		if( entity_get_int( i,EV_INT_team ) == 2 )
		{
			if ( ns_get_exp( i ) > ALIEN_EXP )
			{
				ns_set_exp( i, ALIEN_EXP )
			}
		}
	}	
}

public client_changeteam( id, newteam, oldteam )
{
	if( g_vip_game_mode == 0 )
		return PLUGIN_HANDLED
	if( newteam == 1 )
	{
		ns_set_exp( id, MARINE_EXP )
		if (g_vip_round_on == 1) // 
		{
			set_task( Float:0.1, "instructions", id )
		}
		else
		{
			ns_set_speedchange( id, -10000 ) //Freeze player
		}
	}
	if( newteam == 2 )
	{
		ns_set_exp( id, ALIEN_EXP )	
		if (g_vip_round_on == 1) // 
		{
			set_task( Float:0.1, "instructions", id )
		}
		else
		{
			ns_set_speedchange( id, -10000 ) //Freeze player
		}
	}
	if( id == g_vip_id ) //VIP must have left the team
	{
		if (g_vip_round_on == 1)
		{
			g_vip_round_on = 0 
			reset_vip
			vip_left       
		}
	}
	return PLUGIN_CONTINUE
} 

public client_disconnect( id )
{
	if (g_vip_game_mode == 0)
		return PLUGIN_HANDLED
	if( id == g_vip_id ) 
	{
		vip_left
	}
	return PLUGIN_CONTINUE
}

public end_match()
{
	set_task( Float:0.1, "reset_vip" ) 
	//Determine the winning team
	new loosing_team = 1	
	if( g_marine_score == g_score_to_win )
		loosing_team = 2
	//Force loosing team to start quit and NS will do the rest
	for( new i = 1; i < get_maxplayers(); i++ ) 
	{
		if( entity_get_int( i,EV_INT_team ) == loosing_team )
		{
			engclient_cmd( i, "readyroom" ) 
			engclient_cmd( i, "readyroom" ) //Remember it has to be executed twice
		}
	}	
}

public vip_left()
{
	if( ns_round_in_progress() ) 
	{	
		display_vipleft
		set_task(  Float:1.0, "start_round" )	
	}
}

public set_vip()
{
	ns_set_player_model( g_vip_id, VIP_MODEL )
	ns_set_speedchange( g_vip_id, VIP_SPEED )
	set_user_armor( g_vip_id , 200 )
	ns_set_mask( g_vip_id, MASK_HEAVYARMOR, 1) 
	g_vip_round_on = 1 
}

public reset_vip()
{
	set_pev( g_vip_id, pev_viewmodel, engfunc(EngFunc_AllocString, DEFAULT_KNIFE ) )
	set_pev( g_vip_id, pev_weaponmodel, engfunc(EngFunc_AllocString, DEFAULT_WEAPON ) )
	ns_set_player_model( g_vip_id )
	ns_set_speedchange( g_vip_id )
	ns_set_mask( g_vip_id, MASK_HEAVYARMOR, 0 )
}


//***[ Readyroom Reset Handler ]********************************************************************

public reset_player_through_readyroom(i)
{
	if ( entity_get_int(i,EV_INT_team) == 1)
	{
		set_task( Float:0.1, "force_to_team1", i )
	}
	if ( entity_get_int( i,EV_INT_team) == 2 )
	{
		set_task( Float:0.1, "force_to_team2", i )	
	}
	engclient_cmd( i, "readyroom" )
	engclient_cmd( i, "readyroom" )	
}

public force_to_team1(i)
{
	server_cmd("mp_limitteams 0")
	engclient_cmd( i, "jointeamone" )	
	set_task(Float:0.1, "force_to_team1_check", i )
}

public force_to_team1_check(i)
{
	if (!is_valid_ent(i))
		return PLUGIN_HANDLED
		
	if (!( entity_get_int(i,EV_INT_team) == 1)) //Verify player did not get stopped by the readyroom delay "feature"
		set_task(Float:4.0, "force_to_team1", i )
	return PLUGIN_CONTINUE
}

public force_to_team2(i)
{
	server_cmd("mp_limitteams 0")
	engclient_cmd( i, "jointeamtwo" )
	set_task(Float:0.1, "force_to_team2_check", i )
}

public force_to_team2_check(i)
{
	if (!is_valid_ent(i))
		return PLUGIN_HANDLED
	if (!( entity_get_int(i,EV_INT_team) == 2)) //Verify player did not get stopped by the readyroom delay "feature"
		set_task(Float:4.0, "force_to_team2", i )		
	return PLUGIN_CONTINUE
}


//***[ Impulse Handler ]****************************************************************************

public  client_impulse( id, impulse ) 
{
	if( g_vip_game_mode == 0) 
		return PLUGIN_CONTINUE
	
	//Prevent any player from upgrading until round starts
	if( ( ( impulse > 19 ) && ( impulse < 127 ) ) && ( g_vip_round_on == 0 ))
	{
		client_print( id,print_chat, "[VIP MATCH IN PROGRESS] Please wait for the round to start." )
		return PLUGIN_HANDLED
	}

	//Prevent VIP from getting most of the upgrades
	if( ( id == g_vip_id ) && ( ( impulse == 20 ) || ( impulse == 23 ) || ( impulse == 27 ) || ( impulse == 37 )|| ( impulse == 61 )|| ( impulse == 62 ) ) ) //Prevent VIP from getting some of the upgrades
	{	
		client_print( id,print_chat, "[VIP MATCH IN PROGRESS] You are the VIP, You are not allowed to unlock this upgrade." )
		return PLUGIN_HANDLED
	}

	//Prevent players from getting: Focus, Fade, Onos, third-hive, HMG, GL
	if( (impulse == 111) || ( impulse == 116 ) || ( impulse == 117 ) || ( impulse == 126) || (impulse == 65) || ( impulse == 66 ) )
	{
		client_print( id,print_chat, "[VIP MATCH IN PROGRESS] You are not allowed to unlock this upgrade." )
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}


//***[ HUD Messages ]*******************************************************************************

public roundstart_message()
{
	//Show round start message
	new message[128]
	for( new i = 1; i < get_maxplayers(); i++ ) 
	{
		if( entity_get_int( i,EV_INT_team ) == 1 )
		{
			if( i == g_vip_id )
			{
				formatex( message, 127, "You are the VIP^nAttack the hive!" )
			}
			else
			{
				formatex( message, 127, "Choose your upgrades.^nProtect the VIP!" )
			}
		}
		if( entity_get_int( i,EV_INT_team ) == 2 )
		{
			formatex( message, 127, "Choose your upgrades.^nAttack the VIP!" )
		}
		set_hudmessage( 255, 255, 255, -1.0, 0.35, 0, 6.0, 4.0, 0.0, 0.5, -1 )
		show_hudmessage( i, message )  
	}
}
public instructions(id)
{
	new message[128]
	formatex( message, 127, "< VIP mode enabled! >^nThe Marine's protect the VIP.^nThe VIP knives the hive to score %i.^nThe Alien's kill the VIP to score %i.",MARINE_POINTS ,ALIEN_POINTS )
	set_hudmessage( 200, 50, 20, -1.0, 0.35, 0, 6.0, 6.0, 0.1, 0.2, -1 )
	show_hudmessage( id, message )   
	if( ! ns_round_in_progress() ) 
	{
		id = 0 
		set_task(  Float:1.0,"instructions", id ) // this should force the instructions to stay up until the first round is started
	}
}
public display_vipleft()
{
	new message[128]
	formatex( message, 127, "The VIP left the marine team^nRestarting this round." )
	set_hudmessage( 255, 100, 0, -1.0, 0.35, 0, 6.0, 6.0, 0.0, 0.5, -1 )
	show_hudmessage( 0, message )
}
public display_marine_point()
{
	new message[128]
	formatex( message, 127, "The Frontiersmen have scored^nThe VIP knifed the hive!^n^n^nPlease wait for upgrade reset^nand random selection of the VIP." )
	set_hudmessage( 255, 100, 0, -1.0, 0.35, 0, 6.0, 6.0, 0.0, 0.5, -1 )
	show_hudmessage( 0, message )
	if (g_vip_round_on == 0)
	{
		set_task(  Float:1.0,"display_marine_point" ) // this will force until VIP is selected
	}	
}

public display_alien_point()
{
	new message[128]
	formatex( message, 127, "The Kharra have scored^nThe VIP has been killed!^n^n^nPlease wait for upgrade reset^nand random selection of the VIP." )
	set_hudmessage( 255, 100, 0, -1.0, 0.35, 0, 6.0, 6.0, 0.0, 0.5, -1 )
	show_hudmessage( 0, message )
	if (g_vip_round_on == 0)
	{
		set_task(  Float:1.0,"display_alien_point" ) // this will force until VIP is selected
	}
}

public show_score()
{
	new vip_score[128]
	formatex( vip_score, 127, "[ Frontiersmen:  %i ] - VIP: %i Point Match - [     Kharra:  %i     ]", g_marine_score, g_score_to_win, g_alien_score )
	set_hudmessage( 230, 0, 0, -1.0, 0.0, 0, 6.0, 99.0, 0.2, 0.2, -1 )
 	
	if (g_vip_round_on == 1)
	{
		show_hudmessage( 0, vip_score )
	}
	set_task(  Float:2.5, "show_score" )
}

/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
