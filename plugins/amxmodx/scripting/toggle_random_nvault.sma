/*
*	ABOUT:
*
*		- Toggable random teams with players sorted by win/lose ratio for stats collected
*		  at the end of a game + new/replacement commands to take advantage of stats logged.
*
*		- Requires:
*			+ AMXx 1.76 with DBI/SQLx, NS and Engine modules loaded (Check your plugins.ini).
*			+ MySQL database on the same server that HLDS is running on.  Remote DB possible
*			  but not recommended if they are far apart.
*
*		- Author can be found on IRC at #yo-clan on QuakeNet.
*
*===================================================================================================
*
*	HEALTH WARNING:
*
*		- If this plugin cannot connect to the SQL database then the entire plugin will fail to run
*		  and you will have no functionality.  This has been coded in delibrately to avoid breakages
*		  and chaos on your server should the connection not be made.
*
*		  Check your amx log files to find an error description of why the connection has failed.
*
*		- This plugin is designed for long term use, bear this in mind when you decide to use
*		  it on your server.  You may want to leave random teams off for a week or so to build
*		  up some stats for your regular players.
*
*===================================================================================================
*
*	FEATURES:
*
*		- Random teams will automatically switch on and off depending if an admin is on the server.
*		  Random teams can be turned on/off by an admin using a appropriate commands.  Random teams
*		  will turn off if the number of players on the server falls below a specified value.
*
*		  The admin check can be disabled using the appropriate CVAR if required
*
*		- This plugin will random teams at the start of each game based on each players percentage
*		  of games they have won using stats logged at the end of each game.  If a player F4's
*		  then their previous team assigned is logged for the stats logging process.
*
*		- Player stats are recorded for a set number of previous games and they must have played at
*		  been on the server for a minimum of 3 minutes for their stats to be logged.  A players stats 
*		  will be reset if they are not seen on the server for a specified period of time.
*
*		- A player will need to have played at least 10 games before their stats become usable.
*		  Until they have played 10 games they will be assigned a random value for their win/loss
*		  ratio that is between 40% and 60%.
*
*		- Two seperate stats groups are recorded, one for Classic maps and one for Combat maps.
*
*		- Players who are AFK will be left in the readyroom and assigned to the team with the
* 		  lowest average win/loss percentage when they try to join a team.
*
*		- Players can vote to turn random teams on by typing "/voterandom" in chat.  Random teams
*		  cannot be voted off in the same manner.  Percentage votes required set by a CVAR.
*
*		- This plugin replaces the forcejoin plugin by cheesypeteza and combines that functionality
*		  into a single package that uses stats.  Disable the forcejoin plugin while using this one.
*
*		- A readyroom blocker will prevent players from returning to the readyroom for a set
*		  period of time after the start of a round, it will however allow a player to F4 during
* 		  this period if the team numbers are unbalanced.
*		  
*		- An "oddman" algorithm will send the last player to be randomed to the marine team
*		  if the team sizes will be uneven (only for initial random, amx_random and amx_rerandom)..
*
*		- Replaces the default "amx_random" command algorithm with one that uses logged stats.
*		  Command usage remains unchanged but it can only be run once every 2 seconds to prevent
*		  breakage.
*
*		- New command "amx_rerandom".  This will allow you to force everyone to the readyroom
*		  and random them if a game has not yet started and people have started to join teams.
*
*===================================================================================================
*
*	HISTORY:
*
*		Version	|	Changes
*    	----------------+---------------------------------------------------------------------------
*	 	0.4	| - Cleanup from closed source for general release
*		beta	| - Added command to create table
*			| - Plugin now independent from whois.amxx
*			| - Join block during random process fixed
*			| - Plugin now uses seperate stats for classic and combat maps
*			|
*    	----------------+---------------------------------------------------------------------------
*	 	0.5	| - Changed connection method (single command now)
*		beta	| - Removed command to create table (now needs to be done manually)
*			| - User can no longer specify field names
*			|
*    	----------------+---------------------------------------------------------------------------
*		0.6	| - Fixed (fingers crossed) stats logging issues
*		beta	| - Reworked end game logging algorithm
*			| - Random selection of ascending/descending rank table sorting to help with
*			|   team assignment issues
*			|
*    	----------------+---------------------------------------------------------------------------
*		0.7	| - Plugin will now create the database table automatically on map load
*		beta	| - Rearranged installation steps to take table create into account
*			| - Updated config file to make it more useful
*			| - Stats reduce properly if a player has logged more than the maximum number
*			|   of games that should be logged.
*			|
*    	----------------+---------------------------------------------------------------------------
*		0.8	| - Added CVAR to switch random teams on/off permanently
*		beta	| - Changed config folder to include new CVAR
*			| - Added verbose mode
*			| - Coded in more failsafes
*			|
*    	----------------+---------------------------------------------------------------------------
*		1.0	| - Finally finished (fingers crossed)
*		release	|
*			|
*    	----------------+---------------------------------------------------------------------------
*		1.1	| - Fixed a typo in stats logging algorithm (not a major breaker, just didn't
*		release	|   check to see if a client was valid when logging stats)
*			|
*    	----------------+---------------------------------------------------------------------------
*		1.2	| - Changed how sv_random_permanent, sv_random_admincheck and sv_random_override
*		release	|   work with admin check and different plugin setups
*			| - Typo fixes
*			| - Changed command behavior, 'amx_random' now 'amx_balance'
*			| - Added CVAR to decide which forcejoin method to use (stats or pure random)
*			| - Fixed SQL connection error reporting for a failed connection attempt
*			|
*	--------------------------------------------------------------------------------------------
*		1.3	| - Fixed calculation of odds and added a function to return marine's win probability
*		changes	| - Changed to always sort by descending order so it has time to correct for disparity at the top
*		for BAD	| - Changed new player range from 40-60 to 49-51, 40-60 is way too much noise
*		server	| - Reduced maximum noise added to each player from 15% to 2%
*		by	| - Removed the disregard functionality that removed one quarter of players for no reason, we do NOT want that much noise
*		Agamem- | - Added self-correcting behavior to the initial assignment and fixed the attempt at that behavior for latejoins
*		non	|
*
*===================================================================================================
*
*	INSTALLATION:
*
*		1 - Create a database in MySQL called random with your own login details (user,password,etc).
*		    IMPORTANT: The user that you create must have the privileges CREATE, UPDATE, INSERT and SELECT
*		    for this plugin to function properly.
*
*		2 - Setup the plugin by editing the defines below.  Compile the .sma source file and
*		    drop the compiled .amxx file into your AMXx plugins directory.
*
*		3 - Drop the file 'toggle_randomd' included in the zip into your AMXx configs directory.
*		    Open it and and modify the amx_random_connect command to include your SQL user/connection details:
*			
*		    I.e. Change it from its default of:
*			amx_random_connect <host> <user> <password> <DB name>
*
*		    To something that should look like this:
*			amx_random_connect localhost admin pa55w0rd random
*
*		4 - Edit your plugins.ini to include this plugin.  You should place it above nscommands.amxx
*		    to avoid conflicts with the default amx_random command.
*
*		5 - Edit your modules.ini to load the 'sql' module.  No SQL module, no plugin workey.
*
*		6 - Create the stats table in the database, the plugin should do this automatically at step 6 below.
*		    If it doesn't, create the table manually using the SQL below in a tool like phpMyAdmin:
*	
*				CREATE TABLE IF NOT EXISTS `stats` (
*					`id` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
*					`steamid` VARCHAR(35) NOT NULL,
*					`last_seen` INTEGER UNSIGNED NOT NULL DEFAULT 0,
*					`ns_wins` INTEGER UNSIGNED NOT NULL DEFAULT 0,
*					`ns_losses` INTEGER UNSIGNED NOT NULL DEFAULT 0,
*					`co_wins` INTEGER UNSIGNED NOT NULL DEFAULT 0,
*					`co_losses` INTEGER UNSIGNED NOT NULL DEFAULT 0,
*					PRIMARY KEY(`id`)
*					);
*
*		7 - Restart your server or change the map to load the plugin.
*
*		8 - Finished and ready to use!
*
*===================================================================================================
*
*	USAGE:
*
*		- The plugin is set to use the toggle behavioue by default.  To make random teams
*		  on or off permanently by default set the CVAR sv_random_permanent to the appropriate
*		  value in your toggle_random.cfg.
*
*		- Stats will not be logged and random will remain off if tournament mode is on
*		  (mp_tournamentmode 1).
*
*		- If random teams have been turned on by an admin and then all the admins leave the server
*		  the plugin will revert to its default behavior.
*
*	Admin Only Commands:
*		amx_random_on <minutes> 	- Turns on random teams for a specified period of time
*		amx_random_off 			- Turns off random teams if they are on
*		amx_balance 			- Randoms all players in readyroom
*		amx_rerandom 			- Forces all players on a team to readyroom and randoms them all after a short delay
*		/odds 				- Typed in chat; displays odds of each team winning, used mostly as a sanity check
*
*	Player Commands:
*		/voterandom - Typed in chat - add's a players vote to turn on random teams temporarily
*
*	RCON Commands:
*		amx_random_connect <host> <user> <password> <DB name> - Connects plugin to MySQL DB
*
*	Defines:
*		ACCESS_REQUIRED		- set admin level needed to use plugin
*		RECORDED_GAMES 		- Number of games per player to log
*		PLAYER_CUTOFF 		- Number of players need on the server to turn on random teams automatically
*		STATS_EXPIRE_TIME 	- Amount of time after which if a player has not been seen, their stats will be reset to 0
*		OVERRIDE_RANDOM_CMD	- Use amx_random from nscommands plugin or the one included here
*		VERBOSE			- Show extra messages in amx logs if defined/uncommented
*
*	CVAR's:
*		sv_random_toggle <1|0> 			- Random on/off switch
*		sv_random_override <1|0> 		- Set to 1 to override default behavior
*		sv_random_nof4 <seconds> 		- Time in seconds to block F4'ing after start of game
*		sv_random_nojoin <seconds> 		- Time in seconds until random at start of game
*		sv_random_resetdelay <seconds> 		- Time delay in seconds to re-random when game finishes, must be greater than 30 seconds
*		sv_random_votetime <seconds> 		- Maximum time in seconds a turn random on vote can go on for
*		sv_random_voterandomtime <minutes>	- Time in minutes random teams will be turned on for after a successful vote
*		sv_random_votesneeded 			- Percentage decimal of player votes required for a successful vote
*		sv_random_admincheck <1|0> 		- Run regular admincheck to turn random on/off depending if an admin is connected
*		sv_random_permanent <0|1|2>		- Random teams permanently default/on/off
*		sv_random_forcejoin <0|1|2>		- Decide which forcejoin method to use
*
*	mrcoffee, 08/2007
*/

