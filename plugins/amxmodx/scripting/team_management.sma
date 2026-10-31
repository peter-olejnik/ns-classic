/*
*
*               Author: Cpt.Hans
*
*
*	        History:
*		v1.0
*		- Initial release
*		v1.1
*		-fixed: Admins were unable to return to ReadyRoom
*		v1.2
*               -fixed: Admins were AutoBalanced and Autoassigned
*		-added: Commanders and Bots wont be AutoBalanced/Autoassigned
*		-fixed: "Function "GameStarted" was not found" Error when Autoassign was turned off.
*		v1.3
*		-fixed: Error when a client was timed out. (Thanks toazron)
*
*/


#include <amxmodx>
#include <amxmisc>
#include <ns>
#include <engine>

#define TEAMCHECKTIME	30.0    // TeamBalance interval (default: 30seconds)
#define ASSIGNTIME	0.1	// How long players have time to choose a team after Roundstart.(default 10 seconds)
#define RRBLOCK		1	// 1= Enable ReadyRoom blocker | 0= disable it
#define AUTOASSIGN	1	// 1= Enable AutoAssign | 0= disable
#define AUTOBALANCE	0	// 1= Enable Auto TeamBalance | 0 = disable

#define VERSION "1.3"

#define MARINE		1
#define ALIEN		2

#if AUTOBALANCE==1
new g_lastMarine = 0, g_lastAlien = 0
new g_Classname[] = "timer1"
new g_autobalance=0
#endif

new sound_file[125] = "hud/tooltip.wav"
new g_roundstarted = 0


public plugin_init() 
{

	register_plugin("Team Management", VERSION, "Cpt.Hans")

	#if AUTOASSIGN==1
	register_event("Countdown","GameStarted","a")
	register_event("GameStatus","GameEnded", "ab", "1=2" )
	#endif
	
	#if RRBLOCK==1
	register_clcmd("readyroom", "blockrr")
	register_clcmd("menureadyroom", "blockrr")
	register_impulse(5, "blockrr")
	#endif
	
	register_cvar("TeamManagement_version",VERSION,FCVAR_SERVER)
	
	#if AUTOBALANCE==1
	new Ent = create_entity("info_target")
	entity_set_string(Ent,EV_SZ_classname,g_Classname)
	entity_set_float(Ent,EV_FL_nextthink,halflife_time() + TEAMCHECKTIME)
    
	register_think(g_Classname,"timer1Think")
	#endif
}

public plugin_precache( )
{
	precache_sound(sound_file)
}

#if AUTOASSIGN==1
public client_putinserver(id) 
{
	if ( g_roundstarted==1 ){
		new msg[150]
		format(msg,149,"Please choose a team or you will be autoassigned in a few seconds.")
		set_hudmessage(47, 47, 255, -1.0, 0.10, 0, 6.0, 10.0)
		show_hudmessage(id, msg)
	}else if( g_roundstarted==2) {
		if(checkTeams())
			assignMarine(id)
		else
			assignRandom(id)
	}
}

public GameStarted()
{
	new msg[180]
	format(msg,179,"A new round has started. Everyone has %0.0f seconds to choose a team.",ASSIGNTIME)
	set_hudmessage(47, 47, 255, -1.0, 0.10, 0, 6.0, 10.0)
	show_hudmessage(0, msg)
	g_roundstarted=1
	set_task(ASSIGNTIME,"checkPlayer")
}

public GameEnded()
{
	g_roundstarted=0
}

public checkPlayer()
{
	for(new i=1; i<=32; i++) {
		if( is_user_connected(i) && !is_user_hltv(i) && !is_user_bot(i) && !is_user_admin(i) ){
			if( (entity_get_int(i,EV_INT_team) != MARINE) && (entity_get_int(i,EV_INT_team) != ALIEN) )
			{
				if(checkTeams())
					assignMarine(i)
				else
					assignRandom(i)
			}
		}
	}
	g_roundstarted = 2
}
#endif

stock getplayersonteam(team) 
{
	new PoT
	for (new i=1;i<=32;i++)
	{
		if (is_user_connected(i))
		{
			if ( entity_get_int(i,EV_INT_team) == team )
			{
			PoT++
			}
		}
	}
	return PoT
}

#if AUTOASSIGN==1
checkTeams()
{	
	new MarinePlayers = getplayersonteam(MARINE)
	new AlienPlayers = getplayersonteam(ALIEN)
	if( ( MarinePlayers == AlienPlayers) && (!ns_is_combat()) )
		return 1
		
	return 0
}

assignMarine(id)
{
	if (is_user_connected(id) && !is_user_hltv(id) && !is_user_admin(id) && !is_user_bot(id))
	{
		new name[32]
		get_user_name(id,name,31)
		client_print(0, print_chat,"%s has been autoassigned.",name)
		engclient_cmd(id,"jointeamone")
	}
}

