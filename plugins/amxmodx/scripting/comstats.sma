/*
*
*	TITLE: 	Commander Statistics for NS
*
*	ABOUT:	Track commander stats and store win loss record in a vault.
* 		
*===================================================================================================
*
*	HISTORY:
*
*		Version	|	Changes
*    	----------------+---------------------------------------------------------------------------
*	 	1.0	| - Initial Release
*			|
*    	----------------+---------------------------------------------------------------------------
*	 	1.1	| - Added check for MvM
*			| - Removed public display of stats
*			| - Added console command cstats for console display
*    	----------------+---------------------------------------------------------------------------
*		1.2	| - Added public announcement function /showcstas
*    	----------------+---------------------------------------------------------------------------
*/

#include <amxmodx>
#include <amxmisc>
#include <nvault>
#include <engine>
#include <fakemeta>
#include <ns>

new is_mvm
new g_commander_id
new g_commander_total_time
new g_comm_stop_timer
new g_comm_start_timer
new g_round_start
new g_commander_in_chair_flag
new g_commander_steamid[32]
new g_commander_name[18]
new tvault
new timestamp 

public plugin_precache()
{
	register_forward(FM_KeyValue, "fw_keyvalue") // Secure MvM Check
}

public plugin_init()
{
	register_plugin("CommStats","1.1","TinCan")
	register_message(get_user_msgid("HudText2"), "check_for_winner")
	register_clcmd("cstats","cstats_console_text")
	register_clcmd("say /showcstats", "show_cstats", 0, "- display your commander stats")
}

