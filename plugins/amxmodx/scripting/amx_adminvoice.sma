///////////////////////////////////////////////////////////////////////////////////////
//
//	AMX Mod (X)
//
//	Developed by:
//	The Amxmodx DoD Community
//	|BW|.Zor Editor (zor@blackwatchclan.net)
//	http://www.dodplugins.net
//
//	This program is free software; you can redistribute it and/or modify it
//	under the terms of the GNU General Public License as published by the
//	Free Software Foundation; either version 2 of the License, or (at
//	your option) any later version.
//
//	This program is distributed in the hope that it will be useful, but
//	WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//	General Public License for more details.
//
//	You should have received a copy of the GNU General Public License
//	along with this program; if not, write to the Free Software Foundation,
//	Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
//
//	In addition, as a special exception, the author gives permission to
//	link the code of this program with the Half-Life Game Engine ("HL
//	Engine") and Modified Game Libraries ("MODs") developed by Valve,
//	L.L.C ("Valve"). You must obey the GNU General Public License in all
//	respects for all of the code used other than the HL Engine and MODs
//	from Valve. If you modify this file, you may extend this exception
//	to your version of the file, but you are not obligated to do so. If
//	you do not wish to do so, delete this exception statement from your
//	version.
//
//	Name:		Admin Voice Comms
//	Author:		Zor
//	Description:	This plugin will manage bots on a server
//	Reference:	http://www.dodplugins.net/viewtopic.php?p=6002
//	Reference:	http://www.amxmodx.org/forums/viewtopic.php?p=212891
//
//	v0.1 	- Be!
//	v0.2	- Added admin to admin chat...thanks to Hell Phoenix for the idea!
//
///////////////////////////////////////////////////////////////////////////////////////

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fun>

///////////////////////////////////////////////////////////////////////////////////////
// Version Control
//
new AUTH[] = "AMXX DoD Community"
new PLUGIN_NAME[] = "Admin Voice Comms"
new VERSION[] = "0.2"
//
///////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////
// Globals
//
new g_listen_on[33] = { 0, ... }
//
///////////////////////////////////////////////////////////////////////////////////////

public plugin_init()
{
	// Register this plugin
	register_plugin(PLUGIN_NAME, VERSION, AUTH)

	// Register Client Commands
	
	// Admin can overide all others voice to give message
	register_clcmd("+adminvoice", "cmd_voice_on", ADMIN_LEVEL_H, "Starts Admin Voice")
	register_clcmd("-adminvoice", "cmd_voice_off", ADMIN_LEVEL_H, "Stops Admin Voice")
	
	// Admin to Admin Communication Only
	register_clcmd("+interadminvoice", "cmd_inter_voice_on", ADMIN_LEVEL_B, "Starts Admin to Admin Voice")
	register_clcmd("-interadminvoice", "cmd_inter_voice_off", ADMIN_LEVEL_B, "Stops Admin to Admin Voice")
	
	// Listen for Peoples Voice
	register_clcmd("+adminlisten", "cmd_listen_on", ADMIN_LEVEL_B, "Admin Listen On")
	register_clcmd("-adminlisten", "cmd_listen_off", ADMIN_LEVEL_B, "Admin Listen Off")
	
	// Toggle a Listening to other peoples Voice
	register_clcmd("toggle_listen", "toggle_cmd_listen", ADMIN_LEVEL_B, "Toggle Admin Listen On/Off")
}

public cmd_voice_on(id)
{
	if(!(get_user_flags(id) & ADMIN_LEVEL_H))
		return PLUGIN_HANDLED
		
	new players[32], count
	get_players(players, count, "c")

	for(new i = 0; i < count; i++)
	{
		set_speak(players[i], SPEAK_MUTED)
	}
	
	set_speak(id, SPEAK_ALL)
	client_cmd(id, "+voicerecord")
	
	client_print(id, print_chat, "[Admin Voice] Speaking On")
		
	return PLUGIN_CONTINUE
}

public cmd_voice_off(id)
{
	client_cmd(id, "-voicerecord")
	
	new players[32], count
	get_players(players, count, "c")

	for(new i = 0; i < count; i++)
	{
		set_speak(players[i], SPEAK_NORMAL)
	}
	
	client_print(id, print_chat, "[Admin Voice] Speaking Off")
	
	return PLUGIN_CONTINUE
}

public cmd_inter_voice_on(id)
{
	if(!(get_user_flags(id) & ADMIN_LEVEL_H))
		return PLUGIN_HANDLED
		
	new players[32], count
	get_players(players, count, "c")

	for(new i = 0; i < count; i++)
	{
		if(get_user_flags(players[i]) & ADMIN_LEVEL_H)
			set_client_listen(players[i], id, 1)
			
		else
			set_client_listen(players[i], id, 0)
	}
		
	client_cmd(id, "+voicerecord")
	
	client_print(id, print_chat, "[Admin to Admin Voice] Speaking On")
		
	return PLUGIN_CONTINUE
}

public cmd_inter_voice_off(id)
{
	client_cmd(id, "-voicerecord")
	
	new players[32], count
	get_players(players, count, "c")

	for(new i = 0; i < count; i++)
	{
		set_speak(players[i], SPEAK_NORMAL)
	}
	
	client_print(id, print_chat, "[Admin to Admin Voice] Speaking Off")
	
	return PLUGIN_CONTINUE
}

public cmd_listen_on(id)
{
	if(!(get_user_flags(id) & ADMIN_LEVEL_H))
		return PLUGIN_HANDLED
		
	set_speak(id, SPEAK_LISTENALL)
	client_print(id, print_chat, "[Admin Voice] Listening On")
	
	return PLUGIN_CONTINUE
}

public cmd_listen_off(id)
{
	if(!(get_user_flags(id) & ADMIN_LEVEL_H))
		return PLUGIN_HANDLED

	if(is_user_connected(id))
	{
		set_speak(id, SPEAK_NORMAL)
		client_print(id, print_chat, "[Admin Voice] Listening Off")
	}
	
	return PLUGIN_CONTINUE
}

public toggle_cmd_listen(id)
{
	if(!(get_user_flags(id) & ADMIN_LEVEL_H))
		return PLUGIN_HANDLED
	
	g_listen_on[id] = 1 - g_listen_on[id]
	(g_listen_on[id]) ? cmd_listen_on(id) : cmd_listen_off(id)
	
	return PLUGIN_CONTINUE
}
