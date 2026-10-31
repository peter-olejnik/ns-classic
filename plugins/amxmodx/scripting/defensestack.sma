/* DC Heal Stacker
 *   for Natural-Selection
 * 
 * Copyright 2007 by sawce
 *
 * 
 * 
 *  This program is free software; you can redistribute it and/or modify it 
 *  under the terms of the GNU General Public License as published by the 
 *  Free Software Foundation; either version 2 of the License, or (at 
 *  your option) any later version. 
 * 
 *  This program is distributed in the hope that it will be useful, but 
 *  WITHOUT ANY WARRANTY; without even the implied warranty of 
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
 *  General Public License for more details. 
 * 
 *  You should have received a copy of the GNU General Public License 
 *  along with this program; if not, write to the Free Software Foundation, 
 *  Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA 
 * 
 *  In addition, as a special exception, the author gives permission to 
 *  link the code of this program with the Half-Life Game Engine ("HL 
 *  Engine") and Modified Game Libraries ("MODs") developed by Valve, 
 *  L.L.C ("Valve"). You must obey the GNU General Public License in all 
 *  respects for all of the code used other than the HL Engine and MODs 
 *  from Valve. If you modify this file, you may extend this exception 
 *  to your version of the file, but you are not obligated to do so. If 
 *  you do not wish to do so, delete this exception statement from your 
 *  version. 
 */ 

/**
 * Known issues:
 *  The idle animation for defense chambers does not play (very moot)
 *  The health ring around some entities may be very slightly off.  The health value is proper, but the display might be off. (very moot)
 */
 
#include <amxmodx>
#include <ns_const>
#include <fakemeta>

enum
{
	AVH_USER3_NONE = 0,					/* 00 */
	AVH_USER3_MARINE_PLAYER,			/* 01 */
	AVH_USER3_COMMANDER_PLAYER,			/* 02 */
	AVH_USER3_ALIEN_PLAYER1,			/* 03 */
	AVH_USER3_ALIEN_PLAYER2,			/* 04 */
	AVH_USER3_ALIEN_PLAYER3,			/* 05 */
	AVH_USER3_ALIEN_PLAYER4,			/* 06 */
	AVH_USER3_ALIEN_PLAYER5,			/* 07 */
	AVH_USER3_ALIEN_EMBRYO,				/* 08 */
	AVH_USER3_SPAWN_TEAMONE,			/* 09 */
	AVH_USER3_SPAWN_TEAMTWO,			/* 10 */
	AVH_USER3_PARTICLE_ON,				/* 11 */
	AVH_USER3_PARTICLE_OFF,				/* 12 */
	AVH_USER3_WELD,						/* 13 */
	AVH_USER3_ALPHA,					/* 14 */
	AVH_USER3_MARINEITEM,				/* 15 */
	AVH_USER3_WAYPOINT,					/* 16 */
	AVH_USER3_HIVE,						/* 17 */
	AVH_USER3_NOBUILD,					/* 18 */
	AVH_USER3_USEABLE,					/* 19 */
	AVH_USER3_AUDIO_ON,					/* 20 */
	AVH_USER3_AUDIO_OFF,				/* 21 */
	AVH_USER3_FUNC_RESOURCE,			/* 22 */
	AVH_USER3_COMMANDER_STATION,		/* 23 */
	AVH_USER3_TURRET_FACTORY, 			/* 24 */
	AVH_USER3_ARMORY, 					/* 25 */
	AVH_USER3_ADVANCED_ARMORY,			/* 26 */
	AVH_USER3_ARMSLAB,					/* 27 */
	AVH_USER3_PROTOTYPE_LAB, 			/* 28 */
	AVH_USER3_OBSERVATORY,				/* 29 */
	AVH_USER3_CHEMLAB,					/* 30 */
	AVH_USER3_MEDLAB,					/* 31 */
	AVH_USER3_NUKEPLANT,				/* 32 */
	AVH_USER3_TURRET,					/* 33 */
	AVH_USER3_SIEGETURRET,				/* 34 */
	AVH_USER3_RESTOWER,					/* 35 */
	AVH_USER3_PLACEHOLDER,				/* 36 */
	AVH_USER3_INFANTRYPORTAL,			/* 37 */
	AVH_USER3_NUKE,						/* 38 */
	AVH_USER3_BREAKABLE,				/* 39 */
	AVH_USER3_UMBRA,					/* 40 */
	AVH_USER3_PHASEGATE,				/* 41 */
	AVH_USER3_DEFENSE_CHAMBER,			/* 42 */
	AVH_USER3_MOVEMENT_CHAMBER,			/* 43 */
	AVH_USER3_OFFENSE_CHAMBER,			/* 44 */
	AVH_USER3_SENSORY_CHAMBER,			/* 45 */
	AVH_USER3_ALIENRESTOWER,			/* 46 */
	AVH_USER3_HEAVY,					/* 47 */
	AVH_USER3_JETPACK,					/* 48 */
	AVH_USER3_ADVANCED_TURRET_FACT,		/* 49 */
	AVH_USER3_SPAWN_READYROOM,			/* 50 */
	AVH_USER3_CLIENT_COMMAND,			/* 51 */
	AVH_USER3_FUNC_ILLUSIONARY,			/* 52 */
	AVH_USER3_MENU_BUILD,				/* 53 */
	AVH_USER3_MENU_BUILD_ADVANCED,		/* 54 */
	AVH_USER3_MENU_ASSIST,				/* 55 */
	AVH_USER3_MENU_EQUIP,				/* 56 */
	AVH_USER3_MINE,						/* 57 */
	AVH_USER3_MAX 						/* 58 */
};



