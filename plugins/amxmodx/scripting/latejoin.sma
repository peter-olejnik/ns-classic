#include <amxmodx>
#include <engine>
#include <ns>

#define XPSYS_NONE		1
#define XPSYS_LEVELCONTROL	2
#define XPSYS_EXTRALEVELS3	3

//-------------------------------------------------------------------------------------------------
///////////////////	DO NOT MESS WITH ANYTHING ABOVE THIS LINE!
//-------------------------------------------------------------------------------------------------

/*
	IMPORTANT:
	The next line defines what extra level system the plugin should work with.
		For Extralevels3: use XPSYS_EXTRALEVELS3
		For LevelControl: use XPSYS_LEVELCONTROL
	If you are not running an extra level system, use XPSYS_NONE
*/
#define USE_XP_SYSTEM 	XPSYS_EXTRALEVELS3

//-------------------------------------------------------------------------------------------------
///////////////////	DO NOT MESS WITH ANYTHING BELOW THIS LINE!
//-------------------------------------------------------------------------------------------------

#if USE_XP_SYSTEM == XPSYS_LEVELCONTROL
#include <lvlctrl>
#endif

#define VERSION			"2.04"
//mode stuff
#define TEAM_OTHER		0
#define TEAM_MARINE		1
#define TEAM_ALIEN		2

#if USE_XP_SYSTEM == XPSYS_LEVELCONTROL
#define FUNC_get_maxlevel(%1) x_get_maxlevel(%1)
#else
#define FUNC_get_maxlevel(%1) x_get_maxlevel()
#endif

new g_bActive
new g_iMaxPlayers
new g_pcvarAverageBoth, g_pcvarMax_Marine, g_pcvarMax_Alien, g_pcvarMultiplier

#if USE_XP_SYSTEM == XPSYS_EXTRALEVELS3
new g_pcvarMaxLevel
#endif

public plugin_init()
{
	register_cvar("v_latejoin", VERSION, FCVAR_SERVER)
	
	g_pcvarAverageBoth = register_cvar("lg_averageboth", "0")
	g_pcvarMax_Marine = register_cvar("lg_max_marine", "5")
	g_pcvarMax_Alien = register_cvar("lg_max_alien", "5")
	g_pcvarMultiplier = register_cvar("lg_multiplier", "0.75")
	
#if USE_XP_SYSTEM == XPSYS_EXTRALEVELS3
	if (!cvar_exists("amx_maxlevel"))
		register_cvar("amx_maxlevel", "50")
	
	g_pcvarMaxLevel = get_cvar_pointer("amx_maxlevel")
#endif
	
	g_bActive = false
	
	if (!ns_is_combat())
	{
		register_plugin("LateJoin(OFF)", VERSION, "Darkns")
	}
	else
	{
		register_plugin("LateJoin(ON)", VERSION, "Darkns")
		
		register_message(get_user_msgid("ResetHUD"),"hook_ResetHUD")
		g_iMaxPlayers = get_maxplayers()
		
		g_bActive = true
	}
}

public hook_ResetHUD(iMsgId, iDest, eTarget)
{
	if (g_bActive)
		if (is_user_alive(eTarget))
			if (get_team(eTarget))
				if (!is_user_bot(eTarget))
					CheckLateXP(eTarget)
}

