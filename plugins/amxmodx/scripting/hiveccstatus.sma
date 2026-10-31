/*
	Hive/CC Status
	Port/Mod of: Hive/CC Health Constant Display
	Current Version: v3.2
	Platform: AMX-X
	Test Machines: Win32
	Author: Darkns
	Credit: Cheesy Peteza (for the original plugin)
	
	
	Please note that this plugin requires the following modules to be enabled:
	    * Engine
	    * FakeMeta
	    * NS
	
	CVARS:
	    * hc_sound: Enable/Disable CC low-health sound. (1 is on, 0 is off)
	    * hc_extrateamcolors: Enable/Disable different colors for Marine2 and Alien2 teams. (1 is on, 0 is off)
	    * hc_mvm_usered: Use red as the color for the second MvM team(1 is on, 0 is off)
	    * hc_ns: Enable this plugin on Classic maps (ns_*)
	    * hc_co: Enable this plugin on Combat maps (co_*)
	    * hc_updatedelay: How often to refresh the status display (in seconds)
	
	Features:
	    * Provides a constant display of CC, Hive, and Armory healths (in percent).
	    * Supports all game modes (MvA, MvM, AvM, AvA)
	    * HUD text is gamma-corrected, so it should never be too bright or too dark.
*/

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <ns>

#define VERSION			"3.2"

#define	TRUE			1
#define	FALSE			0

//HUD
#define HUD_CHANNEL		2			//what the most recent iteration was using...


#define DIEING_RED		1.00	//255
#define DIEING_GREEN		0.00	//0
#define DIEING_BLUE		0.00	//0

#define MARINE_RED		0.00	//0
#define MARINE_GREEN		0.60	//154
#define MARINE_BLUE		1.00	//255

#define MARINE2_RED		0.57	//145
#define MARINE2_GREEN		0.84	//215
#define MARINE2_BLUE		0.55	//140


#define ALIEN_RED		1.00	//255
#define ALIEN_GREEN		0.62	//160
#define ALIEN_BLUE		0.00	//0

#define ALIEN2_RED		0.78	//200
#define ALIEN2_GREEN		0.35	//90
#define ALIEN2_BLUE		0.27	//70


#define Y_MARINE_ALIVE		0.92
#define Y_MARINE_DEAD		0.85
#define Y_COMMANDER		0.87
#define Y_ALIEN_ALIVE		0.95
#define Y_ALIEN_DEAD		0.90

#define X_MARINE		0.6
#define X_COMMANDER		0.35
#define X_ALIEN			0.7	//0.85

#define OTHER			0
#define MARINE			1	//makes all odd teamnumbers considered 'rine
#define ALIEN			2

#define MAX_TEAMS		5
#define MAX_BUILDINGS		20

#define DIEING_HP		33.3333	// (Percentage)
#define MIN_WARNING_REPEAT_TIME	10.0	// How long to wait before playing the CC warning sound again
#define WARNING_LEN		5.0	// How long to play the CC warning sound
#define SOUND_WARNING		"ambience/warn3.wav"	// The half-life wav used for playing the CC warning sound

#define	BUILDINGS_BEFORE_WRAPPING	6

#define FixGamma(%1,%2)		floatround(((%1) / (%2)) * 255.0)


///////////////////////////////////////////////////////////////////////////////////////////////////
////////	Settings
///////////////////////////////////////////////////////////////////////////////////////////////////

#define	ENABLE_CC	TRUE
#define	ENABLE_ARMORY	TRUE
#define	ENABLE_TF	FALSE
#define	ENABLE_IP	FALSE
#define	ENABLE_ARMSLAB	FALSE
#define	ENABLE_PROTOLAB	FALSE
#define	ENABLE_OBS	FALSE
#define	ENABLE_TURRET	FALSE	//siege and normal
#define	ENABLE_PG	FALSE

#define	ENABLE_RT	FALSE	//alien and marine

#define	ENABLE_HIVE	TRUE
#define	ENABLE_DC	FALSE
#define	ENABLE_MC	FALSE
#define	ENABLE_SC	FALSE
#define	ENABLE_OC	FALSE



///////////////////////////////////////////////////////////////////////////////////////////////////
////////	Enums
///////////////////////////////////////////////////////////////////////////////////////////////////

enum _:
{
	HUDMSGFX_FADE,
	HUDMSGFX_FLICKER,
	HUDMSGFX_TYPE, 
	
