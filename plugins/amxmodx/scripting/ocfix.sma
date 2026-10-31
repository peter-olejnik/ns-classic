//==================================================================================================
//==================================================================================================
//	Includes

#include <amxmodx>
#include <fakemeta>


//==================================================================================================
//==================================================================================================
//	Compile Parameters

#pragma semicolon	1
#pragma	tabsize		0	//gives a bunch of indentation warnings if left alone


//==================================================================================================
//==================================================================================================
//	Defines

#define VERSION			"1.1"

#define	TRUE			1
#define	FALSE			0

#define NATIVE_DYNAMIC		1

#define PRIV_NEXTATTACK		123
#define LINUX_OFFSET_SMALL	4


//==================================================================================================
//==================================================================================================
//	Macros

#define VectorAddSelf(%1,%2)	%1[0] += %2[0];\
				%1[1] += %2[1];\
				%1[2] += %2[2]

#define	VectorSubSelf(%1,%2)	%1[0] -= %2[0];\
				%1[1] -= %2[1];\
				%1[2] -= %2[2]


//==================================================================================================
//==================================================================================================
//	Enums

enum _:iUser3Values
{
	AVH_USER3_TURRET = 33,
	AVH_USER3_SIEGETURRET,
	
	AVH_USER3_OFFENSE_CHAMBER = 44
};


//==================================================================================================
//==================================================================================================
//	Constants

new Float:g_buildingViewFudge[3] = {0.0, 0.0, 10.0};


//==================================================================================================
//==================================================================================================
//	Global Variables

new g_offsetFudged[2000] = {FALSE, ...};
new g_isRunningSC = FALSE;

//==================================================================================================
//==================================================================================================
//	Forwarded Functions

public plugin_init()
{
	register_plugin("OC Fix", VERSION, "Darkns");
	register_cvar("v_ocfix", VERSION, FCVAR_SERVER);
	
	register_forward(FM_Think, "fmhook_Think");
	register_forward(FM_Think, "fmhook_Think_Post", 1);
}

public plugin_cfg()
{
	if (cvar_exists("v_stickychamb"))
		g_isRunningSC = TRUE;
}


//==================================================================================================
//==================================================================================================
//	Hook Functions

public fmhook_Think(eEnt)
{
	if (pev_valid(eEnt) && IsTurret(eEnt))
	{
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

//==================================================================================================
//==================================================================================================
//Util functions

Float:Now()
{
	static Float:fNow;
	global_get(glb_time, fNow);
	return fNow;
}

IsTurret(eEnt)
{
	new iuser3 = pev(eEnt, pev_iuser3);
	
	switch (iuser3)
	{
		case AVH_USER3_TURRET:
			return TRUE;
		case AVH_USER3_SIEGETURRET:
			return TRUE;
		case AVH_USER3_OFFENSE_CHAMBER:
		{
			return !g_isRunningSC;
		}
	}
	
	return FALSE;
}
