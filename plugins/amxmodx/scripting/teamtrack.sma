/* TeamTrack 


DESCRIPTION 
TeamTrack is a plugin designed to prevent players 
from continually joining the marine team exclusively.


MODUALS 
amxmodx 
ns 
nvault 


CVARS 
amx_tracktime (default 180) 
amx_trackratio (default 3) 
amx_trackon (default 6)


NOTES 
- This plug-in requires the NVAULT module to be installed 
and creates a file named "track.vault" stored in data\vault. 

- amx_tracktime determines the number of seconds a player 
needs to play as an alien before it counts as a turn.
 
- amx_trackratio determines the number of times a player 
can consecutively join the marine team. 

- amx_trackon determines the number of players that need 
to be on the server for TeamTrack to function. 

- A player receives a notice when consecutive marine joins 
are detected. The notice shows the number of times joined 
and the limit that has been set in amx_ratio

- A player is forced back to the readyroom if the limit set 
in amx_ratio has been reached. A notice is displayed to the 
player and a public chat message is sent to all players.  

- Users with access to the flag ADMIN_CHAT are not tracked. 

-The file ‘track.vault’ prunes data over three days old to 
avoid becoming too large. 

- If an alien player goes to the readyroom, disconnects 
from the server, or if the round ends before the time set 
in amx_tracktime has been completed, the played time does 
not count as a turn and the alien timer is reset back to 
zero.


CHANGE LOG 
Version 1.1: 
	Fixed first time player initialization bug;
	Replaced show_hudmessage with ShowSyncHudMsg function;
	Reduced amx_tracktime default to 180 (3 min);
	Reduced amx_trackon default to 6;
	Tweaks to code spelling and grammar; 
	
	Version 1.0: 
	Initial Release 9/16/07;


*/
  
#include <amxmodx>
#include <ns>
#include <nvault>



#define PLUGIN		"TeamTrack"
#define VERSION		"1.0"
#define AUTHOR		"TinCan"

new tvault,
	g_MyMsgSync,
	g_track_time,
	g_track_ratio,
	g_track_on,
	name[18],
	steamid[33],
	trackscore,	
	trackcount[4],
	totaltrackcount[4],
	timestamp;
	
public plugin_init()
{	
	register_plugin( PLUGIN, VERSION, AUTHOR );
	g_track_time = register_cvar( "amx_tracktime", "180" );
	g_track_ratio = register_cvar( "amx_trackratio", "3" );
	g_track_on = register_cvar( "amx_trackon", "6" );
	g_MyMsgSync = CreateHudSyncObj()
}





