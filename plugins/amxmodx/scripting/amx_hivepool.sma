#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <ns>
#include <helper>

#define PLUGIN_AUTHOR		"Foo@Trogdor"
#define PLUGIN_VERSION		"1.5"
#define VOTE_TIME 15

new GRrunning = 1
new Float:roundstart_time
new Float:respool
new markhive[5]
new g_pool = -1
new DONATE_GOAL = 400
new DONATE_WAIT_TIME = 0

//VOTING ADDON
new g_DCA, g_MCA, g_SCA
new g_voteCount[3]
new voted[33], once, previous
new g_voteTime = VOTE_TIME
new g_countDown = 6
new g_sound[] = "hud/countdown.wav"
new g_sound1[] = "hud/alien_now.wav"

#define MARINE		1
#define ALIEN		2
#define MARINE2		3

public plugin_precache()
{
	precache_sound(g_sound)
	precache_sound(g_sound1)
}

public plugin_init( )
{
	register_cvar("hivepool_version", PLUGIN_VERSION, FCVAR_SERVER)
	set_cvar_string("hivepool_version", PLUGIN_VERSION)
	
	if ( ns_is_combat() )
	{
		register_plugin("Hive Pool (off)", PLUGIN_VERSION, PLUGIN_AUTHOR)
		
		pause("ad")
		
		return
	}
	
	register_plugin("Hive Pool", PLUGIN_VERSION, PLUGIN_AUTHOR)
	register_concmd("amx_hivepool", "amx_hivepool", ADMIN_LEVEL_E, "<on/off> or <1/0> turns Hive Pool on or off")
	register_concmd("amx_pool_goal", "amx_pool_goal", ADMIN_LEVEL_E, "Amount of Resources To Switch Chambers")
	register_concmd("amx_pool_wait", "amx_pool_wait", ADMIN_LEVEL_E, "Amount of Seconds until players can donate")
	register_menucmd(register_menuid("VoteChamber"),MENU_KEY_6|MENU_KEY_7,"chamberCount")
	register_clcmd("givepool", "donate_pool")
	register_clcmd("say", "donate_pool_say")
	register_clcmd("say_team", "donate_pool_say")
	register_event("Countdown", "pCountdown", "ab")
	g_pool = floatround(respool)

}

public amx_hivepool( id , level , cid )
{
	if ( !cmd_access(id, level, cid, 2) )
		return PLUGIN_HANDLED
	
	new onoff[5]
	read_argv(1, onoff, 4)
	if ( equal(onoff, "on")
		|| equal(onoff, "1") )
	{
		if ( GRrunning == 1 )
		{
			console_print(id, "Hive Pool already enabled")
		}else
		{
			GRrunning = 1
			console_print(id, "Hive Pool enabled")
			client_print(0, print_chat, "[Hive Pool] Admin has turned plugin on")
		}
	}else if ( equal(onoff, "off")
		|| equal(onoff, "0") )
	{
		if ( GRrunning == 0 )
		{
			console_print(id, "Hive Pool already disabled")
		}else
		{
			GRrunning = 0
			console_print(id, "Hive Pool disabled")
			client_print(0, print_chat, "[Hive Pool] Admin has turned plugin off")
		}
	}
	return PLUGIN_HANDLED
}

public amx_pool_goal( id , level , cid )
{
	if ( !cmd_access(id, level, cid, 2) )
		return PLUGIN_HANDLED
	new goal[10]
	read_argv(1, goal, 9)
	DONATE_GOAL = str_to_num(goal)
	return PLUGIN_HANDLED
}

public amx_pool_wait( id , level , cid )
{
	if ( !cmd_access(id, level, cid, 2) )
		return PLUGIN_HANDLED
	new time[10]
	read_argv(1, time, 9)
	DONATE_WAIT_TIME = str_to_num(time)
	return PLUGIN_HANDLED
}

public donate_pool( id )
{
	if ( !is_alien(id) )
		return PLUGIN_HANDLED
	
	new res[4]
	read_argv(1, res, 3)
	check_and_pool(id, float(str_to_num(res)))
	return PLUGIN_HANDLED
}

