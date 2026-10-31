/* The Header of Dewm:

CVars:
	sc_playerbuild_dist	How far away a player can place a chamber (default 120.0)
	sc_unchained		Unchains chambers from hives (default 0)
	sc_cost_oc		Cost of OCs. (default 10)
	sc_cost_dc		Cost of DCs. (default 10, default 12 when unchained)
	sc_cost_sc		Cost of MCs. (default 10, default 15 when unchained)
	sc_cost_mc		Cost of SCs. (default 10)
	sc_chamberlimit_dist	How big is the 'Too Many Structures' radius (default 1000.0)
	sc_chamberlimit_num	How many chambers can be built per area (default 8)
*/


//==================================================================================================
//==================================================================================================
//	Configuration

/*
INT (0)
0 - Do use default helper output
1 - Use the "Helper" plugin! (recommended)
*/
#define HELPER 0

//==================================================================================================
//==================================================================================================
//	Includes
#include <amxmodx>
#include <fakemeta>
#include <ns>

#if HELPER == 1
	#include <helper>
#else
	#define help_add(%1) 	float(0)
#endif


//==================================================================================================
//==================================================================================================
//	Compile Parameters

#pragma semicolon	1
#pragma	tabsize		0	//gives a bunch of indentation warnings if left alone


//==================================================================================================
//==================================================================================================
//	Defines

#define LOG_TAG			"StickyChambers"
#define VERSION			"1.25"

#define	TRUE			1
#define	FALSE			0

#define NATIVE_DYNAMIC		1

#define PRIV_NEXTATTACK		123
#define LINUX_OFFSET_SMALL	4

#define	DELAY_RESEND_TOOMANY	10.0

#define HUD_SOUND		0
#define HUD_BUILT		1
#define HUD_SOUND_ALIEN_MORE	40
#define	CHAMBER_SOLID		SOLID_BBOX
#define	CHAMBER_MOVETYPE	MOVETYPE_FLY
#define OC_FIRE_HEIGHT		48.0

#define SETTECH_IMPULSE		1
#define SETTECH_COST		5

#define	TH_INVALID		0
#define	TH_ALREADYEXISTS	-1	//already has a hive bound

#define OTHER			0
#define MARINE			1
#define ALIEN			2

#define PITCH			0
#define YAW			1
#define ROLL			2


//==================================================================================================
//==================================================================================================
//	Macros

#define fm_write_coord(%1)		engfunc(EngFunc_WriteCoord, %1)
#define create_entity(%1)		engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, %1))
#define	angle_to_vector(%1,%2)		engfunc(EngFunc_AngleVectors, %1, %2, {0.0,0.0,0.0}, {0.0,0.0,0.0})
#define	angle_to_vectors(%1,%2,%3,%4)	engfunc(EngFunc_AngleVectors, %1, %2, %3, %4)

#define	remove_entity_soft(%1)		set_pev(%1, pev_flags, pev(%1, pev_flags) | FL_KILLME)
#define GetAimVars(%1,%2,%3)		pev(%1, pev_origin, %2); pev(%1, pev_view_ofs, %3); VectorAddSelf(%2, %3); pev(%1, pev_v_angle, %3)

#define get_team(%1)		pev(%1, pev_team)
#define set_team(%1,%2)		set_pev(%1, pev_team, %2)
#define	get_teamtype(%1)	get_team_teamtype(get_team(%1))

#define	sin(%1)			floatsin(%1, degrees)
#define	cos(%1)			floatcos(%1, degrees)

#define VectorEqual(%1,%2)	(  (%1[0] == %2[0])\
				&& (%1[1] == %2[1])\
				&& (%1[2] == %2[2]) )

#define	VectorAdd(%1,%2,%3)	%3[0] = %1[0] + %2[0];\
				%3[1] = %1[1] + %2[1];\
				%3[2] = %1[2] + %2[2]

#define VectorAddSelf(%1,%2)	%1[0] += %2[0];\
				%1[1] += %2[1];\
				%1[2] += %2[2]

#define VectorSub(%1,%2,%3)	%3[0] = %1[0] - %2[0];\
				%3[1] = %1[1] - %2[1];\
				%3[2] = %1[2] - %2[2]

#define	VectorSubSelf(%1,%2)	%1[0] -= %2[0];\
				%1[1] -= %2[1];\
				%1[2] -= %2[2]