	HUDMSGFX_MAX
}

enum _:
{
	AVH_USER3_NONE = 0,
	
	AVH_USER3_HIVE = 17,
	
	AVH_USER3_COMMANDER_STATION = 23,
	AVH_USER3_TURRET_FACTORY, 
	AVH_USER3_ARMORY, 
	AVH_USER3_ADVANCED_ARMORY,
	AVH_USER3_ARMSLAB,
	AVH_USER3_PROTOTYPE_LAB, 
	AVH_USER3_OBSERVATORY,
	
	AVH_USER3_TURRET = 33,
	AVH_USER3_SIEGETURRET,
	AVH_USER3_RESTOWER,
	
	AVH_USER3_INFANTRYPORTAL = 37,
	
	AVH_USER3_PHASEGATE = 41,
	AVH_USER3_DEFENSE_CHAMBER,
	AVH_USER3_MOVEMENT_CHAMBER,
	AVH_USER3_OFFENSE_CHAMBER,
	AVH_USER3_SENSORY_CHAMBER,
	AVH_USER3_ALIENRESTOWER,
	
	AVH_USER3_ADV_TURRET_FACTORY = 49,		//trunc'd from AVH_USER3_ADVANCED_TURRET_FACTORY
	
	AVH_USER3_MAX
}

enum _:
{
	BC_NONE = 0,
	
#if ENABLE_CC
	BC_CC,
#endif
#if ENABLE_ARMORY
	BC_ARMORY,
	BC_ADV_ARMORY,
#endif
#if ENABLE_IP
	BC_IP,
#endif
#if ENABLE_ARMSLAB
	BC_ARMSLAB,
#endif
#if ENABLE_OBS
	BC_OBS,
#endif
#if ENABLE_PROTOLAB
	BC_PROTOLAB,
#endif
#if ENABLE_PG
	BC_PG,
#endif
#if ENABLE_TF
	BC_TF,
	BC_ADV_TF,
#endif
#if ENABLE_TURRET
	BC_TURRET,
	BC_SIEGE,
#endif

#if ENABLE_RT
	BC_RT,
	BC_RC,	//res chamber
#endif

#if ENABLE_HIVE
	BC_HIVE,
#endif
#if ENABLE_DC
	BC_DC,
#endif
#if ENABLE_MC
	BC_MC,
#endif
#if ENABLE_SC
	BC_SC,
#endif
#if ENABLE_OC
	BC_OC,
#endif
	
	BC_MAX
}

///////////////////////////////////////////////////////////////////////////////////////////////////
////////	Globals
///////////////////////////////////////////////////////////////////////////////////////////////////

new g_krsBuildingClassname[][] = 
{
	"Yams",
	
#if ENABLE_CC
	"CC",
#endif
#if ENABLE_ARMORY
	"Armory",
	"Adv Armory",
#endif
#if ENABLE_IP
	"IP",
#endif
#if ENABLE_ARMSLAB
	"Armslab",
#endif
#if ENABLE_OBS
	"Obs",
#endif
#if ENABLE_PROTOLAB
	"ProtoLab",
#endif
#if ENABLE_PG
	"PG",
#endif
#if ENABLE_TF
	"TF",
	"Adv TF",
#endif
#if ENABLE_TURRET
	"Turret",
	"Siege",
#endif

#if ENABLE_RT
	"RT",
	"RT",	//res chamber
#endif

#if ENABLE_HIVE
	"Hive",
#endif
#if ENABLE_DC
	"DC",
#endif
#if ENABLE_MC
	"MC",
#endif
#if ENABLE_SC
	"SC",
#endif
#if ENABLE_OC
	"OC",
#endif
	
	"Gaben"
}


new g_iMaxPlayers, g_iMaxEnts

new g_kriUser3ToiBuildingClass[AVH_USER3_MAX]
new g_kriBuildingClassToiUser3[BC_MAX]

new g_riCount[MAX_TEAMS][BC_MAX]
new g_reEnt[MAX_TEAMS][BC_MAX][MAX_BUILDINGS]
new Float:g_rfHP_Cur[MAX_TEAMS][BC_MAX][MAX_BUILDINGS]
new Float:g_rfHP_Last[MAX_TEAMS][BC_MAX][MAX_BUILDINGS]
new Float:g_rfHP_Max[MAX_TEAMS][BC_MAX][MAX_BUILDINGS]
new Float:g_rfHP_Percent[MAX_TEAMS][BC_MAX][MAX_BUILDINGS]