/* cvar pointers */
new mp_dchealtime;
new mp_dchealamount;
new mp_dchealpercent;
new mp_dchealtargets;
new mp_dchealradius;
new mp_dcenabled;
new mp_dcrequirehives;

new ActiveHiveCount[5];

/* Saved parameters to not require passing extra parameters. */
new Float:HealAmount;
new Float:HealPercent;
new HealTarget;
new Regeneration;

new MaxArmor[9][4] = 
{
	/* base    cara1   cara2   cara3 */
	{	0,		0,		0,		0	}, 		/* buffer */
	{	0,		0,		0,		0	}, 		/* buffer */
	{	0,		0,		0,		0	}, 		/* buffer */
	{	10, 	16,		23,		30	},		/* skulk */
	{	70,		86,		103,	120	},		/* gorge */
	{	30,		40,		50,		60	},		/* lerk */
	{	150,	183,	216,	250	},		/* fade */
	{	600,	716,	833,	950 },		/* onos */
	{	150,	150,	150,	150 }		/* gestate */
};

/* Set to 0 if this entity should not be healed by a DC - I include marine structures because a same team DC heals same team marine structures in base NS 
 * Some of the marine values may be off, but they're probably never used in any maps.
 */
new Float:MaxHealth[AVH_USER3_MAX] =
{
	0.0,		/* none */
	100.0,		/* marine */
	0.0,		/* commander */
	70.0,		/* skulk */
	150.0,		/* gorge */
	125.0,		/* lerk */
	300.0,		/* fade */
	950.0,		/* onos */
	200.0,		/* gestate */
	0.0,		/* team1 spawn */
	0.0,		/* team2 spawn */
	0.0,		/* particle */
	0.0,		/* particle */
	0.0,		/* weldable */
	0.0,		/* alpha */
	0.0,		/* marine item */
	0.0,		/* waypoint */
	7000.0,		/* hive */
	0.0,		/* nobuild */
	0.0,		/* usable */
	0.0,		/* audio on */
	0.0,		/* audio off */
	0.0,		/* func_resource */
	10000.0,	/* comm station */
	3000.0,		/* turret fact */
	2400.0,		/* armory */
	2400.0, 	/* adv armory */
	2200.0,		/* armslab */
	4000.0,		/* proto lab */
	1700.0,		/* observatory */
	0.0,		/* chem lab */
	0.0,		/* med lab */
	0.0,		/* nuke plant */
	1200.0,		/* turret */
	2000.0,		/* siege */
	5500.0,		/* marine rt */
	0.0,		/* placeholder */
	2500.0,		/* infantry portal */
	0.0,		/* nuke */
	0.0,		/* breakable */
	0.0,		/* umbra */
	3000.0,		/* phase gate */
	1200.0,		/* defense chamber */
	1000.0,		/* movement health */
	1100.0,		/* offense chamber */
	800.0,		/* sensory health */
	2500.0,		/* alien res tower */
	0.0,		/* heavy */
	0.0,		/* jetpack */
	3000.0,		/* advanced tf */
	0.0,		/* ready room spawn */
	0.0,		/* client command?? */
	0.0,		/* func_illusionary */
	0.0,		/* menu build */
	0.0,		/* menu advanced */
	0.0,		/* menu assist */
	0.0,		/* menu equip */
	0.0			/* mine - don't know amt */
	
};


