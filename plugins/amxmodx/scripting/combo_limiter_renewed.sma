/* 
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
* Original Code
*
* Combo Limiter
* Copyright © 2006  KCE
* 
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License
* as published by the Free Software Foundation; either version 2
* of the License, or (at your option) any later version.
* 
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
* 
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
* 
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
* New Code
*
* Combo Limiter Renewed
* Copyright © 2008	NeoMatrix99.j2 also known as NeoMatrix99, Daemonmatrix, Classof2001, or 187combat | NeoMatrix99.j2
* 
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License
* as published by the Free Software Foundation; either version 3
* of the License, or (at your option) any later version.
* 
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
* 
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
* 
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*
* Title : Combo Limiter Renewed
* 
* Original Author : KCE
* New Author: NeoMatrix99.j2
*  
* Original Credits :
*		CombalanceXX by Joe "Lord Skitch" Jackson - Time blocking
*		Blocker by -j00- Clan - Proportion blocking
*		ClassCTRL by Darkness - Other checks and misc.
*		Combat Limiter by ZeroX4 - Other checks and misc.
*
* New Credits:
*		Combo Limiter by KCE - Original Base Code
*		Extralevels3 by White_Panther - Level detection, death detection, 
*		Combat Buildings by Endgame - Team change detection, rather smart I say
*		Cronos101 - For the time based slot add/remove request
*
* Version : 2.1
* 
* Cvars (name/default value/description) : 
*		amx_combolimit (1) - Enable/Disable limiter
*
*		climit_*_* 
*
*		I.E. : limit_gorge_max, limit_gorge_min,...
*
*		Where the first * is either - gorge, lerk, fade, onos, jp, ha, hmg, gl, sg
*
*		And the second * is either -  max, min, prop, wait, lvl, frags, slot_mintime, timeinterval, slot_interval, or max_interval - where:
*			max - Maximum people allowed to get that upgrade
*			min - Minimum amount of people on the opposite team required to get that upgrade
*			prop - The ratio of marines/aliens required to get that upgrade
*					Example: For 1:3 Onos to Marine ratio, 1 onos for every 3 marines...
*							limit_onos_prop 3
*			wait - Time in minutes before upgrade is unblocked
*			lvl - Minimum level required to get that upgrade
*			frags - Minimum amount of kills required to get that upgrade
*			slot_mintime - min time into a game that you want slot(s) to be added/removed, set to
*				0 or below to disable slots over time.
*			timeinterval - amount of time before additional slot(s) are added/removed
*			slot_interval - amount of slot(s) you want to add/remove, positive number to add and negative to remove
*							ex. setting to 1 will add one slot to max allowed (even if 0 set max to -1 to disabled)
*							ex. Setting to -1 will remove one slot from max allowed (only if set to 1 or above)
*			max_interval - max amount of times you want to add/remove slot(s)
*
*
*		Set to -1 to disable that check
*		If prop is set -1 or 0 it'll disable that check (doesn't make sense if you need 0 ratio of people to go gorge)
*		If min is set -1 or 0 it'll disable that check (doesn't make sense if you need 0 people to go gorge)
*		
*		***Setting max to 0 will disable that upgrade unless you have slot_mintime and slot_interval setup to add slot(s)***
*
* Cmds : 
*
*
* History :
*		v1.0	- 	Initial Release
*		v1.1	-	Updated for Bots
*		v1.2	-	Major revision, now actually works
*		v1.3	-	Fixed some more things
*		v1.4	- 	Now works with latest version of amxmodx (1.55/1.60)
*		v1.4.1	- 	Fixed onos bug
*		v1.5	-	Updated
*		v1.6	-	Fixed HMG cvar typos
*		v1.7	-	Disabled on classic NS
*				-	Changed cvars to defines
*				-	Added limiters for Shotgun
*		v1.8	-	Removed focus fade limiter
*				-	Fixed runtime errors
*		v2.0	2-2-2008 - Combo Limiter Renewed
*				-	Practically re-written by NeoMatrix99.j2
*				-	Fixed all known methods of bypassing max setting
*				-	Entered code that detects level and points available
*					based on Extralevels3 default level exp.
*				-	Added new time based add/remove max slot option
*					-	Can now add or remove slots after a minimum amount
*						of time and then add or remove more at set intervals
*				-	Fixed possible exploit found after new block methods
*						installed
*				-	Added access call to allow admins to bypass limits
*						Set with ADMIN_EXCLUSION_FLAG
*		v2.1	12-24-2008
*				-	Added failed gestate check
*				-	Fixed possible exploit involving RR
*				-	Fixed excluded admin not being counted towards limits
*				-	Fixed bug with marines not being able to buy armor two, jp, or heavy
*				-	Fixed big with marines not being able to buy shotty, hmg, or gl
*				-	Fixed bug in heavy lock
*		v2.2	12-26-2008
*				-	Fixed missing check against disabled blocks
*		v2.3	12-30-2008
*				-	Fixed new bug intrduced by my previous fix
*				-	Reduced code by 130ish lines
*				
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*/

#include < amxmodx >
#include < engine >
#include < ns >
#include < fakemeta >

#define ADMIN_EXCLUSION_FLAG ADMIN_LEVEL_C

///////////////
//Begin Editing

#define GORGE_SLOTMINTIME "0"
#define LERK_SLOTMINTIME "0"
#define FADE_SLOTMINTIME "0"
#define ONOS_SLOTMINTIME "0"
	
#define GORGE_INTERVAL "0"
#define LERK_INTERVAL "0"
#define FADE_INTERVAL "0"
#define ONOS_INTERVAL "0"
	
#define GORGE_SLOT_INTERVAL "0"
#define LERK_SLOT_INTERVAL "0"
#define FADE_SLOT_INTERVAL "0"
#define ONOS_SLOT_INTERVAL "0"
	
#define GORGE_MAX_INTERVAL "0"
#define LERK_MAX_INTERVAL "0"
#define FADE_MAX_INTERVAL "0"
#define ONOS_MAX_INTERVAL "0"
	
#define GORGE_MAX  "-1"
#define LERK_MAX   "-1"
#define FADE_MAX   "-1"
#define ONOS_MAX   "4"

#define GORGE_MIN "-1"
#define LERK_MIN   "-1"
#define FADE_MIN   "3"
#define ONOS_MIN   "5"

#define GORGE_PROP "-1"
#define LERK_PROP  "-1"
#define FADE_PROP  "-1"
#define ONOS_PROP  "3"

#define GORGE_WAIT "-1"
#define LERK_WAIT  "-1"
#define FADE_WAIT  "-1"
#define ONOS_WAIT  "-1"

#define GORGE_LVL "-1"
#define LERK_LVL  "-1"
#define FADE_LVL  "-1"
#define ONOS_LVL  "-1"

#define GORGE_FRAGS "-1"
#define LERK_FRAGS  "-1"
#define FADE_FRAGS  "-1"
#define ONOS_FRAGS  "-1"

#define JP_SLOTMINTIME "0"
#define HA_SLOTMINTIME "0"
#define HMG_SLOTMINTIME "0"
#define GL_SLOTMINTIME "0"
#define SG_SLOTMINTIME "0"

#define JP_INTERVAL "0"
#define HA_INTERVAL "0"
#define HMG_INTERVAL "0"
#define GL_INTERVAL "0"
#define SG_INTERVAL "0"
	
#define JP_SLOT_INTERVAL "0"
#define HA_SLOT_INTERVAL "0"
#define HMG_SLOT_INTERVAL "0"
#define GL_SLOT_INTERVAL "0"
#define SG_SLOT_INTERVAL "0"
	
#define JP_MAX_INTERVAL "0"
#define HA_MAX_INTERVAL "0"
#define HMG_MAX_INTERVAL "0"
#define GL_MAX_INTERVAL "0"
#define SG_MAX_INTERVAL "0"

#define JP_MAX 	 "-1"
#define HA_MAX 	 "-1"
#define HMG_MAX  "-1"
#define GL_MAX 	"4"
#define SG_MAX 	"-1"

#define JP_MIN 	"3"
#define HA_MIN 	"5"
#define HMG_MIN "-1"
#define GL_MIN 	"-1"
#define SG_MIN 	"-1"

#define JP_PROP	 "-1"
#define HA_PROP	 "-1"
#define HMG_PROP "-1"
#define GL_PROP  "3"
#define SG_PROP  "-1"

#define JP_WAIT  "-1"
#define HA_WAIT	 "-1"
#define HMG_WAIT "-1"
#define GL_WAIT	 "3"
#define SG_WAIT	 "-1"

#define JP_LVL 	"-1"
#define HA_LVL 	"-1"
#define HMG_LVL "-1"
#define GL_LVL 	"-1"
#define SG_LVL 	"-1"

#define JP_FRAGS  "-1"
#define HA_FRAGS  "-1"
#define HMG_FRAGS "-1"
#define GL_FRAGS  "-1"
#define SG_FRAGS  "-1"

//End editing
/////////////

//Do not edit these
///////////////////////////

#define IMPULSE_GORGE		114
#define IMPULSE_LERK		115
#define IMPULSE_FADE		116
#define IMPULSE_ONOS		117

#define IMPULSE_JP			39
#define	IMPULSE_HA			38
#define IMPULSE_SG			64
#define IMPULSE_HMG			65
#define IMPULSE_GL			66

#define IMPULSE_ARMORONE	20
#define IMPULSE_ARMORTWO	21
#define IMPULSE_WEAPONS1	23

////////////////////////////