new g_rsBuildingStatus[MAX_TEAMS][1024]

new Float:g_rfLastWarningTime[MAX_TEAMS] = {0.0, ...}
new g_riColorList[5][3];

new g_pcvarSound, g_pcvarExtraColors, g_pcvarMvM_Red, g_pcvarUpdateDelay


///////////////////////////////////////////////////////////////////////////////////////////////////
////////	Macros
///////////////////////////////////////////////////////////////////////////////////////////////////

#define	get_team(%1)	pev(%1, pev_team)
#define	floor(%1)	floatround(%1, floatround_floor)


///////////////////////////////////////////////////////////////////////////////////////////////////
////////	Forwarded Funcs
///////////////////////////////////////////////////////////////////////////////////////////////////

public plugin_precache()
	precache_sound(SOUND_WARNING)

public plugin_init()
{
	register_plugin("Hive/CC Status", VERSION, "Darkns")
	register_cvar("hiveccstatus_version", VERSION, FCVAR_SERVER)

	g_pcvarSound = register_cvar("hc_sound", "1")
	g_pcvarExtraColors = register_cvar("hc_extrateamcolors", "1")
	g_pcvarMvM_Red = register_cvar("hc_mvm_usered", "1")
	g_pcvarUpdateDelay = register_cvar("hc_updatedelay", "2.0")
	
	register_cvar("hc_ns", "1")
	register_cvar("hc_co", "1")
	
	
	new iIsDisabled = FALSE
	
	if (get_cvar_num("mp_tournamentmode"))
		iIsDisabled = TRUE
	else if (ns_is_combat())	//combat
	{
		if (!get_cvar_num("hc_co"))
			iIsDisabled = TRUE
	}
	else	//classic
	{
		if (!get_cvar_num("hc_ns"))
			iIsDisabled = TRUE
	}
	
	if (iIsDisabled)
	{
		pause("ad")
		return
	}
	
	set_task(10.0, "UpdateStatuses")
	
	register_message(get_user_msgid("SetGmma"),"hook_SetGmma")	//no, this isn't my bad spelling...
	
	g_iMaxPlayers = get_maxplayers()
	g_iMaxEnts = get_global_int(GL_maxEntities)
	
	RecordBuildingClasses()
	
	LoadGamma(1.0);	//init these to neutral
}


///////////////////////////////////////////////////////////////////////////////////////////////////
////////	Hooked Funcs
///////////////////////////////////////////////////////////////////////////////////////////////////

public hook_SetGmma(iMsgId, iDest, eTarget)
{
	LoadGamma(float(get_msg_arg_int(1)) / 128.0);
	
	return BLOCK_NOT
}

public UpdateStatuses()
{
	UpdateBuildingStructs()
	
	
	new rIsTeamStatusStringUpdated[MAX_TEAMS] = {FALSE, ...};
	
	for (new ePlayer = 1; ePlayer <= g_iMaxPlayers; ePlayer++)
	{
		if (is_user_connected(ePlayer))
		{
			new iTeam = get_team(ePlayer)
			if (!rIsTeamStatusStringUpdated[iTeam])
			{
				UpdateTeamStatusString(iTeam)
				
				rIsTeamStatusStringUpdated[iTeam] = TRUE
			}
			
			ShowStatus(ePlayer)
		}
	}
	
	set_task(get_pcvar_float(g_pcvarUpdateDelay), "UpdateStatuses")
}


///////////////////////////////////////////////////////////////////////////////////////////////////
////////	Main Funcs
///////////////////////////////////////////////////////////////////////////////////////////////////

