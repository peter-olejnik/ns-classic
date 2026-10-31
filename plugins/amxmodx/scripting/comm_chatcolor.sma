/*
* This Plugin changes the chat color of a commander
* you can set the comms color with the define "comm_color" (default is green)
*
* Credits:
*	-> mayhem	-	some rip of his colorAdminChat
*
* Author:
*	-> White Panther
*
* v1.0c:
*	- initial release
*	- some code improvements (thx mayhem)
*
* v1.1:
*	- changed:
*		- moved from pev/set_pev to entity_get/entity_set (no fakemeta)
*
* v1.2:
*	- added:
*		- when comm uses chat there is now a sound (can be turned of via define)
*	- changed:
*		- minor code improvements
*
* v1.3:
*	- fixed:
*		- message was displayed when containing only spaces or tabs
*	- added:
*		- define to either play a sound when ever comm uses chat or only if message starts with a !
*	- changed:
*		- code improvements
*
* v1.3.2:
*	- fixed:
*		- messages are now logged ( thanks Gimp )
*		- minor code tweaks
*
* v1.3.3:
*	- fixed:
*		- runtime error due to variable exchange (thx John2be)
*
* v1.3.3d:
*	- fixed:
*		- little error with logging ( thx BIGPhil )
*
* v1.3.4:
*	- changed:
*		- minor code tweak
*
* v1.3.4b:
*	- fixed:
*		- message was replaced with playername ( thx AiRbOrN )
*
* v1.3.4c:
*	- fixed:
*		- bug with compiling option "PLAY_SOUND"
*
* v1.3.5:
*	- changed:
*		- NS 3.2 adjustment
*
* v1.3.6:
*	- added:
*		- Helper support
*
* v1.3.7:
*	- changed:
*		- paused in combat mode
*		- removed one helper specific function, unneeded
*		- moved to fakemeta
*
* v1.3.8:
*	- fixed:
*		- corrupted log messages
*/


#include <amxmodx>
#include <fakemeta>
#include <ns>
#include <helper>

#define comm_color		3	// 1 = blue (default by NS) , 2 = yellow (aliens), 3 = green (default by plugin), 4 = red (alien2 or marine2 in MvM)
#define PLAY_SOUND		1	// set to 0 if no sound shall be played when commander uses chat
#define PLAY_SOUND_ALLWAYS	1	// set this to 0 to only play sound when starting message with a !

#if PLAY_SOUND == 1
new sound_file[125] = "hud/tooltip.wav"
#endif

#define PLUGIN_AUTHOR	"White Panther"
#define PLUGIN_VERSION	"1.3.8"

enum
{
	PLAYER = 1,
	SCORE,
	KILLS,
	DEATHS,
	LEVEL,	// in classic: weapon / res
	CLASS,
	AUTH,
	TEAM,
	HEALTH,
	ICON,
	
	SIZE_OF_SCOREBOARD_ENUM
}

new scoredata[33][SIZE_OF_SCOREBOARD_ENUM]
new scoreicon[33][36]

new ScoreInfo_id, SayText_id

new g_maxplayers

public plugin_init( )
{
	register_cvar("commchatcolor_version", PLUGIN_VERSION, FCVAR_SERVER)
	set_cvar_string("commchatcolor_version", PLUGIN_VERSION)
	
	if ( ns_is_combat() )
	{
		register_plugin("Comm Chatcolor(off)", PLUGIN_VERSION, PLUGIN_AUTHOR)
		
		pause("ad")
		
		return
	}
	
	register_plugin("Comm Chatcolor", PLUGIN_VERSION, PLUGIN_AUTHOR)
	ScoreInfo_id = get_user_msgid("ScoreInfo")
	SayText_id = get_user_msgid("SayText")
	register_message(ScoreInfo_id, "scoreinfo")
	register_clcmd("say", "editSayText")
	register_clcmd("say_team", "editSayText2")
	
	g_maxplayers = get_maxplayers()
}

#if PLAY_SOUND == 1
public plugin_precache( )
{
	precache_sound(sound_file)
}
#endif

