/* * * *
*
* Stacksplit 
*
* DESCRIPTION 
* Whenever a player joins a team,
* Stacksplit checks whether that player is in the config file stacksplit.ini
* If so, it will count the number of such players on the marine team, and also on the alien
* team.
* If there are 2 more of these specified players on the team that the player just joined,
* he will be moved to the other team (so that there are an equal number of specified players
* on each team)
* This calculation is made 4 seconds after joining a team in order to avoid conflicting with
* ns code that limits the speed with which you can change teams.
* 
* 
* MODULES 
* amxmodx 
* amxmisc
* engine
* 
* CVARS 
* - none -
*  
* COMMANDS
* showstackers//lists all flagged players currently in game.  
* 
* NOTES 
* This plugin borrows heavily from Kost's constant names plugin, and also
* TinCan's TeamTrack plugin.
* Thanks Kost and TinCan!
* 
* 
* CHANGE LOG 
* 0.1 
* - Initial Release
*
* 0.2
* - Added showstackers console command to list stackers in console.
* - Adjusted code due to bug in 1.8. client_changeteam (id,oldclass,newclass) used to be backwards (id,newclass,oldclass)
* - Cleaned up some code.
* 
* 0.3 
* - Logging made more readable.
* - Prevented stack check when players join team 0 (readyroom)
* - corrected bug that stopped players being moved away from the majority stacked team if the most recently checked other player joined the minority stacked team. 
* 
* 0.4
* - added checkclass variable to fix bug caused by error in logging syntax 
* - removed ns.inc (#include <ns>) since it is not needed
* 
* 0.5
* - Re-adjusted code (see 0.2) since client_changeteam bug in 1.8 was fixed 
*
* * * */

#include <amxmodx>
#include <amxmisc>
#include <engine>

#define MAX_USERS 200 // set this to a higher value if you need more predefined users in you config file
#define CONFIG_FILE "stacksplit.ini" // you can modify the default config file name if needed

#define PLUGIN		"StackSplit"
#define VERSION		"0.5"
#define AUTHOR		"Yolkfolk"

new i=0 // counter
new j=0 // counter
new k=0 // counter
new num_users=0 // parsed users
new file_name[128] // the config path/file 
new steam_names[MAX_USERS][2][35] // steamid->playername values from config file

public plugin_init()
{
	register_plugin(PLUGIN,VERSION,AUTHOR)
	register_clcmd("showstackers","show_stackers")
		
	new config_dir[80] // get config dir
	get_configsdir(config_dir,79)
	format(file_name,127,"%s/%s",config_dir,CONFIG_FILE) // store path/file in global 'file_name'
	new text[256],name[33],steamid[33],txtLen,line_num=0

	if (file_exists(file_name)) // parse config file if exists
	{
		line_num=read_file(file_name,line_num,text,255,txtLen) // read first line
		while(line_num)
		{
			parse(text,steamid,32,name,32)
			if (line_num<=MAX_USERS)// stop caching if MAX_USERS reached
			{ 
				if (strlen(steamid) && strlen(name)) // cache (SteamID -> PlayerName) pairs
				{
					format(steam_names[line_num-1][0],34,"%s",steamid)
					format(steam_names[line_num-1][1],34,"%s",name)
					num_users=line_num // update number of listed users
				}
				line_num=read_file(file_name,line_num,text,255,txtLen) // read next line
			}else line_num=0 // MAX_USERS reached stop parsing
		}
	}
}


public client_changeteam ( id, newclass, oldclass )	
{
	new argid[1]
	argid[0]= id
	if (newclass == 1 || newclass == 2)
	{
		set_task(4.0,"correctstack",id,argid,3,"a",1) 
	}
	return PLUGIN_HANDLED	
}	


