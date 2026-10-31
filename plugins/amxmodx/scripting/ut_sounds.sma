/*
#############################################################################################################
#                           NS (Natural Selection)UT Sounds version 1.0                                     #					
#############################################################################################################
*
* Author:
*	-> Rothgar
*
* Description:
*	UT Sound script for Natural Selection scripted for AMXModX 1.8.1+. This	script has been tested with
*	NS 3.2 (Natural Selection) and AMXModX 1.8.1. This script if configured correctly will play UT Sounds
*	to your entire	server (or killer only) based on a number of console variables. It will also print
*	messages to the chat area for those who have sounds disabled. Users have the choice of having sounds
*	enabled or disabled based on chat triggers which work per-user per-session. There is also an experience
*	mode where the script can add experience (on CO maps) for the killer when they trigger events.
*
* Credits:
*	-> White Panther		> For using his credit block formating & help with round-end checking
*	-> TopChris				> For porting the original UT script even though it was a nightmare to
*							re-write due to crazy code which did not make sense >_<
*	-> White Knight			> For helping test
*	-> CustomFactor Server	> Being a test bed for the re-written script
*	-> amckern				> Helping test humiliation
*	-> P34CH_34732			> Suggestions and help on round_end function
*	-> sawce				> Crazy ammounts of NS AMXModX knowledge!
*	-> SAMURAI16			> End-of-round Command Chair calculation fix
*
* Required Files (Case Sensitive?):
*
*	-> These files can be downloaded from http://www.dawgclan.net
*
*	-> ns/sound/misc/doublekill.wav
*	-> ns/sound/misc/triplekill.wav
*	-> ns/sound/misc/multikill.wav
*	-> ns/sound/misc/megakill.wav
*	-> ns/sound/misc/ultrakill.wav
*	-> ns/sound/misc/monsterkill.wav
*	-> ns/sound/misc/LudicrousKill.wav
*	-> ns/sound/misc/HolyShit.wav
*	-> ns/sound/misc/killingspree.wav
*	-> ns/sound/misc/rampage.wav
*	-> ns/sound/misc/dominating.wav
*	-> ns/sound/misc/unstoppable.wav
*	-> ns/sound/misc/godlike.wav
*	-> ns/sound/misc/WhickedSick.wav
*	-> ns/sound/misc/firstblood.wav
*	-> ns/sound/misc/humiliation.wav
*	-> ns/sound/misc/Humiliating_Defeat.wav
*	-> ns/sound/misc/You_have_won_the_match.wav
*	-> ns/sound/misc/Play.wav      
*	-> ns/sound/misc/impressive.wav
*	-> ns/sound/misc/llama.wav
*
*
* Usage:
*
*	-> say "ut_sounds" or to enable/disable sounds in-game
*	-> say "ut_on" to turn the UT sounds on in-game
*	-> say "ut_off" to turn the UT sounds off in-game
*	->
*	-> The following cvars work as follows:
*	->
*	->		0 (Disabled)
*	->		1 (Default, Enabled and play sounds to all players on server)
*	->		2 (Enabled and play sounds to killer only)
*	->
*	->	ut_play (Play sound at round start)
*	->	ut_victory (Victory/Defeat sounds for end of round)
*	->	ut_llamatkmode
*		Llama sound for TK'ers who exceed the TK threshold defined below
*	->	ut_humiliationmode
*			This sound is played for users who are killed by a humiliating weapon:
*
*				Knife
*				Welder
*				Charge
*				Spike Gun
*				Healing Spray
*				Parasite
*				Leap
*				Hand Grenade
*
*	->	ut_excellentmode
*			If enabled, excellent sound will play at the end of round if a player has a K/D ratio
*			of the "excellent ratio" value defined by the cvar below.
*	->	ut_impressivemode (Impressive sound)
*	->	ut_firstbloodmode
*			First blood sound, this triggers for the first kill in a round.
*	->	ut_multikillmode
*			If enabled, multi-kill sounds will play after a player successfully kills the amount
*			of players greater than or equal the number defined in the "multi-kill start" cvar
*			divided by the "multi-kill step" cvar and each aditional kill made must be within the
*			"multi-kill interval" time. cvars explained below.
*	->	ut_multikillspam
*			This cvar is used in conjunction with "multi-kill mode". If "multi-kill mode" is set
*			to 1 (Play sounds to all players) and this cvar is enabled, sounds will only play to
*			the entire server after a player has reached the multi-kill level defined by this cvar.
*			Sounds below this level will play to killer only. Default 2 
*	->	ut_killingspreemode (Killing spree sound(s))
*
*	-> ut_llamatks			- Number of TK's required to trigger llamatk's. Default 3
*	-> ut_impressivekills	- Number of kills required w/o death to trigger impressive. Default 9
*	-> ut_excellentratio	- Ratio required to trigger excellent. Default 4
*	-> ut_expmode			- Experience mode. 1 = Enabled, 0 = Disabled. Default 0
*	-> ut_multikillstart
*			Kills required for a Multi-kill sequence to start, relies on ut_multikillstep. Default 2
*	-> ut_multikillstep
*			Number of kills required to advance a Multi-kill level. Default 1
*	-> ut_multikillinterval
*			Defines the number of seconds between kills allowed before Multi-kill resets. Default 10
*	-> ut_killingspreestart
*			Kills required for a Killingspree sequence to start, relies on ut_killingspreestep. Default 10
*	-> ut_killingspreestep
*			Number of kills required to advance a Killingspree level. Default 2
*
*
* Version history:
*
*	v1.0: (Initial release after re-write)
*	- fixed:
*		- Everything...
*	- added:
*		- Optimizations + Enhancements
*	- changed:
*		- Most of the code...
*
*	v1.0.1:
*	- fixed:
*		- Extra un-necessary parameter in Excellent message... Who knows why it was there in the first place?
*		- Error in multi-kill function calculations causing out-of-bounds errors.
*	- added:
*		- Tracking cvar to find how many server might be running this plugin?
*	- changed:
*		- Multi-kill message syntax to now include name of player who triggered the event.
*/

