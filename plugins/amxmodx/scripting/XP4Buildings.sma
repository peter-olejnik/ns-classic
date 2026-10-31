/*
* Plugin: XP4Buildings
* By: Nut (toazron1@gmail.com)
* May 20, 2009
* 
* Description:
* 	Awards experience to a player and his teammates for killing structures
* 
* Change Log:
* 
* 	v0.1 - Inital coding
* 	v0.2 - Code cleanup, bug fixes
* 	v0.3 - Using deli for now.. switched to HAM_TAKEDAMAGE
* 	v0.4 - Fixed xp calculation. The xp gained is % of dmg done not current level exp ><
* 	v0.5 - Helper support.  Seperate defines for marines and alien xp
* 	v0.6 - Removed deli/ Fixed 2x firing for armory.  Simplified code.
* 	v0.6a - Fixed <= 33 - Thanks Darkness.
*/

#include <amxmodx>
#include <ns>
#include <fakemeta>
#include <hamsandwich>

#define HELPER 1

#if HELPER == 1
#include <helper>
#endif

#pragma semicolon 1

#define PLUGIN		"XP4Buildings"
#define VERSION		"0.6"
#define AUTHOR		"Nut"

//	Percent of damage done to add (lvl 1 skulk gets ~4% on CC per 
//	bite / lvl 1 marine lmg gets ~.8% per bullet);
#define MARINE_XP_DMG_PERCENT		0.06			
#define ALIEN_XP_DMG_PERCENT		0.05			

#define MAX_STRUC 10
new const strucs[MAX_STRUC][] = 
{
	"sensorychamber",
	"movementchamber",
	"defensechamber",
	"offensechamber",
	"team_observatory",
	"team_armory",
	"turret",
	"siegeturret",
	"team_turretfactory",
	"phasegate"
};

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_cvar(PLUGIN, VERSION, FCVAR_SERVER);
	
	if (!ns_is_combat())
		pause("ad");

	for(new i = 0; i < MAX_STRUC; i++)
		RegisterHam(Ham_TakeDamage, strucs[i], "HamHook_TakeDamage");
}

#if HELPER == 1
public client_help(id)
{
	help_add("Information","This plugin awards some exp for the damage you do to enemy structures.");
	help_add("Usage","Point at an enemy structure and attack it.");
}

public client_advertise(id) return PLUGIN_CONTINUE;
#endif

public HamHook_TakeDamage(eEnt, inflictor, eAttacker, Float:fDamage, dmgbits)
{
	if (!eAttacker) return HAM_IGNORED;
	if (eAttacker < 33)
	{
		if (pev(eEnt, pev_team) == pev(eAttacker, pev_team)) return HAM_IGNORED;

		new Float:fXp, team = pev(eAttacker, pev_team);
		if (team == 1 || team == 3)
			fXp = fDamage * MARINE_XP_DMG_PERCENT;
		else
			fXp = fDamage * ALIEN_XP_DMG_PERCENT;
		
		ns_set_exp(eAttacker, ns_get_exp(eAttacker) + fXp);
	}
	return HAM_IGNORED;
}
