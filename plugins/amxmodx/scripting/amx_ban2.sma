/*
*
*  AMXX BAN Replacement v 1.0
*
*  The ban code itself was created by the AMXX Dev Team. This is just used as a replacement
*  for the normal ban, so an admin can impose a limit on bans from certain users.
*  I made the modification at the request of an admin friend who's server admins
*  tend to make bans permanent without thinking about it first. This will prevent that from
*  happening, by restricting the max length to whatever the admin sets amx_ban_temp cvar to. 	
*
*  This should be placed above your admincmd.amxx in your plugins.ini file.
*  You can change the access level for the temp ban, by modifying the define low_ban line.
*  It's currently set to ADMIN_LEVEL_E
*
*  A user who has both NORMAL_BAN and LOW_BAN will have it default to NORMAL_BAN which means they
*  can ban a user to any amount of time. A user with access only to LOW_BAN cannot.
*
*
*  The amx_ban_temp cvar is set to 1440 or 24 hours by default.
*
*/

#include <amxmodx>
#include <amxmisc>



#define NORMAL_BAN ADMIN_BAN
#define LOW_BAN ADMIN_LEVEL_E
new BanAccess[33]


public plugin_init(){
	register_plugin("amx_ban2","1.0","AMXX Dev Team/jsauce")
	register_concmd("amx_ban","cmdBan",ADMIN_ADMIN,"<name or #userid> <minutes> [reason]")
	register_cvar("amx_ban_temp","1440")
  
	return PLUGIN_CONTINUE
}
public noaccess(id){
	client_print(id, print_console, "You have insufficient access to use this command.")
	
}


public cmdBan(id,level,cid) {
  if (!cmd_access(id,level,cid,3))
    return PLUGIN_HANDLED
  BanAccess[id] = 0
  if (get_user_flags(id) & NORMAL_BAN){
    BanAccess[id] = BanAccess[id] + 2
  }
  if (get_user_flags(id) & LOW_BAN){
    BanAccess[id] = BanAccess[id] + 1   
  }
  if (BanAccess[id] == 0){
    noaccess(id)
    return PLUGIN_HANDLED
  }
  new target[32],minutes[8],minutes2,minutes3,reason[64]
  read_argv(1,target,31)
  read_argv(2,minutes,7)
  read_argv(3,reason,63)
  minutes2 = str_to_num(minutes)
  minutes3 = get_cvar_num("amx_ban_temp")
  if (BanAccess[id] == 1){
    if ((minutes2 == 0) || (minutes2 == 0.0)) {
      client_print(id,print_console,"[AMXX] You cannot impose a permanent ban at your level. Max ban length is %i minutes",minutes3)
      minutes2 = minutes3
      format(minutes,7,"%i",minutes2)
    } 
    else if (minutes2 > minutes3) {
      client_print(id,print_console,"[AMXX] Maximum limitation of ban in minutes exceeded for your level. Max ban length is %i minutes",minutes3)
      minutes2 = minutes3
      format(minutes,7,"%i",minutes2)
     }
  }
  else { 
    if (BanAccess[id] > 1){
    }
  }
  new player = cmd_target(id,target,11)
  if (!player) return PLUGIN_HANDLED
  new authid[32],name2[32],authid2[32],name[32]
  new userid2 = get_user_userid(player)
  get_user_authid(player,authid2,31)
  get_user_authid(id,authid,31)
  get_user_name(player,name2,31)
  get_user_name(id,name,31)
  userid2 = get_user_userid(player)
  log_amx("Ban: ^"%s<%d><%s><>^" ban and kick ^"%s<%d><%s><>^" (minutes ^"%s^") (reason ^"%s^")", 
    name,get_user_userid(id),authid, name2,userid2,authid2,minutes,reason)

  new temp[64],banned[16],nNum = str_to_num(minutes)
  if (nNum)
    format(temp,63,"%L",player,"FOR_MIN",minutes)
  else
    format(temp,63,"%L",player,"PERM")

  format(banned,15,"%L",player,"BANNED")

  if (reason[0])
    server_cmd("kick #%d ^"%s (%s %s)^";wait;banid ^"%s^" ^"%s^";wait;writeid",userid2,reason,banned,temp,minutes,authid2)
  else
    server_cmd("kick #%d ^"%s %s^";wait;banid ^"%s^" ^"%s^";wait;writeid",userid2,banned,temp,minutes,authid2)
    
  new activity = get_cvar_num("amx_show_activity")
  if (activity!=0) {
    new players[32],pnum,msg[256],len
    get_players(players,pnum,"c")
    for (new i=0;i<pnum;i++) {
      len = format(msg,255,"%L",players[i],"ADMIN")
      if (activity==1)
        len += copy(msg[len],255-len,":")
      else
        len += format(msg[len],255-len," %s:",name)
      len += format(msg[len],255-len," %L",players[i],"BAN")
      len += format(msg[len],255-len," %s ",name2)
      if (nNum)
        format(msg[len],255-len,"%L",players[i],"FOR_MIN",minutes)
      else
        format(msg[len],255-len,"%L",players[i],"PERM")
      client_print(players[i],print_chat,msg)
    }
  }


  console_print(id,"[AMXX] %L",id,"CLIENT_BANNED",name2)
  return PLUGIN_HANDLED
}