/*
INT (1)
0 - Do use default helper output
1 - Use the "Helper" plugin! (recommended)
*/
#define HELPER 1

#include <amxmodx>
#include <ns>
#include <fakemeta>

#if HELPER == 1
  #include <helper>
#endif

// No MaxPlayers auto-define?
#define MAXPLAYERS 32

// HUD channel (1 - 4) to use to show the vote results and to show the time
// remaining to a vote (can conflict with other plugins)
#define DISPLAY_HUD_CHANNEL 4

// Define Colors
new Blue[3] = {0,63,191}
new Red[3] = {255,0,0}
new Green[3] = {0,191,63}
new Purple[3] = {128,0,128}
new Yellow[3] = {230,230,0}

// Force clients to download wav files
// Assumed if you disable the sound download the sound should be disabled...
/*
*	MK = Multi Kill
*	KS = Killing Spree
*	FB = First Blood
*	HM = Humiliation
*	HD = Humiliating Defeat
*	WV = Winning Victory
*	PL = Play
*	IM = Impressive
*	EX = Excellent
*	LL = Llama
*/

#define DL_MK true
#define DL_WV true
#define DL_HD true
#define DL_KS true
#define DL_FB true
#define DL_HM true
#define DL_PL true
#define DL_IM true
#define DL_EX true
#define DL_LL true





// Should Be Nothing To Edit Below This Line


// Define Teams
#define UNDEFINED 0
#define MARINE 1
#define ALIEN 2
new g_team[2] = {UNDEFINED,...}
new g_teamtype[2] = {UNDEFINED,...}


// Define variables
new bool:firstblood = false
new ut_sounds_enabled[MAXPLAYERS + 1] = {1,...}
new MK_count[MAXPLAYERS + 1] = {0,...}
new Float:MK_last_kill[MAXPLAYERS + 1] = {0.0,...}
new KS_count[MAXPLAYERS + 1] = {0,...}
new IM_count[MAXPLAYERS + 1] = {0,...}
new LL_tks[MAXPLAYERS + 1] = {0,...}
new victory_mode = 0, firstblood_mode = 0, llamatk_mode = 0
new humiliation_mode = 0, multikill_mode = 0, exp_mode = 0
new killingspree_mode = 0, excellent_mode = 0, impressive_mode = 0
new llamatk_tks, impressive_kills, excellent_ratio
new multikill_spam, multikill_step, killingspree_step