public plugin_precache()
{
	register_forward ._post=1, ._forwardType=FM_PrecacheEvent, ._function="ForwardPrecacheEvent_Post";
}

/** 
 * Find the events/Regeneration.sc event index for playback of the heal sound.
 */
public ForwardPrecacheEvent_Post(type, const name[])
{
	if (strcmp(.ignorecase=1, .string1=name, .string2="events/Regeneration.sc")==0)
	{
		Regeneration=get_orig_retval();
	}
	
	return FMRES_IGNORED;
}
public plugin_init()
{

	/* Whether the plugin is enabled. */
	mp_dcenabled=		register_cvar("mp_dcenabled","2");
	
	/* The duration between each heal. */
	mp_dchealtime=		register_cvar("mp_dchealtime","2");
	
	/* The base amount of each heal. */
	mp_dchealamount=	register_cvar("mp_dchealamount","10");
	
	/* A maximum health percentage amount of each heal. Use a float percentage (eg: 0.01 = 1%, 0.03 = 3%) */
	mp_dchealpercent=	register_cvar("mp_dchealpercent","0");
	
	/* The maximum amount of targets healed each duration. */
	mp_dchealtargets=	register_cvar("mp_dchealtargets","3");
	
	/* The radius that the defensechamber can heal from. */
	mp_dchealradius=	register_cvar("mp_dchealradius","400");
	
	/* Whether or not hives are required for defense chambers to operate.  This will probably not operate properly on AvA maps. */
	mp_dcrequirehives=	register_cvar("mp_dcrequirehives","0");
	
	register_plugin .author="sawce", .version="1.0", .plugin_name="DC Heal Stacker";
	
	register_srvcmd .function="dc_plugininit", .server_cmd="dc_plugininit";
	server_cmd "dc_plugininit";
	
}
/**
 * I do this very delayed initialization to pretty much ensure this is loaded after all config files.
 * It doesn't matter much for this plugin since DC's wont be up until at least 30 seconds into the map.
 */
public dc_plugininit()
{
	set_task .function="LateInitialize", .time=10.0;
}

#define ENABLED_EXPLICIT		(1<<0)
#define ENABLED_NAME			(1<<1)
#define ENABLED_DISTANCE		(1<<2)
#define ENABLED_NO_COMBAT		(1<<3)

