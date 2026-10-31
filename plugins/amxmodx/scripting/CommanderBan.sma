/*
Change Log:
0.1 - offshoot of Commander Ban (http://forums.alliedmods.net/showthread.php?p=7941)
0.2 - removed outdated code, cleaned up functions
0.3 - rewrote most of the functions.
0.4 - added round / map bans
0.5 - combined timercode + add ban code
0.6 - added remove all bans function
0.7 - added old cmd_target2 function back to get around adding people who arent connected (why reinvent the wheel?)
0.8 - reworked commbanlist to show banned players
0.9 - added accounce (defined) obeys amx_show_activity
1.0 - fixed adding offline bug. thanks king arthur
1.1 - fix perma ban for people connecting (completly forgot to finish the code Lol)
1.2 - fixed unban display bug./ output print bug fixed.

Usage:
amx_commban      -   <name / steamid> <length of time in minutes> - bans the commander for a specific amount of time. If no time is specified, it defaults to a round ban.  (0 = perma ban, -1 = round ban, -2 = map ban)
amx_communban     -   <name / steamid> - removes ban on the commander
amx_commbanreset     - resets ALL bans (server command only)
amx_commbanlist     - lists all CONNECTED players who are banned.

NOTE: Banning offline players must be done with a steamid and the length MUST be specified. IE: amx_commban STEAM_0:0:682374 0 will ban me.
*/
#include <amxmodx>
#include <amxmisc>
#include <nvault>
#include <ns>

#define PLUGIN "CommanderBan"
#define VERSION "1.2"
#define AUTHOR "Nut"

#define COMMBAN_ACCESS ADMIN_CHAT	//access level needed
#define MAXBANS 64			//max bans needed
#define ANNOUNCEBAN 0			//do you want to announce the bans?

//Class nums used by pev->iuser3 and ScoreInfo
enum {
	IUSER3_READYROOM = 0,
	IUSER3_MARINE,
	IUSER3_JETPACK,
	IUSER3_HEAVY,
	IUSER3_SKULK,
	IUSER3_GORGE,
	IUSER3_LERK,
	IUSER3_FADE,
	IUSER3_ONOS,
	IUSER3_DIGESTING,
	IUSER3_GESTATE,
	IUSER3_DEADMARINE,
	IUSER3_DEADALIEN,
	IUSER3_COMMANDER,
	IUSER3_REINFORCING,
	IUSER3_SPECTATOR
}

#define VAULTNAME "comm_bann"

new gMaxPlayers, gVault, gActivity
new roundBanned[33], mapBanned[33], permBanned[MAXBANS], playerClass[33]

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	if (ns_is_combat()) {
		pause("ad")
	}
	
	register_clcmd("amx_commban","addBan",COMMBAN_ACCESS,"- <name or authid> <length of ban (0=perm -1=round -2=map)>")
	register_clcmd("amx_communban","removeBan",COMMBAN_ACCESS,"- <name or authid> <authid>")
	register_clcmd("amx_commbanlist","listBans",COMMBAN_ACCESS,"- lists people on the server who are currently banned.")
	register_srvcmd("amx_commbanreset","resetBans")

	register_event("GameStatus", "eRoundEnd", "ab", "1=2" )
	register_message(get_user_msgid("ScoreInfo"),"eStatusInfo")
	
	gVault = nvault_open( VAULTNAME )
	if(gVault == INVALID_HANDLE) {
		server_print("[%s]: Error opening nVault file: %s",PLUGIN,VAULTNAME)
		return PLUGIN_HANDLED
	}
	
	gMaxPlayers = get_maxplayers()
	gActivity = get_cvar_num("amx_show_activity")
	
	return PLUGIN_CONTINUE
}

public plugin_end() {
	nvault_close(gVault)
}

public client_connect(id) {
	roundBanned[id] = false
	mapBanned[id] = false
	permBanned[id] = false
		
	new steamid[64], key[32], val[511], timeStamp, banFlag[56]
	get_user_authid(id,steamid,63)
	format(key,32,"%s",steamid)
	if( nvault_lookup(gVault, key, val, 510, timeStamp) ) {
		parse(val, banFlag,55)
		if (str_to_num(banFlag) > 0) {
			if (time() >= timeStamp) {//ban expired.
				nvault_remove(gVault,key)
				
			}else{ //player has some timeleft on their ban
				set_task(str_to_float(banFlag)*60.0,"banTimer",id)
				permBanned[id] = true
			}
				
		}else{ //user is perma banned
			permBanned[id] = true
		}
	}
	
	
}