// Need to be defined default values due to checks in death function
new multikill_start = 2, multikill_interval = 10
new killingspree_start = 10
// Plugin Version
#define UT_VERSION "1.0.1"


// Define messages
// First Blood
new FB_msg[] = "%s drew first blood!"
new FB_snd[] = "misc/firstblood.wav"

// Humiliation
new HM_msg[] = "%s has humiliated %s with a %s!"
new HM_snd[] = "misc/humiliation.wav"

// Win Round
new WV_msg[] = "You have won the match"
new WV_snd[] = "misc/You_have_won_the_match.wav"

// Lose Round
new HD_msg[] = "You have suffered a humiliating defeat"
new HD_snd[] = "misc/Humiliating_Defeat.wav"

// Start Round
new PL_msg[] = "Play"
new PL_snd[] = "misc/play.wav"

// Impressive Kill
new IM_msg[] = "%s is impressive with %d kills after killing %s"
new IM_snd[] = "misc/impressive.wav"

// Excellent Kill
new EX_msg[] = "%s is excellent with %d kills and only %d deaths"
new EX_snd[] = "misc/excellent.wav"

// Team Kill
new LL_msg[] = "%s is a Llama with %d teamkills"
new LL_snd[] = "misc/llama.wav"

// Killing Spree
new KS_endmsg[] = "%s's killing spree was ended by %s"
new KS_suicidemsg[] = "%s was looking good till he killed himself!"


// Define Sound Settings
#define MK_LEVELS 8
new MK_msg[MK_LEVELS][] = {
	"Double Kill!",
	"Triple Kill!",
	"Multi Kill!",
	"MEGA KILL!",
	"ULTRA KILL!!!",
	"M O N S T E R   K I L L!!!",
	"L U D I C R O U S   K I L L!!!",
	"H O L Y   S H I T!!!!!!"
}
new MK_snd[MK_LEVELS][] = {
	"misc/doublekill.wav",
	"misc/triplekill.wav",
	"misc/multikill.wav",
	"misc/megakill.wav",
	"misc/ultrakill.wav",
	"misc/monsterkill.wav",
	"misc/LudicrousKill.wav",
	"misc/HolyShit.wav"
}

#define KS_LEVELS 6
new KS_msg[KS_LEVELS][] = {
	"%s is on a killing spree!",
	"%s is on a rampage!",
	"%s is dominating!",
	"%s is unstoppable!",
	"%s is Godlike!",
	"%s is Wicked Sick!!!"
}
new KS_snd[KS_LEVELS][] = {
	"misc/killingspree.wav",
	"misc/rampage.wav",
	"misc/dominating.wav",
	"misc/unstoppable.wav",
	"misc/godlike.wav",
	"misc/WhickedSick.wav"
}


// Base Functions
public plugin_init() {
	register_plugin("UT Sounds NS",UT_VERSION,"Rothgar")
	register_cvar("ut_version", UT_VERSION, FCVAR_SERVER)
	set_cvar_string("ut_version",UT_VERSION)

	register_event("DeathMsg", "event_Death", "ab")
	register_event("HudText2", "event_roundEnd", "ab")
	register_clcmd("say ut_sounds","ut_toggle",0,"typing this in will disable/enable the ut sounds")
	register_clcmd("say_team ut_sounds","ut_toggle",0,"typing this in will disable/enable the ut sounds")
	register_clcmd("say ut_on","ut_enable",0,"typing this in will enable the ut sounds")
	register_clcmd("say_team ut_on","ut_enable",0,"typing this in will enable the ut sounds")
	register_clcmd("say ut_off","ut_disable",0,"typing this in will disable the ut sounds")
	register_clcmd("say_team ut_off","ut_disable",0,"typing this in will disable the ut sounds")
	register_cvar("ut_llamatkmode", "1")
	register_cvar("ut_humiliationmode", "1")
	register_cvar("ut_victory", "1")
	register_cvar("ut_play", "1")
	register_cvar("ut_expmode", "0")
	register_cvar("ut_llamatks", "3")
	register_cvar("ut_excellentmode", "1")
	register_cvar("ut_impressivemode", "1")
	register_cvar("ut_firstbloodmode", "1")
	register_cvar("ut_multikillmode", "1")
	register_cvar("ut_multikillspam", "2")
	register_cvar("ut_multikillstart", "2")
	register_cvar("ut_multikillstep", "1")
	register_cvar("ut_multikillinterval", "10")
	register_cvar("ut_killingspreemode", "1")
	register_cvar("ut_killingspreestart", "10")
	register_cvar("ut_killingspreestep", "2")
	register_cvar("ut_impressivekills", "9")
	register_cvar("ut_excellentratio", "4")
}