public LateInitialize()
{
	/* Check to see if I'm enabled or not. */
	
	new bool:enabled=false;
	
	new MapName[32];
	get_mapname .len=sizeof MapName -1, .name=MapName;

	new EnabledFlags=get_pcvar_num(mp_dcenabled);
	
	/* Plugin is explicitly enabled by default.  NO_COMBAT can override this. */
	if (EnabledFlags & ENABLED_EXPLICIT)
	{
		enabled=true;
		goto nocombat_check;
	}
	
	/* Plugin is enabled if the map name contains the word "siege". */
	if (EnabledFlags & ENABLED_NAME)
	{
		if (containi(.string=MapName, .source="siege")!=-1)
		{
			enabled=true;
		}
	}
	
	/* Plugin is enabled if all of the hives are less than 1024 units from each other. */
	if (EnabledFlags & ENABLED_DISTANCE)
	{
		/* This check would be silly to do on combat maps, so get out of here if combat. */
		if (equali(.b=MapName, .c=3, .a="co_")==1)
		{
			goto nocombat_check;
		}
	
	
		new Float:Origins[3][3];
		new bool:HiveTooFar;
		new Ent=0;
		new HiveCount=0;
		new const Float:HiveDetectionDistance=1024.0;

		/* Mark down origins for all of the hives (3 max). */
		while ((Ent=engfunc(EngFunc_FindEntityByString,Ent,"classname","team_hive"))!=0)
		{
			pev Ent, pev_origin, Origins[HiveCount++];
			if (HiveCount==3)
			{
				break;
			}
		}
		
		/* Compare distances. */
		while (HiveCount--)
		{
			if (get_distance_f(Origins[HiveCount],Origins[0])>=HiveDetectionDistance)
			{
				HiveTooFar=true;
			}
			if (get_distance_f(Origins[HiveCount],Origins[1])>=HiveDetectionDistance)
			{
				HiveTooFar=true;
			}
			if (get_distance_f(Origins[HiveCount],Origins[2])>=HiveDetectionDistance)
			{
				HiveTooFar=true;
			}
			
			/* Every hive passes the 1024 unit test. */
			if (!HiveTooFar)
			{
				enabled=true;
			}
		}

	}
	
nocombat_check:
	/* Plugin is disabled on combat. */
	if (EnabledFlags & ENABLED_DISTANCE)
	{
		/* This check would be silly to do on combat maps, so get out of here if combat. */
		if (equali(.b=MapName, .c=3, .a="co_")==1)
		{
			enabled=false;
		}
	}
	
	
	if (enabled)
	{
		register_forward ._function="ForwardThink", ._forwardType=FM_Think;
		set_task .function="CheckActiveHives", .time=4.0, .flags="b";
	}
	else
	{
		register_plugin .author="sawce", .version="1.0", .plugin_name="DC Heal Stacker (OFF)";
		pause "ad";
	}
}

public CheckActiveHives()
{
	if (get_pcvar_float(mp_dcrequirehives)!=0.0)
	{
		arrayset(.size=sizeof(ActiveHiveCount), .value=0, .array=ActiveHiveCount);
		
		new Ent=0;
		
		new Team;
		
		while ((Ent=engfunc(EngFunc_FindEntityByString,Ent,"classname","team_hive"))!=0)
		{
			if (pev(._value=pev_fuser1, ._index=Ent)>=1000)
			{
				Team=pev(._value=pev_team, ._index=Ent);
				
				if (Team>=0 && Team<=4)
				{
					ActiveHiveCount[Team]++;
				}
			}
		}
	}
}
/**
 * Plays the heal sound, and compensates for silence levels.
 */
stock PlayHealSound()
{
	/* Silence 1 is 50% volume, silence 2 is 15% volume, silence 3 is 0% volume. */
	new Float:Volume=1.00;
	
	new iuser3=pev(._value=pev_iuser3,._index=HealTarget);

	/* Don't need to check bounds here, but just make sure it's a valid player. */

	if (iuser3 >= AVH_USER3_ALIEN_PLAYER1 && iuser3 <= AVH_USER3_ALIEN_EMBRYO)
	{
		new iuser4=pev(._value=pev_iuser4,._index=HealTarget);

		if (iuser4 & MASK_SILENCE)
		{
			Volume=0.5;
			
			if (iuser4 & MASK_MOVEMENT2)
			{
				Volume=0.15;
			}
			if (iuser4 & MASK_MOVEMENT3)
			{
				Volume=0.0;
			}
		}

	}
	
	/* NS sets the volume of the event as fparam1.  It also plays the event even if volume is 0 (so I will too, just incase it has some hidden meaning) */
	/* PlaybackEvent(flags (always 0 in NS), entity, eventid, Float:delay (always 0.0), origin[3], angles[3] (always 0.0,0.0,0.0_), fparam1 (volume), fparam2 (0), iparam1(0), iparam2(0), bparam1(0), bparam2(0)); */

	static Float:Origin[3];
	
	pev HealTarget, pev_origin, Origin;
	engfunc EngFunc_PlaybackEvent,0, HealTarget, Regeneration, 0.0, Origin, {0.0, 0.0, 0.0}, Volume, 0.0, 0, 0, 0, 0;
}
/**
 * Returns the maximum armor for an entity.
 * Uses the global HealTarget parameter for the index to heal.
 */
