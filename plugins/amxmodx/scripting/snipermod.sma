/**********************************************************************************
* SniperMod by KrX
* Converts Marine's pistol to a sniper rifle.
* Does a certain amount of damage(default 110) and has only 1 bullet in his clip.
* Reloads require 10 bullets, but will appear as one in his clip (definable by CVAR)
* Resupply can be blocked (definable) using Darkness' Resupply Emulator.
* 
* Special Thanks: peachy, for alot of help with the plugin
* 		  gr1mre4p3r, for ideas
*		  The testers and bug-reporters: s095, +hairy+, Sgt.Riot, iBlank, Fixer
*		  steve, for his ns_popup_var
*		  Darkness, for helping with the getting of level, and zooming in/out
*		  Cheap_Suit(from AlliedModders forums) for his tutorial on Changing weapon models
*		  #endgame, for his #tryinclude template
* 		  Mini_Midget on AlliedModders, for his public Event_WeaponFire( id )
*
* Changelog	
* 			v2.0
*			-> Fixed up most of the parts, with help from peachy
*			v2.1
*			-> Added the [SniperMod] prefix for messages
*			-> Made the /sniperhelp command
*			v2.2
*			-> peachy helped to clean up the code
*			-> Bullets will now be 1 in the clip, but the usual for the reserve
*			-> Reloads will take 10 bullets
*			-> No more resupply spamming bug
*			v2.3
*			-> Added the precaching to prepare for the next release
*			v2.4
*			-> Added the level requirement setting
*			v2.5
*			-> Added Helper support
*			-> Removed the /sniperhelp command
*			-> Initial Release on ModNS
*			v2.6
*			-> Fixed the current exp bug
*			v2.7
*			-> Changed exp to level
*			-> Added new defines, requiredlvl2 & announcetoall. See defines.
*			-> Switched to using ns_popups instead of client_prints. Except for announcements.
*			v2.8
*			-> Added the shooting sound (recorded =D)
*			-> Added the 2 defines, HELPER & RESUPPLY in the comments
*			-> Aliens can now use /sniperget to check Sniper's damage, and required level.
*			-> Internal Cleanup
*			v2.9
*			-> Done model change.
*			-> Added say_team commands
*			-> Added option of blocking Resupply (requires Resupply Emulator)
*			-> Made plugin pause on classic maps
*			-> Removed enums & major cleanup
*			-> Only requires one define for the requiredlvl (Now uses a formula. Thanks peachy!)
*			-> Thanks to peachy for help with fakemeta
*			-> Added zoomin/zoomout console commands.
*			v3.0 (MAJOR UPDATE)
*			-> Model bugs fixed
*			-> Uses fakemeta for model changing/event handling
*			-> zoomin/zoomout commands added a check if client is allowed to
*			-> Added info texts to print on server console
*			-> Sound temporarily removed, to be used for done for next release
*			-> Used static variables where needed
*			-> Cleaned up code, removed line breaks where not needed.
*			-> Commented future release(s) code
*			v3.1 (MAJOR UPDATE)
*			-> Used #tryinclude for includes
*			-> Updated helper text
*			-> Removed useless stock functions
*			-> pragma semicolon 1 NOT possible, with helper.inc not semi-colon-ed
* 			-> AWP Fire sound re-added, bug-fixed, can be heard by all players nearby
* 			-> Zooming in/out sounds
*			-> Reverts fov when changing weapon/shooting
* 			-> Now resets player-specific variables upon connection
* 			-> Fixed exploit where players could have unlimited ammo when amx_smclip was above 1
* 			-> Fixed exploit where players could have a constant 10 ammo reserve, even after reloading
* 			-> Now shows the /help menu when typing /sniperhelp if HELPER is enabled
* 			-> Fixed bug where setting amx_smclip to anything higher than 1 will have no effect
*			-> Now glows Snipers the Marine Colour
* 			-> New CVAR: amx_smglow, controls above
* 			-> New CVAR: amx_smreserve, controls the amount of bullets stored as reserve when player spawns
*			-> New Command: sm_zoom - Zooms player in/out. Bind a key with this.
* 			-> New CVAR: amx_smzoom, adjusts zoom ratio of sm_zoom
* 			-> Changed command: /sniperget to /sniperinfo
* 			-> /sniperinfo now shows Zoom Ratio. Proper line breaking and spacing
*
*
* CVARs: 		
* 			amx_smdmg (default:110) 	<- Change this for the amount of damage sniper does
*			amx_smclip (default:1)		<- Change this for the amount of bullets stored in clip
* 			amx_smreserve (default:100)	<- Change this for the amount of bullets stored as reserve when player spawns
* 			amx_smglow (default:1) 		<- Change this to enable glowing of snipers
* 			amx_smzoom (default:2.5)	<- Change this to adjust zoom ratio
*
* Defines:		
* 			requiredlvl 	(default:4) 			<- Change this for the minimum level required to be a Sniper
*			announcetoall 	(default:1) 			<- Change to 0 if you want to disable announcing
*			HELPER 			(default:1) 			<- If you are NOT using -mE-'s Helper, change this to 0, else 1.
*			RESUPPLY 		(default:0) 			<- If you are using Darkness's Resupply Emulator, change this to 1, else 0 (note this blocks resupply)
* 			GLOW_RED, GLOW_GREEN, GLOW_BLUE			<- Change these values for the Sniper Glow colour. Remember to add .0 at the end!
*
* Commands:		
* 			say /sniperon	(Makes player a Sniper on next spawn)
*			say /sniperoff	(Makes player revert to Marine)
*			say /sniperinfo	(Gets Sniper Info)
*			say /sniperhelp	(Shows Sniper help)
*			sm_zoom			(Zooms in/out)
*
* Upcoming Releases:	-> Laser pointer
* 						-> NS Support
* 						-> To fully implement Resupply Emulator
* 						-> Full Uranium Ammo implementation - (currently working on)
* 						-> Full Advanced Ammo implementation
*
***********************************************************************************/

