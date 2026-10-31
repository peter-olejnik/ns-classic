/* 	SPOREMINES.SMA  
* 	Author: Nut (original - mahnsawce (Edition Flash25)
* 	Version: 1.0
* 	Released: 11 july 04
*
* 	Allows gorges to create mines which emit a spore cloud when an enemy player comes near it.
* 	Command: "sporemine"
* 	Eg: "bind End sporemine"
*	           or 
*  	press on your evol gorge button
* 	Can also be created by using the impulse to evolve to gorge while already gorge (impulse 114).
*
*
*
*	Change Log:
*	v2.5 - Assumed support. Removed regacy code. fixed Scoreboard error. removed server print spam.
*	v2.6 - helper support
*	v2.7 - removed need for fun module
*	v2.8 - helper adjustment and /sporemine command (thanks mE).  Removed engine requirement, cleaned a little code up.
*	v2.9 - fixed scoreboard error.  removed server_frame()
*	v2.9b - fixed kill assignment for real this time... fixed major glitch (touch != think for serverframe) fixed unknown command return from givesmines
*	v2.9c - fixed velocity issue on mine drop, reverted back to default mine settings / model
*/


#include <amxmodx>
#include <fakemeta>
#include <ns>

#define HELPER 0

#if HELPER == 1
#include <helper>
#endif

#define AUTHOR 	"Nut (Flash25)"
#define VERSION "2.9c"
#define DATE 	"7/26/07" 

#define SMINE_CO_PERLIFE  		3  	// How many sporemines gorges can drop per life in combat
#define SMINE_CO_REPICKUP_TIME 		220.0 	// 220 sec after this time if gorge is not dead and not have mine, he got again mine. 0 for disable

#define SMINE_NS_COST  			5 	// Ress cost for build smine on ns map
#define SMINE_NS_PERLIFE		4	//how many mines gorges get for ns maps
#define SMINE_MAX_PERRNG  		4

#define SMINE_EXPIRED_TIME		500.0 	// 500 sec after this time the mine explode, 0 for disable

#define SMINE_MODEL 			"models/acidrocket.mdl"

#define SMINE_DESTROY_WITH_PISTOL 	1 	// 0 disable, u can destroy sporemine with pistol
#define SMINE_DESTROY_MODE		2 	// 1 - the mine explode with 4 balls, 2 - the mine start attack with 2 balls

#define SMINE_DRANGE  			250
#define SMINE_VELOCITY 			225 	// Velocity aim multiplier (for place the mine in front of gorge)
#define SMINE_PREATTACK_TIME 		0.2 	// after this time the mine start attack mode (dmg and sporemine etc)
#define SMINE_TOUCH_RNG 		75	//range that players touch mine

#define SMINE_BLASTDMG  		100	//inital blast damage
#define SMINE_BLASTRNG  		200.0	//range of blast
#define SMINE_DMG  			12.0	//dmg per SMINE_DTIME
#define SMINE_DTIME  			0.5	//dmg every x seconds
#define SMINE_ATTACKS_TIME  		15.0	//length mine lasts

#define SMINE_HP  			100.0	// They die to explosive types of damages only...
#define SMINE_DMG_HEAVY 		0	// Set to "1" to make heavy armors take damage from the mines.  set to "0" for them to be immune.
#define SMINE_BLAST_HEAVY 		1	// Set to 1 for heavyarmor take the blast damage but not spore damage
#define SMINE_SIZE   			32.0

enum {
	SONG_MAKE_SMINE1 = 0,
	SONG_MAKE_SMINE2,
	SONG_SMINE_OFF,
	SONG_SMINE_ON,
	SONG_SPORE,
	SONG_TOUCH,
	SONG_SMINE_ACTIVE,
	SONG_SMINE_DEAD,
	SONG_CLOAK,
	SONG_UNCLOAK,
	SONG_SHOTSMINE1,
	SONG_SHOTSMINE2,
	SONG_GOTNEWSMINE,
	
	MAX_SONG
}

new const songInfo[13][] = {
	"misc/a-build1.wav",
	"misc/a-build2.wav",
	"misc/aliensightoff.wav",
	"misc/aliensighton.wav",
	"weapons/sporecloud.wav",
	"misc/egg_die.wav",
	"misc/alien_chamber_deploy.wav",
	"misc/alien_chamber_die.wav",
	"misc/startcloak.wav",
	"misc/endcloak.wav",
	"weapons/bullet_hit2.wav",
	"weapons/bullet_hit1.wav",
	"misc/a-levelup.wav"
}

// eg for disable : //#define SMINE_CO_CLOAKED
#define SMINE_CO_CLOAKED  	// Comment out if you dont want cloak mines if gorge have cloaking on combat map
#define SMINE_SENSORY     	// Comment out if you dont want sensory chambers to cloak mines
#define SMINE_MOVEMENT		// Comment out if you dont want movement chambers to speed up it's attacks.
//#define SMINE_ROUND		// To decide how the mines look (round, or pointy) (comment out for pointy)
#define SMINE_PARASITE		// The mine parasite all marine touch him (blast range)

#define HUDMSG 		1	// Set to 1 for Allow gorge to see the number of sporemine in combat and ns map.
#define HUDCHANNEL 	1	// the channel of hudmessage

//just in case these ever change
#define GORGEIMPULSE 	114
#define SCANIMPULSE	53

#define SMINE_MC_RANGE 500
#define SMINE_SC_RANGE 750
#define SMINE_SCAN_RANGE 800
#define SMINE_OBS_RANGE 900

enum {
	TOOMANYMINES = 0,
	NEEDTOBEGORGE,
	NOTENOUGHRES,
	ONEPERLIFE
}

new const infoStr[4][] = {
	"There are too many sporemines in the area already.",
	"You must be a gorge to place a sporemine.",
	"Not enough resources to place a sporemine.",
	"You used all your sporemines for this life already."
}

// Do _NOT_ edit below here unless you know what you're doing!

//#define ON_TEST	//uncomment to make mines stay after disconnect debuging.? (not recommended)

#define SM_LI 60
#define SM_LI3 22

new HUD_MSG[SM_LI] = "<t>SporeMine<s>:<number></total><n><t><Reason>" 

// used for telling the sporemine's "state".. dont modify this
#define SPOREMINE_SPAWN    	0.0	// It's just placed.
#define SPOREMINE_SET		1.0 	// It's set, and ready to be activated.
#define SPOREMINE_ACTIVE0	1.8
#define SPOREMINE_ACTIVE	2.0	// It's active, and looking for a target.
#define SPOREMINE_PRE_ATTACK	3.0	// It's on pre attack mode and prepar for shoot spores
#define SPOREMINE_ATTACKING	4.0	// It's attacking anything in range.
#define SPOREMINE_HIDE		5.0	// make the sporemine invisible but she attack again some secondes.
#define SPOREMINE_EXHAUSTED	6.0	// It's dead.


enum {
	XP_LEVEL_1	=     0,
	XP_LEVEL_2	=   100,
	XP_LEVEL_3	=   250,
	XP_LEVEL_4	=   450,
	XP_LEVEL_5	=   700,
	XP_LEVEL_6	=  1000,
	XP_LEVEL_7	=  1350,
	XP_LEVEL_8	=  1750,
	XP_LEVEL_9	=  2200,
	XP_LEVEL_10	=  2700
}

enum {
	PLAYER = 1,
	SCORE,
	FRAGS,
	DEATHS,
	LEVEL,	// in classic: weapon / res
	CLASS,
	AUTH,
	TEAM,
	HEALTH,
	ICON
}


new g_smine_co[33], g_msg[33][SM_LI], g_reason[33][SM_LI3]
new g_EventParticle, gmsgHudText2, g_maxplayers
new g_numofmine[33], say_msg[33], g_Lastclip[33]
new g_roundstarted,  g_ShowHud[33], g_HaveScan[33], g_DelSmine[33], DeleteHud[33]
new Float:g_pickup_time[33], Float:g_LastTime[512]
new g_MsgFlash[33],g_smineTOut[33]
new g_s_zero[33][SM_LI],g_zero[33], Float:g_fzero[33]

#if SMINE_DESTROY_WITH_PISTOL == 1
new Float:g_delay_frame[33]
#endif

//scoreboard stuff
new scoreBoardInfo[33][ICON], scoreBoardIcon[33][33] , gmsgScoreInfo