stock GetMaxArmor()
{
	/* Only players have armor. */
	new iuser3=pev(HealTarget,pev_iuser3);
	if (iuser3 < AVH_USER3_ALIEN_PLAYER1 || iuser3 > AVH_USER3_ALIEN_EMBRYO)
	{
		return 0;
	}
	
	new field=0; /* The field in the array to use. (How many DCs the player has powering his carapace) */
	new iuser4=pev(HealTarget,pev_iuser4);

	if (iuser4 & MASK_CARAPACE)
	{
		field=1;
		
		if (iuser4 & MASK_DEFENSE2)
		{
			field=2;
		}
		if (iuser4 & MASK_DEFENSE3)
		{
			field=3;
		}
	}
	
	return MaxArmor[iuser3][field];
	
}

/**
 * Recalculates the entity's fuser2 field.
 * fuser2 is the client display of an entity's 
 * health percentage * 1000.0.
 * This is not done on hives.
 */
stock CalculateNewFUser2(Float:NewHealth)
{
	new iuser3=pev(HealTarget,pev_iuser3);
	if (iuser3 < 0 || iuser3 > AVH_USER3_MAX || iuser3 == AVH_USER3_HIVE)
	{
		return;
	}
	
	new Float:Max=MaxHealth[iuser3];
	
	set_pev HealTarget,pev_fuser2, (NewHealth / Max) * 1000.0;
	
}
/**
 * Returns the maximum health for an entity.
 * If the target is an alien player, use the array.
 * Otherwise, use pev->max_health.
 */
stock Float:GetMaxHealth()
{
	new iuser3=pev(._value=pev_iuser3,._index=HealTarget);
	if (iuser3 < 0 || iuser3 > AVH_USER3_MAX)
	{
		return 0.0;
	}

	/* Player */
	if (iuser3 <= AVH_USER3_ALIEN_EMBRYO)
	{
		return MaxHealth[iuser3];
	}
	
	/* Structure */
	new Float:fuser1;
	/* fuser2 is health% (I THINK!) */
	/* fuser1 is build% */
	/* Hive health % is not set, have to calculate as if it's unbuilt. */
	pev HealTarget, pev_fuser1, fuser1;
	
	/* After much testing it appears NS's defensechamber does not heal building structures (wont even heal building hives!).  
	 * I won't either then.  I would add a cvar for this, but it's far too much work for very little gain. 
	 */
	if (fuser1 < 1000.0)
	{
		return 0.0;
	}

	return MaxHealth[iuser3];

}
/**
 * Heals the target.  Target is stored as the global variable HealTarget, amount is "HealAmount", and percentage is "HealPercentage"
 *
 * @return			true if the target was healed, false otherwise.
 */
stock bool:HealEntity()
{
	/* First check to see if this target actually needs healed. */
	new Float:MaxHealth=GetMaxHealth();
	
	if (MaxHealth==0.0)
	{
		return false;
	}
	new Float:Health;
	pev HealTarget, pev_health, Health;
	
	new Float:Armor;
	
	pev HealTarget, pev_armorvalue, Armor;
	new MaxArmor=GetMaxArmor();
	
	/* This target does not need healed. */
	if (Health>=MaxHealth && Armor>=MaxArmor)
	{
		return false;
	}
	
	/* Calculate the amount to heal. */
	new Float:HealthToHeal=(MaxHealth * HealPercent) + HealAmount;
	
	
	PlayHealSound();
	
	/* Now check to see if I need health or armor healed. */
	if (Health<MaxHealth)
	{
		/* Need to heal health. */
		Health+=HealthToHeal;
		
		if (Health>MaxHealth)
		{
			Health=MaxHealth;
		}
		
		set_pev HealTarget, pev_health, Health;
		CalculateNewFUser2 Health;
		return true;
	}
	
	Armor+=HealthToHeal;
	
	if (Armor>MaxArmor)
	{
		Armor=float(MaxArmor);
	}
	
	set_pev HealTarget, pev_armorvalue, Armor;
	
	return true;
}
/**
 * The actual heal routine.  This is called directly from think.
 * 
 * @param id			Assumed to be fully built, and operational defensechamber.
 */
