
#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <ns>

#define PLUGIN "Marine Model"
#define VERSION "1.0"
#define AUTHOR "TinCan"
#define MARINE_MODEL   "models/player/soldier/mpumpkin.mdl"
#define JETPACK_MODEL    "models/player/soldier/mpumpkin.mdl"

public plugin_init()
{
   register_plugin(PLUGIN, VERSION, AUTHOR)
   register_touch("item_heavyarmor","player","HeavyTouch")
   register_touch("item_jetpack","player","JetPackTouch")
}

public plugin_precache()
{
   precache_model(MARINE_MODEL)
   precache_model(JETPACK_MODEL)
}

public client_spawn(id)
{
   if( entity_get_int( id,EV_INT_team ) == 1 )
   {
      ns_set_player_model( id, MARINE_MODEL )
   }
}

public client_changeteam( id, newteam, oldteam )
{
   ns_set_player_model( id )
}

public round_start()
{
   for( new i = 1; i < get_maxplayers(); i++ )
   {
      if( entity_get_int( i,EV_INT_team ) == 1 )
      {
         ns_set_player_model( i, MARINE_MODEL )
      }
   }
}

public HeavyTouch(ptr,ptd)
{
   if(pev(ptd,pev_team) == 1 )
   {
      new ptd_classname[32]
      entity_get_string(ptd,EV_SZ_classname,ptd_classname,31)
      if (equal(ptd_classname,"player"))
      {
         new class = ns_get_class(ptd)
         if(class == CLASS_MARINE)
         {
            ns_set_player_model( ptd )         
         }
      }
   }
}

public JetPackTouch(ptr,ptd)
{
   if(pev(ptd,pev_team) == 1 )
   {
      new ptd_classname[32]
      entity_get_string(ptd,EV_SZ_classname,ptd_classname,31)
      if (equal(ptd_classname,"player"))
      {
         new class = ns_get_class(ptd)
         if(class == CLASS_MARINE)
         {
            ns_set_player_model( ptd, JETPACK_MODEL )               
         }
      }
   }
}
