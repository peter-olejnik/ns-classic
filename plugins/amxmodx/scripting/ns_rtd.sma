/*
* NS Roll the dice plugin
*
* By White Panther and mICKE
*
* This Plugin gives players prizes when they Roll the Dice
*
* Comments:
*	Any say * commands can only be used by clients, NOT SERVER CONSOLE
*
* Credits:
*	- Depot		- his assistance in getting bugs fixed
*	- CheesyPeteza	- For help with fake_damage
*	- Ludwig van	- rips from his plugins
*
* Commands:
*	say rolldice / rollthedice / the dice
*	say_team rolldice / rollthedice / roll the dice
*	say vote_rtd / vote_roll / vote_dice
*
* Changelog:
* v 0.7.4c:
*	- Initial beta
*
* v 0.7.7c:
*	- fixed:
*		- alien who got crappy weapon, still got his normal weapon
*		- marine could pickup his old weapon after getting crappy weapon
*		- fixed bug for 32 players
*		- message hud display was fading in and out
*	- changed:
*		- cvar names (to recognize them being from Roll the Dice)
*		- some cvar values
*		- kills by time bomb are shown
*		- now u can have multiple timer prizes (if u manage to get them ;) )
*
* v0.7.9:
*	- fixed:
*		- bug with constant godmode/noclip
*		- setting stealth time to 0 (= no time limit) acted as being disabled
*		- menu did not disappear once voted
*		- when RtD started disabled and been enabled by vote, timer prizes were bugged
*		- diabling RtD by vote did not remove a players prizes
*		- CO: when winning JP/HA players lost their upgrades
*
* v0.8:
*	- changed:
*		- moved from pev/set_pev to entity_get/entity_set (no fakemeta)
*
* v0.8.4b:
*	- fixed:
*		- error with slapdisease
*		- aliens could see marines with stealth
*		- minor errors with hud text
*	- added:
*		- define to either kill or unstuck player after noclip
*		- cvar to only allow RTD on specific mode
*	- changed:
*		- drunken can now be set as a timer prize too (default is none timer prize)
*
* v0.8.6:
*	- fixed:
*		- crash with stealth
*		- rtd_vote_mode was acting wrong
*	- changed:
*		- some tweaks
*
* v0.8.7:
*	- fixed:
*		- no more godmode/noclip for 1 sec even if time set to zero
*		- spawnprotect will not interfer with godmode anymore
*	- changed:
*		- code improvements
*
* v0.8.7b:
*	- fixed:
*		- bug with compiling option "kill_if_stuck"
*
* v0.9.0:
*	- fixed:
*		- some bug fixes
*	- changed:
*		- partly rewritten
*		- removed fun module
*		- added fakemeta
*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <ns>

#define ADMIN_ACCESS	ADMIN_LEVEL_A

// vote configs
#define rtd_ratio		0.5		// % needed to win ( 0.25 = 25% )
#define vote_time		15.0		// how long shall the vote last
#define vote_delay		90.0		// time between 2 votes

#define kill_if_stuck		0		// set to 1 to kill the player when he is stuck after having Noclip (default 0 = try to unstuck player, if fails he gets killed)

#define START_DISTANCE		32		// The first search distance for finding a free location in the map
#define MAX_ATTEMPTS		128		// How many times to search in an area for a free space
#define BLOCKED_MASKS		MASK_PLAYER_STUNNED | MASK_ENSNARED | MASK_ALIEN_EMBRYO

new plugin_author[] = "White Panther/mICKE"
new plugin_version[] = "0.9.0"

// Prize vars
enum{
	prize_timebomb = 1,
	prize_slapdisease,
	prize_god,
	prize_noclip,
	prize_stealth,
	prize_drunken,
	end_of_prize_list
}

enum {
	m_prize_timebomb = 1,
	m_prize_slapdisease = 2,
	m_prize_god = 4,
	m_prize_noclip = 8,
	m_prize_stealth = 16,
	m_prize_drunken = 32,
	m_end_of_prize_list = 64
}

// Speed of each class (NS defaults)
new class_speed[13][] =
{
	"0", "290", "170", "175", "240", "240", "206", "206", "190", "0", "0", "0", "0"
}

/* Cvars*/
#define cvar_num	23

// Cvars
new CVAR_list[cvar_num]
new CVAR_mp_blockscripts, CVAR_mp_friendlyfire

enum {
	CVAR_rtd_skulk_slap_disease = 0,
	CVAR_rtd_fade_slap_disease,
	CVAR_rtd_onos_slap_disease,
	CVAR_rtd_other_slap_disease,
	CVAR_rtd_skulk_slap_dmg,
	CVAR_rtd_gorge_slap_dmg,
	CVAR_rtd_fade_slap_dmg,
	CVAR_rtd_onos_slap_dmg,
	CVAR_rtd_gestate_slap_dmg,
	CVAR_rtd_marine_slap_dmg,
	CVAR_rtd_timebomb_time,
	CVAR_rtd_timebomb_range,
	CVAR_rtd_slap_each_sec,
	CVAR_rtd_speed_boost,
	CVAR_rtd_speed_reduce,
	CVAR_rtd_time,
	CVAR_rtd_chicks,
	CVAR_rtd_god_time,
	CVAR_rtd_noclip_time,
	CVAR_rtd_stealth_time,
	CVAR_rtd_drunken_time,
	CVAR_rtd_vote_mode,
	CVAR_rtd_play_mode
}

new svar[cvar_num][] =
{
	"rtd_skulk_slap_disease","rtd_fade_slap_disease","rtd_onos_slap_disease","rtd_other_slap_disease",	// Damage from slap disease
	"rtd_skulk_slap_dmg","rtd_gorge_slap_dmg","rtd_fade_slap_dmg","rtd_onos_slap_dmg","rtd_gestate_slap_dmg","rtd_marine_slap_dmg",	// Damage from bitch slap
	"rtd_timebomb_time",	// Time till bomb explodes
	"rtd_timebomb_range",	// Radius of bomb
	"rtd_slap_each_sec",	// Time between slaps
	"rtd_speed_boost",	// New speed: normal speed + this
	"rtd_speed_reduce",	// New speed: normal speed - this
	"rtd_time",		// Time between rolls
	"rtd_chicks",		// amount of chickens that can be thrown
	"rtd_god_time",		// Godmode time
	"rtd_noclip_time",	// Noclip time
	"rtd_stealth_time",	// Stealth time (0 = no time limit)
	"rtd_drunken_time",	// Drunken time (0 = no time limit)
	"rtd_vote_mode",	// specify if vote is disabled = 0 / co only = 1 / ns only = 2 / co + ns = 3 / admins only = 4
	"rtd_play_mode"		// specify if rtd is co only = 1 / ns only = 2 / co + ns = 3 / admins only = 4
}

