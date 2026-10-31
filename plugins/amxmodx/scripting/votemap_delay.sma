/*
 *   Votemap Delay 1.0
 *   by neXXus
 *
 *   Delays the ability to votemap right after mapchange in Natural-Selection.
 *   Prevents fastjoiners from votemap'ing another map right after mapchange,
 *   which would mean another mapchange, since they're the only person on the
 *   server at this time.
 *   
 *
 *   mp_votemapdelay - Sets the amount of time the ability to votemap
 *       will be delayed in seconds.
 *       Default: 60
 */

#include <amxmodx>

public plugin_init() {
	register_plugin("Votemap Delay","1.0","neXXus")
	register_cvar("mp_votemapdelay","60")
	register_cvar("mp_votemapratio","0.6")		// To save mp_mapvoteratio for re-enabling
							// Know a better way? Tell me!
	set_task(0.1,"delay")
}

public delay() {
	if (get_cvar_float("mp_mapvoteratio") != -1) {
		set_cvar_float("mp_votemapratio",get_cvar_float("mp_mapvoteratio"))	// Save mapvoteratio for later reenabling
		set_cvar_num("mp_mapvoteratio",-1)					// Disable voting
		set_task(get_cvar_float("mp_votemapdelay"),"enableVotemap")
	}
	return PLUGIN_HANDLED
}

public enableVotemap() {
	set_cvar_float("mp_mapvoteratio",get_cvar_float("mp_votemapratio"))	// Re-enable voting
	//client_print(0,print_chat,"Mapvoting is now enabled.")			// Tell users about it
	return PLUGIN_HANDLED
}