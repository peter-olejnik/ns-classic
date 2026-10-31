/* Admin Sprite show
About:
This plugin allows admins to place signs over the head of other players/admins, you can place 1 sign pr player. And you can spesify what .spr files to use in a included
config file.

Forum thread: http://www.amxmodx.org/forums/viewtopic.php?t=6037

Install:
Install the plugin like any other.
Copy the sprites.ini to AMXX configs dir
Copy the .spr files to <mod>/sprites
Edit/Add new sprites by editing the sprites.ini file

Usage:
amx_sprite <name / #userid> <sign name> <time>
amx_sprite <name / #userid> <sign name>
amx_unsprite <name / #userid>

Credits:
Ops in #AMXmod @ Quakenet for alot of help ( + AssKicker & CheesyPeteza )
Based on idea from: KRoTaL, StuD|MaN

Changelog:
1.2.3 ( 8.01.2010 ) by Doc
    -Added: AMX admin logging via log_amx() so all use of this plugin will be logged

1.2.2 ( 16.09.2005 )
	- Changed: Plugin now uses log_amx() instead to print errors if the sprite is not there ( so it shows in amxx log )
	- Changed: Plugin will now break out of for() loop when it found the correct sprite name
	- Changed: Plugin now has support for longer path names to amxx config folder

1.2.1 ( 15.09.2004 )
	- Fixed: func_AddSprite() would make g_PlayerStatus go out of sync
	- Fixed: CMD_AddSprite() not working properbly
	- Added: plugin_precache() will now stop reading the sprites.ini file when maximum number of sprites the plugin can handle is reached(Controled by: Max_Sprites )

1.2.0 ( 10.09.2004 )
	- Added: func_AddSprite() to allow third party plugins to activate sprite( Like my admin Aimmenu)
	- Added: func_RemoveSprite() to remove a sprite via a third party plugin
	- Fixed: Bug where g_TotalSprites would get out of sync if a admin add a new sprite to a player that allready had one

1.1.0
	- Added: You can now spesify what .spr files and commands to use in a ini file (addons/amxx/configs/sprites.ini)
	- First public version

1.0.1 Beta
	- Optimised code.
	- Code cleaned up & Comments added.

1.0.0 Beta
	- First release
*/   
#define Max_Sprites 99
#define MAXPLAYERS 32
#define DefaultSpriteTime 180.0
#define SpriteReason 1
#define AllowOtherPlugin2Interface 1


#define SpriteShowTime 4000
#define ReAddSpriteTime 4.0

#include <amxmodx> 
#include <amxmisc> 


new gs_SpriteFile[128]
new gs_SpriteName[Max_Sprites+1][12]	// contains the "name" of the sprite used in the command
new gs_SpriteID[Max_Sprites+1]			// Contains the precash index of the sprite
new g_TotalSprites						// Contains the number of sprites used ingame
new g_PlayerStatus[MAXPLAYERS+1]		// Contains the precashe index of the sprite for eatch player (0 if no sprite is assigned)

public plugin_init()
{ 
	register_plugin("Admin Sprite Show", "1.2.2", "EKS") 
	register_clcmd("amx_sprite", "CMD_AddSprite", ADMIN_KICK, "<name/id/wonid> <sprite> - shows sprite above player's head") 
	register_clcmd("amx_unsprite", "CMD_RemoveSprite", ADMIN_KICK, "changes back to normal")

	set_task(ReAddSpriteTime,"Task_ReAddSprites",MAXPLAYERS+1,_,_,"b")
}

