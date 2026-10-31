#include <amxmodx>

#define max_player_cutoff 11

new allow_bots_flag

public plugin_init()
{
	register_plugin("WhichBot Control", "1.0", "TinCan")
	register_clcmd("say","bot_access_check")
}

public client_connect(id)
{
	
	if ( get_cvar_num("mp_limitteams")== 0 )
		return PLUGIN_HANDLED
	
	
	
	if (is_user_bot(id) == 1 && allow_bots_flag == 0)
	{
		new name[32] //Ignore RC bots
		get_user_name( id, name, 31 )
		if(containi(name , "[RC]") != -1)  
		{
			return PLUGIN_HANDLED
		}

		new players = get_playersnum( )  //Check the player count on server	
		if ( players >= max_player_cutoff )
		{
				server_cmd("wb remove") 
		}
	}
	else
	{
		if (is_user_bot(id)) //reset clan access flag 
		{
			allow_bots_flag = 0
		}
	}
	return PLUGIN_CONTINUE
}

public bot_access_check(id)
{
	if ( get_cvar_num("mp_limitteams")== 0 )
		return PLUGIN_HANDLED
	
	
	new check_text[31] // Check for WB add comand
	read_args(check_text, 30)
	remove_quotes(check_text)
	if ( equali(check_text, "/wb add", 7) )
	{
		if ((get_user_flags(id) & ADMIN_CHAT)) //Set flag to let Clan members add bots
		{
			allow_bots_flag = 1
		}
		else
		{
			new players = get_playersnum( ) 
			if ( players >= max_player_cutoff )//Check the player count on server
			{
				client_print(id, print_chat, "* You cannot add anymore WhichBots. [ %i slots are taken ]", max_player_cutoff)
			}
		
		}
	}
	return PLUGIN_CONTINUE
}