#define VectorScal(%1,%2,%3)	%3[0] = %1[0] * %2;\
				%3[1] = %1[1] * %2;\
				%3[2] = %1[2] * %2

#define VectorScalSelf(%1,%2)	%1[0] *= %2;\
				%1[1] *= %2;\
				%1[2] *= %2


//==================================================================================================
//==================================================================================================
//	Enums

enum _:iUser3Values
{
	AVH_USER3_DEFENSE_CHAMBER = 42,
	AVH_USER3_MOVEMENT_CHAMBER,
	AVH_USER3_OFFENSE_CHAMBER,
	AVH_USER3_SENSORY_CHAMBER
};

enum _:Impulse
{
	IMPULSE_OC = 91,
	IMPULSE_DC,
	IMPULSE_SC,
	IMPULSE_MC,
	
	IMPULSE_MAX
};

enum _:
{
	MODE_CLASSIC,
	MODE_COMBAT,
	
	MODE_MAX
};


//==================================================================================================
//==================================================================================================
//	Constants

//chamber
new Float:g_kvMin[3] = {-16.0, -16.0,  0.0};	//constant, but not const
new Float:g_kvMax[3] = { 16.0,  16.0, 44.0};
//test box size
#define	TESTBOX_HEIGHT	32.0		//48 - 16 = 32, 48 is OC fire height
//needs to leave at least 16u space, even at 45pitch, 45yaw, -> 16^2 = 3*x^2, x = 16 / sqrt(3) ~= 16 / 1.732 ~= 9.238
new Float:g_kvTestMin[3] = {-9.2, -9.2, -9.2};	//constant, but not const
new Float:g_kvTestMax[3] = { 9.2,  9.2,  9.2};
new Float:g_buildingViewFudge[3] = {0.0, 0.0, 10.0};

new const g_krs_Sound_ChamberSpawn[2][] = 
{
	"misc/a-build1.wav",
	"misc/a-build2.wav"
};

#define	NULLSTRING	""	//make it easier to read...
#define	NULLSTRING_10	NULLSTRING,NULLSTRING,NULLSTRING,NULLSTRING,NULLSTRING,\
			NULLSTRING,NULLSTRING,NULLSTRING,NULLSTRING,NULLSTRING

new const g_krsChamberClass[IMPULSE_MAX][] = 
{
	NULLSTRING_10,	//0-9
	NULLSTRING_10,	//10-19
	NULLSTRING_10,	//20-29
	NULLSTRING_10,	//30-39
	NULLSTRING_10,	//40-49
	
	NULLSTRING_10,	//50-59
	NULLSTRING_10,	//60-69
	NULLSTRING_10,	//70-79
	NULLSTRING_10,	//80-89
	NULLSTRING,	//90
	
	"offensechamber",	//91
	"defensechamber",	//92
	"sensorychamber",	//93
	"movementchamber"	//94
};


//==================================================================================================
//==================================================================================================
//	Global Variables

new g_iGameMode;
new g_iMaxPlayers;
new g_pcvarUnchained, g_pcvarPlayerBuildDist;
new g_pcvarChamberLimitDist, g_pcvarChamberLimitNum;
new g_rpcvarChamberCost[IMPULSE_MAX];
new g_iMsgID_PlayHUDNot, g_iMsgID_SetTech;
new Float:g_rfNext_TooMany[33];
new g_offsetFudged[2000] = {FALSE, ...};

//==================================================================================================
//==================================================================================================
//	Forwarded Functions

public plugin_precache()
{
	precache_sound(g_krs_Sound_ChamberSpawn[0]);
	precache_sound(g_krs_Sound_ChamberSpawn[1]);
}