public CMD_AddSprite(id,level,cid) 
{ 
	if(!cmd_access (id,level,cid,2) || !g_TotalSprites) return PLUGIN_HANDLED
	new arg[32],VictimID
	
	read_argv(1,arg,31)  			// Arg contains Targets nick or Userid
	VictimID = cmd_target(id,arg,2)		// This code here tryes to find out the player index. Either from a nick or #userid
	if ((get_user_flags(VictimID) & ADMIN_IMMUNITY) && VictimID != id || !cmd_access (id,level,cid,2) ) { return PLUGIN_HANDLED; } // This code is kind of "long", its job is to. Stop actions against admins with immunity, Stop actions action if the user lacks access, or is a bot/hltv
	new VictimName[32],AdminName[32],SpriteNR
	new Float:f_SpriteTime
	read_argv(2,arg,11) // Reads out the sprite name
	for(new i=0;i<=g_TotalSprites;i++) if(equali(arg,gs_SpriteName[i]))
	{
		Add_Sprite(VictimID,gs_SpriteID[i])
		if(!g_PlayerStatus[VictimID]) g_PlayerStatus[0]++		// This is increased so the server knows how many ppl have a sign over their head
		SpriteNR = i
		g_PlayerStatus[VictimID] = gs_SpriteID[i]
		break
	}
	if(!SpriteNR)
	{
		new Sprites[48]
		for(new i=0;i<=g_TotalSprites;i++) format(Sprites,47,"%s %s",Sprites,gs_SpriteName[i])
		console_print(id,"[AMXX] %s not a vaild sprite, the vaild once are:%s",arg,Sprites)
		return PLUGIN_HANDLED
	}

	read_argv(3,arg,11) // Reads out how long the sprite should be shown.
	if(!arg[0])
		f_SpriteTime = DefaultSpriteTime
	else if(contain(arg,"m")!=-1) // This means the time was entered in minuts and not seconds
	{
		new Temp[8]
		copyc(Temp,7,arg, 'm')
		f_SpriteTime = floatstr(Temp) * 60
	}
	else if(isdigit(arg[0])) // The value was entered in seconds
	{
		f_SpriteTime = floatstr(arg)
	}
	else
	{
		f_SpriteTime = DefaultSpriteTime
	}

	get_user_name(id,AdminName,31)
	get_user_name(VictimID,VictimName,31)
	
	new AdminAuth[32], VictimAuth[32]
	
	get_user_authid(id,AdminAuth,31)
	get_user_authid(VictimID,VictimAuth,31)	

	switch(get_cvar_num("amx_show_activity"))   
	{ 
		case 2: client_print(0,3,"ADMIN %s: Has put a %s sign above %s for %0.0f minutes",AdminName,gs_SpriteName[SpriteNR],VictimName,(f_SpriteTime / 60))
   		case 1: client_print(0,3,"ADMIN: %s has had a %s sign put over his head for %0.0f minutes",VictimName,gs_SpriteName[SpriteNR],(f_SpriteTime / 60))
	}
	
	log_amx("Sprite: ^"%s<%s>^" has put a %s sign above ^"%s<%s>^" for %0.0f minutes",AdminName,AdminAuth,gs_SpriteName[SpriteNR],VictimName,VictimAuth,(f_SpriteTime / 60))

	new parm[1]
	parm[0] = VictimID
	remove_task(VictimID)	// Incase a task was there allready
	set_task(f_SpriteTime,"task_RemoveSprite",VictimID,parm,1,"a",1)
	return PLUGIN_HANDLED
}
public CMD_RemoveSprite(id,level,cid)   /// Removed gagged player ( done via console command )
{
	new arg[32],VictimID
	read_argv(1,arg,31)  			// Arg contains Targets nick
	
	VictimID = cmd_target(id,arg,2)		// This code here tryes to find out the player index. Either from a nick or #userid
	if ((get_user_flags(VictimID) & ADMIN_IMMUNITY) && VictimID != id || !cmd_access (id,level,cid,2) ) { return PLUGIN_HANDLED; } // This code is kind of "long", its job is to. Stop actions against admins with immunity, Stop actions action if the user lacks access, or is a bot/hltv

	new AdminName[32],VictimName[32] 

	get_user_name(id,AdminName,31)		// Gets Admin name
	get_user_name(VictimID,VictimName,31)

	if(!g_PlayerStatus[VictimID])		// Checks if player has gagged flag
	{
		console_print(id,"%s has no sign over his head",arg)
		return PLUGIN_HANDLED
	}
	switch(get_cvar_num("amx_show_activity"))   
	{ 
   		case 2:   client_print(0,print_chat,"ADMIN %s: has removed the sign over %s`s head",AdminName,VictimName) 
   		case 1:   client_print(0,print_chat,"ADMIN: Has removed the sign over %s`s head",VictimName) 
  	}
  	
	new AdminAuth[32], VictimAuth[32]
	
	get_user_authid(id,AdminAuth,31)
	get_user_authid(VictimID,VictimAuth,31)	  	
  	
	log_amx("UnSprite: ^"%s<%s>^" has removed the sign over ^"%s<%s>^"",AdminName,AdminAuth,VictimName,VictimAuth)
  	
	new parm[1]
	parm[0] = VictimID
	task_RemoveSprite(parm)
	return PLUGIN_HANDLED

}
public client_disconnect(id)
{
	if(g_PlayerStatus[id])
	{
		new Name[32],Authid[35]
		get_user_name(id,Name,31)
		get_user_authid(id,Authid,34)
		client_print(0,print_chat,"[AMXX]: %s<%s> has disconnected while having a sign over his head",Name,Authid)
		new parm[1]
		parm[0] = id
		task_RemoveSprite(parm)
	}
}