#include <amxmodx>
#include <amxmisc>
#include <ns>
#include <fakemeta>
#include <engine>

#define HELPER 0		// 1 if Helper is running, 0 if not.
#define RESUPPLY 0		// 1 if you want to block Resupply (requires Resupply Emulator by Darkness)

// Change the below define for the required level.
#define requiredlvl		4
// Below define determines whether to announce to all players that he is a Sniper.
#define announcetoall	1

// Below defines the Sniper glow colour (glowing controllable by CVAR amx_smglow)
// Default values: 0.0, 170.0, 255.0	(Marine colour)
// REMEMBER TO ADD THE .0 BEHIND!
#define GLOW_RED	0.0
#define GLOW_GREEN	170.0
#define GLOW_BLUE	255.0

/* !!! DO NOT EDIT ANYTHING BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING! !!!! */

#if HELPER == 1
#tryinclude <helper>
#if !defined(HELPER_INC)
#error Cannot find helper.inc . Either set #define HELPER 0 or get helper from http://www.nsmod.org/forums/index.php?showtopic=3784
#endif
#endif

#if RESUPPLY == 1		// if Resupply Emulator is running, see define RESUPPLY
#include <resupply>
#endif

#if RESUPPLY == 1
#tryinclude <resupply>
#if !defined(RESUPPLY_HEALTH)
#error Cannot find resupply.inc . Either set #define RESUPPLY 0 or get Resupply Emulator from http://www.nsmod.org/forums/index.php?showtopic=7212
#endif
#endif

static cvar_amx_smdmg, cvar_amx_smclip, cvar_amx_smreserve, cvar_amx_smglow, Float:cvar_amx_smzoom;	// Static cvar holders
static plugin_version[] = "3.1";												// Static var for plugin version
new onsnipemode[33], pistolid[33];												// Individual ID-holding vars
new iszoomed[33], weaponID[33], Float:pistoliddmg[33], Float:pistolrealdmg[33];	// Player-specific ID Vars for adjusting stuffs
new g_CurWeap[33][2];															// Used for second curweapon event handler
static name[33];																// Temporary array for holding playername												

// Static Colour values
new Float:colourtoglow[3] = {GLOW_RED,GLOW_GREEN,GLOW_BLUE};
new Float:clear[3] = {0.0,0.0,0.0};

// Static variables holding paths for Sounds and Models
static ShootSound[] = "sfx/awp_shoot.wav";
static ZoomInSound[] = "sfx/zoomin.mp3";
static ZoomOutSound[] = "sfx/zoomout.mp3";
static awp_viewModel[] = "models/v_awp.mdl";
static awp_weapModel[] = "models/p_awp.mdl";

