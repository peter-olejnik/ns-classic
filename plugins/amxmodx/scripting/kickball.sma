/*
 *  Comments: 
 *  Kickball, each team, must fight for control of the "ball" and kick it to the enemy Command Chair.
 *  The ball can and will do damage to the enemy, if going fast enough and randomly, according to the CVARs.
 *  Upon scoring, the team will receive a cheerleader for their team's goal, only one team may have the cheerleader
 *  at one time.  At the end, of match, a Top Statistics of the game will be displayed.
 *
 *	Note:	The plugin requires an entity added to maps manually, view command below for details.  
 *	
 * 	Commands: 
 *		kickball_spawn 		- Adds <mapname> <origin> of ball spawn location to kickball.ini , if none exists
 									plugin will create one automatically. To use, simply enter map, stand where
 									you want ball to spawn. And type command, requires RCON access.  After you
 									have created a location, after restarting map, ball will spawn where you specified.
 *	CVARs:
 *		amx_ball			- CVAR for determining if kickball is activated, (from another plugin).
 *		- These CVARS can be changed at any time during round!
 *		kickball_kick 		(default: 1000)	- Kicking velocity without meter.
 *		kickball_meter 		(default: 0)	- Disable/Enable kicking meter.
 *		kickball_dmg 		(default: 0.13)	- Damage multiplier for when ball hits enemy.
 *		kickball_dmgpct 	(default: 40)	- Percentage chance for taking damage by ball. (If it goes to fast.)
 *		kickball_knife 		(default: 0)	- Make the round knife only.
 *		kickball_jetpack 	(default: 0)	- Disable/Enable jetpack buying.
 *		kickball_score 		(default: 6)	- Scores needed to win a round.
 *		kickball_reset 		(default: 30.0)	- Ball reset time, to respawn at ball spawn location.
 *		kickball_goalsafety (default: 300)	- Distance around Comm Chair, that does damage to enemy.
 *		
 *  Version : 	1.0
 *	Requires:	AMXX 1.01 or 1.5 with NS module 
 *
 *	Author:		OneEyed
 *	Date:		08-21-2005
 *	Email:		oneeyed@stx.rr.com
 *	IRC:		#zT (gamesurge.net) 
 *
 * 	Tested :
 *	Kickball plugin was tested on a win32 machine.  Linux untested.
 * 
 *  Credits: 
 *    theqizmo     		   - Helped with alot of ideas and things in this plugin.
 * 	  WhitePanther 		   - Knife Knockback Effect
 *	  Twilight Suzuka	   - For snippet on keeping a model in front.
 *    CheesyPeteza 		   - For his impulse handler.
 *    zeroTolerance server - For helping test it on live server. ip: 209.75.97.8:27015
 *   
 */


#include <amxmodx>
#include <amxmisc>
#include <engine>     
#include <fakemeta>
#include <ns>
#include <fun>


//------------------------------------------------------------------------------------
//DANCER
//------------------------------------------------------------------------------------
//Comment this to NOT use a dancer
//Dancer will appear on top of team command chair, of team who recently scored.
#define DANCER
//------------------------------------------------------------------------------------
//MODELS
//------------------------------------------------------------------------------------
//You may change the ball model and dancer model. Just give correct path of new model.
new ball[] = "models/kickball/ball.mdl"

#if defined DANCER
	new dancerm[] = "models/kickball/dancer.mdl"
	new dancerCreated //do not touch this
#endif
//------------------------------------------------------------------------------------
//GLOW COLORS 
//------------------------------------------------------------------------------------
//Only ball holder, Comm Chairs, and ball will glow!
//Format is (0-255) { Red , Green , Blue }
//Team ONE Color
new team1color[3] = { 10,10,250 }	//BLUE
//Team TWO Color
new team2color[3] = { 250,10,10 } 	//RED
//Ball color
new ballcolor[3] = { 255,200,100 } 	// YELLOW
//------------------------------------------------------------------------------------


//-----------------------------------------------------------------------------------------------------------------
//------------------DO NOT TOUCH BELOW THIS LINE, unless you know what your doing.---------------------------------
//-----------------------------------------------------------------------------------------------------------------
#define HUD_CHANNEL 7
#define MESSAGE_DELAY 4.0

new kicked[] = "kickball/kicked.wav"
new ballhit[] = "kickball/bounce.wav"
new distress[] = "misc/distressbeacon.wav"
new returned[] = "kickball/returned.wav"
new amaze[] = "kickball/amaze.wav"
new laugh[] = "kickball/laugh.wav"
new perfect[] = "kickball/perfect.wav"
new diebitch[] = "kickball/diebitch.wav"
new pussy[] = "kickball/pussy.wav"
new prepare[] = "kickball/prepare.wav"
new gotball[] = "kickball/gotball.wav"
new tomes[] = "kickball/tomes.wav"
new bday[] = "kickball/bday.wav"

new bholder
new ballowner
new maxplayers

new info[4][] = {
	"Capture and Kick the ball to ENEMY Command Chair!",
	"Blue Team Goals:",
	"Red Team Goals:",
	"Goals Wins." 
}

new sname[32], tsname[32], maname[32], mdname[32], kiname[32]
new aball, someoneScored = 0
new is_kickball
new Float:testorigin[3], Float:attacker_vec[33][3], Float:vd[3], Float:velocity[3]
new fire, smoke, beamspr, Burn_Sprite //beam, precache effects
new score[3], scoreEvent, resetting
new scoreboard[1025]
new temp1[64], temp2[64]
new madesteal[33], scored[33], madeassist[33], madekill[33]
new distorig[2][3] //distance recorder
new topsteal, highsteal, topassist, highassist, topdist, highdist, topkill, highkill
new topscored, highscored, killedcc
new gmsgDeathMsg, gmsgProgress
new Float:powerAmt, powerMeter, meterD
new Float:g_lastmessage[33], goaldied[33]

