/*
* This plugin enables Aliens vs Aliens
* - Weapon, players and buildings are now Yellow vs Red (new models)
*
* Credits:
* These go in no particular order but everyone here played a part in helping this happen
*
*	[Custom Lifeform and Weapon models]
*	KCE
*	9 iI IN C IH G IL O C IK
*
*	[Plugin - Author - Why]
*	mvm_allinone - White Panther - Base of this plugin
*	nightvision - mahnsawce - Borrowed for Alien Visi

*
*	[Helping with; convert on-the-fly, optimziing code & for having endless patience ]
*	White Panther
*	Darkness
*
*
*	[Others - what they did]
*	Calimaw - Supvising and commenting on hive locations
*	Isban - Being supportive and being there to help test initial changes
*	OneEyed - Pointing me to a good function for "just-before-map-change" stuff
*	mahnsawce - helping with hive distance loop
*	All those naggers - Keeping me on track and motivated
*
*	by DDR Khat
*
* v1.0:
*	- initial release
*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <ns>

#define	NOTEAM			0
#define	ALIEN			2
#define	ALIEN2			4
#define NAME_HIVEFILE		"hivelocs.ini"
#define MIN_HIVE_SPAWNDIST	700

new plugin_author[] = "DDR Khat"
new plugin_version[] = "1.0"
new avaserver[] =  "0" // 1 = Yes 0 = No

// Register Entities
enum
{
	ENTITY_SKULK = 0,
	ENTITY_GORGE,
	ENTITY_LERK,
	ENTITY_FADE,
	ENTITY_ONOS,
	ENTITY_GESTATE,
	
	ENTITY_HIVE,
	ENTITY_ALIENRESOURCETOWER,
	ENTITY_MOVEMENTCHAMBER,
	ENTITY_SENSORYCHAMBER,
	ENTITY_DEFENSECHAMBER,
	ENTITY_OFFENSECHAMBER,

	ENTITY_END_OF_LIST
}

// Change models
new ava_models[ENTITY_END_OF_LIST][] =
{
	"models/player/alien1/alien1_color.mdl",	// model of skulk
	"models/player/alien2/alien2_color.mdl",	// model of gorge
	"models/player/alien3/alien3_color.mdl",	// model of lerk
	"models/player/alien4/alien4_color.mdl",	// model of fade
	"models/player/alien5/alien5_color.mdl",	// model of onos
	"models/player/gestate/gestate_color.mdl",	// model of Gestation
	
	"models/hive_color.mdl",			// model of hive
	"models/ba_resource_color.mdl",			// model of RT
	"models/ba_movement_color.mdl",			// model of MC
	"models/ba_sensory_color.mdl",			// model of SC
	"models/ba_defense_color.mdl",			// model of DC
	"models/ba_offense_color.mdl"			// model of OC
}


// Entity names for starting structures
new entity_name[2][] =
{
	"team_hive",
	"alienresourcetower"
}

// Team set

enum
{
	tNone = 0,
	tAttacker,
	tDefender,
	tMarine2,
	tAlien2,
	tObserver
}

#define MAXTEAMS	6

new teamnames[MAXTEAMS][] =
{
	"#undefinedteam",
	"Blue",
	"Kharaa",
	"Green",
	"Zerg",
	"#spectatorteam"
}


new g_maxplayers
new g_msgHudText2, g_msgScoreInfo
new player_team[33]

new is_ava_game, is_combat_running, AJrunning, is_gameplay, newgameplay, cantvote , voted, voting, max_entities

new command_found, temp_command_id

new Float:g_oCurSpawnPoint[3]
new g_iShouldMakeSpawn = 0
new Float:loadedhiveorigin[3]
new g_IsMadeAvA = 0
new votes[2]

new g_iEvent_Devour
new g_eCurAttacker, g_iTracesToSkip

// Alienvision stuff

new iFlashLight[33]
new iFLEnabled[33]

#define A1V_RED		220
#define A1V_GREEN	220
#define A1V_BLUE	54
#define A1V_ALPHA	64
#define A2V_RED		180
#define A2V_GREEN	0
#define A2V_BLUE	0
#define A2V_ALPHA	64

#define A1V_LIGHT_RED	165
#define A1V_LIGHT_GREEN	165
#define A1V_LIGHT_BLUE	54
#define A2V_LIGHT_RED	80
#define A2V_LIGHT_GREEN	0
#define A2V_LIGHT_BLUE	0
#define NV_LIGHT_RADIUS	400

#define FFADE_IN	0x0000		// Just here so we don't pass 0 into the function
#define FFADE_OUT	0x0001		// Fade out (not in)
#define FFADE_MODULATE	0x0002		// Modulate (don't blend)
#define FFADE_STAYOUT	0x0004		// ignores the duration, stays faded out until new ScreenFade message received

#define TE_ELIGHT			28

//////////////////// Plugin Init + Forwards ////////////////////
public plugin_init( )
{
	register_cvar("avaenable_version", plugin_version, FCVAR_SERVER)
	register_cvar("amx_avaserver", avaserver, FCVAR_SERVER)
	set_cvar_string("avaenable_version", plugin_version)
	register_clcmd("say /avavote","avavote",ADMIN_CHAT,"Start an AvA Vote") 
	register_menucmd(register_menuid("voting"),1023,"voting_handler");
	
	if ( is_ava_game )
	{
		max_entities = global_get(glb_maxEntities)
		register_plugin("AvAEnable", plugin_version, plugin_author)
		
		for ( new i = 0; i <= ENTITY_OFFENSECHAMBER; ++i )
		{
			engfunc(EngFunc_PrecacheModel, ava_models[i])
		}
		
		g_maxplayers = get_maxplayers()
		
		killstructure( )
		register_event("Countdown", "eCountdown", "ab")
		register_event("ResetHUD", "ePlayerSpawned", "b")
		register_event("TeamInfo", "eTeamChanges", "ab")
		register_event("TeamNames", "eFix_teams", "ab")
		register_event("CurWeapon","eChange_weapon","b")
		
		g_msgHudText2 = get_user_msgid("HudText2")
		g_msgScoreInfo = get_user_msgid("ScoreInfo")
		
		
		register_message(g_msgScoreInfo, "editScoreInfo")
		register_message(g_msgHudText2, "editHudText2")
		register_message(get_user_msgid("TextMsg"), "editTextMsg")
		register_impulse(100,"do_flashlight")
		register_impulse(111,"nofocus")
		
		// <BAD> hacks
		register_impulse(117,"onoshook") //<-----------Prevent Onos
		pause("ac", "badchambers.amxx")
		//
		
		
		register_clcmd("flashlight","do_flashlight")
		register_event("ScreenFade","do_sf","b")
		register_event("DeathMsg","do_dm","ab")
		register_concmd("amx_ava_auto", "amx_ava_auto", ADMIN_LEVEL_E, "<on/off> or <1/0> turns autoassign on or off")
		register_clcmd("jointeamone", "jointeamone_fix")
		
		g_iEvent_Devour = precache_event(1, "events/Devour.sc")
		
		register_forward(FM_PlaybackEvent, "fmhook_PlaybackEvent")
		register_forward(FM_TraceLine, "fmhook_TraceLine_Post", 1)	//1 is POST
		
	}else
		register_plugin("AvAEnable (off)", plugin_version, plugin_author)
}

public plugin_precache( )
{
	new sInfo[8]
	get_localinfo("is_made_ava", sInfo, 7)
	g_IsMadeAvA = str_to_num(sInfo)
	
	is_combat_running = ns_is_combat()
	
	if( g_IsMadeAvA )
	{
		register_forward(FM_KeyValue, "fw_keyvalue")
		register_forward(FM_Spawn, "fmhook_Spawn_Post", 1)		
		cantvote = 1
		is_ava_game = 1
	}
	else
	{
		new mapname[64]
		get_mapname(mapname,63)
		if ( containi(mapname, "_ava_") != -1 )
		{
			is_ava_game = 1
			cantvote = 1
		}
	}
	
	if ( is_ava_game )
	{
		precache_model ( "models/v_lvl1_color.mdl" )
		precache_model ( "models/v_lvl2_color.mdl" )
		precache_model ( "models/v_lvl3_color.mdl" )
		precache_model ( "models/v_lvl4_color.mdl" )
		precache_model ( "models/v_lvl5_color.mdl" )
	}
}

public plugin_end( )
{
	if ( g_IsMadeAvA )
		set_localinfo("is_made_ava","0")
	if ( get_cvar_num("amx_avaserver") == 1 )
		set_localinfo("is_made_ava","1")
}
		
public plugin_cfg( )
{
	LoadHiveOrigin( loadedhiveorigin )
	if ( g_IsMadeAvA )
	{
		MakeHive( )
		FixHive_SpawnDists()
		if( !is_gameplay )
		{
			newgameplay = create_entity("info_gameplay")
			DispatchKeyValue(newgameplay, "teamone", "2")
			DispatchKeyValue(newgameplay, "teamtwo", "2")
			DispatchSpawn(newgameplay)
		}
	
	}
	
	if ( !is_combat_running && !command_found && is_ava_game )
	{
		temp_command_id = create_entity("team_command")
		DispatchKeyValue(temp_command_id, "origin", "0 0 0")
		DispatchKeyValue(temp_command_id, "teamchoice", "1")
		DispatchKeyValue(temp_command_id, "angles", "0 0 0")
		DispatchSpawn(temp_command_id)
	}
}

public client_connect( id )
{
	if ( is_ava_game )
	{
		player_team[id] = NOTEAM
		remove_task(5000+id)
	}
	
	iFlashLight[id] = iFLEnabled[id] = 0
}

public client_putinserver( id )
{
	if (AJrunning)
		set_task(1.0, "task_AutoAssign", 6000 + id)
}

public task_AutoAssign(iTaskID)
{
	new ePlayer = iTaskID - 6000

	if ( is_user_connected(ePlayer) )
		AutoAssign_Player(ePlayer)
}

public client_disconnect( id )
{
	if ( is_ava_game )
	{
		player_team[id] = NOTEAM
		remove_task(5000+id)
	}
}

public client_changeteam( id , newteam , oldteam )
{
	if ( is_ava_game )
	{
		remove_task(5000 + id)
		if ( 1 <= newteam <= 4 )
			modelchange(id)
		else
			player_team[id] = NOTEAM
	}
}

public client_changeclass( id , newclass , oldclass )
{
	if ( is_ava_game )
	{
		if ( is_user_connected(id) )
		{
			if ( newclass != CLASS_DEAD && newclass != CLASS_NOTEAM )
				modelchange(id)
		}
	}
}

public client_spawn( id )
{
	if ( is_ava_game )
	{
		new model[64]
		pev(id, pev_model, model, 63)
		if (equal("models/player.mdl", model))
			modelchange(id)		
	}
	
	return PLUGIN_CONTINUE
}

public client_built( idPlayer , idStructure , type , impulse )
{
	if ( !is_ava_game )
		return
	
	new model_index = -1
	switch ( impulse )
	{
		case 90:
		{
			model_index = ENTITY_ALIENRESOURCETOWER
		}
		case 91:
		{
			model_index = ENTITY_OFFENSECHAMBER
		}
		case 92:
		{
			model_index = ENTITY_DEFENSECHAMBER
		}
		case 93:
		{
			model_index = ENTITY_SENSORYCHAMBER
		}
		case 94:
		{
			model_index = ENTITY_MOVEMENTCHAMBER
		}
		case 95:
		{
			model_index = ENTITY_HIVE
		}
	}
	if ( model_index != -1 )
		red_yellow_model_change(idStructure, model_index)
}

red_yellow_model_change( idStructure , model_index )
{
	new Float:vMin[3], Float:vMax[3], Float:vSize[3], Float:oEnt[3]
	pev(idStructure, pev_mins, vMin)
	pev(idStructure, pev_maxs, vMax)
	pev(idStructure, pev_size, vSize)
	pev(idStructure, pev_origin, oEnt)
	
	entity_set_model(idStructure, ava_models[model_index])
	
	
	set_pev(idStructure, pev_mins, vMin)
	set_pev(idStructure, pev_maxs, vMax)
	set_pev(idStructure, pev_size, vSize)
	set_pev(idStructure, pev_origin, oEnt)
	
	VectorAddSelf(vMin, oEnt)
	VectorAddSelf(vMax, oEnt)
	
	set_pev(idStructure, pev_absmin, vMin)
	set_pev(idStructure, pev_absmax, vMax)
	
	
	if ( pev(idStructure, pev_team) == ALIEN2 )
		set_pev(idStructure, pev_skin, 1)
	else	//if ( pev(idStructure, pev_team) == ALIEN )
		set_pev(idStructure, pev_skin, 0)
	
	set_pev(idStructure, pev_solid, SOLID_BBOX)
}

//////////////////// AvAEnable ////////////////////

public eCountdown( )
{
	hive_rt_model_change(ENTITY_HIVE)
	if ( !is_combat_running)
		hive_rt_model_change(ENTITY_ALIENRESOURCETOWER)
	if ( pev_valid(temp_command_id) )
		set_pev(temp_command_id, pev_flags, pev(temp_command_id, pev_flags) | FL_KILLME)	//safer than remove_entity(temp_command_id)
	return PLUGIN_HANDLED
}

public ePlayerSpawned( id )
{
	new team = pev(id, pev_team)
	
	if ( AJrunning && ( team < 1 || team > 4 ) )
		client_cmd(id, "autoassign")
	
	return PLUGIN_HANDLED
}

public eTeamChanges( )
{
	new teamname[32], id = read_data(1)
	read_data(2,teamname, 31)
	if ( equal(teamname, "alien1team") )
		player_team[id] = ALIEN
	else if ( equal(teamname, "alien2team") )
		player_team[id] = ALIEN2
}

public eFix_teams( id )
{
	message_begin(MSG_ONE, get_user_msgid("TeamNames"), {0, 0, 0}, id)
	write_byte(MAXTEAMS)
	for( new i = 0; i < MAXTEAMS; i++ )
		write_string(teamnames[i])
	message_end()
}

public editScoreInfo( )
{
	new arg7 = get_msg_arg_int(7)
	
	if ( arg7 == tAlien2 || arg7 == tAttacker )
	{
		set_msg_arg_int(7, get_msg_argtype(7), tAlien2)
		
		return BLOCK_SET
	}
	
	return BLOCK_NOT
}

public editHudText2( dummy , dummy2 , receiver )
{	
	if ( !is_user_connected(receiver) )
		return PLUGIN_CONTINUE
	
	new szMessage[64]
	get_msg_arg_string(1, szMessage, 63)
	
	new szMsg[190]
	if ( equal(szMessage, "TeamOneWon") )
	{
		format(szMsg, 189, "Kharaa win!")
		set_msg_arg_string(1, szMsg)
	}else if ( equal(szMessage, "TeamTwoWon") )
	{
  		format(szMsg, 189, "Zerg Win!")
		set_msg_arg_string(1, szMsg)
	}else if ( equal(szMessage, "GameDraw") )
	{
  		format(szMsg, 189, "Tie Game!")
		set_msg_arg_string(1, szMsg)
	}
	
	return PLUGIN_CONTINUE
}

public editTextMsg( dummy , msgid , receiver )
{
	new position
	new message[128]
	get_msg_arg_string(2, message, 127)
	if ( ( position = contain(message, " has joined") ) != -1 )
	{
		new player_name[32]
		// name length is = position
		copy(player_name, position, message)
		
		new ID = get_user_index(player_name)
		
		// just to be sure
		if ( !is_user_connected(ID) )
			return PLUGIN_CONTINUE
		
		if ( pev(ID, pev_team) != 4 )
			return PLUGIN_CONTINUE
		
		new string_length = strlen(message)
		// string length - 1 - 6 = first char of Kharaa
		copy(message[string_length - 1 - 6], 127, "Zerg")
		
		set_msg_arg_string(2, message)
	}
	
	return PLUGIN_CONTINUE
}

public amx_ava_auto( id , level , cid )
{
	if ( !cmd_access(id, level, cid, 2) )
		return PLUGIN_HANDLED
	
	new onoff[5]
	read_argv(1, onoff, 4)
	if ( equal(onoff, "on") || equal(onoff, "1") )
	{
		if ( AJrunning == 1 )
		{
			console_print(id, "AvA Autoassign already enabled")
		}else
		{
			AJrunning = 1
			console_print(id, "AvA Autoassign enabled")
			autoassign_players()
		}
	}
	else if ( equal(onoff, "off") || equal(onoff, "0") )
	{
		if ( AJrunning == 0 )
		{
			console_print(id, "AvA Autoassign already disabled")
		}else
		{
			AJrunning = 0
			console_print(id, "AvA Autoassign disabled")
		}
	}
	return PLUGIN_HANDLED
}

public jointeamone_fix( id )
{
	if ( player_team[id] == NOTEAM )
		client_cmd(id, "jointeamfour")
}

public nofocus(id)
{
	client_print(id, print_chat, "[AvA] Focus is disallowed")
	return PLUGIN_HANDLED
}

//////////////////// Additional Functions ////////////////////
modelchange( id )
{
	if ( !player_team[id] )
	{
		set_task(0.1, "modelchange_timer", 5000 + id)
	}else
	{
		switch (ns_get_class(id))
		{
			case CLASS_SKULK:
				ns_set_player_model(id, ava_models[ENTITY_SKULK])
			case CLASS_GORGE:
				ns_set_player_model(id, ava_models[ENTITY_GORGE])
			case  CLASS_LERK:
				ns_set_player_model(id, ava_models[ENTITY_LERK])
			case  CLASS_FADE:
				ns_set_player_model(id, ava_models[ENTITY_FADE])
			case  CLASS_ONOS:
				ns_set_player_model(id, ava_models[ENTITY_ONOS])
			case  CLASS_GESTATE:
				ns_set_player_model(id, ava_models[ENTITY_GESTATE])
		}
		
		if ( player_team[id] == ALIEN2 )
			set_pev(id, pev_skin, 1)
		else
			set_pev(id, pev_skin, 0)
	}
}

hive_rt_model_change( entity_index )
{
	new hive_rt_id = -1
	while ( ( hive_rt_id = find_ent_by_class(hive_rt_id, entity_name[entity_index - 6]) ) > 0 )
	{
		new Float:vMin[3], Float:vMax[3], Float:vSize[3], Float:oEnt[3]
		pev(hive_rt_id, pev_mins, vMin)
		pev(hive_rt_id, pev_maxs, vMax)
		pev(hive_rt_id, pev_size, vSize)
		pev(hive_rt_id, pev_origin, oEnt)
		
		entity_set_model(hive_rt_id, ava_models[entity_index])
		
		set_pev(hive_rt_id, pev_mins, vMin)	//you need to reset these after entity_set_model()
		set_pev(hive_rt_id, pev_maxs, vMax)
		set_pev(hive_rt_id, pev_size, vSize)
		set_pev(hive_rt_id, pev_origin, oEnt)
		
		VectorAddSelf(vMin, oEnt)
		VectorAddSelf(vMax, oEnt)
		
		set_pev(hive_rt_id, pev_absmin, vMin)
		set_pev(hive_rt_id, pev_absmax, vMax)
		
		
		if( pev(hive_rt_id, pev_team) == ALIEN2 )
			set_pev(hive_rt_id, pev_skin, 1)
		else	
			set_pev(hive_rt_id, pev_skin, 0)
		
		set_pev(hive_rt_id, pev_solid, SOLID_BBOX)
	}
}

autoassign_players( )
{
	for ( new id = 1; id <= g_maxplayers; id++ )
		AutoAssign_Player(id)
}

AutoAssign_Player(ePlayer)
{
	if ( is_user_connected(ePlayer) )
	{
		if ( pev(ePlayer, pev_team) == NOTEAM )
			client_cmd(ePlayer, "autoassign")
	}
}

//////////////////// Timer Functions ////////////////////

public modelchange_timer( timerid_id )
{
	new id = timerid_id - 5000
	if ( is_user_connected(id) )
	{
		modelchange(id)
	}
}

////////////// Change Weapon Models ////////////////////////////

public eChange_weapon( id )
{
	if ( read_data(1) != 6 )
		return PLUGIN_CONTINUE
	
	new wpn_model[65]
	pev(id, pev_viewmodel2, wpn_model, 64)
	if ( contain(wpn_model, "color") == -1 )
	{
		new iViewModel_Num = str_to_num(wpn_model[12])
		switch ( iViewModel_Num )
		{
			case 1:
				set_pev(id,pev_viewmodel2,"models/v_lvl1_color.mdl")
			case 2:
				set_pev(id,pev_viewmodel2,"models/v_lvl2_color.mdl")
			case 3:
				set_pev(id,pev_viewmodel2,"models/v_lvl3_color.mdl")
			case 4:
				set_pev(id,pev_viewmodel2,"models/v_lvl4_color.mdl")
			case 5:
				set_pev(id,pev_viewmodel2,"models/v_lvl5_color.mdl")
		}
	}
	
	return PLUGIN_CONTINUE
}
/////////////Alien Vision////////////////////////////////
public do_dm( id )
{
	if ( iFlashLight[read_data(2)] == 1 )
	{
		doav_off(read_data(2))
	}
	iFlashLight[read_data(2)] = 0
}

doav_on( nvuser )
{
	new origin[3]
	get_user_origin(nvuser, origin)

	message_begin( MSG_ONE, SVC_TEMPENTITY, origin, nvuser )
	write_byte(TE_ELIGHT)
	write_short(nvuser) // entity to follow

   	write_coord( origin[0] ) 
   	write_coord( origin[1] ) 
   	write_coord( origin[2] ) 

	write_coord(NV_LIGHT_RADIUS) // radius
	if ( pev(nvuser,pev_team) == ALIEN )
	{
		write_byte(A1V_LIGHT_RED) // color
		write_byte(A1V_LIGHT_GREEN)
		write_byte(A1V_LIGHT_BLUE)
	}
	else// if (pev(nvuser,pev_team) == ALIEN2)	//skip this test: if the test fails, this message will be all messed up, and probably crash
	{
		write_byte(A2V_LIGHT_RED) // color
		write_byte(A2V_LIGHT_GREEN)
		write_byte(A2V_LIGHT_BLUE)
	}
	write_byte(255) // life
	write_coord(0) // decay
	message_end()
}

public doav_off(nvuser)
{
	new origin[3]
	get_user_origin(nvuser, origin)
	message_begin( MSG_ONE, SVC_TEMPENTITY, origin, nvuser )
	write_byte(TE_ELIGHT)
	write_short(nvuser) // entity to follow

   	write_coord( origin[0] ) 
   	write_coord( origin[1] ) 
   	write_coord( origin[2] ) 

	write_coord(NV_LIGHT_RADIUS) // radius

	write_byte(0) // color
	write_byte(0)
	write_byte(0)

	write_byte(0) // life
	write_coord(0) // decay
	message_end()
}

public do_sf( id )
{
	iFlashLight[id]=0
	doav_off(id)
}

public do_flashlight( id )
{
	if ( !IsAlienClass(id) )
		return PLUGIN_CONTINUE
	
	new iTeam = pev(id, pev_team)
	if ( iFlashLight[id] == 0 )
	{
		if ( iTeam == ALIEN )
		{
			iFlashLight[id] = 1
			doav_on(id)
			do_av(id,1,2.0,A1V_ALPHA,FFADE_OUT | FFADE_STAYOUT, A1V_RED, A1V_BLUE, A1V_GREEN)
			set_pev(id,pev_impulse,0)
			return PLUGIN_HANDLED
		}

		else
		{
			iFlashLight[id] = 1
			doav_on(id)
			do_av(id,1,2.0,A2V_ALPHA,FFADE_OUT | FFADE_STAYOUT, A2V_RED, A2V_BLUE, A2V_GREEN)
			set_pev(id,pev_impulse,0)
			return PLUGIN_HANDLED
		}
	}
	else
	{
		if (iTeam == ALIEN)
		{
			iFlashLight[id] = 0
			doav_off(id)
			do_av(id,1,2.0,A1V_ALPHA,FFADE_IN, A1V_RED, A1V_BLUE, A1V_GREEN)
			set_pev(id,pev_impulse,0)
			return PLUGIN_HANDLED
		}
		else
		{
			iFlashLight[id] = 0
			doav_off(id)
			do_av(id,1,2.0,A2V_ALPHA,FFADE_IN, A2V_RED, A2V_BLUE, A2V_GREEN)
			set_pev(id,pev_impulse,0)
			return PLUGIN_HANDLED
		}
	}
	return PLUGIN_CONTINUE
}

IsAlienClass( ePlayer )
{
	new iClass = ns_get_class(ePlayer)
	if ( ( CLASS_SKULK <= iClass && iClass <= CLASS_ONOS ) || iClass == CLASS_GESTATE )
		return true
	
	return false
}

public do_av( id , duration , Float:hold , alpha , flags , red , blue , green )
{
	message_begin(MSG_ONE,get_user_msgid("ScreenFade"),{0,0,0},id)
	write_short(duration)
	write_short(floatround(hold))
	write_short(flags)
	write_byte(red)
	write_byte(green)
	write_byte(blue)
	write_byte(alpha)
	message_end()
}

/////// Helper /////////
public client_help( id )
{
	help_add("Information", "Enables and fixes Aliens vs Aliens play")
	help_add("Usage", "Type /voteava to change the current map into AvA mode. Vote will not start if map has no defined hive")
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


/// Devour Fix ///

public fmhook_PlaybackEvent( flags , entid , eventid , Float:delay , Float:Origin[3] , Float:Angles[3] , Float:fparam1 , Float:fparam2 , iparam1 , iparam2 , bparam1 , bparam2 )
{
	if ( eventid == g_iEvent_Devour )
	{
		g_eCurAttacker = entid
		g_iTracesToSkip = 1
	}
		
	return FMRES_IGNORED
}

public fmhook_TraceLine_Post( Float:oStart[3] , Float:oEnd[3] , iNoMonsters , eIgnore , trHit )
{
	if ( g_iTracesToSkip )
	{
		g_iTracesToSkip--
	}
	else if ( pev_valid(g_eCurAttacker) )
	{
		new eHit = get_tr2(trHit, TraceResult:TR_pHit)
		
		if ( is_user_connected(eHit) && IsFadeOrOnos(eHit) )
		{
			set_tr2(trHit, TraceResult:TR_pHit, g_eCurAttacker)	//that's right, make the attacker eat himself
			//because of FakeMeta's checks for NULL ents and whatnot, you can't send 0 or -1, you have to send a valid ent.
			//since you obviously can't eat yourself, this effectively blocks the devour.
		}
		
		g_eCurAttacker = -1
	}
	else
		g_eCurAttacker = -1
	
	return FMRES_IGNORED
}

IsFadeOrOnos(ePlayer)
{
	new iClass = ns_get_class(ePlayer)
	if ( (iClass == CLASS_FADE)
	  || (iClass == CLASS_ONOS) )
		return true
	
	return false
}

///////Convert on-the-fly/////////
public fmhook_Spawn_Post( eEnt )
{
	if ( g_iShouldMakeSpawn )
	{
		MakeSpawn()
		g_iShouldMakeSpawn = 0
	}
	
	return FMRES_IGNORED
}

public fw_keyvalue( ent , kvdid )
{
	new classname[32]
	new keyname[32]
	new keyvalue[32]
	get_kvd(kvdid, KV_KeyName, keyname, 31)
	get_kvd(kvdid, KV_Value, keyvalue, 31)
	if ( pev_valid(ent) )
	{
		get_kvd(kvdid, KV_ClassName, classname, 31)
		
		if ( equali(classname, "info_team_start") )
		{
			if ( equali(keyname, "origin") )
			{
				new sX[8], sY[8], sZ[8]
				parse(keyvalue, sX, 7, sY, 7, sZ, 7)	//<3 parse
				
				g_oCurSpawnPoint[0] = str_to_float(sX)
				g_oCurSpawnPoint[1] = str_to_float(sY)
				g_oCurSpawnPoint[2] = str_to_float(sZ)
				g_iShouldMakeSpawn = 1
			}
			else if ( equal(keyname, "teamchoice") && equal(keyvalue, "1") )
				set_kvd(kvdid, KV_Value,"2")
		}
		else if ( equali(classname, "info_gameplay") )
		{
			if ( equali(keyname, "teamone") && !equali(keyvalue,"2") )
				set_kvd(kvdid, KV_Value, "2")
			
			is_gameplay = 1
		}
		else if ( equali(classname, "info_join_team") )
		{
			if ( equali(keyname, "teamchoice") && !equali(keyvalue,"2") )
				set_kvd(kvdid, KV_Value, "4")
		}
	}
	
	return FMRES_IGNORED
}

MakeSpawn( )
{
	new eSpawn = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_team_start"))
	
	set_pev(eSpawn, pev_origin, g_oCurSpawnPoint)
	set_pev(eSpawn, pev_team, ALIEN2)
	
	dllfunc(DLLFunc_Spawn, eSpawn)
}

MakeHive( )
{
	new eSpawn = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "team_hive"))
	set_pev(eSpawn, pev_origin, loadedhiveorigin)
	set_pev(eSpawn, pev_team, ALIEN)
	
	dllfunc(DLLFunc_Spawn, eSpawn)
}

bool:LoadHiveOrigin( Float:oHive[3] )
{
	new sConfigDir[128]
	get_configsdir(sConfigDir, 127)
	
	new sFilePath[128]
	format(sFilePath, 127, "%s/%s", sConfigDir, NAME_HIVEFILE)

	if ( file_exists(sFilePath) )
	{
		new sCurMapName[32]
		get_mapname(sCurMapName, 31)
		
		new iFileHandle = fopen(sFilePath, "r")
		while ( !feof(iFileHandle) )
		{
			new sLine[64]
			fgets(iFileHandle, sLine, 63)
			
			new sMap[32], sOrigin[32]
			strtok(sLine, sMap, 31, sOrigin, 31, '{')
			if ( equal(sCurMapName, sMap) )
			{
				strtok(sOrigin, sOrigin, 31, "", 0, '}')
				
				new sX[8], sY[8], sZ[8]
				parse(sOrigin, sX, 7, sY, 7, sZ, 7)
				oHive[0] = str_to_float(sX)
				oHive[1] = str_to_float(sY)
				oHive[2] = str_to_float(sZ)
				return true
			}
		}
		cantvote = 1
	}
	else
	{
		log_amx("[AVA] Hive Config file ^"%s^" not found in ^"%s^"", NAME_HIVEFILE, sConfigDir)
	}
	
	return false
}


public avavote( id, level, cid )
{
	if (!cmd_access(id,level,cid,1)) 
		return PLUGIN_HANDLED 
	if( !cantvote && !voted && !voting )
	{
		// pause the map vote plugin while this vote is running
		pause("ac", "badcrabmapmanager.amxx") // server 1
		pause("ac", "crabmapmanager.amxx") // server 2
		
		
		voting = 1
		new menubody[128], keys;
		format(menubody,127,"Start Aliens vs Aliens?^n^n1. Yes^n2. No");
		keys = MENU_KEY_1|MENU_KEY_2;
		show_menu(0,keys,menubody,get_cvar_num("amx_vote_time"),"voting");
		set_task(get_cvar_float("amx_vote_time"),"display_results");
	}
	else if( cantvote )
		client_print(id, print_chat, "[AMXX] This map is either already AvA or does not have a hive location for this map.")
	else
		client_print(id, print_chat, "[AMXX] There has been a recent vote. Please wait before trying again.")
	return PLUGIN_HANDLED;
}

public voting_handler( id , key )
{
	if ( key == 0 )
	{
		votes[0]++;
	}
	
	// if they voted no
	if ( key == 1 )
	{
		votes[1]++;
	}
	
	// if we should display their choices
	if ( get_cvar_num("amx_vote_answers") )
	{
		new username[32];
		get_user_name(id,username,31);
		client_print(0,print_chat,"%s voted %s",username,(key == 0) ? "Yes" : "No");
	}
}

public display_results( )
{
	client_print(0,print_chat,"Voting results: %i Yes -- %i No",votes[0],votes[1]);
	if ( votes[0] > votes[1] )
	{
		client_print(0,print_chat,"Starting map in AvA mode");
		set_localinfo("is_made_ava","1")
		message_begin(MSG_ALL, SVC_INTERMISSION)
		message_end()
		set_task(3.0, "reloadmap")
	}
	else
	{
		set_task(120.0,"enablemapvote",0,"")
		// unpause the map vote plugin
		unpause("ac", "badcrabmapmanager.amxx") // server 1
		unpause("ac", "crabmapmanager.amxx") // server 2
	}
	votes[0] = 0;
	votes[1] = 0;
	voted = 1
}

public reloadmap( )
{
	new mapname[64]
	get_mapname(mapname,63)
	server_cmd("changelevel %s", mapname)
}

public enablemapvote( )
{
	voted = 0
}

killstructure( )
{
	for ( new entity_counter = g_maxplayers + 1; entity_counter <= max_entities; entity_counter++ )
	{
		if ( !pev_valid(entity_counter) )
			continue
		
		if ( ShouldRemoveBuilding(entity_counter) )
		{
			set_pev(entity_counter, pev_flags, pev(entity_counter, pev_flags) | FL_KILLME)	//safer than remove_entity(ent_to_remove)
		}
	}
}

bool:ShouldRemoveBuilding( ent )
{
	switch ( pev( ent, pev_iuser3 ) )
	{
		case 17:	return false	//"Hive"
		case 23:	return true	//"Command Console"
		case 24:	return true	//"Turret Factory"
		case 25:	return true	//"Armory"
		case 26:	return true	//"Advanced Armory"
		case 27:	return true	//"Arms Lab"
		case 28:	return true	//"Prototype Lab"
		case 29:	return true	//"Observatory"
		case 33:	return true	//"Turret"
		case 34:	return true	//"Siege Turret"
		case 35:	return true	//"Resource Tower"
		case 37:	return true	//"Infantry Portal"
		case 41:	return true	//"Phasegate"
		case 42:	return true	//"Defense Chamber"
		case 43:	return true	//"Movement Chamber"
		case 44:	return true	//"Offense Chamber"
		case 45:	return true	//"Sensory Chamber"
		case 46:	return false	//"Resource Chamber"
		case 49:	return true	//"Advanced Turret Factory"
		default:	return false	//any other value
	}
	
	return false	//unreachable code, w00t!
}


VectorAddSelf( Float:vA[3] , Float:vB[3] )
{
	vA[0] += vB[0];
	vA[1] += vB[1];
	vA[2] += vB[2];
}

stock check_entity_distance(ent1, ent2)
{
	new Float:orig1[3], Float:orig2[3]
	pev(ent1, pev_origin, orig1)
	set_pev(ent2, pev_origin, orig2)
	return floatround(get_distance_f(orig1, orig2))
}

FixHive_SpawnDists()
{
	new iHiveCount = ns_get_build("team_hive", 0, 0)
	for (new iHiveA = 1; iHiveA <= iHiveCount; iHiveA++)
	{
		new eHiveA = ns_get_build("team_hive", 0, iHiveA)
		new Float:oHiveA[3]
		pev(eHiveA, pev_origin, oHiveA)
		for (new iHiveB = 1; iHiveB <= iHiveCount; iHiveB++)
		{
			if (iHiveA != iHiveB)	//not with itself
			{
				new eHiveB = ns_get_build("team_hive", 0, iHiveB)
				new Float:oHiveB[3]
				pev(eHiveB, pev_origin, oHiveB)
				
				new iNewSpawnDist = floatround(vector_distance(oHiveA, oHiveB) / 2.0)
				new iCurSpawnDist = get_pdata_int(eHiveA, 122, 4)
				
				if (iNewSpawnDist < MIN_HIVE_SPAWNDIST)
					iNewSpawnDist = MIN_HIVE_SPAWNDIST
				
				if (iNewSpawnDist < iCurSpawnDist)
				{
					set_pdata_int(eHiveA, 122, iNewSpawnDist, 4)	//yay pdata
				}
			}
		}
	}
}

public onoshook(id)
{
	ns_popup(id, "Onos is not permitted on AvA")
	return PLUGIN_HANDLED
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
