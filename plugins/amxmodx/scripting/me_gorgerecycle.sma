////////////////////////////////////////////////////////////////////////////////
//                            Information                                     //
////////////////////////////////////////////////////////////////////////////////
/*
GorgeRecycle (v2.6 - 05.01.07)
By: mE @ PsiX.org

Description:
  This plugin allows gorges to recycle their chambers.
  Become are Gorge, point at the desired chamber and say /rec.
  A menu will pop up to confirm removal and
  you'll get back half of what you've paid for it.

Installation:
  Set the desired defines below and install this plugin just like any other.
*/
////////////////////////////////////////////////////////////////////////////////
//                           Configuration                                    //
////////////////////////////////////////////////////////////////////////////////

/* INT (1)
0 - Do use default helper output
1 - Use the "Helper" plugin! (recommended)
*/
#define HELPER 1

/* ADMIN_* (ADMIN_KICK)
Admin flag required to be allowed to remove other players' structures
*/
#define REC_ACCESS ADMIN_KICK

////////////////////////////////////////////////////////////////////////////////
//      NO need to edit anything below unless you know what you're doing      //
////////////////////////////////////////////////////////////////////////////////

#include <amxmodx>
#include <ns>
#include <engine>
#if HELPER == 1
  #include <helper>
#endif

#define PLUGIN_VERSION "2.6"

new g_buildextname[5][9]  = { "Defense", "Movement", "Offense", "Sensory", "Resource" }
new g_blocksound
new g_maxplayers

new ua_choice[33]

public plugin_init(){
  register_plugin("GorgeRecycle",PLUGIN_VERSION,"mE @ PsiX.org")
  register_cvar("me_gorgerecycle",PLUGIN_VERSION,FCVAR_SERVER)
  
  if(!ns_is_combat()){
    g_maxplayers = get_maxplayers()
    
    register_clcmd("say /rec","recycle_menu")
    register_clcmd("say_team /rec","recycle_menu")
    
    register_message(get_user_msgid("PlayHUDNot"),"playhudnot")
    
    register_menucmd(register_menuid("Confirm Recycling"),MENU_KEY_1|MENU_KEY_2,"recycle_select")
  }else{
    pause("ad")
  }
}

public playhudnot(){
  if(!g_blocksound) return PLUGIN_CONTINUE                                      // most certainly there's no reason to block anything
  if(get_msg_arg_int(1) != 0) return PLUGIN_CONTINUE                            // skip wrong type of message
  if(get_msg_arg_int(2) != g_blocksound) return PLUGIN_CONTINUE                 // skip messaged not regarding this entity
  
  return PLUGIN_HANDLED
}

#if HELPER == 1
  public client_help(id){
    help_add("Information","This plugin allows gorges to recycle their chambers")
    help_add("Usage","Become are Gorge, point at the desired chamber and say /rec.^nA menu will pop up to confirm removal and^nyou'll get back half of what you've paid for it.")
    help_add("Commands","Say /rec")
  }
  
  public client_advertise(id){
    if(entity_get_int(id,EV_INT_team) & 1) return PLUGIN_HANDLED                // skip if this is an uneven team (1 or 3)
    return PLUGIN_CONTINUE                                                      // continue if it's an alien team
  }
#endif