public plugin_init()
{
	register_plugin("SniperMod", plugin_version, "KrX");
	register_cvar("KrX_snipermod",plugin_version,FCVAR_SERVER);
	
	if (!ns_is_combat())
	{
		pause("ad");
		server_print("[SniperMod v%s] Game is combat, disabling SniperMod.", plugin_version);
		return;
	}
	
	register_clcmd("say /sniperon", "set_sniper");
	register_clcmd("say /sniperoff", "stop_sniper");
	register_clcmd("say /sniperinfo", "get_status");
	register_clcmd("say /sniperhelp", "show_help");
	register_clcmd("say_team /sniperon", "set_sniper");
	register_clcmd("say_team /sniperoff", "stop_sniper");
	register_clcmd("say_team /sniperinfo", "get_status");
	register_clcmd("say_team /sniperhelp", "show_help");
	register_clcmd("sm_zoom", "sniper_scope");
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=6");
	register_event("CurWeapon", "Event_WeaponFire",  "b");
	register_event("DeathMsg", "client_died", "ab");
	
	register_cvar("amx_smdmg", "110");
	register_cvar("amx_smclip", "1");
	register_cvar("amx_smreserve", "1");
	register_cvar("amx_smglow", "0");
	register_cvar("amx_smzoom", "2.5");
	cvar_amx_smdmg = get_cvar_pointer("amx_smdmg");
	cvar_amx_smclip = get_cvar_pointer("amx_smclip");
	cvar_amx_smreserve = get_cvar_pointer("amx_smreserve");
	cvar_amx_smglow = get_cvar_pointer("amx_smglow");
	cvar_amx_smzoom = get_cvar_float("amx_smzoom");
	
	server_print("[SniperMod v%s] Loaded Succesfully!", plugin_version);
}

// This function is automatically called to precache required files for use
public plugin_precache()
{
	//EngFunc_PrecacheSound automatically adds "sound/" at the front of names
	engfunc(EngFunc_PrecacheSound, ShootSound);
	engfunc(EngFunc_PrecacheSound, ZoomInSound);
	engfunc(EngFunc_PrecacheSound, ZoomOutSound);
	engfunc(EngFunc_PrecacheModel, awp_viewModel);
	engfunc(EngFunc_PrecacheModel, awp_weapModel);
	server_print("[SniperMod v%s] Files precached", plugin_version);
}

public Event_CurWeapon(id) 
{
	if (onsnipemode[id] && pistolid[id])
	{
		// Get user's current weapon
		weaponID[id] = read_data(2);
		
		// Not pistol? Ignore following steps
		if(weaponID[id] != WEAPON_PISTOL) { 		
			// Revert his fov to normal when changing weapon to anything other than pistol
			if (iszoomed[id]) {
				iszoomed[id] = 0;
			}
			return PLUGIN_HANDLED; 		// If its not the pistol, do nothing
		}
		
		// Change models
		set_pev(id, pev_viewmodel2, awp_viewModel);
		set_pev(id, pev_weaponmodel2, awp_weapModel);
		
		//ns_set_weap_dmg(pistolid[id], get_pcvar_float(cvar_amx_smdmg));
		ns_set_weap_dmg(pistolid[id], pistolrealdmg[id]);
		
		pistolid[id] = find_ent_by_owner(0, "weapon_pistol", id);
	}
	return PLUGIN_CONTINUE;
}

public Event_WeaponFire( id ) 
{ 
	new weapon = read_data(2); 
	new ammo = read_data(3); 
	
	if( g_CurWeap[id][0] != weapon ) // User Changed Weapons.. 
	{ 
		g_CurWeap[id][0] = weapon;
		g_CurWeap[id][1] = ammo;
		return PLUGIN_CONTINUE; 
	} 
	if( g_CurWeap[id][1] < ammo ) // User Reloaded.. 
	{
		if(weapon == WEAPON_PISTOL && ammo > get_pcvar_num(cvar_amx_smclip)) 
			set_ammo(id);
		g_CurWeap[id][1] = ammo;
		return PLUGIN_CONTINUE;
	}
	if( g_CurWeap[id][1] == ammo ) // User did something else, but didn't shoot.. 
		return PLUGIN_CONTINUE 
	
	g_CurWeap[id][1] = ammo;
	g_CurWeap[id][0] = weapon;
	
	if(weapon == WEAPON_PISTOL && onsnipemode[id] && pistolid[id])
	{
		// Zoom player out after shooting
		iszoomed[id] = 0;
		engfunc(EngFunc_EmitSound, id, CHAN_STATIC, ShootSound, 1.0, ATTN_NORM, 0, PITCH_NORM);
	}  
	return PLUGIN_CONTINUE;
}