public plugin_init()
{
	register_plugin("Sticky Chambers", VERSION, "Darkns");
	register_cvar("v_stickychamb", VERSION, FCVAR_SERVER);
	
	g_pcvarPlayerBuildDist = register_cvar("sc_playerbuild_dist", "120.0");
	g_pcvarChamberLimitDist = register_cvar("sc_chamberlimit_dist", "1000.0");
	g_pcvarChamberLimitNum = register_cvar("sc_chamberlimit_num", "8");
	g_pcvarUnchained = register_cvar("sc_unchained", "0");
	
	if (ns_is_combat())
		g_iGameMode = MODE_COMBAT;
	else
		g_iGameMode = MODE_CLASSIC;
		
	if (get_pcvar_num(g_pcvarUnchained))
	{
		g_rpcvarChamberCost[IMPULSE_OC] = register_cvar("sc_cost_oc", "10");
		g_rpcvarChamberCost[IMPULSE_DC] = register_cvar("sc_cost_dc", "12");
		g_rpcvarChamberCost[IMPULSE_SC] = register_cvar("sc_cost_sc", "15");
		g_rpcvarChamberCost[IMPULSE_MC] = register_cvar("sc_cost_mc", "10");
	}
	else
	{
		g_rpcvarChamberCost[IMPULSE_OC] = register_cvar("sc_cost_oc", "10");
		g_rpcvarChamberCost[IMPULSE_DC] = register_cvar("sc_cost_dc", "10");
		g_rpcvarChamberCost[IMPULSE_SC] = register_cvar("sc_cost_sc", "10");
		g_rpcvarChamberCost[IMPULSE_MC] = register_cvar("sc_cost_mc", "10");
	}
	
	g_iMsgID_PlayHUDNot = get_user_msgid("PlayHUDNot");
	g_iMsgID_SetTech = get_user_msgid("SetTech");
	
	register_forward(FM_CmdStart, "fmhook_CmdStart");
	register_forward(FM_Think, "fmhook_Think");
	register_forward(FM_Think, "fmhook_Think_Post", 1);
	register_forward(FM_Touch, "fmhook_Touch");
	
	register_message(g_iMsgID_SetTech, "msghook_SetTech");
	
	g_iMaxPlayers = global_get(glb_maxClients);	//because FakeMeta is just that cool
}


//==================================================================================================
//==================================================================================================
//	Helper Interface

public client_help(ePlayer)
{
	help_add("Information","This plugin allows chambers to be built on any surface.");
	if (get_teamtype(ePlayer) == ALIEN)
	{
		help_add("Usage","Aim where you want to build the chamber before you build it.^nMake sure you're close enough to the surface you want to build on!");
	}
	else
	{
		help_add("Warning","Be on the lookout for chambers in unusual places!");
	}
	
	
	if (get_pcvar_num(g_pcvarUnchained))
		help_add("Note","Chamber types are currently unchained from hives.");
}

public client_advertise(ePlayer)
{
	if (get_teamtype(ePlayer) == ALIEN)
		return PLUGIN_CONTINUE;	//show
	
	return PLUGIN_HANDLED;	//ignore
}

//==================================================================================================
//==================================================================================================
//	Hook Functions

