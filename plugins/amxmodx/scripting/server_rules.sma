/* AMX Mod script.
* Server Rules 1.1
*
* (c) 2004, FullThrottle
* This file is provided as is (no warranties).
*
* Used CVARS
* sr_display <float> - Length of time to display message
* sr_color <string> - Color to display message RGB values 
*	Example for green: 000255000 
*/

/* Update Log

1.1
	- Changed sr_color so now commas are not used between colors and removed xeroblood's
	code from the project
	- Added keyword processing to display a message to users when they ask how to display the message.
	- Changed default rule color to white.
	- Added the violation menu and the following cvars.
		sr_warnings <- Max Warnings before action is taken
		sr_action <- Action to take for violators 0=Warn Only,1=Kick,2=Ban
		sr_bantime <- Length to ban after max rule violations
	- Added menu command amx_rulemenu
	- Uses the AMXX 1.0 Dynamic menu system.  Set DYNAMICMENU to 0 if you do not have 1.0 running.
	
1.0
	- Initial release
	
*/

#include <amxmodx>
#include <amxmisc>

#define MAXENTRYCOUNT 10
#define MAXENTRYLENGTH 60
#define MESSAGELENGTH MAXENTRYCOUNT*MAXENTRYLENGTH+20

new DYNAMICMENU = 1

new ENTRY[MAXENTRYCOUNT][MAXENTRYLENGTH]
new MESSAGE[MESSAGELENGTH]
new DISPLAYCOLOR[3]
new ENTRYCOUNT = 0

new WARNINGS[32] = 0
new ACTIONS[3][] = {"Warned","Kicked","Banned"}

new Float:TIMERWAIT = 10.0
new DISPLAYTITLE[] = "Server Rules"
new RULEMENUTITLE[] = "Rule Violation Menu"

new PLUGINVERSION[] = "1.1"
new PLUGINNAME[] = "Server Rules"
new PLUGINAUTHOR[] = "FullThrottle"

new ADDENTRYCMD[] = "amx_addrule"
new RULEMENUCMD[] = "amx_rulemenu"
new REMOVEENTRYCMD[] = "amx_removerule"
new ADMINDISPLAYMESSAGECMD[] = "amx_displayrules"
new DISPLAYMESSAGECMD[] = "say /rules"

new KEYWORD[] = "rule"
new KEYWORDMESSAGE[] = "Type /rules for a list of server rules."

new CVARCOLOR[] = "sr_color"
new CVARDISPLAY[] = "sr_display"
new CVARMAXWARNINGS[] = "sr_warnings"
new CVARMAXWARNINGSACTION[] = "sr_action"
new CVARBANTIME[]	= "sr_bantime"

new MENU_POSITION[33]
new MENU_PLAYERS[33][32]
new MENU_PLAYERSNUM[33]
new MENU_OPTION[33]

new g_cstrikeRunning

public plugin_init()	{
	register_plugin(PLUGINNAME, PLUGINVERSION, PLUGINAUTHOR) 
	register_concmd(ADDENTRYCMD, "addentry", ADMIN_CVAR, "<entry> : Adds a entry")
	register_concmd(REMOVEENTRYCMD, "removeentry", ADMIN_CVAR, "<id> : Removes a entry")
	register_concmd(ADMINDISPLAYMESSAGECMD, "displaymessage", ADMIN_KICK, ": Display message to all players")
	register_clcmd(DISPLAYMESSAGECMD, "displaymessage")
	register_clcmd("say", "processsay")

	register_menucmd(register_menuid(RULEMENUTITLE), 1023, "actionMenu")
	register_clcmd(RULEMENUCMD, "cmdMenu", ADMIN_KICK, ": Display the Rule Violation Menu")

	register_cvar(CVARDISPLAY, "20.0", 4)
	register_cvar(CVARCOLOR, "255255255", 4)
	register_cvar(CVARMAXWARNINGS, "3", 4)
	register_cvar(CVARMAXWARNINGSACTION, "1", 4)
	register_cvar(CVARBANTIME, "60", 4)
	
	if ( DYNAMICMENU )
		AddMenuItem(RULEMENUTITLE, RULEMENUCMD, ADMIN_KICK, PLUGINNAME)
}

