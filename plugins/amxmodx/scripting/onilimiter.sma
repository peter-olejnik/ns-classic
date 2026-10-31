/*  onilimiter.sma 
 * Version 1.3   
 *	Limits the amount of onos in AvA.
 *
 *  Most of the base code was used from classctrl.sma by Darkns
 *  Hacked into working order for AvA by TinCan for the NS<BAD>Clan 
 */

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <ns>

#define CHECK_DELAY 0.5

#define IMPULSE_ONOS 117

#define IMPULSE_CARAPACE 101   
#define IMPULSE_REGENERATION 102
#define IMPULSE_REDEMPTION 103
#define IMPULSE_CELERITY 107
#define IMPULSE_ADRENALINE 108
#define IMPULSE_SILENCE 109
#define IMPULSE_CLOAKING 110
#define IMPULSE_SCENT 112

new g_IsMadeAvA = 0
new g_maxplrs, g_oni[5] //Note: TinCan set this array to 5 because pev_team reports teams 2 or 4 for AvAliens

public plugin_init()
{
	new sInfo[8] //Place holder for localinfo
	get_localinfo("is_made_ava", sInfo, 7) //Check if AvA is active (shows as 1 in sinfo)
	g_IsMadeAvA = str_to_num(sInfo) // 1.1 convert sInfo into a number
	if( g_IsMadeAvA )	//Here is where it looks to see if ava is enabled and set ava to 1 if it is...
	{
		register_plugin("AvA Oni Limiter (on)", "1.3", "TinCan")
		register_cvar("ava_maxoni", "1")
		register_impulse(IMPULSE_ONOS,"onoshook")
		
		register_impulse(IMPULSE_CARAPACE, "carapacehook")
		register_impulse(IMPULSE_REGENERATION, "regenerationhook")
		register_impulse(IMPULSE_REDEMPTION, "redemptionhook")
		register_impulse(IMPULSE_CELERITY, "celerityhook")
		register_impulse(IMPULSE_ADRENALINE, "adrenalinehook")
		register_impulse(IMPULSE_SILENCE, "silencehook")
		register_impulse(IMPULSE_CLOAKING, "cloakinghook")
		register_impulse(IMPULSE_SCENT, "scenthook")
				
		g_maxplrs = get_maxplayers()
	}
	else
		register_plugin("AvA Oni Limiter (off)", "1.3", "TinCan")
	return
}



public onoshook(id)
{
	if (is_user_bot(id))
		return PLUGIN_CONTINUE
	new count
	for(new i = 1; i <= g_maxplrs; i++)
	{
	if ( is_user_connected(i) )
		{
		if ((ns_get_class(i) == CLASS_ONOS) && (pev(id, pev_team) == pev(i, pev_team)))
			count++
		}
	}
	count += g_oni[pev(id, pev_team)]
	if (count >= get_cvar_num("ava_maxoni"))
	{
		ns_popup(id, "Your team already has enough oni")
		return PLUGIN_HANDLED
	}
	else
	{
		g_oni[pev(id, pev_team)]++
		new parm[1]
		parm[0] = id
		set_task(CHECK_DELAY, "checkonos",_,parm,1)
	}
	return PLUGIN_CONTINUE
}

public carapacehook(id)
{
	if (is_user_bot(id))
		return PLUGIN_CONTINUE
	if (ns_get_class(id) == CLASS_ONOS)
	{
		g_oni[pev(id, pev_team)]++
		new parm[1]
		parm[0] = id
		set_task(CHECK_DELAY, "checkonos",_,parm,1)
	}
	return PLUGIN_CONTINUE
}

public regenerationhook(id)
{
	if (is_user_bot(id))
		return PLUGIN_CONTINUE
	if (ns_get_class(id) == CLASS_ONOS)
	{
		g_oni[pev(id, pev_team)]++
		new parm[1]
		parm[0] = id
		set_task(CHECK_DELAY, "checkonos",_,parm,1)
	}
	return PLUGIN_CONTINUE
}

public redemptionhook(id)
{
	if (is_user_bot(id))
		return PLUGIN_CONTINUE
	if (ns_get_class(id) == CLASS_ONOS)
	{
		g_oni[pev(id, pev_team)]++
		new parm[1]
		parm[0] = id
		set_task(CHECK_DELAY, "checkonos",_,parm,1)
	}
	return PLUGIN_CONTINUE
}

public celerityhook(id)
{
	if (is_user_bot(id))
		return PLUGIN_CONTINUE
	if (ns_get_class(id) == CLASS_ONOS)
	{
		g_oni[pev(id, pev_team)]++
		new parm[1]
		parm[0] = id
		set_task(CHECK_DELAY, "checkonos",_,parm,1)
	}
	return PLUGIN_CONTINUE
}

public adrenalinehook(id)
{
	if (is_user_bot(id))
		return PLUGIN_CONTINUE
	if (ns_get_class(id) == CLASS_ONOS)
	{
		g_oni[pev(id, pev_team)]++
		new parm[1]
		parm[0] = id
		set_task(CHECK_DELAY, "checkonos",_,parm,1)
	}
	return PLUGIN_CONTINUE
}

public silencehook(id)
{
	if (is_user_bot(id))
		return PLUGIN_CONTINUE
	if (ns_get_class(id) == CLASS_ONOS)
	{
		g_oni[pev(id, pev_team)]++
		new parm[1]
		parm[0] = id
		set_task(CHECK_DELAY, "checkonos",_,parm,1)
	}
	return PLUGIN_CONTINUE
}

public cloakinghook(id)
{
	if (is_user_bot(id))
		return PLUGIN_CONTINUE
	if (ns_get_class(id) == CLASS_ONOS)
	{
		g_oni[pev(id, pev_team)]++
		new parm[1]
		parm[0] = id
		set_task(CHECK_DELAY, "checkonos",_,parm,1)
	}
	return PLUGIN_CONTINUE
}

public scenthook(id)
{
	if (is_user_bot(id))
		return PLUGIN_CONTINUE
	if (ns_get_class(id) == CLASS_ONOS)
	{
		g_oni[pev(id, pev_team)]++
		new parm[1]
		parm[0] = id
		set_task(CHECK_DELAY, "checkonos",_,parm,1)
	}
	return PLUGIN_CONTINUE
}

public checkonos(parm[1])
{
	new id = parm[0]
	if (ns_get_class(id) == CLASS_GESTATE)
		set_task(CHECK_DELAY, "checkonos",_,parm,1)
	else
		g_oni[pev(id, pev_team)]--
}