public donate_pool_say( id )
{
	if ( !is_alien(id) )
		return PLUGIN_CONTINUE
	
	new Speech[31]
	read_args(Speech, 30)
	remove_quotes(Speech)
	if ( equali(Speech, "givepool", 8)
		|| equali(Speech, "/givepool", 9) )
	{
		new res
		for ( new i = 7; Speech[i]; ++i )
		{
			if ( !isdigit(Speech[i]) )
				continue
			
			res = str_to_num(Speech[i])
			break
		}
		check_and_pool(id, float(res))
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public pCountdown( )
{
	roundstart_time = get_gametime()
	register_event( "ResetHUD", "WaitShowPoolStatus", "b")
	register_event( "HideWeapon", "WaitShowPoolStatus", "b")
	set_task( 1.0, "UpdatePoolStatus",_,_,_, "b" )
	
	return PLUGIN_HANDLED
}

check_and_pool( id , Float:res )
{
	if ( GRrunning != 1 )
	{
		client_print(id, print_chat, "[Hive Pool] Donating is currently off")
		return
	}
	if ( get_gametime() - roundstart_time <= DONATE_WAIT_TIME )
	{
		new Float:gametime = get_gametime()
		new Float:roundtime = (DONATE_WAIT_TIME - (gametime - roundstart_time))	
		new Float:minutes = float(floatround(roundtime/60, floatround_floor))
		new Float:seconds    = roundtime-(minutes*60)
		if(DONATE_WAIT_TIME - (gametime - roundstart_time) < 60)
		{
			client_print(id, print_chat, "[Hive Pool] You must wait %i more seconds until you can donate", floatround(seconds))
		}
		if(DONATE_WAIT_TIME - (gametime - roundstart_time) > 60)
		{
			if(floatround(seconds) != 0)
				client_print(id, print_chat, "[Hive Pool] You must wait %i minute(s) and %i more second(s) until you can donate", floatround(minutes), floatround(seconds))
			if(floatround(seconds) == 0 )
				client_print(id, print_chat, "[Hive Pool] You must wait %i minute(s) until you can donate", floatround(minutes))
		}
		return
	}

	
	if (ns_get_build("team_hive",1) < 2)
	{
		client_print(id, print_chat, "[Hive Pool] You can't donate until there are 2 hives")
		return
	}
	if (ns_get_build("team_hive",1) == 3)
	{
		client_print(id, print_chat, "[Hive Pool] You have all 3 hives, donating has been temporarily suspended.")
		return
	}
	if ( res < 1.0 )
	{
		client_print(id, print_chat, "[Hive Pool] You have to donate at least 1 res")
		return
	}
	
	new Float:userres = ns_get_res(id)
	
	if ( userres < 1.0 )
	{
		client_print(id, print_chat, "[Hive Pool] You must have at least 1 res")
		return
	}
	
	if ( userres < res )
		res = userres
	
	if ( respool + res > DONATE_GOAL )
		res = DONATE_GOAL - respool
	
	respool = res + respool
	ns_set_res(id, userres - res)
	
	new Float:giveres = DONATE_GOAL-respool
	
	client_print(id, print_chat, "[Hive Pool] You have donated %i Resource to the pool.  The Pool now has %i Resources",floatround(res),floatround(respool))
	if (giveres != 0)
		client_print(id, print_chat, "[Hive Pool] Your team needs to donate %i more Resources to switch chambers",floatround(giveres))

	if (respool == DONATE_GOAL)
	{	
		set_task(1.0,"countdown",12345,"",_,"a",6)
//		set_task(5.0,"chamberVote",12345,"",_,"a",g_voteTime+1)
	}
	g_countDown = 6
}

is_alien( id )
{
	new teamname[32]
	get_user_team(id, teamname, 31)
	if ( equali(teamname, "alien", 5) )
		return 1
	
	return 0
}

public create_new_chamber( oldtrait )
{
	new trait[3]
	new newhive
	for(new x=1;x<=2;x++) {
		markhive[x] = ns_get_build("team_hive",1,x)
		trait[x] = ns_get_hive_trait(markhive[x])
		if(trait[x] == oldtrait)
			newhive = x
	}
	new newchamber[11]

	if(trait[1] == HIVETRAIT_DC){
		if(trait[2] == HIVETRAIT_MC){
			ns_set_hive_trait(markhive[newhive],HIVETRAIT_SC)
			format(newchamber, 9, "Sensory", 8)
		}else{
			ns_set_hive_trait(markhive[newhive],HIVETRAIT_MC)
			format(newchamber, 10, "Movement", 9)
		}
	}else if(trait[1] == HIVETRAIT_MC){
		if(trait[2] == HIVETRAIT_DC){
			ns_set_hive_trait(markhive[newhive],HIVETRAIT_SC)
			format(newchamber, 9, "Sensory", 8)
		}else{
			ns_set_hive_trait(markhive[newhive],HIVETRAIT_DC)
			format(newchamber, 11, "Defense", 10)	
		}
	}else if(trait[1] == HIVETRAIT_SC){
		if(trait[2] == HIVETRAIT_DC){
			ns_set_hive_trait(markhive[newhive],HIVETRAIT_MC)
			format(newchamber, 10, "Movement", 9)
		}else{
			ns_set_hive_trait(markhive[newhive],HIVETRAIT_DC)
			format(newchamber, 11, "Defensive", 10)	
		}
	}else if(trait[1] == HIVETRAIT_NONE || trait[2] == HIVETRAIT_NONE ){}
	


	for ( new i = 1; i <= get_maxplayers(); i++ ) 
	{
			if ( pev(i, pev_team) == 2 ) {
				set_hudmessage(255, 100, 0, -1.0, 0.15, 1, 1.0, 7.5, 4.5, 0.2, 4)
				show_hudmessage(i,"         You Now Have Access to %s Chambers", newchamber)
				client_print(i, print_chat, "[Hive Pool] NOTICE: The Hive pool has been filled. You May Now Drop A %s Chamber!!!", newchamber)	
				client_cmd(i, "spk sound/%s", g_sound1)
			}
			if ( pev(i, pev_team) == 1 ) {
				set_hudmessage(0, 255, 0, -1.0, 0.15, 1, 1.0, 7.5, 0.1, 0.2, 1)
				show_hudmessage(i,"         NOTICE: Aliens Now Have Access To All 3 Chambers")
				client_print(i, print_chat, "[Hive Pool] MARINES: Aliens have filled the Hive pool. They now have a third chamber!")	
			}
	}
	respool = respool - DONATE_GOAL
	previous = once
}

public UpdatePoolStatus() {
	new teamsToUpdate

	if ( g_pool != respool ) {
		g_pool = floatround(respool)
		teamsToUpdate |= ALIEN
	}

	PoolTeamStatus( teamsToUpdate )

	return PLUGIN_HANDLED
}

PoolTeamStatus( teamsToUpdate ) {
	for (new id=1 ; id <= get_maxplayers() ; ++id) {
		if (!is_valid_ent(id)) continue

		if (pev(id, pev_team) == ALIEN) {
			if (teamsToUpdate & ALIEN)
				ShowPoolStatus( id )
		}
	}
}

public WaitShowPoolStatus( id ) {
	if (pev(id, pev_team) == ALIEN)
		set_task( 1.0, "ShowPoolStatus", id )

	return PLUGIN_HANDLED
}

public ShowPoolStatus( id ) 
{
	set_hudmessage(255, 100, 0, 0.80, is_user_alive(id)?0.95:0.9, 0, 1.0, 3600.0, 1.0, 1.0, 3)
	if (ns_get_build("team_hive",1) == 2)
		show_hudmessage( id, "Say /givepool to donate^nHive Pool: %i out of %i", floatround(respool), DONATE_GOAL)
}


/*       Chamber Vote       */

public chamberVote(id) {
	if (respool == DONATE_GOAL){
		for ( new i = 1; i <= get_maxplayers(); i++) 
			if ( pev(i, pev_team) == 2 && !voted[i] && is_user_connected(i)) 
				show_menu( i, ((1<<5)|(1<<6)), " ", g_voteTime, "VoteChamber") 
		if(once == previous) {
			g_voteCount = { 0, 0, 0 }
			set_task(1.0,"chamberVote",12345,"",_,"a",g_voteTime+1)
			set_task(1.0,"checkVotes",99889988,"",_,"a",g_voteTime)
			once = previous++
			return PLUGIN_HANDLED
		}
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED

}

public chamberCount(id,key) {
	if (respool == DONATE_GOAL){
		voted[id] = 1
		++g_voteCount[key-5]
		if ( !get_cvar_num("amx_show_activity") ) return PLUGIN_HANDLED

		new name[32]
		switch( get_cvar_num("amx_show_activity") ) {
			case 1: format( name, 31, "Player" )
			case 2: get_user_name(id, name, 31)
		}

		for ( new i = 1; i <= get_maxplayers(); i++ ) {
			if ( pev(i, pev_team) == 2 && is_user_connected(i) ) {
				client_print(i, print_chat, "%s voted for option #%d", name, key + 1)
			}
		}
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}

public countdown()
{
	g_countDown -= 1
	
	for(new i=1;i<=get_maxplayers();i++) 
		if(pev(i,pev_team) == 2 && is_user_connected(i)) { 
			set_hudmessage(255, 100, 0, -1.05, 0.30, 0, 1.0, float(g_countDown+1), 0.1, 0.1, 2)
			show_hudmessage(i,"        The Chamber vote will be starting in %i SECONDS",g_countDown)
			if(g_countDown <= 3)
				client_cmd(i, "spk sound/%s", g_sound)
		}
	if(g_countDown == 1)
		set_task(1.0,"chamberVote",12345,"",_,"a",g_voteTime+1)
}

public checkVotes() {
	
	new result
	g_voteTime -= 1

	new trait[3]
	new oldtrait
	
	for(new x=1;x<=2;x++) {
		markhive[x] = ns_get_build("team_hive",1,x)
		trait[x] = ns_get_hive_trait(markhive[x])
	}

	if (trait[1] == HIVETRAIT_DC || trait[2] == HIVETRAIT_DC)
		g_DCA = 1
	if (trait[1] == HIVETRAIT_MC || trait[2] == HIVETRAIT_MC)
		g_MCA = 1
	if (trait[1] == HIVETRAIT_SC || trait[2] == HIVETRAIT_SC)
		g_SCA = 1

	if(g_voteTime >= 0) {

		if(g_DCA == 1 && g_MCA == 1) {
			for(new i=1;i<=get_maxplayers();i++) 
				if(pev(i,pev_team) == 2 && is_user_connected(i)) { 
					set_hudmessage(255, 100, 0, -1.05, 0.30, 0, 1.0, float(VOTE_TIME+1), 0.1, 0.1, 2)
					show_hudmessage(i,"        Choose A Chamber for Sensory (SCs) to replace (%i seconds):^n        6. Defense Chamber (%i votes)^n        7. Movement Chamber (%i votes) ",g_voteTime,g_voteCount[0],g_voteCount[1])
				}
		}
		if(g_DCA == 1 && g_SCA == 1) {
			for(new i=1;i<=get_maxplayers();i++) 
				if(pev(i,pev_team) == 2 && is_user_connected(i)) { 
					set_hudmessage(255, 100, 0, -1.05, 0.30, 0, 1.0, float(VOTE_TIME+1), 0.1, 0.1, 2)
					show_hudmessage(i,"        Choose A Chamber for Movement (MCs) to replace (%i seconds):^n        6. Defense Chamber (%i votes)^n        7. Sensory Chamber (%i votes) ",g_voteTime,g_voteCount[0],g_voteCount[1])
				}
		}
		if(g_MCA == 1 && g_SCA == 1) {
			for(new i=1;i<=get_maxplayers();i++) 
				if(pev(i,pev_team) == 2 && is_user_connected(i)) { 
					set_hudmessage(255, 100, 0, -1.05, 0.30, 0, 1.0, float(VOTE_TIME+1), 0.1, 0.1, 2)
					show_hudmessage(i,"        Choose A Chamber for Defense (DCs) to replace (%i seconds):^n        6. Sensory Chamber (%i votes)^n        7. Movement Chamber (%i votes) ",g_voteTime,g_voteCount[0],g_voteCount[1])
				}
		}
	}

	if(g_voteTime == 0 && markhive[1] > 0) {
		result = 0
		if ( g_voteCount[0] > g_voteCount[1] || g_voteCount[0] == g_voteCount[1] ) {
			result = 1
		} else {
			result = 2
		}

		if ( ((g_DCA && g_MCA == 1) && result == 2) || ((g_SCA && g_MCA == 1) && result == 2)) {
			oldtrait = HIVETRAIT_MC
			create_new_chamber(oldtrait)
		}
		else if (((g_DCA && g_SCA == 1) && result == 2) || (g_MCA && g_SCA && result == 1)) {
			oldtrait = HIVETRAIT_SC
			create_new_chamber(oldtrait)
		}
		else if ( (g_DCA && g_MCA && result == 1) || (g_DCA && g_SCA && result == 1)) {
			oldtrait = HIVETRAIT_DC
			create_new_chamber(oldtrait)
		} 
		
		g_voteTime = VOTE_TIME
		g_DCA = g_MCA = g_SCA = 0
		arrayset( trait , 0 , sizeof( trait ) )
		arrayset( markhive , 0 , sizeof( markhive ) )
		arrayset( voted , 0 , sizeof( voted ) )
		arrayset( g_voteCount, 0 , sizeof( g_voteCount) )
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}


/*       End Chamber Vote       */


public client_help( id )
{
	help_add("Information", "Allows aliens to Hive Pool Resources to change a second Chamber.")
	help_add("Usage", "Type in chat ^"/givepool^" or ^"givepool^".")
}

public client_advertise( id )
{
	new team = pev(id, pev_team)
	switch ( team )
	{
		case MARINE:
			return PLUGIN_HANDLED
		case MARINE2:
		{
			pause("ad")
			
			return PLUGIN_HANDLED
		}
	}
	
	return PLUGIN_CONTINUE
}