new Float: g_startTime;
new g_maxPlayers;
new	gorgeuser[33];
new	lerkuser[33];
new	fadeuser[33];
new	onosuser[33];
new	jetpackuser[33];
new	heavyuser[33];
new	sguser[33];
new	gluser[33];
new	hmguser[33];
new	heavylock[33];
new	jetpacklock[33];
new	sglock[33];
new	gllock[33];
new	hmglock[33];
new	heavyready[33];
new	jetpackready[33];
new	sgready[33];
new	glready[33];
new	hmgready[33];
new currentlevel[33];
new pointstospend[33];
new armor2ready[33];
public plugin_init()
{
	register_plugin( "Combo Limiter Renewed", "2.3", "NeoMatrix99.j2" );
	
	if ( !ns_is_combat() )	
		return PLUGIN_CONTINUE;
	
	register_cvar( "amx_combolimit", "1" );

	//ALIENS
	register_cvar( "climit_gorge_slot_mintime" , GORGE_SLOTMINTIME );
	register_cvar( "climit_lerk_slot_mintime" , LERK_SLOTMINTIME );
	register_cvar( "climit_fade_slot_mintime" , FADE_SLOTMINTIME );
	register_cvar( "climit_onos_slot_mintime" , ONOS_SLOTMINTIME );
	
	register_cvar( "climit_gorge_timeinterval" , GORGE_INTERVAL );
	register_cvar( "climit_lerk_timeinterval" , LERK_INTERVAL );
	register_cvar( "climit_fade_timeinterval" , FADE_INTERVAL );
	register_cvar( "climit_onos_timeinterval" , ONOS_INTERVAL );
	
	register_cvar( "climit_gorge_slot_interval" , GORGE_SLOT_INTERVAL );
	register_cvar( "climit_lerk_slot_interval" , LERK_SLOT_INTERVAL );
	register_cvar( "climit_fade_slot_interval" , FADE_SLOT_INTERVAL );
	register_cvar( "climit_onos_slot_interval" , ONOS_SLOT_INTERVAL );
	
	register_cvar( "climit_gorge_max_interval" , GORGE_MAX_INTERVAL );
	register_cvar( "climit_lerk_max_interval" , LERK_MAX_INTERVAL );
	register_cvar( "climit_fade_max_interval" , FADE_MAX_INTERVAL );
	register_cvar( "climit_onos_max_interval" , ONOS_MAX_INTERVAL );
	
	register_cvar( "climit_gorge_max" , GORGE_MAX );
	register_cvar( "climit_lerk_max" , LERK_MAX );
	register_cvar( "climit_fade_max" , FADE_MAX );
	register_cvar( "climit_onos_max" , ONOS_MAX );

	register_cvar( "climit_gorge_min" , GORGE_MIN );
	register_cvar( "climit_lerk_min" , LERK_MIN );
	register_cvar( "climit_fade_min" , FADE_MIN );
	register_cvar( "climit_onos_min" , ONOS_MIN );

	register_cvar( "climit_gorge_prop" , GORGE_PROP );
	register_cvar( "climit_lerk_prop" , LERK_PROP );
	register_cvar( "climit_fade_prop" , FADE_PROP );
	register_cvar( "climit_onos_prop" , ONOS_PROP );

	register_cvar( "climit_gorge_wait" , GORGE_WAIT );
	register_cvar( "climit_lerk_wait" , LERK_WAIT );
	register_cvar( "climit_fade_wait" , FADE_WAIT );
	register_cvar( "climit_onos_wait" , ONOS_WAIT );

	register_cvar( "climit_gorge_lvl" , GORGE_LVL );
	register_cvar( "climit_lerk_lvl" , LERK_LVL );
	register_cvar( "climit_fade_lvl" , FADE_LVL );
	register_cvar( "climit_onos_lvl" , ONOS_LVL );

	register_cvar( "climit_gorge_frags" , GORGE_FRAGS );
	register_cvar( "climit_lerk_frags" , LERK_FRAGS );
	register_cvar( "climit_fade_frags" , FADE_FRAGS );
	register_cvar( "climit_onos_frags" , ONOS_FRAGS );
	
	//MARINES
	register_cvar( "climit_jp_slot_mintime" , JP_SLOTMINTIME );
	register_cvar( "climit_ha_slot_mintime" , HA_SLOTMINTIME );
	register_cvar( "climit_hmg_slot_mintime" , HMG_SLOTMINTIME );
	register_cvar( "climit_gl_slot_mintime" , GL_SLOTMINTIME );\
	register_cvar( "climit_sg_slot_mintime" , SG_SLOTMINTIME );
	
	register_cvar( "climit_jp_timeinterval" , JP_INTERVAL );
	register_cvar( "climit_ha_timeinterval" , HA_INTERVAL );
	register_cvar( "climit_hmg_timeinterval" , HMG_INTERVAL );
	register_cvar( "climit_gl_timeinterval" , GL_INTERVAL );
	register_cvar( "climit_sg_timeinterval" , SG_INTERVAL );
	
	register_cvar( "climit_jp_slot_interval" , JP_SLOT_INTERVAL );
	register_cvar( "climit_ha_slot_interval" , HA_SLOT_INTERVAL );
	register_cvar( "climit_hmg_slot_interval" , HMG_SLOT_INTERVAL );
	register_cvar( "climit_gl_slot_interval" , GL_SLOT_INTERVAL );
	register_cvar( "climit_sg_slot_interval" , SG_SLOT_INTERVAL );
	
	register_cvar( "climit_jp_max_interval" , JP_MAX_INTERVAL );
	register_cvar( "climit_ha_max_interval" , HA_MAX_INTERVAL );
	register_cvar( "climit_hmg_max_interval" , HMG_MAX_INTERVAL );
	register_cvar( "climit_gl_max_interval" , GL_MAX_INTERVAL );
	register_cvar( "climit_sg_max_interval" , SG_MAX_INTERVAL );
	
	register_cvar( "climit_jp_max" , JP_MAX );
	register_cvar( "climit_ha_max" , HA_MAX );
	register_cvar( "climit_hmg_max" , HMG_MAX );
	register_cvar( "climit_gl_max" , GL_MAX );
	register_cvar( "climit_sg_max" , SG_MAX );

	register_cvar( "climit_jp_min" , JP_MIN );
	register_cvar( "climit_ha_min" , HA_MIN );
	register_cvar( "climit_hmg_min" , HMG_MIN );
	register_cvar( "climit_gl_min" , GL_MIN );
	register_cvar( "climit_sg_min" , SG_MIN );

	register_cvar( "climit_jp_prop" , JP_PROP );
	register_cvar( "climit_ha_prop" , HA_PROP );
	register_cvar( "climit_hmg_prop" , HMG_PROP );
	register_cvar( "climit_gl_prop" , GL_PROP );
	register_cvar( "climit_sg_prop" , SG_PROP );

	register_cvar( "climit_jp_wait" , JP_WAIT );
	register_cvar( "climit_ha_wait" , HA_WAIT );
	register_cvar( "climit_hmg_wait" , HMG_WAIT );
	register_cvar( "climit_gl_wait" , GL_WAIT );
	register_cvar( "climit_sg_wait" , SG_WAIT );

	register_cvar( "climit_jp_lvl" , JP_LVL );
	register_cvar( "climit_ha_lvl" , HA_LVL );
	register_cvar( "climit_hmg_lvl" , HMG_LVL );
	register_cvar( "climit_gl_lvl" , GL_LVL );
	register_cvar( "climit_sg_lvl" , SG_LVL );

	register_cvar( "climit_jp_frags" , JP_FRAGS );
	register_cvar( "climit_ha_frags" , HA_FRAGS );
	register_cvar( "climit_hmg_frags" , HMG_FRAGS );
	register_cvar( "climit_gl_frags" , GL_FRAGS );
	register_cvar( "climit_sg_frags" , SG_FRAGS );

	register_impulse( IMPULSE_GORGE, "gorgeCheck" );
	register_impulse( IMPULSE_LERK, "lerkCheck" );
	register_impulse( IMPULSE_FADE, "fadeCheck" );
	register_impulse( IMPULSE_ONOS, "onosCheck" );
	
	register_impulse( IMPULSE_JP, "jpCheck" );
	register_impulse( IMPULSE_HA, "haCheck" ); 
	register_impulse( IMPULSE_HMG, "hmgCheck" );
	register_impulse( IMPULSE_GL, "glCheck" );
	register_impulse( IMPULSE_SG, "sgCheck" );
	register_impulse( IMPULSE_ARMORONE, "armorone" );
	register_impulse( IMPULSE_ARMORTWO, "armortwo" );
	register_impulse( IMPULSE_WEAPONS1, "weapons" );
	
	register_event("DeathMsg", "event_Death", "a");
	register_event( "Countdown" , "gameStarting", "a" );
	
	
	g_maxPlayers = get_maxplayers();
	
	return PLUGIN_CONTINUE;
}

public getpoints( id )
{
	new points = ns_get_points(id);
	new Float:xp = ns_get_exp(id);
	currentlevel[id] = (floatround(floatsqroot(xp / 25 + 2.21) - 1))
	pointstospend[id] = ((currentlevel[id] - 1) - points)
	
	if ( currentlevel[id] > 10 )
		pointstospend[id] = (pointstospend[id] - (currentlevel[id] - 10))
	
	return pointstospend[id]
}

public client_disconnect( id )
{
	reset_blocks(id)
	return PLUGIN_HANDLED;
}

public client_connect( id )
{
	reset_blocks(id)
	return PLUGIN_HANDLED;
}

public client_changeteam( id , newteam , oldteam )
{
	if (floatcmp(Float:oldteam, Float:1)|| floatcmp(Float:oldteam, Float:2))
	{
		if ( newteam != oldteam )
			reset_blocks(id)
		return PLUGIN_HANDLED;
	}
	return PLUGIN_HANDLED;
}

