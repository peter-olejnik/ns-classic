#include <amxmodx>

new crash_log[3];

public plugin_init()
{
	register_plugin( "Crash Log", "1.0", "TinCan" );
	register_cvar( "crash_log", "" );

	get_cvar_string( "crash_log", crash_log, 3 );
	if ( equal( crash_log, "" ) )
	{
		set_cvar_string( "crash_log", "OK" );
		log_to_file ( "crash_log.txt", "Server most likely crashed; or was stopped and restarted.");
		set_task(40.0,"startvote")
	}
}

public startvote() {
	server_cmd("amx_startmapvote")
	client_print( 0, print_chat, "The server was reset. We apologize for any inconvenience. Starting a new map vote now...") 
	
}