public plugin_precache() {
#if DL_MK
	for (new i=0; i < MK_LEVELS; i++)
		precache_sound(MK_snd[i])
#endif

#if DL_KS
	for (new i=0; i < KS_LEVELS; i++)
		precache_sound(KS_snd[i])
#endif

#if DL_FB
	precache_sound(FB_snd)
#endif

#if DL_HM
	precache_sound(HM_snd)
#endif

#if DL_WV
	precache_sound(WV_snd)
#endif

#if DL_HD
	precache_sound(HD_snd)
#endif

#if DL_PL
	precache_sound(PL_snd)
#endif

#if DL_IM
	precache_sound(IM_snd)
#endif

#if DL_EX
	precache_sound(EX_snd)
#endif

#if DL_LL
	precache_sound(LL_snd)
#endif
}

#if HELPER == 1
public client_help(id)
{
	help_add("Information","This plugin creates UT sounds")
	help_add("Usage","Type in chat:^nut_sounds to enable/disable sounds or ut_on/ut_off to turn on/off respectively")
}
#endif


// Reset Functions
public ut_reset_MK(id) {
	MK_last_kill[id] = 0.0
	MK_count[id] = 0
}

public ut_reset_KS(id) {
	KS_count[id] = 0
}

public ut_reset_IM(id) {
	IM_count[id] = 0
}

public ut_reset_LL(id) {
	LL_tks[id] = 0
}

public ut_reset_all(id){
	if (id == 0) {
		new max_players = get_maxplayers()
		for (new x=1; x<max_players; x++) {
			ut_reset_MK(x)
			ut_reset_KS(x)
			ut_reset_IM(x)
			ut_reset_LL(x)
		}
	}
	else {
		ut_reset_MK(id)
		ut_reset_KS(id)
		ut_reset_IM(id)
		ut_reset_LL(id)
	}
}


// Enable/Disable UT Sounds (Client Based)
public ut_enable(id) {
	ut_sounds_enabled[id] = 1
	client_print(id, print_chat, "You have enabled the UT sounds")
}

public ut_disable(id) {
	ut_sounds_enabled[id] = 0
	client_print(id, print_chat, "You have disabled the UT sounds")
}

public ut_toggle(id) {
	if (ut_sounds_enabled[id]) {
		ut_disable(id)
	}
	else {
		ut_enable(id)
	}
	return PLUGIN_HANDLED
}


// Sound Functions
public playSound(id, sound[]) {
	if (id == 0) {
		new max_players = get_maxplayers()
		for(new x=1; x<=max_players; x++) {
			if (is_user_connected(x)) {
				if (ut_sounds_enabled[x]) {
					client_cmd(x,"spk %s",sound)
				}
			}
		}
	}
	else {
		if (ut_sounds_enabled[id]) {
			client_cmd(id,"spk %s",sound)
		}
	}
}


// Check Excellent Function
public checkExcellent(id) {
	new kills = get_user_frags(id)
	new deaths = ns_get_deaths(id)
	if (kills > 0) {
		new ratio = 0
		if (deaths > 0)
			ratio = kills / deaths
		else if (deaths == 0)
			ratio = kills

		if (ratio >= excellent_ratio) {
			if (excellent_mode > 0)
				playSound(id,EX_snd)

			new msg[128], player_name[32]
			get_user_name(id,player_name,31)
			format(msg,127,EX_msg,player_name,kills,deaths)
			printMessage(0,Purple,msg)
		}
	}
}


// Message Functions
public printMessage(id, color[3], message[]) {
	set_hudmessage(color[0],color[1],color[2],0.05,0.65,2,0.02,6.0,0.01,0.1,DISPLAY_HUD_CHANNEL)
	show_hudmessage(id,message)
	client_print(id,print_chat,"* %s",message)
}

public announceStart() {
	playSound(0, PL_snd)
	printMessage(0, Green, PL_msg)
}

