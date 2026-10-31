/* AMX Mod X script.
*   AG Menu
*
* by Sparky911
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

#include <amxmodx>
#include <amxmisc>

new PLUGIN[]="AMX PASS/NO PASS"
new AUTHOR[]="Sparky911"
new VERSION[]="1.00"

new authid[32]
new name[32]
new steamids[32][32]
new steamidCount

public plugin_init()
{
     register_plugin(PLUGIN, VERSION, AUTHOR)
     // all these commands can be used by players with their ID in clan_night_attendants.ini. See function code.
     
     // pass and nopass can also be executed by users with ADMIN_SLAY. These are Lts. See function code.
     register_concmd("amx_pass","pass",ADMIN_SLAY,"- Sets a server password")
     register_concmd("amx_nopass","nopass",ADMIN_SLAY,"- Removes the server password")

     register_concmd("amx_alltalk","alltalk",ADMIN_SLAY,"- Turns alltalk on or off, 1 = on, 0 = off")
     register_concmd("amx_tmode","tmode",ADMIN_SLAY,"- Turns tournament mode on or off, 1 = on, 0 = off")
     register_concmd("amx_ff","ff",ADMIN_SLAY,"- Turns friendly fire on or off, 1 = on, 0 = off")
     
     steamidCount = 0
     
     loadSteamIds()
}

public loadSteamIds() {
	new filename[32]
	new lineIndex = 0
	new lineText[32]
	new readLength = 256;
	new charsRead = 0
	//new warningIndex = 0
	
	format(filename, 128, "addons/amxmodx/configs/clan_night_attendants.ini")	
	if (file_exists(filename)) {
		while (read_file(filename, lineIndex, lineText, readLength, charsRead)) {
			if (strlen(lineText) > 4) {
				steamids[steamidCount] = lineText
				steamidCount++
			}
			lineIndex++
		}
	}	
}

public pass(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1) && !userInSteamIDFile(id) && !(get_user_flags(id) & ADMIN_SLAY)) {
        return PLUGIN_HANDLED
    }

    new cmd[32], password[128]

    read_argv(0, cmd, 31)
    read_args(password, 127)
    replace(password, 127, cmd, "")
    format(password, 127, "%s", password)

    get_user_name(id, name, 31)
    get_user_authid(id, authid, 31)
    switch (get_cvar_num("amx_show_activity")) {
      case 2: client_print(0,print_chat,"ADMIN %s has set a server password",name)
      case 1: client_print(0,print_chat,"ADMIN A server password has been set")
    }
    log_amx("Cmd: ^"%s<%d><%s>^" set the server password to %s",name,get_user_userid(id),authid,password)
    set_cvar_string("sv_password", password)

    return PLUGIN_HANDLED
}



public nopass(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1) && !userInSteamIDFile(id) && !(get_user_flags(id) & ADMIN_SLAY)) {
        return PLUGIN_HANDLED
    }

    get_user_name(id, name, 31)
    get_user_authid(id, authid, 31)
    switch (get_cvar_num("amx_show_activity")) {
      case 2: client_print(0,print_chat,"ADMIN %s has removed the server password",name)
      case 1: client_print(0,print_chat,"ADMIN The server password has been removed")
    }
    log_amx("Cmd: ^"%s<%d><%s>^" removed server password", name,get_user_userid(id),authid)
    set_cvar_string("sv_password", "")

    return PLUGIN_HANDLED
}

public alltalk(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1) && !userInSteamIDFile(id) && !(get_user_flags(id) & ADMIN_SLAY)) {
        return PLUGIN_HANDLED
    }

    new cmd[32], password[128]

    read_argv(0, cmd, 31)
    read_args(password, 127)
    replace(password, 127, cmd, "")
    format(password, 127, "%s", password)
    
    new onoroff[32]
    
    if (strcmp(password, "1") == 0)
        format(onoroff, 32, "on")
    else
        format(onoroff, 32, "off")

    get_user_name(id, name, 31)
    get_user_authid(id, authid, 31)
    switch (get_cvar_num("amx_show_activity")) {
      case 2: client_print(0,print_chat,"ADMIN %s has turned alltalk %s",name, onoroff)
      case 1: client_print(0,print_chat,"ADMIN Alltalk has be turned %s", onoroff)
    }
    log_amx("Cmd: ^"%s<%d><%s>^" turned alltalk %s",name,get_user_userid(id),authid,onoroff)
    set_cvar_string("sv_alltalk", password)

    return PLUGIN_HANDLED
}

public tmode(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1) && !userInSteamIDFile(id) && !(get_user_flags(id) & ADMIN_SLAY)) {
        return PLUGIN_HANDLED
    }

    new cmd[32], password[128]

    read_argv(0, cmd, 31)
    read_args(password, 127)
    replace(password, 127, cmd, "")
    format(password, 127, "%s", password)
    
    new onoroff[32]
    
    if (strcmp(password, "1") == 0)
        format(onoroff, 32, "on")
    else
        format(onoroff, 32, "off")

    get_user_name(id, name, 31)
    get_user_authid(id, authid, 31)
    switch (get_cvar_num("amx_show_activity")) {
      case 2: client_print(0,print_chat,"ADMIN %s has turned tournament mode %s",name, onoroff)
      case 1: client_print(0,print_chat,"ADMIN Tournament mode has be turned %s", onoroff)
    }
    log_amx("Cmd: ^"%s<%d><%s>^" turned tournamentmode %s",name,get_user_userid(id),authid,onoroff)
    set_cvar_string("mp_tournamentmode", password)

    return PLUGIN_HANDLED
}

public ff(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1) && !userInSteamIDFile(id) && !(get_user_flags(id) & ADMIN_SLAY)) {
        return PLUGIN_HANDLED
    }

    new cmd[32], password[128]

    read_argv(0, cmd, 31)
    read_args(password, 127)
    replace(password, 127, cmd, "")
    format(password, 127, "%s", password)
    
    new onoroff[32]
    
    if (strcmp(password, "1") == 0)
        format(onoroff, 32, "on")
    else
        format(onoroff, 32, "off")

    get_user_name(id, name, 31)
    get_user_authid(id, authid, 31)
    switch (get_cvar_num("amx_show_activity")) {
      case 2: client_print(0,print_chat,"ADMIN %s has turned friendly fire mode %s",name, onoroff)
      case 1: client_print(0,print_chat,"ADMIN friendly fire mode has be turned %s", onoroff)
    }
    log_amx("Cmd: ^"%s<%d><%s>^" turned friendly fire %s",name,get_user_userid(id),authid,onoroff)
    set_cvar_string("mp_friendlyfire", password)

    return PLUGIN_HANDLED
}

public userInSteamIDFile(id)
{
    new authid[32]
    get_user_authid(id, authid, 32)
    new i
    
    for (i = 0; i < steamidCount; i++) {
        if (strcmp(authid, steamids[i]) == 0)
            return true
    }
    
    return false      
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