// Client just spawned
public client_spawn(id)
{
	if (onsnipemode[id])
	{
		pistolid[id] = find_ent_by_owner(0, "weapon_pistol", id);
		if (pistolid[id])
		{
			if (get_pcvar_num(cvar_amx_smglow)) 
				set_task(3.0, "glow", id);		// Give 3.0 spare time for spawninvfun
			pistoliddmg[id] = ns_get_weap_dmg(pistolid[id]);
			//ns_set_weap_dmg(pistolid[id], get_pcvar_float(cvar_amx_smdmg));
			pistolrealdmg[id] = (get_pcvar_float(cvar_amx_smdmg)+pistoliddmg[id]);
			ns_set_weap_dmg(pistolid[id], pistolrealdmg[id]);
			set_ammo(id);
			ns_set_weap_reserve(id, WEAPON_PISTOL, get_pcvar_num(cvar_amx_smreserve));
		}
	}
}

// Client changed team, so revert back. (RR/Spec/Marine/Alien)
public client_changeteam(id, newteam, oldteam)
{
	onsnipemode[id] = 0;
	pistolid[id] = 0;
	iszoomed[id] = 0;
	weaponID[id] = 0;
	g_CurWeap[id][0] = 0;
	g_CurWeap[id][1] = 0;
	pistoliddmg[id] = 0.0;
	pistolrealdmg[id] = 0.0;
}

// Client just connected. Reset previous values
public client_connect(id){
	onsnipemode[id] = 0;
	pistolid[id] = 0;
	iszoomed[id] = 0;
	weaponID[id] = 0;
	g_CurWeap[id][0] = 0;
	g_CurWeap[id][1] = 0;
	pistoliddmg[id] = 0.0;
	pistolrealdmg[id] = 0.0;
	return PLUGIN_CONTINUE;
}

// Client has died
public client_died(id)
{
	new victim = read_data(2);
	if (pistolid[victim])
	{
		pistolid[victim] = 0;
	}
	return PLUGIN_CONTINUE;
}

public sniper_scope(id)
{		// If is not sniper || If current weapon is not pistol || is not pistol || no ammo
	if (!onsnipemode[id] || g_CurWeap[id][0] != WEAPON_PISTOL || !pistolid[id] || g_CurWeap[id][1] <= 0) {
		//client_print(id, print_chat, "[SniperMod] Please be a sniper first!");
		return PLUGIN_HANDLED;
	}
	if (iszoomed[id]) {
		client_cmd(id, "mp3 play sound/%s", ZoomOutSound);
		iszoomed[id] = 0;
	} else {
		client_cmd(id, "mp3 play sound/%s", ZoomInSound);
		iszoomed[id] = 1;
	}
	return PLUGIN_HANDLED;
}

// Thanks to Darkness for the following two functions for zooming
public client_PostThink(id)
{
	if (iszoomed[id])
		SetZoomMult(id, cvar_amx_smzoom);
	if(!is_user_alive(id))
		iszoomed[id] = 0;		// If user is dead, reset his fov, else it will zoom the spectating player
}

SetZoomMult(ePlayer, Float:fMult)
{
    set_pev(ePlayer, pev_fov, 2.0 * floatatan(1.0 / fMult, degrees));
}

// Set player to be a Sniper
public set_sniper(id)
{
	if (pev(id, pev_team) & 1)
	{
		if (onsnipemode[id])
		{
			ns_popup_var(id, "[SniperMod] You already are a Sniper.");
		}
		else
		{
			new level = floatround(floatsqroot(ns_get_exp(id) / 25 + 2.21) - 1);
			if ( level >= requiredlvl )
			{
				onsnipemode[id] = 1;
				ns_set_weap_dmg(pistolid[id], get_pcvar_float(cvar_amx_smdmg));
				set_ammo(id);
				ns_popup_var(id, "[SniperMod] You will be a Sniper on your next spawn.");
				#if announcetoall == 1
				static name[33];
				get_user_name(id, name, 32);
				client_print(0, print_chat, "[SniperMod] %s is now a Sniper", name);
				#endif
			}
			else
			{
				client_print(id, print_chat, "[SniperMod] You need to be at least level %d to be a Sniper", requiredlvl);
			}
		}
	}
	return PLUGIN_HANDLED;
}