// Values of cvars
new ivar[cvar_num][] =
{
	"6", "20", "50", "10",			// Damage from slap disease
	"50", "90", "190", "550", "150", "70",	// Damage from bitch slap
	"15",					// Time till bomb explodes
	"400",					// Radius of bomb
	"5",					// Time between slaps by slap disease
	"130",					// New speed: normal speed + this
	"80",					// New speed: normal speed - this
	"90",					// Time between rolls
	"200",					// amount of chickens that can be thrown
	"15",					// Godmode time
	"10",					// Noclip time
	"0",					// Stealth time (0 = no time limit)
	"0",					// Drunken time (0 = no time limit)
	"1",					// specify if vote is disabled = 0 / co only = 1 / ns only = 2 / co + ns = 3 / admins only = 4
	"3"					// specify if rtd is co only = 1 / ns only = 2 / co + ns = 3 / admins only = 4
}

// Infos of cvars
new infovar[cvar_num][] =
{
	"Damage by slap disease for Skulk", "Damage by slap disease for Fade", "Damage by slap disease for Onos", "Damage by slap disease for Gorge,Lerk,Marine,Gestate",
	"Damage by bitch slap for Skulk", "Damage by bitch slap for Gorge,Lerk", "Damage by bitch slap for Fade", "Damage by bitch slap for Onos", "Damage by bitch slap for Gestate", "Damage by bitch slap for Marine",
	"Time till bomb explodes",
	"Radius of bomb",
	"Time between slaps by slap disease",
	"Speed increase (newspeed = oldspeed + this)",
	"Speed decrease (newspeed = oldspeed - this)",
	"Time between rolls",
	"Amount of chickens allowed to throw",
	"How long godmode is set",
	"How long noclip is set",
	"How long stealth is set (0 = no time limit)",
	"How long drunken is set (0 = no time limit)",
	"off = 0/co only = 1/ns only = 2/co + ns = 3/admins only = 4",
	"co only = 1 / ns only = 2 / co + ns = 3 / admins only = 4"
}

/* Vars */
new light, smoke, white, fire, fuselight, bottle, chicken, sound_exist, g_maxplayers, combat_running
new DeathMsg_ID
new chicken_exists
new RTD_running = 1
new voters, allow_vote = 1, Float:last_vote = -vote_delay, vote_option[2], player_voted[33]
new prize[33][end_of_prize_list]
new Float:lastroll[33]
new moved[33]
new moves[4][] =
{
	"+moveleft", "+moveright", "+back", "+forward"
}
new moves_clear[4][] =
{
	"-moveleft", "-moveright", "-back", "-forward"
}
//new model_before_stealth[33][64]

/* Init and forwards */
public plugin_init( )
{  
	register_plugin("NS Roll the Dice", plugin_version, plugin_author)
	register_cvar("amx_rtd_version", plugin_version, FCVAR_SERVER)
	set_cvar_string("amx_rtd_version", plugin_version)

	register_concmd("amx_rollthedice", "rollthedice", ADMIN_ACCESS, "<on/off> or <1/0>: Turns Roll the Dice on or off")
	register_concmd("amx_rollthedice_cvar", "rollthedice_cvar", ADMIN_ACCESS, "Type ^"amx_rollthedice_cvar list^" to get all available cvars")
	
	register_clcmd("say", "handle_say")
	register_clcmd("say_team", "handle_say")
	
	register_menucmd(register_menuid("Roll the Dice?") , MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_0, "count_votes")
	
	for ( new a = 0; a < cvar_num; ++a )
		CVAR_list[a] = register_cvar(svar[a], ivar[a])
	
	CVAR_mp_blockscripts = get_cvar_pointer("mp_blockscripts")
	CVAR_mp_friendlyfire = get_cvar_pointer("mp_friendlyfire")
	
	DeathMsg_ID = get_user_msgid("DeathMsg")
	
	set_task(1.0, "timer", 864850, "", 0, "b")
	
	g_maxplayers = get_maxplayers()
	combat_running = ns_is_combat()
}

public client_putinserver( id )
{
	reset(id)
}

public client_changeclass( id , newclass , oldclass )
{
	if ( !is_user_connected(id) )
		return
	
	if( newclass != CLASS_NOTEAM
		&& newclass != CLASS_DEAD )
		return
	
	if ( prize[id][0] & m_prize_timebomb )
		action(id)
	reset(id)
} 

public plugin_precache( )
{
	bottle = precache_model("models/can.mdl")
	fire = precache_model("sprites/explode1.spr")
	fuselight = precache_model("sprites/glow01.spr")
	light = precache_model("sprites/lgtning.spr")
	smoke = precache_model("sprites/steam1.spr")
	white = precache_model("sprites/white.spr")
	precache_sound("buttons/blip2.wav")
	
	if ( file_exists("models/chick.mdl") )
	{
		chicken = precache_model("models/chick.mdl")
		chicken_exists = 1
	}else
		chicken = precache_model("models/headcrab.mdl")
	
	if ( file_exists("sound/ambience/thunder_clap.wav") )
	{
		sound_exist = 1
		precache_sound("ambience/thunder_clap.wav")
	}
}