public plugin_init() {
	register_plugin("SporeMines",VERSION,AUTHOR)
	register_cvar("ns2amx_sporemines", VERSION,4)
	
	register_event("ResetHUD", "resethud", "ab")
	register_event("HideWeapon","resethud","ab")
	register_event("HudText2","event_HudText2","ab") //remove all mine if the game end
	register_event("Countdown","event_Countdown", "ab") //remove all mine if the game start

	#if HUDMSG == 1
	register_event("AlienInfo","hud_sporemine_toall","abc","1=0")
	set_task(ns_is_combat()?20.0:10.0,"hud_sporemine_toall",50,"",0,"b",0)
	set_task(ns_is_combat()?1.2:0.6,"check_sporemine_toall",51,"",0,"b",0)
	#endif
	
	register_clcmd("sporemine","make_sporemine")
	register_clcmd("say /sporemine","make_sporemine")
	register_clcmd("say_team /sporemine","make_sporemine")
	register_clcmd("givesmine","give_smine") //if sv_cheats is 1
	
	set_task(0.5,"Fix_Smine",53,_,_,"b")

	register_forward(FM_CmdStart,"hook_Impulse")
	register_forward(FM_Touch,"hook_Touch")
	

	if (!ns_is_combat()) {
		register_forward(FM_Think,"hook_Think_ns")
	}else{
		set_task(30.0,"scan_smine_co",58,_,_,"b")
		if (SMINE_CO_REPICKUP_TIME > 0)
			set_task(30.0,"co_Add_smine",59,_,_,"b")
		register_forward(FM_Think,"hook_Think_co")
		Reset_manysmine()
	}
	
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	
	if (ent) {
		set_pev(ent,pev_classname,"smine_serverframe")
		set_pev(ent,pev_nextthink,get_gametime() + 0.1)
	}
	
	g_maxplayers = get_maxplayers()
	gmsgHudText2 = get_user_msgid("HudText2")
	gmsgScoreInfo = get_user_msgid("ScoreInfo")
	register_message(gmsgScoreInfo,"msg_ScoreInfo")
	g_EventParticle = engfunc(EngFunc_PrecacheEvent, 1, "events/Particle.sc")
}

#if HELPER == 1
public client_help(id) {
	help_add("Information","This plugin adds mines that gorges can drop.")
	help_add("Usage","To drop a sporemine simply bind a key or the command, Reselect the gorge evolve, or type /sporemine in chat")
	help_add("Commands","bind key sporemine, or select the gorge evolve again.")
}

public client_advertise(id) return pev(id,pev_team) & 1 ? PLUGIN_HANDLED : PLUGIN_CONTINUE
#endif

stock Reset_manysmine() {
	for (new i = 1;i<=g_maxplayers;++i)
		g_smine_co[i]=SMINE_CO_PERLIFE
}

new g_smineExtra[2][255]
new Float:g_smineExtra_Ori[255][3]

public ServerFrame(ent){
	new ts = ns_get_build("sporemine",0,0)
	if (g_smineExtra[0][0] > ts){
		for (new nn = 1;nn <= g_smineExtra[0][0];++nn) {
			new smi = g_smineExtra[1][nn]
			g_smineExtra[1][nn] = 0
			new Float:or[3]
			or = g_smineExtra_Ori[nn]
			if (!pev_valid(smi) && smi 
			&& or[0] != 0.0 && or[1] != 0.0
			&& or[2] != 0.0) {
				new s = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
				pev(s,pev_origin,or)
				set_pev(s,pev_owner,s)
				set_pev(s,pev_team,2)
				dllfunc(DLLFunc_Spawn, s)
				fm_set_kvd(s, "classname", "smine_dead", "info_target")
				sporemines_spawnx(s)
				//console_print(0,"TEST0 %d - %.1f %.1f %.1f",s,or[0],or[1],or[2])
				or[2] += 2.0
				engfunc(EngFunc_PlaybackEvent, 0, s, g_EventParticle, 0.0, or,Float:{0.0,0.0,0.0},0.0,0.0,11,0,0,0)
				engfunc(EngFunc_PlaybackEvent, 0, s, g_EventParticle, 0.0, or,Float:{0.0,0.0,0.0},0.0,0.0,21,0,0,0)
				engfunc(EngFunc_PlaybackEvent, 0, s, g_EventParticle, 0.0, or,Float:{0.0,0.0,0.0},0.0,0.0,26,0,0,0)
				g_smineExtra_Ori[nn]=Float:{0.0,0.0,0.0}
				emit_sound(s,CHAN_VOICE,songInfo[SONG_SMINE_DEAD],0.8,ATTN_NORM,0,PITCH_NORM)
				engfunc(EngFunc_RemoveEntity, s)
				
			}
		}
		g_smineExtra[0][0] -= 1
		
	} else if (g_smineExtra[0][0] <= ts){
		g_smineExtra[0][0] = ts
		for (new nn = 1;nn <= ts;++nn) {
			new ent =ns_get_build("sporemine",0,nn)
			new Float:vuser1[3]
			pev(ent,pev_vuser1,vuser1)
			if (vuser1[0] == SPOREMINE_EXHAUSTED) continue
			g_smineExtra[1][nn] = ent
			pev(ent,pev_origin,g_smineExtra_Ori[nn])
		}
	}
	#if SMINE_DESTROY_WITH_PISTOL == 1
	new Float:tim = get_gametime()
	for (new i = 1;i<=g_maxplayers;++i){
		if (!is_user_alive(i)) continue
		new clip,ammo ,origin[3] ,Float:forigin[3]
		if ( (tim >= g_delay_frame[i]) && (pev(i,pev_team) == 1) 
		&& (pev(i,pev_button) & IN_ATTACK) 
		&& (get_user_weapon(i,clip,ammo) == WEAPON_PISTOL) 
		&& clip && (g_Lastclip[i] != clip) ){
			g_Lastclip[i] = clip 
			g_delay_frame[i] = tim+0.1
			get_user_origin(i,origin,3)
			forigin[0] = float(origin[0])
			forigin[1] = float(origin[1])
			forigin[2] = float(origin[2])
			
			new smine = engfunc(EngFunc_FindEntityInSphere, i, forigin, 10.0)
			if (!pev_valid(smine)) continue
			new class[12]
			pev(smine,pev_classname,class,11)
			new Float:vuser1[3]
			
			if (equal(class,"sporemine")) { 
				pev(smine,pev_vuser1,vuser1)
				if (vuser1[0] == SPOREMINE_ACTIVE){
					if (random_num(1,2) == 1)
						emit_sound(smine,CHAN_VOICE,songInfo[SONG_SHOTSMINE1],1.0,ATTN_NORM,0,PITCH_NORM)
					else
						emit_sound(smine,CHAN_VOICE,songInfo[SONG_SHOTSMINE2],1.0,ATTN_NORM,0,PITCH_NORM)
					up_smine2(smine,1)

					pev(smine,pev_origin,forigin)
					forigin[2] += 1.5

					engfunc(EngFunc_PlaybackEvent, 0, smine,g_EventParticle,0.0,forigin,Float:{0.0,0.0,0.0},0.0,0.0,11,0,0,0)
					#if SMINE_DESTROY_MODE == 1 
					set_pev(smine,pev_health,(pev(smine,pev_health)-25.0))
					#endif
					#if SMINE_DESTROY_MODE == 2
					new Float:hp = float(pev(smine,pev_health))
					if (hp > 50.0)
						set_pev(smine,pev_health,(hp-50.0))
					else
						Prepar_Smine(smine,i,2)
					#endif
				}
			}
		}
	}
#endif
	set_pev(ent,pev_nextthink,get_gametime() + 0.1)
}

public deleteRegmine(smine){
	new ts =ns_get_build("sporemine",0,0)
	for (new nn = 1;nn <= ts;++nn) {
		new ent =ns_get_build("sporemine",0,nn)
		if (ent == smine) {
			g_smineExtra[0][0] = ts
			g_smineExtra[1][nn] = ent
			g_smineExtra_Ori[nn] = Float:{0.0,0.0,0.0}
		}
	}
}

