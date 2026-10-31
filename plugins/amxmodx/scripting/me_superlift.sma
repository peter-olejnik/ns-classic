////////////////////////////////////////////////////////////////////////////////
//                            Information                                     //
////////////////////////////////////////////////////////////////////////////////
/*
SuperLift / LerkLift (v2.4 - 25.04.07)
By: mE @ PsiX.org
Many thanks to White Panther for supporting this plugin for quite some time and improving it alot!

Description:
  This plugin can work as both SuperLift or LerkLift.
  LerkLift
    Lerks can pick up friendly gorges and lift them around
  SuperLift
    JPers and Lerks can pickup enemy and friendly players and lift them around.
    Picking up enemy players deals damage to them - starting with 10dmg/second it continuously increases to avoid flying around for too long.
    Marines will throw away their selected weapon and switch to the knife while being lifted by an enemy player.

Installation:
  Set the desired defines below and install this plugin just like any other.
*/
////////////////////////////////////////////////////////////////////////////////
//                           Configuration                                    //
////////////////////////////////////////////////////////////////////////////////
/*
INT (2)
0 - Use custom settings below
1 - Default LerkLift settings
2 - Default SuperLift settings
*/
#define MODE_AUTO 2

/*
INT (1)
0 - Do use default helper output
1 - Use the "Helper" plugin! (recommended)
*/
#define HELPER 1

////////////////////////////////////////////////////////////////////////////////
//      NO need to edit anything below unless you set MODE_AUTO to 0          //
////////////////////////////////////////////////////////////////////////////////
#if MODE_AUTO == 0
/*
INT (1)
0 - LerkLift
1 - SuperLift
*/
#define MODE_LIFT 1

/*
INT (2)
0 - Allow lifted players to attack like normal
1 - Don't allow lifted player to use their weapons at all
2 - Allow enemy rines to only use knife and drop their current weapon (SL only)
*/
#define MODE_ATTACK 2

/*
BITMASK (1 + 2 + 4)
0 - Don't deal damage or assign any lift kills at all
1 - Deal damage to enemy players and assign kills made by superlift's damage (SL only)
2 - Assign suicides of players who were lifted less then 3s ago (try to assign suicides due to fall damage)
4 - Modify XP/res for assigned kills
*/
#define MODE_KILL 7

/*
BITMASK (2)
0 - Don't show any help output at all
2 - Show usage when connecting   (Ignored if HELPER = 1)
*/
#define MODE_INFO 2
////////////////////////////////////////////////////////////////////////////////
//      NO need to edit anything below unless you know what you're doing      //
////////////////////////////////////////////////////////////////////////////////
#else
  #if MODE_AUTO == 1
    #define MODE_LIFT 0
    #define MODE_ATTACK 0
    #define MODE_KILL 0
  #else
    #define MODE_LIFT 1
    #define MODE_ATTACK 2
    #define MODE_KILL 7
  #endif
  #define MODE_INFO 2
#endif


#define LIFT_INACTIVE 0
#define LIFT_LIFTER 1
#define LIFT_LIFTED 2

#if MODE_LIFT == 0
  #define PLUGIN_NAME "LerkLift"
#else
  #define PLUGIN_NAME "SuperLift"
#endif
#define PLUGIN_VERSION "2.4"

#define GM_COMBAT  1
#define GM_CLASSIC 2
#define GM_MVA     4
#define GM_MVM     8
#define GM_AVA    16

#include <amxmodx>
#include <engine>
#include <ns>
#include <fun>
#include <fakemeta>
#if HELPER == 1
  #include <helper>
#endif

new ua_mode[33]
new ua_lift[33]
new Float:ua_offset[33]
new ua_allowed[33]
new ua_connected[33]
new Float:ua_lifttime[33]
new Float:ua_energytime[33]
new Float:ua_energy[33]

new g_maxplayers
new Float:g_gametime

#if MODE_LIFT == 1
new ua_sameteam[33]
new g_gamemode
new g_nsp

  #if MODE_KILL & 1
new gmsg_ScoreInfo
new Float:ua_damagetime[33]
new ua_scoreinfo[33][8]
new ua_scoreicon[33][33]
  #endif
  #if MODE_KILL & 2
new gmsg_DeathMsg
  #endif