public client_disconnect(id) {
	roundBanned[id] = false
	mapBanned[id] = false
	permBanned[id] = false
}

public listBans(id,level,cid) {
	
	if (!cmd_access(id,level,cid,1)) return PLUGIN_HANDLED
	
	
	new playerList[512], found = 0
	for(new i = 0; i < gMaxPlayers; i++) {
		if (roundBanned[i] || mapBanned[i] || permBanned[i]) {
			new name[33]
			get_user_name(i,name,32)
			add(playerList,511,name)
			add(playerList,511,"^n")
			found = 1
		}
	}
	
	if(found) {
		client_print(id,print_console,"[AMXX]: Online players banned from commanding: ^n %s",playerList)
	}else{
		client_print(id,print_console,"[AMXX]: No online players are currently banned.")
	}
	
	return PLUGIN_HANDLED
}

public addBan(id,level,cid) {
	
	if (!cmd_access(id,level,cid,1)) return PLUGIN_HANDLED

	if (read_argc() == 1) {	//no target
		new foundcomm = 0, name[33], auth[64]
		for (new i = 1; i < gMaxPlayers; i++) {
			if (is_user_connected(i)) {
				if (playerClass[i] == IUSER3_COMMANDER) {
					get_user_authid(i,auth,63)
					engclient_cmd(i,"stopcommandermode")
					foundcomm=1
					set_task(0.1,"notifyOfBan",i)
					get_user_name(i,name,32)
					if (!isBanned(auth)) {
						set_commBan(id,auth,-1)
					}
				}
			}
		}
		if (foundcomm == 1) {
			client_print(id,print_console,"[AMXX]: %s (%s) has been banned from commanding for the round.", name, auth)
		}else{
			client_print(id,print_console,"[AMXX]: There is no active commander.")
		}
		return PLUGIN_HANDLED
	}
	
	if (read_argc() == 2) {	//specific target
		new arg1[32]
		new target
		read_argv(1,arg1,32)
		target = cmd_target2(id,arg1,8)
		if (is_user_connected(target)) {	// valid connected player
			
			new auth[64], name[32]
			get_user_authid(target,auth,63)
			get_user_name(target,name,32)
			if (!isBanned(auth)) {
				set_commBan(id,auth,-1)
				client_print(id,print_console,"[AMXX]: %s (%s) has been banned from commanding for the round.", name, auth)
				#if ANNOUNCEBAN == 1
				switch (gActivity) {
					case 1: {
						new name[33]
						get_user_name(target,name,32)
						client_print(0,print_chat,"ADMIN: %s has been banned from commanding for the round.",name)	
					}
					case 2:{
						new name[33], admin[33]
						get_user_name(target,name,32)
						get_user_name(id,admin,32)
						client_print(0,print_chat,"ADMIN %s: %s has been banned from commanding for the round.",admin,name)	
					}
				}
				#endif
			} else {
				client_print(id,print_console,"[AMXX]: %s is already banned from the command station.",auth)
			}
		
			if (playerClass[target] == IUSER3_COMMANDER) {
				engclient_cmd(target,"stopcommandermode")
				set_task(0.2,"notifyOfBan",target)
			}
			return PLUGIN_HANDLED
			
		}else{
			client_print(id,print_console,"[AMXX]: %s is not a valid player.",arg1)
		}
		
	}
	
	if (read_argc() == 3) {	// time is specified
		new arg1[32], arg2[32], target
		read_argv(1,arg1,32)
		read_argv(2,arg2,32)
		new banTime = str_to_num(arg2)
		target = cmd_target2(id,arg1,8)
		if (is_user_connected(target)) {
			new auth[32], name[32]
			get_user_authid(target,auth,32)
			get_user_name(target,name,32)
			if (!isBanned(auth)) {
				set_commBan(id,auth,banTime)

				switch (banTime) {
					case 0: {
						client_print(id,print_console,"[AMXX]: %s (%s) has been banned from commanding permanently.", name, auth)
						#if ANNOUNCEBAN == 1
						switch (gActivity) {
							case 1: {
								new name[33]
								get_user_name(target,name,32)
								client_print(0,print_chat,"ADMIN: %s has been banned from commanding permanently.",name)	
							}
							case 2:{
								new name[33], admin[33]
								get_user_name(target,name,32)
								get_user_name(id,admin,32)
								client_print(0,print_chat,"ADMIN %s: %s has been banned from commanding permanently.",admin,name)	
							}
						}
						#endif
					}
					case -1: {
						client_print(id,print_console,"[AMXX]: %s (%s) has been banned from commanding for the round.", name, auth)
						#if ANNOUNCEBAN == 1
						switch (gActivity) {
							case 1: {
								new name[33]
								get_user_name(target,name,32)
								client_print(0,print_chat,"ADMIN: %s has been banned from commanding for the round.",name)	
							}
							case 2:{
								new name[33], admin[33]
								get_user_name(target,name,32)
								get_user_name(id,admin,32)
								client_print(0,print_chat,"ADMIN %s: %s has been banned from commanding for the round.",admin,name)	
							}
						}
						#endif
					}
					case -2: {
						client_print(id,print_console,"[AMXX]: %s (%s) has been banned from commanding for the map.", name, auth)
						#if ANNOUNCEBAN == 1
						switch (gActivity) {
							case 1: {
								new name[33]
								get_user_name(target,name,32)
								client_print(0,print_chat,"ADMIN: %s has been banned from commanding for the map.",name)	
							}
							case 2:{
								new name[33], admin[33]
								get_user_name(target,name,32)
								get_user_name(id,admin,32)
								client_print(0,print_chat,"ADMIN %s: %s has been banned from commanding for the map.",admin,name)	
							}
						}
						#endif
					}
					default: {
						client_print(id,print_console,"[AMXX]: %s (%s) has been banned from commanding for %i mins.", name, auth, banTime)
						set_task(float(banTime)*60.0,"banTimer",target)
						#if ANNOUNCEBAN == 1
						switch (gActivity) {
							case 1: {
								new name[33]
								get_user_name(target,name,32)
								client_print(0,print_chat,"ADMIN: %s has been banned from commanding for %i minutes.",name,banTime)	
							}
							case 2:{
								new name[33], admin[33]
								get_user_name(target,name,32)
								get_user_name(id,admin,32)
								client_print(0,print_chat,"ADMIN %s: %s has been banned from commanding for %i minutes.",admin,name)	
							}
						}
						#endif
					}
				}
				
				
			} else {
				client_print(id,print_console,"[AMXX]: %s is already banned from the command station.",auth)
			}

			if (playerClass[target] == IUSER3_COMMANDER) {
				engclient_cmd(target,"stopcommandermode")
				set_task(0.1,"notifyOfBan",target)
			}
			return PLUGIN_HANDLED
		}else{
			if (containi(arg1,"STEAM") != -1) {
				set_commBan(id,arg1,banTime)
				client_print(id,print_console,"[AMXX]: %s has been added to the banned list.",arg1)
			}else{
				client_print(id,print_console,"[AMXX]: %s is not a valid player or STEAMID.",arg1)
			}
		}
	}
	return PLUGIN_HANDLED
}