public play_songandevent(num,id){
	if (num == 1)
		emit_sound(id,CHAN_ITEM,songInfo[SONG_SMINE_ON],0.5,ATTN_NORM,0,PITCH_NORM)
	else if(num == 2){
		new Float:origin[3],Float:origin1[3],Float:origin2[3]
		pev(id,pev_origin,origin)
		origin1[0]=origin[0]
		origin1[1]=origin[1]
		origin1[2]=origin[2]+1.0
		origin2[0]=origin[0]
		origin2[1]=origin[1]
		origin2[2]=origin[2]+5.0
		
		emit_sound(id,CHAN_WEAPON,songInfo[SONG_SMINE_ON],0.5,ATTN_NORM,0,PITCH_NORM)
		emit_sound(id,CHAN_ITEM,songInfo[SONG_TOUCH],0.5,ATTN_NORM,0,PITCH_NORM)
		
		engfunc(EngFunc_PlaybackEvent, 0,id,g_EventParticle,0.0,origin1,Float:{0.0,0.0,0.0},0.0,0.0,28,0,0,0)
		engfunc(EngFunc_PlaybackEvent, 0,id,g_EventParticle,0.1,origin2,Float:{0.0,0.0,0.0},0.0,0.0,18,0,0,0)
		engfunc(EngFunc_PlaybackEvent, 0,id,g_EventParticle,0.2,origin1,Float:{0.0,0.0,0.0},0.0,0.0,26,0,0,0)
		engfunc(EngFunc_PlaybackEvent, 0,id,g_EventParticle,0.4,origin1,Float:{0.0,0.0,0.0},0.0,0.0,27,0,0,0)
	}
	else if (num == 3){
		drawsmspores(id)
		new Float:vuser1[3]
		pev(id,pev_vuser1,vuser1)
		vuser1[1] = get_gametime() + 6.0
		set_pev(id,pev_vuser1,vuser1)
	}
	else if (num == 4)
		emit_sound(id,CHAN_WEAPON,songInfo[SONG_GOTNEWSMINE],0.8,ATTN_NORM,0,PITCH_NORM)
}

public down_smine(id){
	emit_sound(id,CHAN_ITEM,songInfo[SONG_SMINE_OFF],1.0,ATTN_NORM,0,PITCH_NORM)
	new Float:ori[3]
	pev(id,pev_origin,ori)
	ori[2] -= 4.5
	set_pev(id,pev_origin,ori)
}

public down_smine2(id){
	emit_sound(id,CHAN_WEAPON,songInfo[SONG_SMINE_ACTIVE],0.5,ATTN_NORM,0,PITCH_NORM)
	new Float:ori[3]
	pev(id,pev_origin,ori)
	ori[2] -= 2.0
	set_pev(id,pev_origin,ori)
}

public up_smine(id){
	new mm=0
	new team = get_team(id)
	for (new i = 1;i<=g_maxplayers;++i){
    if (!is_user_connected(i)) continue
    if (pev_valid(i) && fm_entity_range(i,id) <= SMINE_TOUCH_RNG){
    	if (pev(i,pev_team) != team 
    	&& pev(i,pev_team) > 0 
    	&& pev(i,pev_deadflag) == 0 
    	&& ns_get_mask(i,4194304) == 0)
    	{
    		mm=3
    		continue
    	}
    	else if (pev(i,pev_team) == team){
      	mm=1
      	continue
      }
    }
	}
	if (mm==3)
		Prepar_Smine(id,id,1)
	else if (mm==1)
		up_smine2(id,1)
	else if (mm==0)
  	up_smine2(id,0)
}

public up_smine2(id,num){
	new Float:origin_z
	new Float:ori[3]
	pev(id,pev_origin,ori)
	origin_z = ori[2]
	new num2
	new pos = pev(id,pev_iuser2)
	if (num == 1 && pos == 0){
		set_pev(id,pev_iuser2,1)
		emit_sound(id,CHAN_VOICE,songInfo[SONG_SMINE_ON],0.3,ATTN_NORM,0,PITCH_NORM)
		origin_z += 4.5
		num2 = 1
	}
	else if (num == 0 && pos == 1){
  	set_pev(id,pev_iuser2,0)
  	emit_sound(id,CHAN_VOICE,songInfo[SONG_SMINE_OFF],0.3,ATTN_NORM,0,PITCH_NORM)
  	origin_z -= 4.5
  	num2 = 1
	}
	if (num2 == 1 && origin_z != ori[2]){
		ori[2] = origin_z
		set_pev(id,pev_origin,ori)
	}
}
public drawsmspores(id){
	if (pev(id,pev_iuser3) != 69){
		new Float:origin[3]
		pev(id,pev_origin,origin)
		emit_sound(id,CHAN_WEAPON,songInfo[SONG_SPORE],1.0,ATTN_NORM,0,PITCH_NORM)
		engfunc(EngFunc_PlaybackEvent, 0,id,g_EventParticle,0.0,origin,Float:{0.0,0.0,0.0},0.0,0.0,13,0,0,0) //spore effect
	}
}

public make_smine_song(id){
	if (random_num(1,2) == 1)
		emit_sound(id,CHAN_ITEM,songInfo[SONG_MAKE_SMINE1],0.5,ATTN_NORM,0,PITCH_NORM)
	else 
		emit_sound(id,CHAN_ITEM,songInfo[SONG_MAKE_SMINE2],0.5,ATTN_NORM,0,PITCH_NORM)
}
public remove_smine(id){
	if (pev_valid(id)){
		new Float:vuser1[3]
		pev(id,pev_vuser1,vuser1)
		vuser1[0] = SPOREMINE_EXHAUSTED
		set_pev(id,pev_vuser1,vuser1)
		deleteRegmine(id)
		set_pev(id,pev_nextthink,get_gametime()+0.2)
	}
}

public remove_smine2(id){
	if (pev_valid(id)){
		deleteRegmine(id)
		engfunc(EngFunc_RemoveEntity, pev(id,pev_euser1))
		engfunc(EngFunc_RemoveEntity, id)
		if (task_exists(666969))
			remove_task(666969)
		set_task(0.5,"hud_sporemine_toall",666969)
	}
}

public remove_smine3(id){
	if (pev_valid(id)){
		new Float:vuser1[3]
		pev(id,pev_vuser1,vuser1)
		vuser1[0] = SPOREMINE_HIDE
		set_pev(id,pev_vuser1,vuser1)
		
		new Float:origin[3]
		pev(id,pev_origin,origin)
		engfunc(EngFunc_PlaybackEvent, 0,id,g_EventParticle,0.0,origin,Float:{0.0,0.0,0.0},0.0,0.0,26,0,0,0)
		emit_sound(id,CHAN_VOICE,songInfo[SONG_SMINE_DEAD],0.5,ATTN_NORM,0,PITCH_NORM)
		hide_smine(id)
		set_pev(id,pev_iuser3,69)
		new iid = i_id("get",id)
		
		if (g_smineTOut[iid] != 0){
			g_smineTOut[iid] = 0
			new ow = pev(id,pev_owner)
			if (g_smine_co[ow] < SMINE_CO_PERLIFE){
				g_smine_co[ow]++
				hud_sporemine_to1(ow,1)
			}
		}
	}
	return PLUGIN_CONTINUE
}

public hide_smine(id){
	set_pev(id,pev_team,0)
	set_pev(id,pev_rendermode,1)
	set_pev(id,pev_renderfx,5)
	set_pev(id,pev_renderamt,0.0)
	engfunc(EngFunc_SetSize, id,Float:{0.0,0.0,0.0},Float:{0.0,0.0,0.0})
	set_pev(id,pev_movetype,0)
	set_pev(id,pev_solid,0)
}

public remove_smine4(id){
	if (pev_valid(id)){
		set_pev(id,pev_team,2)
		new Float:origin[3]
		pev(id,pev_origin,origin)
		engfunc(EngFunc_PlaybackEvent, 0,id,g_EventParticle,0.0,origin,Float:{0.0,0.0,0.0},0.0,0.0,11,0,0,0)
		emit_sound(id,CHAN_ITEM,songInfo[SONG_SMINE_DEAD],0.5,ATTN_NORM,0,PITCH_NORM)
		hide_smine(id)
		new Float:vuser1[3]
		pev(id,pev_vuser1,vuser1)
		vuser1[0] = SPOREMINE_EXHAUSTED
		set_pev(id,pev_vuser1,vuser1)
		set_pev(id,pev_iuser3,69)
		set_pev(id,pev_nextthink,get_gametime()+0.3)
	}
}
stock i_id(sget[],smine){
	if (equal(sget,"get")){
		for (new x=1;x <= 32;++x){
			if (g_smineTOut[x] == smine)
				return x
		}
	}
	else if (equal(sget,"set")){
		for (new x=1;x <= 32;++x){
			if (g_smineTOut[x] == 0)
				return x
		}
	}
	return 0
}
public got_scan(id)
	g_HaveScan[id] = 1