#endif


public plugin_init(){
  register_plugin(PLUGIN_NAME,PLUGIN_VERSION,"mE @ PsiX.org")
#if MODE_LIFT == 1
  register_cvar("me_superlift",PLUGIN_VERSION,FCVAR_SERVER)
  if(cvar_exists("sv_structurelimit")) g_nsp = 1

  if(ns_get_build("team_command",0) == 0 && ns_get_build("team_hive",0) >= 2){
    g_gamemode |= GM_AVA
  }else if(ns_get_build("team_command",0) >= 2 && ns_get_build("team_hive",0) == 0){
    g_gamemode |= GM_MVM
  }else{
    g_gamemode |= GM_MVA
  }
  if(ns_is_combat()){
    g_gamemode |= GM_COMBAT
  }else{
    g_gamemode |= GM_CLASSIC
  }
  #if MODE_KILL & 1
    gmsg_ScoreInfo = get_user_msgid("ScoreInfo")
    register_message(gmsg_ScoreInfo,"lift_scoreinfo")
  #endif
  #if MODE_KILL & 2
    gmsg_DeathMsg = get_user_msgid("DeathMsg")
    register_message(gmsg_DeathMsg,"lift_deathmsg")
  #endif
  #if MODE_ATTACK == 2
    register_event("CurWeapon","lift_switchweapon","be","1=1")
  #endif
#else
  new version[33]
  format(version,32,"%s (%s)",PLUGIN_VERSION,PLUGIN_NAME)
  register_cvar("me_superlift",version,FCVAR_SERVER)
#endif
      
  g_maxplayers = get_maxplayers()
  register_clcmd("say /lifthelp",     "cmd_lift_help")
  register_clcmd("say /lifton",       "cmd_lift_on")
  register_clcmd("say /liftoff",      "cmd_lift_off")
  register_clcmd("say_team /lifthelp","cmd_lift_help")
  register_clcmd("say_team /lifton",  "cmd_lift_on")
  register_clcmd("say_team /liftoff", "cmd_lift_off")
}

public plugin_pause(){
  new found
  for(new i=0;i<=g_maxplayers;i++){
    if(ua_mode[i] != LIFT_LIFTER) continue

    lift_drop(i,ua_lift[i],7)
    found = 1
  }
  if(found){
    client_print(0,print_chat,"[%s] Lifting has just been disabled",PLUGIN_NAME)
  }
}

#if HELPER == 1
public client_help(id){
  help_add("Information","This plugin allows certain classes to pick up and carry around other classes")
  #if MODE_LIFT == 1
  help_add("Usage","USE other players to lift them as a JPer or lerk")
  #else
  help_add("Usage","You can lift friendly gorges by using them as a lerk")
  #endif
  help_add("Commands","Say /lifton to enable being lifted (default)^nSay /liftoff to disable")
}

public client_advertise(id){
  #if MODE_LIFT == 0
    if(pev(id,pev_team) & 1) return PLUGIN_HANDLED
  #endif
  return PLUGIN_CONTINUE
}
#endif