public Task_ReAddSprites()
{
	if(g_PlayerStatus[0] == 0)
		return PLUGIN_HANDLED

	for(new i=1;i<=MAXPLAYERS;i++) if(is_user_connected(i) && is_user_alive(i) && g_PlayerStatus[i] != 0)
		{
			server_print("Add_Sprite adding sprite to: %d",i)
			Add_Sprite(i,g_PlayerStatus[i])
		}
	return PLUGIN_HANDLED
}

public task_RemoveSprite(parm[])
{
	remove_task(parm[0])
	g_PlayerStatus[parm[0]] = 0
	Remove_Sprite(parm[0])
	g_PlayerStatus[0]--
}

stock Remove_Sprite(id)	// This is the function used to remove a sprite from a player
{
	message_begin(MSG_ALL,SVC_TEMPENTITY)
     	write_byte(125)
     	write_byte(id)
     	message_end()
}



stock Add_Sprite(id,SpriteID)
{	
	message_begin(MSG_ALL,SVC_TEMPENTITY)
	write_byte(124)
	write_byte(id)
	write_coord(65)
	write_short(SpriteID)
	write_short(SpriteShowTime)
	message_end()
}


public plugin_precache() 
{ 
	get_localinfo("amxx_configsdir",gs_SpriteFile,127)
	format(gs_SpriteFile,127,"%s/sprites.ini",gs_SpriteFile)
	if (!file_exists(gs_SpriteFile))  // If the file does not exist no point trying to read it.
	{
		server_print("Fatal error, no config file was found(%s)",gs_SpriteFile)
		return PLUGIN_HANDLED
	}
	new CurrentLine = 0 
	new EndOfFile = 1
	new InfoFromFile[32]
	new SpriteFileName[Max_Sprites+1][32]

	while(read_file(gs_SpriteFile,CurrentLine,InfoFromFile,31,EndOfFile) != 0 && CurrentLine <= Max_Sprites) 
	{
		CurrentLine++
		parse(InfoFromFile, SpriteFileName[CurrentLine], 31, gs_SpriteName[CurrentLine], 11)
		if (!file_exists(SpriteFileName[CurrentLine]))  // If the file does not exist no point trying to read it.
		{
			log_amx("[AMXX] Could not find the .spr file(%s). Stopping plugin",SpriteFileName[CurrentLine])
			return PLUGIN_HANDLED
		}
		gs_SpriteID[CurrentLine] = precache_model(SpriteFileName[CurrentLine])
		g_TotalSprites++
	}
	return PLUGIN_HANDLED
}
#if AllowOtherPlugin2Interface == 1
public func_AddSprite(id,SpriteName[12])
{
	//new SpriteNR
	for(new i=0;i<=g_TotalSprites;i++) if(equali(SpriteName,gs_SpriteName[i]))
	{
		Add_Sprite(id,gs_SpriteID[i])
		if(!g_PlayerStatus[id]) g_PlayerStatus[0]++		// This is increased so the server knows how many ppl have a sign over their head
		g_PlayerStatus[id] = gs_SpriteID[i]
		Add_Sprite(id,gs_SpriteID[i])
		
		new parm[1]
		parm[0] = id
		remove_task(id)	// Incase a task was there allready
		set_task(DefaultSpriteTime,"task_RemoveSprite",id,parm,1,"a",1)
	}
	if(!g_PlayerStatus[id]) g_PlayerStatus[0]++		// This is increased so the server knows how many ppl have a sign over their head
}
public func_RemoveSprite(id)
{
	new parm[1]
	parm[0] = id
	task_RemoveSprite(parm)
}
#endif