public scan_smine_co(){
	new t = get_maxplayers()
	new sca[33]
	for (new i=1;i<=t;++i){
		if (!is_user_connected(i)) continue
		if (!pev_valid(i)) continue
		if (g_HaveScan[i] == 1){
			new tt = ns_get_build("sporemine",0,0)
			for (new m=1;m<=tt && sca[i] != 1;++m){
    		new k = ns_get_build("sporemine",0,m)
    		new Float:v[3]
    		pev(k,pev_vuser1,v)
    		if (pev(i,pev_deadflag) == 0 && ns_get_mask(i,4194304) == 0 && v[0] == SPOREMINE_ACTIVE && is_user_alive(i) && ns_get_mask(k,MASK_CLOAKING) && fm_entity_range(i,k) <= 600){
    			if (many_scan(i) != 1) {
    				create_scan(i)
    				sca[i] = 1
    			}
    		}
    	}
		}
	}
}

stock many_scan(id) {
	new ent
	while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "scan")) > 0){
		if (!pev_valid(ent)) continue
		if (pev(ent,pev_owner) == id)
			return 1
	}
	return 0
}

stock create_scan(id){
	new sc =  engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "scan"))
	movetoent(sc,id,0)
	set_pev(sc,pev_owner,id)
	set_pev(sc,pev_team,1)
	dllfunc(DLLFunc_Spawn, sc)
}

public cloak_uncloak_song(id,num){
	if (num == 1)
		emit_sound(id,CHAN_ITEM,songInfo[SONG_CLOAK],0.5,ATTN_NORM,0,PITCH_NORM)
	else
		emit_sound(id,CHAN_ITEM,songInfo[SONG_UNCLOAK],0.5,ATTN_NORM,0,PITCH_NORM)
}
public Fix_Smine(){
	new t = ns_get_build("sporemine",0,0)
	for (new i=1;i<=t;i++){
		new s = ns_get_build("sporemine",0,i)
		if (pev(s,pev_nextthink) == 0.0)
			set_pev(s,pev_nextthink,get_gametime()+0.5)
	}
}

public Blast_smine(smine){
	for (new i=1;i<=g_maxplayers;++i) {
		if (!is_user_connected(i)) continue
		if (pev_valid(i)) {
			new team = get_team(smine)
			if (pev(i,pev_team) != team)
				//server_print("Blown up mine(%d)! Range: %.1f (id:%d)",smine,entity_range(smine,i),i)
			#if SMINE_DMG_HEAVY == 1 || SMINE_BLAST_HEAVY == 1
			if (fm_entity_range(i,smine) <= SMINE_BLASTRNG && (pev(i,pev_team) != team) && (pev(i,pev_team) > 0) && (pev(i,pev_deadflag) == 0) && (ns_get_mask(i,4194304) == 0)) // Don't trigger on dead, or digesting marines
			#else
			if (fm_entity_range(i,smine) <= SMINE_BLASTRNG && (pev(i,pev_team) != team) && (pev(i,pev_team) > 0) && (pev(i,pev_deadflag) == 0) && (ns_get_mask(i,4194304) == 0) && (ns_get_class(i) != 8))
			#endif
			{
				#if defined SMINE_PARASITE
				ns_set_mask(i,MASK_PARASITED,1)
				#endif
				new Float:fBlastDmg
				new Float:range = fm_entity_range(i,smine)
				fBlastDmg = ((SMINE_BLASTRNG - range) / SMINE_BLASTRNG) * SMINE_BLASTDMG
				//server_print("Doing blast damage of %.1f (Range of %.1f) (id:%d)",fBlastDmg,range,i)
				getdamage(i,pev(smine,pev_owner),"sporemine",fBlastDmg,1)
			}
		}
	}
}
public client_disconnect(id){
	#if !defined ON_TEST
	resetsome(id)
	#endif
}
public client_putinserver(id){
	#if !defined ON_TEST
	resetsome(id)
	#endif
}

public client_changeteam(id){
	#if !defined ON_TEST
	resetsome(id)
	#endif
}
stock resetsome(id){
	if (g_DelSmine[id] != 1){
		g_DelSmine[id] = 1
		clear_smine_owner(id)
		reset_allvar(id)
	}
}

stock reset_allvar(id){
	if (id == 0){
		g_msg = g_s_zero
		g_HaveScan = g_zero
		g_DelSmine = g_zero
		g_MsgFlash = g_zero
		g_pickup_time = g_fzero
		g_ShowHud = g_zero
		g_smine_co = g_zero
		g_numofmine = g_zero
		DeleteHud = g_zero
		g_Lastclip = g_zero
	}
	else {
		g_msg[id] = ""
		g_Lastclip[id] = 0
		g_HaveScan[id] = 0
		g_DelSmine[id] = 0
		g_MsgFlash[id] = 0
		g_pickup_time[id] = 0.0
		g_ShowHud[id] = 0
		g_smine_co[id] = SMINE_CO_PERLIFE
		g_numofmine[id] = 0
		DeleteHud[id] = 0

	}
}

stock clear_smine_owner(id){
	new j = 1, t = ns_get_build("sporemine",0,0)
	while (j<=t){
		new smine = ns_get_build("sporemine",0,j)
		new Owner = pev(smine,pev_owner)
		if (Owner == id || Owner == 0){// remove all sporemines for this owner...
			remove_smine2(smine)
			t = ns_get_build("sporemine",0,0)
			j = 1
		}
		else j++
  }
	g_DelSmine[id] = 0
}

public check_sporemine_toall(){
	for (new i = 1;i<=g_maxplayers;++i){
		if (!is_user_connected(i)) continue
		check_sporemine_to1(i)
	}
}

public check_sporemine_to1(id){
	new team = pev(id, pev_team)
	if (ns_get_class(id) == 2 && team == 2 && !is_morph(id) && g_roundstarted == 1) {
		new spore, costreason[SM_LI3]
		if (ns_is_combat()) {
			new ss = SMINE_MAX_PERRNG - getsmcount(id)
			new sp = (ss < g_smine_co[id])? ss : g_smine_co[id]
			costreason = "" 
			spore = (sp > 0) ? sp : 0
		}
		else {
			new sp = SMINE_MAX_PERRNG - getsmcount(id)
			new spo = floatround(ns_get_res(id)) / SMINE_NS_COST
			if (sp > spo){
				costreason = (spo > 0) ? "[<Cost>]" : "[No ress]"
				spore = (spo > 0) ? spo : 0
			}
		}
		if (g_numofmine[id-1] != spore || !equal(g_reason[id],costreason)){
			g_numofmine[id] = spore
			g_reason[id] = costreason
			hud_sporemine_to1(id,0)
		}
	}
}

public hud_sporeinfo(id) {
	new msg[SM_LI], s[2], spore,rest, spore2[4], total, total2[4], r[30], reason[30], cost[15]
	msg = HUD_MSG
	if (ns_is_combat()) {
		new smine = g_smine_co[id]
		new ss = SMINE_MAX_PERRNG - getsmcount(id)
		new sp = (ss < smine)? ss : smine
		reason = ""
		spore = ((getsmcount(id) >= SMINE_MAX_PERRNG)? 0 : sp)
		total = SMINE_CO_PERLIFE
		if (smine > spore) rest = smine - spore
		replace(msg,SM_LI-1,"<n>","")
	}
	else {
		replace(msg,SM_LI-1,"<n>","^n")
		total = SMINE_NS_PERLIFE
		new sp = total - getsmcount(id)
		new spo = floatround(ns_get_res(id)) / SMINE_NS_COST
		if (sp > spo) {
			r = ((spo > 0) ? "[<Cost>]" : "[No ress]")
			spore = (spo > 0) ? spo : 0
		}
		else {
			r = ((sp > 0) ? "[<Cost>]" : "[MaxHere]")
			spore = (sp > 0) ? sp : 0
		}
	}
	
	copy(reason,29,r)
	replace(msg,SM_LI-1,"<Reason>",reason)	
	if (equal(r,"[<Cost>]")) {
		format(cost,14,"Cost: %d Ress",SMINE_NS_COST)
		replace(msg,SM_LI-1,"<Cost>",cost)
	}
	if (spore > 1) {
		s = "s"
	}
	else {
		s = "" 
	}
	if (spore == total) { 
		total2 = ""
	}
	else {
		format(total2,3,"/%d",total)
	}
	num_to_str(spore,spore2,3)
	new rest2[5]
	replace(msg,SM_LI-1,"<s>",s)
	replace(msg,SM_LI-1,"</total>",total2)
	if (rest) {
		format(rest2,4,"(%d)",rest)
		while(replace(msg,SM_LI-1,"<t>","")) {}
		replace(msg,SM_LI-1,"<number>","<rest><number>")
	}
	else {
		while(replace(msg,SM_LI-1,"<t>","^t^t^t^t")) {}
	}
	
	replace(msg,SM_LI-1,"<rest>",rest2)
	replace(msg,SM_LI-1,"<number>",spore2)
	
	g_msg[id] = msg
}

