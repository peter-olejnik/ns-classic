#include <amxmisc>
public plugin_init() {
	register_plugin("ff4lt", "1.0", "TinCan")
	register_concmd( "amx_ff", "ff4lt", ADMIN_KICK, "  FF4LT" )
}

public ff4lt(id, lvl, cid) {
	if(!cmd_access(id, lvl, cid, 1)) 
		return PLUGIN_HANDLED
	new arg1[4]     
	read_argv( 1 , arg1 , 3)
	if (equali(arg1[0], "1")) {
		set_cvar_num("mp_friendlyfire",1)
		//client_print( 0, print_chat, "Friendly fire has been turned on.")
          }
	 else if (equali(arg1[0], "0")) {
	 	set_cvar_num("mp_friendlyfire",0)
		//client_print( 0, print_chat, "Friendly fire has been turned off.")
         }
	return PLUGIN_HANDLED
}

public round_end (){
	set_cvar_num("mp_friendlyfire",0) 
}