public processsay(id) {
	new stringsay[192]
	read_args(stringsay,192)
	if( (containi(stringsay, KEYWORD) != -1) ) {
		client_print(id,print_chat, "[%s] %s", DISPLAYTITLE, KEYWORDMESSAGE)
	}
	return PLUGIN_CONTINUE
}

public client_connect(id) 
	WARNINGS[id] = 0

public client_disconnect(id) 
	WARNINGS[id] = 0
	
public client_putinserver(id) 
	set_task( TIMERWAIT, "displaymessage", id)

public addentry(id,level,cid){
	if (!cmd_access(id,level,cid,2))
		return PLUGIN_HANDLED
	if (ENTRYCOUNT >= MAXENTRYCOUNT){
		console_print(id,"[%s] Entry limit reached. %d active entries.", DISPLAYTITLE, ENTRYCOUNT)
		return PLUGIN_HANDLED
	}
	read_argv(1,ENTRY[ENTRYCOUNT],MAXENTRYLENGTH)
	console_print(id,"[%s] Entry added: %s", DISPLAYTITLE, ENTRY[ENTRYCOUNT])
	ENTRYCOUNT++
	return PLUGIN_HANDLED
}

public removeentry(id,level,cid){
	// This code currenty does not work but I will be adding the remove feature soon
	new nId[2]
	if (!cmd_access(id,level,cid,2))
		return PLUGIN_HANDLED
	read_argv(1,nId,2)
	if ( ENTRYCOUNT < str_to_num(nId) ){
		console_print( id, "[%s] Entry doesn't exist.", DISPLAYTITLE )
		return PLUGIN_HANDLED
	}
	console_print( id, "[%s] Entry Removed: %d", DISPLAYTITLE, ENTRY[str_to_num(nId)] )
	ENTRYCOUNT--
	return PLUGIN_HANDLED
}

public displaymessage(id) {
	new sDisplayColor[9]
	new Float:nDisplayTime = get_cvar_float(CVARDISPLAY)
	
	get_cvar_string( CVARCOLOR, sDisplayColor, 9 )
	DISPLAYCOLOR[2] = str_to_num(sDisplayColor[6])
	sDisplayColor[6] = 0
	DISPLAYCOLOR[1] = str_to_num(sDisplayColor[3])
	sDisplayColor[3] = 0
	DISPLAYCOLOR[0] = str_to_num(sDisplayColor[0])
	
	format( MESSAGE, MESSAGELENGTH, DISPLAYTITLE )
	for ( new i=0; i<ENTRYCOUNT; ++i ) {
		format( MESSAGE, MESSAGELENGTH, "%s^n%d. %s", MESSAGE, i+1, ENTRY[i] )
	}
	set_hudmessage( DISPLAYCOLOR[0], DISPLAYCOLOR[1], DISPLAYCOLOR[2], 0.05, 0.05, 2, 0.01, nDisplayTime, 0.01, 0.1, 4 )
	if (!id) {
		for(new i = 1; i <= get_maxplayers(); ++i) { 
			show_hudmessage( i, "%s", MESSAGE )
		}
	} else {
			show_hudmessage( id, "%s", MESSAGE )
	}
	return PLUGIN_HANDLED
}

public displayentry(id, entryid) {
	new sDisplayColor[9]
	new Float:nDisplayTime = get_cvar_float(CVARDISPLAY)
	
	get_cvar_string( CVARCOLOR, sDisplayColor, 9 )
	DISPLAYCOLOR[2] = str_to_num(sDisplayColor[6])
	sDisplayColor[6] = 0
	DISPLAYCOLOR[1] = str_to_num(sDisplayColor[3])
	sDisplayColor[3] = 0
	DISPLAYCOLOR[0] = str_to_num(sDisplayColor[0])
	
	format( MESSAGE, MESSAGELENGTH, "[%s] Rule Violation Warning^nYou violated the following rule.^n[ %s ]", DISPLAYTITLE, ENTRY[entryid] )

	set_hudmessage( DISPLAYCOLOR[0], DISPLAYCOLOR[1], DISPLAYCOLOR[2], 0.05, 0.05, 2, 0.01, nDisplayTime, 0.01, 0.1, 4 )
	show_hudmessage( id, "%s", MESSAGE )
	return PLUGIN_HANDLED
}