new assist[16]
new iassist[4]
//-----------------------------------------------------------------------------------------------------------------
public precacheFiles() {
	engfunc( EngFunc_PrecacheModel, ball)
	#if defined DANCER
		engfunc( EngFunc_PrecacheModel, dancerm)
	#endif
	
	beamspr = engfunc( EngFunc_PrecacheModel,"sprites/laserbeam.spr")
	fire = engfunc( EngFunc_PrecacheModel,"sprites/shockwave.spr")
	smoke = engfunc( EngFunc_PrecacheModel,"sprites/steam1.spr")
	//Burn_Sprite = engfunc( EngFunc_PrecacheModel,"sprites/xfire.spr")
	Burn_Sprite = engfunc( EngFunc_PrecacheModel,"sprites/muzzleflash.spr")
	engfunc( EngFunc_PrecacheSound, amaze)
	engfunc( EngFunc_PrecacheSound, laugh)
	engfunc( EngFunc_PrecacheSound, perfect)
	engfunc( EngFunc_PrecacheSound, diebitch)
	engfunc( EngFunc_PrecacheSound, pussy)
	engfunc( EngFunc_PrecacheSound, prepare)
	engfunc( EngFunc_PrecacheSound, tomes)
	engfunc( EngFunc_PrecacheSound, ballhit)
	engfunc( EngFunc_PrecacheSound, gotball)
	engfunc( EngFunc_PrecacheSound, bday)
	engfunc( EngFunc_PrecacheSound, returned)
	engfunc( EngFunc_PrecacheSound, distress)
	engfunc( EngFunc_PrecacheSound, kicked)
}
//-----------------------------------------------------------------------------------------------------------------
public plugin_init() {
	
	if(is_mvm()) {
		register_cvar("amx_ball","0",FCVAR_SERVER)
		register_concmd("kickball_spawn","createSpawn",ADMIN_RCON," - Creates a Kickball BALL spawn. (1 per map)")
		register_concmd("kickball_bind","cmdBindButton",ADMIN_BAN," <name> <key> - Binds a button to kickball for user.")
		//Check if entity is hardcoded/ripented in map
		is_kickball = find_ent_by_tname(0, "kickball")
		//If not, search for it in kickball.ini , and make the entity
		if(!is_kickball) {
			LoadBallSpawn()
			//Check for the entity again
			is_kickball = find_ent_by_tname(0, "kickball")
		}
		
		if(is_kickball > 0) {
			
			precacheFiles()
			
			register_plugin("Kickball (ON)", "1.0", "OneEyed")
			
			gmsgDeathMsg = get_user_msgid("DeathMsg")
			gmsgProgress = get_user_msgid("Progress")
			set_cvar_num("amx_ball",1)
			maxplayers = get_maxplayers()
			
			register_clcmd("kickball","kickBall")
			register_clcmd("say","handle_say")
			
			register_event("GameStatus", "EndofRound", "ab", "1=2" )
			register_event("Countdown", "gameStart", "ac")
			register_event("Damage","KnifeDmg", "b","2!0")
			register_event("ResetHUD","ResetHUD","b")
			
			if(!cvar_exists("kickball_meter"))
				register_cvar("kickball_meter","0")
			if(!cvar_exists("kickball_score"))
				register_cvar("kickball_score","6")
			if(!cvar_exists("kickball_knife"))
				register_cvar("kickball_knife","0")
			if(!cvar_exists("kickball_reset"))
				register_cvar("kickball_reset","30.0")
			if(!cvar_exists("kickball_goalsafety"))
				register_cvar("kickball_goalsafety","300")
			if(!cvar_exists("kickball_dmg"))
				register_cvar("kickball_dmg","0.13")
			if(!cvar_exists("kickball_kick"))
				register_cvar("kickball_kick","1000")
			if(!cvar_exists("kickball_dmgpct"))
				register_cvar("kickball_dmgpct","40")
			if(!cvar_exists("kickball_jetpack"))
				register_cvar("kickball_jetpack","0")
				
			register_touch("PwnBall", "player", 			"touchPlayer")
			register_touch("PwnBall", "team_command",		"touchCC")
			register_touch("PwnBall", "worldspawn",			"touchWorld")
			register_touch("PwnBall", "func_wall",			"touchWorld")
			register_touch("PwnBall", "func_door",			"touchWorld")
			register_touch("PwnBall", "func_door_rotating", "touchWorld")
			register_touch("PwnBall", "func_wall_toggle",	"touchWorld")
			register_touch("PwnBall", "func_breakable",		"touchWorld")
	
			register_think("PwnBall","ball_think")
	
			register_impulse(39,"block_jetpack")
			
			for( new x = 23 ; x <= 25 ; x++)
				register_impulse(x,"block_other")
			for( new x = 61 ; x <= 66 ; x++)
				register_impulse(x,"block_other")
		}
		else {
			register_plugin("Kickball (OFF)", "1.0", "OneEyed")
			set_cvar_num("amx_ball",0)
			log_amx("There is no ball spawn location, use ^"kickball_spawn^" to create a ball spawn.")
			log_amx("Join the map, and type it in, where you want the ball to spawn, and restart map.")
		}
	}
	else
		register_plugin("Kickball (OFF)", "1.0", "OneEyed")
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public cmdBindButton(id,level,cid) {
	if (!cmd_access(id,level,cid,2))
		return PLUGIN_HANDLED
		
	new arg[32]
	read_argv(1,arg,31)
	
	new player = cmd_target(id,arg,5)
	if (!player) 
		return PLUGIN_HANDLED
		
	new arg2[32]
	read_argv(2,arg2,31)
	
	new bind[64]
	format(bind,63,"bind ^"%s^" ^"kickball^"",arg2)
	client_cmd(player,"%s",bind)
	
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public LoadBallSpawn() {
	new filename[512], mapname[64], configdir[64], text[512], mapcfg[4][64]
	new Float:bsO[3], currentLine, sSize
	get_localinfo("amxx_configsdir",configdir,63)
	get_mapname(mapname,63)
	format(filename, 511, "%s/kickball.ini",configdir)
	if ( file_exists(filename) ) {
		
		//Read Map Ball Spawn Origin from .ini file
		while( read_file(filename, currentLine++, text, 511, sSize) > 0 ) {
			//server_print("current line # = %i",currentLine)
			if ( text[0] == ';' || ( text[0] == '/' && text[1] == '/' ) )
				continue
			parse(text, mapcfg[0], 63, mapcfg[1], 63, mapcfg[2], 63, mapcfg[3], 63)
			if(equali(mapcfg[0], mapname)) {
				
				//copy origin from .ini file to origin
				for(new x=1;x<4;x++)
					bsO[x-1] = float(str_to_num(mapcfg[x]))
					
				//create the custom entity for ball spawn location
				new ent = create_entity("info_target")
				if(ent) {
					DispatchKeyValue(ent,"targetname","kickball")
					entity_set_origin(ent, bsO)
				}
				return PLUGIN_HANDLED
			}
		}
	}
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public createSpawn(id,level,cid) {
	if (!cmd_access(id,level,cid,0))
		return PLUGIN_HANDLED
	new filename[512]
	new mapname[64]
	new configdir[64]
	new text[512]
	get_localinfo("amxx_configsdir",configdir,63)
	get_mapname(mapname,63)
	format(filename, 511, "%s/kickball.ini",configdir)
	
	//Grab current origin of user, and make mapname origin line
	new Float:saveOrig[3]
	entity_get_vector(id,EV_VEC_origin,saveOrig)
	format(text,511, "%s %i %i %i",mapname,floatround(saveOrig[0]),floatround(saveOrig[1]),floatround(saveOrig[2]))
	
	//Check if file exists
	new mapcfg[4][64]
	new currentLine, readTxt[512], sSize
	new fileLine
	if ( file_exists(filename) ) {
		while( (fileLine = read_file(filename, currentLine++, readTxt, 511, sSize)) > 0 ) {
			if ( readTxt[0] == ';' || ( readTxt[0] == '/' && readTxt[1] == '/' ) )
				continue
			parse(readTxt, mapcfg[0], 63, mapcfg[1], 63, mapcfg[2], 63, mapcfg[3], 63)
			if(equali(mapcfg[0], mapname)) {
				write_file(filename,text,currentLine-1)
				break
			}
		}
		if(fileLine == 0)
			write_file(filename,text,-1)
	}
	else
		write_file(filename,text,-1)
	
	client_print(id,print_chat,"[KickBall] Created Ball Spawn [%s] , restart map to activate.",text)
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public ResetHUD(id)
	goaldied[id] = 0
//-----------------------------------------------------------------------------------------------------------------
public plugin_modules(){
	require_module("engine")
	require_module("fakemeta")
	require_module("ns")
}
//-----------------------------------------------------------------------------------------------------------------
public handle_say(id) {
	if(is_mvm() && is_kickball > 0) {
		new said[192]
		read_args(said,192)
		remove_quotes(said)
		if( (containi(said, "kick") != -1) )
			kickball_help(id)
	}
	return PLUGIN_CONTINUE
}
//-----------------------------------------------------------------------------------------------------------------
public kickball_help(id) {
	client_print(id,print_chat,"[KickBall] - Kickball Plugin by: OneEyed ^n")
	client_print(id,print_chat,"[KickBall] - To kick, open console and type: bind key ^"kickball^"^n")
}
//-----------------------------------------------------------------------------------------------------------------
public client_disconnect(id) {
	if(is_mvm()) {
		madesteal[id] = 0
		scored[id] = 0
		madeassist[id] = 0
		madekill[id] = 0
	}
}
//-----------------------------------------------------------------------------------------------------------------
public client_connect(id) {
	if(is_mvm()) {
		madesteal[id] = 0
		scored[id] = 0
		madeassist[id] = 0
		madekill[id] = 0
	}
}
//-----------------------------------------------------------------------------------------------------------------
public gameStart(id) {
	if(get_cvar_num("amx_ball") != 1)
		return PLUGIN_HANDLED
	remove_task(7654321)
	new Float:cdTime = get_cvar_float("mp_countdowntime") * 35
	set_task( cdTime, "SetupRound",123456)
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public EndofRound()
	if(is_valid_ent(aball) && get_cvar_num("amx_ball") == 1 && is_mvm())
		remove_entity(aball)
//-----------------------------------------------------------------------------------------------------------------
public SetupRound(id) {
	score[0] = 0
	score[2] = 0
	topscored = 0
	highscored = 0
	killedcc = 0
	highsteal = 0
	topsteal = 0
	topassist = 0
	highassist = 0
	topdist = 0
	highdist = 0
	topkill = 0
	highkill = 0
	someoneScored = 0
	#if defined DANCER
		if(is_valid_ent(dancerCreated))
			remove_entity(dancerCreated)
		dancerCreated = 0
	#endif
	for(new x=1;x<=maxplayers;x++) {
		scored[x] = 0
		madesteal[x] = 0
		madeassist[x] = 0
		madekill[x] = 0
		if(!is_user_connected(x)) continue
		client_cmd(x,"spk %s", prepare)
	}
	set_task(0.3,"draw",7654321,"",0,"b")
	createball()
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public draw() {
	if(killedcc == 1)
	
		set_hudmessage(200, 100, 200, -1.10, 0.65, 0, 1.0, 180.0, 0.1, 0.1, HUD_CHANNEL)
	
	if(score[0] >= get_cvar_num("kickball_score") || score[2] >= get_cvar_num("kickball_score")) {
		
		//Run our Top Stat Checker (runs once)
		if(killedcc != 1)
			calculateStats()
		
		//Display Winning Team & Awards
		displayWinnerAwards()
		
		return PLUGIN_HANDLED
	}
	on_fire()
	//Display thats shown during kickball play.
	set_hudmessage(20, 255, 20, -1.10, 0.30, 0, 1.0, 180.0, 0.1, 0.1, HUD_CHANNEL)
	format(scoreboard,1024,"         %s^n         %s^n^n^n^n^n^n^n^n^n^n^n^n^n^n^n^n         %s^n                  %s %i  |  %s %i ^n                                  %i %s",temp1,temp2,info[0],info[1],score[0],info[2],score[2],get_cvar_num("kickball_score"),info[3])
	show_hudmessage(0,"%s",scoreboard)
	
	if(score[0] >= get_cvar_num("kickball_score") || score[2] >= get_cvar_num("kickball_score")) return PLUGIN_HANDLED	
	
	// Check if Enemy is in Goal Range (to dmg them)
	checkGoalRange()
	// Check for ball being in Lava/Slime or if user disconected or changed team, to respawn it back to middle.
	is_ball_valid()
	
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public powerUp(ids[]) {
	new id = ids[0]
	if(powerMeter == 1) {
	  	if(powerAmt >= 999.0)	
	  		meterD = 1
	  	else if(powerAmt <= 0.0) 
	  		meterD = 0

	  	if(!meterD)	
	  		powerAmt += 99.9
	  	else if(meterD)
	  		powerAmt -= 99.9
	  		
		if(powerAmt <= 0.0)
			set_pev(id,pev_fuser1,0.1)
		else
			set_pev(id,pev_fuser1,powerAmt)
	}
	else {
		message_begin(MSG_ONE,gmsgProgress,{0,0,0},id)
		write_short(-1)
		write_byte(-1)
		message_end()
		remove_task(808)
	}
}
public kickBall(id) {
	if(id == ballowner) {
		if(!powerMeter && get_cvar_num("kickball_meter")) {
			powerMeter = 1
			set_pev(id,pev_fuser1,0.0)
			powerAmt = 0.0
			meterD = 0
			message_begin(MSG_ONE,gmsgProgress,{0,0,0},id)
			write_short(id)
			write_byte(1)
			message_end()
			new args[1]
			args[0] = id
			set_task(0.1,"powerUp",808,args,1,"b")
			return PLUGIN_HANDLED
		}
		
		new team = pev(id,pev_team)
		//Put Ball in front before kicking
		ball_infront(id)
		//Give it some lift
		testorigin[2] -= 5
		  
		//Check Make sure our ball isnt inside a wall before kicking		
		new Float:ballF[3]
		new Float:ballR[3]
		new Float:ballL[3]
		new Float:ballB[3]
		new Float:ballTR[3]
		new Float:ballTL[3]
		for(new x=0;x<3;x++) {
			ballF[x] = testorigin[x]
			ballR[x] = testorigin[x]
			ballL[x] = testorigin[x]
			ballB[x] = testorigin[x]
			ballTR[x] = testorigin[x]
			ballTL[x] = testorigin[x]
		}
		ballF[1] = ballF[1] + 25.0
		ballR[0] = ballR[0] + 22.0
		ballL[0] = ballL[0] - 22.0
		ballTL[0] = ballTL[0] - 22
		ballTL[1] = ballTL[1] + 22
		ballTR[0] = ballTR[0] + 22
		ballTR[1] = ballTR[1] + 22
		if(point_contents(testorigin) == -1 && point_contents(ballF) == -1 && point_contents(ballR) == -1 && point_contents(ballL) == -1 && point_contents(ballB) == -1 && point_contents(ballTR) == -1 && point_contents(ballTL) == -1) {
			new Float:ballorig[3]
			entity_get_vector(id,EV_VEC_origin,ballorig)
			new kickVel
			if(get_cvar_num("kickball_meter"))
				kickVel = floatround(powerAmt) + floatround(get_cvar_num("kickball_kick") / 0.25)
			else
				kickVel = get_cvar_num("kickball_kick")
			velocity_by_aim(id,kickVel, velocity)
			for(new x=0;x<3;x++)
				distorig[0][x] = floatround(ballorig[x])
			
			/////////////////////WRITE ASSIST CODE HERE IF NEEDED///////////
			if ( iassist[ 0 ] == team ) {
				if ( iassist[ team ] == 15 ) {
					iassist[ team ] = 0
				}
			}
			else {
				// clear the assist list
				for ( new ind = 0; ind < 16; ind++ )
					assist[ ind ] = 0
				// clear the assist index
				iassist[ team ] = 0
				// set which team to track
				iassist[ 0 ] = team
			}
			assist[ iassist[ team ]++ ] = id
			/////////////////////WRITE ASSIST CODE HERE IF NEEDED///////////
			ballowner = 0
			entity_set_origin(aball,testorigin)
			set_pev(aball,pev_velocity,velocity)
			
			emit_sound(aball, CHAN_ITEM, kicked, 1.0, ATTN_NORM, 0, PITCH_NORM)
			glow(id,0,0,0,0)
			new aname[64]
			get_user_name(id,aname,63)
			if(pev(bholder,pev_team) == 1) {
				remove_task(3333)
				set_task(4.0,"eraser",3333) 
				format(temp1,63,"Blue Team [%s] kicked the ball!",aname)
			}
			if(pev(bholder,pev_team) == 3) {
				remove_task(3333)
				set_task(4.0,"eraser",3333)
				format(temp1,63,"Red Team [%s] kicked the ball!",aname)
			}
			if(get_cvar_num("kickball_meter"))
				powerMeter = 0
		}
	
	}
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public createball() {
	new Float:spawnorig[3]
	new Float:v[3]
	new teamcc

	new kickball = find_ent_by_tname(0, "kickball")
	entity_get_vector(kickball, EV_VEC_origin,spawnorig)
  			
	spawnorig[2] += 50

	new entity = create_entity("info_target")
	if (entity) {
		
		entity_set_string(entity,EV_SZ_classname,"PwnBall")
		entity_set_model(entity, ball)
		
		set_pev(entity,pev_solid,SOLID_BBOX)
		set_pev(entity,pev_movetype,MOVETYPE_BOUNCE)
		//entity_set_int(entity,EV_INT_solid,SOLID_BBOX)
		//entity_set_int(entity,EV_INT_solid,MOVETYPE_BOUNCE)
		
		new Float:MinBox[3]
		new Float:MaxBox[3]
		MinBox[0] = -6.0
		MinBox[1] = -6.0
		MinBox[2] = 0.0
		MaxBox[0] = 6.0
		MaxBox[1] = 6.0
		MaxBox[2] = 12.0
		
		entity_set_vector(entity, EV_VEC_mins, MinBox)
		entity_set_vector(entity, EV_VEC_maxs, MaxBox)
		
		entity_set_origin(entity, spawnorig)
		pev(entity,pev_velocity,v)
		bholder = 0
		ballowner = 0//set_pev(entity,pev_owner,0)
		set_pev(entity,pev_team,0)
		
		glow(entity,ballcolor[0],ballcolor[1],ballcolor[2],10)
		
		teamcc = getTeamComm(1)
		set_pev(teamcc,pev_takedamage,0.0)
		glow(teamcc,team1color[0],team1color[1],team1color[2],1)
			
		teamcc = getTeamComm(3)
		set_pev(teamcc,pev_takedamage,0.0)
		glow(teamcc,team2color[0],team2color[1],team2color[2],1)
		
		entity_set_float(entity,EV_FL_framerate,0.0)
		entity_set_int(entity,EV_INT_sequence,0)
		//entity_set_int(entity,EV_INT_effects,EF_BRIGHTLIGHT)
	}
	//save our entity ID to aball variable
	aball = entity
	entity_set_float(entity,EV_FL_nextthink,halflife_time() + 0.01)
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public ball_think() {
	if(get_cvar_num("kickball_knife") == 1)
		for(new i=1;i<=maxplayers;i++)
			if(is_user_connected(i) && is_user_alive(i) && pev(i,pev_team) != 0)
				engclient_cmd(i,"weapon_knife")
	if(score[0] >= get_cvar_num("kickball_score") || score[2] >= get_cvar_num("kickball_score"))
		return PLUGIN_HANDLED
	
	if(is_valid_ent(aball)) {
		if(ballowner > 0) {
			
			entity_get_vector(ballowner, EV_VEC_origin,testorigin)
			entity_get_vector(ballowner, EV_VEC_velocity,velocity)
			//pev(ballowner,pev_velocity,velocity)
			
			if(!is_user_alive(ballowner)) {
				testorigin[2] += 10
				entity_set_origin(aball, testorigin)
				new tname[32]
				get_user_name(ballowner,tname,31)
				if(pev(ballowner,pev_team) == 1) {
					remove_task(3333)
					set_task(6.0,"eraser",3333)
					format(temp1,63,"Blue Team [%s] dropped the ball!",tname)
				}
				else if(pev(ballowner,pev_team) == 3) {
					remove_task(3333)
					set_task(6.0,"eraser",3333) 
					format(temp1,63,"Red Team [%s] dropped the ball!",tname)
				}
				//remove glow of owner and set ball velocity really really low
				glow(ballowner,0,0,0,0)
				
				for(new x=0;x<3;x++)
					velocity[x] *= 0.4
	
				set_pev(aball,pev_velocity,velocity)
				ballowner = 0
				if(get_cvar_num("kickball_meter"))
					powerMeter = 0
				entity_set_float(aball,EV_FL_nextthink,halflife_time() + 0.01)
				return PLUGIN_HANDLED
			}
			
			if(entity_get_int(aball,EV_INT_solid) != SOLID_TRIGGER)
				entity_set_int(aball, EV_INT_solid, SOLID_TRIGGER)
				
			//Put ball in front of player
			ball_infront(ballowner)
			
			for(new i=0;i<3;i++)	
				velocity[i] = 0.0
			//Add lift to z axis
			if(get_entity_flags(ballowner) & FL_DUCKING)
				testorigin[2] -= 18
			else
				testorigin[2] -= 28
			//set its origin and remove its velocity
	 		set_pev(aball,pev_velocity,velocity)
	  		entity_set_origin(aball,testorigin)
		}
		else {
			if(entity_get_int(aball,EV_INT_solid) != SOLID_BBOX)
				entity_set_int(aball, EV_INT_solid, SOLID_BBOX)			
		}
			
	}
	
	//Run think, so it does all this again. (runs through engine, its so fast!)
	entity_set_float(aball,EV_FL_nextthink,halflife_time() + 0.01)
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public touchPlayer(pToucher, pTouched) {
	if(score[0] >= get_cvar_num("kickball_score") || score[2] >= get_cvar_num("kickball_score")) {
		return PLUGIN_HANDLED
	}
	if(pev(pTouched,pev_team) == 0 || ballowner > 0) {
		return PLUGIN_HANDLED
	}

	if(resetting == 1) {
		resetting = 0
		remove_task(55555)
	}
	new aname[64]
	get_user_name(pTouched,aname,63)
	if(pev(bholder,pev_team) != pev(pTouched,pev_team) && bholder != 0){
		pev(aball,pev_velocity,vd)
		if((vd[0] < -500.0 || vd[0] > 500.0) || (vd[1] < -500.0 || vd[1] > 500.0)) {
			for(new x=0;x<3;x++)
				vd[x] = velocity[x]
			new rnd = random_num(0,100)
			if(rnd > get_cvar_num("kickball_dmgpct")) {
				new Float:dodmg
				dodmg = ((vd[0] + vd[1]) * get_cvar_float("kickball_dmg"))
				if(dodmg < 0.0)
					dodmg *= -1.0
				dodmg += random_num(-20,40)
				
				client_print(0,print_chat,"%s got smacked for %i damage.",aname,floatround(dodmg))
				
				set_msg_block(gmsgDeathMsg,BLOCK_ONCE)
				fakedamage(pTouched,"tracktrain",dodmg,1)
				set_msg_block(gmsgDeathMsg,BLOCK_NOT)

				if(!is_user_alive(pTouched)) {
					message_begin(MSG_ALL, gmsgDeathMsg)
					write_byte(bholder)
					write_byte(pTouched)
					write_string("tracktrain")
					message_end()
					
					set_user_frags(bholder, get_user_frags(bholder)+1)
					madekill[bholder]++
					ns_set_exp(bholder,ns_get_exp(bholder)+100.0)
					client_print(pTouched,print_chat,"[Kickball] You were killed by the ball going to fast!")
					client_print(bholder,print_chat,"[Kickball] You gained 100xp for killing with ball!")
				}
				else {
					new Float:pushVel[3]
					pushVel[0] = velocity[0] * random_float(5.0,8.0)
					pushVel[1] = velocity[1] * random_float(5.0,8.0)
					pushVel[2] = velocity[2] + ((velocity[2] < 0)?random_float(-3000.0,-1500.0):random_float(1500.0,3000.0))
					entity_set_vector(pTouched,EV_VEC_velocity,pushVel)
				}
				for(new x=0;x<3;x++)
					velocity[x] = (velocity[x] * random_float(0.01,0.9))
				set_pev(pToucher,pev_velocity,velocity)
				return PLUGIN_HANDLED
			}
		}
		
		madesteal[pTouched]++
		client_print(pTouched,print_chat,"[Kickball] You gained 50xp for making a steal!")
		ns_set_exp(pTouched,ns_get_exp(pTouched)+50.0)
		if(random_num(1,5) == 5) {
			for(new x=1;x<=maxplayers;x++)
				if(is_user_connected(x))
					client_cmd(x,"spk %s",pussy)
		}
	}
	
	get_user_name(pTouched,aname,63)
	//for(new x=1;x<=maxplayers;x++)
	//	if(is_user_connected(x))
	emit_sound(aball, CHAN_ITEM, gotball, 1.0, ATTN_NORM, 0, PITCH_NORM)
	//client_cmd(x,"play %s", gotball)
	if(pev(pTouched,pev_team) == 1)
		format(temp1,63,"Blue Team [%s] has the ball!",aname)
	else if(pev(pTouched,pev_team) == 3)
		format(temp1,63,"Red Team [%s] has the ball!",aname)
	
	bholder = pTouched
	ballowner = pTouched
	set_pev(pToucher,pev_team,pev(pTouched,pev_team))

	//Glow Player who has ball their team color
	if(pev(pTouched,pev_team) == 1) {
		glow(pTouched,team1color[0],team1color[1],team1color[2],1)
		beam(team1color)
	}
	else {
		glow(pTouched,team2color[0],team2color[1],team2color[2],1)
		beam(team2color)
	}
	return PLUGIN_HANDLED
}
public on_fire()
{
	new rx, ry, rz, Float:forig[3], forigin[3]
	new id = aball
	//new killer = args[1]
	
	rx = random_num(-5, 5)
  	ry = random_num(-5, 5)
  	rz = random_num(-5, 5)
	entity_get_vector(id, EV_VEC_origin, forig)
	for(new x=0;x<3;x++)
		forigin[x] = floatround(forig[x])

	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(17)
	write_coord(forigin[0] + rx)
	write_coord(forigin[1] + ry)
	write_coord(forigin[2] + 10 + rz)
	write_short(Burn_Sprite)
	write_byte(5)
	write_byte(100)
	message_end()
}
public beam(colors[]) {
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(22); // TE_BEAMFOLLOW
	write_short(aball); // ball
	write_short(beamspr); // laserbeam
	write_byte(10); // life
	write_byte(5); // width
	write_byte(colors[0]); // R
	write_byte(colors[1]); // G
	write_byte(colors[2]); // B
	write_byte(255); // brightness
	message_end();	
}
//-----------------------------------------------------------------------------------------------------------------
public touchCC(pToucher, pTouched) { 
	if(someoneScored == 1) return PLUGIN_HANDLED
	if (pev(pToucher,pev_team) != pev(pTouched,pev_team) && ballowner == 0) {
		someoneScored = 1
		new aname[64]
		new Float:ccorig[3], teamcc
		new ccorig2[3]
		if(pev(pToucher,pev_team) == 1)
			teamcc = getTeamComm(3)
		else
			teamcc = getTeamComm(1)
		entity_get_vector(teamcc, EV_VEC_origin,ccorig)
		for(new l=0;l<3;l++) 
			ccorig2[l] = floatround(ccorig[l])
		flameWave(ccorig2)
		get_user_name(bholder,aname,63)
		
		ns_set_score(bholder,ns_get_score(bholder)+10)
		set_user_frags(bholder, get_user_frags(bholder)+10)
		if(pev(pToucher,pev_team) == 1) {
			remove_task(4444)
			set_task(6.0,"eraser",4444) 
			format(temp2,63,"%s SCORED for Blue Team!!",aname)
		}
		if(pev(pToucher,pev_team) == 3) {
			remove_task(4444)
			set_task(6.0,"eraser",4444) 
			format(temp2,63,"%s SCORED for Red Team!!",aname)
		}
		for(new i=1;i<=maxplayers;i++)
			if(is_user_connected(i)) {
				client_cmd(i, "spk %s", distress)
			}
		for(new l=0;l<3;l++) 
			distorig[1][l] = floatround(ccorig[l])
		
		new distshot = (get_distance(distorig[0],distorig[1])/12)
		new Float:gainedxp = distshot * 1.5
		client_print(bholder,print_chat,"[Kickball] You gained %i xp for making a %i ft GOAL !",floatround(gainedxp),distshot)
		ns_set_exp(bholder,ns_get_exp(bholder)+gainedxp)
		#if defined DANCER
			if(!dancerCreated)
				createDancer(getTeamComm(pev(bholder,pev_team)))
			else
				moveDancer(getTeamComm(pev(bholder,pev_team)))
		#endif
		if(distshot > highdist) {
			highdist = distshot
			topdist = bholder
		}
		/////////////////////ASSIST CODE HERE///////////
		
		new assisters[4] = { 0, 0, 0, 0 }
		new iassisters = 0
		new team = pev( bholder, pev_team )
		new ilastplayer = iassist[ team ]
		
		// We just need the last player to kick the ball
		// 0 means it has passed 15 at least once
		if ( ilastplayer == 0 )
			ilastplayer = 15
		else
			ilastplayer--
		
		if ( assist[ ilastplayer ] != 0 ) {
			for ( new i = 0; i < 16; i++ ) {
				// Stop if we've already found 4 assisters
				if ( iassisters == 2 )
					break;
				new playerid = assist[ i ]
				// Skip if player is invalid
				if ( playerid == 0 )
					continue;
				// Skip if kicker is counted as an assister
				if ( playerid == assist[ ilastplayer ] )
					continue;

				new bool:canadd = true
				// Loop through each assister value
				for ( new x = 0; x < 3; x++ )
					// make sure we can add them
					if ( playerid == assisters[ x ] ) {
						canadd = false;
						break;
					}
		
				// Skip if they've already been added
				if ( canadd == false )
					continue;
				// They didn't kick the ball last, and they haven't been added, add them
				assisters[ iassisters++ ] = playerid
			}
			// This gives each person an assist, xp, and prints that out to them
			for ( new c = 0; c < iassisters; c++ ) {
				new pass = assisters[ c ]
				madeassist[ pass ]++
				ns_set_exp( pass, ns_get_exp( pass ) + 250.0 )
				client_print( pass, print_chat, "[Kickball] You gained 250xp for making an assist!" )
			}
		}
		iassist[ 0 ] = 0
		/////////////////////ASSIST CODE HERE///////////
			
		score[pev(pToucher,pev_team)-1]++
		scored[bholder]++
		
		if(score[0] >= get_cvar_num("kickball_score") || score[2] >= get_cvar_num("kickball_score")) {
			remove_entity(aball)
			return PLUGIN_HANDLED
		}
		new Float:hideorig[3]
		for(new g=0;g<3;g++)
			hideorig[g] = -9500.0
		entity_set_origin(aball, hideorig)
		
		set_task(2.5,"teamScored",1111) 
	   }
	else if(pev(pToucher,pev_team) == pev(pTouched,pev_team)) {
		respawnBall(pev(pToucher,pev_team))
		client_print(bholder,print_chat,"You cannot kick ball to your command chair!!")
	}
	return PLUGIN_HANDLED	
}
//-----------------------------------------------------------------------------------------------------------------
public touchWorld(pToucher, pTouched) {
	if(score[0] >= get_cvar_num("kickball_score") || score[2] >= get_cvar_num("kickball_score"))
		return PLUGIN_HANDLED
	
	if(resetting != 1 && ballowner == 0) {
		resetting = 1
		set_task(get_cvar_float("kickball_reset"),"clearBall",55555)
	}
	new Float:v[3]
	pev(pToucher,pev_velocity,v)
	if((v[0] < -30 || v[0] > 30) || ( v[1] < -30 || v[1] > 30)) {
		v[0] = (v[0] * 0.85)
		v[1] = (v[1] * 0.85)
		v[2] = (v[2] * 0.85)
		set_pev(pToucher,pev_velocity,v)
		emit_sound(pToucher, CHAN_ITEM, ballhit, 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public KnifeDmg(id)
{
	if(get_cvar_num("kickball_knife") == 0)
		return PLUGIN_HANDLED
	new attacker_weapon_id = entity_get_edict(id,EV_ENT_dmg_inflictor)
	new attacker = entity_get_edict(attacker_weapon_id,EV_ENT_owner)
	new attacker_weapon[51]
	entity_get_string(attacker_weapon_id, EV_SZ_classname,attacker_weapon,50)
	if ( entity_get_float(id, EV_FL_health) >= 1.0 && equali(attacker_weapon,"weapon_knife") )
		Knockback(id,attacker,1.2)
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
Knockback(id,attacker,Float:mult){
	new Float:attacker_ang[3]
	new booster = random_num(200, 400)
	
	//if(attacker > 0) {
	velocity_by_aim(attacker, 1, attacker_vec[id])
	vector_to_angle(attacker_vec[id], attacker_ang)
	
	attacker_ang[0] += random_num(-40,40)
	attacker_ang[1] += random_num(-40,40)
	attacker_ang[2] += random_num(0,30)
	
	angle_vector(attacker_ang,1,attacker_vec[id])
	
	attacker_vec[id][0] *= booster*mult
	attacker_vec[id][1] *= booster*mult
	attacker_vec[id][2] *= random_num(0,50)*mult
	
	set_user_velocity(id, attacker_vec[id])
}
//-----------------------------------------------------------------------------------------------------------------
public calculateStats() {
	for(new k=1;k<=maxplayers;k++) {
		if(!is_user_connected(k)) continue
		if(scored[k] > highscored) {
			highscored = scored[k]
			topscored = k
		}
		if(madesteal[k] > highsteal) {
			highsteal = madesteal[k]
			topsteal = k
		}
		if(madeassist[k] > highassist) {
			highassist = madeassist[k] 
			topassist = k
		}
		if(madekill[k] > highkill) {
			highkill = madekill[k]
			topkill = k	
		}
	} 
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public destroyEnemyCC(team) {
	if(killedcc != 1) {
		new teamcc = getTeamComm(team)
		set_pev(teamcc,pev_takedamage,1.0)
		fakedamage(teamcc,"Blasphemy",entity_get_float(teamcc, EV_FL_health),1)
		killedcc = 1
	}
}
//-----------------------------------------------------------------------------------------------------------------
public displayWinnerAwards()
{
	//If NO steal/assist was made, set name to Nobody
	if(killedcc != 1) {
		if(topsteal == 0)
			format(tsname,31,"Nobody")
		else
			get_user_name(topsteal,tsname,31)
		if(topassist == 0)
			format(maname,31,"Nobody")
		else
			get_user_name(topassist,maname,31)
		if(topkill == 0)
			format(kiname,31,"Nobody")
		else
			get_user_name(topkill,kiname,31)
		//Grab names of Top Distance / Scored players.
		get_user_name(topdist,mdname,31)
		get_user_name(topscored,sname,31)
	}
	set_hudmessage(250, 130, 20, -1.10, 0.20, 0, 1.0, 180.0, 0.1, 0.1, HUD_CHANNEL)
	
	//Display our Winning Team, with Awards, and kill Comm Chair of opponent
	if(score[0] > score[2]) {
		show_hudmessage(0,"                Blue Team WINS!! ^n^n                    --Awards--^n        -Most Goals:(%i) By: %s  ^n        -Most Steals:(%i) By: %s  ^n        -Most Assists:(%i) By: %s  ^n        -Most Kickball Kills:(%i) By: %s  ^n        -Furthest Goal:(%ift) By: %s", highscored, sname, highsteal, tsname, highassist, maname, highkill, kiname, highdist, mdname)
		destroyEnemyCC(3)
	}
	else {
		show_hudmessage(0,"                Red Team WINS!! ^n^n                    --Awards--^n        -Most Goals:(%i) By: %s  ^n        -Most Steals:(%i) By: %s  ^n        -Most Assists:(%i) By: %s  ^n        -Most Kickball Kills:(%i) By: %s  ^n        -Furthest Goal:(%ift) By: %s", highscored, sname, highsteal, tsname, highassist, maname, highkill, kiname, highdist, mdname)
		destroyEnemyCC(1)
	}
}
//-----------------------------------------------------------------------------------------------------------------
public checkGoalRange() //Check if enemy in range of comm chair, if so start dmging them
{						//if they die, give the entire team a bit of xp, (since the goalsafety can be abused by enemy)
	if(get_cvar_num("kickball_knife") == 1) {
		new cc1 = getTeamComm(1)
		new cc2 = getTeamComm(3)
		for(new x=1;x<=maxplayers;x++)
			if(pev(x,pev_team) == 1 && entity_range(x,cc2) <= get_cvar_num("kickball_goalsafety"))
				if(ns_get_class(x) == CLASS_HEAVY) {
					fakedamage(x,"weapon_nuke",50.0,1)
					if(!is_user_alive(x) && goaldied[x] == 0) {
						increaseTeamXP(3, 50.0)
						goaldied[x] = 1
					}
				}
				else {
					fakedamage(x,"weapon_nuke",15.0,1)
					if(!is_user_alive(x) && goaldied[x] == 0){
						increaseTeamXP(3, 30.0)
						goaldied[x] = 1
					}
				}
			else if(pev(x,pev_team) == 3 && entity_range(x,cc1) <= get_cvar_num("kickball_goalsafety"))
				if(ns_get_class(x) == CLASS_HEAVY) {
					fakedamage(x,"weapon_nuke",50.0,1)
					if(!is_user_alive(x) && goaldied[x] == 0){
						increaseTeamXP(1, 50.0)
						goaldied[x] = 1
					}
				}
				else {
					fakedamage(x,"weapon_nuke",15.0,1)
					if(!is_user_alive(x) && goaldied[x] == 0){
						increaseTeamXP(1, 30.0)
						goaldied[x] = 1
					}
				}
		
	}
	return PLUGIN_HANDLED
}
public increaseTeamXP(team, Float:amt) {
	for(new s=1;s<=maxplayers;s++)
		if(pev(s,pev_team) == team && is_user_connected(s))
			ns_set_exp(s, ns_get_exp(s) + amt)
}
//-----------------------------------------------------------------------------------------------------------------
public is_ball_valid() {
	new Float:borig[3]
	entity_get_vector(aball, EV_VEC_origin,borig)
	if((point_contents(borig) == -5 || point_contents(borig) == -4) || (!is_user_connected(ballowner) && ballowner > 0))
		respawnBall(10) // Respawn at middle
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public ball_infront(id) {
	new Float:nOrigin[3]
	new Float:vAngles[3] // plug in the view angles of the entity
	new Float:vReturn[3] // to get out an origin fDistance away
	entity_get_vector(aball,EV_VEC_origin,testorigin)
	entity_get_vector(id,EV_VEC_origin,nOrigin)
	entity_get_vector(id,EV_VEC_v_angle,vAngles)
	
	vReturn[0] = floatcos( vAngles[1], degrees ) * 40.0
	vReturn[1] = floatsin( vAngles[1], degrees ) * 40.0
	
	vReturn[0] += nOrigin[0]
	vReturn[1] += nOrigin[1]
	
	testorigin[0] = vReturn[0] 
	testorigin[1] = vReturn[1]
	testorigin[2] = nOrigin[2]
	new Float:ang[3]
	//pev(id,pev_angles,ang)
	//set_pev(aball,pev_angles,ang)
	entity_get_vector(id,EV_VEC_angles,ang)
	ang[0] = 0.0
	ang[1] -= 90.0
	ang[2] = 0.0
	entity_set_vector(aball,EV_VEC_angles,ang)
}
//-----------------------------------------------------------------------------------------------------------------
public respawnBall(team) {
	new Float:bv[3]
	bv[2] = -50.0
	for(new i=1;i<=maxplayers;i++)
		if(is_user_connected(i))
			glow(i,0,0,0,0)
	if(team == 10)
	{
		format(temp1,63,"Ball RESPAWNED at the middle!")
		new Float:spawnorig[3]
		new kickball = find_ent_by_tname(0, "kickball")
		entity_get_vector(kickball, EV_VEC_origin,spawnorig)	
		spawnorig[2] += 20
 		
 		set_pev(aball,pev_velocity,bv)
		entity_set_origin(aball,spawnorig)
		bholder = 0
		ballowner = 0
		set_pev(aball,pev_team,0)
		return PLUGIN_HANDLED
	}
	new teamcc
	new Float:ccorig[3]
	if(team == 1)
		teamcc = getTeamComm(team)
	else 
		teamcc = getTeamComm(3)
	entity_get_vector(teamcc, EV_VEC_origin,ccorig)
 	
 	bv[2] = -50.0
	ccorig[2] += 10.0
	ccorig[0] += 80.0
	entity_set_origin(aball, ccorig)
	set_pev(aball,pev_velocity,bv)
	bholder = 0
	ballowner = 0
	set_pev(aball,pev_team,0)
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public teamScored() {
	if(scoreEvent == 0) {
		//Respawn Everyone ( mostly alive people :| )
		respawnTeams()
		for(new x=1;x<=maxplayers;x++) {
			if(!is_user_connected(x)) continue
			client_cmd(x, "spk %s", tomes)
			ns_set_speedchange(x, -5000)
		}
		if(scored[bholder] > 0) {
			new r = random_num(1,5)
			for(new a=1;a<=maxplayers;a++) {
				if(is_user_connected(a)) {
					switch(r) {
						case 1: client_cmd(a, "spk %s", amaze)
						case 2: client_cmd(a, "spk %s", laugh)
						case 3: client_cmd(a, "spk %s", perfect)
						case 4: client_cmd(a, "spk %s", diebitch)
						case 5: client_cmd(a, "spk %s", bday)
					}
				}
			}
		}
		scoreEvent = 1
		//Respawn ball at middle
		respawnBall(10)
		//Run Team Scored Event
		set_task(2.0,"teamScored",1111)
		return PLUGIN_HANDLED 
	}
	else if(scoreEvent == 1) {
		for(new x=1;x<=maxplayers;x++) {
			if(!is_user_connected(x)) continue
			ns_set_speedchange(x)
		}
		someoneScored = 0
		scoreEvent = 0
	}
	return PLUGIN_HANDLED 
}
//-----------------------------------------------------------------------------------------------------------------
public respawnTeams() {
	for(new i=1;i<=maxplayers;i++) {
		if(!is_user_connected(i)) continue
		glow(i,0,0,0,0)
		//if(!is_user_alive(i)) {
		//	entity_set_int(i, EV_INT_playerclass, 5) // spectate
		//	now()
		//}
		if(pev(i,pev_team) != 0 && is_user_alive(i)) {
			DispatchSpawn(i)
			entity_set_float(i, EV_FL_health, 100.0)
			if(entity_get_float(i, EV_FL_armorvalue) < 30.0)
				entity_set_float(i, EV_FL_armorvalue, 30.0)
				
			if(get_cvar_num("kickball_knife") == 1)	continue
			
			new ammo_reserve, dummy
			new weap_id = get_user_weapon(i,dummy,ammo_reserve)
			if ( weap_id == 14 ){		// Pistol
				if ( ammo_reserve < 11 ){
					ns_give_item(i, "item_genericammo")
				}
			}else if ( weap_id == 15 ){	// LMG
				if ( ammo_reserve < 51 ){
					ns_give_item(i, "item_genericammo")
				}
			}else if ( weap_id == 16 ){	// Shotgun
				if ( ammo_reserve < 9 ){
					ns_give_item(i, "item_genericammo")
					ns_give_item(i, "item_genericammo")
				}
			}else if ( weap_id == 17 ){	// HMG
				if ( ammo_reserve < 100 ){
					ns_give_item(i, "item_genericammo")
					ns_give_item(i, "item_genericammo")
				}
			}else if ( weap_id == 20 ){	// GL
				if ( ammo_reserve < 12 ){
					ns_give_item(i, "item_genericammo")
				}
				
			}
		}
	}
}
//-----------------------------------------------------------------------------------------------------------------
public clearBall(id)
	respawnBall(10)
//-----------------------------------------------------------------------------------------------------------------
public block_jetpack(id)	//Message for blocked impulses.
{
	if(get_cvar_num("kickball_jetpack") == 1)
		return PLUGIN_CONTINUE
	if ((get_gametime() - g_lastmessage[id]) > MESSAGE_DELAY) {
		ns_popup(id, "No Jetpack Allowed.")
		g_lastmessage[id] = get_gametime()
	}
	set_pev(id, pev_impulse, 0)
	return PLUGIN_HANDLED
}

public block_other(id)	//Message for blocked impulses.
{
	if(get_cvar_num("kickball_knife") == 0)
		return PLUGIN_CONTINUE
	if ((get_gametime() - g_lastmessage[id]) > MESSAGE_DELAY) {
		ns_popup(id, "Thats not allowed at this time.")
		g_lastmessage[id] = get_gametime()
	}
	set_pev(id, pev_impulse, 0)
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public getTeamComm(team) {
	for(new x=1;x<=ns_get_build("team_command",1,0);x++)
		if(pev(ns_get_build("team_command",1,x),pev_team) == team)
			return ns_get_build("team_command",1,x)
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
// Erase our current temps (used for ball events)
public eraser(num) {
	if(num == 3333)
		format(temp1,63,"")
	if(num == 4444)
		format(temp2,63,"")
	return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public glow(id, r, g, b, on) {
	if(on == 1) {
		set_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 255)
		set_pev(id,pev_renderamt,2.0)
	}
	else if(!on) {
		set_rendering(id, kRenderFxNone, r, g, b,  kRenderNormal, 255)
		set_pev(id,pev_renderamt,2.0)
	}
	else if(on == 10) {
		set_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 255)
		set_pev(id,pev_renderamt,50.0)
	}
}
//-----------------------------------------------------------------------------------------------------------------
public flameWave(myorig[3]) {
    message_begin(MSG_ALL,SVC_TEMPENTITY,myorig) 
    write_byte( 21 ) 
    write_coord(myorig[0]) 
    write_coord(myorig[1]) 
    write_coord(myorig[2] + 16) 
    write_coord(myorig[0]) 
    write_coord(myorig[1]) 
    write_coord(myorig[2] + 500) 
    write_short( fire )
    write_byte( 0 ) // startframe 
    write_byte( 0 ) // framerate 
    write_byte( 15 ) // life 2
    write_byte( 50 ) // width 16 
    write_byte( 10 ) // noise 
    write_byte( 255 ) // r 
    write_byte( 0 ) // g 
    write_byte( 0 ) // b 
    write_byte( 255 ) //brightness 
    write_byte( 1 / 10 ) // speed 
    message_end() 
    
    message_begin(MSG_ALL,SVC_TEMPENTITY,myorig) 
    write_byte( 21 ) 
    write_coord(myorig[0]) 
    write_coord(myorig[1]) 
    write_coord(myorig[2] + 16) 
    write_coord(myorig[0]) 
    write_coord(myorig[1]) 
    write_coord(myorig[2] + 500) 
    write_short( fire )
    write_byte( 0 ) // startframe 
    write_byte( 0 ) // framerate 
    write_byte( 10 ) // life 2
    write_byte( 70 ) // width 16 
    write_byte( 10 ) // noise 
    write_byte( 255 ) // r 
    write_byte( 50 ) // g 
    write_byte( 0 ) // b 
    write_byte( 200 ) //brightness 
    write_byte( 1 / 9 ) // speed 
    message_end() 
    
    message_begin(MSG_ALL,SVC_TEMPENTITY,myorig)
    write_byte( 21 )
    write_coord(myorig[0])
    write_coord(myorig[1])
    write_coord(myorig[2] + 16) 
    write_coord(myorig[0]) 
    write_coord(myorig[1]) 
    write_coord(myorig[2] + 500) 
    write_short( fire )
    write_byte( 0 ) // startframe 
    write_byte( 0 ) // framerate 
    write_byte( 10 ) // life 2
    write_byte( 90 ) // width 16 
    write_byte( 10 ) // noise 
    write_byte( 255 ) // r 
    write_byte( 100 ) // g 
    write_byte( 0 ) // b 
    write_byte( 200 ) //brightness 
    write_byte( 1 / 8 ) // speed 
    message_end() 
    
    //Explosion2 
    message_begin( MSG_BROADCAST,SVC_TEMPENTITY) 
    write_byte( 12 ) 
    write_coord(myorig[0]) 
    write_coord(myorig[1]) 
    write_coord(myorig[2])
    write_byte( 80 ) // byte (scale in 0.1's) 188 
    write_byte( 10 ) // byte (framerate) 
    message_end() 

    //TE_Explosion 
    message_begin( MSG_BROADCAST,SVC_TEMPENTITY,myorig) 
    write_byte( 3 ) 
    write_coord(myorig[0]) 
    write_coord(myorig[1]) 
    write_coord(myorig[2])
    write_short( fire ) 
    write_byte( 65 ) // byte (scale in 0.1's) 188 
    write_byte( 10 ) // byte (framerate) 
    write_byte( 0 ) // byte flags 
    message_end() 

    //Smoke 
    message_begin( MSG_BROADCAST,SVC_TEMPENTITY,myorig) 
    write_byte( 5 ) // 5
    write_coord(myorig[0]) 
    write_coord(myorig[1]) 
    write_coord(myorig[2]) 
    write_short( smoke )
    write_byte( 50 )  // 2
    write_byte( 10 )  // 10
    message_end()
    
    return PLUGIN_HANDLED
}
//-----------------------------------------------------------------------------------------------------------------
public is_mvm() {
	new checkcc = ns_get_build("team_command",0, 0)
	if(checkcc > 1 && ns_is_combat())
		return 1
	return 0
}
//-----------------------------------------------------------------------------------------------------------------
#if defined DANCER
	public createDancer(cc) {
		new entity = create_entity("info_target")
		if (entity) {
			entity_set_string(entity,EV_SZ_classname,"Dancer")
			entity_set_model(entity, dancerm)
	
			entity_set_int(entity,EV_INT_solid,SOLID_BBOX)
			entity_set_int(entity,EV_INT_solid,MOVETYPE_TOSS)
			new Float:MinBox[3]
			new Float:MaxBox[3]
			MinBox[0] = -6.0
			MinBox[1] = -6.0
			MinBox[2] = 0.0
			MaxBox[0] = 6.0
			MaxBox[1] = 6.0
			MaxBox[2] = 12.0
			
			entity_set_vector(entity, EV_VEC_mins, MinBox)
			entity_set_vector(entity, EV_VEC_maxs, MaxBox)
			
			entity_set_float(entity,EV_FL_framerate,1.0)
			entity_set_int(entity,EV_INT_sequence,0)
			entity_set_int(entity,EV_INT_team,0)
			
			dancerCreated = entity
			
			moveDancer(cc)
		}
		return PLUGIN_HANDLED
	}
	
	public moveDancer(cc) {
		new Float:spawnorig[3], Float:ang[3]
		entity_get_vector(cc, EV_VEC_origin,spawnorig)	
		entity_get_vector(cc, EV_VEC_angles, ang)
		spawnorig[2] += 100
		entity_set_origin(dancerCreated, spawnorig)
		entity_set_vector(dancerCreated, EV_VEC_angles,ang)
}
#endif
//-----------------------------------------------------------------------------------------------------------------