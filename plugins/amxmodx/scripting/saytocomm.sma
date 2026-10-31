/*
* AMX mod X plugin "Say to Commander 1.0" for "Natural-Selection 3.2"
* by Mev-Rael (Tyrael@inbox.lv ; Tyrael_Greefien @ skype; Mevrael @ steam)
*
* 13.06.2010
*
* http://ns.boxg.lv - Baltic Natural-Selection Community
*
* This plugin allows marines to send HUD messages for commander.
*/

#include <amxmodx>
#include <ns>
#include <nsteam>

// Commander index
new comid = 0

public plugin_init()
{
	if (ns_is_combat())
	{
		register_plugin("Say to Commander (OFF)", "1.0", "Mev-Rael")
		pause("ade")
	}
	else
	{
		register_plugin("Say to Commander", "1.0", "Mev-Rael")
		register_clcmd("say_team", "say_to_comm")
	}
	return PLUGIN_HANDLED
}

public client_changeclass(id, newclass, oldclass)
{
	if (newclass == CLASS_COMMANDER)
	{
		comid = id
	}
	else if (oldclass == CLASS_COMMANDER)
	{
		comid = 0
	}
	return PLUGIN_HANDLED
}

public client_changeteam(id, newteam, oldteam)
{
	if (newteam == 1)
	{
		client_print(id, print_chat, "[Say to Commander] You can send a HUD message to commander. Use say_team !msg")
	}
}

public say_to_comm(id)
{
	if (nst_is_marine(id))
	{
		new symbol[3]
		read_args(symbol, 2)
		if (equal(symbol[1], "!"))
		{
			if (comid == 0)
			{
				client_print(id, print_chat, "WARNING! There is no commander at this time!")
				return PLUGIN_HANDLED
			}
			new name[32], marines[33], message[64], i
			read_args(message, 63)
			replace(message[0], 63, "^"", "")
			replace(message[0], 63, "!", "")
			replace(message[strlen(message)-1], 63, "^"", "")
			get_user_name(id, name, 31)
			marines = nst_get_marine()
			set_hudmessage(100, 240, 100, 0.1, 0.2, 0, 4.0, 8.0)
			show_hudmessage(comid, "COMMANDER! %s (%s)", message, name)
			for (i=1; i<=marines[0]; i++)
			{
				if (marines[i] != comid)
				{
					client_print(marines[i], print_chat, "(To commander) %s: %s", name, message)
				}
				else
				{
					client_print(marines[i], print_chat, "COMMANDER! %s (%s)", message, name)
				}
			}
			return PLUGIN_HANDLED
		}
	}
	return PLUGIN_CONTINUE
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