CheckLateXP(ePlayer)
{
	new iTeam = get_team(ePlayer)
	new iLateGiveMax = 0
	new iTeamType = get_team_teamtype(iTeam)
	if (iTeamType == TEAM_MARINE)
		iLateGiveMax = get_pcvar_num(g_pcvarMax_Marine)
	else if (iTeamType == TEAM_ALIEN)
		iLateGiveMax = get_pcvar_num(g_pcvarMax_Alien)
	
	if (iLateGiveMax > 0)
	{
		new iTeamMaxLevel = FUNC_get_maxlevel(iTeamType)
		if (iLateGiveMax > iTeamMaxLevel)
			iLateGiveMax = iTeamMaxLevel
		
		new iPlayerCount = 0
		new iPlayerLevels = 0
		new bAverageBoth = get_pcvar_num(g_pcvarAverageBoth)
		for (new eOther = 1; eOther <= g_iMaxPlayers; eOther++)
		{
			if (eOther != ePlayer)
			{
				if (is_user_connected(eOther))
				{
					if ( (get_team(eOther) == iTeam) || bAverageBoth)
					{
						iPlayerCount++
						iPlayerLevels += x_get_level(eOther)
					}
				}
			}
		}
		
		if (iPlayerCount)
		{
			new iAveragePlayerLevels = floor((float(iPlayerLevels) / float(iPlayerCount)) * get_pcvar_float(g_pcvarMultiplier))
			
			new iCurLevel = x_get_level(ePlayer)
			if (iAveragePlayerLevels > iLateGiveMax)
				iAveragePlayerLevels = iLateGiveMax
			if (iCurLevel < iAveragePlayerLevels)
			{
				x_set_xp(ePlayer, x_min_xp(iAveragePlayerLevels))
				new iLevelBoost = iAveragePlayerLevels - iCurLevel
				client_print(ePlayer, print_chat, " [LateJoin] YOU SUCK! Giving you %i %s pity levels.", iLevelBoost, (iLevelBoost == 1)?"level":"levels")
			}
		}
	}
}

get_team(eEnt)
	return entity_get_int(eEnt, EV_INT_team)	//this is a bit slower than pev(), but now I don't need to include fakemeta

get_team_teamtype(iTeam)	//MvM support...
{
	switch (iTeam)
	{
		case 1:
			return TEAM_MARINE;
		case 2:
			return TEAM_ALIEN;
		case 3:
			return TEAM_MARINE;
		case 4:
			return TEAM_ALIEN;
	}
	return TEAM_OTHER;
}

floor(Float:fNum)
	return floatround(fNum, floatround_floor)

//change these for compatibility wtih extralevels/levelcontrol/or nothing...

FUNC_get_maxlevel(iTeamType)
{
#if USE_XP_SYSTEM == XPSYS_NONE
	return 10
#endif
#if USE_XP_SYSTEM == XPSYS_LEVELCONTROL
	return lvlc_GetMaxLevel(iTeamType)
#endif
#if USE_XP_SYSTEM == XPSYS_EXTRALEVELS3
	return get_pcvar_num(g_pcvarMaxLevel)
#endif
}

x_set_xp(ePlayer, iXP)
{
#if USE_XP_SYSTEM == XPSYS_NONE
	ns_set_exp(ePlayer, float(iXP))
#endif
#if USE_XP_SYSTEM == XPSYS_LEVELCONTROL
	lvlc_SetXP(ePlayer, float(iXP))
#endif
#if USE_XP_SYSTEM == XPSYS_EXTRALEVELS3
	ns_set_exp(ePlayer, float(iXP))
#endif
}

x_get_level(ePlayer)
{
#if USE_XP_SYSTEM == XPSYS_NONE
	new Float:fXP = ns_get_exp(ePlayer)
	if (fXP <= 0.0)		//it can get negetive after a reset, where it kinda borks for a sec, though only if maxlevel is 1...
		return 1	//0xp is really level 0 and 98%, so...
	
	return floor((floatsqroot(fXP + 55.25) - 2.5) / 5.0)
#endif
#if USE_XP_SYSTEM == XPSYS_LEVELCONTROL
	return lvlc_GetLevel(ePlayer)
#endif
#if USE_XP_SYSTEM == XPSYS_EXTRALEVELS3
	new Float:fXP = ns_get_exp(ePlayer)	//same as XPSYS_NONE until the vext version of EL3
	if (fXP <= 0.0)
		return 1
	
	return floor((floatsqroot(fXP + 55.25) - 2.5) / 5.0)
#endif
}

x_min_xp(iLevel)
{
#if USE_XP_SYSTEM == XPSYS_NONE
	return ((25 * iLevel) * (iLevel + 1)) - 49
#endif
#if USE_XP_SYSTEM == XPSYS_LEVELCONTROL
	return floatround(lvlc_MinXP(iLevel))
#endif
#if USE_XP_SYSTEM == XPSYS_EXTRALEVELS3
	return ((25 * iLevel) * (iLevel + 1)) - 49
#endif
}