public hud_sporemine_toall() {
	for (new i = 1;i<=g_maxplayers;++i){
		if (pev_valid(i)){
			hud_sporemine_to1(i,0)
		}
	}
}
public give_smine(id) {
	if (ns_is_combat() && pev(id,pev_team) == 2 && get_cvar_num("sv_cheats") == 1) {
		g_smine_co[id] = SMINE_CO_PERLIFE
		hud_sporemine_to1(id,1)
		return PLUGIN_HANDLED
	}
	return 0
}

public co_Add_smine() {
	new Float:ti = get_gametime()
	for (new i = 1;i<=g_maxplayers;++i){
		if (!is_user_connected(i)) continue
		if (pev_valid(i) && pev(i,pev_team) == 2) {
			//console_print(0,"TEST1 %d %d %.1f %.1f",i,g_smine_co[i],ti,g_pickup_time[i])
			if (ti >= g_pickup_time[i] && g_pickup_time[i] > 0.0 && g_smine_co[i] != SMINE_CO_PERLIFE) {
				g_pickup_time[i] = 0.0
				g_smine_co[i] = SMINE_CO_PERLIFE
				//console_print(0,"TEST2 %d %d",i,g_smine_co[i])
				hud_sporemine_to1(i,1)
			}
		}
	}
	return PLUGIN_CONTINUE
}
public hud_sporemine_to11(id) {
	hud_sporemine_to1(id,0)
}

public hud_sporemine_to1(i,Fx) {
	new id
	if (i > 100) id = i-100
	else id = i
	new vid, team = pev(id, pev_team)
	if (g_roundstarted != 1) return PLUGIN_HANDLED
	if (!is_user_alive(id) && team == 2 && pev(id, pev_iuser1) == 4 && pev(id, pev_iuser2) > 0)
		vid = pev(id, pev_iuser2)
	else vid = id
	if (ns_get_class(vid) == 2 && pev(vid, pev_team) == 2 && !is_morph(vid) && is_user_alive(vid))
		DeleteHud[id] = 0
	if (pev(vid, pev_team) == 2 && ns_get_class(vid) == 2 && !is_morph(vid) && is_user_alive(vid) && pev_valid(vid) && DeleteHud[id] != 1) {
		g_ShowHud[id] = 1
		hud_sporeinfo(vid)
		new v = get_cvar_num("hiveccstatus_version")
		new vv = (ns_is_combat() && v)?1:0
		new Float:fff 
		if (is_user_alive(id)){
			if (vv) fff=0.925
			else fff=0.950
		}
		else{
			if (vv) fff=0.857
			else fff=0.880
		}
		new msg[SM_LI] 
		msg = g_msg[vid]
		
		if (!equal(msg,"")){
			if (g_MsgFlash[id] == 1) {
				g_MsgFlash[id] = 0
				set_hudmessage(250, 150, 0, 0.80,fff, 1, 1.0, 3600.0, 1.0, 1.0, HUDCHANNEL)
				show_hudmessage(id,"%s",msg)
			}
			else if (Fx == 1) {
				play_songandevent(4,id)
				g_MsgFlash[id] = 1
				set_hudmessage(255, 200, 0, 0.80,fff, Fx, 1.0, 3600.0, 1.0, 1.0, HUDCHANNEL)
				show_hudmessage(id,"%s",msg)
			}
			else {
				set_hudmessage(200, 100, 0, 0.80,fff, 0, 1.0, 3600.0, 1.0, 1.0, HUDCHANNEL)
				show_hudmessage(id,"%s",msg)
			}
		}
	}
	else if (g_ShowHud[id] == 1 && pev_valid(id) && (is_morph(vid) || pev(vid, pev_team) != 2 || !is_user_alive(vid)) && DeleteHud[id] != 1){
		g_ShowHud[id] = 0
		DeleteHud[id] = 1
		set_hudmessage(200, 100, 0, 0.75, 0.95 , 0, 1.0, 1.0, 1.0, 1.0, HUDCHANNEL)
		show_hudmessage(id,"")
	}
	return PLUGIN_HANDLED
}
public resethud(id){ 
	if (ns_is_combat() && !is_user_alive(id)) 
	{
		g_pickup_time[id] = 0.0
		g_smine_co[id]=SMINE_CO_PERLIFE
	}
	#if HUDMSG == 1
	if (is_morph(id))
		hud_sporemine_to1(id,0)
	else
		set_task(0.1,"hud_sporemine_to11",id+100)
	#endif
}