public handleViolation(id,player) {
	WARNINGS[player]++
	
	new authid[32], authid2[32], name[32], name2[32]
	
	get_user_authid(id, authid, 31)
	get_user_authid(player, authid2, 31)
	get_user_name(id, name, 31)
	get_user_name(player, name2, 31)			
	
	new userid2 = get_user_userid(player)
	new reason[MAXENTRYLENGTH] 
	reason = ENTRY[MENU_OPTION[id]]

	new nAction = get_cvar_num( CVARMAXWARNINGSACTION )
	new nLimit = get_cvar_num( CVARMAXWARNINGS )
	new nBanTime = get_cvar_num( CVARBANTIME )
	
	switch(get_cvar_num("amx_show_activity")) {
		case 2: client_print(0, print_chat, "ADMIN %s: %s %s for: %s", name, (WARNINGS[player] <= nLimit) ? ACTIONS[0] : ACTIONS[nAction], name2, reason )
		case 1: client_print(0, print_chat, "ADMIN: %s %s for: %s", (WARNINGS[player] <= nLimit) ? ACTIONS[0] : ACTIONS[nAction], name2, reason )
	}

	if ( WARNINGS[player] <= nLimit ) {
		displayentry( player, MENU_OPTION[id] )
	} else {
		switch(nAction) {
			case 1:	server_cmd( "kick #%d", userid2 )
			case 2: server_cmd( "banid %d #%d kick;writeid", nBanTime, userid2 )
		}   
	}
	return PLUGIN_HANDLED
}

public actionMenu(id,key) {
	switch(key){
		case 7:{
			++MENU_OPTION[id]
			MENU_OPTION[id] = (MENU_OPTION[id] >= ENTRYCOUNT) ? 0 : MENU_OPTION[id]
			displayMenu(id,MENU_POSITION[id])
		}
		case 8: displayMenu(id,++MENU_POSITION[id])
		case 9: displayMenu(id,--MENU_POSITION[id])
		default:{
			new player = MENU_PLAYERS[id][MENU_POSITION[id] * 8 + key]					 
			handleViolation(id,player)
			displayMenu(id,MENU_POSITION[id])
		}
	}
	return PLUGIN_HANDLED
}

displayMenu(id,pos){
	if (pos < 0)	return
	get_players(MENU_PLAYERS[id],MENU_PLAYERSNUM[id])
	new menuBody[512]
	new b = 0
	new i
	new name[32]
	new start = pos * 7
	if (start >= MENU_PLAYERSNUM[id])
		start = pos = MENU_POSITION[id] = 0
	new len = format(menuBody,511, g_cstrikeRunning ? "\y%s\R%d/%d^n\w^n" : "%s %d/%d^n^n", RULEMENUTITLE, pos+1,( MENU_PLAYERSNUM[id] / 7 + ((MENU_PLAYERSNUM[id] % 7) ? 1 : 0 )) )		
	new end = start + 7
	new keys = (1<<9)|(1<<7)
	if (end > MENU_PLAYERSNUM[id])
		end = MENU_PLAYERSNUM[id]
	for(new a = start; a < end; ++a)
	{
		i = MENU_PLAYERS[id][a]
		get_user_name(i,name,31)
		if ( is_user_bot(i) || (get_user_flags(i)&ADMIN_IMMUNITY) )
		{
			++b	 
			if ( g_cstrikeRunning )
				len += format(menuBody[len],511-len,"\d%d. %s^n\w",b,name)
			else
				len += format(menuBody[len],511-len,"#. %s^n",name)
		}
		else
		{
			keys |= (1<<b)
			len += format(menuBody[len],511-len,"%d. %s^n",++b,name)
		}
	}
	len += format(menuBody[len],511-len,"^n8. %s" , ENTRY[MENU_OPTION[id]] )
	if (end != MENU_PLAYERSNUM[id])
	{
		format(menuBody[len],511-len,"^n9. More...^n0. %s", pos ? "Back" : "Exit")
		keys |= (1<<8)
	}
	else format(menuBody[len],511-len,"^n0. %s", pos ? "Back" : "Exit")
	show_menu(id,keys,menuBody)
}

public cmdMenu(id,level,cid)
{
	if (!cmd_access(id,level,cid,1))	return PLUGIN_HANDLED
	MENU_OPTION[id] = 0
	displayMenu(id,MENU_POSITION[id] = 0)
	return PLUGIN_HANDLED 
}