public fmhook_Touch(eEnt, eOther)
{
	if (pev_valid(eEnt) && IsValidWorld(eOther) && (AVH_USER3_DEFENSE_CHAMBER <= pev(eEnt, pev_iuser3) <= AVH_USER3_SENSORY_CHAMBER) )
	{
		//otherwise this would not allow the chamber to cloak
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

//(const edict_t *player, const struct usercmd_s *cmd, unsigned int random_seed);
public fmhook_CmdStart(ePlayer, ucHandle)	//, iRandomSeed)
{
	if (g_iGameMode != MODE_CLASSIC)	//should only function in classic
		return FMRES_IGNORED;
	
	if (pev_valid(ePlayer) && !is_user_bot(ePlayer))
	{
		static iTeam;
		iTeam = get_team(ePlayer);
		
		if (get_team_teamtype(iTeam) == ALIEN)	//check for gorge later
		{
			static iImpulse;
			iImpulse = get_uc(ucHandle, UserCmd:UC_Impulse);
			
			if (IMPULSE_OC <= iImpulse <= IMPULSE_MC)
			{
				static Float:fChamberCost;
				fChamberCost = get_pcvar_float(g_rpcvarChamberCost[iImpulse]);
				
				static Float:fRes;
				fRes = ns_get_res(ePlayer) - fChamberCost;
				if ( (fRes < 0.0) || (ns_get_class(ePlayer) != CLASS_GORGE) )	//not a gorgeh!
				{
					message_begin(MSG_ONE, g_iMsgID_PlayHUDNot, {0,0,0}, ePlayer);
					write_byte(HUD_SOUND);
					write_byte(HUD_SOUND_ALIEN_MORE);
					write_coord(0);
					write_coord(0);
					message_end();
				}	//ns_set_res( ) is down further
				else
				{
					static eTraitHive;
					eTraitHive = GetTraitHive(iTeam, iImpulse);
					
					if (eTraitHive != TH_INVALID)
					{
						if (CreateChamber(ePlayer, iImpulse))
						{
							if (eTraitHive != TH_ALREADYEXISTS)	//if it's not TH_ALREADYEXISTS, and it wasn't TH_INVALID, then eTraitHive is the blank hive we want
								ns_set_hive_trait(eTraitHive, iImpulse);
							
							ns_set_res(ePlayer, fRes);
						}
					}
				}
				
				set_uc(ucHandle, UserCmd:UC_Impulse, 0);
			}
		}
	}
	
	return FMRES_IGNORED;
}

public fmhook_Think(eEnt)
{
	if (pev_valid(eEnt) && (AVH_USER3_DEFENSE_CHAMBER <= pev(eEnt, pev_iuser3) <= AVH_USER3_SENSORY_CHAMBER))	//it's a chamber
	{
		if (!ValidPlacement(eEnt))
		{
			new Float:oChamber[3], Float:aChamber[3];
			pev(eEnt, pev_origin, oChamber);
			pev(eEnt, pev_angles, aChamber);
			log_amx("[%s] removing %i: invalid placement at o{%.2f, %.2f, %.2f} a{%.2f, %.2f, %.2f}", LOG_TAG, eEnt,
														  oChamber[0], oChamber[1], oChamber[2],
														  aChamber[0], aChamber[1], aChamber[2]);
			remove_entity_soft(eEnt);
			return FMRES_SUPERCEDE;
		}
		
		new Float:nextAttack = get_pdata_float(eEnt, PRIV_NEXTATTACK, LINUX_OFFSET_SMALL);
		if (nextAttack <= Now())
		{
			new Float:origin[3];
			pev(eEnt, pev_origin, origin);
			new Float:viewOffset[3];
			pev(eEnt, pev_view_ofs, viewOffset);
			
			VectorSubSelf(origin, g_buildingViewFudge);
			VectorAddSelf(origin, viewOffset);
			
			set_pev(eEnt, pev_origin, origin);
			
			g_offsetFudged[eEnt] = TRUE;
		}
	}
	
	return FMRES_IGNORED;
}

public fmhook_Think_Post(eEnt)
{
	if (g_offsetFudged[eEnt])
	{
		new Float:origin[3];
		pev(eEnt, pev_origin, origin);
		new Float:viewOffset[3];
		pev(eEnt, pev_view_ofs, viewOffset);
		
		VectorSubSelf(origin, viewOffset);
		VectorAddSelf(origin, g_buildingViewFudge);
		
		set_pev(eEnt, pev_origin, origin);
		
		g_offsetFudged[eEnt] = FALSE;
	}
}

public msghook_SetTech(iMsgID, iDestType, eTarget)
{
	if (g_iGameMode != MODE_CLASSIC)	//should only function in classic
		return FMRES_IGNORED;
	
	
	static iImpulse;
	iImpulse = get_msg_arg_int(SETTECH_IMPULSE);
	
	if (IMPULSE_OC <= iImpulse <= IMPULSE_MC)
	{
		static iCost;
		iCost = get_pcvar_num(g_rpcvarChamberCost[iImpulse]);
		
		set_msg_arg_int(SETTECH_COST, ARG_SHORT, iCost);
		
		return BLOCK_SET;
	}
	
	return BLOCK_NOT;
}

//==================================================================================================
//==================================================================================================
//Main Functions

//assume valid iImpulse
CreateChamber(ePlayer, iImpulse)
{
	static iTeam;
	iTeam = get_team(ePlayer);
	
	static Float:oPlayer[3], Float:aView[3], Float:vAim[3];
	GetAimVars(ePlayer, oPlayer, aView);
	angle_to_vector(aView, vAim);
	
	static Float:fMaxDist;
	fMaxDist = get_pcvar_float(g_pcvarPlayerBuildDist);
	
	static Float:oFar[3];
	VectorScal(vAim,fMaxDist,oFar);
	VectorAddSelf(oFar,oPlayer);
	
	static trHit;
	engfunc(EngFunc_TraceLine, oPlayer, oFar, 0, ePlayer, trHit);
	static eHit;
	static Float:oChamber[3], Float:vNormal[3];
	eHit = get_tr2(trHit, TraceResult:TR_pHit);
	get_tr2(trHit, TraceResult:TR_vecEndPos, oChamber);
	get_tr2(trHit, TraceResult:TR_vecPlaneNormal, vNormal);
	
	if (VectorEqual(oChamber, oFar) || !IsValidWorld(eHit))
		return 0;
	
	if (CountEntsInRange(oChamber, g_krsChamberClass[iImpulse], get_pcvar_float(g_pcvarChamberLimitDist)) >= get_pcvar_num(g_pcvarChamberLimitNum))
	{
		static Float:fNow;
		global_get(glb_time, fNow);
		
		if (g_rfNext_TooMany[ePlayer] <= fNow)
		{
			ns_popup(ePlayer, "#TooManyStructuresOfThisTypeNearby", 0);
			g_rfNext_TooMany[ePlayer] = fNow + DELAY_RESEND_TOOMANY;
		}
		return 0;
	}
	
	static Float:vMin[3], Float:vMax[3];
	MakeBBox(g_kvMin, g_kvMax, vNormal, vMin, vMax);
	
	if (!DoesChamberFit(ePlayer, oChamber, vNormal))
		return 0;
	
	
	static eChamber;
	eChamber = create_entity(g_krsChamberClass[iImpulse]);
	
	if (!pev_valid(eChamber))
	{
		log_amx("[%s] failed to create chamber for impulse %i", LOG_TAG, iImpulse);
		return 0;
	}
	
	dllfunc(DLLFunc_Spawn, eChamber);
	
	static Float:aChamber[3];
	vector_to_angle(vNormal, aChamber);
	
	aChamber[PITCH] -= 90.0;
	set_pev(eChamber, pev_angles, aChamber);
	
	
	static Float:vSize[3];
	VectorSub(vMax,vMin,vSize);
	
	static Float:oCenter[3];
	VectorScal(vSize,0.5,oCenter);
	VectorAddSelf(oCenter,oChamber);
	
	set_pev(eChamber, pev_mins, vMin);
	set_pev(eChamber, pev_maxs, vMax);
	set_pev(eChamber, pev_size, vSize);
	
	
	//this moves the chamber's origin 1u along the normal so it doesn't get stuck...
	VectorAddSelf(oChamber,vNormal);
	
	set_pev(eChamber, pev_origin, oChamber);
	set_pev(eChamber, pev_movetype, CHAMBER_MOVETYPE);
	set_pev(eChamber, pev_solid, CHAMBER_SOLID);
	ns_set_struct_owner(eChamber, ePlayer);
	set_team(eChamber, iTeam);
	
	if (iImpulse == IMPULSE_OC)
	{
		static Float:vOffset[3];
		VectorScal(vNormal,OC_FIRE_HEIGHT,vOffset);
		set_pev(eChamber, pev_view_ofs, vOffset);	//Where the spikes should originate. (I wish I knew about this a while ago)
	}
	
	SendHUDEvent(iImpulse, iTeam, oChamber);
	emit_sound(ePlayer, CHAN_AUTO, g_krs_Sound_ChamberSpawn[random_num(0,1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	
	return eChamber;
}

//==================================================================================================
//==================================================================================================
//	Native Functions


public plugin_natives()
{
	register_native("SC_CreateChamber", "native_CreateChamber", NATIVE_DYNAMIC);
}

public native_CreateChamber(ePlayer, iImpulse)
{
	return CreateChamber(ePlayer, iImpulse);
}

//==================================================================================================
//==================================================================================================
//Util functions

SendHUDEvent(iImpulse, iTeam, Float:oChamber[3])
{
	static i;
	for (i = 1; i <= g_iMaxPlayers; i++)
	{
		if (pev_valid(i) && (get_team(i) == iTeam))
		{
			message_begin(MSG_ONE, g_iMsgID_PlayHUDNot, {0,0,0}, i);
			write_byte(HUD_BUILT);
			write_byte(iImpulse);
			fm_write_coord(oChamber[0]);
			fm_write_coord(oChamber[1]);
			message_end();
		}
	}
}

DoesChamberFit(eOwner, Float:oChamber[3], Float:vNormal[3])
{
	new Float:oCenter[3];
	VectorScal(vNormal, 40.0, oCenter);
	VectorAddSelf(oCenter, oChamber);
	
	static Float:oMin[3], Float:oMax[3];
	
	VectorAdd(oCenter, g_kvTestMin, oMin);
	VectorAdd(oCenter, g_kvTestMax, oMax);
	
	if (!IsBoxEmpty(oMin, oMax, FALSE, eOwner))
		return FALSE;
	
	return TRUE;
}

IsBoxEmpty(Float:oMin[3], Float:oMax[3], iIgnoreMonsters, eSkip)
{
	new Float:oStart[3], Float:oEnd[3];
	//Z's constant
	oStart[2] = oMin[2];
	oEnd[2] = oMax[2];
	
	
	oStart[0] = oMin[0];
	oStart[1] = oMin[1];
	
	oEnd[0] = oMax[0];
	oEnd[1] = oMax[1];
	
	if (!IsTraceClear(oStart, oEnd, iIgnoreMonsters, eSkip))
		return FALSE;
	
	oStart[0] = oMin[0];
	oStart[1] = oMax[1];
	
	oEnd[0] = oMax[0];
	oEnd[1] = oMin[1];
	
	if (!IsTraceClear(oStart, oEnd, iIgnoreMonsters, eSkip))
		return FALSE;
	
	oStart[0] = oMax[0];
	oStart[1] = oMin[1];
	
	oEnd[0] = oMin[0];
	oEnd[1] = oMax[1];
	
	if (!IsTraceClear(oStart, oEnd, iIgnoreMonsters, eSkip))
		return FALSE;
	
	oStart[0] = oMax[0];
	oStart[1] = oMax[1];
	
	oEnd[0] = oMin[0];
	oEnd[1] = oMin[1];
	
	if (!IsTraceClear(oStart, oEnd, iIgnoreMonsters, eSkip))
		return FALSE;
	
	return TRUE;
}

IsTraceClear(Float:oStart[3], Float:oEnd[3], iIgnoreMonsters, eSkip)
{
	//(const float *v1, const float *v2, int fNoMonsters, edict_t *pentToSkip, TraceResult *ptr);
	new trResult;
	engfunc(EngFunc_TraceLine, oStart, oEnd, iIgnoreMonsters, eSkip, trResult);
	
	if (get_tr2(trResult, TraceResult:TR_StartSolid))
		return FALSE;
	
	if (get_tr2(trResult, TraceResult:TR_pHit) != -1)
		return FALSE;
	
	return TRUE;
}

GetTraitHive(iTeam, iTrait)
{
	if ((iTrait == IMPULSE_OC) || get_pcvar_num(g_pcvarUnchained))	//if it's an OC or everything's unchained, pretend we already have a hive for it
		return TH_ALREADYEXISTS;
	
	static iBuiltHives;
	iBuiltHives = ns_get_build("team_hive",1,0);
	static eFreeHive;
	eFreeHive = 0;
	static iHiveNum;
	for (iHiveNum = 1; iHiveNum <= iBuiltHives; iHiveNum++)
	{
		static eHive;
		eHive = ns_get_build("team_hive", 1, iHiveNum);
		if (get_team(eHive) == iTeam)
		{
			static iHiveTrait;
			iHiveTrait = ns_get_hive_trait(eHive);
			if (iHiveTrait == iTrait)
				return TH_ALREADYEXISTS;
			else if (!iHiveTrait)
				eFreeHive = eHive;
		}
	}
	
	if (eFreeHive)
		return eFreeHive;
	
	return TH_INVALID;
}

ValidPlacement(eChamber)
{
	static Float:aChamber[3], Float:vChamber[3];
	pev(eChamber, pev_angles, aChamber);
	aChamber[PITCH] -= 90.0;
	aChamber[YAW] -= 180.0;
	angle_to_vector(aChamber, vChamber);
	
	VectorScalSelf(vChamber,8.0);
	static Float:oChamber[3];
	pev(eChamber, pev_origin, oChamber);
	
	static Float:oTraceTo[3];
	VectorSub(oChamber,vChamber,oTraceTo);
	
	static Float:oHit[3];
	static eHit;
	static trHit;
	engfunc(EngFunc_TraceLine, oChamber, oTraceTo, 0, eChamber, trHit);
	eHit = get_tr2(trHit, TraceResult:TR_pHit);
	get_tr2(trHit, TraceResult:TR_vecEndPos, oHit);
	
	if (VectorEqual(oHit, oTraceTo) || !IsValidWorld(eHit))
		return 0;
	
	return 1;
}

IsValidWorld(eEnt)
{
	if (pev_valid(eEnt))
	{
		if ( !(pev(eEnt, pev_flags) & FL_WORLDBRUSH) )
			return 0;
		
		static sHitClass[32];
		pev(eEnt, pev_classname, sHitClass, 31);
		
		if (equal(sHitClass, "func_nobuild"))
			return 0;
		
		
	}
	
	return 1;
}

get_team_teamtype(iTeam)
{
	switch (iTeam)
	{
		case 1:
			return MARINE;
		case 2:
			return ALIEN;
		case 3:
			return MARINE;
		case 4:
			return ALIEN;
	}
	return OTHER;
}

MakeBBox(Float:vBBMin[3], Float:vBBMax[3], Float:vNorm[3], Float:vNewMin[3], Float:vNewMax[3])
{
	static Float:rvBasePoints[8][3];
	static i;
	for (i = 0; i < 8; i++)
	{
		rvBasePoints[i][0] = ((i>>2) % 2)?vBBMin[0]:vBBMax[0];
		rvBasePoints[i][1] = ((i>>1) % 2)?vBBMin[1]:vBBMax[1];
		rvBasePoints[i][2] = (i % 2)?vBBMin[2]:vBBMax[2];
	}
	
	static Float:aEnt[3];
	vector_to_angle(vNorm, aEnt);
	aEnt[PITCH] -= 90.0;
	aEnt[YAW] -= 180.0;
	
	static Float:fPitchSin;
	fPitchSin = sin(aEnt[PITCH]);
	static Float:fPitchCos;
	fPitchCos = cos(aEnt[PITCH]);
	static Float:fYawSin;
	fYawSin = sin(aEnt[YAW]);
	static Float:fYawCos;
	fYawCos = cos(aEnt[YAW]);
	
	//pitch
	static Float:rPointsPostPitch[8][3];
	for (i = 0; i < 8; i++)
	{
		rPointsPostPitch[i][0] = (rvBasePoints[i][0] *  fPitchCos) + (rvBasePoints[i][2] * fPitchSin);
		rPointsPostPitch[i][1] =  rvBasePoints[i][1];
		rPointsPostPitch[i][2] = (rvBasePoints[i][0] * -fPitchSin) + (rvBasePoints[i][2] * fPitchCos);
	}
	
	//yaw
	static Float:rPointsPostYaw[8][3];
	for (i = 0; i < 8; i++)
	{
		rPointsPostYaw[i][0] = (rPointsPostPitch[i][0] *  fYawCos) + (rPointsPostPitch[i][1] * fYawSin);
		rPointsPostYaw[i][1] = (rPointsPostPitch[i][0] * -fYawSin) + (rPointsPostPitch[i][1] * fYawCos);
		rPointsPostYaw[i][2] =  rPointsPostPitch[i][2];
	}
	
	vNewMin = Float:{ 8192.0,  8192.0,  8192.0};
	vNewMax = Float:{-8192.0, -8192.0, -8192.0};
	
	for (i = 0; i < 8; i++)
	{
		static j;
		for (j = 0; j < 3; j++)
		{
			if (vNewMin[j] > rPointsPostYaw[i][j])
				vNewMin[j] = rPointsPostYaw[i][j];
			else if (vNewMax[j] < rPointsPostYaw[i][j])
				vNewMax[j] = rPointsPostYaw[i][j];
		}
	}
	
	//done!
}

CountEntsInRange(Float:oCenter[3], sClass[], Float:fMaxDist)
{
	static iInRange;
	iInRange = 0;
	
	static iCount;
	iCount = ns_get_build(sClass,0,0);
	
	static iNum;
	for (iNum = 1; iNum <= iCount; iNum++)
	{
		static eOther;
		eOther = ns_get_build(sClass, 0, iNum);
		
		static Float:oOther[3];
		pev(eOther, pev_origin, oOther);
		if (vector_distance(oCenter, oOther) <= fMaxDist)
			iInRange++;
	}
	
	return iInRange;
}

Float:Now()
{
	static Float:fNow;
	global_get(glb_time, fNow);
	return fNow;
}