public correctstack (argid[]) 
{
        new id = argid[0]
        new newclass // This variablw will store what team the player is trying to join
	new marinestackers=0
	new alienstackers=0
	new steamid[35]
	get_user_authid(id,steamid,34)
	if (!strlen(steamid)) return PLUGIN_CONTINUE
	for (i=0;i<num_users;i++) // compare users steamid to cached ones
	{ 
		if (equali(steam_names[i][0],steamid))
		{
			client_print ( id, print_chat, ":::: Type showstackers in console to see a list of flagged players like you." );
			new offendername[31]
	                get_user_name(id, offendername, 31)
		        newclass = (entity_get_int(id,EV_INT_team))
                        log_amx("Flagged player %s is changing team to team %i.", offendername, newclass)
	  		new allplayers[32], num
	  		get_players(allplayers,num,"h")
 			marinestackers=0
	  		alienstackers=0
			for (j=0;j<num;j++)
			{
				new checkid = allplayers[j]
				new checkclass //  This variable stores what team each flagged player is currently on
				for (k=0;k<num_users;k++)
				{ // compare users steamid to cached ones
					get_user_authid(checkid,steamid,34)
					if (!strlen(steamid)) return PLUGIN_CONTINUE
					if (equali(steam_names[k][0],steamid))
					{    
						checkclass = (entity_get_int(checkid,EV_INT_team))
						new checkname[31]
						get_user_name(checkid, checkname, 31)                  
						log_amx("Flagged player %s in game on team %i", checkname, checkclass)
						{
							if (entity_get_int(checkid,EV_INT_team) == 1)
							{
								marinestackers = marinestackers + 1
								log_amx("marineflags is now at %i", marinestackers)
							}
							if (entity_get_int(checkid,EV_INT_team) == 2)
							{
								alienstackers = alienstackers + 1
								log_amx("alienflags is now at %i", alienstackers)
							}
						}
					}
				}
			}
			
				
			if (((alienstackers - 1) > marinestackers) && (newclass == 2))
			{
				log_amx("more alien flags than marine flags, moving player to marines")
				set_cvar_num("mp_limitteams", 5)
				engclient_cmd(id,"readyroom");
				engclient_cmd(id,"readyroom");
				engclient_cmd(id,"jointeamone");
				set_cvar_num("mp_limitteams", 2)
				client_print ( id, print_chat, "Thank you for playing with a variety of teammates!" );
			}
			if (((marinestackers - 1) > alienstackers) && (newclass == 1))	
			{
				log_amx("more marine flags than alien flags, moving player to aliens")
				set_cvar_num("mp_limitteams", 5)
				engclient_cmd(id,"readyroom");
				engclient_cmd(id,"readyroom");
				engclient_cmd(id,"jointeamtwo"); //join aliens
				set_cvar_num("mp_limitteams", 2)
				client_print ( id, print_chat, "Thank you for playing with a variety of teammates!" );
			}	
				
		}
	}
	return PLUGIN_CONTINUE
}

public show_stackers ( id )
{
	new allplayers[32], num, steamid[35], checkteam, team[35]
	get_players ( allplayers,num, "h" )
	console_print (id, " ______________________________________________" )
	console_print (id, "|  *  Start listing of current players flagged in stacksplit:" )
	console_print (id, "|  -" )
	for ( j = 0; j < num; j++ )
	{
		new checkid = allplayers[j]
		for ( k = 0; k < num_users; k++ )
		{
			get_user_authid ( checkid,steamid, 34 )
			if ( !strlen(steamid)) return PLUGIN_CONTINUE
			if ( equali(steam_names[k][0], steamid ) )
			{    
				checkteam = ( entity_get_int( checkid,EV_INT_team ) )
				switch ( checkteam )
				{
					case 1:
					{
						team = "is on the marine team"
					}
					case 2:
					{
						team = "is on the alien team"
					}
					default:
					{	
						team = "has not joined a team"
					}
				}	
				new checkname[31]
				get_user_name( checkid, checkname, 31 )                  
				console_print( id, "| %s, is a flagged player and %s", checkname, team )
			}
		}
	}	
	console_print( id, "|  -" )
	console_print( id, "|  *  End listing of current players flagged in stacksplit." )
	console_print( id, "|______________________________________________" )
	return PLUGIN_HANDLED
}