UpdateBuildingStructs()
{
	for (new iTeam = 1; iTeam < MAX_TEAMS; iTeam++)
	{
		for (new iBuildingClass = BC_NONE + 1; iBuildingClass < BC_MAX; iBuildingClass++)
		{
			static iCount;
			iCount = 0
			
			static eBuilding;
			eBuilding = FindTeamBuildingByIUser3Class(iTeam, g_kriBuildingClassToiUser3[iBuildingClass], g_iMaxPlayers + 1)	//players aren't buildings, skip them
			
			while (eBuilding != -1)
			{
				if (IsValidStruct(eBuilding))
				{
					g_reEnt[iTeam][iBuildingClass][iCount] = eBuilding
					
					g_rfHP_Last[iTeam][iBuildingClass][iCount] = g_rfHP_Cur[iTeam][iBuildingClass][iCount]
					
					static Float:fHP_Cur;
					fHP_Cur = g_rfHP_Cur[iTeam][iBuildingClass][iCount] = fpev(eBuilding, pev_health)
					static Float:fHP_Max;
					fHP_Max = g_rfHP_Max[iTeam][iBuildingClass][iCount] = fpev(eBuilding, pev_max_health)
					g_rfHP_Percent[iTeam][iBuildingClass][iCount] = (fHP_Cur / fHP_Max) * 100.0
					
					iCount++
				}
				
				eBuilding = FindTeamBuildingByIUser3Class(iTeam, g_kriBuildingClassToiUser3[iBuildingClass], eBuilding + 1)
			}
			
			g_riCount[iTeam][iBuildingClass] = iCount
		}
	}
}

UpdateTeamStatusString(iTeam)
{
	if (get_team_teamtype(iTeam) != OTHER)
	{
		static sHUDText[1024]
		sHUDText[0] = '^0';
		
		for (new iBuildingClass = BC_NONE + 1; iBuildingClass < BC_MAX; iBuildingClass++)
		{
			new iBuildingCount = g_riCount[iTeam][iBuildingClass]
			
			if (iBuildingCount)
			{
				add(sHUDText, 1023, g_krsBuildingClassname[iBuildingClass])
				add(sHUDText, 1023, ": ")
				
				for (new iCurBuilding = 0; iCurBuilding < iBuildingCount; iCurBuilding++)
				{
					if (mod(iCurBuilding + 1, BUILDINGS_BEFORE_WRAPPING) == 0)	//makes for a nice effect...
						add(sHUDText, 1023, "^n")	//gets WAAY too long
					
					static sTemp[8];
					format(sTemp, 7, " %.1f%%", g_rfHP_Percent[iTeam][iBuildingClass][iCurBuilding])
					add(sHUDText, 1023, sTemp)
				}
				
				add(sHUDText, 1023, "^n")
			}
		}
		
		copy(g_rsBuildingStatus[iTeam], 1023, sHUDText)
	}
}