public announceVictory(winner) {
	if (victory_mode) {
		if (winner == 0) {
			new msg[128]
			format(msg,127,"%s %s", HD_msg, "(Game has ended in a draw)")
			playSound(0,HD_snd)
			printMessage(0,Red,msg)
			log_amx("DRAW? TEAM1: %d TYPE: %d TEAM2: %d TYPE: %d",g_team[0], g_teamtype[0],g_team[1], g_teamtype[1])

			// Check Excellent Players & Reset Stats
			new max_players = get_maxplayers()
			for (new x=1; x<=max_players; x++) {
				// Check Excellent
				checkExcellent(x)

				// Extra Reset for safety
				ut_reset_all(x)
			}
		}
		else {
			log_amx("WINNING TEAM COULD BE: %d TEAM1: %d TYPE: %d TEAM2: %d TYPE: %d", winner,g_team[0], g_teamtype[0],g_team[1], g_teamtype[1])
			new team, max_players = get_maxplayers()
			for (new x=1; x<=max_players; x++) {
				team = pev(x, pev_team)
				if (team == winner) {
					playSound(x,WV_snd)
					printMessage(x,Green,WV_msg)
				}
				else {
					playSound(x,HD_snd)
					printMessage(x,Red,HD_msg)
				}

				// Check Excellent
				checkExcellent(x)

				// Extra Reset for safety
				ut_reset_all(x)
			}
		}
	}
}


// Structure Gathering Functions
ut_get_buildings(type[]) {
	new g_buildings[2] = {0,0}
	new buildings = ns_get_build(type,1,0)
	if (buildings > 0) {
		new entid
		for (new x=1; x<=buildings; x++) {
			for (new y=0; y<2; y++) {
				entid = ns_get_build(type,1,x)
				// Check entity is solid for correct command chair return?
				if(pev(entid,pev_solid) != SOLID_NOT) {
					// Check the command chair is drawn for correct return?
					if (!(pev(entid, pev_effects) & EF_NODRAW)) {
						if (pev(entid,pev_team) == g_team[y]) {
							g_buildings[y]++
						}
					}
				}
			}
		}
	}
	return g_buildings
}


// Retrieve Team Information
ut_get_teams() {
	// Reset team variables
	arrayset(g_team,UNDEFINED,2)
	arrayset(g_teamtype,UNDEFINED,2)

	// Check Player Teams
	new i = 0, spawns = 0, Float:coords[3] = {0.0,0.0,0.0}
	for (new x=1; x<=4; x++) {
		spawns = ns_get_spawn(x,0,coords)
		if (spawns > 0) {
			// Check Marine
			new commcount = ns_get_build("team_command",0,0)
			if (commcount > 0) {
				// There is a commander, check team
				for (new y=1; y<=commcount; y++) {
					if (pev(ns_get_build("team_command",0,y),pev_team) == x) {
						// Commander chair belongs to this team?
						g_team[i] = x
						g_teamtype[i] = MARINE
					}
				}
			}
			// If team has not been set (Not Marine), check Alien?
			if (!g_team[i]) {
				// Check Alien
				new hives = ns_get_build("team_hive",0,0)
				if (hives > 0) {
					// There is a hive, check team
					for (new y=1; y<=hives; y++) {
						if (pev(ns_get_build("team_hive",0,y),pev_team) == x) {
							g_team[i] = x
							g_teamtype[i] = ALIEN
						}
					}
				}
			}
			// Increment for Next Team
			log_amx("TEAM SPAWNS: TEAM: %d SPAWNS: %d TYPE: %d", x, spawns, g_teamtype[i])
			if (g_team[i])
				i++
		}
	}
}


// Events
public client_putinserver(id){
	// Reset UT Sounds
	ut_sounds_enabled[id] = 1

	ut_reset_all(id)
}

