/* AMXX  

RCBOT helper
-Prevents bots from being added in first 15 seconds of map
-Removes all RCBOTs at round end


* * */ 

#include <amxmodx>
#include <amxmisc> 

new rcbot_count
	
public plugin_init()
{ 
	register_plugin( "ns RCBOT Helper", "1.0", "TinCan" )
}

/*
public client_connect(id) 
{
	if (get_gametime ( )  <  60 )
	{
	if (is_user_bot ( id ) == 1 )
	{
		new name[5] 
		get_user_name(id, name, 4)
		if (equali(name,"[RC]"))
		{
			rcbot_count++
			set_task(Float:0.5, "remove_bot")
		}
	}
	}
}
*/			
public  round_end ()
{
	rcbot_count = 0	
	for( new id = 1; id < get_maxplayers(); id++ ) 
		if (is_user_bot ( id ) == 1 )
		{
			new name[5] 
			get_user_name(id, name, 4)
			if (equali(name,"[RC]"))
			{
				rcbot_count++
			}
		}
	set_task(Float:0.5, "remove_bot")
}

public remove_bot()
{
	if (rcbot_count > 0)
	{
		server_cmd("rcbot removebot")	
		rcbot_count --
		set_task(Float:0.5, "remove_bot")
	}
}
