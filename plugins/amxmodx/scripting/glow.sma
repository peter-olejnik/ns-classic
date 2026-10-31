/* 	This glow plugin created by devicenull 
	was hacked into working	order for the 
	NS<BAD>Clan server by TinCan.
*/	
#include <amxmodx>
#include <engine>
#include <engine_stocks>
#include <fun>
new g_IsMadeAvA = 0
public plugin_init() {
	register_plugin("AutoGlow","0.2a","devicenull/TinCan")
	new cc, ava, ccount 
	cc = find_ent_by_class(0,"team_command")
	new sInfo[8] // place holder for localinfo
	get_localinfo("is_made_ava", sInfo, 7) // Check if AvA is active (shows as 1 in sinfo)
	g_IsMadeAvA = str_to_num(sInfo) // convert sInfo into a number
	while (cc != 0) { 
		client_print ( 0, print_chat, "cc" ) 
		ccount++
		cc = find_ent_by_class(cc,"team_command")
	}
	if( g_IsMadeAvA )	// Here is where it looks to see if ava is enabled and set ava to 1 if it is...
	{
		ava = 1
	}
	server_print("Glow: %i CC's and ava status is %i",ccount,ava)
	if (ccount == 2 || ava == 1) {		
		pause("ac", "spawninvfun.amxx") // Hopefully this will pause the spawn protection plugin to allow for glowing teams		
		register_event("ResetHUD","doglow","b")
		register_event("PlayHUDNot","glowb","b")
		glowb()
	}
}
public doglow(id) {
	set_task(Float:0.5,"glowme",id)
}
public glowme(id) {
	new team[32]
	get_user_team(id,team,32)
	
	if (equal(team,"marine1team"))
		set_user_rendering(id,kRenderFxGlowShell,0,170,255,kRenderNormal,10)//blue Marine
	if (equal(team,"marine2team"))
		set_user_rendering(id,kRenderFxGlowShell,200,0,0,kRenderNormal,10)//red marine
	if (equal(team,"alien1team"))
		set_user_rendering(id,kRenderFxGlowShell,255,170,0,kRenderNormal,10)// yellow Alein
	if (equal(team,"alien2team"))
		set_user_rendering(id,kRenderFxGlowShell,200,0,0,kRenderNormal,10)// red Alien		
	if (equal(team,"undefinedteam") || strlen(team) == 0)
		set_user_rendering(id,kRenderFxNone,0,0,0,kRenderNormal,16)
}
public glowb() {
	glowall("team_command")
	glowall("team_armory")
	glowall("team_advarmory")
	glowall("phasegate")
}
glowall(object[62])
{
	new team, obj
	obj = find_ent_by_class(obj,object)
	while (obj != 0) 
	{
		team = entity_get_int(obj, EV_INT_team)
		if (team == 1) 
			set_rendering(obj,kRenderFxGlowShell,0,170,255,kRenderNormal,10)
		if (team == 3)
			set_rendering(obj,kRenderFxGlowShell,200,0,0,kRenderNormal,10)
		obj = find_ent_by_class(obj,object)
	}
}