public event_Death( )
{
	new victim = read_data(2);
	new class = ns_get_class(victim);
	if (is_user_connected(victim)){
		if ((class == CLASS_MARINE) || (class == CLASS_JETPACK) || (class == CLASS_HEAVY))
			return PLUGIN_HANDLED;
		else
			reset_blocks(victim)
	}
	return PLUGIN_HANDLED;
}

reset_blocks( id )
{
	gorgeuser[id] = 0;
	lerkuser[id] = 0;
	fadeuser[id] = 0;
	onosuser[id] = 0;
	jetpackuser[id] = 0;
	heavyuser[id] = 0;
	sguser[id] = 0;
	gluser[id] = 0;
	hmguser[id] = 0;
	heavylock[id] = 0;
	jetpacklock[id] = 0;
	sglock[id] = 0;
	gllock[id] = 0;
	hmglock[id] = 0;
	heavyready[id] = 0;
	jetpackready[id] = 0;
	sgready[id] = 0;
	glready[id] = 0;
	hmgready[id] = 0;
	armor2ready[id] = 0;
	return PLUGIN_HANDLED;
}


public gameStarting()
{
	g_startTime = get_gametime() + 5.0;
	return PLUGIN_CONTINUE;
}

// *******************************************************
// *******************************************************

public armorone( id )
{
	if (( is_user_alive(id) ) && ( getpoints(id) >= 1 ) && ( is_user_connected(id) ))
	{
		set_pev(id, pev_impulse, 20)
		armor2ready[id] = 1
		return PLUGIN_HANDLED;
	}else{
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	return PLUGIN_HANDLED;
}

// *******************************************************
// *******************************************************

public armortwo( id )
{
	if ((is_user_alive(id)) && ( getpoints(id) >= 1 ) && ( armor2ready[id] == 1 ) && ( is_user_connected(id) ))
	{
		set_pev(id, pev_impulse, 21)
		jetpackready[id] = 1
		heavyready[id] = 1
		return PLUGIN_HANDLED;
	}else{
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	return PLUGIN_HANDLED;
}

// *******************************************************
// *******************************************************

public weapons( id )
{
	if ((is_user_alive(id)) && (getpoints(id) >=1) && ( is_user_connected(id) ))
	{
		set_pev(id, pev_impulse, 23)
		sgready[id] = 1
		return PLUGIN_HANDLED;
	} else
	{
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	return PLUGIN_HANDLED;
}

// *******************************************************
// *******************************************************

public gorgeCheck( id )
{
	if ( (!is_user_alive(id)) || (!is_user_connected(id)) || ( ns_get_class(id) != CLASS_SKULK ) || ( getpoints(id) < 1 ) )
	{
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
		
	if (( !get_cvar_num("amx_combolimit" ) ) || (get_user_flags(id) & ADMIN_EXCLUSION_FLAG))
	{
		set_pev(id, pev_impulse, 114)
		gorgeuser[id] = 1
		return PLUGIN_HANDLED;
	}
	
	new teamID = pev(id, pev_team);
	
	new i, g, m;
	for( i = 1; i <= g_maxPlayers; i++ )
	{
		if ( !is_user_connected( i ) )
			continue;
			
		new teamI = pev(i, pev_team);
		
		if ( (teamI == teamID) && ( gorgeuser[i] == 1 ) && (ns_get_class(i) != CLASS_SKULK) )
		{
			g++;
		}
		
		if ( ( teamI != teamID ) && ( teamI != 0 ) && ( teamI != 6 ) )
		{
			m++;
		}
	}
	
	new Float:wait = get_cvar_float( "climit_gorge_wait" );
	new Float:minsLeft, Float:secsLeft, Float:timeElapse, Float:startTime2, Float:timeRemain;
	startTime2 = get_gametime();
	
	timeRemain = wait * 60;
	
	timeElapse = startTime2 - g_startTime;
	
	if ( (wait > 0) && ( timeElapse < timeRemain ) )		//not clear
	{
		timeRemain = timeRemain - timeElapse;
		minsLeft = ( timeRemain / 60 );
		secsLeft = ( timeRemain - ( floatround( minsLeft, floatround_floor ) * 60 ) );
		client_print( id, print_chat, "[Combo Limiter] %d minutes %d seconds left until Gorge is unblocked" , floatround ( minsLeft, floatround_floor ), floatround( secsLeft ) );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Certain number of kills required
	new frags = get_cvar_num( "climit_gorge_frags" );
	if ( (frags >= 2) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kills are required to go Gorge" , frags );
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( (frags == 1) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kill is required to go Gorge" , frags );
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	
	//Minimum level required
	new reqlvl = get_cvar_num( "climit_gorge_lvl" );
	if ( (reqlvl >= 2) && ( (floatround(floatsqroot(ns_get_exp(id) / 25 + 2.21) - 1)) < reqlvl ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Level %d is required to go Gorge" ,reqlvl);
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//If not enough players on the opposing team...
	new least = get_cvar_num( "climit_gorge_min" );
	if ( (least >= 1) && ( m < least ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d Marines required to go Gorge" ,least);		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Require ratio
	new prop = get_cvar_num( "climit_gorge_prop" );
	if ( (prop >= 2) && ( g >= m/prop ) )
	{
		client_print( id, print_chat, "[Combo Limiter] 1 Gorge for every %d Marines, you need %d more Marines to go Gorge" , prop, prop - (m%prop));
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( (prop == 1) && ( g >= m/prop ) )
	{
		client_print( id, print_chat, "[Combo Limiter] 1 Gorge for every %d Marine, you need %d more Marine to go Gorge" , prop, prop - (m%prop));
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	// Slot Interval
	new most = get_cvar_num( "climit_gorge_max" );
	
	new Float:g_mintime = ( get_cvar_float ( "climit_gorge_slot_mintime" ) * 60 );
	new Float:g_interval1 = ( get_cvar_float ( "climit_gorge_timeinterval" ) * 60 );
	new g_slotinterval = get_cvar_num ( "climit_gorge_slot_interval" );
	new g_maxinterval = get_cvar_num ( "climit_gorge_max_interval" );
	
	if ((g_mintime <= timeRemain) && (g_mintime > 0) && ( most >= 0 ))
		g_mintime = g_mintime + timeRemain
	if ( ( g_mintime > 0 ) && ( timeElapse > g_mintime ) && ( most >= 0 ) )
	{
		new g_interval2 = floatround( ( (timeElapse - g_mintime) / g_interval1 ),floatround_floor );
		
		if ( (g_interval2 == 0) || ( g_maxinterval == 1 ) )
			most = most + g_slotinterval;
		else if ( (g_interval2 > 0) && ( g_maxinterval >= 2 ) )
		{
			if ( g_interval2 >= ( g_maxinterval - 1 )){
				g_interval2 = g_maxinterval ;
				most = most + ( g_slotinterval * g_interval2 );
			}
			else if ( g_interval2 < ( g_maxinterval - 1 )){
				g_interval2 = g_interval2 + 1
				most = most + ( g_slotinterval * g_interval2 );
			}
		}
		if ( most <= 0 )
			most = 0
	}
	
	if (most <= -1)
	{
		set_pev(id, pev_impulse, 114)
		gorgeuser[id] = 1
		return PLUGIN_HANDLED;
	}
	
	
	//If too many players already this class...
	
	if ( (most >= 0) && ( g >= most ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Maximum amount of players allowed to go Gorge is %d" ,most);
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	else if ( (most >= 0) && ( g <= most ) )
	{
		if (( (most - (g+1) ) >= 2 ) || ((most - (g+1) ) == 0))
		{
			client_print( id, print_chat, "[Combo Limiter] %d Gorges remaining" , most - (g+1) );
			set_pev(id, pev_impulse, 114)
			gorgeuser[id] = 1
		}
		else if ( (most - (g+1) ) == 1 )
		{
			client_print( id, print_chat, "[Combo Limiter] %d Gorge remaining" , most - (g+1) );
			set_pev(id, pev_impulse, 114)
			gorgeuser[id] = 1
		}
		else
		{
			set_pev(id, pev_impulse, 0)
			client_print( id, print_chat, "[Combo Limiter] Unknown Error - Unable to evolve." );
		}
	}
	set_pev(id, pev_impulse, 0)
	return PLUGIN_CONTINUE;
}

// *******************************************************
// *******************************************************

public lerkCheck( id )
{
	if ( (!is_user_alive(id)) || (!is_user_connected(id)) || ( ns_get_class(id) != CLASS_SKULK ) || ( getpoints(id) < 2 ) )
	{
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	if (( !get_cvar_num("amx_combolimit" ) ) || (get_user_flags(id) & ADMIN_EXCLUSION_FLAG))
	{
		set_pev(id, pev_impulse, 115)
		lerkuser[id] = 1
		return PLUGIN_HANDLED;
	}
	
	new teamID = pev(id, pev_team);
	
	new i, g, m;
	for( i = 1; i <= g_maxPlayers; i++ )
	{
		if ( !is_user_connected( i ) )
			continue;
			
		new teamI = pev(i, pev_team);
		
		if ( (teamI == teamID) && ( lerkuser[i] == 1 ) && (ns_get_class(i) != CLASS_SKULK) )
		{
			g++;
		}
		
		if ( ( teamI != teamID ) && ( teamI != 0 ) && ( teamI != 6 ) )
		{
			m++;
		}
	}
	
	new Float:wait = get_cvar_float( "climit_lerk_wait" );
	new Float:minsLeft, Float:secsLeft, Float:timeElapse, Float:startTime2, Float:timeRemain;
	startTime2 = get_gametime();
	
	timeRemain = wait * 60;
	
	timeElapse = startTime2 - g_startTime;
	
	if ( (wait > 0) && ( timeElapse < timeRemain ) )		//not clear
	{
		timeRemain = timeRemain - timeElapse;
		minsLeft = ( timeRemain / 60 );
		secsLeft = ( timeRemain - ( floatround( minsLeft, floatround_floor ) * 60 ) );
		client_print( id, print_chat, "[Combo Limiter] %d minutes %d seconds left until Lerk is unblocked" , floatround ( minsLeft, floatround_floor ), floatround( secsLeft ) );		
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Certain number of kills required
	new frags = get_cvar_num( "climit_lerk_frags" );
	if ( (frags >= 2) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kills are required to go Lerk" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( (frags == 1) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kill is required to go Lerk" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Minimum level required
	new reqlvl = get_cvar_num( "climit_lerk_lvl" );
	if ( (reqlvl >= 2) && ( (floatround(floatsqroot(ns_get_exp(id) / 25 + 2.21) - 1)) < reqlvl ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Level %d is required to go Lerk" ,reqlvl);
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//If not enough players on the opposing team...
	new least = get_cvar_num( "climit_lerk_min" );
	if ( (least >= 1) && ( m < least ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d Marines required to go Lerk" ,least);		
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Require ratio
	new prop = get_cvar_num( "climit_lerk_prop" );
	if ( (prop >= 2) && ( g >= m/prop ) )
	{
		client_print( id, print_chat, "[Combo Limiter] 1 Lerk for every %d Marines, you need %d more Marines to go Lerk" , prop, prop - (m%prop));
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( (prop == 1) && ( g >= m/prop ) )
	{
		client_print( id, print_chat, "[Combo Limiter] 1 Lerk for every %d Marine, you need %d more Marine to go Lerk" , prop, prop - (m%prop));
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}		

	// Slot Interval
	new most = get_cvar_num( "climit_lerk_max" );
	new Float:g_mintime = ( get_cvar_float ( "climit_lerk_slot_mintime" ) * 60 );
	new Float:g_interval1 = ( get_cvar_float ( "climit_lerk_timeinterval" ) * 60 );
	new g_slotinterval = get_cvar_num ( "climit_lerk_slot_interval" );
	new g_maxinterval = get_cvar_num ( "climit_lerk_max_interval" );
	
	if ((g_mintime <= timeRemain) && (g_mintime > 0) && ( most >= 0 ))
		g_mintime = g_mintime + timeRemain
	if ( ( g_mintime > 0 ) && ( timeElapse > g_mintime ) && ( most >= 0 ) )
	{
		new g_interval2 = floatround( ( (timeElapse - g_mintime) / g_interval1 ),floatround_floor );
		
		if ( (g_interval2 == 0) || ( g_maxinterval == 1 ) )
			most = most + g_slotinterval;
		else if ( (g_interval2 > 0) && ( g_maxinterval >= 2 ) )
		{
			if ( g_interval2 >= ( g_maxinterval - 1 )){
				g_interval2 = g_maxinterval ;
				most = most + ( g_slotinterval * g_interval2 );
			}
			else if ( g_interval2 < ( g_maxinterval - 1 )){
				g_interval2 = g_interval2 + 1
				most = most + ( g_slotinterval * g_interval2 );
			}
		}
		if ( most <= 0 )
			most = 0
	}
	
	if (most <= -1)
	{
		set_pev(id, pev_impulse, 115)
		lerkuser[id] = 1
		return PLUGIN_HANDLED;
	}

	//If too many players already this class...
	if ( (most >= 0) && ( g >= most ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Maximum amount of players allowed to go Lerk is %d" ,most);
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	else if ( (most >= 0) && ( g <= most ) )
	{
		if (( (most - (g+1) ) >= 2 ) || ((most - (g+1) ) == 0))
		{
			client_print( id, print_chat, "[Combo Limiter] %d Lerks remaining" , most - (g+1) );
			set_pev(id, pev_impulse, 115)
			lerkuser[id] = 1
		}
		else if ((most - (g+1) ) == 1)
		{
			client_print( id, print_chat, "[Combo Limiter] %d Lerk remaining" , most - (g+1) );
			set_pev(id, pev_impulse, 115)
			lerkuser[id] = 1
		}
		else
		{
			set_pev(id, pev_impulse, 0)
			client_print( id, print_chat, "[Combo Limiter] Unknown Error - Unable to evolve." );
		}
	}
	set_pev(id, pev_impulse, 0)
	return PLUGIN_CONTINUE;
}

// *******************************************************
// *******************************************************

public fadeCheck( id )
{
	if ( (!is_user_alive(id)) || (!is_user_connected(id)) || ( ns_get_class(id) != CLASS_SKULK ) || ( getpoints(id) < 3 ) )
	{
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	if (( !get_cvar_num("amx_combolimit" ) ) || (get_user_flags(id) & ADMIN_EXCLUSION_FLAG))
	{
		set_pev(id, pev_impulse, 116)
		fadeuser[id] = 1
		return PLUGIN_HANDLED;
	}

	new teamID = pev(id, pev_team);
	
	new i, g, m;
	for( i = 1; i <= g_maxPlayers; i++ )
	{
		if ( !is_user_connected( i ) )
			continue;
			
		new teamI = pev(i, pev_team);
		
		if ( (teamI == teamID) && ( fadeuser[i] == 1 ) && (ns_get_class(i) != CLASS_SKULK) )
		{
			g++;
		}
		
		if ( ( teamI != teamID ) && ( teamI != 0 ) && ( teamI != 6 ) )
		{
			m++;
		}
	}
	
	new Float:wait = get_cvar_float( "climit_fade_wait" );
	new Float:minsLeft, Float:secsLeft, Float:timeElapse, Float:startTime2, Float:timeRemain;
	startTime2 = get_gametime();
	
	timeRemain = wait * 60;
	
	timeElapse = startTime2 - g_startTime;
	
	if ( (wait > 0) && ( timeElapse < timeRemain ) )		//not clear
	{
		timeRemain = timeRemain - timeElapse;
		minsLeft = ( timeRemain / 60 );
		secsLeft = ( timeRemain - ( floatround( minsLeft, floatround_floor ) * 60 ) );
		client_print( id, print_chat, "[Combo Limiter] %d minutes %d seconds left until Fade is unblocked" , floatround ( minsLeft, floatround_floor ), floatround( secsLeft ) );		
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Certain number of kills required
	new frags = get_cvar_num( "climit_fade_frags" );
	if ( (frags >= 2) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kills are required to go Fade" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( (frags == 1) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kill is required to go Fade" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Minimum level required
	new reqlvl = get_cvar_num( "climit_fade_lvl" );
	if ( (reqlvl >= 2) && ( (floatround(floatsqroot(ns_get_exp(id) / 25 + 2.21) - 1)) < reqlvl ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Level %d is required to go Fade" ,reqlvl);
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//If not enough players on the opposing team...
	new least = get_cvar_num( "climit_fade_min" );
	if ( (least >= 1) && ( m < least ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d Marines required to go Fade" ,least);	
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Require ratio
	new prop = get_cvar_num( "climit_fade_prop" );
	if ( (prop >= 2) && ( g >= m/prop ) )
	{
		client_print( id, print_chat, "[Combo Limiter] 1 Fade for every %d Marines, you need %d more Marines to go Fade" , prop, prop - (m%prop));
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( (prop == 1) && ( g >= m/prop ) )
	{
		client_print( id, print_chat, "[Combo Limiter] 1 Fade for every %d Marine, you need %d more Marine to go Fade" , prop, prop - (m%prop));
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	// Slot Interval
	new most = get_cvar_num( "climit_fade_max" );
	new Float:g_mintime = ( get_cvar_float ( "climit_fade_slot_mintime" ) * 60 );
	new Float:g_interval1 = ( get_cvar_float ( "climit_fade_timeinterval" ) * 60 );
	new g_slotinterval = get_cvar_num ( "climit_fade_slot_interval" );
	new g_maxinterval = get_cvar_num ( "climit_fade_max_interval" );
	
	if ((g_mintime <= timeRemain) && (g_mintime > 0) && ( most >= 0 ))
		g_mintime = g_mintime + timeRemain
	if ( ( g_mintime > 0 ) && ( timeElapse > g_mintime ) && ( most >= 0 ) )
	{
		new g_interval2 = floatround( ( (timeElapse - g_mintime) / g_interval1 ),floatround_floor );
		
		if ( (g_interval2 == 0) || ( g_maxinterval == 1 ) )
			most = most + g_slotinterval;
		else if ( (g_interval2 > 0) && ( g_maxinterval >= 2 ) )
		{
			if ( g_interval2 >= ( g_maxinterval - 1 )){
				g_interval2 = g_maxinterval ;
				most = most + ( g_slotinterval * g_interval2 );
			}
			else if ( g_interval2 < ( g_maxinterval - 1 )){
				g_interval2 = g_interval2 + 1
				most = most + ( g_slotinterval * g_interval2 );
			}
		}
		if ( most <= 0 )
			most = 0
	}
	
	if (most <= -1)
	{
		set_pev(id, pev_impulse, 116)
		fadeuser[id] = 1
		return PLUGIN_HANDLED;
	}

	//If too many players already this class...
	if ( (most >= 0) && ( g >= most ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Maximum amount of players allowed to go Fade is %d" ,most);
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	else if ( (most >= 0) && ( g <= most ) )
	{
		if (( (most - (g+1) ) >= 2 ) || ((most - (g+1) ) == 0))
		{
			client_print( id, print_chat, "[Combo Limiter] %d Fades remaining" , most - (g+1) );
			
			set_pev(id, pev_impulse, 116)
			fadeuser[id] = 1
		}
		else if ((most - (g+1) ) == 1)
		{
			client_print( id, print_chat, "[Combo Limiter] %d Fade remaining" , most - (g+1) );
			
			set_pev(id, pev_impulse, 116)
			fadeuser[id] = 1
		}
		else
		{
			set_pev(id, pev_impulse, 0)
			client_print( id, print_chat, "[Combo Limiter] Unknown Error - Unable to evolve." );
		}
	}
	set_pev(id, pev_impulse, 0)
	return PLUGIN_CONTINUE;
}

// *******************************************************
// *******************************************************

public onosCheck( id )
{
	if ( (!is_user_alive(id)) || (!is_user_connected(id)) || ( ns_get_class(id) != CLASS_SKULK ) || ( getpoints(id) < 4 ))
	{
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	if (( !get_cvar_num("amx_combolimit" ) ) || (get_user_flags(id) & ADMIN_EXCLUSION_FLAG))
	{
		set_pev(id, pev_impulse, 117)
		onosuser[id] = 1
		return PLUGIN_HANDLED;
	}
	
	new teamID = pev(id, pev_team);
	
	new i, g, m;
	for( i = 1; i <= g_maxPlayers; i++ )
	{
		if ( !is_user_connected( i ) )
			continue;
			
		new teamI = pev(i, pev_team);
		
		if ( (teamI == teamID) && ( onosuser[i] == 1) && (ns_get_class(i) != CLASS_SKULK) )
		{
			g++;
		}
		
		if ( ( teamI != teamID) && ( teamI != 0 ) && ( teamI != 6 ) )
		{
			m++;
		}
	}				

	new Float:wait = get_cvar_float( "climit_onos_wait" );
	new Float:minsLeft, Float:secsLeft, Float:timeElapse, Float:startTime2, Float:timeRemain;
	startTime2 = get_gametime();
	
	timeRemain = wait * 60;
	
	timeElapse = startTime2 - g_startTime;
	
	if ( (wait > 0) && ( timeElapse < timeRemain ) )		//not clear
	{
		timeRemain = timeRemain - timeElapse;
		minsLeft = ( timeRemain / 60 );
		secsLeft = ( timeRemain - ( floatround( minsLeft, floatround_floor ) * 60 ) );
		client_print( id, print_chat, "[Combo Limiter] %d minutes %d seconds left until Onos is unblocked" , floatround ( minsLeft, floatround_floor ), floatround( secsLeft ) );		
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Certain number of kills required
	new frags = get_cvar_num( "climit_onos_frags" );
	if ( (frags >= 2) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kills are required to go Onos" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( (frags == 1) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kill is required to go Onos" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Minimum level required
	new reqlvl = get_cvar_num( "climit_onos_lvl" );
	if ( (reqlvl >= 2) && ( (floatround(floatsqroot(ns_get_exp(id) / 25 + 2.21) - 1)) < reqlvl ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Level %d is required to go Onos" ,reqlvl);
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//If not enough players on the opposing team...
	new least = get_cvar_num( "climit_onos_min" );
	if ( (least >= 1) && ( m < least ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d Marines required to go Onos" ,least);		
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Require ratio
	new prop = get_cvar_num( "climit_onos_prop" );
	if ( (prop >= 2) && ( g >= m/prop ) )
	{
		client_print( id, print_chat, "[Combo Limiter] 1 Onos for every %d Marines, you need %d more Marines to go Onos" , prop, prop - (m%prop));
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( (prop == 1) && ( g >= m/prop ) )
	{
		client_print( id, print_chat, "[Combo Limiter] 1 Onos for every %d Marine, you need %d more Marine to go Onos" , prop, prop - (m%prop));
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	// Slot Interval
	new most = get_cvar_num( "climit_onos_max" );
	new Float:g_mintime = ( get_cvar_float ( "climit_onos_slot_mintime" ) * 60 );
	new Float:g_interval1 = ( get_cvar_float ( "climit_onos_timeinterval" ) * 60 );
	new g_slotinterval = get_cvar_num ( "climit_onos_slot_interval" );
	new g_maxinterval = get_cvar_num ( "climit_onos_max_interval" );
	
	if ((g_mintime <= timeRemain) && (g_mintime > 0) && ( most >= 0 ) && ( g_slotinterval != 0) && (g_maxinterval >= 1))
		g_mintime = g_mintime + timeRemain
	if ( ( g_mintime > 0 ) && ( timeElapse > g_mintime ) && ( most >= 0 ) && ( g_slotinterval != 0) && (g_maxinterval >= 1) )
	{
		new g_interval2 = floatround( ( (timeElapse - g_mintime) / g_interval1 ),floatround_floor );
		
		if ( (g_interval2 == 0) || ( g_maxinterval == 1 ) )
			most = most + g_slotinterval;
		else if ( (g_interval2 > 0) && ( g_maxinterval >= 2 ) )
		{
			if ( g_interval2 >= ( g_maxinterval - 1 )){
				g_interval2 = g_maxinterval ;
				most = most + ( g_slotinterval * g_interval2 );
			}
			else if ( g_interval2 < ( g_maxinterval - 1 )){
				g_interval2 = g_interval2 + 1
				most = most + ( g_slotinterval * g_interval2 );
			}
		}
		if ( most <= 0 )
			most = 0
	}
	
	if (most <= -1)
	{
		set_pev(id, pev_impulse, 117)
		onosuser[id] = 1
		return PLUGIN_HANDLED;
	}

	//If too many players already this class...
	if ( (most >= 0) && ( g >= most ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Maximum amount of players allowed to go Onos is %d" ,most);
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	else if ( (most >= 0) && ( g <= most ) )
	{
		if (( (most - (g+1) ) >= 2 ) || ((most - (g+1) ) == 0))
		{
			client_print( id, print_chat, "[Combo Limiter] %d Oni remaining" , most - (g+1) );
			set_pev(id, pev_impulse, 117)
			onosuser[id] = 1
		}
		else if ((most - (g+1) ) == 1)
		{
			client_print( id, print_chat, "[Combo Limiter] %d Onos remaining" , most - (g+1) );
			set_pev(id, pev_impulse, 117)
			onosuser[id] = 1
		}
		else
		{
			set_pev(id, pev_impulse, 0)
			client_print( id, print_chat, "[Combo Limiter] Unknown Error - Unable to evolve." );
		}
	}
	set_pev(id, pev_impulse, 0)
	return PLUGIN_CONTINUE;
}

// *******************************************************
// *******************************************************

public jpCheck( id )
{
	if ( (!is_user_alive(id)) || (!is_user_connected(id)) || ( jetpackready[id] == 0 ) || ( getpoints(id) < 2 ) || ( jetpacklock[id] == 1 ) )
	{
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	if (( !get_cvar_num("amx_combolimit" ) ) || (get_user_flags(id) & ADMIN_EXCLUSION_FLAG))
	{
		if (heavyuser[id] == 1)
		{
			heavyuser[id] = 0
		}
		set_pev(id, pev_impulse, 39)
		jetpackuser[id] = 1
		jetpacklock[id] = 1
		return PLUGIN_HANDLED;
	}
		
	new teamID = pev(id, pev_team);
	
	new i, g, m;
	new jetpackuser[33];
	for( i = 1; i <= g_maxPlayers; i++ )
	{
		if ( !is_user_connected( i ) )
			continue;
			
		new teamI = pev(i, pev_team);
		
		if ( (teamI == teamID) && ( jetpackuser[i] == 1) )
		{
			g++;
		}
		
		if ( ( teamI != teamID) && ( teamI != 0 ) && ( teamI != 6 ) )
		{
			m++;
		}
	}					

	new Float:wait = get_cvar_float( "climit_jp_wait" );
	new Float:minsLeft, Float:secsLeft, Float:timeElapse, Float:startTime2, Float:timeRemain;
	startTime2 = get_gametime();
	
	timeRemain = wait * 60;
	
	timeElapse = startTime2 - g_startTime;
	
	if ( (wait > 0) && ( timeElapse < timeRemain ))		//not clear
	{
		timeRemain = timeRemain - timeElapse;
		minsLeft = ( timeRemain / 60 );
		secsLeft = ( timeRemain - ( floatround( minsLeft, floatround_floor ) * 60 ) );
		client_print( id, print_chat, "[Combo Limiter] %d minutes %d seconds left until Jetpacks are unblocked" , floatround ( minsLeft, floatround_floor ), floatround( secsLeft ) );		
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Certain number of kills required
	new frags = get_cvar_num( "climit_jp_frags" );
	if ( (frags >= 2) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kills are required to get a Jetpack" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( (frags == 1) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kill is required to get a Jetpack" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Minimum level required
	new reqlvl = get_cvar_num( "climit_jp_lvl" );
	if ( (reqlvl >= 2) && ( (floatround(floatsqroot(ns_get_exp(id) / 25 + 2.21) - 1)) < reqlvl ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Level %d is required to get a Jetpack" , reqlvl );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//If not enough players on the opposing team...
	new least = get_cvar_num( "climit_jp_min" );
	if ( (least >= 1) && ( m < least ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d Aliens required to get a Jetpack" , least );	
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	//Require ratio
	new prop = get_cvar_num( "climit_jp_prop" );
	if ( ( prop >= 2 )  && ( g >= m/prop ))
	{
		client_print( id, print_chat, "[Combo Limiter] 1 Jetpacker for every %d Aliens, you need %d more Aliens to get a Jetpack" , prop, prop - (m%prop) );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( ( prop == 1 )  && ( g >= m/prop ))
	{
		client_print( id, print_chat, "[Combo Limiter] 1 Jetpacker for every %d Alien, you need %d more Alien to get a Jetpack" , prop, prop - (m%prop) );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	// Slot Interval
	new most = get_cvar_num( "climit_jp_max" );
	new Float:g_mintime = ( get_cvar_float ( "climit_jp_slot_mintime" ) * 60 );
	new Float:g_interval1 = ( get_cvar_float ( "climit_jp_timeinterval" ) * 60 );
	new g_slotinterval = get_cvar_num ( "climit_jp_slot_interval" );
	new g_maxinterval = get_cvar_num ( "climit_jp_max_interval" );
	
	if ((g_mintime <= timeRemain) && (g_mintime > 0) && ( most >= 0 ))
		g_mintime = g_mintime + timeRemain
	if ( ( g_mintime > 0 ) && ( timeElapse > g_mintime ) && ( most >= 0 ) )
	{
		new g_interval2 = floatround( ( (timeElapse - g_mintime) / g_interval1 ),floatround_floor );
		
		if ( (g_interval2 == 0) || ( g_maxinterval == 1 ) )
			most = most + g_slotinterval;
		else if ( (g_interval2 > 0) && ( g_maxinterval >= 2 ) )
		{
			if ( g_interval2 >= ( g_maxinterval - 1 )){
				g_interval2 = g_maxinterval ;
				most = most + ( g_slotinterval * g_interval2 );
			}
			else if ( g_interval2 < ( g_maxinterval - 1 )){
				g_interval2 = g_interval2 + 1
				most = most + ( g_slotinterval * g_interval2 );
			}
		}
		if ( most <= 0 )
			most = 0
	}
	
	if (most <= -1)
	{
		if (heavyuser[id] == 1)
		{
			heavyuser[id] = 0
		}
		set_pev(id, pev_impulse, 39)
		jetpackuser[id] = 1
		jetpacklock[id] = 1
		return PLUGIN_HANDLED;
	}

	//If too many players already this class...
	if ( (most >= 0) && ( g >= most ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Maximum amount of players allowed to get a Jetpack is %d" , most);
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;	
	}
	else if ( (most >= 0) && ( g <= most ) )
	{
		if (( (most - (g+1) ) >= 2 ) || ((most - (g+1) ) == 0))
		{
			client_print( id, print_chat, "[Combo Limiter] %d Jetpacks remaining" , most - (g+1) );
			if (heavyuser[id] == 1)
			{
				heavyuser[id] = 0
			}
			set_pev(id, pev_impulse, 39)
			jetpackuser[id] = 1
			jetpacklock[id] = 1
		}
		else if ((most - (g+1) ) == 1)
		{
			client_print( id, print_chat, "[Combo Limiter] %d Jetpack remaining" , most - (g+1) );
			if (heavyuser[id] == 1)
			{
				heavyuser[id] = 0
			}
			set_pev(id, pev_impulse, 39)
			jetpackuser[id] = 1
			jetpacklock[id] = 1
		}
		else
		{
			set_pev(id, pev_impulse, 0)
			client_print( id, print_chat, "[Combo Limiter] Unknown Error - Unable to upgrade." );
		}
	}	
	set_pev(id, pev_impulse, 0)
	return PLUGIN_CONTINUE;
}

// *******************************************************
// *******************************************************

public haCheck( id )
{
	if ( (!is_user_alive(id)) || (!is_user_connected(id)) || ( heavyready[id] == 0 ) || ( getpoints(id) < 2 ) || ( heavylock[id] == 1 ) )
	{
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	if (( !get_cvar_num("amx_combolimit" ) ) || (get_user_flags(id) & ADMIN_EXCLUSION_FLAG))
	{
		if (jetpackuser[id] == 1)
		{
			jetpackuser[id] = 0
		}
		set_pev(id, pev_impulse, 38)
		heavyuser[id] = 1
		heavylock[id] = 1
		return PLUGIN_HANDLED;
	}
	
	new teamID = pev(id, pev_team);
	
	new i, g, m;
	for( i = 1; i <= g_maxPlayers; i++ )
	{
		if ( !is_user_connected( i ) )
			continue;
			
		new teamI = pev(i, pev_team);
	
		if ( (teamI == teamID) && ( heavyuser[i] == 1 ) )
		{
			g++;
		}
	
		if ( ( teamI != teamID ) && ( teamI != 0 ) && ( teamI != 6 ) )
		{
			m++;
		}
	}					

	new Float:wait = get_cvar_float( "climit_ha_wait" );
	new Float:minsLeft, Float:secsLeft, Float:timeElapse, Float:startTime2, Float:timeRemain;
	startTime2 = get_gametime();
	
	timeRemain = wait * 60;
	
	timeElapse = startTime2 - g_startTime;
	
	if ( (wait > 0) && ( timeElapse < timeRemain ) ) 	//not clear
	{
		timeRemain = timeRemain - timeElapse;
		minsLeft = ( timeRemain / 60 );
		secsLeft = ( timeRemain - ( floatround( minsLeft, floatround_floor ) * 60 ) );
		client_print( id, print_chat, "[Combo Limiter] %d minutes %d seconds left until Heavy Armor is unblocked" , floatround ( minsLeft, floatround_floor ), floatround( secsLeft ) );		
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Certain number of kills required
	new frags = get_cvar_num( "climit_ha_frags" );
	if ( (frags >= 2) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kills are required to get Heavy Armor" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( (frags == 1) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kill is required to get Heavy Armor" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Minimum level required
	new reqlvl = get_cvar_num( "climit_ha_lvl" );
	if ( (reqlvl >= 2) && ( (floatround(floatsqroot(ns_get_exp(id) / 25 + 2.21) - 1)) < reqlvl ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Level %d is required to get Heavy Armor" , reqlvl );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//If not enough players on the opposing team...
	new least = get_cvar_num( "climit_ha_min" );
	if ( (least >= 1) && ( m < least ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d Aliens required to get Heavy Armor" , least );	
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Require ratio
	new prop = get_cvar_num( "climit_ha_prop" );
	if ( ( prop >= 2 )  && ( g >= m/prop ) )
	{
		client_print( id, print_chat, "[Combo Limiter] 1 Heavy Armor for every %d Aliens, you need %d more Aliens to get Heavy Armor" , prop, prop - (m%prop) );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( ( prop == 1 )  && ( g >= m/prop ) )
	{
		client_print( id, print_chat, "[Combo Limiter] 1 Heavy Armor for every %d Alien, you need %d more Alien to get Heavy Armor" , prop, prop - (m%prop) );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	// Slot Interval
	new most = get_cvar_num( "climit_ha_max" );
	new Float:g_mintime = ( get_cvar_float ( "climit_ha_slot_mintime" ) * 60 );
	new Float:g_interval1 = ( get_cvar_float ( "climit_ha_timeinterval" ) * 60 );
	new g_slotinterval = get_cvar_num ( "climit_ha_slot_interval" );
	new g_maxinterval = get_cvar_num ( "climit_ha_max_interval" );
	
	if ((g_mintime <= timeRemain) && (g_mintime > 0) && ( most >= 0 ))
		g_mintime = g_mintime + timeRemain
	if ( ( g_mintime > 0 ) && ( timeElapse > g_mintime ) && ( most >= 0 ) )
	{
		new g_interval2 = floatround( ( (timeElapse - g_mintime) / g_interval1 ),floatround_floor );
		
		if ( (g_interval2 == 0) || ( g_maxinterval == 1 ) )
			most = most + g_slotinterval;
		else if ( (g_interval2 > 0) && ( g_maxinterval >= 2 ) )
		{
			if ( g_interval2 >= ( g_maxinterval - 1 )){
				g_interval2 = g_maxinterval ;
				most = most + ( g_slotinterval * g_interval2 );
			}
			else if ( g_interval2 < ( g_maxinterval - 1 )){
				g_interval2 = g_interval2 + 1
				most = most + ( g_slotinterval * g_interval2 );
			}
		}
		if ( most <= 0 )
			most = 0
	}
	
	if (most <= -1)
	{
		if (jetpackuser[id] == 1)
		{
			jetpackuser[id] = 0
		}
		set_pev(id, pev_impulse, 38)
		heavyuser[id] = 1
		heavylock[id] = 1
		return PLUGIN_HANDLED;
	}

	//If too many players already this class...
	if ( (most >= 0) && ( g >= most ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Maximum amount of players allowed to get Heavy Armor is %d" , most);
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	else if ( (most >= 0) && ( g <= most ) )
	{
		if (( (most - (g+1) ) >= 2 ) || ((most - (g+1) ) == 0))
		{
			client_print( id, print_chat, "[Combo Limiter] %d Heavy Armors remaining" , most - (g+1) );
			if (jetpackuser[id] == 1)
			{
				jetpackuser[id] = 0
			}
			set_pev(id, pev_impulse, 38)
			heavyuser[id] = 1
			heavylock[id] = 1
		}
		else if ((most - (g+1) ) == 1)
		{
			client_print( id, print_chat, "[Combo Limiter] %d Heavy Armor remaining" , most - (g+1) );
			if (jetpackuser[id] == 1)
			{
				jetpackuser[id] = 0
			}
			set_pev(id, pev_impulse, 38)
			heavyuser[id] = 1
			heavylock[id] = 1
		}
		else
		{
			set_pev(id, pev_impulse, 0)
			client_print( id, print_chat, "[Combo Limiter] Unknown Error - Unable to upgrade." );
		}
	}
	set_pev(id, pev_impulse, 0)
	return PLUGIN_CONTINUE;
}

// *******************************************************
// *******************************************************

public hmgCheck( id )
{
	if ( (!is_user_alive(id)) || (!is_user_connected(id)) || ( hmgready[id] == 0 ) || ( getpoints(id) < 1 ) || ( hmglock[id] == 1 ))
	{
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	if (( !get_cvar_num("amx_combolimit" ) ) || (get_user_flags(id) & ADMIN_EXCLUSION_FLAG))
	{
		if (sguser[id] == 1) 
		{
			sguser[id] = 0
		}
		if (gluser[id] == 1)
		{
			gluser[id] = 0
		}
		set_pev(id, pev_impulse, 65)
		hmguser[id] = 1
		hmglock[id] = 1
		return PLUGIN_HANDLED;
	}
	
	new teamID = pev(id, pev_team);
	
	new i, g, m;
	for( i = 1; i <= g_maxPlayers; i++ )
	{
		if ( !is_user_connected( i ) )
			continue;
			
		new teamI = pev(i, pev_team);
	
		if ( (teamI == teamID) && ( hmguser[i] == 1 ) )
		{
			g++;
		}
	
		if ( ( teamI != teamID ) && ( teamI != 0 ) && ( teamI != 6 ) )
		{
			m++;
		}
	}					

	new Float:wait = get_cvar_float( "climit_hmg_wait" );
	new Float:minsLeft, Float:secsLeft, Float:timeElapse, Float:startTime2, Float:timeRemain;
	startTime2 = get_gametime();
	
	timeRemain = wait * 60;
	
	timeElapse = startTime2 - g_startTime;
	
	if ( (wait > 0) && ( timeElapse < timeRemain ))		//not clear
	{
		timeRemain = timeRemain - timeElapse;
		minsLeft = ( timeRemain / 60 );
		secsLeft = ( timeRemain - ( floatround( minsLeft, floatround_floor ) * 60 ) );
		client_print( id, print_chat, "[Combo Limiter] %d minutes %d seconds left until HMGs are unblocked" , floatround ( minsLeft, floatround_floor ), floatround( secsLeft ) );		
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	//Certain number of kills required
	new frags = get_cvar_num( "climit_hmg_frags" );
	if ((frags >= 2) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kills are required to get a HMG" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ((frags == 1) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kill are required to get a HMG" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Minimum level required
	new reqlvl = get_cvar_num( "climit_hmg_lvl" );
	if ( (reqlvl >= 2) && ( (floatround(floatsqroot(ns_get_exp(id) / 25 + 2.21) - 1)) < reqlvl ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Level %d is required to get a HMG" , reqlvl );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//If not enough players on the opposing team...
	new least = get_cvar_num( "climit_hmg_min" );
	if ( (least >= 1) && ( m < least ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d Aliens required to get  a HMG" , least );		
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}	

	//Require ratio
	new prop = get_cvar_num( "climit_hmg_prop" );
	if (( prop >= 2 )  && ( g >= m/prop ) )
	{
		client_print( id, print_chat, "[Combo Limiter] 1 HMG for every %d Aliens, you need %d more Aliens to get a HMG" , prop, prop - (m%prop) );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if (( prop == 1 )  && ( g >= m/prop ) )
	{
		client_print( id, print_chat, "[Combo Limiter] 1 HMG for every %d Alien, you need %d more Alien to get a HMG" , prop, prop - (m%prop) );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	// Slot Interval
	new most = get_cvar_num( "climit_hmg_max" );
	new Float:g_mintime = ( get_cvar_float ( "climit_hmg_slot_mintime" ) * 60 );
	new Float:g_interval1 = ( get_cvar_float ( "climit_hmg_timeinterval" ) * 60 );
	new g_slotinterval = get_cvar_num ( "climit_hmg_slot_interval" );
	new g_maxinterval = get_cvar_num ( "climit_hmg_max_interval" );
	
	if ((g_mintime <= timeRemain) && (g_mintime > 0) && ( most >= 0 ))
		g_mintime = g_mintime + timeRemain
	if ( ( g_mintime > 0 ) && ( timeElapse > g_mintime ) && ( most >= 0 ) )
	{
		new g_interval2 = floatround( ( (timeElapse - g_mintime) / g_interval1 ),floatround_floor );
		
		if ( (g_interval2 == 0) || ( g_maxinterval == 1 ) )
			most = most + g_slotinterval;
		else if ( (g_interval2 > 0) && ( g_maxinterval >= 2 ) )
		{
			if ( g_interval2 >= ( g_maxinterval - 1 )){
				g_interval2 = g_maxinterval ;
				most = most + ( g_slotinterval * g_interval2 );
			}
			else if ( g_interval2 < ( g_maxinterval - 1 )){
				g_interval2 = g_interval2 + 1
				most = most + ( g_slotinterval * g_interval2 );
			}
		}
		if ( most <= 0 )
			most = 0
	}
	
	if (most <= -1)
	{
		if (sguser[id] == 1) 
		{
			sguser[id] = 0
		}
		if (gluser[id] == 1)
		{
			gluser[id] = 0
		}
		set_pev(id, pev_impulse, 65)
		hmguser[id] = 1
		hmglock[id] = 1
		return PLUGIN_HANDLED;
	}

	//If too many players already this class...
	if ( (most >= 0) && ( g >= most ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Maximum amount of players allowed to get a HMG is %d" , most);
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	else if ( (most >= 0) && ( g <= most ) )
	{
		if (( (most - (g+1) ) >= 2 ) || ((most - (g+1) ) == 0))
		{
			client_print( id, print_chat, "[Combo Limiter] %d HMGs remaining" , most - (g+1) );
			if (sguser[id] == 1) 
			{
				sguser[id] = 0
			}
			if (gluser[id] == 1)
			{
				gluser[id] = 0
			}
			set_pev(id, pev_impulse, 65)
			hmguser[id] = 1
			hmglock[id] = 1

		}
		else if ((most - (g+1) ) == 1)
		{
			client_print( id, print_chat, "[Combo Limiter] %d HMG remaining" , most - (g+1) );
			if (sguser[id] == 1) 
			{
				sguser[id] = 0
			}
			if (gluser[id] == 1)
			{
				gluser[id] = 0
			}
			set_pev(id, pev_impulse, 65)
			hmguser[id] = 1
			hmglock[id] = 1

		}
		else
		{
			set_pev(id, pev_impulse, 0)
			client_print( id, print_chat, "[Combo Limiter] Unknown Error - Unable to upgrade." );
		}
	}
	set_pev(id, pev_impulse, 0)
	return PLUGIN_CONTINUE;
}

// *******************************************************
// *******************************************************

public glCheck( id )
{
	if ( (!is_user_alive(id)) || (!is_user_connected(id)) || ( glready[id] == 0 ) || ( getpoints(id) < 1 ) || ( gllock[id] == 1 ) )
	{
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	if (( !get_cvar_num("amx_combolimit" ) ) || (get_user_flags(id) & ADMIN_EXCLUSION_FLAG))
	{
		if (sguser[id] == 1)
		{
			sguser[id] = 0
		}
		if (hmguser[id] == 1)
		{
			hmguser[id] = 0
		}
		set_pev(id, pev_impulse, 66)
		gluser[id] = 1
		gllock[id] = 1
		return PLUGIN_HANDLED;
	}
	new teamID = pev(id, pev_team);
	
	new i, g, m;
	for( i = 1; i <= g_maxPlayers; i++ )
	{
		if ( !is_user_connected( i ) )
			continue;
			
		new teamI = pev(i, pev_team);
	
		if ( (teamI == teamID) && ( gluser[i] == 1 ) )
		{
			g++;
		}
	
		if ( ( teamI != teamID ) && ( teamI != 0 ) && ( teamI != 6 ) )
		{
			m++;
		}
	}					

	new Float:wait = get_cvar_float( "climit_gl_wait" );
	new Float:minsLeft, Float:secsLeft, Float:timeElapse, Float:startTime2, Float:timeRemain;
	startTime2 = get_gametime();
	
	timeRemain = wait * 60;
	
	timeElapse = startTime2 - g_startTime;
	
	if ( (wait > 0) && ( timeElapse < timeRemain ) )		//not clear
	{
		timeRemain = timeRemain - timeElapse;
		minsLeft = ( timeRemain / 60 );
		secsLeft = ( timeRemain - ( floatround( minsLeft, floatround_floor ) * 60 ) );
		client_print( id, print_chat, "[Combo Limiter] %d minutes %d seconds left until GLs are unblocked" , floatround ( minsLeft, floatround_floor ), floatround( secsLeft ) );		
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Certain number of kills required
	new frags = get_cvar_num( "climit_gl_frags" );
	if ( (frags >= 2) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kills are required to get a GL" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( (frags == 1) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kill are required to get a GL" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Minimum level required
	new reqlvl = get_cvar_num( "climit_gl_lvl" );
	if ( (reqlvl >= 2) && ( (floatround(floatsqroot(ns_get_exp(id) / 25 + 2.21) - 1)) < reqlvl ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Level %d is required to get a GL" , reqlvl );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//If not enough players on the opposing team...
	new least = get_cvar_num( "climit_gl_min" );
	if ( (least >= 1) && ( m < least ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d Aliens required to get a GL" , least );	
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Require ratio
	new prop = get_cvar_num( "climit_gl_prop" );
	if ( ( prop >= 2 )  &&( g >= m/prop ) )
	{
		client_print( id,print_chat,"1 GL for every %d Aliens, you need %d more Aliens to get a GL" , prop, prop - (m%prop) );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( ( prop == 1 )  &&( g >= m/prop ) )
	{
		client_print( id,print_chat,"1 GL for every %d Alien, you need %d more Alien to get a GL" , prop, prop - (m%prop) );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	// Slot Interval
	new most = get_cvar_num( "climit_gl_max" );
	new Float:g_mintime = ( get_cvar_float ( "climit_gl_slot_mintime" ) * 60 );
	new Float:g_interval1 = ( get_cvar_float ( "climit_gl_timeinterval" ) * 60 );
	new g_slotinterval = get_cvar_num ( "climit_gl_slot_interval" );
	new g_maxinterval = get_cvar_num ( "climit_gl_max_interval" );
	
	if ((g_mintime <= timeRemain) && (g_mintime > 0) && ( most >= 0 ))
		g_mintime = g_mintime + timeRemain
	if ( ( g_mintime > 0 ) && ( timeElapse > g_mintime ) && ( most >= 0 ) )
	{
		new g_interval2 = floatround( ( (timeElapse - g_mintime) / g_interval1 ),floatround_floor );
		
		if ( (g_interval2 == 0) || ( g_maxinterval == 1 ) )
			most = most + g_slotinterval;
		else if ( (g_interval2 > 0) && ( g_maxinterval >= 2 ) )
		{
			if ( g_interval2 >= ( g_maxinterval - 1 )){
				g_interval2 = g_maxinterval ;
				most = most + ( g_slotinterval * g_interval2 );
			}
			else if ( g_interval2 < ( g_maxinterval - 1 )){
				g_interval2 = g_interval2 + 1
				most = most + ( g_slotinterval * g_interval2 );
			}
		}
		if ( most <= 0 )
			most = 0
	}
	
	if (most <= -1)
	{
		if (sguser[id] == 1)
		{
			sguser[id] = 0
		}
		if (hmguser[id] == 1)
		{
			hmguser[id] = 0
		}
		set_pev(id, pev_impulse, 66)
		gluser[id] = 1
		gllock[id] = 1
		return PLUGIN_HANDLED;
	}

	//If too many players already this class...
	if ( (most >= 0) && ( g >= most ) )
	{
		client_print( id,print_chat,"Maximum amount of players allowed to get a GL is %d" , most);
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	else if ( (most >= 0) && ( g <= most ) )
	{
		if (( (most - (g+1) ) >= 2 ) || ((most - (g+1) ) == 0))
		{
			client_print( id, print_chat, "[Combo Limiter] %d GLs remaining" , most - (g+1) );
			if (sguser[id] == 1)
			{
				sguser[id] = 0
			}
			if (hmguser[id] == 1)
			{
				hmguser[id] = 0
			}
			set_pev(id, pev_impulse, 66)
			gluser[id] = 1
			gllock[id] = 1
		}
		else if ((most - (g+1) ) == 1)
		{
			client_print( id, print_chat, "[Combo Limiter] %d GL remaining" , most - (g+1) );
			if (sguser[id] == 1)
			{
				sguser[id] = 0
			}
			if (hmguser[id] == 1)
			{
				hmguser[id] = 0
			}
			set_pev(id, pev_impulse, 66)
			gluser[id] = 1
			gllock[id] = 1
		}
		else
		{
			set_pev(id, pev_impulse, 0)
			client_print( id, print_chat, "[Combo Limiter] Unknown Error - Unable to upgrade." );
		}
	}
	set_pev(id, pev_impulse, 0)
	return PLUGIN_CONTINUE;
}

// *******************************************************
// *******************************************************

public sgCheck( id )
{
	if ( (!is_user_alive(id)) || (!is_user_connected(id)) || ( sgready[id] == 0 ) || ( getpoints(id) < 1 ) || ( sglock[id] == 1 ) )
	{
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	if (( !get_cvar_num("amx_combolimit" ) ) || (get_user_flags(id) & ADMIN_EXCLUSION_FLAG))
	{
		set_pev(id, pev_impulse, 64)
		hmgready[id] = 1
		glready[id] = 1
		sguser[id] = 1
		sglock[id] = 1
		return PLUGIN_HANDLED;
	}
	
	new teamID = pev(id, pev_team);
	
	new i, g, m;
	for( i = 1; i <= g_maxPlayers; i++ )
	{
		if ( !is_user_connected( i ) )
			continue;
			
		new teamI = pev(i, pev_team);
	
		if ( (teamI == teamID) && ( sguser[i] == 1 ) )
		{
			g++;
		}
	
		if ( ( teamI != teamID ) && ( teamI != 0 ) && ( teamI != 6 ) )
		{
			m++;
		}
	}					

	new Float:wait = get_cvar_float( "climit_sg_wait" );
	new Float:minsLeft, Float:secsLeft, Float:timeElapse, Float:startTime2, Float:timeRemain;
	startTime2 = get_gametime();
	
	timeRemain = wait * 60;
	
	timeElapse = startTime2 - g_startTime;
	
	if ( (wait > 0) && ( timeElapse < timeRemain ) )		//not clear 
	{
		timeRemain = timeRemain - timeElapse;
		minsLeft = ( timeRemain / 60 );
		secsLeft = ( timeRemain - ( floatround( minsLeft, floatround_floor ) * 60 ) );
		client_print( id, print_chat, "[Combo Limiter] %d minutes %d seconds left until Shotguns are unblocked" , floatround ( minsLeft, floatround_floor ), floatround( secsLeft ) );		
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	//Certain number of kills required
	new frags = get_cvar_num( "climit_sg_frags" );
	if ( (frags >= 2) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kills are required to get a Shotgun" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( (frags == 1) && ( get_user_frags( id ) < frags ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d kill are required to get a Shotgun" , frags );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Minimum level required
	new reqlvl = get_cvar_num( "climit_sg_lvl" );
	if ( (reqlvl >= 2) && ( (floatround(floatsqroot(ns_get_exp(id) / 25 + 2.21) - 1)) < reqlvl ) )
	{
		client_print( id, print_chat, "[Combo Limiter] Level %d is required to get a Shotgun" , reqlvl );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	
	//If not enough players on the opposing team...
	new least = get_cvar_num( "climit_sg_min" );
	if ( (least >= 1) && ( m < least ) )
	{
		client_print( id, print_chat, "[Combo Limiter] %d Aliens required to get a Shotgun" , least );		
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	//Require ratio
	new prop = get_cvar_num( "climit_sg_prop" );
	if ( ( prop >= 2 )  && ( g >= m/prop ) )
	{
		client_print( id,print_chat,"1 Shotgun for every %d Aliens, you need %d more Aliens to get a Shotgun" , prop, prop - (m%prop) );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	} else if ( ( prop == 1 )  && ( g >= m/prop ) )
	{
		client_print( id,print_chat,"1 Shotgun for every %d Alien, you need %d more Alien to get a Shotgun" , prop, prop - (m%prop) );
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}

	// Slot Interval
	new most = get_cvar_num( "climit_sg_max" );
	new Float:g_mintime = ( get_cvar_float ( "climit_sg_slot_mintime" ) * 60 );
	new Float:g_interval1 = ( get_cvar_float ( "climit_sg_timeinterval" ) * 60 );
	new g_slotinterval = get_cvar_num ( "climit_sg_slot_interval" );
	new g_maxinterval = get_cvar_num ( "climit_sg_max_interval" );
	
	if ((g_mintime <= timeRemain) && (g_mintime > 0) && ( most >= 0 ))
		g_mintime = g_mintime + timeRemain
	if ( ( g_mintime > 0 ) && ( timeElapse > g_mintime ) && ( most >= 0 ) )
	{
		new g_interval2 = floatround( ( (timeElapse - g_mintime) / g_interval1 ),floatround_floor );
		
		if ( (g_interval2 == 0) || ( g_maxinterval == 1 ) )
			most = most + g_slotinterval;
		else if ( (g_interval2 > 0) && ( g_maxinterval >= 2 ) )
		{
			if ( g_interval2 >= ( g_maxinterval - 1 )){
				g_interval2 = g_maxinterval ;
				most = most + ( g_slotinterval * g_interval2 );
			}
			else if ( g_interval2 < ( g_maxinterval - 1 )){
				g_interval2 = g_interval2 + 1
				most = most + ( g_slotinterval * g_interval2 );
			}
		}
		if ( most <= 0 )
			most = 0
	}
	
	if (most <= -1)
	{
		set_pev(id, pev_impulse, 64)
		hmgready[id] = 1
		glready[id] = 1
		sguser[id] = 1
		sglock[id] = 1
		return PLUGIN_HANDLED;
	}

	//If too many players already this class...
	if ( (most >= 0) && ( g >= most ) )
	{
		client_print( id,print_chat,"Maximum amount of players allowed to get a Shotgun is %d" , most);
		
		set_pev(id, pev_impulse, 0)
		return PLUGIN_HANDLED;
	}
	else if ( (most >= 0) && ( g <= most )  )
	{
		if (( (most - (g+1) ) >= 2 ) || ((most - (g+1) ) == 0))
		{
			client_print( id, print_chat, "[Combo Limiter] %d Shotguns remaining" , most - (g+1) );
			set_pev(id, pev_impulse, 64)
			hmgready[id] = 1
			glready[id] = 1
			sguser[id] = 1
			sglock[id] = 1
		}
		else if ((most - (g+1) ) == 1)
		{
			client_print( id, print_chat, "[Combo Limiter] %d Shotgun remaining" , most - (g+1) );
			set_pev(id, pev_impulse, 64)
			hmgready[id] = 1
			glready[id] = 1
			sguser[id] = 1
			sglock[id] = 1
		}
		else
		{
			set_pev(id, pev_impulse, 0)
			client_print( id, print_chat, "[Combo Limiter] Unknown Error - Unable to upgrade." );
		}
	}
	set_pev(id, pev_impulse, 0)
	return PLUGIN_CONTINUE;
}