public fw_keyvalue( ent , kvdid )
{
	// see if there are two com chairs and if so set is_mvm to 1
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


public round_start () 
{
	g_commander_total_time = 0
	g_commander_id = 0 //Not needed but just in case
	g_commander_in_chair_flag = 0
	g_round_start = get_systime()
}	

public check_for_winner()
{
	if (is_mvm) return
	new szMessage[64]
	get_msg_arg_string(1, szMessage, 63)
	if ( equal(szMessage, "TeamOneWon") )
	{
		////////////////Marine team is the winner
		if (g_commander_id==0) return		
		g_comm_stop_timer = get_systime()
		if (g_commander_in_chair_flag == 1)
		{
			g_commander_total_time = g_commander_total_time + (g_comm_stop_timer - g_comm_start_timer)	
		}
		if ( ((g_comm_stop_timer-g_round_start)/2) < g_commander_total_time   )
		{
			new win_loss_string[64]
			new new_win_loss_string[64]
			tvault = nvault_open( "comstats" );
			if( tvault == INVALID_HANDLE ) // Check to see if file can be opened
			{
				log_amx( "Error opening nVault file: %d", "comstats.vault" ); // Write to log if error occurs
			}
			if(!nvault_lookup( tvault, g_commander_steamid, win_loss_string, 63, timestamp )) // Checks if player does not exists in file 'comstats.vault'
			{		
				client_print(0,print_chat,"[Commander Stats] %s's statistics have been updated.",g_commander_name )
				client_print(0,print_chat,"[Commander Stats] Type cstats in console for more information." )
				format(new_win_loss_string,63,"1 0"); 
				nvault_set( tvault, g_commander_steamid, new_win_loss_string ); // Save win_loss to file 'comstats.vault' 
				g_commander_id=0 //so it wont loop through check_for_winner on every player
			}
			else
			{ 
				nvault_lookup( tvault, g_commander_steamid, win_loss_string, 63, timestamp ); // Get player's previous win_loss & timestamp
				new wins
				new losses
				new par1[32],par2[32]
				parse(win_loss_string,par1,31,par2,31)  
				wins = str_to_num( par1 )
				losses = str_to_num( par2)
				wins+= 1
				client_print(0,print_chat,"[Commander Stats] %s's statistics have been updated.",g_commander_name )
				client_print(0,print_chat,"[Commander Stats] Type cstats in console for more information." )
				format(new_win_loss_string,63,"%d %d",wins,losses); 
				nvault_set( tvault, g_commander_steamid, new_win_loss_string );
				g_commander_id=0 //so it wont loop through check_for_winner on every player
			}
		}
	}
	
	
	if ( equal(szMessage, "TeamTwoWon") )
	{
		////////////////Alien team is the winner
		if (g_commander_id==0) return
		g_comm_stop_timer = get_systime()
		if (g_commander_in_chair_flag == 1)
		{
			g_commander_total_time = g_commander_total_time + (g_comm_stop_timer - g_comm_start_timer)	
		}

		new win_loss_string[64]
		new new_win_loss_string[64]
		tvault = nvault_open( "comstats" );
		if( tvault == INVALID_HANDLE ) // Check to see if file can be opened
		{
			log_amx( "Error opening nVault file: %d", "comstats.vault" ); // Write to log if error occurs
		}
		if(!nvault_lookup( tvault, g_commander_steamid, win_loss_string, 63, timestamp )) // Checks if player does not exists in file 'comstats.vault'
		{		
			client_print(0,print_chat,"[Commander Stats] %s's statistics have been updated.",g_commander_name )
			client_print(0,print_chat,"[Commander Stats] Type cstats in console for more information." )
			format(new_win_loss_string,63,"0 1"); 		
			nvault_set( tvault, g_commander_steamid, new_win_loss_string ); // Save win_loss to file 'comstats.vault' 
			g_commander_id=0
		}
		else
		{ 
			nvault_lookup( tvault, g_commander_steamid, win_loss_string, 63, timestamp ); // Get player's previous win_loss & timestamp
			new wins
			new losses
			new par1[32],par2[32]
			parse(win_loss_string,par1,31,par2,31)  
			wins = str_to_num( par1 )
			losses = str_to_num( par2)
			losses += 1
			client_print(0,print_chat,"[Commander Stats] %s's statistics have been updated.",g_commander_name )
			client_print(0,print_chat,"[Commander Stats] Type cstats in console for more information." )
			format(new_win_loss_string,63,"%d %d",wins,losses);
			nvault_set( tvault, g_commander_steamid, new_win_loss_string );
			g_commander_id=0
		}
	}
}

public  client_changeclass ( id, newclass, oldclass ) 
{
	//Monitor the command chair
	if (is_mvm) return
	if (g_commander_id!=0 && id != g_commander_id) return
	if (newclass == 9) //We have a new or retunring commm
	{		
		if (g_commander_id == 0)
		{
			get_user_authid ( id, g_commander_steamid, 32 );
			get_user_name ( id, g_commander_name, 17 );			
			g_commander_id = id   //Set the primary commander for the game;			
		}
		if (id == g_commander_id)
		{
			g_comm_start_timer = get_systime()
			g_commander_in_chair_flag = 1
		}	
	
	}
	if (id == g_commander_id && oldclass == 9) //The primary comm left the chair
	{
		g_commander_in_chair_flag = 0
		g_comm_stop_timer = get_systime()
		g_commander_total_time = g_commander_total_time + (g_comm_stop_timer - g_comm_start_timer)	
		
		if ((g_comm_stop_timer-g_round_start)<60)
		{
			g_commander_id = 0   //Reset the primary commander if less than 60 secs has passed	
		}
	
	}
}

public cstats_console_text ( id )
{
	new win_loss_string[64]
	new user_id[32]
	new wins
	new losses
	tvault = nvault_open( "comstats" );
	if( tvault == INVALID_HANDLE ) // Check to see if file can be opened
	{
		log_amx( "Error opening nVault file: %d", "comstats.vault" ); // Write to log if error occurs
	}
	get_user_authid ( id, user_id, 32 );
	if(!nvault_lookup( tvault, user_id, win_loss_string, 63, timestamp )) // Checks if player does not exists in file 'comstats.vault'
	{		
		wins = 0
		losses = 0
	}
	else
	{ 
		nvault_lookup( tvault, user_id, win_loss_string, 63, timestamp ); // Get player's previous win_loss & timestamp
		new par1[32],par2[32]
		parse(win_loss_string,par1,31,par2,31)  
		wins = str_to_num( par1 )
		losses = str_to_num( par2)
	}
	console_print (id, " ______________________________________________" )
	console_print (id, "|  *  Commander Statistics Information Center" )
	console_print (id, "|  " )
	console_print (id, "|  *  Your current Commanding Statistics" )
	console_print (id, "|  *  Wins: %i", wins )
	console_print (id, "|  *  Losses: %i", losses )
	console_print (id, "|  " )
	console_print (id, "|  *  Say /showcstats to display your statistics" )
	console_print( id, "|______________________________________________" )
	return PLUGIN_HANDLED
}

public show_cstats (id)
{
	new win_loss_string[64]
	new user_id[32]
	new wins
	new losses
	new user_name[18]
		
	tvault = nvault_open( "comstats" );
	if( tvault == INVALID_HANDLE ) // Check to see if file can be opened
	{
		log_amx( "Error opening nVault file: %d", "comstats.vault" ); // Write to log if error occurs
	}
	get_user_authid ( id, user_id, 32 );
	if(!nvault_lookup( tvault, user_id, win_loss_string, 63, timestamp )) // Checks if player does not exists in file 'comstats.vault'
	{		
		wins = 0
		losses = 0
	}
	else
	{ 
		nvault_lookup( tvault, user_id, win_loss_string, 63, timestamp ); // Get player's previous win_loss & timestamp
		new par1[32],par2[32]
		parse(win_loss_string,par1,31,par2,31)  
		wins = str_to_num( par1 )
		losses = str_to_num( par2)
	}
	get_user_name ( id, user_name, 17 )	
	client_print(0,print_chat,"[%s's cstats]  Wins: %i      Losses: %i", user_name, wins, losses )  
	return PLUGIN_HANDLED
}