ShowStatus(ePlayer)
{
	new iTeam = get_team(ePlayer)
	new iTeamType = get_team_teamtype(iTeam)
	if (iTeamType == OTHER)
	{
		iTeam = get_team(pev(ePlayer, pev_iuser2))	//get team of player we're viewing
		iTeamType = get_team_teamtype(iTeam)
	}
	
	if (iTeamType == OTHER)
	{
		set_hudmessage(0, 0, 0, 0.0, 0.0, 0, 1.0, 3600.0, 1.0, 1.0, HUD_CHANNEL)
		show_hudmessage(ePlayer, " ")
	}
	else
	{
		new Float:fX, Float:fY
		new iEffect = HUDMSGFX_FADE
		
		new iTeamColor;
		if (iTeamType == MARINE)
		{
			//location
			if (ns_get_class(ePlayer) == CLASS_COMMANDER)
			{
				fX = X_COMMANDER
				fY = Y_COMMANDER
			}
			else
			{
				fX = X_MARINE
				fY = IsNotDead(ePlayer)?Y_MARINE_ALIVE:Y_MARINE_DEAD
			}
			
			//color
			if (IsLastBuildingDieing(iTeam, BC_CC))
			{
				iTeamColor = 0;
				
				if (IsLastBuildingUnderAttack(iTeam, BC_CC))
					iEffect = HUDMSGFX_FLICKER
			}
			else if ((iTeam == 3) && get_pcvar_num(g_pcvarExtraColors))	//MarineTeam2
			{
				if (get_pcvar_num(g_pcvarMvM_Red))
				{
					iTeamColor = 4;
				}
				else
				{
					iTeamColor = 3;
				}
			}
			else
			{
				iTeamColor = 1;
			}
		}
		else
		{
			//location
			fX = X_ALIEN
			fY = IsNotDead(ePlayer)?Y_ALIEN_ALIVE:Y_ALIEN_DEAD
			
			//color
			if (IsLastBuildingDieing(iTeam, BC_HIVE))
			{
				iTeamColor = 0;
				
				if (IsLastBuildingUnderAttack(iTeam, BC_HIVE))
					iEffect = HUDMSGFX_FLICKER
			}
			else if ((iTeam == 4) && get_pcvar_num(g_pcvarExtraColors))	//MarineTeam2
			{
				iTeamColor = 4;
			}
			else
			{
				iTeamColor = 2;
			}
		}
		
		if (iEffect == HUDMSGFX_FLICKER)	//DIEING
		{
			if (get_pcvar_num(g_pcvarSound))	//if we should play the sound, and it was DIEING before as well...
			{
				new Float:fNow = halflife_time()
				if ((fNow - g_rfLastWarningTime[iTeam]) >= MIN_WARNING_REPEAT_TIME)
				{
					g_rfLastWarningTime[iTeam] = fNow
					PlayWarningSound(iTeam)
				}
			}
		}
		
		
		
		set_hudmessage(g_riColorList[iTeamColor][0], g_riColorList[iTeamColor][1], g_riColorList[iTeamColor][2], fX, fY, iEffect, 1.0, 3600.0, 0.0, 0.0, HUD_CHANNEL)
		show_hudmessage(ePlayer, "%s", g_rsBuildingStatus[iTeam])
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////
////////	Util Funcs
///////////////////////////////////////////////////////////////////////////////////////////////////

RecordBuildingClasses()
{
	//and again...
#if ENABLE_CC
	RecordBuildingClass(AVH_USER3_COMMANDER_STATION, BC_CC)
#endif
#if ENABLE_ARMORY
	RecordBuildingClass(AVH_USER3_ARMORY, BC_ARMORY)
	RecordBuildingClass(AVH_USER3_ADVANCED_ARMORY, BC_ADV_ARMORY)
#endif
#if ENABLE_IP
	RecordBuildingClass(AVH_USER3_INFANTRYPORTAL, BC_IP)
#endif
#if ENABLE_ARMSLAB
	RecordBuildingClass(AVH_USER3_ARMSLAB, BC_ARMSLAB)
#endif
#if ENABLE_OBS
	RecordBuildingClass(AVH_USER3_OBSERVATORY, BC_OBS)
#endif
#if ENABLE_PROTOLAB
	RecordBuildingClass(AVH_USER3_PROTOTYPE_LAB, BC_PROTOLAB)
#endif
#if ENABLE_PG
	RecordBuildingClass(AVH_USER3_PHASEGATE, BC_PG)
#endif
#if ENABLE_TF
	RecordBuildingClass(AVH_USER3_TURRET_FACTORY, BC_TF)
	RecordBuildingClass(AVH_USER3_ADV_TURRET_FACTORY, BC_ADV_TF)
#endif
#if ENABLE_TURRET
	RecordBuildingClass(AVH_USER3_TURRET, BC_TURRET)
	RecordBuildingClass(AVH_USER3_SIEGETURRET, BC_SIEGE)
#endif

#if ENABLE_RT
	RecordBuildingClass(AVH_USER3_RESTOWER, BC_RT)
	RecordBuildingClass(AVH_USER3_ALIENRESTOWER, BC_RC)	//res chamber
#endif

#if ENABLE_HIVE
	RecordBuildingClass(AVH_USER3_HIVE, BC_HIVE)
#endif
#if ENABLE_DC
	RecordBuildingClass(AVH_USER3_DEFENSE_CHAMBER, BC_DC)
#endif
#if ENABLE_MC
	RecordBuildingClass(AVH_USER3_MOVEMENT_CHAMBER, BC_MC)
#endif
#if ENABLE_SC
	RecordBuildingClass(AVH_USER3_SENSORY_CHAMBER, BC_SC)
#endif
#if ENABLE_OC
	RecordBuildingClass(AVH_USER3_OFFENSE_CHAMBER, BC_OC)
#endif
	//done
}

FindTeamBuildingByIUser3Class(iTeam, iUser3Class, eStart = 1)
{
	for (new eCur = eStart; eCur <= g_iMaxEnts; eCur++)
	{
		if ( (pev_valid(eCur))
		  && (get_team(eCur) == iTeam)
		  && (pev(eCur, pev_iuser3) == iUser3Class)
		  && !(pev(eCur, pev_iuser4) & MASK_BUILDABLE) )	//not buildable means it's built already
		{
			return eCur
		}
	}
	
	return -1
}

RecordBuildingClass(iUser3Class, iBuidlingClass)
{
	g_kriUser3ToiBuildingClass[iUser3Class] = iBuidlingClass
	g_kriBuildingClassToiUser3[iBuidlingClass] = iUser3Class
}

IsLastBuildingDieing(iTeam, iBuildingClass)
{
	if (g_riCount[iTeam][iBuildingClass] == 1)
	{
		if (g_rfHP_Percent[iTeam][iBuildingClass][0] < DIEING_HP)
			return TRUE
	}
	
	return FALSE
}

IsLastBuildingUnderAttack(iTeam, iBuildingClass)
{
	if (g_riCount[iTeam][iBuildingClass] == 1)
	{
		if (g_rfHP_Cur[iTeam][iBuildingClass][0] < g_rfHP_Last[iTeam][iBuildingClass][0])
			return TRUE
	}
	
	return FALSE
}

LoadGamma(Float:fGamma)
{
	g_riColorList[0][0] = FixGamma(DIEING_RED   , fGamma);
	g_riColorList[0][1] = FixGamma(DIEING_GREEN , fGamma);
	g_riColorList[0][2] = FixGamma(DIEING_BLUE  , fGamma);
	
	g_riColorList[1][0] = FixGamma(MARINE_RED   , fGamma);
	g_riColorList[1][1] = FixGamma(MARINE_GREEN , fGamma);
	g_riColorList[1][2] = FixGamma(MARINE_BLUE  , fGamma);
	
	g_riColorList[2][0] = FixGamma(ALIEN_RED    , fGamma);
	g_riColorList[2][1] = FixGamma(ALIEN_GREEN  , fGamma);
	g_riColorList[2][2] = FixGamma(ALIEN_BLUE   , fGamma);
	
	g_riColorList[3][0] = FixGamma(MARINE2_RED  , fGamma);
	g_riColorList[3][1] = FixGamma(MARINE2_GREEN, fGamma);
	g_riColorList[3][2] = FixGamma(MARINE2_BLUE , fGamma);
	
	g_riColorList[4][0] = FixGamma(ALIEN2_RED   , fGamma);
	g_riColorList[4][1] = FixGamma(ALIEN2_GREEN , fGamma);
	g_riColorList[4][2] = FixGamma(ALIEN2_BLUE  , fGamma);
}

IsNotDead(ePlayer)
{
	if (pev(ePlayer, pev_deadflag) & DEAD_DEAD)
		return FALSE
	
	return TRUE
}

PlayWarningSound(iTeam)
{
	for (new ePlayer = 1; ePlayer <= g_iMaxPlayers; ePlayer++)
	{
		if (is_user_connected(ePlayer))
		{
			if (get_team(ePlayer) == iTeam)
			{
				client_cmd(ePlayer, "play %s", SOUND_WARNING)
				new rVal[1]
				rVal[0] = iTeam
				set_task(WARNING_LEN, "Task_StopWarningSound",_, rVal, 1)
			}
		}
	}
}

public Task_StopWarningSound(rVal[1])
	StopWarningSound(rVal[0])

StopWarningSound(iTeam)
{
	for (new ePlayer = 1; ePlayer <= g_iMaxPlayers; ePlayer++)
	{
		if (is_user_connected(ePlayer))
			if (get_team(ePlayer) == iTeam)
				client_cmd(ePlayer, "stopsound")
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////
////////	Basic Util Funcs
///////////////////////////////////////////////////////////////////////////////////////////////////

/* macro'd
get_team(eEnt)
	return pev(eEnt, pev_team)
*/

get_team_teamtype(iTeam)	//MvM/AvA support...
{
	switch (iTeam)
	{
		case 1: 
			return MARINE
		case 2: 
			return ALIEN
		case 3: 
			return MARINE
		case 4: 
			return ALIEN
	}
	//default:
	return OTHER
}

Float:fpev(eEnt, iPevVar)
{
	static Float:fVal
	pev(eEnt, iPevVar, fVal)
	return fVal
}

mod(iNumber, iMod) //amx-x doesn't seem to have a modulo function/operator...
	return iNumber - ( iMod * floor(float(iNumber) / float(iMod)) )	//mmm

/* macro'd
floor(Float:fNum)
	return floatround(fNum, floatround_floor)
*/

IsValidStruct(eEnt)
{
	if (!pev_valid(eEnt))
		return FALSE;
	
	if (fpev(eEnt, pev_health) < 0.5)
		return FALSE;
	
	if (pev(eEnt, pev_iuser4) & MASK_RECYCLING)
		return FALSE;
	
	return TRUE;
}