public client_PreThink(id){
  if(!ua_connected[id]) return PLUGIN_CONTINUE
  if(ua_mode[id] != LIFT_INACTIVE){
    if(ns_get_mask(id,MASK_DIGESTING)){
      if(ua_mode[id] == LIFT_LIFTER){
        lift_drop(id,ua_lift[id],7)
      }else{
        lift_drop(ua_lift[id],id,8)
      }
      return PLUGIN_CONTINUE
    }
  }
  
  if(pev(id,pev_button) & IN_USE && !(pev(id,pev_oldbuttons) & IN_USE)){
#if MODE_LIFT == 1
    if(ua_mode[id] == LIFT_LIFTED && ua_sameteam[id]){                        // user is being lifted by friend
      lift_drop(ua_lift[id],id,2)
      return PLUGIN_CONTINUE
    }
#else
    if(ua_mode[id] == LIFT_LIFTED){
      lift_drop(ua_lift[id],id,2)
      return PLUGIN_CONTINUE
    }
#endif
    if(ua_mode[id] == LIFT_LIFTER){                                                          // user is lifting somebody
      new ent,dummy
      get_user_aiming(id,ent,dummy,200)
      if(ent > g_maxplayers){
        new classname[33]
        pev(ent,pev_classname,classname,32)
        if(equal(classname,"func_button") || equal(classname,"func_door")){
          return PLUGIN_CONTINUE
        }
      }
      lift_drop(id,ua_lift[id],1)
      return PLUGIN_CONTINUE
    }
    if(ua_mode[id] == LIFT_INACTIVE){
      new class = ns_get_class(id)
#if MODE_LIFT == 1
      if(class != CLASS_LERK && class != CLASS_JETPACK) return PLUGIN_CONTINUE
#else
      if(class != CLASS_LERK) return PLUGIN_CONTINUE
#endif
      new ent,dummy
      get_user_aiming(id,ent,dummy,200)
      if(ent == 0 || ent > g_maxplayers) return PLUGIN_CONTINUE                 // not pointing at a player
      if(ua_mode[ent] != LIFT_INACTIVE) return PLUGIN_CONTINUE                  // player is already being lifted/lifting

      lift_pickup(id,ent)
      return PLUGIN_CONTINUE
    }
  }
  g_gametime = get_gametime()
  
  if(ua_mode[id] != LIFT_INACTIVE){                                             // either lifting or being lifted
#if MODE_LIFT == 1                                                              // if this is superlift
    if(get_team_type(id) == 2){                                                 // make sure we only set energy for aliens
#endif
    
    if(g_gametime-ua_energytime[id] > 0.1){
      new Float:energy = ns_get_energy(id)
      if(energy != 100.0 && energy == ua_energy[id]){
        new Float:energyadd = 7.8 * (g_gametime-ua_energytime[id])
        if(ns_get_mask(id,MASK_ADRENALINE)){
          if(ns_get_mask(id,MASK_MOVEMENT3)){
            energyadd *= 1.99
          }else if(ns_get_mask(id,MASK_MOVEMENT2)){
            energyadd *= 1.66
          }else{
            energyadd *= 1.33
          }
        }
        energy += energyadd
        if(energy > 100.0) energy = 100.0
        //client_print(id,print_console,"> added %.1f/%.1f percent energy",energyadd,energy)
        ns_set_energy(id,energy)
      }
      ua_energy[id]     = energy
      ua_energytime[id] = g_gametime
    }
    if(ua_mode[id] == LIFT_LIFTER) return PLUGIN_CONTINUE
    
#if MODE_LIFT == 1
    }else{                                                                    // this is a JPer
      if(ua_mode[id] == LIFT_LIFTER){                                         // make sure we adjust the offset if the lifter is a JPer
        if(pev(id,pev_flags) & FL_DUCKING){
          ua_offset[ua_lift[id]] = 8.0
        }else{
          ua_offset[ua_lift[id]] = 24.0
        }
        if(ns_get_class(ua_lift[id]) == CLASS_HEAVY){
          if(!ns_get_mask(id,MASK_PRIMALSCREAM)){
            lift_drop(id,ua_lift[id],7)
          }
        }
        return PLUGIN_CONTINUE                                                // below we only care about players being lifted
      }
    }
#endif
  }else{
    return PLUGIN_CONTINUE
  }

#if MODE_ATTACK == 1
  if(pev(id,pev_button) & IN_ATTACK){
    set_pev(id,pev_button,pev(id,pev_button)-IN_ATTACK)
  }
#endif
  
#if MODE_LIFT == 1
  if(!ua_sameteam[id]){
    if(!pev_f(id,pev_takedamage)){
      lift_drop(ua_lift[id],id,7)
      return PLUGIN_CONTINUE
    }
    if(entity_range(id,ua_lift[id]) > 300.0){                               // enemy lifter redeemed
      lift_drop(ua_lift[id],id,7)
      return PLUGIN_CONTINUE
    }
  #if MODE_KILL & 1
    if(ua_damagetime[id] < g_gametime){
      ua_damagetime[id] = g_gametime + 1.0
      new Float:damage  = 0.2 * (g_gametime-ua_lifttime[id]) * (g_gametime-ua_lifttime[id])
      if(damage < 10.0) damage = 10.0
      if(lift_hurt(id,ua_lift[id],damage)==2){
        lift_drop(ua_lift[id],id,4)
        return PLUGIN_CONTINUE
      }
    }
  #endif
  }
#endif
  new Float:origin[3]
  pev(ua_lift[id],pev_origin,origin)
  origin[2] -= ua_offset[id]
  set_pev(id,pev_origin,origin)
  
  new Float:velocity[3]
  pev(ua_lift[id],pev_velocity,velocity)
  velocity[2] = 0.0
  set_pev(id,pev_velocity,velocity)
  
  return PLUGIN_CONTINUE
}