// =================================================================================================
// EDITABLE - User set definitions, a recompile is needed if you change any of these values
// =================================================================================================

#define ACCESS_REQUIRED	ADMIN_CHAT		// admin access required to use plugin
#define RECORDED_GAMES 1000			// number of players previous games to be recorded
#define PLAYER_CUTOFF 10			// number of players needed to turn random on automatically
#define STATS_EXPIRE_TIME 180.0			// number of days after which a players stats are reset after not being seen
// #define VERBOSE				// uncommenting this will cause the plugin to produce more log messages



// =================================================================================================
// DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING
// =================================================================================================
// Modules required and plugin info
// =================================================================================================

#define HELPER 0

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <nvault>
#include <ns>
#if HELPER == 1
	#include <helper>
#else
	#define help_add set_localinfo
#endif

#define PLUGIN "Toggle random teams nVault"
#define VERSION "1.2d"
#define AUTHOR "mrcoffee/Asmodee`"

// =================================================================================================
// Variables
// =================================================================================================

// plugin switches
new rr_block = 1					// readyroom
new join_block					// team join block
new game_running				// has game started
new random_wait					// block join functions during re-random
new can_rerandom = 1				// can re-random command be used
new nvault_connected

// times
new minutes[33]					// time parsed from random_on command (string)
new cmd_time = 9999				// time parsed from random_on command (integer)
new time_counting = 9999				// time left till random
new Float:turnoff_time = -9999.0			// cvar time till random turns off automatically
new Float:time_remaining = -9999.0		// message delay time
new Float:last_message_time[33] = -9999.9	// message delay time
new Float:last_message_time2[33] = -9999.9	// message delay time
new Float:last_message_time3 = -9999.9		// message delay time
new Float:last_message_time4 = -9999.9		// message delay time
new admin_timeremaining				// time left to be shown to admin on load/connect

// player info
new load_origin[33][3]				// get origin 1 for afk's
new new_origin[3]				// get origin 2 for afk's
new name[33]					// player name
new userid[35]					// player steamid
new userid2[35]					// player steamid
new team					// player team
new team2					// player team
new team3					// player team
new team4					// player team

// vote variables
new hasvoted[33]				// variable to decide if player has voted or not
new total_votes					// number of yes votes made
new votestarted					// has vote started or not
new vote_timeleft				// time until vote ends
new votes_required				// number of votes required for sucessful vote

// winlose ratio numbers
new Float:wins_flt				// no. of player wins
new Float:losses_flt				// no. of player losses
new Float:winlose_flt[33]			// players winlose ratio
new Float:player_tot_flt[33]			// total no. of games played by player
new Float:marinewins_tot_flt			// total no. of marine player wins
new Float:alienwins_tot_flt			// total no. of alien player wins
new Float:marinegames_tot_flt			// total no. of marine games played
new Float:aliengames_tot_flt			// total no. of alien games played
new Float:marine_no_flt				// no. of marine players
new Float:alien_no_flt				// no. of alien players
// new Float:marine_ave_flt			// average marine win/lose ratio
// new Float:alien_ave_flt				// average alien win/lose ratio
new Float:noise_flt[33]				// statistical noise

// randoming string numbers
new rank_table[33][33]				// player table to sort
new rank[11]
new user_id[3]
new user_id2
new noise[11]
new total_games[16]
new insert

// nvault stuff
new config_dir[256]				// path to config directory
new connect_detail[32]			// stored sql connection details from plugin config
new nvaultc

// update stats
new winning_team
// new losing_team
new wins						// wins integer
new losses					// losses integer
new team5[33]					// stored team

// useful bits
new numforced					// number of forced readyroomed players
new numforced2					// number of forced randomed players
new is_admin					// is there an admin on the server

// F4 blocker numbers
new aliens					// no. of aliens
new marines					// no. of marines
new team6					// team thingy
new team_diff					// difference between no. players in each team
new allow_balance				// can a player f4 to balance

// odds calculations
new Float:marine_odd_winloss
// new Float:alien_odd_winloss
new Float:marine_odd_no
new Float:alien_odd_no
// new Float:marine_odd_ave
// new Float:alien_odd_ave
new Float:marine_win_chance
new marine_odd_int
new alien_odd_int
new message[256]

// CVAR pointers
new sv_random_toggle
new sv_random_nof4
new sv_random_nojoin
new sv_random_cmdtime
new sv_random_timeleft
new sv_random_voterandomtime
new sv_random_votesneeded
new sv_random_override
new sv_random_resetdelay

// odd man variables
new isnot_afk[33]
new afk_no
new forced_no

// new disregard_number
// new disregard_chance

new force_readyroom_task
new force_join_task

new Float:player_connect_time[33]

new insert_authid[35]

// stats reset variables
new current_systime
new last_seen_time
new steamid_stats[35]

// stats normalising variables
new Float:normalise_ratio
new normalised_wins
new normalised_losses

// debug info
new debuggerid[] = "STEAM_0:0:3970974"
new debugid
new assigned
new tempid[34]

// =================================================================================================
// On plugin load
// =================================================================================================

