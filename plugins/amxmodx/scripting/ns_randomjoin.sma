/**
* INFO: This plugin may only work for
* 	Natural-Selection(.org) servers!
*
* This plugin is a rip of the version we
* use on The Alien Breeder Natural-Selection
* Server. You can see the plugin in action
* at 213.202.211.193 : 27015.
* 
* This plugin will force all players to join
* a random team to prevent team stacking. Only
* admins can join and select a team manualy.
* 
* Same for the spectaror mode, only admins can
* spectate!
*/

#include <amxmodx>
#include <amxmisc>
#include <engine>

public plugin_init()
{
	// plugin name, version and author
	register_plugin("<TAB> Random Join","1.0","Unsichtbar")
	register_cvar("<TAB> Random Join", "1.0", FCVAR_SERVER)
	
	// lock spectate, team join entity/zone and impulse command
	register_touch("info_spectate", "player", "spectateN1")
	register_touch("info_join_team", "player", "spectateN2")
	register_concmd("spectate","spectateNN")
	register_concmd("readyroom","spectateNN")
	register_concmd("jointeamone","jointeamN")
	register_concmd("jointeamtwo","jointeamN")
	register_impulse(5, "spectateNN")
}

public spectateN1(id, player)
{
	if(!access(player,ADMIN_KICK))
	{
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public spectateN2(id, player)
{
	if(!access(player,ADMIN_KICK))
	{
		client_cmd(player, "autoassign")
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public spectateNN(id)
{
	if(!access(id,ADMIN_KICK))
	{
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public jointeamN(id)
{
	if(!access(id,ADMIN_KICK))
	{
		client_cmd(id, "autoassign")
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}