public do_gorgeimpulse(id) {
	
	if (ns_get_class(id) == 2) {
		make_sporemine(id)
		set_pev(id,pev_impulse,0)
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public event_HudText2() {
	new i[190]
	read_data(1,i,189)
	//added gameTie just in cause!
	if (equal("TeamTwoWon",i) || equal("GameTie",i) || equal("TeamOneWon",i))  {
		reset_allvar(0)
		g_roundstarted = 0
		new t = ns_get_build("sporemine",0,0)
		for (new j=0;j<=t;++j) // remove all sporemines...
			engfunc(EngFunc_RemoveEntity, ns_get_build("sporemine",0,1))
			
	}
}

//Handle the scoreboard info
public msg_ScoreInfo(){
	new id = get_msg_arg_int(PLAYER)
	scoreBoardInfo[id][SCORE] = get_msg_arg_int(SCORE) 	// score
	scoreBoardInfo[id][FRAGS] = get_msg_arg_int(FRAGS) 	// frags
	scoreBoardInfo[id][DEATHS] = get_msg_arg_int(DEATHS) 	// deaths
	scoreBoardInfo[id][LEVEL] = get_msg_arg_int(LEVEL) 	// level
	scoreBoardInfo[id][CLASS] = get_msg_arg_int(CLASS) 	// class
	scoreBoardInfo[id][AUTH] = get_msg_arg_int(AUTH)		// auth
	scoreBoardInfo[id][TEAM] = get_msg_arg_int(TEAM) 	// team
	scoreBoardInfo[id][HEALTH] = get_msg_arg_int(HEALTH) 	// health
	get_msg_arg_string(ICON,scoreBoardIcon[id],32)		// icon
}

public refresh_ScoreBoard(id) {
	set_pev(id,pev_frags,float(scoreBoardInfo[id][FRAGS]))
	emessage_begin(MSG_ALL, gmsgScoreInfo)
	ewrite_byte(id)
	ewrite_short(scoreBoardInfo[id][SCORE])		// score
	ewrite_short(scoreBoardInfo[id][FRAGS])		// frags
	ewrite_short(scoreBoardInfo[id][DEATHS])	// deaths
	ewrite_short(scoreBoardInfo[id][LEVEL])		// level
	ewrite_byte (scoreBoardInfo[id][CLASS])		// class
	ewrite_short(scoreBoardInfo[id][AUTH])		// auth status
	ewrite_short(scoreBoardInfo[id][TEAM])		// team
	ewrite_short(scoreBoardInfo[id][HEALTH])	// health
	ewrite_string(scoreBoardIcon[id])   		 // icon
	emessage_end()
}

public hook_Touch(toucher,touched) {
	if (pev_valid(toucher)) {
		static classname[32]
		pev(toucher, pev_classname, classname, 31)

		if (equal(classname,"sporemine")) {
			sporemine_touchedx(toucher,touched)
		}
	}
	return FMRES_IGNORED
}

public hook_Think_co(ent) {

	if (pev_valid(ent)) {
		static classname[32]
		pev(ent, pev_classname, classname, 31)

		if (equal(classname,"sporemine")) {
			sporemines_think_cox(ent)
		}
		
		//this is for the server_frame replacement
		if (equal(classname,"smine_serverframe")) {
			ServerFrame(ent)
		}
	}
	return FMRES_IGNORED
}

public hook_Think_ns(ent) {

	if (pev_valid(ent)) {
		static classname[32]
		pev(ent, pev_classname, classname, 31)

		if (equal(classname,"sporemine")) {
			sporemines_thinkx(ent)
		}
		
		//this is for the server_frame replacement
		if (equal(classname,"smine_serverframe")) {
			ServerFrame(ent)
		}
	}
	return FMRES_IGNORED
}

public hook_Impulse(id, cmd, random_seed ) {
	
	if (get_uc(cmd, UC_Impulse) == GORGEIMPULSE) {
		do_gorgeimpulse(id)
	}
		
	if (ns_is_combat() && get_uc(cmd, UC_Impulse) == SCANIMPULSE) {
		got_scan(id)
	}

	return FMRES_IGNORED
}

/*
public client_connect(id){
	client_cmd(id,"echo ^"* Alien Sporemine(gorge only) Amxx Plugin version %s  %s^"",g_Version,g_Date)
	client_cmd(id,"echo ^"	Commands:^"")
	client_cmd(id,"echo ^"		1- bind 'KEY' sporemine^"")
	client_cmd(id,"echo ^"		2- Press on your evol gorge button^"")
	client_cmd(id,"echo ^"	By mahnsawce, continued by %s^"",g_Author)
}*/

public event_Countdown() { 
	g_roundstarted = 1
	reset_allvar(0)
	new t = ns_get_build("sporemine",0,0)
	for (new j=0;j<=t;++j) //remove all mine if game start
		engfunc(EngFunc_RemoveEntity, ns_get_build("sporemine",0,1))
	Reset_manysmine()
}

public make_sporemine(id) {
	if (ns_is_combat())  {
		if (ns_get_class(id) == 2) {	// gorge only.
			if (g_smine_co[id] >= 1)  {
				
				if (getsmcount(id) >= SMINE_MAX_PERRNG) {		// Only allow so many mines in an area.
					hud_sporemine_to1(id,0)
					nspopup(id,infoStr[TOOMANYMINES])
				}else {
					if (g_pickup_time[id] == 0.0 && SMINE_CO_REPICKUP_TIME >= 0) {
						g_pickup_time[id] = get_gametime()+SMINE_CO_REPICKUP_TIME
					}
					g_smine_co[id]--
					new smine = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
					movetoent(smine,id,1)
					set_pev(smine,pev_owner,id)
					set_pev(smine,pev_team,0)
					set_team(smine)
					dllfunc(DLLFunc_Spawn, smine)
					fm_set_kvd(smine,"classname","sporemine","info_target")
					sporemines_spawnx(smine)
					
					make_smine_song(id)
					hud_sporemine_to1(id,0) // added by Flash24
					set_expiration(smine)
				}
			} else {
				nspopup(id,infoStr[ONEPERLIFE])
			}
		} else {
			hud_sporemine_to1(id,0)
			nspopup(id,infoStr[NEEDTOBEGORGE])
		}
		return PLUGIN_HANDLED
	}else{
		if (ns_get_class(id) == 2) {// gorge only.
		
			if (ns_get_res(id) >= SMINE_NS_COST) {
			// Only allow so many mines in an area.
				if (getsmcount(id) >= SMINE_MAX_PERRNG) {
					nspopup(id,infoStr[TOOMANYMINES])
					hud_sporemine_to1(id,0)
				}else{
					new smine = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
					movetoent(smine,id,1)
					set_pev(smine,pev_owner,id)
					set_pev(smine,pev_team,0)
					set_team(smine)
					dllfunc(DLLFunc_Spawn, smine)
					
					fm_set_kvd(smine,"classname","sporemine","info_target")
					sporemines_spawnx(smine)
					
					ns_set_res(id,ns_get_res(id) - SMINE_NS_COST)
					make_smine_song(smine)
					hud_sporemine_to1(id,0)
					set_expiration(smine)
				}
			}else{
				nspopup(id,infoStr[NOTENOUGHRES])
				hud_sporemine_to1(id,0)
			}
		}else{
			nspopup(id,infoStr[NEEDTOBEGORGE])
		}
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}

public get_team(smine){
	new team
	new vuser3[3]
	pev(smine,pev_vuser3,vuser3)
	team = vuser3[2]
	return team
}

public set_team(smine){
	new team = pev(pev(smine,pev_owner),pev_team)
	new vuser3[3]
	pev(smine,pev_vuser3,vuser3)
	vuser3[2]=team
	set_pev(smine,pev_vuser3,vuser3)
}

// Helper functions for the plugin
public set_smine_size(id) {
	engfunc(EngFunc_SetSize, id,Float:{-4.0,-4.0,0.0},Float:{4.0,4.0,4.0})
	set_pev(id,pev_solid,1) //1
	set_pev(id,pev_movetype,6)
}

public movetoent(idMoved,idDest,MoveOnAim) {
	new Float:origin[3]
	pev(idDest,pev_origin,origin)
	set_pev(idMoved,pev_origin,origin)
	
	if (MoveOnAim == 1){
		new Float:velo[3]
		velocity_by_aim(idDest,SMINE_VELOCITY,velo)
		
		set_pev(idMoved,pev_velocity,velo)
	}else{
		engfunc(EngFunc_DropToFloor, idMoved)
	}
}

public getsmcount(id) {
	new j
	for (new i=1;i<=ns_get_build("sporemine",0,0);i++) {
		if (fm_entity_range(id,ns_get_build("sporemine",0,i)) <= 1000) {
			j++
		}
	}
	return j
}

public nspopup(id,szText[]) {
	message_begin(MSG_ONE,gmsgHudText2,{0,0,0},id)
	write_string(szText)
	write_byte(0)
	message_end()
}

stock is_morph(id) {
	if (ns_get_class(id) == CLASS_GESTATE) 
		return 1
	return 0
}

stock getdamage(idvictim,idkiller,szClassname[],Float:takedmgdamage,damagetype) {
	
	new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "trigger_hurt"))
	if (entity && pev(idvictim,pev_deadflag) == 0 && idvictim <= g_maxplayers){
		new Float:dmg = (takedmgdamage * 2)
		new szDamage[16],szDamage2[16]
		format(szDamage,15,"%f",dmg)
		format(szDamage2,15,"%i",damagetype)

		fm_set_kvd(entity,"classname","trigger_hurt")
		fm_set_kvd(entity,"dmg",szDamage)
		fm_set_kvd(entity,"damagetype",szDamage2)
		fm_set_kvd(entity,"origin","8192, 8192, 8192")

		dllfunc(DLLFunc_Spawn, entity)
		
		set_pev(entity,pev_classname,szClassname)
		new playerdie
		new hp2 = pev(idvictim,pev_health)
		if (hp2 <= (dmg*2)) playerdie = 1
		if (playerdie) set_msg_block(get_user_msgid("DeathMsg"),BLOCK_ONCE)
		dllfunc(DLLFunc_Touch, entity, idvictim)
		if (playerdie) set_msg_block(get_user_msgid("DeathMsg"),BLOCK_NOT)
		engfunc(EngFunc_RemoveEntity, entity)
		if (pev(idvictim,pev_deadflag) != 0){
			makeDeathMsg(idkiller, idvictim, szClassname)
			
			if (ns_is_combat() && g_smine_co[idkiller] == 0){
				g_smine_co[idkiller]++
				hud_sporemine_to1(idkiller,1)
				
			}
		}	
	}
}

stock makeDeathMsg(killer, victim, weapon[]) {
	if (!say_msg[victim]) {
		say_msg[victim] = 1
		// Create the fake message in top right corner	
		emessage_begin(MSG_ALL, get_user_msgid("DeathMsg"),{0,0,0},0)
		ewrite_byte(killer)
		ewrite_byte(victim)
		ewrite_string(weapon)
		emessage_end()

		if (pev(killer,pev_team) == 2) {
			if (ns_is_combat()){
				new Float:exp = ns_get_exp(killer)
				ns_set_exp(killer,exp + float( check_level(killer) * 10 + 60 ) )
			}
			else{
				new Float:res= ns_get_res(killer)
				ns_set_res(killer,res +2)
			}
			//set_pev(killer,pev_frags, pev(killer,pev_frags)+1)

			scoreBoardInfo[killer][SCORE] += 1
			scoreBoardInfo[killer][FRAGS] += 1
			refresh_ScoreBoard(killer)
		}
		set_task(0.5,"reset_saymsg",victim)
	}
	return PLUGIN_HANDLED
}

public reset_saymsg(id)
	say_msg[id] = 0

public sporemines_spawnx(id) {

	engfunc(EngFunc_SetModel, id, SMINE_MODEL)
	set_pev(id,pev_rendermode,0) 	// render normal
	set_pev(id,pev_renderfx,0) 	// no fx
	set_pev(id,pev_movetype,6)
	set_pev(id,pev_fuser1,SMINE_ATTACKS_TIME)
	
	new Float:angles[3]
	pev(id,pev_angles,angles)
	
	#if defined SMINE_ROUND
	angles[0] = angles[0] - 90.0
	set_pev(id,pev_angles,angles) // Orient it properly on the floor...
	#else
	angles[0] = angles[0] + 90.0
	set_pev(id,pev_angles,angles) // Orient it properly on the floor...
	#endif
	set_pev(id,pev_iuser3,0)
	new Float:vuser1[3]
	pev(id,pev_vuser1,vuser1)
	vuser1[0] = SPOREMINE_SET
	set_pev(id,pev_vuser1,vuser1) // vuser1.x is our "state". 
	set_smine_size(id)
	set_pev(id,pev_nextthink,get_gametime()+2.0) // make it "initialize" in 2 seconds
	set_pev(id,pev_health,SMINE_HP)
	set_pev(id,pev_takedamage,1.0)
}

public sporemine_touchedx(smine,id)
{
	new Float:vuser1[3]
	pev(smine,pev_vuser1,vuser1)
	new team = get_team(smine)
	//client_print(0,print_console,"TEST %d",id)
	if (pev(id,pev_team) != team && pev(id,pev_team) > 0 
	&& pev(id,pev_deadflag) == 0 && ns_get_mask(id,4194304) == 0 
	&& id <= g_maxplayers
	&& vuser1[0] == SPOREMINE_ACTIVE) // Don't trigger on dead, or digesting marines
	{
		Prepar_Smine(smine,id,1)
	}
}

stock Prepar_Smine(smine,id,Touched){
	new Float:vuser1[3]
	pev(smine,pev_vuser1,vuser1)
	if (pev(smine,pev_rendermode) != 0){
    cloak_uncloak_song(smine,0)
    ns_set_mask(smine,MASK_CLOAKING,0)
    set_pev(smine,pev_rendermode,0)
    set_pev(smine,pev_renderfx,0)
    set_pev(smine,pev_renderamt,0.0)
  }
	if (Touched == 0) {
		//server_print("SporeMine Time Out (%d)! ",smine)
		new iid = i_id("set",smine)
		g_smineTOut[iid] = smine
	}
	set_pev(smine,pev_team,0)
	play_songandevent(1,smine)
	new Float:origin[3]
	pev(id,pev_origin,origin)
	vuser1[0] = SPOREMINE_PRE_ATTACK
	vuser1[1] = 0.0
	set_pev(smine,pev_vuser1,vuser1)
	set_pev(smine,pev_vuser2,origin)
	// Make the mine invisible (so it appears it burst into a cloud of spores.)
	// Modified
	if (pev(smine,pev_iuser2) == 1){
  	set_pev(smine,pev_iuser2,2)
  	pev(smine,pev_origin,origin)
  	origin[2] += 5.0
  	set_pev(smine,pev_origin,origin)
  }
	else if (pev(smine,pev_iuser2) == 0){
  	set_pev(smine,pev_iuser2,3)
  	pev(smine,pev_origin,origin)
  	origin[2] += 10.0
  	set_pev(smine,pev_origin,origin)
  }
	set_pev(smine,pev_nextthink,get_gametime()+ SMINE_PREATTACK_TIME)
}

stock set_expiration(id){
	if (SMINE_EXPIRED_TIME > 0.0) {
		set_pev(id,pev_fuser4,get_gametime()+SMINE_EXPIRED_TIME)
	}
}

public sporemines_thinkx(id) {
	new Float:vuser1[3]
	pev(id,pev_vuser1,vuser1)
	if (vuser1[0] == SPOREMINE_SET) {// Do our initialization here
		vuser1[0] = SPOREMINE_ACTIVE0
		set_pev(id,pev_vuser1,vuser1)
		set_pev(id,pev_nextthink,get_gametime()+0.2)
		set_smine_size(id)
	} else if (vuser1[0] == SPOREMINE_ACTIVE0){
		vuser1[0] = SPOREMINE_ACTIVE
		set_pev(id,pev_vuser1,vuser1)
		set_pev(id,pev_nextthink,get_gametime()+0.5)
		down_smine2(id)
	} else if (vuser1[0] == SPOREMINE_ACTIVE) { // It's looking for an enemy...

		if (SMINE_EXPIRED_TIME > 0.0 && get_gametime() > pev(id,pev_fuser4)){
			Prepar_Smine(id,id,0)
			return
		}
		if (pev(id,pev_health) <= 0.0) {
			remove_smine4(id)
			return
		}
		
		set_pev(id,pev_nextthink,get_gametime()+0.2)
		
		new k,s,sc,m
		#if defined SMINE_SENSORY
		m = 0
		for (s=1;s<=ns_get_build("sensorychamber",0,0);s++) {
			k = ns_get_build("sensorychamber",0,s)
			if (ns_get_mask(k,MASK_BUILDABLE)) // added by Flash24
				continue
			if (fm_entity_range(id,k) <= SMINE_SC_RANGE) {
				if (pev(k,pev_fuser2) > 0) {
					m = 1
				}
			}
		}
		#endif
		for (s=1;s<=ns_get_build("scan",0,0);s++) { // Quick hack to make pings uncloak the mines.
			k = ns_get_build("scan",0,s)
			if (fm_entity_range(id,k) <= SMINE_SCAN_RANGE) {
				sc =1
				m = 0
			}
		}
		
		for (s=1;s<=ns_get_build("team_observatory",0,0);s++) {// Quick hack to radar uncloak the mines.
		
			k = ns_get_build("team_observatory",0,s)
			if (ns_get_mask(k,MASK_BUILDABLE))
				continue
		
			if (fm_entity_range(id,k) <= SMINE_OBS_RANGE) {
				m = 0
			}
		}
		
		if (m == 1 && pev(id,pev_rendermode) != 1) {
			cloak_uncloak_song(id,1)
			ns_set_mask(id,MASK_CLOAKING,1)
			set_pev(id,pev_rendermode,1)
			set_pev(id,pev_renderfx,5) //5
			set_pev(id,pev_renderamt,45.0) //45.0
		}  else if (m == 0 && pev(id,pev_rendermode) != 0) {
			cloak_uncloak_song(id,0)
			ns_set_mask(id,MASK_CLOAKING,0)
			set_pev(id,pev_rendermode,0)
			set_pev(id,pev_renderfx,0)
			set_pev(id,pev_renderamt,0.0)
		}
		
		if (sc == 1)
		set_pev(id,pev_team,0)
		else 
		set_pev(id,pev_team,2)
		
		if (get_gametime()>= g_LastTime[id]) {
			g_LastTime[id] = get_gametime()+0.2
			up_smine(id)
		}
	} else if (vuser1[0] == SPOREMINE_PRE_ATTACK){
		vuser1[0] = SPOREMINE_ATTACKING
		set_pev(id,pev_vuser1,vuser1)
		play_songandevent(2,id)
		set_task(0.1,"Blast_smine",id)
		set_pev(id,pev_nextthink,get_gametime()+0.5)
	#if defined SMINE_MOVEMENT
		new k,s,m
		m = 0
		for (s=1;s<=ns_get_build("movementchamber",0,0);s++){
			k=ns_get_build("movementchamber",0,s)
			if (ns_get_mask(k,MASK_BUILDABLE)) // added by Flash24
			continue
			if (fm_entity_range(id,k) <= SMINE_MC_RANGE){
				if (pev(k,pev_fuser2) > 0){
					m = 1
					break
				}
			}
		}
		if (m == 1){
			set_pev(id,pev_fuser1,SMINE_ATTACKS_TIME +6.0)
		}
	#endif
	} else if (vuser1[0] == SPOREMINE_ATTACKING || vuser1[0] == SPOREMINE_HIDE) { // It's attacking...
			if (vuser1[1] <= get_gametime() && vuser1[0] != SPOREMINE_HIDE) {
				play_songandevent(3,id)        
			}
			for (new i = 1;i<=g_maxplayers;++i) {
				if (pev_valid(i)) {
					new team = get_team(id)
					#if SMINE_DMG_HEAVY == 1
					if (fm_entity_range(i,id) <= SMINE_DRANGE && (pev(i,pev_team) != team) && (pev(i,pev_team) > 0) && (pev(i,pev_deadflag) == 0) && (ns_get_mask(i,4194304) == 0)) // Don't trigger on dead, or digesting marines
					#else
					if (fm_entity_range(i,id) <= SMINE_DRANGE && (pev(i,pev_team) != team) && (pev(i,pev_team) > 0) && (pev(i,pev_deadflag) == 0) && (ns_get_mask(i,4194304) == 0) && (ns_get_class(i) != 8))
					#endif      
					{
						getdamage(i,pev(id,pev_owner),"sporemine",SMINE_DMG,1)   
					}
				}
			}
			
			set_pev(id,pev_fuser1,pev(id,pev_fuser1)-0.5)
			new Float:n
			pev(id,pev_fuser1,n)
			if (n == 7.0) {
				down_smine(id)
			}else if (n == 6.5){
				remove_smine3(id)
			}
			
			if (n <= 0) {// The mine has expired.  Remove it.
				remove_smine(id)
			}else{
				if (pev(id,pev_rendermode) != 0 && pev(id,pev_iuser3) != 69){
					set_pev(id,pev_rendermode,0)
					set_pev(id,pev_renderfx,0)
					set_pev(id,pev_renderamt,0.0)
				}
				set_pev(id,pev_nextthink,get_gametime() + SMINE_DTIME)
			}
	}else if (vuser1[0] == SPOREMINE_EXHAUSTED){
		remove_smine2(id)
	}
}

public sporemines_think_cox(id) {
	new Float:vuser1[3]
	pev(id,pev_vuser1,vuser1)
	
	if (vuser1[0] == SPOREMINE_SET) {// Do our initialization here
		vuser1[0] = SPOREMINE_ACTIVE0
		set_pev(id,pev_vuser1,vuser1)
		set_pev(id,pev_nextthink,get_gametime()+0.2)
		set_smine_size(id)
	} else if (vuser1[0] == SPOREMINE_ACTIVE0) {
		vuser1[0] = SPOREMINE_ACTIVE
		set_pev(id,pev_vuser1,vuser1)
		set_pev(id,pev_nextthink,get_gametime() + 0.5)
		down_smine2(id)
	} else if (vuser1[0] == SPOREMINE_ACTIVE) {	// It's looking for an enemy...
		if (SMINE_EXPIRED_TIME > 0.0 && get_gametime() > pev(id,pev_fuser4)) {
			Prepar_Smine(id,id,0)
			return
		}
		if (pev(id,pev_health) <= 0.0) {
			remove_smine4(id)
			return
		}
		set_pev(id,pev_nextthink,get_gametime() + 0.2)
		new k,s,m,sc
		
		#if defined SMINE_CO_CLOAKED
		m = 0
		if (ns_get_mask(pev(id,pev_owner),MASK_CLOAKING)) {
			m = 1
		}else{
			for (s=1;s<=ns_get_build("sensorychamber",0,0);s++) {
				k=ns_get_build("sensorychamber",0,s)
				if (ns_get_mask(k,MASK_BUILDABLE)) // added by Flash24
					continue
				if (fm_entity_range(id,k) <= SMINE_SC_RANGE) {
					if (pev(k,pev_fuser2) > 0) {
						m = 1
					}
				}
			}
		}
		#endif
		for (s=1;s<=ns_get_build("team_observatory",0,0);s++) {// Quick hack to radar uncloak the mines.
		
			k = ns_get_build("team_observatory",0,s)
			if (ns_get_mask(k,MASK_BUILDABLE))
				continue
			
			if (fm_entity_range(id,k) <= SMINE_OBS_RANGE) {
				m = 0
			}
		}
		
		new tt = ns_get_build("scan",0,0)
		for (s=1;s<=tt;s++) {// Quick hack to make pings uncloak the mines.
			k = ns_get_build("scan",0,s)
			if (fm_entity_range(k,id) <= SMINE_SCAN_RANGE) {
				sc=1
				m = 0
			}
		}
		
		if (m == 1 && pev(id,pev_rendermode) != 1) {
			ns_set_mask(id,MASK_CLOAKING,1)
			cloak_uncloak_song(id,1)
			set_pev(id,pev_rendermode,1)
			set_pev(id,pev_renderfx,5) //5
			set_pev(id,pev_renderamt,45.0) //45.0
		}else if (m == 0 && pev(id,pev_rendermode) != 0) {
			cloak_uncloak_song(id,0)
			ns_set_mask(id,MASK_CLOAKING,0)
			set_pev(id,pev_rendermode,0)
			set_pev(id,pev_renderfx,0)
			set_pev(id,pev_renderamt,0.0)
		}
		if (sc == 1)
			set_pev(id,pev_team,0)
		else 
			set_pev(id,pev_team,2)
			
		if (get_gametime() >= g_LastTime[id]) {
			g_LastTime[id] = get_gametime()+0.2
			up_smine(id)
		}
	}else if (vuser1[0] == SPOREMINE_PRE_ATTACK) {
		vuser1[0] = SPOREMINE_ATTACKING
		set_pev(id,pev_vuser1,vuser1)
		play_songandevent(2,id)
		set_task(0.1,"Blast_smine",id)
		set_pev(id,pev_nextthink,get_gametime()+0.5)
	}else if (vuser1[0] == SPOREMINE_ATTACKING || vuser1[0] == SPOREMINE_HIDE) {	// It's attacking...
	
		if (vuser1[1] <= get_gametime() && vuser1[0] != SPOREMINE_HIDE) {
			play_songandevent(3,id)       
		}
    
		for (new i = 1;i<=g_maxplayers;i++) {
			if (pev_valid(i)) {
				new team = get_team(id)
				#if SMINE_DMG_HEAVY == 1
				if (fm_entity_range(i,id)<=SMINE_DRANGE && (pev(i,pev_team) != team) && (pev(i,pev_team) > 0) && (pev(i,pev_deadflag) == 0) && (ns_get_mask(i,4194304) == 0)) // Don't trigger on dead, or digesting marines
				#else
				if (fm_entity_range(i,id)<=SMINE_DRANGE && (pev(i,pev_team) != team) && (pev(i,pev_team) > 0) && (pev(i,pev_deadflag) == 0) && (ns_get_mask(i,4194304) == 0) && (ns_get_class(i) != 8))
				#endif      
				{
					getdamage(i,pev(id,pev_owner),"sporemine",SMINE_DMG,1)
				}
			}
		}
		
		set_pev(id,pev_fuser1,pev(id,pev_fuser1) - 0.5)
		new Float:n
		pev(id,pev_fuser1,n)
		if (n == 7.0){
			down_smine(id)
		}else if (n == 6.5) {
			remove_smine3(id)
		}
		
		if (n <= 0) { // The mine has expired.  Remove it.
			remove_smine(id)
		}else{
			if (pev(id,pev_rendermode) != 0 && pev(id,pev_iuser3) != 69) {
				set_pev(id,pev_rendermode,0)
				set_pev(id,pev_renderfx,0)
				set_pev(id,pev_renderamt,0.0)
			}
			set_pev(id,pev_nextthink,get_gametime() + SMINE_DTIME)
		}
	}else if (vuser1[0] == SPOREMINE_EXHAUSTED) {
		remove_smine2(id)
	}
}

stock get_level(id) {
	new cur_xp = floatround(ns_get_exp(id))
	new temp_xp, xp_to_next_lvl = 100, player_level = 1
	while ( cur_xp > ( temp_xp + xp_to_next_lvl ) )
	{
		temp_xp += xp_to_next_lvl
		xp_to_next_lvl += 50
		++player_level
	}
	
	return player_level
}

stock check_level(id){
	if (!pev_valid(id)) return 0
	new cur_xp = get_xp(id)
	if ( cur_xp > XP_LEVEL_10 ){
		return 9
	}else if ( cur_xp > XP_LEVEL_9 ){
		return 8
	}else if ( cur_xp > XP_LEVEL_8 ){
		return 7
	}else if ( cur_xp > XP_LEVEL_7 ){
		return 6
	}else if ( cur_xp > XP_LEVEL_6 ){
		return 5
	}else if ( cur_xp > XP_LEVEL_5 ){
		return 4
	}else if ( cur_xp > XP_LEVEL_4 ){
		return 3
	}else if ( cur_xp > XP_LEVEL_3 ){
		return 2
	}else if ( cur_xp > XP_LEVEL_2 ){
		return 1
	}
	return 0
}

stock get_xp(id) {
	return floatround(ns_get_exp(id))
}
stock set_xp(id,Float:exp) {
	return ns_set_exp(id,exp)
}

  //stocks from fakemeta_util.inc
stock fm_set_kvd(entity, const key[], const value[], const classname[] = "") {
	if (classname[0])
		set_kvd(0, KV_ClassName, classname)
	else {
		new class[32]
		pev(entity, pev_classname, class, sizeof class - 1)
		set_kvd(0, KV_ClassName, class)
	}
	set_kvd(0, KV_KeyName, key)
	set_kvd(0, KV_Value, value)
	set_kvd(0, KV_fHandled, 0)
	return dllfunc(DLLFunc_KeyValue, entity, 0)
}

stock Float:fm_entity_range(ent1, ent2) {
	new Float:origin1[3], Float:origin2[3]
	pev(ent1, pev_origin, origin1)
	pev(ent2, pev_origin, origin2)
	return get_distance_f(origin1, origin2)
}