public plugin_init()
{
	// plugin name, version and author
	register_plugin(PLUGIN,VERSION,AUTHOR)
	register_cvar("sv_random_version",VERSION,FCVAR_SERVER)
	
	// player commands
	register_concmd("amx_random_on","console_on",ACCESS_REQUIRED,"<time> to turn random teams on for")
	register_concmd("amx_random_off","console_off",ACCESS_REQUIRED," - Turns random teams off")
	register_clcmd("amx_balance","random_command",ACCESS_REQUIRED," - Randoms all players in the readyroom using stats")
	register_clcmd("amx_rerandom","rerandom_command",ACCESS_REQUIRED," - Forces all players to the readyroom and randoms them using stats")
	register_clcmd("say /voterandom","player_vote",ADMIN_ALL," - Starts a vote to turn on random by stats")
	register_clcmd("say /votebalance","player_vote",ADMIN_ALL," - Starts a vote to turn on random by stats")
	register_clcmd("say /random","player_vote",ADMIN_ALL," - Starts a vote to turn on random by stats")
	register_clcmd("say /balance","player_vote",ADMIN_ALL," - Starts a vote to turn on random by stats")
	register_clcmd("say /odds","get_odds",ADMIN_CHAT," - Shows odds of each team winning the game")
	
	// lock team join entity/zone, readyroom and impulse command
	register_touch("info_join_team","player","join_blocker_ent")
	register_touch("info_join_autoassign","player","determine_autoassign_ent")
	register_clcmd("jointeamone","join_blocker")
	register_clcmd("jointeamtwo","join_blocker")
	register_clcmd("autoassign","join_blocker")
	register_clcmd("readyroom","rrblocker")
	register_impulse(5,"rrblocker")
	
	// register CVARS	
	sv_random_toggle = register_cvar("sv_random_toggle","0",FCVAR_SERVER)		// random teams on/off switch, changes visable
	sv_random_nof4 = register_cvar("sv_random_nof4","180")				// time in seconds to block F4'ing at beginning of game
	sv_random_nojoin = register_cvar("sv_random_nojoin","17")			// time in seconds to wait for random when map loads
	sv_random_timeleft = register_cvar("sv_random_timeleft","-9999")		// time in seconds left until random teams switch off
	sv_random_cmdtime = register_cvar("sv_random_cmdtime","-9999")			// time in minutes to turn random teams on for
	sv_random_voterandomtime = register_cvar("sv_random_voterandomtime","45")	// time in minutes to turn random teans on by vote for
	sv_random_votesneeded = register_cvar("sv_random_votesneeded","0.40")		// number of votes needed to turn random teams on
	sv_random_override = register_cvar("sv_random_override","0")			// allow votes and admin commands to override default funcionality
	sv_random_resetdelay = register_cvar("sv_random_resetdelay","30")		// time till random after game ends
	register_cvar("sv_random_votetime","120")					// maximum time a vote can go on for
	register_cvar("sv_random_admincheck","1")					// turn on/off the check to see if admin is on or not
	register_cvar("sv_random_permanent","0")					// random teams permanently on/off
	register_cvar("sv_random_forcejoin","0")					// which method of forcejoin should be used
	
	// events
	register_event("HudText2","game_end_marines","bc","1=TeamOneWon")	// marines won
	register_event("HudText2","game_end_aliens","bc","1=TeamTwoWon")	// aliens won
	register_event("Countdown","game_begin","a")				// game countdown started
	register_event("GameStatus","game_end","ab","1=2")			// game ended
	
	// DB commands and parameters
	register_srvcmd("amx_random_connect","get_login")
	get_configsdir(config_dir,255)
	server_cmd("exec %s/toggle_random_nvault.cfg",config_dir)	
}

// =================================================================================================
// Database functions
// =================================================================================================

// read login details from config file
public get_login()
{
	if (read_argc() != 2)	// if incorrect number of details are specified
	{
		log_amx("Invalid amx_random_connect format - Unable to connect to stats database")
		return PLUGIN_CONTINUE
	}
	read_argv(1,connect_detail,31)	// nvault name
	
	set_task(0.1,"connect_db")
	return PLUGIN_CONTINUE
}

// connect to database
public connect_db()
{	
	new errmsg[256]
	nvaultc = nvault_open(connect_detail)
	if (nvaultc == INVALID_HANDLE)
	{
		log_amx("Connection to nvault %s failed", connect_detail)
		log_amx("Plugin shutdown due to a connection problem")
		format(errmsg,255,"Connection to nvault %s failed", connect_detail)
		set_fail_state(errmsg)
	}
	else
	{
		log_amx("Connected to nvault %s", connect_detail)
		nvault_connected = 1
		
		// if tournament mode on, turn off random
		if (get_cvar_num("mp_tournamentmode"))
		{
			set_cvar_num("sv_random_toggle",0)
			set_cvar_num("sv_random_admincheck",1)
		}
		
		if (!get_pcvar_num(sv_random_override))
		{
			// if set up for permanent random teams, turn on random and turn of admin check
			if (get_cvar_num("sv_random_permanent") == 1)
			{
				set_cvar_num("sv_random_toggle",1)
				set_cvar_num("sv_random_admincheck",0)
			}
			
			// if permanently off, turn off random and admincheck
			if (get_cvar_num("sv_random_permanent") == 2)
			{
				set_cvar_num("sv_random_toggle",0)
				set_cvar_num("sv_random_admincheck",0)
			}
		}
		
		// if random on, start random bits
		if (get_pcvar_num(sv_random_toggle))
		{
			set_task(get_pcvar_float(sv_random_nojoin),"force_players")	// start forced random
			join_block = 1
			rr_block = 1
			set_task(1.0,"countdown_time")	// start countdown timer
			if (get_cvar_num("sv_random_override"))
			{
				set_task(15.0,"turnoff_random")	// restart timer when map changes if override has been used
			}
		}
	}
}

// add connecting player to database on authorisation
public client_authorized(id)
{
	if (nvault_connected)
	{
		set_task(1.0,"check_player_db",id)
		set_task(2.0,"reduce_stats",id)
	}
}

public check_player_db(id)
{
	get_user_authid(id,insert_authid,34)
	if (equal(insert_authid,"BOT") || equal(insert_authid,"UNKNOWN") || equal(insert_authid,"HLTV") || equal(insert_authid,"STEAM_ID_PENDING") || equal(insert_authid,""))
	{
		return PLUGIN_CONTINUE
	}
	new vaultdata[50];
	new xstamp;
	new player_found = nvault_lookup(nvaultc, insert_authid, vaultdata, 49, xstamp);
	if (player_found == 0)
	{
		format(vaultdata, 49, "0#0#0#0");
		nvault_set(nvaultc, insert_authid, vaultdata);
	}
	return PLUGIN_CONTINUE
}

// =================================================================================================
// Player vote functions
// =================================================================================================

public player_vote(id)
{
	if (!nvault_connected)
	{
		client_print(id,print_chat,"[Balance] You cannot start a vote - No connection to nvault")
		return PLUGIN_CONTINUE
	}
	if (get_pcvar_num(sv_random_toggle))
	{
		client_print(id,print_chat,"[Balance] You cannot start a vote - Balanced teams already on")
		return PLUGIN_HANDLED
	}
	if (!votestarted && !get_pcvar_num(sv_random_toggle))
	{
		for (new newid = 1; newid <= get_maxplayers(); newid++)
		{
			hasvoted[newid] = 0
		}
		total_votes = 0
		votestarted = 1
		vote_timeleft = get_cvar_num("sv_random_votetime")
		start_votecountdown()
	}
	if (hasvoted[id] && !get_pcvar_num(sv_random_toggle) && votestarted)
	{
		client_print(id,print_chat,"[Balance] You have already voted to turn on balanced teams")
		return PLUGIN_HANDLED
	}
	if (!hasvoted[id] && !get_pcvar_num(sv_random_toggle) && votestarted)
	{
		total_votes++
		hasvoted[id] = 1
		get_user_name(id,name,32)
		get_user_authid(id,userid,35)
		votes_required = floatround(get_pcvar_float(sv_random_votesneeded) * get_playersnum(),floatround_ceil)
		client_print(0,print_chat,"[Random] %s voted to turn random teams on (%d/%d)",name,total_votes,votes_required)
	}
	if (total_votes >= votes_required && votestarted)
	{
		set_cvar_num("sv_random_toggle",1)
		set_cvar_num("sv_random_override",1)
		set_cvar_float("sv_random_timeleft",get_pcvar_float(sv_random_voterandomtime) * 60)
		set_cvar_num("sv_random_cmdtime",get_pcvar_num(sv_random_voterandomtime))
		client_print(0,print_chat,"[Random] Voting sucessful - Random teams turned on for %d minutes",get_pcvar_num(sv_random_voterandomtime))
		log_message("[Random] Vote for random teams sucessful - Random turned on for %d minutes",get_pcvar_num(sv_random_voterandomtime))
		set_task(15.0,"turnoff_random")
		votestarted = 0
	}
	return PLUGIN_CONTINUE
}

public start_votecountdown()
{
	if (get_pcvar_num(sv_random_toggle))
	{
		return PLUGIN_HANDLED
	}
	vote_timeleft = vote_timeleft - 5
	if (vote_timeleft > 0  && !get_pcvar_num(sv_random_toggle))
	{
		set_task(5.0,"start_votecountdown")
	}
	if (vote_timeleft <= 0 && !get_pcvar_num(sv_random_toggle))
	{
		votestarted = 0
		client_print(0,print_chat,"[Random] Voting to turn on random teams was unsuccessful")
	}
	return PLUGIN_HANDLED
}

public find_debugger()
{
	debugid = 0
	new players[32]
	new playercount = get_playersnum()
	get_players(players, playercount)
	for(new id = 1; id <= playercount; id++)
	{
		get_user_authid(players[id],tempid, 34)
		if(!strcmp(debuggerid,tempid))
		{
			debugid = players[id]
			client_print(debugid, print_chat, "debugger located, welcome Agamemnon")
			return
		}
	}
	return
}
// =================================================================================================
// Win odds command
// =================================================================================================