// Set player to revert
public stop_sniper(id)
{
	if (pev(id, pev_team) & 1)
	{
		if (onsnipemode[id])
		{
			get_user_name(id, name, 32);
			onsnipemode[id] = 0;
			ns_set_weap_dmg(pistolid[id], 30.0);
			if (get_pcvar_num(cvar_amx_smglow))
				revertglow(id);
			ns_popup_var(id, "[SniperMod] You are no longer a sniper.");
			#if announcetoall == 1
			client_print(0, print_chat, "[SniperMod] %s is no longer a Sniper", name);
			#endif
		}
		else
		{
			ns_popup_var(id, "[SniperMod] You are not even a sniper...");
		}
	}
	return PLUGIN_HANDLED;
}

// /sniperinfo
public get_status(id)
{
	static dmg, zoomlvl[5];
	dmg = get_pcvar_num(cvar_amx_smdmg);
	float_to_str(cvar_amx_smzoom, zoomlvl, 4);
	if (pev(id, pev_team) & 1)
	{
		if (onsnipemode[id])
		{
			ns_popup_var(id, "[SniperMod] You are a Sniper.^nSniper's Damage: [%d], Zoom level: [%sx]^nRequired Level: [%d], Current Level: [%d]", dmg, zoomlvl, requiredlvl, floatround(floatsqroot(ns_get_exp(id) / 25 + 2.21) - 1));
		}
		else
		{
			ns_popup_var(id, "[SniperMod] You are NOT a Sniper.^nSniper's Damage: [%d], Zoom level: [%sx]^nRequired Level: [%d], Current Level: [%d]", dmg, zoomlvl, requiredlvl, floatround(floatsqroot(ns_get_exp(id) / 25 + 2.21) - 1));
		}
	}
	else 
	{
		ns_popup_var(id, "[SniperMod] Sniper's Damage: [%d]^nZoom level: [%sx]^nRequired Level: [%d].^nNote: for Marines only.", dmg, zoomlvl, requiredlvl);
	}
	return PLUGIN_HANDLED;
}

// /sniperhelp command
public show_help(id)
{
	#if HELPER == 1
	client_cmd(id, "say /help");
	#else
	ns_popup_var(id, "[SniperMod] Say /sniperon to be a sniper, /sniperoff to stop being a sniper. /sniperget to view requirements, status & damage");
	#endif
	return PLUGIN_HANDLED;
}

// Revert player glow back to normal
public revertglow(id)
{
	set_pev(id, pev_renderfx, kRenderFxNone);
	set_pev(id, pev_rendercolor, clear);
	set_pev(id, pev_rendermode, kRenderNormal);
	set_pev(id, pev_renderamt, 0);
	return PLUGIN_HANDLED;
}

// Glow function
public glow(id)
{
	set_pev(id, pev_renderfx, kRenderFxGlowShell);
	set_pev(id, pev_rendercolor, colourtoglow);
	set_pev(id, pev_rendermode, kRenderNormal);
	set_pev(id, pev_renderamt, 16.0);
	return PLUGIN_HANDLED;
}

// Small fix by steve for ns_popup to allow other variables to be added
stock ns_popup_var(id, const msg[], ...)
{
	static temp[180];
	vformat(temp,sizeof(temp)-1,msg,3);
	ns_popup(id,temp);
}

// Set ammo stock
stock set_ammo(id)
{
	ns_set_weap_clip(pistolid[id], get_pcvar_num(cvar_amx_smclip));
}

// Only block resupply when we want it to
#if RESUPPLY == 1
public nshook_Resupply(id, iStage)
{
	if (onsnipemode[id])
	{
		ns_popup_var(id, "[SniperMod] Resupply is not allowed when you are a Sniper.");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}
#endif

// Helper Info
#if HELPER == 1					// if helper is running, see define HELPER
/************************************************
client_help( id )
Public Help System
************************************************/

public client_help(id)
{
	help_add("Information","This plugin allows Marines to be Snipers.");
	help_add("Commands","say /sniperon^nsay /sniperoff^nsay /sniperinfo^nsay /sniperhelp^nsm_zoom");
	help_add("Description","/sniperon: Makes the player receive AWP on next spawn. ^n/sniperoff: Reverses /sniperon^n/sniperinfo: Get Sniper Info^n/sniperhelp: Help on SniperMod");
	help_add("Zooming","Zooming only works while holding the AWP^nBind sm_zoom to a key. (eg. bind z sm_zoom)^n Press once to zoom");
}

public client_advertise(id)
{
	return PLUGIN_CONTINUE;
}
#endif