public client_changeclass(id,newclass,oldclass){
  if(ua_mode[id] != LIFT_INACTIVE){
    if(ua_mode[id] == LIFT_LIFTER){
      lift_drop(id,ua_lift[id],7)
    }else{
#if MODE_LIFT == 1
      if(!lift_checkclass(id)){
        lift_drop(ua_lift[id],id,8)
      }else{
        if(!ua_sameteam[id] && newclass == CLASS_ONOS) lift_drop(ua_lift[id],id,8)
      }
#else
      if(!lift_checkclass(id)) lift_drop(ua_lift[id],id,8)
#endif
    }
  }
}

public client_changeteam(id,newteam,oldteam){
  if(ua_mode[id] != LIFT_INACTIVE){
    if(ua_mode[id] == LIFT_LIFTER){
      lift_drop(id,ua_lift[id],9)
    }else{
      lift_drop(ua_lift[id],id,10)
    }
    ua_mode[id] = LIFT_INACTIVE
    ua_lift[id] = 0
  }
}

public client_disconnect(id){
  ua_connected[id] = 0
  
  if(ua_mode[id] != LIFT_INACTIVE){
    if(ua_mode[id] == LIFT_LIFTER){
      lift_drop(id,ua_lift[id],5)
    }else{
      lift_drop(ua_lift[id],id,6)
    }
    ua_mode[id] = LIFT_INACTIVE
    ua_lift[id] = 0
  }
}

public client_putinserver(id){
  ua_connected[id] = 1
  
  new cpstring[33]
  get_user_info(id,"cp",cpstring,32)
  new cp = str_to_num(cpstring)
  if(cp & 1){
    ua_allowed[id] = 0
  }else{
    ua_allowed[id] = 1
  }
#if HELPER == 0 && MODE_INFO & 2
  set_task(5.0,"lift_usage",id)
#endif
}

lift_pickup(lifter,lifted){
  if(!lift_checkclass(lifted)){
#if MODE_LIFT == 1
    client_print(lifter,print_center,"Can't pick up that class")
#else
    client_print(lifter,print_center,"You can only pick up gorges")
#endif
    return 0
  }
  
  new sameteam = (pev(lifter,pev_team) == pev(lifted,pev_team)) ? 1 : 0

#if MODE_LIFT == 0
  if(!sameteam) return 0
  if(!ua_allowed[lifted]){
    client_print(lifter,print_center,"Player has disabled lifting")
    return 0
  }
  if(pev(lifted,pev_button) & IN_USE){
    client_print(lifter,print_center,"Player is currently using something")
    return 0
  }
#else
  new class = ns_get_class(lifted)
  if(sameteam){
    if(class == CLASS_HEAVY && !ns_get_mask(lifter,MASK_PRIMALSCREAM)){
      client_print(lifter,print_center,"You need Catalyst to pick up HA")
      return 0
    }
    if(class == CLASS_ONOS && !ns_get_mask(lifter,MASK_ADRENALINE)){
      client_print(lifter,print_center,"You need Adrenaline to pick up an Onos")
      return 0
    }
    if(!ua_allowed[lifted]){
      client_print(lifter,print_center,"Player has disabled lifting")
      return 0
    }
    if(pev(lifted,pev_button) & IN_USE){
      client_print(lifter,print_center,"Player is currently using something")
      return 0
    }
  }else{
    if(!pev_f(lifted,pev_takedamage)){
      client_print(lifter,print_center,"Can't pick up invincible enemies");
      return 0
    }
    if(class == CLASS_ONOS){
      client_print(lifter,print_center,"Can't pick up that class")
      return 0
    }
    if(class == CLASS_HEAVY && !ns_get_mask(lifter,MASK_ADRENALINE)){
      client_print(lifter,print_center,"You need Adrenaline to pick up a HA")
      return 0
    }
  }
#endif

  ua_mode[lifter] = LIFT_LIFTER
  ua_lift[lifter] = lifted
  
  ua_mode[lifted] = LIFT_LIFTED
  ua_lift[lifted] = lifter

#if MODE_LIFT == 1
  if(ns_get_class(lifter) == CLASS_LERK){
    ua_offset[lifted] = 8.0
  }else{
    ua_offset[lifted] = 24.0
  }
  ua_sameteam[lifted] = sameteam
#else
  ua_offset[lifted] = 8.0
#endif
  ua_lifttime[lifted] = g_gametime
  ua_energy[lifter]   = 0.0
  ua_energy[lifted]   = 0.0
#if MODE_LIFT == 1 && MODE_ATTACK == 2
  if(!sameteam){
    if(get_team_type(lifted) == 1){
      client_cmd(lifted,"drop")
      client_cmd(lifted,"weapon_knife")
    }
  }
#endif
  set_pev(lifted,pev_solid,SOLID_NOT)

  new username[33]
  get_user_name(lifted,username,32)

#if MODE_LIFT == 1
  client_print(lifter,print_center,"Picked up %s%s",(sameteam)?"":"(enemy) ",username)
  if(sameteam){
    get_user_name(lifter,username,32)
  }else{
    username = "enemy"
  }
  client_print(lifted,print_center,"Picked up by %s",username)
#else
  client_print(lifter,print_center,"Picked up %s",username)
  get_user_name(lifter,username,32)
  client_print(lifted,print_center,"Picked up by %s",username)
#endif
  return 1
}

