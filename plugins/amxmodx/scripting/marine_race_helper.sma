#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <time>

// ns-classic: registered by NSA_NS_General.amxx; the declaration wasn't in the backup
native NSA_NS_General_Race_Won(id)


new timer = 120 // Pre-round timer
new g_start_race_time // sets starting time so results can be calculated
new g_race_status = 1 // Race is still going while 1 and turns to 0 when the race is complete


public plugin_init()
{
	register_plugin( "Marine_Race_Helper", "1.0", "TinCan")
	register_forward( FM_CmdStart, "fwd_CmdStart" ) 
	register_dictionary("time.txt") //Format for time display 
	register_concmd("mrtime", "mrtime", ADMIN_MENU, "sets the number of seconds left before the race starts.")
	register_concmd("mrff", "friendly_fire_mode_on", ADMIN_MENU, "sets Friendly Fire on for 30 seconds.")
	register_clcmd("jointeamtwo","force_marine")
	register_clcmd("autoassign","force_marine")
	set_task(Float:3.0,"server_settings")	// Small delay to ensure server settings change ok
	set_task(Float:0.5,"add_a_bot")
	

}

public mrtime(id, level, cid) {
	if (!cmd_access(id, level, cid, 2)) 
		return PLUGIN_HANDLED
	new arg[25]
	read_argv(1, arg, 24)
	timer = str_to_num(arg)
	return PLUGIN_HANDLED
}


public force_marine (id)
{
	client_cmd(id,"jointeamone")
	return PLUGIN_HANDLED
}


public server_settings() {
	//set_cvar_num("mp_team1damagepercent", 50)
	set_cvar_num("mp_autoconcede",0)
	set_cvar_num("mp_limitteams",32) 
	set_cvar_num("mp_countdowntime",100) // 100 = forever? Race is started by the timer	
	set_cvar_num("mp_combattime", 90)
	pause("ac", "idlekicker.amxx")
	prehudmessage
}


public add_a_bot()
{			
	new bot = engfunc(EngFunc_CreateFakeClient, "Marine Race Bot")
	if(!bot) return PLUGIN_HANDLED
	engfunc(EngFunc_FreeEntPrivateData, bot)
	static szRejectReason[128]
	dllfunc(DLLFunc_ClientConnect, bot, "Marine Race Bot", "127.0.0.1", szRejectReason)
	if(!is_user_connected(bot)) return PLUGIN_HANDLED
	dllfunc(DLLFunc_ClientPutInServer, bot)
	set_pev(bot,pev_spawnflags, pev(bot, pev_spawnflags) | FL_FAKECLIENT)
	set_pev(bot,pev_flags, pev(bot,pev_flags) | FL_FAKECLIENT)
	engclient_cmd( bot, "jointeamtwo" )
	return PLUGIN_HANDLED
}

public fwd_CmdStart( id, uc_handle, seed ) 
{
	//Force pistol on Marines
	if( ! is_user_alive( id ) ) return FMRES_IGNORED
	if( entity_get_int( id,EV_INT_team ) == 1 )
		{
			client_cmd( id,"weapon_pistol" ) 
		}
	return FMRES_HANDLED 
}

public prehudmessage() {
    new countdown_message[128]
    if(timer > 0){
	formatex(countdown_message, 127, "The next Marine Race will start in %d seconds.",timer)
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


public round_start()
{
	g_start_race_time = get_systime() // Set start time for end calculation
}


public friendly_fire_mode_on ()
{
	
	//**********************************************
	new message[128]
	formatex(message, 127, "**  Friendly Fire is on for 30 seconds!  **")
	set_hudmessage(255, 0, 0, -1.0, 0.35, 0, 6.0, 12.0, 0.1, 0.2, -1)
	show_hudmessage(0, message)   
	//**********************************************	
	set_task(Float:30.0,"friendly_fire_mode_off")
	client_cmd(0,"spk turret/tu_spinup")
	set_cvar_num("mp_friendlyfire",1) 
	
	
	
}

public friendly_fire_mode_off()
{
	
	//**********************************************
	new message[128]
	formatex(message, 127, "**  Friendly Fire is now off  **^nKeep trying!")
	set_hudmessage(0, 100, 255, -1.0, 0.35, 0, 6.0, 12.0, 0.1, 0.2, -1)
	show_hudmessage(0, message)   
	//**********************************************	
	client_cmd(0,"spk turret/tu_spindown")
	set_cvar_num("mp_friendlyfire",0) 
}


public start_race(){
	set_cvar_num("mp_countdowntime",0)
	//**********************************************
	new message[128]
	formatex(message, 127, "The race is starting")
	set_hudmessage(0, 100, 255, -1.0, 0.35, 0, 6.0, 8.0, 0.1, 0.2, -1)
	show_hudmessage(0, message)   
	//**********************************************
	//**********************************************
	new message1[128]
	formatex(message, 127, "Go") // This doesn't seem to show but  at least it clears the counter off the screen
	set_hudmessage(0, 100, 255, -1.0, -3.0, 0, 6.0, 12.0, 0.1, 0.2, -1)
	show_hudmessage(0, message1)   
	//**********************************************
}

// Called when two entities touch/collide.- Watch for event and display winner
public pfn_touch(ptr,ptd) {
	if (g_race_status == 1) {
		new classptr[32],classptd[32]
		entity_get_string(ptr,EV_SZ_classname,classptr,31) //
		entity_get_string(ptd,EV_SZ_classname,classptd,31) //
		if ( equal(classptd, "func_breakable" ) && entity_get_int(ptr,EV_INT_team) == 1 )   {
			
			new winner_message[128], race_time[128],name_ptr[32]		
			get_user_name(ptr, name_ptr, 31)
			get_time_length ( 0, (get_systime() - g_start_race_time), timeunit_seconds, race_time, 128) 
			
			client_cmd(0,"spk ambience/goal_1")
			formatex(winner_message, 127, "* WE HAVE A WINNER! * ^n %s ^n completed the Marine course in %s", name_ptr, race_time)
			set_hudmessage(0, 100, 255, -1.0, 0.35, 0, 6.0, 15.0, 0.1, 0.2, -1)
			show_hudmessage(0, winner_message)
			client_print( 0, print_chat, "%s completed the Marine course in %s", name_ptr, race_time)
			log_amx("%s completed the Marine course in %s", name_ptr, race_time)
			g_race_status = 0	
			NSA_NS_General_Race_Won(ptd)
		}
	} 
}
