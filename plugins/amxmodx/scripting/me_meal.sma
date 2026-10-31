////////////////////////////////////////////////////////////////////////////////
//                            Information                                     //
////////////////////////////////////////////////////////////////////////////////
/*
Meal (v3.3 - 01.10.06)
By: mE @ PsiX.org

Description:
  This plugin was initially created to remove the default corpses with some gibs
  for aliens to gain health from and has since evolved into plugin that (just)
  adds alot of atmosphere to natural selection.
  If alot of damage (default setting, adjustable: 40dmg within the last 0.2s
  before the death) is dealt to a player, he'll explode into gibs.

Installation:
  Set the desired defines below and just install this plugin like any other.

Configuration:
  (All cvars default to 1.0)
  Use the following cvars as factors (e.g. 2.0 being "twice as much as default")
    violence_agibs  - amount of alien gibs
    violence_hgibs  - amount of human (marine) gibs

    (The following cvars will only work if you've set MEAL_BLEED to 1)
    violence_ablood - amount of alien blood
    violence_hblood - amount of human blood
  Notice: These cvars are probably already set to 0.0 within your server.cfg!
          Keeping these settings, this plugin will be disabled, so make sure you
          edit them there.
*/
////////////////////////////////////////////////////////////////////////////////
//                           Configuration                                    //
////////////////////////////////////////////////////////////////////////////////

/* INT (0)
0 - disable additional bleeding
1 - enable bleeding when being hit
*/
#define MEAL_BLEED 1

/* FLOAT (0.2)
X.X - time to wait between drawing blood when being hit
*/
#define MEAL_BLEEDTIME 0.2

/* FLOAT (0.2)
X.X - time to take into account when counting damage to decide whether one is supposed to splatter (explode into gibs)
*/
#define MEAL_DMGTIME 1.0

/* FLOAT (40.0)
X.X - Damage (influenced within the last X seconds (above define)) required to explode
      (Default setting: Player will explode when 40.0 damage has been dealed to him within the last 0.2 seconds)
*/
#define MEAL_DMGEXPLODE 20.0
////////////////////////////////////////////////////////////////////////////////
//      NO need to edit anything below unless you know what you're doing      //
////////////////////////////////////////////////////////////////////////////////

#define MEAL_DMGNUM   128     // # maximum number of dmgs to remember

#include <amxmodx>
#include <ns>
#include <engine>

new g_mdl_agibs
new g_mdl_hgibs

new g_damage_num = 0
new g_damage_user[MEAL_DMGNUM]
new Float:g_damage_amount[MEAL_DMGNUM]
new Float:g_damage_time[MEAL_DMGNUM]

new ua_deathclass[33]
new ua_connected[33]

#if MEAL_BLEED == 1
  new Float:ua_bleedtime[33]
  new g_spr_blood
  new g_spr_bloodspray
#endif

public plugin_precache(){
  precache_sound("common/bodysplat.wav")

  g_mdl_agibs = precache_model("models/agibs.mdl")
  g_mdl_hgibs = precache_model("models/hgibs.mdl")

  #if MEAL_BLEED == 1
    g_spr_blood      = precache_model("sprites/blood.spr")
    g_spr_bloodspray = precache_model("sprites/bloodspray.spr")
  #endif
}

public plugin_init(){
  register_plugin("Marine Meal","3.3","mE @ PsiX.org")
  register_cvar("me_meal","3.3",FCVAR_SERVER)

  register_event("Damage","meal_damage","b")
  register_event("DeathMsg","meal_deathmsg","ac")

  register_cvar("violence_agibs","2.0")
  register_cvar("violence_hgibs","2.0")

  #if MEAL_BLEED == 1
    register_cvar("violence_ablood","2.0")
    register_cvar("violence_hblood","2.0")
  #endif
}

//////////////////////////////// CLIENT ACTIONS ////////////////////////////////

public client_disconnect(id){
  ua_deathclass[id] = CLASS_UNKNOWN
  ua_connected[id] = false
}

public client_putinserver(id){
  ua_connected[id] = true
}

public client_changeteam(id,newteam,oldteam){
  ua_deathclass[id] = CLASS_UNKNOWN
}

///////////////////////////////// MESSAGES /////////////////////////////////////