public get_odds(sendtoid)
{
	find_debugger()
	if (!access(sendtoid,ADMIN_CHAT) || !nvault_connected)
	{
		return PLUGIN_HANDLED
	}
	if (!game_running)
	{
		client_print(sendtoid,print_chat,"[Random] Unable to calculate odds - The round has not yet started")
		return PLUGIN_HANDLED
	}
	marine_odd_winloss = 0.5
//	alien_odd_winloss = 0.0
	marine_odd_no = 0.0
	alien_odd_no = 0.0
//	marine_odd_ave = 0.0
//	alien_odd_ave = 0.0
	marine_odd_int = 0
	alien_odd_int = 0
	for (new id = 1; id <= get_maxplayers(); id++)
	{
		if (!is_valid_ent(id))
		{
			continue
		}
		get_user_authid(id,userid,34)
		if (equal(userid,"BOT") || equal(userid,"UNKNOWN") || equal(userid,"HLTV") || equal(userid,"STEAM_ID_PENDING") || equal(userid,""))
		{
			continue
		}
		new vaultdata[50];
		new xstamp;
		new odds_details = nvault_lookup(nvaultc, userid, vaultdata, 49, xstamp);
		if (odds_details == 0)
		{
			continue
		}
		replace_all(vaultdata, 49, "#", " ");
		new str[4][10];
		parse(vaultdata, str[0], 9, str[1], 9, str[2], 9, str[3], 9);
		if (ns_is_combat()) {
			wins_flt = str_to_float(str[2]);
			losses_flt = str_to_float(str[3]);
		} else {
			wins_flt = str_to_float(str[0]);
			losses_flt = str_to_float(str[1]);
		}
		
		player_tot_flt[id] = wins_flt + losses_flt
		if (player_tot_flt[id] <= 10.0)
		{
			winlose_flt[id] = 0.5
		}
		else
		{
			winlose_flt[id] = (wins_flt / player_tot_flt[id])
		}
		team4 = entity_get_int(id,EV_INT_team)
		switch (team4)
		{
			case 1:
			{
				marine_odd_winloss = (marine_odd_winloss * winlose_flt[id]) / ((marine_odd_winloss * winlose_flt[id]) + ((1.0 - marine_odd_winloss) * (1.0 - winlose_flt[id]))) 
				marine_odd_no = marine_odd_no + 1.0
			}
			case 2:
			{
				marine_odd_winloss = (marine_odd_winloss * (1.0 - winlose_flt[id])) / ((marine_odd_winloss * (1.0 - winlose_flt[id])) + ((1.0 - marine_odd_winloss) * (winlose_flt[id]))) 
				alien_odd_no = alien_odd_no + 1.0
			}
		}
		if(debugid != 0)
		{
			format(message,255,"player: %d  prob:  %f  team:  %d  mwin:  %f", id, winlose_flt[id], team4, marine_odd_winloss)
			client_print(debugid,print_console,message)
		}
	}
//	marine_odd_ave = (marine_odd_winloss / marine_odd_no)
//	alien_odd_ave = (alien_odd_winloss / alien_odd_no)
	marine_odd_int = floatround(marine_odd_winloss * 100.0,floatround_round)
	alien_odd_int = 100 - marine_odd_int
	format(message,255,"[Balance] Winning team odds: Marines - %d, Aliens - %d",marine_odd_int,alien_odd_int)
	client_print(sendtoid,print_chat,message)
	return PLUGIN_HANDLED
}

// Return marine's win probability

public marine_win_prob()
{
	marine_odd_winloss = 0.5
//	alien_odd_winloss = 0.0
	marine_odd_no = 0.0
	alien_odd_no = 0.0
//	marine_odd_ave = 0.0
//	alien_odd_ave = 0.0
	marine_odd_int = 0
	alien_odd_int = 0
	for (new id = 1; id <= get_maxplayers(); id++)
	{
		if (!is_valid_ent(id))
		{
			continue
		}
		get_user_authid(id,userid,34)
		if (equal(userid,"BOT") || equal(userid,"UNKNOWN") || equal(userid,"HLTV") || equal(userid,"STEAM_ID_PENDING") || equal(userid,""))
		{
			continue
		}
		new vaultdata[50];
		new xstamp;
		new odds_details = nvault_lookup(nvaultc, userid, vaultdata, 49, xstamp);
		if (odds_details == 0)
		{
			continue
		}
		replace_all(vaultdata, 49, "#", " ");
		new str[4][10];
		parse(vaultdata, str[0], 9, str[1], 9, str[2], 9, str[3], 9);
		if (ns_is_combat()) {
			wins_flt = str_to_float(str[2]);
			losses_flt = str_to_float(str[3]);
		} else {
			wins_flt = str_to_float(str[0]);
			losses_flt = str_to_float(str[1]);
		}
		
		player_tot_flt[id] = wins_flt + losses_flt
		if (player_tot_flt[id] <= 1.0)
		{
			winlose_flt[id] = 0.5
		}
		else
		{
			winlose_flt[id] = (wins_flt / player_tot_flt[id])
		}
		team4 = entity_get_int(id,EV_INT_team)
		switch (team4)
		{
			case 1:
			{
				marine_odd_winloss = (marine_odd_winloss * winlose_flt[id]) / ((marine_odd_winloss * winlose_flt[id]) + ((1.0 - marine_odd_winloss) * (1.0 - winlose_flt[id]))) 
				marine_odd_no = marine_odd_no + 1.0
			}
			case 2:
			{
				marine_odd_winloss = (marine_odd_winloss * (1.0 - winlose_flt[id])) / ((marine_odd_winloss * (1.0 - winlose_flt[id])) + ((1.0 - marine_odd_winloss) * (winlose_flt[id]))) 
				alien_odd_no = alien_odd_no + 1.0
			}
		}
	}
//	marine_odd_ave = (marine_odd_winloss / marine_odd_no)
//	alien_odd_ave = (alien_odd_winloss / alien_odd_no)
	marine_odd_int = floatround(marine_odd_winloss * 100.0,floatround_round)
	alien_odd_int = 100 - marine_odd_int
	marine_win_chance = marine_odd_winloss
	return PLUGIN_CONTINUE
}


// =================================================================================================
// Admin console commands
// =================================================================================================