//the timer has expired, lets clear the vault entry
public banTimer(id) {

	new steamid[64], key[32], val[511], timeStamp, banFlag[56]
	get_user_authid(id,steamid,63)
	format(key,32,"%s",steamid)
		
	//prune ban
	if( nvault_lookup(gVault, key, val, 510, timeStamp) ) {
		parse(val, banFlag,55)
		if (str_to_num(banFlag) > 0) {
			if (time() >= timeStamp) {
				nvault_remove(gVault,key)
			}
		}
	}
	
	ns_popup(id,"You are able to command again.")
	#if ANNOUNCEBAN == 1
	if (gActivity > 0) {
		new name[33]
		get_user_name(id,name,32)
		client_print(0,print_chat,"ADMIN: %s is able to command again.",name)	
	}
	#endif
	permBanned[id] = false
}

public enforceBan(id) {
	engclient_cmd(id,"stopcommandermode")
	set_task(0.3,"notifyOfBan",id)
}

public notifyOfBan(id) {
	ns_popup(id,"You have been banned from commanding.")
	client_cmd(id, "spk ^"%s^"", "hud/tooltip.wav")
}

public resetBans() {
	for (new i=0; i < MAXBANS ; i++) {
		if (i < 33) {
			roundBanned[i] = 0
			mapBanned[i] = 0
		}
		permBanned[i] = 0
	}
	nvault_prune(gVault,0,0)
	
	server_print("[AMXX]: All commander bans have been reset.")
}

public isBanned(auth[]) {
	new id = find_player("cj",auth)
	if (roundBanned[id] || mapBanned[id] || permBanned[id]) {
		return true
	}
	return false
}

public eRoundEnd() {
	for (new i=0; i < gMaxPlayers; i++) {
		roundBanned[i] = 0
	}
}