public recycle_menu(id){
  if(ns_get_class(id) != CLASS_GORGE && !(get_user_flags(id) & REC_ACCESS)){
    client_print(id,print_chat,"[GorgeRecycle] Recycling only allowed for gorges")
    return PLUGIN_CONTINUE
  }
  new ent,dummy
  get_user_aiming(id,ent,dummy,200)
  if(!is_valid_ent(ent)){
    client_print(id,print_chat,"[GorgeRecycle] Point at the desired chamber and retry")
    return PLUGIN_CONTINUE
  }
  
  new iuser = entity_get_int(ent,EV_INT_iuser3) - 42
  if(iuser < 0 || iuser > 4){
    client_print(id,print_chat,"[GorgeRecycle] You can only recycle chambers")
    return PLUGIN_CONTINUE
  }
  
  new sname[32]
  format(sname,31,"%s Chamber",g_buildextname[iuser])
  new owner  = ns_get_struct_owner(ent)
  
  if (owner == -1) {
      client_print(id,print_chat,"[GorgeRecycle] You're not the owner of this structure")
      return PLUGIN_CONTINUE
  }
  
  if(!is_user_connected(owner)) owner = 0
  
  if(!(get_user_flags(id) & REC_ACCESS)){                                       // player has no access to remove other player's chambers
    if(entity_get_int(ent,EV_INT_team) != entity_get_int(id,EV_INT_team)){
      client_print(id,print_chat,"[GorgeRecycle] This chamber doesn't belong to your team")
      return PLUGIN_CONTINUE
    }
    if(owner && owner != id){                                                   // this chamber has its owner set and belongs to somebody else
      new sowner[33]
      get_user_name(owner,sowner,32)
      client_print(id,print_chat,"[GorgeRecycle] You're not the owner of this %s. Ask %s to recycle it.",sname,sowner)
      return PLUGIN_CONTINUE
    }
  }

  new ownerstring[33]
  if(owner == id){
    ownerstring = "your"
  }else if(owner == 0){
    ownerstring = "this"
  }else{
    get_user_name(owner,ownerstring,32)
    format(ownerstring,32,"%s's",ownerstring)
  }
  new menu_msg[256]
  format(menu_msg,255,"Confirm Recycling: ^n^nPlease confirm recycling of %s^n%s^n+%.1f res^n^n1.  Yes^n2.  No",ownerstring,sname,(iuser==4?7.5:5.0))
  show_menu(id,MENU_KEY_1|MENU_KEY_2,menu_msg,5)

  ua_choice[id]=ent
  
  return PLUGIN_CONTINUE
}

public recycle_select(id,key){
  new ent = ua_choice[id]
  if(!is_valid_ent(ent)) return PLUGIN_HANDLED
  new iuser = entity_get_int(ent,EV_INT_iuser3) - 42
  if(iuser < 0 || iuser > 4) return PLUGIN_HANDLED
  new sname[32]
  format(sname,31,"%s Chamber",g_buildextname[iuser])
  if(key == 0){
    new Float:dres = (iuser==4?7.5:5.0)

    new owner = ns_get_struct_owner(ent)
    if(!is_user_connected(owner)) owner = 0
    if(owner){                                                                  // if owner exists
      ns_set_res(owner,ns_get_res(owner)+dres)
    }else{                                                                      // distrubute res for the whole team otherwise
      new team = entity_get_int(ent,EV_INT_team)
      new aliens
      for(new i=1;i<=g_maxplayers;i++){
        if(!is_user_connected(i)) continue
        if(entity_get_int(i,EV_INT_team) == team) aliens++
      }
      if(aliens == 0) return PLUGIN_HANDLED                                     // just in case - although this should never happen :)
      if(aliens > 1) client_print(id,print_chat,"[GorgeRecycle] Distributing %.1f res among %i aliens because owner is unknown",dres,aliens)
      dres = dres / aliens
      for(new i=1;i<=g_maxplayers;i++){
        if(!is_user_connected(i)) continue
        if(entity_get_int(i,EV_INT_team) != team) continue
        ns_set_res(i,ns_get_res(i)+dres)
      }
    }
    if(task_exists(63716)) remove_task(63716)
    set_task(1.0,"remove_blocksound",63716)
    g_blocksound = (iuser == 4)?46:47                                           // this _should_ prevent the "structure is under attack" sound from being played
    fakedamage(ent,"trigger_hurt",10000.0,1)                                    // KILL the chamber
    client_print(id,print_chat,"[GorgeRecycle] Received %.1f resources for recycling %s",dres,sname)
  }else{
    client_print(id,print_chat,"[GorgeRecycle] Canceled recycling of %s",sname)
  }
  return PLUGIN_HANDLED
}

public remove_blocksound(){
  g_blocksound = 0
}