/* Roll the dice */
public rollthedice( id , level , cid )
{
	if ( !cmd_access(id, level, cid, 2) )
		return PLUGIN_HANDLED
	
	new onoff[5]
	read_argv(1, onoff, 4)
	if ( equal(onoff, "on")
		|| equal(onoff, "1") )
	{
		if ( RTD_running == 1 )
		{
			console_print(id, "Roll the Dice already enabled")
		}else
		{
			RTD_running = 1
			console_print(id, "Roll the Dice enabled")
			set_task(1.0, "timer", 864850, "", 0, "b")
			client_print(0, print_chat, "RTD >> Admin has turned on Roll the Dice")
		}
		return PLUGIN_HANDLED
	}else if ( equal(onoff, "off")
		|| equal(onoff, "0") ) {
		if ( RTD_running == 0 )
		{
			console_print(id, "Roll the Dice already disabled")
		}else
		{
			RTD_running = 0
			console_print(id, "Roll the Dice disabled")
			remove_task(864850)
			
			// reset everything
			for ( new target = 1; target <= g_maxplayers; ++target )
			{
				if ( !is_user_connected(target) )
					continue
				
				reset(target)
			}
			
			client_print(0, print_chat, "RTD >> Admin has turned off Roll the Dice")
		}
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}

public rollthedice_cvar( id , level , cid )
{
	if ( !cmd_access(id, level, cid, 2) )
		return PLUGIN_HANDLED
	
	new arg1[41], arg2[5]
	read_argv(1, arg1, 40)
	read_argv(2, arg2, 4)
	if ( cvar_exists(arg1) )
	{
		new var_num = str_to_num(arg2)
		if (equali(arg2, "") )
		{
			new num
			for ( new a = 0; a < cvar_num; ++a )
			{
				if ( !equal(arg1, svar[a]) )
					continue
				
				num = a
				break
			}
			console_print(id, "%s currently set to %i    |    %s", arg1, get_pcvar_num(CVAR_list[num]), infovar[num])
		}else if ( var_num >= 0 )
		{
			set_cvar_num(arg1, var_num)
			console_print(id, "%s set to %i", arg1, var_num)
		}else
			console_print(id, "You have to enter a digit >= 0")
	}else if ( equal(arg1, "list") )
	{
		console_print(id, "%4s %s %22s %5s       %s"," ","Cvars:"," ","Value:","Info:")
		for ( new a = 0; a < cvar_num; ++a )
			console_print(id, "%3d: %18.18s %10d    |    %s", a + 1, svar[a], get_pcvar_num(CVAR_list[a]), infovar[a])
	}else
		console_print(id,"Not a valid cvar, type ^"amx_rollthedice_cvar list^" to get all available cvars")
	
	return PLUGIN_HANDLED
}

public roll_the_dice( id )
{
	if ( RTD_running == 0
		|| ( combat_running
			&& get_pcvar_num(CVAR_list[CVAR_rtd_play_mode]) == 2 )
		|| ( !combat_running
			&& get_pcvar_num(CVAR_list[CVAR_rtd_play_mode]) == 1 )
		|| ( get_pcvar_num(CVAR_list[CVAR_rtd_play_mode]) == 4
			&& !(get_user_flags(id)&ADMIN_ACCESS) ) )
	{
		client_print(id, print_chat, "RTD >> Roll the Dice is disabled or not allowed in current play mode. Say vote_rtd to start a vote")
		return PLUGIN_HANDLED
	}
	
	new team = pev(id, pev_team)
	if ( team == 0
		|| team == 5 )
	{	// No team
		client_print(id, print_chat, "RTD >> Sorry, join a team first!")
		return PLUGIN_HANDLED
		
	}
	
	if ( is_user_alive(id) == 0 )
	{
		client_print(id, print_chat, "RTD >> I dont play with dead men.")
		return PLUGIN_HANDLED
	}
	
	if ( get_gametime() < ( lastroll[id] + get_pcvar_num(CVAR_list[CVAR_rtd_time]) ) )
	{
		client_print(id, print_chat, "RTD >> You gambled recently, try again in %d seconds", floatround(lastroll[id] + get_pcvar_num(CVAR_list[CVAR_rtd_time]) - get_gametime() ) )
		return PLUGIN_HANDLED
	}
	
	new Red = random(256)
	new Green = random(256)
	new Blue = random(256)
	
	new diceroll = random(23) + 1
	set_hudmessage(id, 100, 200, 0.05, 0.65, 2, 0.02, 4.0, 0.01, 0.1, 2)
	new User[33], msg[128]
	get_user_name(id, User, 32)
	new class = ns_get_class(id)
	//check_cvar_errors()
	
/* Good none weapon prizes */
	switch ( diceroll )
	{
		case 1:
		{
			if ( get_pcvar_num(CVAR_list[CVAR_rtd_god_time]) )
			{
				if ( !( prize[id][0] & m_prize_god ) )
				{
					prize[id][0] += m_prize_god
					set_pev(id, pev_takedamage, 0.0)
				}
				prize[id][prize_god] = get_pcvar_num(CVAR_list[CVAR_rtd_god_time])
				
				print_to_client("RTD >> Congratulations, %s won Godmode!", User)
			}
		}
		case 2:
		{
			if ( get_pcvar_num(CVAR_list[CVAR_rtd_noclip_time]) )
			{
				if ( !( prize[id][0] & m_prize_noclip ) )
				{
					prize[id][0] += m_prize_noclip
					set_pev(id, pev_movetype, MOVETYPE_NOCLIP)
				}
				prize[id][prize_noclip] = get_pcvar_num(CVAR_list[CVAR_rtd_noclip_time])
				
				print_to_client("RTD >> Congratulations, %s won Noclip!", User)
			}
		}
		case 3:
		{
			new Float:max_speed
			pev(id, pev_maxspeed, max_speed)
			if ( ( floatround(max_speed) + get_pcvar_num(CVAR_list[CVAR_rtd_speed_boost]) ) > ( str_to_num(class_speed[class]) + get_pcvar_num(CVAR_list[CVAR_rtd_speed_boost]) ) )
			{
				// already got speed boost, so roll again
				roll_the_dice(id)
				return PLUGIN_HANDLED
			}
			ns_set_speedchange(id, get_pcvar_num(CVAR_list[CVAR_rtd_speed_boost]) )
			
			print_to_client("RTD >> %s has won turbo mode!", User)
		}
		case 4:
		{
			if ( get_pcvar_num(CVAR_list[CVAR_rtd_stealth_time]) )
			{
				if ( !( prize[id][0] & m_prize_stealth ) )
					prize[id][0] += m_prize_stealth
				prize[id][prize_stealth] = get_pcvar_num(CVAR_list[CVAR_rtd_stealth_time])
				
				set_pev(id, pev_rendermode, 2)
				print_to_client("RTD >> %s got stealth mode!", User)
			}
			
			////////// this code could crash server
			/*if ( CLASS_MARINE <= ns_get_class(id) <= CLASS_COMMANDER )
			{
				//set_rendering(id, kRenderFxGlowShell, 9, 9, 9, kRenderTransAlpha, 10)
				pev(id, pev_model, model_before_stealth[id], 63)
				ns_set_player_model(id, "models/null.mdl")
			}else
				set_pev(id, pev_rendermode, 2)*/
			////////////
			
			//set_pev(id, pev_rendermode, 2)
			//print_to_client("RTD >> %s got stealth mode!", User)
		}
		case 5:
		{
			if ( class != CLASS_ONOS )
			{	// onos
				set_pev(id, pev_health, 1000.0)
				print_to_client("RTD >> %s is now GODLIKE with 1000hp!", User)
			}else
			{
				set_pev(id, pev_health, 1700.0)
				print_to_client("RTD >> %s is now GODLIKE with 1700hp!", User)
			}
			
			if ( !( prize[id][0] & m_prize_stealth ) )
				set_rendering(id, kRenderFxGlowShell, 255, 255, 255, kRenderNormal, 16)
		}
		case 6:
		{
			if ( class == CLASS_HEAVY || class == CLASS_FADE ) // Heavy, fade
				set_pev(id, pev_armorvalue, 600.0)
			else if ( class == CLASS_ONOS ) // onos
				set_pev(id, pev_armorvalue, 1200.0)
			else // skulk, gorge, Lerk, gestate, marine, Jetpack, Commander
				set_pev(id, pev_armorvalue, 300.0)
			
			print_to_client("RTD >> %s won a super shield", User)
		}
		case 7:
		{
			mod_spawn(id)
			
			new text[256]
			formatex(text, 255, "RTD >> %s won %i %s !!!", User , get_pcvar_num(CVAR_list[CVAR_rtd_chicks]), chicken_exists ? "CHICKENS" : "HEADCRABS")
			print_to_client(text, User)
/* Bad none weapon prizes */
		}
		case 8:
		{
			new Float:max_speed
			pev(id, pev_maxspeed, max_speed)
			if ( ( floatround(max_speed) - get_pcvar_num(CVAR_list[CVAR_rtd_speed_reduce]) ) > ( str_to_num(class_speed[class]) - get_pcvar_num(CVAR_list[CVAR_rtd_speed_reduce]) ) )
			{
				// already got speed reduce, so roll again
				roll_the_dice(id)
				return PLUGIN_HANDLED
			}
			ns_set_speedchange(id, - get_pcvar_num(CVAR_list[CVAR_rtd_speed_reduce]) )
			
			print_to_client("RTD >> Oh no, %s is an old man now.", User)
		}
		case 9:
		{
			if ( get_pcvar_num(CVAR_list[CVAR_rtd_drunken_time]) )
			{
				if ( !( prize[id][0] & m_prize_drunken ) )
					prize[id][0] += m_prize_drunken
				prize[id][prize_drunken] = get_pcvar_num(CVAR_list[CVAR_rtd_drunken_time])
			}
			set_task(0.5, "drunken", 100 + id, _, _, "b")
			
			print_to_client("RTD >> %s is now a smoking drunkard!", User)
		}
		case 10:
		{
			set_rendering(id, kRenderFxGlowShell, Red, Green, Blue, kRenderNormal, 16)
			
			print_to_client("RTD >> Nice, %s is glowing!", User)
		}
		case 11:
		{
			set_pev(id, pev_health, 1.0)
			new origin[3]
			get_user_origin(id, origin)
			origin[2] = origin[2] - 26
			new sorigin[3]
			sorigin[0] = origin[0] + 150
			sorigin[1] = origin[1] + 150
			sorigin[2] = origin[2] + 400
			lightning(sorigin, origin)
			if ( sound_exist )
				emit_sound(id, CHAN_ITEM, "ambience/thunder_clap.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			
			print_to_client("RTD >> %s now has 1 health!!!", User)
		}
		case 12:
		{
			switch ( class )
			{
				case CLASS_SKULK:
				{	// skulk
					if ( ( get_user_health(id) - get_pcvar_num(CVAR_list[CVAR_rtd_skulk_slap_dmg]) ) < 1 )
					{
						kill_player(id)
					}else
						user_slap(id, get_pcvar_num(CVAR_list[CVAR_rtd_skulk_slap_dmg]))
				}
				case CLASS_GORGE, CLASS_LERK:
				{	// gorge, Lerk
					if ( ( get_user_health(id) - get_pcvar_num(CVAR_list[CVAR_rtd_gorge_slap_dmg]) ) < 1 )
						kill_player(id)
					else
						user_slap(id, get_pcvar_num(CVAR_list[CVAR_rtd_gorge_slap_dmg]))
				}
				case CLASS_GESTATE:
				{	// gestate
					if ( ( get_user_health(id) - get_pcvar_num(CVAR_list[CVAR_rtd_gestate_slap_dmg]) ) < 1 )
						kill_player(id)
					else
						user_slap(id, get_pcvar_num(CVAR_list[CVAR_rtd_gestate_slap_dmg]))
				}
				case CLASS_FADE:
				{	// fade
					if ( ( get_user_health(id) - get_pcvar_num(CVAR_list[CVAR_rtd_fade_slap_dmg]) ) < 1 )
						kill_player(id)
					else
						user_slap(id, get_pcvar_num(CVAR_list[CVAR_rtd_fade_slap_dmg]))
				}
				case CLASS_ONOS:
				{	// onos
					if ( ( get_user_health(id) - get_pcvar_num(CVAR_list[CVAR_rtd_onos_slap_dmg]) ) < 1 )
						kill_player(id)
					else
						user_slap(id, get_pcvar_num(CVAR_list[CVAR_rtd_onos_slap_dmg]))
				}
				default:
				{	// Haevy, Jetpack, marine, Commander
					if ( ( get_user_health(id) - get_pcvar_num(CVAR_list[CVAR_rtd_marine_slap_dmg]) ) < 1 )
						kill_player(id)
					else
						user_slap(id, get_pcvar_num(CVAR_list[CVAR_rtd_marine_slap_dmg]))
				}
			}
			print_to_client("RTD >> %s got bitch slapped!", User)
		}
		case 13:
		{
			if ( prize[id][0] & m_prize_slapdisease )
			{
				// already has slap disease
				roll_the_dice(id)
				return PLUGIN_HANDLED
			}
			prize[id][0] += m_prize_slapdisease
			set_rendering(id, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 16)
			
			print_to_client("RTD >> %s has contracted the deadly slap disease!", User)
		}
		case 14:
		{
			new origin[3]
			get_user_origin(id, origin)
			origin[2] -= 26
			kill_player(id)
			blood(origin)
			explode(origin)
			
			print_to_client("RTD >> %s was killed!", User)
		}
		case 15:
		{
			if ( !( prize[id][0] & m_prize_timebomb ) )
			{
				prize[id][0] += m_prize_timebomb
				set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 16)
				client_cmd(0, "spk ^"vox/warning _comma _comma detonation device activated^"")
				formatex(msg, 127, "%s is now a TimeBomb, run for cover !!!", User)
				set_hudmessage(200, 100, 0, -1.0, 0.30, 0, 6.0, 6.0, 0.5, 0.15, 2)
				show_hudmessage(0, msg)
			}
			prize[id][prize_timebomb] = get_pcvar_num(CVAR_list[CVAR_rtd_timebomb_time])
			
			print_to_client("RTD >> %s is now a human time-bomb!  Everyone RUN for cover", User)
		}
		case 16:
		{
			new Float:origin[3]
			pev(id, pev_origin, origin)
			origin[2] -= 30.0
			entity_set_origin(id, origin)
			
			print_to_client("RTD >> %s has been burried alive!", User)
		}
		case 17:
		{
			print_to_client("RTD >> %s didn't get anything!", User)
/* Weapon + Item prizes */
		}
		case 18:
		{
			if ( class == CLASS_MARINE
				|| class == CLASS_COMMANDER )
			{
				ns_give_item(id, "item_heavyarmor")
				ns_give_item(id, "weapon_welder")
			}else if ( CLASS_SKULK <= class <= CLASS_FADE
				|| class == CLASS_GESTATE )
			{
				ns_give_item(id, "weapon_devour")
				ns_give_item(id, "weapon_stomp")
			}else
			{
				// already has HA or Devour
				roll_the_dice(id)
				return PLUGIN_HANDLED
			}
			print_to_client("RTD >> %s has been given really heavy things!", User)
		}
		case 19:
		{
			if ( class == CLASS_MARINE
				|| class == CLASS_JETPACK
				|| class == CLASS_HEAVY
				|| class == CLASS_COMMANDER )
			{
				new randnum = random(3)
				regive_weaps(id, {15}, 1)
				new weap_item[33]
				if ( randnum == 0 )
					weap_item = "weapon_shotgun"
				else if ( randnum == 1 )
					weap_item = "weapon_heavymachinegun"
		 		else
					weap_item = "weapon_grenadegun"
		 		
		 		ns_give_item(id, weap_item)
			}else if ( class != CLASS_ONOS )
			{
				ns_give_item(id, "weapon_claws")
			}else
			{
				// already has Claws
				roll_the_dice(id)
				return PLUGIN_HANDLED
			}
			print_to_client("RTD >> %s has been given heavy weapons!", User)
		}
		case 20:
		{
			if ( class == CLASS_MARINE
				|| class == CLASS_JETPACK
				|| class == CLASS_HEAVY
				|| class == CLASS_COMMANDER )
			{
				ns_give_item(id,"weapon_mine")
	         		ns_give_item(id,"weapon_grenade")
			}else{
				new randnum = random(3)
				if ( randnum == 0 && class != CLASS_SKULK )
					ns_give_item(id, "weapon_parasite")
				else if ( randnum == 1 && class != CLASS_LERK )
					ns_give_item(id, "weapon_spore")
				else if ( class != CLASS_ONOS )
					ns_give_item(id, "weapon_stomp")
				else
				{
					// already has Parasite, Spore or Stomp
					roll_the_dice(id)
					return PLUGIN_HANDLED
				}
			}
			print_to_client("RTD >> %s has been given support weapons!", User)
		}
		case 21:
		{
			if ( class == CLASS_MARINE
				|| class == CLASS_JETPACK
				|| class == CLASS_HEAVY
				|| class == CLASS_COMMANDER )
			{
				ns_give_item(id, "weapon_welder")
			}else
			{
				new randnum = random(2)
				if ( randnum == 0
					&& class != CLASS_GORGE )
					ns_give_item(id, "weapon_healingspray")
				else if ( class != CLASS_LERK )
					ns_give_item(id, "weapon_umbra")
				else
				{
					// already has Healspray or Umbra
					roll_the_dice(id)
					return PLUGIN_HANDLED
				}
			}
			print_to_client("RTD >> %s has been given revitalizing weapons!", User)
		}
		case 22:
		{
			if ( CLASS_SKULK <= class <= CLASS_ONOS
				|| class == CLASS_GESTATE )
			{	// Aliens
				new randnum = random(2)
				if ( randnum == 0
					&& class != CLASS_LERK )
					ns_give_item(id, "weapon_spikegun")
				else if ( class != CLASS_GORGE )
					ns_give_item(id, "weapon_webspinner")
				else
				{
					// already has Spikes or Webs
					roll_the_dice(id)
					return PLUGIN_HANDLED
				}
			}else
			{	// Marines
				if ( class != CLASS_JETPACK
					&& class != CLASS_HEAVY )
					ns_give_item(id, "item_jetpack")
				else
				{
					// already has Jetpack or HA, so roll again
					roll_the_dice(id)
					return PLUGIN_HANDLED
				}
			}
			print_to_client("RTD >> %s has been given anti-flight gear!", User)
		}
		case 23:
		{
			if ( class == CLASS_MARINE
				|| class == CLASS_JETPACK
				|| class == CLASS_HEAVY
				|| class == CLASS_COMMANDER )
			{
				regive_weaps(id, {16, 17, 20}, 3)
		 		ns_give_item(id, "weapon_machinegun")
			}else if ( class != CLASS_GORGE )
			{
				regive_weaps(id, {1, 2, 5, 6, 7}, 5)
				ns_give_item(id, "weapon_spit")
			}else
			{
				// already has Spit
				roll_the_dice(id)
				return PLUGIN_HANDLED
			}
			print_to_client("RTD >> %s has been given crappy weapons!", User)
		}
	}

	lastroll[id] = get_gametime()
	return PLUGIN_HANDLED
}

public handle_say( id )
{
	new Speech[31]
	read_args(Speech, 30)
	remove_quotes(Speech)
	
	if ( equal(Speech, "rollthedice")
		|| equal(Speech, "rolldice")
		|| equal(Speech, "roll the dice") )
	{
		roll_the_dice(id)
		return PLUGIN_HANDLED
	}
	
	if ( equal(Speech, "vote_rtd")
		|| equal(Speech, "vote_roll")
		|| equal(Speech, "vote_dice") )
	{
		switch ( get_pcvar_num(CVAR_list[CVAR_rtd_vote_mode]) )
		{
			case 0:
			{
				client_print(id, print_chat, "RTD >> Vote has been disabled")
				return PLUGIN_HANDLED
			}
			case 1:
			{
				if ( !combat_running )
				{
					client_print(id, print_chat, "RTD >> Vote is currently only allowed on CO maps")
					return PLUGIN_HANDLED
				}
			}
			case 2:
			{
				if ( combat_running )
				{
					client_print(id, print_chat, "RTD >> Vote is currently only allowed on NS maps")
					return PLUGIN_HANDLED
				}
			}
			case 4:
			{
				if ( !( get_user_flags(id) & ADMIN_ACCESS ) )
				{
					client_print(id, print_chat, "RTD >> Vote is currently only allowed for admins")
					return PLUGIN_HANDLED
				}
			}
		}
		if ( allow_vote )
		{
			if ( get_gametime() - last_vote > vote_delay )
				vote_for_rtd()
			else
				client_print(id, print_chat, "RTD >> Vote for Roll the Dice not allowed right now")
		}else
			client_print(id, print_chat, "RTD >> Currently another vote is running")
		
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

/* Additional Functions */
action( id )
{
	if ( !(prize[id][0] & m_prize_timebomb) )
		return
	
	prize[id][0] = 0
	new name[33]
	get_user_name(id, name, 32)
	
	new team = pev(id, pev_team)
	set_hudmessage(0, 100, 200, 0.05, 0.65, 2, 0.02, 1.0, 0.01, 0.1, 2)
	show_hudmessage(0, "%s has exploded.", name)
	
	new ff = get_pcvar_num(CVAR_mp_friendlyfire)
	new Float:timebomb_range1 = float(get_pcvar_num(CVAR_list[CVAR_rtd_timebomb_range]))
	
	new target_origin[3]
	new target_team
	new bomberkills = get_user_frags(id)
	for ( new target = 1; target <= g_maxplayers; ++target )
	{
		if ( !is_user_connected(target) )
			continue
		
		if ( !is_user_alive(target) )
			continue
		
		if( entity_range(id, target) > timebomb_range1 )
			continue
		
		// Commander cant be killed (he has something like godmode, and i dont like to eject to kill)
		if ( ns_get_class(target) == CLASS_COMMANDER )
			continue
		
		get_user_origin(target, target_origin)
		target_team = pev(target, pev_team)
		
		target_origin[2] -= 26
		if( team != target_team )
		{
			client_print(target, print_chat, "You were to close to the walking timebomb")
			kill_player(target, id)
			++bomberkills
			
			explode(target_origin)
		}else if ( target == id )
		{
			client_print(target, print_chat, "You have exploded")
			kill_player(target)
			
			explode(target_origin)
		}else if( ff == 1 )
		{
			client_print(target, print_chat, "You were to close to the walking timebomb")
			kill_player(target, id)
			
			explode(target_origin)
		}
	}
	set_pev(id, pev_frags, float(bomberkills))
}

reset( id )
{
	prize[id][0] = 0
	for ( new i = 1; i < end_of_prize_list; ++i )
		prize[id][i] = 0
	
	ns_set_speedchange(id, 0 )
	//set_rendering(id,kRenderFxGlowShell,0,0,0,kRenderTransAlpha,255)
	set_rendering(id,kRenderFxGlowShell, 0, 0, 0, kRenderNormal, 0)
	remove_task(100 + id)
	reset_drunken(id)
	
	remove_task(200 + id)
	set_pev(id, pev_takedamage, 2.0)
	set_pev(id, pev_movetype, MOVETYPE_WALK)
}

reset_drunken( id )
{
	if ( get_pcvar_num(CVAR_mp_blockscripts) == 1 )
	{
		client_cmd(id, "%s", "-forward")
		new param[2]
		param[0] = id
		param[1] = 0
		set_task(0.1, "clear_movement", 300 + id, param, 2)
	}else
		client_cmd(id, "-moveleft;-moveright;-forward;-back")
	
	moved[id] = 0
}

public clear_movement( param[2] )
{
	new id = param[0]
	if ( !is_user_connected(id) )
		return
	
	client_cmd(id, "%s", moves_clear[param[1]])
	if ( param[1] < 3 )
	{
		++param[1]
		set_task(0.1, "clear_movement", 300 + id, param, 2)
	}
}

kill_player( id , bomb_killer = 0 )
{
	set_msg_block(DeathMsg_ID, BLOCK_ONCE)
	fakedamage(id, "trigger_hurt", 9999.0, 0)
	if ( !bomb_killer )
		return
	
	message_begin( MSG_ALL, DeathMsg_ID, {0,0,0}, 0)
	write_byte(bomb_killer)
	write_byte(id)
	write_string("Time Bomb")
	message_end()
}

mod_spawn( id )
{
	set_task(0.3, "make_mod", 200 + id, _, _, "a", 100)
	
	return PLUGIN_HANDLED
}

print_to_client( msg_to_send[] , user_name[] )
{
	for ( new target = 1; target <= g_maxplayers; ++target )
	{
		if ( !is_user_connected(target) )
			return
		
		if ( CLASS_UNKNOWN < ns_get_class(target) < CLASS_NOTEAM )
			client_print(target, print_chat, msg_to_send, user_name)
	}
}

vote_for_rtd( )
{
	allow_vote = 0
	last_vote = get_gametime()
	set_task(vote_time, "check_votes", 864851)
	vote_menu()
}

vote_menu( )
{
	new keys = MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_0
	new Float:holdtime = last_vote + vote_time - get_gametime()
	set_hudmessage(255, 255, 255, -2.0, 0.30, 0, 6.0, holdtime, 0.5, 0.15, 1)
	new menu_body[256]
	for ( new target = 1; target <= g_maxplayers; ++target )
	{
		if ( !is_user_connected(target) )
			continue
		
		formatex(menu_body, 255, "Roll the Dice?%s^n^n%sYes (%i)^n%sNo (%i)", player_voted[target] ? " (voted)" : "", player_voted[target] ? "" : "1.  ", vote_option[0], player_voted[target] ? "" : "2.  ", vote_option[1])
		if ( !player_voted[target] )
			show_menu(target, keys, menu_body, floatround(vote_delay))
		else
			show_hudmessage(target, menu_body)
	}
}

public count_votes( id , key )
{
	if ( key >= 9 )
		return PLUGIN_HANDLED
	
	if ( !player_voted[id] )
	{
		++vote_option[key]
		++voters
		player_voted[id] = key + 1
	}
	vote_menu()
	
	return PLUGIN_HANDLED
}

regive_weaps( id , bad_weapons[] , bad_num )
{
	new weapon_list[32], weapon_num
	get_user_weapons(id, weapon_list, weapon_num)
	
	//strip_user_weapons(id)
	new stripper = create_entity("player_weaponstrip")
	DispatchSpawn(stripper)
	fake_touch(id, stripper)
	remove_entity(stripper)
	
	for ( new a = 0; a < weapon_num; ++a )
	{
		new found
		for ( new b = 0; b < bad_num; ++b )
		{
			if ( weapon_list[a] != bad_weapons[b] )
				continue
			
			bad_weapons[b] = bad_weapons[bad_num - 1]
			--bad_num
			found = 1
		}
		if ( found )
			continue
		
		new weapon_name[33]
		get_weaponname(weapon_list[a], weapon_name, 32)
		ns_give_item(id, weapon_name)
	}
}

check_if_stuck( id )
{
	new Float:origin[3]
	pev(id, pev_origin, origin)
	new hullsize = getHullSize(id)
	if ( !hullsize )
		return 0
	
	if ( trace_hull(origin, hullsize, id) == 0 )
		return 0
	
	return 1
}

getHullSize( id )
{
	switch ( ns_get_class(id) )
	{
		case 1, 2, 3:
			return HULL_HEAD
		case 4, 6, 7, 8:
			return (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN
		case 5:
			return (pev(id, pev_flags) & FL_DUCKING) ? HULL_HUMAN : HULL_LARGE
		default: {
			return false
		}
	}
	return false
}

#if kill_if_stuck == 0
unstuck( id )
{
	if ( ns_get_mask(id, BLOCKED_MASKS) )
		return
	
	new Float:origin[3], Float:new_origin[3], hullsize, distance
	
	hullsize = getHullSize(id)
	if ( !hullsize )
		return
	
	pev(id, pev_origin, origin)
	distance = START_DISTANCE
	
	while( distance < 1000 )
	{	// 1000 is just incase, should never get anywhere near that
		for ( new i = 0; i < MAX_ATTEMPTS; ++i )
		{
			new_origin[0] = random_float(origin[0] - distance, origin[0] + distance)
			new_origin[1] = random_float(origin[1] - distance, origin[1] + distance)
			new_origin[2] = random_float(origin[2] - distance, origin[2] + distance)
			
			if ( trace_hull(new_origin, hullsize, id) == 0 )
			{
				entity_set_origin(id, new_origin)
				return
			}
		}
		distance += START_DISTANCE
	}
	
	fakedamage(id, "trigger_hurt", 9999.0, 0)
	client_print(id, print_chat, "RTD >> You got killed cause of being stuck and unstucking failed")
}
#endif

/* Timer */
public timer( )
{
	for ( new id = 1; id <= g_maxplayers; ++id )
	{
		if ( !is_user_connected(id) )
			continue
		
		new class = ns_get_class(id)
		new msg[256] = "Remaining"
		new found_hud_msg
		
		// check for each prize that has a timer
		if ( prize[id][0] & m_prize_timebomb )
		{
			new origin[3]
			get_user_origin(id, origin)
			
			new Float:takedamage
			pev(id, pev_takedamage, takedamage)
			new godmode = ( takedamage == 0.0 ) ? 1 : 0
			if ( ( class == CLASS_COMMANDER
					|| godmode )
				&& prize[id][prize_timebomb] == 1 )
			{
				// commander and godmode user cannot be killed so keep the timer running without any effects shown
			}else
			{
				//TE_SPRITE	
				message_begin(MSG_BROADCAST, SVC_TEMPENTITY, {0, 0, 0}, id)
				write_byte(17) // additive sprite, plays 1 cycle
				write_coord(origin[0]) // pos
				write_coord(origin[1]) // pos
				write_coord(origin[2] + 20) // pos
				write_short (fuselight) // spr index	
				write_byte(20) // (scale in 0.1's) 
				write_byte (200) //(brightness)
				message_end()
				
				if ( prize[id][prize_timebomb] <= 1 )	// && class != CLASS_COMMANDER ){
				{
					action(id)
				}else
				{
					if( class == CLASS_DEAD )
						action(id)
					else
					{
						emit_sound(id, CHAN_ITEM, "buttons/blip2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
						
						--prize[id][prize_timebomb]
						new name[33]
						get_user_name(id, name, 32)
						set_hudmessage(200, 0, 0, 0.05, 0.35, 2, 0.02, float(get_pcvar_num(CVAR_list[CVAR_rtd_timebomb_time])), 0.01, 0.1, 2)
						//set_hudmessage(255, 255, 255, -1.0, 0.30, 0, 6.0, 6.0, 0.5, 0.15, 3)
						show_hudmessage(0, "%s will explode in %i second%s.", name,prize[id][prize_timebomb], (prize[id][prize_timebomb] == 1) ? "" : "s")
						if ( prize[id][prize_timebomb] == 11 )
						{
							client_cmd(0, "spk ^"fvox/remaining^"")
						}else if ( prize[id][prize_timebomb] < 11 )
						{
							new temp[48]
							num_to_word(prize[id][1], temp, 48)
							client_cmd(0, "spk ^"fvox/%s^"", temp)
						}
					}
				}
			}
		}
		if ( prize[id][0] & m_prize_slapdisease )
		{
			if ( prize[id][prize_slapdisease] >= get_pcvar_num(CVAR_list[CVAR_rtd_slap_each_sec]) )
			{
				user_slap(id, 0)
				switch ( class )
				{
					case CLASS_SKULK:
					{	// skulk
						if ( ( get_user_health(id) - get_pcvar_num(CVAR_list[CVAR_rtd_skulk_slap_disease]) ) < 1 )
							kill_player(id)
						else
							user_slap(id, get_pcvar_num(CVAR_list[CVAR_rtd_skulk_slap_disease]))
					}
					case CLASS_FADE:
					{	// fade
						if ( ( get_user_health(id) - get_pcvar_num(CVAR_list[CVAR_rtd_fade_slap_disease]) ) < 1 )
							kill_player(id)
						else
							user_slap(id, get_pcvar_num(CVAR_list[CVAR_rtd_fade_slap_disease]))
					}
					case CLASS_ONOS:
					{	// onos
						if ( ( get_user_health(id) - get_pcvar_num(CVAR_list[CVAR_rtd_onos_slap_disease]) ) < 1 )
							kill_player(id)
						else
							user_slap(id, get_pcvar_num(CVAR_list[CVAR_rtd_onos_slap_disease]))
					}
					case CLASS_COMMANDER:
					{	// commander can be slaped but not to death, so keep the timer running
						user_slap(id, get_pcvar_num(CVAR_list[CVAR_rtd_other_slap_disease]))
					}
					default:
					{	// gorge, Lerk, marine, gestate
						if ( ( get_user_health(id) - get_pcvar_num(CVAR_list[CVAR_rtd_other_slap_disease]) ) < 1 )
							kill_player(id)
						else
							user_slap(id, get_pcvar_num(CVAR_list[CVAR_rtd_other_slap_disease]))
					}
				}
				prize[id][prize_slapdisease] = 1
			}else
				++prize[id][prize_slapdisease]
		}
		if ( prize[id][0] & m_prize_god )
		{
			if ( prize[id][prize_god] <= 1 )
			{
				set_pev(id, pev_takedamage, 2.0)
				prize[id][0] -= m_prize_god
			}else
			{
				--prize[id][prize_god]
				set_pev(id, pev_takedamage, 0.0)
				//show_hudmessage(a,"Godmode remaining %i second%s",prize[id][1], (prize[id][1] == 1) ? "" : "s")
				new temp_str[128]
				formatex(temp_str, 127, "^nGodmode: %i second%s", prize[id][prize_god], (prize[id][prize_god] == 1) ? "" : "s")
				add(msg, 255, temp_str)
				found_hud_msg = 1
			}
		}
		if ( prize[id][0] & m_prize_noclip )
		{
			if ( prize[id][prize_noclip] <= 1 )
			{
				set_pev(id, pev_movetype, MOVETYPE_WALK)
				prize[id][0] -= m_prize_noclip
				if ( check_if_stuck(id) )
				{
#if kill_if_stuck == 1
					fakedamage(id, "trigger_hurt", 9999.0, 0)
					client_print(id, print_chat, "RTD >> You got killed cause of being stuck")
#else
					unstuck(id)
#endif
				}
			}else
			{
				--prize[id][prize_noclip]
				//show_hudmessage(a,"Noclip remaining %i second%s",prize[a][1], (prize[a][1] == 1) ? "" : "s")
				new temp_str[128]
				formatex(temp_str, 127, "^nNoclip: %i second%s", prize[id][prize_noclip], (prize[id][prize_noclip] == 1) ? "" : "s")
				add(msg, 255, temp_str)
				found_hud_msg = 1
			}
		}
		if ( prize[id][0] & m_prize_stealth )
		{
			if ( prize[id][prize_stealth] <= 1 )
			{
				/*if ( CLASS_MARINE <= ns_get_class(a) <= CLASS_COMMANDER )
					ns_set_player_model(a,model_before_stealth[a])
				else
					set_pev(a, pev_rendermode, 0)*/
				set_pev(id, pev_rendermode, 0)
				//set_rendering(a, kRenderFxGlowShell, 0, 0, 0, kRenderNormal, 0)
				prize[id][0] -= m_prize_stealth
			}else
			{
				--prize[id][prize_stealth]
				//show_hudmessage(a,"Stealth remaining %i second%s",prize[a][1], (prize[a][1] == 1) ? "" : "s")
				new temp_str[128]
				formatex(temp_str, 127, "^nStealth: %i second%s", prize[id][prize_stealth], (prize[id][prize_stealth] == 1) ? "" : "s")
				add(msg, 255, temp_str)
				found_hud_msg = 1
			}
		}
		if ( prize[id][0] & m_prize_drunken )
		{
			if ( prize[id][prize_drunken] <= 1 )
			{
				prize[id][0] -= m_prize_drunken
				remove_task(100 + id)
				reset_drunken(id)
			}else
			{
				--prize[id][prize_drunken]
				new temp_str[128]
				formatex(temp_str, 127, "^nDrunken: %i second%s", prize[id][prize_drunken], (prize[id][prize_drunken] == 1) ? "" : "s")
				add(msg, 255, temp_str)
				found_hud_msg = 1
			}
		}
		if ( found_hud_msg )
		{
			set_hudmessage(0, 100, 200, 0.05, 0.65, 2, 0.02, float(get_pcvar_num(CVAR_list[CVAR_rtd_god_time])), 0.01, 0.1, 3)
			show_hudmessage(id, msg)
		}
	}
}

public drunken( timerid_id )
{
	new id = timerid_id - 100
	if ( !is_user_connected(id) )
		return
	
	if( !is_user_alive(id) )
		return
	
	new vec[3]
	get_user_origin(id, vec)
	new y1,x1
	x1 = random_num(-40, 40)
	y1 = random_num(-40, 40)
	
	//Smoke
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(5)		// 5
	write_coord(vec[0] + x1)
	write_coord(vec[1] + y1)
	write_coord(vec[2] + 30)
	write_short( smoke )
	write_byte(30)		// 10
	write_byte(10)		// 10
	message_end()
	
	if ( moved[id] )
	{
		/*client_cmd(id, "-moveleft")
		client_cmd(id, "-moveright")
		client_cmd(id, "-forward")
		client_cmd(id, "-back")*/
		reset_drunken(id)
	}
	
	new b = random(10)
	if ( b != 1 )
		return
	
	new a = random(4)
	client_cmd(id, "%s", moves[a])
	moved[id] = 1
	new aimvec[3]
	new velocityvec[3]
	new length
	new speed = 500
	get_user_origin(id, aimvec, 2)
	velocityvec[0] = aimvec[0] - vec[0]
	velocityvec[1] = aimvec[1] - vec[1]
	velocityvec[2] = aimvec[2] - vec[2]
	length = floatround( floatsqroot( float(velocityvec[0] * velocityvec[0] + velocityvec[1] * velocityvec[1] + velocityvec[2] * velocityvec[2]) ) )
	
	if ( length == 0 )
		length = 1
	
	velocityvec[0] = velocityvec[0] * speed / length
	velocityvec[1] = velocityvec[1] * speed / length
	velocityvec[2] = velocityvec[2] * speed / length
	
	// TE_MODEL from HL-SDK common/const.h
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(106)
	write_coord(vec[0])
	write_coord(vec[1])
	write_coord(vec[2] + 20)
	write_coord(velocityvec[0])
	write_coord(velocityvec[1])
	write_coord(velocityvec[2] + 100)
	write_angle(0)
	write_short(bottle)
	write_byte(2)
	write_byte(255)
	message_end()
}

public make_mod( timerid_id )
{
	new id = timerid_id - 200
	if ( !is_user_connected(id) )
		return
	
	new vec[3]
	new aimvec[3]
	new velocityvec_x, velocityvec_y, velocityvec_z
	new length
	new speed = 800
	get_user_origin(id, vec)
	get_user_origin(id, aimvec, 2)
	
	velocityvec_x = aimvec[0] - vec[0]
	velocityvec_y = aimvec[1] - vec[1]
	velocityvec_z = aimvec[2] - vec[2]
	
	length = floatround( floatsqroot( float(velocityvec_x * velocityvec_x + velocityvec_y * velocityvec_y + velocityvec_z * velocityvec_z) ) )
	
	if ( !length )
		length = 1
	
	velocityvec_x = velocityvec_x * speed / length
	velocityvec_y = velocityvec_y * speed / length
	velocityvec_z = velocityvec_z * speed / length
	
	// TE_MODEL from HL-SDK common/const.h
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(106)			// TE_MODEL index
	write_coord(vec[0])		// location coords
	write_coord(vec[1])
	write_coord(vec[2] + 20)
	write_coord(velocityvec_x)	// speed coords - stupid, but thats how its done
	write_coord(velocityvec_y)
	write_coord(velocityvec_z + 100)
	write_angle(0)			// yaw
	write_short(chicken)		// model
	write_byte(2)			// sound
	write_byte(255)			// duration
	message_end()
}

public check_votes( )
{
	allow_vote = 1
	for ( new id = 1; id <= g_maxplayers; ++id )
	{
		if ( !is_user_connected(id) )
			continue
		
		client_cmd(id, "slot10")
		player_voted[id] = 0
	}
	
	new winner
	if ( vote_option[0] > vote_option[1] )
		winner = 0
	else if ( vote_option[0] < vote_option[1] )
		winner = 1
	else if ( vote_option[0] == vote_option[1] )
		winner = 2
	
	new cur_players = get_playersnum()
	
	if ( cur_players )
	{
		client_print(0, print_chat, "RTD >> vote results: (voters %i) / (yes %i) (no %i) / (need to win %i)", voters, vote_option[0], vote_option[1], floatround( rtd_ratio * float( cur_players ) ,floatround_ceil) )
		if ( winner != 2 )
		{
			new Float:result = float(vote_option[winner]) / float(cur_players)
			if ( result >= rtd_ratio )
			{
				if ( winner == 0 )
				{
					if ( RTD_running )
					{
						client_print(0, print_chat, "RTD >> Vote over: Roll the Dice will stay enabled")
					}else
					{
						client_print(0, print_chat, "RTD >> Vote over: Roll the Dice will be enabled")
						RTD_running = 1
						set_task(1.0, "timer", 864850, "", 0, "b")
					}
				}else if ( winner == 1 )
				{
					if ( RTD_running )
					{
						client_print(0, print_chat, "RTD >> Vote over: Roll the Dice will be disabled")
						RTD_running = 0
						remove_task(864850)
						
						// reset everything
						for ( new id = 1; id <= g_maxplayers; ++id )
						{
							if ( is_user_connected(id) )
								reset(id)
						}
					}else
						client_print(0, print_chat, "RTD >> Vote over: Roll the Dice will stay disabled")
				}
			}
		}else
			client_print(0, print_chat, "RTD >> %s: Roll the Dice will stay %s", winner == 2 ? "Tie" : "Not enough votes", RTD_running ? "enabled" : "disabled")
	}
	
	voters = 0
	vote_option[0] = 0
	vote_option[1] = 0
}

/* FX */
explode( vec[3] )
{
	// blast circles
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY, vec)
	write_byte(21)
	write_coord(vec[0])
	write_coord(vec[1])
	write_coord(vec[2] + 16)
	write_coord(vec[0])
	write_coord(vec[1])
	write_coord(vec[2] + 1936)
	write_short(white)
	write_byte(0)		// startframe
	write_byte(0)		// framerate
	write_byte(3)		// life 2
	write_byte(20)		// width 16
	write_byte(0)		// noise
	write_byte(188)		// r
	write_byte(220)		// g
	write_byte(55)		// b
	write_byte(255)		//brightness
	write_byte(0)		// speed
	message_end()
		
	//Explosion2
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(12)
	write_coord(vec[0])
	write_coord(vec[1])
	write_coord(vec[2])
	write_byte(188)		// byte (scale in 0.1's) 188
	write_byte(10)		// byte (framerate)
	message_end()

	//TE_Explosion
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY, vec)
	write_byte(3)
	write_coord(vec[0])
	write_coord(vec[1])
	write_coord(vec[2])
	write_short(fire)
	write_byte(65)		// byte (scale in 0.1's) 188
	write_byte(10)		// byte (framerate)
	write_byte(0)		// byte flags
	message_end()

	//Smoke 
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY, vec) 
	write_byte(5)		// 5
	write_coord(vec[0]) 
	write_coord(vec[1]) 
	write_coord(vec[2]) 
	write_short(smoke)
	write_byte(10)		// 2
	write_byte(10)		// 10
	message_end()
} 

blood( vec1[3] )
{
	//LAVASPLASH
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(10)
	write_coord(vec1[0])
	write_coord(vec1[1])
	write_coord(vec1[2])
	message_end()
}

lightning( vec1[3] , vec2[3])
{
	//Lightning
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(0)
	write_coord(vec1[0])
	write_coord(vec1[1])
	write_coord(vec1[2])
	write_coord(vec2[0])
	write_coord(vec2[1])
	write_coord(vec2[2])
	write_short(light)
	write_byte(1)		// framestart
	write_byte(5)		// framerate
	write_byte(2)		// life
	write_byte(20)		// width
	write_byte(30)		// noise
	write_byte(200)		// r, g, b
	write_byte(200)		// r, g, b
	write_byte(200)		// r, g, b
	write_byte(200)		// brightness
	write_byte(200)		// speed
	message_end()

	//Sparks
	message_begin(MSG_PVS, SVC_TEMPENTITY, vec2)
	write_byte(9)
	write_coord(vec2[0])
	write_coord(vec2[1])
	write_coord(vec2[2])
	message_end()
}