assignRandom(id)
{
	if (is_user_connected(id) && !is_user_hltv(id) && !is_user_admin(id) && !is_user_bot(id))
	{
		new name[32]
		get_user_name(id,name,31)
		client_print(0, print_chat,"%s has been autoassigned.",name)
		engclient_cmd(id,"autoassign")
	}
}
#endif

#if RRBLOCK==1
public blockrr(id)
{
	if ( is_user_admin(id) || mayswitch(id) || g_roundstarted==0)
		return PLUGIN_CONTINUE
	
	new msg[180]
	format(msg, 179,"Readyroom is blocked")
	client_cmd(id, "spk %s",sound_file) 
	ns_popup(id,msg)
	return PLUGIN_HANDLED
}

public mayswitch(id)
{
	if(entity_get_int(id,EV_INT_team) == MARINE) 
	{
		if ( ((getplayersonteam(MARINE)) - (getplayersonteam(ALIEN))) > 1)
			return 1
		else
			return 0
	}else if(entity_get_int(id,EV_INT_team) == ALIEN)
	{
		if ( ((getplayersonteam(ALIEN)) - (getplayersonteam(MARINE))) > 1)
			return 1
		else
			return 0
	}
	return 1
}
#endif

#if AUTOBALANCE==1
public client_changeteam(id, newteam, oldteam)
{
	if( newteam==MARINE && !is_user_admin(id) && !is_user_bot(id) )
		g_lastMarine=id
	if( newteam==ALIEN && !is_user_admin(id) && !is_user_bot(id) )
		g_lastAlien=id
}

public client_changeclass(id, newclass, oldclass)
{
	if((newclass==9) && (id==g_lastMarine))
	{
		for(new i=1; i<=32; i++)
		{
			if(is_user_connected(i))
			{
				if( (entity_get_int(i,EV_INT_team)==MARINE) && !is_user_admin(i) && (ns_get_class(i)!=9) && !is_user_bot(i) )
				{
					g_lastMarine=i
					continue
				}
			}
		}
	}
	
	if(is_user_bot(g_lastMarine))
	{
		for(new i=1; i<=32; i++)
		{
			if(is_user_connected(i))
			{
				if( (entity_get_int(i,EV_INT_team)==MARINE) && !is_user_admin(i) && (ns_get_class(i)!=9) && !is_user_bot(i) )
				{
					g_lastMarine=i
					continue
				}
			}
		}
	}
	if(is_user_bot(g_lastAlien))
	{
		for(new i=1; i<=32; i++)
		{
			if(is_user_connected(i))
			{
				if( (entity_get_int(i,EV_INT_team)==ALIEN) && !is_user_admin(i) && !is_user_bot(i) )
				{
					g_lastAlien=i
					continue
				}
			}
		}
	}
	
}

public timer1Think(Ent)
{
	if(g_roundstarted==2)
	{
		if( ( ((getplayersonteam(MARINE)) - (getplayersonteam(ALIEN))) > 1) || ( ((getplayersonteam(ALIEN)) - (getplayersonteam(MARINE))) > 1) )
		{
			if(!g_autobalance)
			{
				client_cmd(0, "spk %s",sound_file) 
				ns_popup(0,"Please balance the teams!^nOtherwise someone will be autobalanced.")
				g_autobalance=1
			}else{
				g_autobalance=0
				if( ((getplayersonteam(MARINE)) - (getplayersonteam(ALIEN))) > 1 && g_lastMarine!=0)
				{
					engclient_cmd(g_lastMarine,"readyroom")
					engclient_cmd(g_lastMarine,"readyroom")
					engclient_cmd(g_lastMarine,"jointeamtwo")
					client_cmd(0, "spk %s",sound_file) 
					ns_popup(0,"Teams balanced.")
					set_task(1.0, "showInfo",g_lastMarine)
				}else if(g_lastAlien!=0)
				{
					engclient_cmd(g_lastAlien,"readyroom")
					engclient_cmd(g_lastAlien,"readyroom")
					engclient_cmd(g_lastAlien,"jointeamone")
					client_cmd(0, "spk %s",sound_file) 
					ns_popup(0,"Teams balanced.")
					set_task(1.0, "showInfo",g_lastAlien)
				}else{
					client_cmd(0, "spk %s",sound_file) 
					ns_popup(0,"No players to move on the bigger team.")
				}
			}
		}
	}
		
			
	entity_set_float(Ent,EV_FL_nextthink, halflife_time() + TEAMCHECKTIME)
}

public showInfo(id)
{
	ns_popup(id,"You were moved to the other team^nbecause the teams were unbalanced.")
}
	
#endif