stock SimulateDCHeal(id)
{
	/* Only heal entities with a pev->team field the same as this chamber. */
	
	new MyTeam=pev(._value=pev_team, ._index=id);				/* The defense chamber's team field. */
	HealTarget=0;												/* Iterator for the FindEntInSphere loop. */
	new HealsLeft=get_pcvar_num(mp_dchealtargets);				/* How many heals I have left in me for this tick. */
	HealAmount=get_pcvar_float(mp_dchealamount);				/* How much raw health to heal each tick. */
	HealPercent=get_pcvar_float(mp_dchealpercent);				/* How much of a percentage to heal each entity. */
	new Float:HealRadius=get_pcvar_float(mp_dchealradius);		/* The radius of the heal from the defensechamber. */

	if (HealsLeft > 0 && AreDCsActive(MyTeam))
	{
		/* Scan for entities around this defensechamber. */
		static Float:Origin[3];
		pev(id,pev_origin,Origin);
		
		while ((HealTarget=engfunc(EngFunc_FindEntityInSphere,HealTarget,Origin,HealRadius))!=0)
		{
			/* If it's not myself (defensechambers never heal themselves) and it's on my team, then heal it. */
			if (HealTarget != id && pev(._value=pev_deadflag, ._index=HealTarget)==0 && pev(._value=pev_team, ._index=HealTarget)==MyTeam)
			{
				if (HealEntity())
				{
					if (--HealsLeft == 0)
					{
						break;
					}
				}
			}
		}
		
	}
	
	/* Make me think again in mp_dchealtime seconds. */
	new Float:NextThink;
	
	global_get glb_time, NextThink;
	
	NextThink+=get_pcvar_float(mp_dchealtime);
	
	set_pev id, pev_nextthink, NextThink;
}

/**
 * Returns whether or not the defense chamber should be active.
 * This varies depending on the mp_dcrequirehives setting.
 * If the cvar is anything other than 0, then it requires a
 * fully operational hive on the team for the defensechamber 
 * to function.
 *
 * @param Team		The team to count hives for.
 * @return			true if the defensechamber should be considered active, false otherwise.
 */
stock bool:AreDCsActive(Team)
{
	if (get_pcvar_float(mp_dcrequirehives)!=0.0)
	{
		if (Team>=0 && Team<=4)
		{
			if (ActiveHiveCount[Team]>0)
			{
				/* Has at least one active hive. */
				return true;
			}
			
			/* Has no active hive. */
			return false;
		}
	}
	
	/* defensechambers do not require hives to operate. */
	return true;
}

/**
 * General think hooking.  Make sure it's a valid defensechamber and call SimulateDCHeal
 *
 * @param id		Index of the entity thinking.
 */
public ForwardThink(id)
{
	if (!pev_valid(id))
	{
		return FMRES_IGNORED;
	}
	/* Fastest possible check if this is a defensechamber or not.
	 * Could potentially conflict with some custom entities, but
	 * NS uses iuser3 for its itemtype field. Custom ents should 
	 * be avoiding setting their iuser3.
	 */
	if (pev(._value=pev_iuser3, ._index=id)==AVH_USER3_DEFENSE_CHAMBER)
	{
		/* Make sure the defensechamber is built. */
		if (pev(._value=pev_fuser1, ._index=id)>=1000) /* pev() casts floats to integers if requested like this */
		{
			/* Fully built. */
			SimulateDCHeal .id=id;
			
			return FMRES_SUPERCEDE;
		}

	}
	
	return FMRES_IGNORED;
}