/*		Watch for team change
============================================================================*/
public client_changeteam ( id, newclass, oldclass ) 
{
	new track_on = ( get_pcvar_num( g_track_on ) );
	if ( get_playersnum ( 1 ) >= track_on ) // Check to see if there are enough players to track
	{
		new track_time = get_pcvar_num( g_track_time ); // Determines number of seconds a player needs to play as alien before it counts. (default 300: 5 min) 
		new track_ratio = get_pcvar_num( g_track_ratio ); // Determines how many times a player can join marines compared to aliens. (default 3)  
		set_hudmessage( 0, 100, 255, 0.02, 0.73, 0, 6.0, 15.0, 0.1, 0.2, 4 ); // hud message setup
		
			
	
	
	
/*		Open file "track.vault" and get player's 'trackscore' 	
============================================================================*/
		

		tvault = nvault_open( "track" );
		if( tvault == INVALID_HANDLE ) // Check to see if file can be opened
		{
			log_amx( "Error opening nVault file: %d", "track.vault" ); // Write to log if error occurs
		}
	
		get_user_authid( id, steamid, 32 ); // Get player's steamid 

		nvault_lookup( tvault, steamid, trackcount, 3, timestamp ); // Get player's previous trackscore & timestamp
		
		
		//------------------------------------------------------------------------------------	
		if(!nvault_lookup( tvault, steamid, trackcount, 3, timestamp )) // Checks if player does not exists in file 'track.vault'
		{		
 			trackscore = 0 // set score to zero if not in file 'track.vault'
			num_to_str( trackscore, totaltrackcount, 3 ); // Switch trackscore to a string (totaltrackcount)
			nvault_set( tvault, steamid, totaltrackcount ); // Save trackscore to file 'track.vault' 
		}
		else
		{ 
			nvault_lookup( tvault, steamid, trackcount, 3, timestamp ); // Get player's previous trackscore & timestamp
			trackscore = str_to_num( trackcount ); // Convert trackcount into an integer (trackscore)
		}




/*		Check what team change occurred  	
============================================================================*/	
		switch ( newclass )
		{

/*		If player Joins the readyroom
----------------------------------------------------------------------------*/
			case 0:
			{
				if ( oldclass == 1 ) // If player joined readyroom from marines
				{
					if ( ( get_systime() - timestamp ) <= 5 ) // If time played as marine is less than 5 seconds then... 
					{	
						if ( trackscore > track_ratio ) // Check to see if player's trackscore was too high to join marines
						{
							get_user_name ( id, name, 17 ); 
							client_print ( 0, print_chat, "TeamTrack Notice: %s was returned to the readyroom.", name ); 
							client_print ( id, print_center, "Access to Marine team denied!" );
							ShowSyncHudMsg ( id, g_MyMsgSync, "This server only allows you to join marines %d times in a row. ^nHelp keep this server fun for everyone and join the alien team.", track_ratio );

							//show_hudmessage ( id, "This server only allows you to join marines %d times in a row. ^nHelp keep this server fun for everyone and join the alien team.", track_ratio ); 
						}
						trackscore -= 1; // Give back 1 point since it was only 5 seconds (This will include blocked players)
					}
					trackscore = min ( trackscore, track_ratio ); // Return the lower value of trackscore or track_ratio just in case track_ratio cvar was adjusted. 
				}
				else if ( oldclass == 2 ) // If player joined readyroom from aliens
				{
					if ( ( get_systime() - timestamp ) <= track_time ) // Check time played as alien
					{	
						trackscore += track_ratio; // Add back track_ratio to trackscore if not on aliens long enough
					}
					else 
					{
						trackscore = 0; // Reset to zero because player played enough time as alien
					} 	
				} 
			} 	 
			
/*		If player joins marines		
----------------------------------------------------------------------------*/		
			case 1:
			{
				trackscore += 1; // increase trackscore by one
				if ( trackscore > 1 )
				{
					client_print ( id, print_center, "Consecutive Marine team joins detected." );
					ShowSyncHudMsg (id, g_MyMsgSync, "You have joined marines %d times in a row.^nThis server only allows you to join marines %d times in a row.", trackscore, track_ratio );
				}
				if ( trackscore  > track_ratio ) // Limit has been reached!
				{
					console_cmd( id, "readyroom" ); // Send marine to readyroom because trackscore is too high
					console_cmd( id, "readyroom" ); // <- You have to do the readyroom command twice 
				}		
			} 
				
/*		If player joins aliens			
----------------------------------------------------------------------------*/		
			case 2:
			{
				trackscore -= track_ratio; // decrease trackscore by track_ratio
			}
		}





/*		Write trackscore to file	
============================================================================*/		
		if ( get_user_flags(id) & ADMIN_CHAT ) // Test if player has access to admin_chat
		{						
	    	trackscore = 0; // Player has admin_chat so do not track
    	}
  		num_to_str( trackscore, totaltrackcount, 3 ); // Switch trackscore to a string (totaltrackcount)
		nvault_set( tvault, steamid, totaltrackcount ); // Save trackscore to file 'track.vault' 
	}



}

/*		Watch for Disconnect
============================================================================*/	
public client_disconnect(id)
{
	new track_on = ( get_pcvar_num( g_track_on ) );
	if ( get_playersnum ( 1 ) > track_on ) // Check to see if there are still enough players to count
	{
		new team[11] 
		new compareteam1[11] = "alien1team"
		team[10] = get_user_team(id, team, 10);
		if (compareteam1[1] == team[1]) // If player disconnects from aliens (checks first letter for an "a")
		{
			new track_time = get_pcvar_num( g_track_time ); // Determines number of seconds a player needs to play as alien before it counts. (default 300: 5 mins) 
			new track_ratio = get_pcvar_num( g_track_ratio ); // Determines how many times a player can join marines compared to aliens. (default 3)  
			get_user_authid( id, steamid, 32 ); // Get player's steamid 
			nvault_lookup( tvault, steamid, trackcount, 3, timestamp ); // Get player's previous trackscore & timestamp
			trackscore = str_to_num( trackcount ); // Convert trackcount into an integer (trackscore)
			
			if ( ( get_systime() - timestamp ) <= track_time ) // Check time played as alien
			{	
				trackscore += track_ratio; // Add back track_ratio to trackscore if not on aliens long enough
			}
			else 
			{
				trackscore = 0; // Reset to zero because player played enough time as alien
			} 	
			if ( get_user_flags(id) & ADMIN_CHAT ) // Test if player has access to admin_chat
			{						
    			trackscore = 0; // Player has admin_chat so do not track
	 	   }		
			num_to_str( trackscore, totaltrackcount, 3 ); // Switch trackscore to a string (totaltrackcount)
			nvault_set( tvault, steamid, totaltrackcount ); // Save trackscore to file 'track.vault' 
		}
	}
}




/*		Prune tvault 
============================================================================*/		
public plugin_end ( )
{
	nvault_prune(tvault, get_systime(), (get_systime() - 259200)) // Prunes after x seconds (259200 = three days)
}