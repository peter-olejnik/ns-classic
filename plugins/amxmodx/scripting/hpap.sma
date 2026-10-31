/*
*	Author: Cpt.hans
*
*
*	History:
*
*		v1.0
*		-initial release
*		v1.1
*		added: Plugin now shows max hp and max armor.
*		v1.2
*		-changed the way the plugin gets max hp and ap
*		v1.3
*		-fixed: Info Message no longer shows when you killed yourself
*		-fixed: Plugin will no longer show negative HP
*
*
*/




#include <amxmodx>
#include <engine>
#include <ns>
#define HUD_CHANNEL	1

#define VERSION		"1.3"

new Float:maxHP[33], maxAP[33]
new g_Classname[] = "timer01"

public plugin_init()
{
   register_plugin("Hp/Ap Info", VERSION, "Cpt.Hans")
   register_event("DeathMsg", "hook_death", "a", "1>0")
   register_cvar("Hp_Ap_Info",VERSION,FCVAR_SERVER)

   new Ent = create_entity("info_target")
   entity_set_string(Ent,EV_SZ_classname,g_Classname)
   entity_set_float(Ent,EV_FL_nextthink,halflife_time() + 5.0)
   register_think(g_Classname,"timer1Think")
}

public hook_death(id)
{
new Killerid = read_data(1)
new Victimid = read_data(2)
maxHP[Killerid] = entity_get_float(Killerid, EV_FL_max_health)
maxAP[Victimid] = 0
new Killername[128]
new Victimname[128]
get_user_name ( Killerid, Killername, 127 )
get_user_name ( Victimid, Victimname, 127 )
new Float:dist = entity_range(Killerid, Victimid)
dist = dist/100.0
new class[16]
switch ( ns_get_class(Killerid) ) {
			case CLASS_SKULK:	class = "SKULK"
			case CLASS_GORGE:	class = "GORGE"
			case CLASS_LERK:	class = "LERK"
			case CLASS_FADE:	class = "FADE"
			case CLASS_ONOS:	class = "ONOS"
			case CLASS_GESTATE:	class = "GEST"
			case CLASS_DEAD:	class = "DEAD"
			case CLASS_COMMANDER:	class = "COMM"
			case CLASS_MARINE:	class = "Marine"
			case CLASS_HEAVY:	class = "Heavy Armor"
			case CLASS_JETPACK:	class = "Jetpacker"
		}
new killerweapon[32]
read_data(3,killerweapon,31)
new armor = get_user_armor (Killerid)
new health = get_user_health (Killerid)
if (health < 0)
	health=0
set_hudmessage(234,113,50, 0.028, 0.15, 1, 0.5, 15.0, 0.5, 0.5, HUD_CHANNEL)
if(Victimid==Killerid)
	show_hudmessage(Victimid,"Congratulations! You killed yourself.")
else
	show_hudmessage(Victimid, "Killer Info ^nName:%s ^nHP:%d/%0.0f ^nAP:%d/%d ^nClass:%s ^nWeapon:%s ^nDistance:%.2fm",Killername,health,maxHP[Killerid],armor,maxAP[Killerid],class,killerweapon,dist)
return PLUGIN_HANDLED
}


public client_changeclass(id)
{
	maxAP[id] = 0
}

public timer1Think(Ent)
{
	for(new i=1; i<=32; i++)
	{	
		if((get_user_armor(i) > maxAP[i]) && is_user_connected(i))
			maxAP[i] = get_user_armor(i)
	}
			
	entity_set_float(Ent,EV_FL_nextthink, halflife_time() + 3.0)
}
