/* AMX Mod X - Script
 *
 *	Constant Names v1.2 - by KoST
 *
 */

// Enhanced by Yolkfolk to protect the names in the file from use by other players.
// Previously, someone using a name registered on this list to another STEAMID would
// cause this plugin to constantly try to rename the STEAMID on the list, crashing the server.



//--------------------------------------------------------------------------------------------------
#include <amxmodx>
#include <amxmisc>
//--------------------------------------------------------------------------------------------------


// set this to a higher value if you need more predefined users in you config file
#define MAX_USERS 200
// you can also modify the default config file name if needed
#define CONFIG_FILE "constant_names.ini"


//--------------------------------------------------------------------------------------------------
#define PLUGIN "Constant Names"
#define VERSION "1.2"
#define AUTHOR "KoST"
//--------------------------------------------------------------------------------------------------

new file_name[128] // the config path/file 
new names[33][32] // id->playername
new steam_names[MAX_USERS][2][35] // steamid->playername values from config file
new num_users=0 // parsed users

public plugin_init(){
	register_plugin(PLUGIN,VERSION,AUTHOR)

	// get config dir
	new config_dir[80]
	get_configsdir(config_dir,79)
	format(file_name,127,"%s/%s",config_dir,CONFIG_FILE) // store path/file in global 'file_name'
	
	new text[256],name[33],steamid[33],txtLen,line_num=0
	// parse config file if exists
	if (file_exists(file_name)){
		line_num=read_file(file_name,line_num,text,255,txtLen) // read first line
		while(line_num){
			parse(text,steamid,32,name,32)
			if (line_num<=MAX_USERS){ // stop caching if MAX_USERS reached
				if (strlen(steamid) && strlen(name)){
					// cache (SteamID -> PlayerName) pairs
					format(steam_names[line_num-1][0],34,"%s",steamid)
					format(steam_names[line_num-1][1],34,"%s",name)
					num_users=line_num // update number of listed users
				}
				line_num=read_file(file_name,line_num,text,255,txtLen) // read next line
			}else line_num=0 // MAX_USERS reached stop parsing
		}
	}
}

public client_putinserver(id){
    new startname[32]
	new steamid[35]
	get_user_authid(id,steamid,34)
	get_user_name(id, startname, 31)
	if (!strlen(steamid)) return PLUGIN_CONTINUE
	names[id]=""
	for (new i=0;i<num_users;i++){ // compare users steamid to cached ones
		if (equali(steam_names[i][0],steamid)){
			format(names[id],31,"%s",steam_names[i][1])
			set_user_info(id,"name",names[id]) // set username to defined one
		}
		if (equali(steam_names[i][1],startname)){
			set_user_info(id,"name","PapaSmurf")
		}
	}	
	return PLUGIN_CONTINUE
}

public client_infochanged(id){
	new newname[32]
	get_user_info(id,"name",newname,31)
	if (strlen(names[id])>0){	
		new oldname[32]
		get_user_name(id,oldname,31)
		if (!equal(newname,oldname)){ // make sure name was changed
			if (!equal(newname,names[id])){
				set_user_info(id,"name",names[id]) // stoped user from changing name
				client_print(id,print_chat,"You are not allowed to change your name")
			}else{
				client_print(id,print_chat,"Your name has been changed to '%s'",newname)
			}
		}
	}else{
		for (new i=0;i<num_users;i++){ // compare users steamid to cached ones
			if (equali(steam_names[i][1],newname)){
				set_user_info(id,"name","PapaSmurf")
				client_print(id,print_chat,"Another STEAMID has reserved that name")
			}
		}	
	}
}

public client_disconnect(id){
	names[id]=""
}
