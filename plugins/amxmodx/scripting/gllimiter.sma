/*
* This plugin limits MvM combat to 1 GL, or it can fully block GL's
* Originally created for sentiel's server(s)
*
* by DDR Khat
*
* v1.0:
*	- initial release
* v1.1:
*	- fixed bug that allowed 2 gls occasionally
*	- Added in forgotten check for Team 1
* v1.2:
*	- added cvar for fully blocking GL
* v1.3
*	- Bugfix
* v1.4
*	- Added option to specfiy limit for NS type.
*	- Helper Support
*/

#include <amxmodx>
#include <ns>
#include <engine>
#include <fakemeta>

//////////////////////////Adjust these to your liking//////////////////

#define HELPER 0 	// IF 1 you need the helper.inc file
#define BLOCKGL "1"	// 0 = 1 GL only, 1 = Disable GL
#define BLOCKTYPE "1" 	// 1 = CO only, 2 = NS only, 3 = Both CO + NS

///////////////////////////////////////////////////////////////////////

/////////////////////////////Do not change below//////////////////

#define PLUGIN "GL Limiter"
#define PLUGINOFF "GL Limiter (off)"
#define VERSION "1.4"
#define AUTHOR "DDR Khat"
#define NULL ""
#if HELPER == 1
  #include <helper>
#else
  #define help_add set_localinfo
#endif  


/////////////////////////////Do not change above//////////////////

//All our needed variables
new team1gl[60];
new team3gl[60];
new g_maxPlayers;
new g_f4ing[33] = 0;
new is_mvm = 0;
//Lets get going!

public plugin_precache()
{
	register_forward(FM_KeyValue, "fw_keyvalue") // Secure MvM Check
}

public plugin_init() {
	if(is_mvm) // IF we're Marines vs Marines
	{
		register_plugin(PLUGIN, VERSION, AUTHOR)
		register_cvar("amx_gllimit",BLOCKGL,FCVAR_SERVER)
		register_cvar("amx_glblocktype",BLOCKTYPE,FCVAR_SERVER)
		switch(get_cvar_num("amx_glblocktype"))
		{
			case 1: {if(ns_is_combat()) blockthegl();} 	// If Combat
			case 2: {if(!ns_is_combat()) blockthegl();}	// If Classic
			case 3: {blockthegl();}				// If Either
		}
	}
	else
		register_plugin(PLUGINOFF, VERSION, AUTHOR)
}

public blockgl(id)
{
	client_print(id, print_chat, "[AMXX] Grenade Launcher in Marines vs Marines is Disabled")
	return PLUGIN_HANDLED
}


public client_disconnect(id)
{
	new szID[60];
	get_user_authid(id,szID,59);
	switch(pev(id, pev_team))
	{
		case 1:
			if(szID[0] == team1gl[0])
			{
				team1gl = NULL
				send_to_team(1,"The Grenade Launcher is available again")
			}
		case 3:
			if(szID[0] == team3gl[0])
			{
				team3gl = NULL
				send_to_team(3,"The Grenade Launcher is available again")
			}
	}
}
public f4(id)
{
	if(g_f4ing[id])
	{
		new szID[60];
		get_user_authid(id,szID,59);
		switch(pev(id, pev_team))
		{
			case 1:
			if(szID[0] == team1gl[0])
			{
				
				team1gl = NULL
				send_to_team(1,"The Grenade Launcher is available again")
			}
			case 3:
			if(szID[0] == team3gl[0])
			{
				team3gl = NULL
				send_to_team(3,"The Grenade Launcher is available again")
			}
		}
	}
	else{
		new params[1];
		params[0] = id;
		g_f4ing[id] = 1;
		set_task(1.0, "abortf4", 0, params, 1);
	}
}

public abortf4(params[], id){
  new player = params[0];
  g_f4ing[player] = 0;
}

public newgl(id)
{	
	new szID[60];
	get_user_authid(id,szID,59);
	switch(pev(id, pev_team))
	{
		case 1:
			if(!team1gl[0] && ns_get_points(id)>0)
				team1gl = szID
			else
			{
				if(ns_get_points(id)>0)
				{
					client_print(id, print_chat, "[AMXX] You're team has a Grenade Launcher")
					return PLUGIN_HANDLED
				}
			}
		case 3:
			if(!team3gl[0] && ns_get_points(id)>0)
				team3gl = szID;
			else
			{
				if(ns_get_points(id)>0)
				{
					client_print(id, print_chat, "[AMXX] You're team has a Grenade Launcher")
					return PLUGIN_HANDLED
				}
			}
	}
	return PLUGIN_CONTINUE
}

public send_to_team(id, msg[]){
  new team = id;
  for(new i = 1 ; i <= g_maxPlayers ; i++){
    if(!is_user_connected(i)) continue;
    else
      if(pev(i, pev_team) == team)
	client_print(i, print_chat, msg);
  }
}

public fw_keyvalue( ent , kvdid )
{
	
	// This part looks to see if there are two com chairs and if so it sets is_mvm to 1
	new cc, ccount 
	cc = find_ent_by_class(0,"team_command")
	while (cc != 0) { 
		client_print ( 0, print_chat, "cc" ) 
		ccount++
		cc = find_ent_by_class(cc,"team_command")
		
		
		if (ccount == 2)
			is_mvm = 1
	}
	return FMRES_IGNORED
}

public blockthegl()
{
	if(get_cvar_num("amx_gllimit") == 0)
	{
		register_impulse(66,"newgl")
		register_clcmd("readyroom","f4")
		g_maxPlayers = get_maxplayers();
	}
	else
		register_impulse(66,"blockgl")
}

///Helper///
public client_help(id){
	if(get_cvar_num("amx_gllimit"))
	{
		switch(get_cvar_num("amx_glblocktype"))
		{
			case 1:{help_add("Information","This plugin Disables the GL for Marines vs Marines in Combat only");}
			case 2:{help_add("Information","This plugin Disables the GL for Marines vs Marines in Classic only");}
			case 3:{help_add("Information","This plugin Disables the GL for Marines vs Marines in Combat & Classic");}
		}
	}
	else
	{
		switch(get_cvar_num("amx_glblocktype"))
		{
			case 1:{help_add("Information","This plugin limits the GL to 1 for Marines vs Marines in Combat only");}
			case 2:{help_add("Information","This plugin limits the GL to 1 for Marines vs Marines in Classic only");}
			case 3:{help_add("Information","This plugin limits the GL to 1 for Marines vs Marines in Combat & Classic");}
		}
	}
	help_add("Usage","This is automatic")
}

public client_advertise(id){
  return PLUGIN_CONTINUE;
}