public round_start() {
	// Reset Firstblood
	firstblood = true

	// Check if CO map for EXP?
	if (ns_is_combat()) {
		exp_mode = get_cvar_num("ut_expmode")
	}
	else {
		exp_mode = 0
	}

	// Check cvars once per round
#if DL_WV
#if DL_HD
	victory_mode = get_cvar_num("ut_victory")
#endif
#endif
#if DL_FB
	firstblood_mode = get_cvar_num("ut_firstbloodmode")
#endif
#if DL_HM
	humiliation_mode = get_cvar_num("ut_humiliationmode")
#endif
#if DL_MK
	multikill_mode = get_cvar_num("ut_multikillmode")
	if (multikill_mode) {
		multikill_spam = get_cvar_num("ut_multikillspam")
		multikill_start = get_cvar_num("ut_multikillstart")
		multikill_step = get_cvar_num("ut_multikillstep")
		multikill_interval = get_cvar_num("ut_multikillinterval")
	}
#endif
#if DL_KS
	killingspree_mode = get_cvar_num("ut_killingspreemode")
	if (killingspree_mode) {
		killingspree_start = get_cvar_num("ut_killingspreestart")
		killingspree_step = get_cvar_num("ut_killingspreestep")
	}
#endif
#if DL_EX
	excellent_mode = get_cvar_num("ut_excellentmode")
	if (excellent_mode > 0)
		excellent_ratio = get_cvar_num("ut_excellentratio")
#endif
#if DL_LL
	llamatk_mode = get_cvar_num("ut_llamatkmode")
	if (llamatk_mode > 0)
		llamatk_tks = get_cvar_num("ut_llamatks")
#endif
#if DL_IM
	impressive_mode = get_cvar_num("ut_impressivemode")
	if (impressive_mode > 0)
		impressive_kills = get_cvar_num("ut_impressivekills")
#endif

	// Play Sound
#if DL_PL
	announceStart()
#endif

	// Get team information at start of round
	ut_get_teams()

	// Reset all player stats
	ut_reset_all(0)
}

