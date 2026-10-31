// Ensure all team voices are heard on HLTV 

#include <amxmodx>
#include <engine>

public plugin_init()
{
	register_plugin("HLTV Voices", "0.1", "TinCan")
}

public  client_putinserver ( id ) 
{
	if (is_user_hltv ( id ) )
	{
		set_speak ( id, SPEAK_LISTENALL )
	}
}