public eStatusInfo() {
	new id = read_data(1)
	playerClass[id] = read_data(6) // For indexing of the player's last known "class".
	if (read_data(6) == IUSER3_COMMANDER) {
		new auth[32]
		get_user_authid(id, auth ,32)
		if (isBanned(auth)) {
			set_task(0.1,"enforceBan", id)
		}
	}
}

public set_commBan(banner,authid[],length) {
	
	new banned = find_player("c",authid)
	
	if (length >= 0) {
		new key[32], val[511], timeStamp

		format(key,32,"%s",authid)

		if( nvault_lookup(gVault, key, val, 510, timeStamp) ) {
			new update[511]
			format(update,510,"%i",length)
			nvault_set(gVault, key, update)
		}else{
			new update[511]
			format(update,510,"%i",length)
			nvault_set(gVault, key, update)
		}
		
		if (is_user_connected(banned)) {
			permBanned[banned] = true
		}
	}else{

		switch (length) {
			case -1: {
				roundBanned[banned] = true
			}
			case -2: {
				mapBanned[banned] = true
			}
		}
	}
}

public removeBan(id,level,cid) {
	
	if (!cmd_access(id,level,cid,1)) return PLUGIN_HANDLED
	
	new arg1[32]
	read_argv(1,arg1,32)
	if (read_argc() == 2) {
		new  target = cmd_target2(id,arg1,8)
		if(is_user_connected(id)) {
			if (roundBanned[target] || mapBanned[target]) {
				roundBanned[target] = false
				mapBanned[target] = false
			}else{
				permBanned[target] = false
	
				new steamid[64], key[32], val[511], timeStamp
				get_user_authid(target,steamid,63)
				format(key,32,"%s",steamid)
				
				if( nvault_lookup(gVault, key, val, 510, timeStamp) ) {
					nvault_remove(gVault,key)
					client_print(id,print_console,"[AMXX]: %s is now unbanned.",arg1)
					if (task_exists(target)) { 
						remove_task(target)
					}
				}else{
					client_print(id,print_console,"[AMXX]: %s was not found on the banned list.",arg1)
					return PLUGIN_HANDLED
				}
			}	
			#if ANNOUNCEBAN == 1
			switch (gActivity) {
				case 1: {
					new name[33]
					get_user_name(target,name,32)
					client_print(0,print_chat,"ADMIN: %s has been unbanned from commanding.",name)	
				}
				case 2:{
					new name[33], admin[33]
					get_user_name(target,name,32)
					get_user_name(id,admin,32)
					client_print(0,print_chat,"ADMIN %s: %s has been unbanned from commanding.",admin,name)	
				}
			}
			#endif
		}else{
			
			new key[32], val[511], timeStamp
			format(key,32,"%s",arg1)
			
			if (containi(arg1,"STEAM") != -1) {
				if( nvault_lookup(gVault, key, val, 510, timeStamp) ) {
					nvault_remove(gVault,key)
					client_print(id,print_console,"[AMXX]: %s is now unbanned.",arg1)
					
					return PLUGIN_CONTINUE
				}
				client_print(id,print_console,"[AMXX]: %s was not found on the banned list.",arg1)
				
			}else{
				client_print(id,print_console,"[AMXX]: %s is not a valid player or STEAMID.",arg1)
			}
		}
		
	}
	return PLUGIN_HANDLED
}

//stock from original plugin
stock cmd_target2(id,const arg[],flags = 1) {
	new player = find_player("bl",arg)
	if (player) {
		if ( player != find_player("blj",arg) )
		{
			console_print(id,"There are more clients matching to your argument")
			return 0    
		}
	} else if ( ( player = find_player("c",arg) )==0 && arg[0]=='#' && arg[1] )
		player = find_player("k",str_to_num(arg[1]))    
	if (!player) {
		//console_print(id,"Client with that name or userid not found")
		// Had to copy this entire bloody stock because of this line ^^
		return 0
	}
	if (flags & 1) {
		if ((get_user_flags(player)&ADMIN_IMMUNITY) && ((flags&2)?(id!=player):true) ) {
			new imname[32]
			get_user_name(player,imname,31)
			console_print(id,"Client ^"%s^" has immunity",imname)
			return 0
		}
	}
	if (flags & 4) {
		if (!is_user_alive(player)) {
			new imname[32]
			get_user_name(player,imname,31) 
			console_print(id,"That action can't be performed on dead client ^"%s^"",imname)
			return 0
		}
	}
	if (flags & 8) {
		if (is_user_bot(player)) {
			new imname[32]
			get_user_name(player,imname,31) 
			console_print(id,"That action can't be performed on bot ^"%s^"",imname)
			return 0
		} 
	}
	return player
}

	
