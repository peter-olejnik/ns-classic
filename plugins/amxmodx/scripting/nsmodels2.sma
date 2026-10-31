
/*
* NS Model Changer - Server 2
* Created for the NS<BAD>Clan Server by TinCan
*
* Ver 1.3 - Modified to exclude gorges on server 2
* Ver 1.2 - Skulk model released!
* Ver 1.1 - Added ability to change Onos model too.
* Ver 1.0 - Initial release only has ability to change gorge model.
*/

#include <amxmodx>
#include <engine>
#include <ns>

#define PLUGIN "nsmodels2"
#define VERSION "1.3"
#define AUTHOR "TinCan"



#define EVOLVE_SKULK 113
#define EVOLVE_GORGE 114
#define EVOLVE_LERK 115
#define EVOLVE_FADE 116
#define EVOLVE_ONOS 117



 
#define IMPULSE_CARAPACE 101   
#define IMPULSE_REGENERATION 102
#define IMPULSE_REDEMPTION 103
#define IMPULSE_CELERITY 107
#define IMPULSE_ADRENALINE 108
#define IMPULSE_SILENCE 109
#define IMPULSE_CLOAKING 110
#define IMPULSE_FOCUS 111
#define IMPULSE_SCENT 112



//************************************************************
//Set path/ModelName.mdl below:

//#define GORGE_MODEL   "models/gorgieegg.mdl"
#define SKULK_MODEL   "models/ns2_alien1.mdl"
//#define GORGE_MODEL   "models/ns2_alien2.mdl"
#define ONOS_MODEL   "models/ns2_alien5.mdl"

//************************************************************

 
public plugin_init() {
   register_plugin(PLUGIN, VERSION, AUTHOR)

   register_impulse(EVOLVE_SKULK,"skulkhook")
   register_impulse(EVOLVE_GORGE,"gorgehook")
   register_impulse(EVOLVE_LERK,"lerkhook")
   register_impulse(EVOLVE_FADE,"fadehook")
   register_impulse(EVOLVE_ONOS,"onoshook")
   
   
   register_impulse(IMPULSE_CARAPACE, "carapacehook")
   register_impulse(IMPULSE_REGENERATION, "regenerationhook")
   register_impulse(IMPULSE_REDEMPTION, "redemptionhook")
   register_impulse(IMPULSE_CELERITY, "celerityhook")
   register_impulse(IMPULSE_ADRENALINE, "adrenalinehook")
   register_impulse(IMPULSE_SILENCE, "silencehook")
   register_impulse(IMPULSE_CLOAKING, "cloakinghook")
   register_impulse(IMPULSE_FOCUS, "focushook")
   register_impulse(IMPULSE_SCENT, "scenthook")
}


public plugin_precache() {
   precache_model(SKULK_MODEL);
//   precache_model(GORGE_MODEL);
   precache_model(ONOS_MODEL);
} 

public client_spawn(id) {
if (entity_get_int(id,EV_INT_team) == 2) {
ns_set_player_model (id, SKULK_MODEL)
}
else {
ns_set_player_model (id)
}
return PLUGIN_CONTINUE
} 

public client_changeteam(id, newteam, oldteam) {
   ns_set_player_model (id)
   return PLUGIN_CONTINUE
}
      
//*****************************************************

public carapacehook(id) {
   ns_set_player_model (id)
   new param[1]
   param[0] = id
   set_task(3.1, "check_class",_,param,1) //
   return PLUGIN_CONTINUE
}

public regenerationhook(id) {
   ns_set_player_model (id)
   new param[1]
   param[0] = id
   set_task(3.1, "check_class",_,param,1) //
   return PLUGIN_CONTINUE
}

public redemptionhook(id) {
   ns_set_player_model (id)
   new param[1]
   param[0] = id
   set_task(3.1, "check_class",_,param,1) //
   return PLUGIN_CONTINUE
}

public celerityhook(id) {
   ns_set_player_model (id)
   new param[1]
   param[0] = id
   set_task(3.1, "check_class",_,param,1) //
   return PLUGIN_CONTINUE
}

public adrenalinehook(id) {
   ns_set_player_model (id)
   new param[1]
   param[0] = id
   set_task(3.1, "check_class",_,param,1) //
   return PLUGIN_CONTINUE
}

public silencehook(id) {      
   ns_set_player_model (id)
   new param[1]
   param[0] = id
   set_task(3.1, "check_class",_,param,1) //
   return PLUGIN_CONTINUE
}

public cloakinghook(id) {
   ns_set_player_model (id)
   new param[1]
   param[0] = id
   set_task(3.1, "check_class",_,param,1) //
   return PLUGIN_CONTINUE
}

public focushook(id) {
   ns_set_player_model (id)
   new param[1]
   param[0] = id
   set_task(3.1, "check_class",_,param,1) //
   return PLUGIN_CONTINUE
}

public scenthook(id) {
   ns_set_player_model (id)
   new param[1]
   param[0] = id
   set_task(3.1, "check_class",_,param,1) //
   return PLUGIN_CONTINUE
}

//*******************************************
public check_class(param[1]){
   new id
   id = param[0]
   new class = ns_get_class(id)
   
   if ( class == CLASS_SKULK ){
   ns_set_player_model (id, SKULK_MODEL)
   }

   else if ( class == CLASS_GORGE ){
   ns_set_player_model (id)
   }

   else if ( class == CLASS_LERK ){
   ns_set_player_model (id)
   }

   else if ( class == CLASS_FADE ){
   ns_set_player_model (id)
   }

   else if ( class == CLASS_ONOS ){
   ns_set_player_model (id, ONOS_MODEL)
   }
   return PLUGIN_CONTINUE   
}
//********************************************
public skulkhook(id) {
   if(is_user_bot(id))
      return PLUGIN_CONTINUE
   new param[1]
   param[0] = id
   set_task(Float:2.9, "change_skulkmodel",_,param,1)
   return PLUGIN_CONTINUE
}

public gorgehook(id) {
   ns_set_player_model (id)
   return PLUGIN_CONTINUE
}   

public lerkhook(id) {
   ns_set_player_model (id)
   return PLUGIN_CONTINUE
}
public fadehook(id) {
   ns_set_player_model (id)
   return PLUGIN_CONTINUE
}
public onoshook(id) {
   if(is_user_bot(id))
      return PLUGIN_CONTINUE
   new param[1]
   param[0] = id
   set_task(Float:34.9, "change_onosmodel",_,param,1) //check time to gestate
   return PLUGIN_CONTINUE
}

//*********************************************

public change_skulkmodel(param[1]) {
   new id = param[0]
   ns_set_player_model (id, SKULK_MODEL)
   return PLUGIN_CONTINUE
} 

public change_onosmodel(param[1]) {
   new id = param[0]
   ns_set_player_model (id, ONOS_MODEL)
   return PLUGIN_CONTINUE
} 
