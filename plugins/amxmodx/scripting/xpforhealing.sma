/*
* Plugin: XP 4 Healing
* By: Nut (toazron1@gmail.com)
* 
* Description: Awards exp for healing/welding players/structures
* 
* Change Log:
* 	v0.1 - Inital coding
* 	v0.2 - Switch to playbackevent hooking
*/

#include <amxmodx>
#include <ns>
#include <fakemeta>

//helper support
#define HELPER 1

#if HELPER == 1
#include <helper>
#endif

#define PLUGIN	"XP4Healing"
#define AUTHOR	"Nut"
#define VERSION	"0.2"

#pragma semicolon 1

#define HEALSPRAYDISTANCE	190.0
#define WELDERDISTANCE		86.0
#define HEALSPRAYPERSEC		3.0
#define WELDPERSEC			1.0

#define ALIEN_PLAYER_MIN	10.0
#define ALIEN_PLAYER_MAX	12.5
#define ALIEN_STRUC_MIN		5.0
#define ALIEN_STRUC_MAX		7.0

#define MARINE_PLAYER_MIN	7.0
#define MARINE_PLAYER_MAX	9.0
#define MARINE_STRUC_MIN	2.5
#define MARINE_STRUC_MAX	5.0

enum
{
	EVENT_HEALSPRAY = 16,
	EVENT_WELDER_EFFECT = 32,
	EVENT_WELDER_CONST,
	EVENT_WELDER_START,
	EVENT_WELDER_END		//35 fired one when done and two times when switching from welder lol.
}

new bool:g_IsWelding[33];
new bool:g_IsHealing[33];
new bool:g_IsStruc[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_cvar(PLUGIN, VERSION, FCVAR_SERVER);
	
	if (!ns_is_combat())
		pause("ad");

	register_forward(FM_PlaybackEvent, "HookPlaybackEvent");
}

#if HELPER == 1
public client_help(id)
	help_add("Information", "This plugin gives players experience for healing / welding players and structures.");

public client_advertise(id)	return PLUGIN_CONTINUE;
#endif

public client_connect(id)
{
	g_IsHealing[id] = false;
	g_IsWelding[id] = false;
}

public HookPlaybackEvent(iFlags, eEnt, iEvent, Float:fDelay, Float:fOrigin[3], Float:fAngles[3], Float:fparam1, Float:fparam2, iparam1, iparam2, bparam1, bparam2)
{
	switch(iEvent)
	{
		case EVENT_HEALSPRAY:
		{
			new ent, bodyPart, Float:distance;
			get_user_aiming(eEnt, ent, bodyPart);
			
			if (!pev_valid(eEnt) || ent <= 0)
				return FMRES_IGNORED;
			
			if (distance > HEALSPRAYDISTANCE)
				return FMRES_IGNORED;

			new Float:fHealth, Float:fHealthMax;
			pev(ent, pev_health, fHealth);
			pev(ent, pev_max_health, fHealthMax);
			
			if (fHealth < fHealthMax)
				if (ent < 33)	//player
					ns_set_exp(eEnt, ns_get_exp(eEnt) + random_float(ALIEN_PLAYER_MIN, ALIEN_PLAYER_MAX));
				else
					ns_set_exp(eEnt, ns_get_exp(eEnt) + random_float(ALIEN_STRUC_MIN, ALIEN_STRUC_MAX));
		}
		case EVENT_WELDER_CONST:
		{
			if (!g_IsWelding[eEnt])
			{
				new ent, bodyPart;
				get_user_aiming(eEnt, ent, bodyPart);
				
				if (!pev_valid(eEnt) || ent <= 0)
					return FMRES_IGNORED;

				if (ent < 33)	//player
				{
					new class = ns_get_class(eEnt);
					if (class == CLASS_MARINE || class == CLASS_JETPACK || class == CLASS_HEAVY)
					{
						new Float:fArmor, fArmorMax;
						pev(ent, pev_armorvalue, fArmorMax);
						fArmorMax = get_max_armor(eEnt);
						
						g_IsStruc[eEnt] = false;
						
						if (fArmor < float(fArmorMax))
							g_IsWelding[eEnt] = true;
					}
				}
				else		//structure
				{
					new Float:fHealth, Float:fHealthMax;
					pev(ent, pev_health, fHealth);
					pev(ent, pev_max_health, fHealthMax);
					
					g_IsStruc[eEnt] = true;
					
					if (fHealth <= fHealthMax)
						g_IsWelding[eEnt] = true;
				}
			}
			else
				g_IsWelding[eEnt] = false;
		}
		case EVENT_WELDER_EFFECT:
			if (g_IsWelding[eEnt])
				if (g_IsStruc[eEnt])
					ns_set_exp(eEnt, ns_get_exp(eEnt) + random_float(MARINE_STRUC_MIN , MARINE_STRUC_MAX));
				else
					ns_set_exp(eEnt, ns_get_exp(eEnt) + random_float(MARINE_PLAYER_MIN , MARINE_PLAYER_MAX));
	}
	return FMRES_IGNORED;
}

stock get_max_armor(id)
{
	if (ns_get_mask(id, MASK_ARMOR1))
		return 50;
	if (ns_get_mask(id, MASK_ARMOR2))
		return 70;
	if (ns_get_mask(id, MASK_ARMOR3))
		return 90;
	return 30;
}