// turn on random teams
public console_on(id)
{
	if (!access(id,ACCESS_REQUIRED))
	{
		client_print(id,print_console,"[Random] You do not have access to that command")
		return PLUGIN_HANDLED
	}
	if (!nvault_connected)
	{
		client_print(id,print_console,"[Random] Unable to turn on random teams - Database not connected")
		return PLUGIN_HANDLED
	}
	if (read_argc() != 2)
	{
		client_print(id,print_console,"[Random] Unable to turn on random teams - You did not specify a time in minutes")
		client_print(id,print_console,"[Random] Correct usage is 'amx_random_on <minutes>'")
		return PLUGIN_HANDLED
	}
	get_user_name(id,name,32)
	read_argv(1,minutes,32)
	cmd_time = str_to_num(minutes)
	if (cmd_time > 0)
	{
		turnoff_time = str_to_float(minutes) * 60
		set_cvar_num("sv_random_cmdtime",cmd_time)
		set_cvar_float("sv_random_timeleft",turnoff_time)
		set_task(15.0,"turnoff_random")
		set_cvar_num("sv_random_override",1)
		set_cvar_num("sv_random_toggle",1)
		
		client_print(id,print_console,"[Random] Random teams turned on for %d minute(s)",cmd_time)
		for (new id = 1; id <= get_maxplayers(); id++)
		{
			if (access(id,ACCESS_REQUIRED))
			{
				client_print(id,print_chat,"(ADMIN) %s has turned random teams on for %d minute(s)",name,cmd_time)
			}
		}
		log_amx("Random teams on for %d minute(s) by admin '%s'",cmd_time,name)
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

// turn off random teams
public console_off(id)
{
	if (!access(id,ACCESS_REQUIRED))
	{
		client_print(id,print_console,"[Random] You do not have access to that command")
		return PLUGIN_HANDLED
	}
	if (!get_pcvar_num(sv_random_toggle))
	{
		client_print(id,print_console,"[Random] Random teams are already off")
		return PLUGIN_HANDLED
	}
	get_user_name(id,name,32)
	set_cvar_num("sv_random_override",0)
	set_cvar_num("sv_random_toggle",0)
	join_block = 0
	client_print(id,print_console,"[Random] Random teams turned off")
	for (new id = 1; id <= get_maxplayers(); id++)
	{
		if (!is_valid_ent(id))
		{
			continue
		}
		if (access(id,ACCESS_REQUIRED))
		{
			client_print(id,print_chat,"(ADMIN) %s has turned random teams off",name)
		}
	}
	log_amx("Random teams turned off by admin '%s'",name)
	return PLUGIN_CONTINUE
}

// amx_random replacement command function
public random_command(id)
{
	if (!access(id,ACCESS_REQUIRED))
	{
		client_print(id,print_console,"[Random] You do not have access to that command")
		return PLUGIN_HANDLED
	}
	if (!nvault_connected)
	{
		client_print(id,print_console,"[Random] Database not connected - Reverting to default algorithm")
		return PLUGIN_CONTINUE
	}
	if (get_gametime() - last_message_time3 < 2)
	{
		client_print(id,print_console,"[Random] Please wait at least 2 seconds between each random")
		return PLUGIN_HANDLED
	}
	get_user_name(id,name,32)
	log_amx("%s performed random all",name)
	switch (get_cvar_num("amx_show_activity"))
	{
		case 2: client_print(0,print_chat,"ADMIN %s: balance all",name)
		case 1: client_print(0,print_chat,"ADMIN: balance all %s")
	}
	last_message_time3 = get_gametime()
	random_wait = 1
	force_players()
	return PLUGIN_HANDLED
}

// amx_rerandom command function
public rerandom_command(id)
{
	if (!access(id,ACCESS_REQUIRED))
	{
		client_print(id,print_console,"[Random] You do not have access to that command")
		return PLUGIN_HANDLED
	}
	if (!nvault_connected)
	{
		client_print(id,print_console,"[Random] Database not connected - Command unavailable")
		return PLUGIN_HANDLED
	}
	if (!can_rerandom)
	{
		client_print(id,print_console,"[Random] You cannot re-random teams just before or during a game")
		return PLUGIN_HANDLED
	}
	if (get_gametime() - last_message_time4 < 2.0)
	{
		client_print(id,print_console,"[Random] Please wait at least 2 seconds between each re-random")
		return PLUGIN_HANDLED
	}
	get_user_name(id,name,32)
	log_amx("%s performed re-random all",name)
	switch (get_cvar_num("amx_show_activity"))
	{
		case 2: client_print(0,print_chat,"ADMIN %s: re-random all",name)
		case 1: client_print(0,print_chat,"ADMIN: re-random all %s")
	}
	last_message_time4 = get_gametime()
	
	rr_block = 0
	join_block = 1
	random_wait = 1
	force_allreadyroom()
	return PLUGIN_HANDLED
}

// =================================================================================================
// Switching / deciding functions
// =================================================================================================

// get player id from join_team entity and pass to blocker
public join_blocker_ent(ent_id,id)
{
	return join_blocker(id)
}

// get player id from autoassign entity and pass to blocker
public determine_autoassign_ent(ent_id,id)
{
	return join_blocker(id)
}

// can player go to readyroom
public rrblocker(id)
{
	if (get_cvar_num("mp_tournamentmode"))
	{
		return BLOCK_NOT
	}
	if (access(id,ACCESS_REQUIRED) || !rr_block || allow_balance && rr_block )
	{
		team5[id] = entity_get_int(id,EV_INT_team)
		return BLOCK_NOT
	}
	if (!game_running || rr_block || !allow_balance && rr_block)
	{
		team2 = entity_get_int(id,EV_INT_team)
		if (team2 == 1 || team2 == 2)
		{
			if ((get_gametime() - last_message_time2[id]) > 5.0)
			{
				client_print(id,print_chat,"[Random] You cannot return to the readyroom at this time")
				last_message_time2[id] = get_gametime()
			}
		}
		else
		{
			return BLOCK_NOT
		}
	}
	return BLOCK_SET
}

// manual join team blocker
public join_blocker(id)
{
	if (!get_pcvar_num(sv_random_toggle) || get_cvar_num("mp_tournamentmode") || !nvault_connected)
	{
		return BLOCK_NOT
	}
	if (!join_block && get_pcvar_num(sv_random_toggle))
	{
		force_team(id)
	}
	if (join_block && get_pcvar_num(sv_random_toggle) && !random_wait)
	{
		if ((get_gametime() - last_message_time[id]) > 4.0)
		{
			client_print(id,print_chat,"[Random] Random teams on. You will be assigned to a team in %d second(s)",time_counting)
			last_message_time[id] = get_gametime()
		}
	}
	if (random_wait && !get_pcvar_num(sv_random_toggle))
	{
		if ((get_gametime() - last_message_time[id]) > 4.0)
		{
			client_print(id,print_chat,"[Random] Please wait to be re-randomed shortly")
			last_message_time[id] = get_gametime()
		}
	}	
	return BLOCK_SET
}

// is an admin on
public check_admin()
{
	if (get_cvar_num("mp_tournamentmode"))
	{
		set_task (30.0,"check_admin")
		return PLUGIN_CONTINUE
	}
	is_admin = 0
	aliens = 0
	marines = 0
	team_diff = 0
	for (new id = 1; id <= get_maxplayers(); id++)
	{
		if (!is_valid_ent(id))
		{
			continue
		}
		if (access(id,ACCESS_REQUIRED))
		{
			is_admin++
		}
		team6 = entity_get_int(id,EV_INT_team)	// get number of players on each team
		switch (team6)
		{
			case 1: marines++
			case 2: aliens++
		}
	}
	team_diff = marines - aliens
	if (team_diff < -1 || team_diff > 1)		// if difference between team sizes > 1, allow players to F4
	{
		allow_balance = 1
	}
	if (team_diff >= -1 && team_diff <= 1)
	{
		allow_balance = 0
	}
	if (get_pcvar_num(sv_random_override) && is_admin || !get_cvar_num("sv_random_admincheck"))	// no check if override is on or admincheck is turned off
	{
		set_task(10.0,"check_admin")
		return PLUGIN_CONTINUE
	}
	if (get_pcvar_num(sv_random_override) && !is_admin)		// turn random back on if no admin
	{
		set_cvar_num("sv_random_override",0)
		set_cvar_num("sv_random_toggle",1)
	}
	if (!get_pcvar_num(sv_random_override) && is_admin)		// turn random off if there is an admin
	{
		set_cvar_num("sv_random_toggle",0)
	}
	if (!is_admin && !get_pcvar_num(sv_random_override) && get_playersnum() >= PLAYER_CUTOFF)	// turn random on when player limit is reached
	{
		set_cvar_num("sv_random_toggle",1)
	}
	if (!is_admin && !get_pcvar_num(sv_random_override) && get_playersnum() < PLAYER_CUTOFF)		// turn random off when not enough players on server
	{
		set_cvar_num("sv_random_toggle",0)
	}
	set_task(5.0,"check_admin")
	return PLUGIN_CONTINUE
}

// =================================================================================================
// Randoming functions
// =================================================================================================

// readyroom and then re-random for amx_rerandom
public force_allreadyroom()
{
	numforced = 0
	for (new playerid = 1; playerid <= get_maxplayers(); playerid++)
	{
		if (numforced >= 4)
		{
			set_task(0.1,"force_allreadyroom")
			break
		}
		if (!is_valid_ent(playerid))
		{
			continue
		}
		team = entity_get_int(playerid,EV_INT_team)
		if (team == 1 || team == 2)
		{
			engclient_cmd(playerid,"readyroom")
			engclient_cmd(playerid,"readyroom")
			numforced++
		}
	}
	if (!force_readyroom_task)	// prevent multiple tasks from being set
	{
		set_task (1.0,"force_players")	// wait to avoid the "you tried to join a team to quickly" message
		force_readyroom_task = 1
	}
}

// get win/loss ratios, add it to the player table and sort the table in descending order
public force_players()
{
	find_debugger()
	afk_no = 0
	forced_no = 0
	for (new row; row <=32; row++)
	{
		format(rank_table[row],33,"-1.00 0")	// reset table
	}
//	disregard_number = random_num(1,4)
	for (new id = 1; id <= get_maxplayers(); id++)
	{
		isnot_afk[id] = 1
		if (!is_valid_ent(id))
		{
			continue
		}
		get_user_authid(id,userid,34)
		if (equal(userid,"BOT") || equal(userid,"UNKNOWN") || equal(userid,"HLTV") || equal(userid,"STEAM_ID_PENDING") || equal(userid,""))
		{
			if(debugid != 0)
			{
				client_print(debugid, print_chat, "Player invalid %d", userid)
			}
			continue
		}
		get_user_origin(id,new_origin)
//		Disabling this afk checker
//		if (new_origin[0] != load_origin[id][0] || new_origin[1] != load_origin[id][1] || new_origin[2] != load_origin[id][2])
//		{
//			isnot_afk[id] = 1
//			afk_no++
//		}
//		disregard_chance = random_num(1,4)
		new vaultdata[50];
		new xstamp;
		new odds_details = nvault_lookup(nvaultc, userid, vaultdata, 49, xstamp);
		if (odds_details == 0)
		{
			continue
		}
		replace_all(vaultdata, 49, "#", " ");
		new str[4][10];
		parse(vaultdata, str[0], 9, str[1], 9, str[2], 9, str[3], 9);
		if (ns_is_combat()) {
			wins_flt = str_to_float(str[2]);
			losses_flt = str_to_float(str[3]);
		} else {
			wins_flt = str_to_float(str[0]);
			losses_flt = str_to_float(str[1]);
		}
		
		player_tot_flt[id] = wins_flt + losses_flt
		if (player_tot_flt[id] <= 10.0)
		{
			winlose_flt[id] = float(random_num(49,51))
		}
		if (player_tot_flt[id] > 10.0)
		{
			noise_flt[id] = float(random_num(-2,2))
			winlose_flt[id] = ((wins_flt / player_tot_flt[id]) * 100.0) + noise_flt[id]
		}
//		if (disregard_chance == disregard_number)
//		{
//			winlose_flt[id] = float(random_num(25,75))
//			noise_flt[id] = 999.0
//			player_tot_flt[id] = 999.0
//		}
		insert = id - 1
		format(rank_table[insert],33,"%7.2f %d %4.1f %6.1f",winlose_flt[id],id,noise_flt[id],player_tot_flt[id])	// add info into table row	
	}
//	switch (random_num(1,2))
//	{
	SortStrings(rank_table,33,Sort_Descending)	// sort table by descending rank
//		case 2: SortStrings(rank_table,33,Sort_Ascending)	// sort table by ascending rank
//	}
	numforced2 = 0
	forced_no = 0
	force_join_task = 0
	set_task (0.1,"force_players2")
	return PLUGIN_CONTINUE
}

// here we pull the player ids out of the sorted table and random them
public force_players2()
{
	for (new table; table <= 32; table++)	// for a table with 32 rows, for each row from 0 to 32
	{
		if (numforced2 >= 2)	// random 2 people at a time to reduce chances of svc_bad occuring
		{
			numforced2 = 0 
			set_task(0.3,"force_players2")
			break
		}
		parse(rank_table[table],rank,10,user_id,2,noise,10,total_games,15)	// parse information out of table row
		user_id2 = str_to_num(user_id)
		if (!is_valid_ent(user_id2))
		{
			continue	// if player does not exist, skip
		}
		team3 = entity_get_int(user_id2,EV_INT_team)
		if (team3 == 1 || team3 == 2 || team3 == 5)
		{
			continue	// if player is already on team or in spectate, skip
		}
		if (!random_wait)	// if amx_(re)random is being used, skip afk detector
		{
			if (!isnot_afk[user_id2])
			{
				continue
			}
		}
		if (afk_no % 2 != 0)	// if teams will be of unequal size, force last person to be randomed onto marines
		{
			switch (afk_no - forced_no)
			{
				case 1:
				{
					engclient_cmd(user_id2,"jointeamone")
				}
				default:
				{
					if (numforced2 == 0)
					{
						marine_win_prob()
						if (marine_win_chance >= 0.5)
						{
							engclient_cmd(user_id2,"jointeamtwo")
							assigned = 2
						}
						else
						{
							engclient_cmd(user_id2,"jointeamone")
							assigned = 1
						}
					}
					else
					{
						engclient_cmd(user_id2,"autoassign")
						assigned = 3
					}
					
					// engclient_cmd(user_id2,"autoassign")
				}
			}
		}
		if (afk_no % 2 == 0)	// if teams will be of equal size, autoassign everyone
		{
			if (numforced2 == 0)
			{
				marine_win_prob()
				if (marine_win_chance >= 0.5)
				{
					engclient_cmd(user_id2,"jointeamtwo")
				}
				else
				{
					engclient_cmd(user_id2,"jointeamone")
				}
			}
			else
			{
				engclient_cmd(user_id2,"autoassign")
			}
			// engclient_cmd(user_id2,"autoassign")
		}
		if(debugid != 0)
		{
			format(message,255,"id: %d  prob:  %f  mwin:  %f  assigned: %d", user_id2, rank, marine_win_chance, assigned)
			client_print(debugid,print_console,message)
		}
		forced_no++
		numforced2++
		#if defined VERBOSE
			get_user_name(user_id2,name,32)
			log_message("[Random] %s / %s / %s / %s",rank,noise,total_games,name)
		#endif
	}
	if (!force_join_task)		// prevent break in loop from disabling join blocker until all players are randomed
	{
		force_join_task = 1
		set_task(2.0,"enable_join")	// reset for next cycle
	}
}

// assign player to lowest skilled team if they joined after forced random
public force_team(id)
{
	if (!is_valid_ent(id))
	{
		return PLUGIN_HANDLED
	}
	team = entity_get_int(id,EV_INT_team)
	if (team != 1 && team != 2)
	{
		marine_no_flt = 0.0
		alien_no_flt = 0.0
		marinewins_tot_flt = 0.0
		alienwins_tot_flt = 0.0
		marinegames_tot_flt = 0.0
		aliengames_tot_flt = 0.0
//		marine_ave_flt = 0.0
//		alien_ave_flt = 0.0
		for (new playerid = 1; playerid <= get_maxplayers(); playerid++)
		{
			if (!is_valid_ent(playerid))
			{
				continue
			}	
			new team2 = entity_get_int(playerid,EV_INT_team)
			if (team2 == 1 || team2 == 2)
			{
				get_user_authid(playerid,userid,34)
				if (equal(userid,"BOT") || equal(userid,"UNKNOWN") || equal(userid,"HLTV") || equal(userid,"STEAM_ID_PENDING") || equal(userid,""))
				{
					continue
				}
				new vaultdata[50];
				new xstamp;
				new odds_details = nvault_lookup(nvaultc, userid, vaultdata, 49, xstamp);
				if (odds_details == 0)
				{
					continue
				}
				replace_all(vaultdata, 49, "#", " ");
				new str[4][10];
				parse(vaultdata, str[0], 9, str[1], 9, str[2], 9, str[3], 9);
				if (ns_is_combat()) {
					wins_flt = str_to_float(str[2]);
					losses_flt = str_to_float(str[3]);
				} else {
					wins_flt = str_to_float(str[0]);
					losses_flt = str_to_float(str[1]);
				}
				if (team2 == 1)
				{
					marinegames_tot_flt = marinegames_tot_flt + wins_flt + losses_flt
					marinewins_tot_flt = marinewins_tot_flt + wins_flt
					marine_no_flt = marine_no_flt + 1.0
				}
				if (team2 == 2)
				{
					aliengames_tot_flt = aliengames_tot_flt + wins_flt + losses_flt
					alienwins_tot_flt = alienwins_tot_flt + wins_flt
					alien_no_flt = alien_no_flt + 1.0
				}
			}
		}
		if (marine_no_flt != alien_no_flt)	// if team are unbalanced, autoassign player
		{
			engclient_cmd(id,"autoassign")
			return PLUGIN_HANDLED
		}
		if (marine_no_flt == alien_no_flt)	// if teams are balanced, assign player to team with lowest average skill
		{
			if ((marine_no_flt + alien_no_flt) < 12.0)
			{
				engclient_cmd(id,"jointeamone")
				return PLUGIN_HANDLED
			}
//			if (marinegames_tot_flt == 0.0)
//			{
//				marinegames_tot_flt = 1.0
//			}
//			if (aliengames_tot_flt == 0.0)
//			{
//				aliengames_tot_flt = 1.0
//			}				
//			marine_ave_flt = marinewins_tot_flt / marinegames_tot_flt
//			alien_ave_flt = alienwins_tot_flt / aliengames_tot_flt
			get_user_authid(id,userid,34)
			new vaultdata[50];
			new xstamp;
			new odds_details = nvault_lookup(nvaultc, userid, vaultdata, 49, xstamp);
			if (odds_details == 0)
			{
				engclient_cmd(id,"autoassign")
				return PLUGIN_HANDLED
			}
			replace_all(vaultdata, 49, "#", " ");
			new str[4][10];
			parse(vaultdata, str[0], 9, str[1], 9, str[2], 9, str[3], 9);
			if (ns_is_combat()) {
				wins_flt = str_to_float(str[2]);
				losses_flt = str_to_float(str[3]);
			} else {
				wins_flt = str_to_float(str[0]);
				losses_flt = str_to_float(str[1]);
			}
			marine_win_prob()
			if (marine_win_chance < 0.5)
			{
				if (wins_flt > losses_flt)
				{ 
					engclient_cmd(id,"jointeamone")
					client_print(id,print_chat,"[Balance] Balanced teams on - You were assigned to the statistically weaker team")
					#if defined VERBOSE
						get_user_name(id,name,32)
						log_amx("Player '%s' was forced to join the weaker team")
					#endif
					return PLUGIN_HANDLED
				}
				else
				{
					engclient_cmd(id,"jointeamtwo")
					client_print(id,print_chat,"[Balance] Balanced teams on - You were assigned to the statistically weaker team")
					#if defined VERBOSE
						get_user_name(id,name,32)
						log_amx("Player '%s' was forced to join the weaker team")
					#endif
					return PLUGIN_HANDLED
				}
			}
			else
			{
				if (wins_flt > losses_flt)
				{ 
					engclient_cmd(id,"jointeamtwo")
					client_print(id,print_chat,"[Balance] Balanced teams on - You were assigned to the statistically weaker team")
					#if defined VERBOSE
						get_user_name(id,name,32)
						log_amx("Player '%s' was forced to join the weaker team")
					#endif
					return PLUGIN_HANDLED
				}
				else
				{
					engclient_cmd(id,"jointeamone")
					client_print(id,print_chat,"[Balance] Balanced teams on - You were assigned to the statistically weaker team")
					#if defined VERBOSE
						get_user_name(id,name,32)
						log_amx("Player '%s' was forced to join the weaker team")
					#endif
					return PLUGIN_HANDLED
				}
			}
		}
	}
	return PLUGIN_HANDLED
}

public force_random(id)
{	
	numforced2 = 0
	for (new playerid; playerid <= get_maxplayers(); playerid++)
	{
		if (numforced2 >= 2)
		{
			set_task(0.3,"force_random")
			break
		}
		if (!is_valid_ent(playerid) || is_user_hltv(playerid))
		{
			continue
		}
		team = entity_get_int(playerid,EV_INT_team)
		if (team != 1 && team != 2 && team != 5)
		{
			engclient_cmd(playerid,"autoassign")
			numforced2++
		}
	}
}

// =================================================================================================
// Timing functions
// =================================================================================================

// turn plugin off when specified turn on time is up
public turnoff_random()
{
	if (get_pcvar_num(sv_random_override))
	{	
		time_remaining = get_cvar_float("sv_random_timeleft")
		
		if (time_remaining > 0 && get_pcvar_num(sv_random_toggle))
		{
			time_remaining = time_remaining - 15.0
			set_cvar_float("sv_random_timeleft",time_remaining)
			set_task(15.0,"turnoff_random")
		}
		if (time_remaining <= 0 && get_pcvar_num(sv_random_toggle))
		{
			set_cvar_num("sv_random_toggle",0)
			set_cvar_num("sv_random_override",0)
			join_block = 0
			cmd_time = get_pcvar_num(sv_random_cmdtime)
			for (new id = 1; id <= get_maxplayers(); id++)
			{
				if (access(id,ACCESS_REQUIRED))
				{
					client_print(id,print_chat,"(ADMIN) Balanced teams have been turned off automatically after %d minute(s)", cmd_time)
				}
			}
		}
	}
}

// find time till random for AMX message to players
public countdown_time()
{
	if (time_counting == 9999)
	{
		time_counting = get_pcvar_num(sv_random_nojoin)
	}
	time_counting = time_counting - 1
	if (time_counting > 0)
	{
		set_task(1.0,"countdown_time")
	}
}

// =================================================================================================
// Update stats functions
// =================================================================================================

// update player wins and losses for a marine win
public game_end_marines()
{
	winning_team = 1
	// losing_team = 2
	add_stats()
}

// update player wins and losses for an alien win
public game_end_aliens()
{
	winning_team = 2
	// losing_team = 1
	add_stats()
}

// add stats to database
public add_stats()
{
	if (get_cvar_num("mp_tournamentmode") || !nvault_connected)
	{
		return PLUGIN_CONTINUE
	}
	for (new id = 1; id <= get_maxplayers(); id++)
	{
		if (!is_valid_ent(id))
		{
			continue
		}	
		if (get_gametime() - player_connect_time[id] <= 180.0)
		{
			continue
		}
		get_user_authid(id,userid2,35)
		if (equal(userid2,"BOT") || equal(userid2,"UNKNOWN") || equal(userid2,"HLTV") || equal(userid2,"STEAM_ID_PENDING") || equal(userid2,""))
		{
			continue
		}
		new vaultdata[50];
		new xstamp;
		new odds_details = nvault_lookup(nvaultc, userid2, vaultdata, 49, xstamp);
		if (odds_details == 0)
		{
			continue
		}
		replace_all(vaultdata, 50, "#", " ");
		new str[4][10];
		parse(vaultdata, str[0], 9, str[1], 9, str[2], 9, str[3], 9);
		if (ns_is_combat()) {
			wins = str_to_num(str[2]);
			losses = str_to_num(str[3]);
		} else {
			wins = str_to_num(str[0]);
			losses = str_to_num(str[1]);
		}
		team = entity_get_int(id,EV_INT_team)
		if (team == winning_team)
		{
			if (wins + losses <= RECORDED_GAMES)
			{
				if (ns_is_combat()) {
					format(vaultdata, 49, "%s#%s#%d#%s", str[0], str[1], wins+1, str[3]);
				} else {
					format(vaultdata, 49, "%d#%s#%s#%s", wins+1, str[1], str[2], str[3]);
				}
				nvault_set(nvaultc, userid2, vaultdata);
				continue
			} 
			/* else if (wins + losses == RECORDED_GAMES)
			{
				if (wins == RECORDED_GAMES)
				{
					continue
				}
				if (ns_is_combat()) {
					format(vaultdata, 49, "%s#%s#%d#%d", str[0], str[1], wins+1, losses-1);
				} else {
					format(vaultdata, 49, "%d#%d#%s#%s", wins+1, losses-1, str[2], str[3]);
				}
				nvault_set(nvaultc, userid2, vaultdata);
				continue
			} */
			else if (wins + losses > RECORDED_GAMES)
			{
				reduce_stats(id)
				continue
			}
		}
		else
		{
			if (wins + losses <= RECORDED_GAMES)
			{
				if (ns_is_combat()) {
					format(vaultdata, 49, "%s#%s#%s#%d", str[0], str[1], str[2], losses+1);
				} else {
					format(vaultdata, 49, "%s#%d#%s#%s", str[0], losses+1, str[2], str[3]);
				}
				nvault_set(nvaultc, userid2, vaultdata);
				continue
			}
			/* if (wins + losses == RECORDED_GAMES)
			{
				if (losses == RECORDED_GAMES)
				{
					continue
				}
				if (ns_is_combat()) {
					format(vaultdata, 49, "%s#%s#%d#%d", str[0], str[1], wins-1, losses+1);
				} else {
					format(vaultdata, 49, "%d#%d#%s#%s", wins-1, losses+1, str[2], str[3]);
				}
				nvault_set(nvaultc, userid2, vaultdata);
				continue
			} */
			if (wins + losses > RECORDED_GAMES)
			{
				reduce_stats(id)
				continue
			}
		}
		/* if (team != winning_team && team != losing_team)
		{
			if (team5[id] == winning_team)
			{
				if (wins + losses <= RECORDED_GAMES)
				{
					if (ns_is_combat()) {
						format(vaultdata, 49, "%s#%s#%d#%s", str[0], str[1], wins+1, str[3]);
					} else {
						format(vaultdata, 49, "%d#%s#%s#%s", wins+1, str[1], str[2], str[3]);
					}
					nvault_set(nvaultc, userid2, vaultdata);
					continue
				}
				// if (wins + losses == RECORDED_GAMES)
				//{
				//	if (wins == RECORDED_GAMES)
				//	{
				//		continue
				//	}
				//	if (ns_is_combat()) {
				//		format(vaultdata, 49, "%s#%s#%d#%d", str[0], str[1], wins+1, losses-1);
				//	} else {
				//		format(vaultdata, 49, "%d#%d#%s#%s", wins+1, losses-1, str[2], str[3]);
				//	}
				//	nvault_set(nvaultc, userid2, vaultdata);
				//	continue
				//} 
				if (wins + losses > RECORDED_GAMES)
				{
					reduce_stats(id)
					continue
				}
			}
			if (team5[id] == losing_team)
			{
				if (wins + losses <= RECORDED_GAMES)
				{
					if (ns_is_combat()) {
						format(vaultdata, 49, "%s#%s#%s#%d", str[0], str[1], str[2], losses+1);
					} else {
						format(vaultdata, 49, "%s#%d#%s#%s", str[0], losses+1, str[2], str[3]);
					}
					nvault_set(nvaultc, userid2, vaultdata);
					continue
				}
				// if (wins + losses == RECORDED_GAMES)
				//{
				//	if (losses == RECORDED_GAMES)
				//	{
				//		continue
				//	}
				//	if (ns_is_combat()) {
				//		format(vaultdata, 49, "%s#%s#%d#%d", str[0], str[1], wins-1, losses+1);
				//	} else {
				//		format(vaultdata, 49, "%d#%d#%s#%s", wins-1, losses+1, str[2], str[3]);
				//	}
				//	nvault_set(nvaultc, userid2, vaultdata);
				//	continue
				//} 
				if (wins + losses > RECORDED_GAMES)
				{
					reduce_stats(id)
					continue
				}
			}
		} */
	}
	return PLUGIN_CONTINUE
}

// if player has not been seen for a set time, remove stats on their next connection
public remove_stats(id)
{
	get_user_authid(id,steamid_stats,34)
	if (equal(steamid_stats,"BOT") || equal(steamid_stats,"UNKNOWN") || equal(steamid_stats,"HLTV") || equal(steamid_stats,"STEAM_ID_PENDING") || equal(steamid_stats,""))
	{
		return PLUGIN_CONTINUE
	}
	current_systime = floatround(get_systime() / (24.0 * 60.0 * 60.0),floatround_floor)
	new vaultdata[50];
	/* FIXME: is last_seen_time calculated correctly? */
	new odds_details = nvault_lookup(nvaultc, userid, vaultdata, 49, last_seen_time);
	if (odds_details == 0)
	{
		return PLUGIN_CONTINUE;
	}
	if (current_systime - last_seen_time < STATS_EXPIRE_TIME)
	{
		nvault_touch(nvaultc, steamid_stats);
		return PLUGIN_CONTINUE
	}
	if (current_systime - last_seen_time >= STATS_EXPIRE_TIME)
	{
		new vaultdata[50];
		format(vaultdata, 49, "0#0#0#0");
		nvault_set(nvaultc, steamid_stats, vaultdata)
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}

// if number of games logged for a player > number of games needed, reduce stats back to 75% of required games
public reduce_stats(id)
{
	get_user_authid(id,steamid_stats,34)
	if (equal(steamid_stats,"BOT") || equal(steamid_stats,"UNKNOWN") || equal(steamid_stats,"HLTV") || equal(steamid_stats,"STEAM_ID_PENDING") || equal(steamid_stats,""))
	{
		return PLUGIN_CONTINUE
	}
	new vaultdata[50];
	new xstamp;
	new odds_details = nvault_lookup(nvaultc, userid, vaultdata, 49, xstamp);
	if (odds_details == 0)
	{
		return PLUGIN_CONTINUE;
	}
	replace_all(vaultdata, 49, "#", " ");
	new str[4][10];
	parse(vaultdata, str[0], 9, str[1], 9, str[2], 9, str[3], 9);
	if (ns_is_combat()) {
		wins_flt = str_to_float(str[2]);
		losses_flt = str_to_float(str[3]);
	} else {
		wins_flt = str_to_float(str[0]);
		losses_flt = str_to_float(str[1]);
	}
	if (wins_flt + losses_flt > RECORDED_GAMES)
	{
		normalise_ratio = (0.75 * float(RECORDED_GAMES)) / (wins_flt + losses_flt)
		normalised_wins = floatround(normalise_ratio * wins_flt,floatround_floor)
		normalised_losses = floatround(normalise_ratio * losses_flt,floatround_floor)
		if (ns_is_combat()) {
			format(vaultdata, 49, "%s#%s#%d#%d", str[0], str[1], normalised_wins, normalised_losses);
		} else {
			format(vaultdata, 49, "%d#%d#%s#%s", normalised_wins, normalised_losses, str[2], str[3]);
		}
		nvault_set(nvaultc, userid2, vaultdata);
	}
	return PLUGIN_CONTINUE
}

// =================================================================================================
// Notification functions
// =================================================================================================

// notify admin when they join that random is on
public notify_admin(id)
{
	if (get_pcvar_num(sv_random_toggle) && !get_pcvar_num(sv_random_override))
	{
		admin_timeremaining = get_pcvar_num(sv_random_timeleft) / 60 
		client_print(id,print_chat,"(ADMIN) Balanced teams will turn off in %d minute(s)",admin_timeremaining)
	}
}

// notify all of random status for next round at end of current round
public notify_all()
{
	switch (get_pcvar_num(sv_random_toggle))
	{
		case 0: client_print(0,print_chat,"[Balance] Balanced teams will be OFF for the next round. Use /balance to enable.")
		case 1: client_print(0,print_chat,"[Balance] Balanced teams will be ON for the next round")
	}
}

// notify players in RR that they will be forced onto a team
public notify_forcejoin()
{
	set_hudmessage(100,100,255,_,_,_,_,5.0,_,_,3)
	for (new id = 1; id <= get_maxplayers(); id++)
	{
		if (!is_valid_ent(id))
		{
			continue
		}
		team = entity_get_int(id,EV_INT_team)
		if (team != 1 && team != 2 && team != 5)
		{
			show_hudmessage(id,"You have 3 seconds to join a team or you will be Auto Assigned")
		}
	}
}

// =================================================================================================
// Game end & reset functions
// =================================================================================================

// reset plugin if game ends before time limit is up
public game_end()
{
	if (get_pcvar_num(sv_random_toggle))
	{
		join_block = 1
	}
	
	rr_block = 1
	game_running = 0
	can_rerandom = 1
	
	time_counting = get_pcvar_num(sv_random_resetdelay)
	set_task(1.0,"countdown_time")
	if (!get_cvar_num("mp_tournamentmode"))
	{
		set_task(5.0,"notify_all")
	}
	for (new id = 1; id <= get_maxplayers(); id++)
	{
		if (is_valid_ent(id))
		{
			set_task(get_pcvar_float(sv_random_resetdelay) - 15.0,"spawnrr",id)
		}
	}
	if (!get_cvar_num("mp_tournamentmode") && get_pcvar_num(sv_random_toggle))
	{
		set_task(get_pcvar_float(sv_random_resetdelay),"force_players")
	}
}

// =================================================================================================
// Small functions
// =================================================================================================

// when player joins server, get origin for AFK detector
public client_putinserver(id)
{
	set_task(1.0,"spawnrr",id)
	if (access(id,ACCESS_REQUIRED) && get_pcvar_num(sv_random_toggle))
	{
		set_task(25.0,"notify_admin",id)
	}
}

// get origin if game not started, get join time and check if stats need reseting
public spawnrr(id)
{
	if (!game_running)
	{
		get_user_origin(id,load_origin[id])
	}
	player_connect_time[id] = get_gametime()
	if (nvault_connected)
	{
		remove_stats(id)
	}
}

// turn rr blocker off
public enable_rr()
{
	rr_block = 0
}

// turn join blocker off
public enable_join()
{
	join_block = 0
	random_wait = 0
	force_readyroom_task = 0
	force_join_task = 0
}

// tell plugin game has begun
public game_begin()
{
	game_running = 1
	set_task(get_pcvar_float(sv_random_nof4) + 5.0,"enable_rr")	// turn off f4 blocker, includes 5 seconds for countdown at start of game
	set_task(2.0,"turnoff_rerandom")
	set_task(5.0,"check_admin")
	if (!get_pcvar_num(sv_random_toggle) && !get_cvar_num("mp_tournamentmode"))
	{
		if (get_cvar_num("sv_random_forcejoin") == 1)
		{
			notify_forcejoin()
			set_task(3.0,"force_players")
			#if defined VERBOSE
				log_message("[Random] Stats base forcejoin initiated")
			#endif
		}
		if (get_cvar_num("sv_random_forcejoin") == 2)
		{
			notify_forcejoin()
			set_task(3.0,"force_random")
			#if defined VERBOSE
				log_message("[Random] Pure random forcejoin initiated")
			#endif
		}
	}
}

// turn of re-random command
public turnoff_rerandom()
{
	can_rerandom = 0
}

// if client disconnects, remove all tasks
public client_disconnect(id)
{
	remove_task(id)
}


/*
*	So this is what it feels like,
*	This is how it feels when you're finally walking on the inside,
*	This is what it looks like,
*	This is how it looks from the outside staring in.
*/

public client_help(id)
{
	help_add("Information","This plugin provides an intelligent random based on individual player stats.")
	help_add("Usage","Random Teams can be temporarily enabled if enough players type /voterandom, /random, /votebalance, or /balance in chat.")
}

public client_advertise(id)
{
	return PLUGIN_CONTINUE;
}

/* assignment methods
	pug method
	assign in pairs: best and worst to team 1, next best and next worst to team 2
	
	complex:
	Mwin = (P1 * P2 * P3 * P4) / ((P1 * P2 * P3 * P4) + ((1-P1)*(1-P2)*(1-P3)*(1-P4))
	take player furthest from 0.5
	newMwin = (Mwin * Pnext) / ((Mwin * Pnext) + ((1-Mwin)*(1-Pnext))
	if Pnext gives you a result closer to 0.5 than (1-Pnext) does, you put him on rines
*/