// Check HudText2 for Victory/Defeat message as opposed to using round_end()
public event_roundEnd(id)
{
	// Get HudText
	new text[32]
	read_data(1, text, 31)

	if (equal(text, "TeamOneWon")) {
		log_amx("TEAM WON: %d", 1)
		//winning_team = 1
	}
	else if (equal(text, "TeamTwoWon")) {
		log_amx("TEAM WON: %d", 2)
		//winning_team = 2
	}
	else if (equal(text, "GameDraw")) {
		log_amx("TEAM WON: %d", 0)
		//winning_team = 0
	}
	else {
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}

public round_end(Float:roundtime) {
	// Before we go too far... check for Unknown teams.
	if ((!g_teamtype[0]) && (!g_teamtype[1])) {
		announceVictory(0)
		return PLUGIN_CONTINUE
	}
	else if (!g_teamtype[0]) {
		announceVictory(g_team[1])
		return PLUGIN_CONTINUE
	}
	else if (!g_teamtype[1]) {
		announceVictory(g_team[0])
		return PLUGIN_CONTINUE
	}

	// Before we get too far... check if players left the team.
	new g_teamplayers[2] = {0,0}
	new team, max_players = get_maxplayers()
	for (new x=1; x<=max_players; x++) {
		team = pev(x, pev_team)
		if (team == g_team[0])
			g_teamplayers[0]++
		else if (team == g_team[1])
			g_teamplayers[1]++
	}
	if (!g_teamplayers[0]) {
		announceVictory(g_team[1])
		return PLUGIN_CONTINUE
	}
	else if (!g_teamplayers[1]) {
		announceVictory(g_team[0])
		return PLUGIN_CONTINUE
	}

	// Get Team Structures
	new g_teamccs[2] = {0,0}, g_teamhives[2] = {0,0}
	if (g_teamtype[0] == g_teamtype[1]) {
		if (g_teamtype[0] == MARINE) {
			// Assume MvM
			g_teamccs = ut_get_buildings("team_command")

			log_amx("CCS: TEAM: %d %d TEAM: %d %d",g_team[0], g_teamccs[0], g_team[1], g_teamccs[1])
			if (g_teamccs[0] > g_teamccs[1]) {
				// Team 1 Wins for having more CC's?
				announceVictory(g_team[0])
			}
			else if (g_teamccs[0] < g_teamccs[1]) {
				// Team 2 Wins for having more CC's?
				announceVictory(g_team[0])
			}
			else {
				// Draw?
				announceVictory(0)
			}
			return PLUGIN_CONTINUE
		}
		else {
			// Assume AvA?
			g_teamhives = ut_get_buildings("team_hive")

			log_amx("HIVES: TEAM: %d %d TEAM: %d %d",g_team[0], g_teamhives[0], g_team[1], g_teamhives[1])
			if (g_teamhives[0] > g_teamhives[1]) {
				// Team 1 Wins for having more Hives?
				announceVictory(g_team[0])
			}
			else if (g_teamhives[0] < g_teamhives[1]) {
				// Team 2 Wins for having more Hives?
				announceVictory(g_team[1])
			}
			else {
				// Draw?
				announceVictory(0)
			}
			return PLUGIN_CONTINUE
		}
	}
	else {
		// Assume MvA or AvM
		g_teamccs = ut_get_buildings("team_command")
		g_teamhives = ut_get_buildings("team_hive")

		log_amx("CCS: TEAM: %d %d TEAM: %d %d",g_team[0], g_teamccs[0], g_team[1], g_teamccs[1])
		log_amx("HIVES: TEAM: %d %d TEAM: %d %d",g_team[0], g_teamhives[0], g_team[1], g_teamhives[1])
		if (g_teamtype[0] == MARINE) {
			// Assume MvA
			if (g_teamccs[0] > g_teamhives[1]) {
				// Team 1 has more CC's than Team 2 has Hives? Team 1 Wins?
				announceVictory(g_team[0])
			}
			else if (g_teamccs[0] < g_teamhives[1]) {
				// Team 2 has more Hives than Team 1 has CC's? Team 2 Wins?
				announceVictory(g_team[1])
			}
			else {
				// Draw?
				announceVictory(0)
			}
			return PLUGIN_CONTINUE
		}
		else {
			// Assume AvM?
			if (g_teamhives[0] > g_teamccs[1]) {
				// Team 1 has more Hives than Team 2 has CC's? Team 1 Wins?
				announceVictory(g_team[0])
			}
			else if (g_teamhives[0] < g_teamccs[1]) {
				// Team 2 has more CC's than Team 1 has Hives? Team 2 Wins?
				announceVictory(g_team[1])
			}
			else {
				// Draw?
				announceVictory(0)
			}
			return PLUGIN_CONTINUE
		}
	}
	return PLUGIN_CONTINUE
}

public event_Death(id) {
	new killer = read_data(1)
	new victim = read_data(2)

	// Get Weapon name
	new killer_weapon[32]
	read_data(3, killer_weapon, 31)

	new victim_name[32]
	get_user_name(victim,victim_name,31)

	// Crude could be changed to run events but not play message/info for killer
	if (!is_user_connected(killer))
		return PLUGIN_CONTINUE

	// Variables
	new msg[128]

	// Check EXP (Not Required now we are using ns_add_exp?)
	if (exp_mode)
	{
		new Float:killer_exp = ns_get_exp(killer)
	}

	if ((killer != victim) && (killer != 0)) {
		new killer_name[32]
		get_user_name(killer,killer_name,31)

		// Check TK
		if (pev(killer,pev_team) == pev(victim,pev_team)) {
			LL_tks[killer]++

			if (LL_tks[killer] >= llamatk_tks) {
				if (llamatk_mode > 0) {
					if (llamatk_mode > 1)
						playSound(killer,LL_snd)
					else
						playSound(0,LL_snd)
				}

				format(msg,127,LL_msg, killer_name, LL_tks[killer])
				printMessage(0,Yellow,msg)

				if (exp_mode == 1) {
					//ns_add_exp(killer, (exp = exp - 50)))
				}
			}
		}
		else {
			// Reset TKs After Non Team Kill?
			//LL_tks[killer] = 0

			// Check first Multi-kill
			if (MK_count[killer] == 0) {
				MK_last_kill[killer] = get_gametime()
			}

			// Check Multi-kill
			new Float:killer_last_kill = MK_last_kill[killer]
			MK_last_kill[killer] = get_gametime()
			if ((MK_last_kill[killer] - killer_last_kill) < multikill_interval)
				MK_count[killer]++
			else
				ut_reset_MK(killer)

			// Increase kill counts
			KS_count[killer]++
			IM_count[killer]++

			// First Blood
			if (firstblood) {
				if (firstblood_mode > 0) {
					if (firstblood_mode > 1)
						playSound(killer,FB_snd)
					else
						playSound(0,FB_snd)
				}
				format(msg,127,FB_msg,killer_name)
				printMessage(0,Red,msg)

				if (exp_mode == 1) {
					//ns_add_exp(killer, (exp = exp + (100)))
				}
				firstblood = false
			}

			// Humiliation (Knife Kill)
			if ((strcmp(killer_weapon,"knife") == 0) || (strcmp(killer_weapon,"welder") == 0) ||
			(strcmp(killer_weapon,"charge") == 0) || (strcmp(killer_weapon,"spikegun") == 0) ||
			(strcmp(killer_weapon,"healingspray") == 0) || (strcmp(killer_weapon,"parasite") == 0) ||
			(strcmp(killer_weapon,"leap") == 0) || (strcmp(killer_weapon,"handgrenade") == 0)) {
				if (humiliation_mode > 0) {
					if (humiliation_mode > 1)
						playSound(killer,HM_snd)
					else
						playSound(0,HM_snd)
				}

				replace(killer_weapon,32,"item_","")
				format(msg,127,HM_msg,killer_name,victim_name,killer_weapon)
				printMessage(0,Red,msg)
			
				if (exp_mode == 1) {
					//ns_add_exp(killer, (exp = exp + 25)))
				}
			}
			else {
				// Killing Spree (Victim)
				if (KS_count[victim] >= killingspree_start) {
					format(msg,127,KS_endmsg,victim_name,killer_name)
					printMessage(0,Blue,msg)
				}

				// Multi Kill
				if (MK_count[killer] >= multikill_start) {
					// Changing to float to check if we are in-between levels
					new Float:multikill_check = float(MK_count[killer] - multikill_start)
					if (multikill_check != 0.0)
						multikill_check = (multikill_check / multikill_step)

					// Convert float back to int
					new MK_lvl = floatround(multikill_check,floatround_floor)
					if (multikill_check == MK_lvl) {
						if (MK_lvl >= MK_LEVELS)
							MK_lvl = MK_LEVELS - 1

						if (multikill_mode > 0) {
							if (multikill_mode > 1)
								playSound(killer,MK_snd[MK_lvl])
							else
								if (MK_lvl >= (multikill_spam - 1))
									playSound(0,MK_snd[MK_lvl])
								else
									playSound(killer,MK_snd[MK_lvl])
						}
						format(msg,127,"%s triggered %s",killer_name,MK_msg[MK_lvl])
						//printMessage(0,Red,msg)
					}

					if (exp_mode == 1) {
						//ns_add_exp(killer, (exp = exp + (35 * MK_lvl)))
					}
				}
				else {
					// Impressive Kill
					if (IM_count[killer] == impressive_kills) {
						if (impressive_mode > 0) {
							if (impressive_mode > 1)
								playSound(killer, IM_snd)
							else
								playSound(0, IM_snd)
						}
						format(msg,127,IM_msg, killer_name, IM_count[killer], victim_name)
						printMessage(0,Purple,msg)

						if (exp_mode == 1) {
							//ns_add_exp(killer, (exp = exp + 150))
						}
						ut_reset_IM(killer)
					}
					else {
						// Killing Spree (Killer)
						if (KS_count[killer] >= killingspree_start) {
							// Changing to float to check if we are in-between levels
							new Float:killingspree_check = float(KS_count[killer] - killingspree_start)
							if (killingspree_check != 0.0)
								killingspree_check = (killingspree_check / killingspree_step)

							// Convert float back to int
							new KS_lvl = floatround(killingspree_check,floatround_floor)
							if (killingspree_check == KS_lvl) {
								if (KS_lvl < KS_LEVELS) {
									if (killingspree_mode > 0) {
										if (killingspree_mode > 1)
											playSound(killer,KS_snd[KS_lvl])
										else
											playSound(0,KS_snd[KS_lvl])
									}
									format(msg,127,KS_msg[KS_lvl],killer_name)
									printMessage(0,Blue,msg)

									if (exp_mode == 1) {
										//ns_add_exp(killer, (exp = exp + (35 * KS_lvl)))
									}
								}
							}
						}
					}
				}
			}
		}
	}
	else {
		// Killing Spree Ended (Suicide Death)
		if (killingspree_mode > 0) {
			if (killingspree_mode > 1)
				playSound(victim,HM_snd)
			else
				playSound(0,HM_snd)
		}
		format(msg,127,KS_suicidemsg,victim_name)
		printMessage(0,Blue,msg)
	}

	// Reset Victim
	ut_reset_all(victim)

	return PLUGIN_CONTINUE
}