public scoreinfo( msgid )
{
	new id = get_msg_arg_int(PLAYER)
	scoredata[id][PLAYER] = id
	scoredata[id][SCORE] = get_msg_arg_int(SCORE)
	scoredata[id][KILLS] = get_msg_arg_int(KILLS)
	scoredata[id][DEATHS] = get_msg_arg_int(DEATHS)
	scoredata[id][LEVEL] = get_msg_arg_int(LEVEL)
	scoredata[id][CLASS] = get_msg_arg_int(CLASS)
	scoredata[id][AUTH] = get_msg_arg_int(AUTH)
	scoredata[id][TEAM] = get_msg_arg_int(TEAM)
	scoredata[id][HEALTH] = get_msg_arg_int(HEALTH)
	get_msg_arg_string(ICON, scoreicon[id], 35)
	
	return PLUGIN_CONTINUE	
}

public editSayText( id )
{
	return chat_say(id)
}
	
public editSayText2( id )
{
	return chat_say(id, 1)
}

chat_say( id , teamsay = 0 )
{
	if ( ns_get_class(id) != CLASS_COMMANDER )
		return PLUGIN_CONTINUE
	
	new input_message[192]
	read_args(input_message, 191)
	remove_quotes(input_message)
	
	new found_non_space, play_sound, i
	for ( i = 0; i < strlen(input_message); ++i )
	{
		if ( i == 0 && input_message[0] == '!' )
		{
			play_sound = 1
			continue
		}else if ( input_message[i] != ' ' && input_message[i] != 9 )
		{	// NOT space and NOT tab ( ascii = 9 ) and first char being ignored if is " ! "
			found_non_space = 1
			break
		}
	}
	
	if ( !found_non_space )
		return PLUGIN_HANDLED
	
	new name[32], comm_team = pev(id, pev_team)
	get_user_name(id, name, 31)
	new message[192]
	formatex(message, 191, "%c%s%s: %s", 2, teamsay ? "(TEAM) " : "", name, input_message)	// %c = 2 means "Start of Text"
	
	for ( i = 1; i <= g_maxplayers; ++i )
	{
		if ( is_user_connected(i) )
		{
			new team_player = pev(i, pev_team)
			if ( comm_team == team_player )
			{
				message_begin(MSG_ONE, ScoreInfo_id, {0,0,0}, i)
				write_byte(scoredata[id][PLAYER])
				write_short(scoredata[id][SCORE])
				write_short(scoredata[id][KILLS])
				write_short(scoredata[id][DEATHS])
				write_short(scoredata[id][LEVEL])
				write_byte(scoredata[id][CLASS])
				write_short(scoredata[id][AUTH])
				write_short(comm_color)
				write_short(scoredata[id][HEALTH])
				write_string(scoreicon[id])
				message_end()
				
				message_begin(MSG_ONE, SayText_id, {0,0,0}, i)
				write_byte(id)
				write_string(message)
				message_end()
				
				message_begin(MSG_ONE, ScoreInfo_id, {0,0,0}, i)
				write_byte(scoredata[id][PLAYER])
				write_short(scoredata[id][SCORE])
				write_short(scoredata[id][KILLS])
				write_short(scoredata[id][DEATHS])
				write_short(scoredata[id][LEVEL])
				write_byte(scoredata[id][CLASS])
				write_short(scoredata[id][AUTH])
				write_short(scoredata[id][TEAM])
				write_short(scoredata[id][HEALTH])
				write_string(scoreicon[id])
				message_end()
				
#if PLAY_SOUND == 1
				if ( PLAY_SOUND_ALLWAYS > 0 || play_sound )
				{
					if ( id != i )
						client_cmd(i, "spk ^"%s^"", sound_file)
				}
#endif
			}else if ( !teamsay && 1 <= team_player <= 4 )
			{
				message_begin(MSG_ONE, SayText_id, {0,0,0}, i)
				write_byte(id)
				write_string(message)
				message_end()
			}
		}
	}
	
	new authid[35], team_name[33]
	get_user_authid(id, authid, 34)
	get_user_team(id, team_name, 32)
	log_message("^"%s<%d><%s><%s>^" say%s ^"%s^"", name, get_user_userid(id), authid, team_name, teamsay ? "_team" : "", input_message)
	
	return PLUGIN_HANDLED
}

//////////////////// These functions are called by other plugins to get/set variables ////////////////////

public client_help( id )
{
	help_add("Information", "Commander's chat color gets different color than normal chat or team chat.^nColor change only visible for teammates.")
}
