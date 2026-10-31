/* 
* Hacked by TinCan for ShenTraX and the NS<BAD>Clan 
* 
* This plugin is designed to be a helper for Gorge Race Maps.
*  
* This plugin will watch for round start and force every alien
* player to morph into a gorge.
* During a round it will force a joining alien player to morph
* into a gorge. If the gorge dies it will force the alien player
* to morph into a gorge.
* 
* Marines have no weapons (weapon damage is set to zero just in case).
* 
* Also this plugin has a section for svar settings like
* mp_autoconcede, mp_limitteams, pause plugins etc.
* 
* Special thanks to Asmodee for reviewing and suggesting
* optimization tips all in an effort to prevent clients
* from getting svc_bad error.
*
*
* */
#include <amxmisc> 
#include <amxmodx>
#include <engine> 
#include <time>
#include <ns>
#include <fun>

// ns-classic: registered by NSA_NS_General.amxx; the declaration wasn't in the backup
native NSA_NS_General_Race_Won(id)


new timer = 120 // Pre-round timer
new g_start_race_time // sets starting time so results can be calculated
new g_race_status = 1 // Race is still going while 1 and turns to 0 when the race is complete


public plugin_init() {
	register_plugin( "Gorge Race Helper", "1.3", "TinCan")
	register_dictionary("time.txt") //Format for time display 
	set_task(3.0,"server_settings")	// Small delay to ensure server settings change ok
	register_concmd("grtime", "grtime", ADMIN_MENU, "sets the number of seconds left before the race starts.")
}


public server_settings() {
	set_cvar_num("mp_autoconcede",0)
	set_cvar_num("mp_limitteams",32) 
	set_cvar_num("mp_countdowntime",100) // 100 = forever? Race is started by the timer	
	set_cvar_num("mp_team1damagepercent", 0)
	set_cvar_num("mp_team2damagepercent", 0)
	set_cvar_num("mp_combattime", 90)
	pause("ac", "stacksplit.amxx")
	pause("ac", "classctrl.amxx")
	pause("ac", "idlekicker.amxx")
	prehudmessage
}

public grtime(id, level, cid) {
	if (!cmd_access(id, level, cid, 2)) 
		return PLUGIN_HANDLED
	new arg[25]
	read_argv(1, arg, 24)
	timer = str_to_num(arg)
	return PLUGIN_HANDLED
}


public start_race(){
	set_cvar_num("mp_countdowntime",0)
	//**********************************************
	new message[128]
	formatex(message, 127, "The race has begun ^n Beware of the skull and cross bones!")
	set_hudmessage(0, 100, 255, -1.0, 0.35, 0, 6.0, 12.0, 0.1, 0.2, -1)
	show_hudmessage(0, message)   
	//**********************************************
	//**********************************************
	new message1[128]
	formatex(message, 127, "Go") // This doesn't seem to show but  at least it clears the counter off the screen
	set_hudmessage(0, 100, 255, -1.0, -3.0, 0, 6.0, 12.0, 0.1, 0.2, -1)
	show_hudmessage(0, message1)   
	//**********************************************
}

public round_start()
{
	//g_round_started = 1
	g_start_race_time = get_systime() // Set start time for end calculation
	for(new i = 1; i < 32; i++)
	{
		if( entity_get_int( i,EV_INT_team ) == 1 )
		{
			set_task(0.1,"strip_marine_weapon", i ) 	
		}
				
		if( entity_get_int( i,EV_INT_team ) == 2 )
		{
			set_task(0.1,"switch_player_to_gorge", i ) 
			set_task(0.3,"switch_player_to_gorge", i ) // Try a second time for any stragglers @ round start
		}
	
}	
}

public switch_player_to_gorge(i)
{
	if( ns_get_exp( i ) < 101)
	{
		ns_set_exp( i, str_to_float("101") )
	}
	if( ! (ns_get_class( i ) == CLASS_GORGE) )
	{
		console_cmd( i, "impulse 114" )
	}
}


public  client_spawn ( id )
{
	if( entity_get_int( id,EV_INT_team ) == 2 )
	{
		set_task(0.1,"switch_player_to_gorge", id ) 
	}
	else
	{
		set_task(0.1,"strip_marine_weapon", id ) 	
	}
}

public client_changeteam ( id, newclass, oldclass )
{ 
	if (newclass == 1)
	{
		set_task(0.1,"strip_marine_weapon", id ) 	
	}
	if (newclass == 2) 
	{
		set_task(0.1,"switch_player_to_gorge", id ) 
	}
}


public strip_marine_weapon(id)
{
	strip_user_weapons ( id ) 	
}


public prehudmessage() {
    new countdown_message[128]
    if(timer > 0){
	formatex(countdown_message, 127, "The next Gorge Race will start in %d seconds.",timer)
	set_hudmessage(0, 100, 255, -1.0, -3.0, 0, 6.0, 12.0, 0.1, 0.2, -1)
  	show_hudmessage(0, countdown_message)   
	timer--
	if (timer < 4){
			client_cmd(0,"spk buttons/bell1")
	}
	set_task(1.0,"prehudmessage") // This shows a counter
        return PLUGIN_HANDLED
	}
    else {
    	start_race
	}
    return PLUGIN_HANDLED
}

// Called when two entities touch/collide.- Watch for event and display winner
public pfn_touch(ptr,ptd) {
	if (g_race_status == 1) {
		new classptr[32],classptd[32]
		entity_get_string(ptr,EV_SZ_classname,classptr,31) //
		entity_get_string(ptd,EV_SZ_classname,classptd,31) //
		if ( equal(classptd, "func_breakable" ) && entity_get_int(ptr,EV_INT_team) == 2 )   {
			
			new winner_message[128], race_time[128],name_ptr[32]		
			get_user_name(ptr, name_ptr, 31)
			get_time_length ( 0, (get_systime() - g_start_race_time), timeunit_seconds, race_time, 128) 
			
			client_cmd(0,"spk ambience/goal_1")
			formatex(winner_message, 127, "* WE HAVE A WINNER! * ^n %s ^n completed the course in %s", name_ptr, race_time)
			set_hudmessage(0, 100, 255, -1.0, 0.35, 0, 6.0, 15.0, 0.1, 0.2, -1)
			show_hudmessage(0, winner_message)
			client_print( 0, print_chat, "%s completed the course in %s", name_ptr, race_time)
			log_amx("%s completed the course in %s", name_ptr, race_time)
			g_race_status = 0	
			NSA_NS_General_Race_Won(ptd)
		}
	} 
}