public meal_damage(id){
  new Float:damage
  read_data(2,damage)
  if(damage > 0.0){
    new Float:gametime = get_gametime()
    g_damage_user[g_damage_num]   = id
    g_damage_time[g_damage_num]   = gametime + MEAL_DMGTIME
    g_damage_amount[g_damage_num] = damage

    g_damage_num = (g_damage_num + 1) % MEAL_DMGNUM

    #if MEAL_BLEED == 1
      if(gametime > ua_bleedtime[id]){
        ua_bleedtime[id] = gametime + MEAL_BLEEDTIME
        meal_fx_bleed(id)
      }
    #endif
  }
}

public meal_deathmsg(){
  new victim = read_data(2)
  if(!ua_connected[victim]) return PLUGIN_CONTINUE

  ua_deathclass[victim] = ns_get_class(victim)
  set_task(0.01,"meal_checkdamage",victim)                                      // damage will be sent afterwards. so we'll have to delay the check

  return PLUGIN_CONTINUE
}

public meal_checkdamage(victim){
  new Float:gametime = get_gametime()
  new Float:damage = 0.0
  for(new i=0;i<MEAL_DMGNUM;i++){
    if(g_damage_user[i] != victim) continue
    if(g_damage_time[i] < gametime) continue
    damage += g_damage_amount[i]
  }
  if(damage >= MEAL_DMGEXPLODE){
    meal_fx_splatter(victim)
  }
}

#if MEAL_BLEED == 1
  meal_fx_bleed(id){
    new origin[3]
    get_user_origin(id,origin)

    new color = entity_get_int(id,EV_INT_team)&1?70:56                          // 70 for marines, 56(?!) for aliens
    new scale = floatround(8.0 * get_cvar_float(color==70?"violence_hblood":"violence_ablood"))

    if(scale <= 0) return
    if(scale > 200) scale = 200

    message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
    write_byte(115) // TE_BLOODSPRITE
    write_coord(origin[0])
    write_coord(origin[1])
    write_coord(origin[2]+10)
    write_short(g_spr_bloodspray)// sprite spray
    write_short(g_spr_blood)     // sprite drop
    write_byte(color)               // color
    write_byte(scale)               // scale
    message_end()

    return
  }
#endif

meal_fx_splatter(victim){
  if(ua_deathclass[victim] == CLASS_UNKNOWN) return

  new Float:multi
  switch(ua_deathclass[victim]){
    case CLASS_GORGE,CLASS_LERK:
      multi = 1.2
    case CLASS_ONOS:
      multi = 5.0
    case CLASS_FADE,CLASS_MARINE,CLASS_JETPACK:
      multi = 2.0
    case CLASS_HEAVY:
      multi = 3.0
    default:
      multi = 1.0
  }
  new maxgibs = floatround(10 * get_cvar_float(entity_get_int(victim,EV_INT_team)&1?"violence_hgibs":"violence_agibs") * multi)
  if(maxgibs <= 0) return
  if(maxgibs > 64) maxgibs = 64                                                 // avoid creating an insane amount of gibs

  for(new i=0;i<maxgibs;i++){
    meal_fx_gib(victim)
  }
  entity_set_int(victim,EV_INT_rendermode,5)                                    // remove normal corpse
  entity_set_float(victim,EV_FL_renderamt,0.0)

  emit_sound(victim,CHAN_ITEM,"common/bodysplat.wav",1.0,ATTN_NORM,0,PITCH_NORM)
  return
}

meal_fx_gib(victim){
  new origin[3]
  get_user_origin(victim,origin)
  origin[0] += random_num(-32,32)
  origin[1] += random_num(-32,32)
  origin[2] += random_num(  0,32)

  message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
  write_byte(106) // TE_MODEL
  write_coord(origin[0])
  write_coord(origin[1])
  write_coord(origin[2])
  write_coord(random_num(-400,400))
  write_coord(random_num(-400,400))
  write_coord(random_num( -10,400))
  write_angle(random_num(-180,180))
  write_short(entity_get_int(victim,EV_INT_team)&1?g_mdl_hgibs:g_mdl_agibs)
  write_byte(0)
  write_byte(random_num(100,250)) // 10 to 25 seconds
  message_end()
}
