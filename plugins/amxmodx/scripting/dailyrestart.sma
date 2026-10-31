#include <amxmodx>

public plugin_init() 
	register_plugin("restart","1.2","watch")


public check_restart()
{
	new currentdate[12], lastrestarted[12]
	get_time("%d/%m/%Y",currentdate,11)

	if (!vaultdata_exists("lastrestarted")) 
		set_vaultdata("lastrestarted",currentdate)

	get_vaultdata("lastrestarted",lastrestarted,11)
	
	if (!equal(currentdate,lastrestarted)) 
	{
		new i,playercount,botcount
		playercount = get_playersnum()

		for(i=1; i<= playercount; i++)
			if(is_user_bot(i) || is_user_hltv(i))
				botcount++
			
		if (playercount == botcount) 
		{
			set_vaultdata("lastrestarted",currentdate)
			log_amx("Restarting: (Last Restart: %s) (Clients: %d) (Bots: %d)",lastrestarted, playercount-botcount, botcount)
			server_cmd("exit") 
			return PLUGIN_HANDLED
		}
	}
	return PLUGIN_CONTINUE
}

public client_disconnect()
{
	set_task(1.0,"check_restart")
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang2057\\ f0\\ fs16 \n\\ par }
*/