/*
dropreason:
 0 - unknown
 1 - lifter stopped lifting (or is at least trying to do so)
 2 - lifted stopped lifting (or is at least trying to do so)
 3 - lifter died
 4 - lifted died
 5 - lifter disconnected
 6 - lifted disconnected
 7 - lifter invalid
 8 - lifted invalid
 9 - lifter changed team
10 - lifted changed team
*/

lift_drop(lifter,lifted,dropreason){
  if(dropreason == 1 || dropreason == 2){                                       // either player <tried> to stop lifting
    set_pev(lifted,pev_solid,SOLID_SLIDEBOX)
    new Float:origin[3]
    pev(lifted,pev_origin,origin)
    origin[2] += ua_offset[lifted]
    set_pev(lifted,pev_origin,origin)
    
    if(!lift_unstuck(lifted,lifter)){                                           // enforce LOS when unstucking
      if(dropreason == 1){
        new username[33]
        get_user_name(lifted,username,32)
        client_print(lifter,print_center,"Can't free %s",username)
      }else{
        client_print(lifted,print_center,"Can't be set free")
      }
      
      origin[2] -= ua_offset[lifted]
      set_pev(lifted,pev_origin,origin)
      set_pev(lifted,pev_solid,SOLID_NOT)
      return 0
    }
  }else{
    if(dropreason != 6){                                                        // if lifted still connected
      if(dropreason == 10){                                                     // if lifted changed team
        new Float:origin[3]                                                     // make sure we move him back to his last position, because this event is triggered a little too late
        pev(lifted,pev_oldorigin,origin)
        set_pev(lifted,pev_origin,origin)
      }else{                                                                    // if any other reason
        set_pev(lifted,pev_solid,SOLID_SLIDEBOX)                                // make player solid again, move him to the right position and force unstuck
        new Float:origin[3]
        pev(lifted,pev_origin,origin)
        origin[2] += ua_offset[lifted]
        set_pev(lifted,pev_origin,origin)
    
        lift_unstuck(lifted,0)
      }
    }
  }

  ua_mode[lifter]   = LIFT_INACTIVE
  ua_lift[lifter]   = 0
  
  ua_mode[lifted]   = LIFT_INACTIVE
  //ua_lift[lifted] = 0
  ua_lifttime[lifted] = g_gametime

  if(dropreason != 5 && dropreason != 6){                                       // both players are still connected
    new Float:velocity[3]                                                       // apply lifter's velocity to lifted
    pev(lifter,pev_velocity,velocity)
    set_pev(lifted,pev_velocity,velocity)
  }
  
  switch(dropreason){
    case 1:{
      new username[33]
      get_user_name(lifted,username,32)
      client_print(lifter,print_center,"Released %s",username)
      client_print(lifted,print_center,"Your Lifter dropped you")
    }
    case 2:{
      client_print(lifter,print_center,"Lifted detached himself")
      client_print(lifted,print_center,"Released from Lifter")
    }
    case 3:{
      new username[33]
      get_user_name(lifted,username,32)
      client_print(lifted,print_center,"Released dead %s",username)
    }
    case 4:{
      client_print(lifter,print_center,"Lifted just died")
    }
    case 5:{
      client_print(lifted,print_center,"Your Lifter disconnected")
    }
    case 6:{
      client_print(lifter,print_center,"Lifted disconnected")
    }
    case 7:{
      new username[33]
      get_user_name(lifted,username,32)
      client_print(lifter,print_center,"Can no longer lift %s",username)
      client_print(lifted,print_center,"You can no longer be lifted")
    }
    case 8:{
      client_print(lifter,print_center,"You can no longer lift")
      client_print(lifted,print_center,"Lifter can no longer lift")
    }
    case 9:{
      client_print(lifted,print_center,"Lifter just left the battlefield")
    }
    case 10:{
      client_print(lifter,print_center,"Lifted just left the battlefield")
    }
  }
  return 1
}

public cmd_lift_on(id){
  if(ua_allowed[id]){
    client_print(id,print_chat,"[%s] Lifting already enabled",PLUGIN_NAME)
  }else{
    new cpstring[33]
    get_user_info(id,"cp",cpstring,32)
    new cp = str_to_num(cpstring)
    if(cp & 1){
      cp -= 1
    }
    if(!(cp & 1024)){                                                           // add useless flag - just to make sure the whole userinfo is never empty
      cp += 1024
    }
    num_to_str(cp,cpstring,32)
    set_user_info(id,"cp",cpstring)
  
    ua_allowed[id] = 1
    client_print(id,print_chat,"[%s] Lifting enabled",PLUGIN_NAME)
  }
}

public cmd_lift_off(id){
  if(!ua_allowed[id]){
    client_print(id,print_chat,"[%s] Lifting already disabled",PLUGIN_NAME)
  }else{
    new cpstring[33]
    get_user_info(id,"cp",cpstring,32)
    new cp = str_to_num(cpstring)
    if(!(cp & 1)){
      cp += 1
    }
    num_to_str(cp,cpstring,32)
    set_user_info(id,"cp",cpstring)

    ua_allowed[id] = 0
    client_print(id,print_chat,"[%s] Lifting disabled",PLUGIN_NAME)
    
#if MODE_LIFT == 1
    if(ua_mode[id] == LIFT_LIFTED && ua_sameteam[id]){
#else
    if(ua_mode[id] == LIFT_LIFTED){
#endif
      lift_drop(ua_lift[id],id,2)
    }
  }
}

public cmd_lift_help(id){
#if HELPER == 1
  client_print(id,print_chat,"[%s] Say /help instead",PLUGIN_NAME)
#else
  #if MODE_LIFT == 1
  client_print(id,print_chat,"[SuperLift] USE other players to lift them as a JPer or lerk")
  #else
  client_print(id,print_chat,"[LerkLift] You can lift friendly gorges by using them as a lerk")
  #endif
#endif
}

#if HELPER == 0 && MODE_INFO & 2
public lift_usage(id){
  if(ua_connected[id]){
  #if MODE_LIFT == 1
    client_print(id,print_chat,"[SuperLift] Lerks and JPers can lift players! Say /lifthelp")
    client_print(id,print_chat,"[SuperLift] Version %s by mE enabled. Say /lifton or /liftoff to enable/disable",PLUGIN_VERSION)
  #else
    client_print(id,print_chat,"[LerkLift] Lerks can lift friendly gorges! Say /lifthelp")
    client_print(id,print_chat,"[LerkLift] Version %s by mE enabled. Say /lifton or /liftoff to enable/disable",PLUGIN_VERSION)
  #endif
  }
}
#endif

#if MODE_LIFT == 1
  #if MODE_KILL & 1
lift_hurt(id,attacker,Float:dmg){
  new Float:health = pev_f(id,pev_health)
  new Float:armor  = pev_f(id,pev_armorvalue)

  if(armor >= 1.0){
    new Float:dmg_parts = dmg / 3.0
    new Float:dmg_armor = dmg_parts * 1.14
    if(armor-dmg_armor < 1.0){
      health -= (dmg_parts + dmg_armor - armor) * 1.14
      armor   = 0.0
    }else{
      health -= dmg_parts
      armor  -= dmg_armor
    }
  }else{
    health -= dmg
  }

  if(health < 1.0){
    set_msg_block(gmsg_DeathMsg,BLOCK_ONCE)
    fakedamage(id,"trigger_hurt",10000.0,1)
        
    ua_scoreinfo[attacker][1] ++
    set_user_frags(attacker,ua_scoreinfo[attacker][1])

    new i
    message_begin(MSG_ALL, gmsg_ScoreInfo)
    write_byte(attacker)
    write_short(ua_scoreinfo[attacker][i++])	                        // score
    write_short(ua_scoreinfo[attacker][i++])	                        // frags
    write_short(ua_scoreinfo[attacker][i++])	                        // deaths
    if(g_nsp){
      write_short(ua_scoreinfo[attacker][i++])                          // type
    }
    write_byte (ua_scoreinfo[attacker][i++])	                        // class
    write_short(ua_scoreinfo[attacker][i++])	                        // auth status
    write_short(ua_scoreinfo[attacker][i++])	                        // team
    if(g_nsp){
      write_short(ua_scoreinfo[attacker][i++])                          // health
    }
    write_string(ua_scoreicon[attacker])                                    // icon
    message_end()
    
    message_begin(MSG_ALL, gmsg_DeathMsg)
    write_byte(attacker)
    write_byte(id)
    write_string("lift")
    message_end()
    
    #if MODE_KILL & 4
    if(g_gamemode & GM_COMBAT){
      ns_set_exp(attacker,ns_get_exp(attacker) + float( lift_getlevel(attacker) * 10 + 50 ) )
    }else{
      if(get_team_type(attacker) == 2){
        ns_set_res(id,ns_get_res(id) + float(random_num(1,3)))
      }
    }
    #endif
    
    return 2
  }else{
    set_pev(id,pev_armorvalue,armor)
    set_pev(id,pev_health,health)
  }
  return 1
}
    
public lift_scoreinfo(){
  new id = get_msg_arg_int(1)

  new i
  ua_scoreinfo[id][i++] = get_msg_arg_int(i+1) // score
  ua_scoreinfo[id][i++] = get_msg_arg_int(i+1) // frags
  ua_scoreinfo[id][i++] = get_msg_arg_int(i+1) // deaths
  if(g_nsp){
    ua_scoreinfo[id][i++] = get_msg_arg_int(i+1) // type
  }
  ua_scoreinfo[id][i++] = get_msg_arg_int(i+1) // class
  ua_scoreinfo[id][i++] = get_msg_arg_int(i+1) // auth
  ua_scoreinfo[id][i++] = get_msg_arg_int(i+1) // team
  if(g_nsp){
    ua_scoreinfo[id][i++] = get_msg_arg_int(i+1) // health
  }
  get_msg_arg_string(8,ua_scoreicon[id],32)// icon
}
  #endif

  #if MODE_KILL & 2
public lift_deathmsg(){
  new killer = get_msg_arg_int(1)
  new id     = get_msg_arg_int(2)
  if(killer == 0 && ua_mode[id] == LIFT_INACTIVE && ua_lift[id]){           // this is a suicide of a player who has been lifted before
    if(g_gametime-ua_lifttime[id] < 3.0){                                   // if he was dropped less than 3s ago
      killer = ua_lift[id]
      ua_scoreinfo[killer][1] += 1
      set_user_frags(killer,ua_scoreinfo[killer][1])

      new i
      message_begin(MSG_ALL, gmsg_ScoreInfo)
      write_byte(killer)
      write_short(ua_scoreinfo[killer][i++])	// score
      write_short(ua_scoreinfo[killer][i++])	// frags
      write_short(ua_scoreinfo[killer][i++])	// deaths
      if(g_nsp){
        write_short(ua_scoreinfo[killer][i++])      // type
      }
      write_byte (ua_scoreinfo[killer][i++])	// class
      write_short(ua_scoreinfo[killer][i++])	// auth status
      write_short(ua_scoreinfo[killer][i++])	// team
      if(g_nsp){
        write_short(ua_scoreinfo[killer][i++])                          // health
      }
      write_string(ua_scoreicon[killer])            // icon
      message_end()
      
      set_msg_arg_int(1,ARG_BYTE,killer)
      set_msg_arg_string(3,"lift")
    }
    ua_lift[id] = 0
  }
}
  #endif

  #if MODE_ATTACK == 2
public lift_switchweapon(id){
  if(ua_mode[id] != LIFT_LIFTED) return PLUGIN_CONTINUE
  if(ua_sameteam[id]) return PLUGIN_CONTINUE
  if(get_team_type(id) != 1) return PLUGIN_CONTINUE

  client_cmd(id,"weapon_knife")

  return PLUGIN_CONTINUE
}
  #endif
  
  #if MODE_KILL & 4
lift_getlevel(index) {
  new userxp = floatround(ns_get_exp(index))
  new addd=100,temp=0,level=0
  while(temp <= userxp){
    temp  += addd
    addd  += 50
    level ++
  }
  return level
}
  #endif
  
get_team_type(id){
  new team = pev(id,pev_team)
  if(team == 0) return 0                                                      // ready room/spectator
  if(g_gamemode & GM_MVM) return 1                                            // MvM must be marine
  if(g_gamemode & GM_AVA) return 2                                            // AvA must be alien
  return team                                                                 // MvA must be teamflag
}
#endif

lift_checkclass(id){
  new class = ns_get_class(id)
#if MODE_LIFT == 1
  if(class == CLASS_GESTATE) return 1
  if(class == CLASS_SKULK)   return 1
  if(class == CLASS_GORGE)   return 1
  if(class == CLASS_ONOS)    return 1
  if(ns_get_mask(id,MASK_JETPACK)) return 0
  if(class == CLASS_MARINE)  return 1
  if(class == CLASS_HEAVY)   return 1
#else
  if(class == CLASS_GESTATE) return 1
  if(class == CLASS_GORGE)   return 1
#endif
  return 0
}

lift_unstuck(id,req_los){
  new Float:old_origin[3]
  pev(id,pev_origin,old_origin)

  new hullsize = getHullSize(id)
  new maxdist  = (req_los?300:1000)
  new distance = 32
  new Float:new_origin[3]
  while( distance < maxdist ) {
    for (new i = 0; i < 128; ++i) {
      new_origin[0] = random_float(old_origin[0]-distance,old_origin[0]+distance)
      new_origin[1] = random_float(old_origin[1]-distance,old_origin[1]+distance)
      new_origin[2] = random_float(old_origin[2]-distance,old_origin[2]+distance)

      if (trace_hull(new_origin, hullsize, id) == 0 ) {
        if(hullsize == HULL_LARGE) new_origin[2] += 16.0                        // HULL_LARGE seems to be reported incorrectly
        entity_set_origin(id, new_origin)
        
        if(req_los){                                                            // require line of sight?
          new Float:unused[3]
          new hit = trace_line(req_los,old_origin,new_origin,unused)
          if(hit != id){                 // if tracing from old_origin (ignoring req_los) to new origin doesnt hit lifted (id), try again
            //client_print(id,print_console,"> Hit %d instead",hit)
            continue
          }
        }
        return 1
      }
    }
    distance += 32
  }
  entity_set_origin(id,old_origin)
  return 0
}

getHullSize(id) {
  switch (ns_get_class(id)) {
    case CLASS_GESTATE,CLASS_SKULK,CLASS_GORGE,CLASS_LERK:
      return HULL_HEAD
    case CLASS_FADE,CLASS_MARINE,CLASS_JETPACK,CLASS_HEAVY:
      return (pev(id,pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN
    case CLASS_ONOS:
      return (pev(id,pev_flags) & FL_DUCKING) ? HULL_HUMAN : HULL_LARGE
    default:
      return HULL_LARGE
  }
  return HULL_LARGE
}

stock Float:pev_f(ent,_pev){
  new Float:ret
  pev(ent,_pev,ret)
  return ret
}

