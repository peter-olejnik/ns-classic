/*
* This plugin allows the Commander to slap players not following orders
*
* by White Panther
*
* Usage:
*	- commander needs to select a player ( optional )
*	- now he can slap that player using the right mouse button
*
* Credits:
*	- Darkness	-	much shorter "trace_direction" code
*
* v0.6:
*	- initial release ( internal )
*
* v0.7:
*	- fixed:
*		- NS 3.2 support
*	- added:
*		- Helper support
*
* v0.8:
*	- public release
*	- fixed:
*		- support for comm zooming
*		- MvM support
*/

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <ns>
//#include <helper>

// change this to 0 if you do not want to first select a player before slapping
#define NEED_SELECTION			1

#define OFFSET_MOUSE_RES_X		506
#define OFFSET_MOUSE_RES_Y		505
#define OFFSET_MOUSE_X			520
#define OFFSET_MOUSE_Y			521

#define SLAP_DAMAGE			0
#define SLAP_POWER			1000.0
#define SLAP_DELAY			0.5

#define HUD_POS_X			0.7
#define HUD_POS_Y			0.3

#if NEED_SELECTION == 1
#define HUD_MSG				"You can slap when being Comm:^nPlace your mouse over a selected player^nand press right mouse button"
#else
#define HUD_MSG				"You can slap when being Comm:^nPlace your mouse over a player^nand press right mouse button"
#endif

#define SETSELECT_AMOUNT_SELECTED	2
#define SETSELECT_PLAYER_SELECTED	3

#define PLUGIN_AUTHOR			"White Panther"
#define PLUGIN_VERSION			"0.8"

new Float:mouse_x, Float:mouse_y
//new Float:mouse_x_resolution, Float:mouse_y_resolution

new Float:corrector_x, Float:corrector_y
new Float:comm_origin[3]
new Float:comm_height
//new Float:comm_view_ofs[3]
new Float:slap_time[5]

new Float:trace_direction[3]
new trace_point_content, trace_point_content_old
new Float:trace_start[3]
new Float:trace_end[3]
new Float:trace_result[3]
new function_call_num
new trace_id, Comm_id
new comm_team

#if NEED_SELECTION == 1
new targetID[5] = 0
#endif

public plugin_init( )
{
	register_cvar("comm_dk_slap_version", PLUGIN_VERSION, FCVAR_SERVER)
	set_cvar_string("comm_dk_slap_version", PLUGIN_VERSION)
	
	if ( !ns_is_combat() )
	{
		register_plugin("Comm DK Slap", PLUGIN_VERSION, PLUGIN_AUTHOR)
		register_event("SetupMap", "get_commview", "bc", "1=0")

#if NEED_SELECTION == 1
		register_message(get_user_msgid("SetSelect"), "editSetSelect")
#endif
	}else
	{
		register_plugin("Comm DK Slap (off)", PLUGIN_VERSION, PLUGIN_AUTHOR)
		pause("ad")
	}
}

public client_changeclass( id , newclass , oldclass )
{
	if ( newclass != CLASS_COMMANDER )
		return PLUGIN_CONTINUE
	
	set_hudmessage(255, 255, 255, HUD_POS_X, HUD_POS_Y, 0, 0.0, 15.0, 0.0, 0.0, 2)
	show_hudmessage(id, HUD_MSG)
	
	return PLUGIN_CONTINUE
}

public client_PreThink( id )
{
	if ( ns_get_class(id) != CLASS_COMMANDER )
		return PLUGIN_CONTINUE
	
	if ( !(pev(id, pev_button) & IN_ATTACK2 ) )
		return PLUGIN_CONTINUE
	
	comm_team = pev(id, pev_team)
	if ( get_gametime() < slap_time[comm_team] )
		return PLUGIN_CONTINUE
	
#if NEED_SELECTION == 1
	if ( targetID[comm_team] == 0 )
		return PLUGIN_CONTINUE
#endif
	
	mouse_x = get_pdata_float(id, OFFSET_MOUSE_X)
	mouse_y = get_pdata_float(id, OFFSET_MOUSE_Y)
	/*mouse_x_resolution = get_pdata_float(id, OFFSET_MOUSE_RES_X)
	mouse_y_resolution = get_pdata_float(id, OFFSET_MOUSE_RES_Y)
	if ( mouse_x < -0.695
		|| mouse_x > 0.695
		|| mouse_y < -0.612
		|| mouse_y > 0.612
		|| ( mouse_x == 0.0 && mouse_x_resolution != 0.0 )
		|| ( mouse_y == 0.0 && mouse_y_resolution != 0.0 ) )
	*/
	if ( mouse_x == 1.0
		|| mouse_x == -1.0
		|| mouse_y == 1.0
		|| mouse_y == -1.0 )
	{
		// player is scrolling
		return PLUGIN_CONTINUE
	}else
	{
		slap_time[comm_team] = get_gametime() + SLAP_DELAY
		
		Comm_id = id
		
		pev(id, pev_origin, comm_origin)
		
		// NOT using orig + offset to support comm zooming. offset is not changed when zooming
		//pev(id, pev_view_ofs, comm_view_ofs)
		//comm_origin[2] += comm_view_ofs[2]
		
		comm_origin[2] = comm_height
		
		trace_direction[0] = mouse_x
		trace_direction[1] = mouse_y
		trace_direction[2] = -1.0 * floatsqroot(1 - ( floatpower(trace_direction[0], 2.0) + floatpower(trace_direction[1], 2.0) ))
		
		trace_start[0] = comm_origin[0]
		trace_start[1] = comm_origin[1]
		trace_start[2] = comm_origin[2]
		
		corrector_x = ( mouse_x < 0.0 ) ? -1.0 : 1.0
		corrector_y = ( mouse_y < 0.0 ) ? -1.0 : 1.0
		
		function_call_num = 1
		keep_tracing()
		
		if ( is_user_connected(trace_id) )
		{
			// wrong team, so do not allow to slap
			if ( comm_team != pev(trace_id, pev_team) )
				return PLUGIN_CONTINUE
			
			slap_player(trace_id)
		}else
		{
			trace_id = -1
			while ( ( trace_id = find_ent_in_sphere(trace_id, trace_result, 20.0) ) > 0 )
			{
				if ( !is_user_connected(trace_id) )
					continue
				
				if ( comm_team != pev(trace_id, pev_team) )
					continue

#if NEED_SELECTION == 1
				if ( trace_id != targetID[comm_team] )
					continue
#endif
				
				slap_player(trace_id)
				
				break
			}
		}
	}
	
	return PLUGIN_CONTINUE
}

public get_commview( id )
{
	comm_height = float(read_data(4))
	
	return PLUGIN_HANDLED
}

#if NEED_SELECTION == 1
public editSetSelect( dummy , dummy2 , receiver )
{
	if ( get_msg_arg_int(SETSELECT_AMOUNT_SELECTED) != 1 )
	{
		targetID[receiver] = 0
	}else
	{
		targetID[receiver] = get_msg_arg_int(SETSELECT_PLAYER_SELECTED)
		// skip entitys
		if ( is_user_connected(targetID[receiver]) == 0 )
			targetID[receiver] = 0
	}
	
	return PLUGIN_CONTINUE
}
#endif

keep_tracing( )
{
	// initialize trace_end
	if ( function_call_num == 1 )
	{
		trace_end[0] = comm_origin[0] + trace_direction[0] * 100.0	// * function_call_num
		trace_end[1] = comm_origin[1] + trace_direction[1] * 100.0	// * function_call_num
		trace_end[2] = comm_origin[2] + trace_direction[2] * 100.0	// * function_call_num
	}
	
	// first trace
	trace_id = trace_line(Comm_id, trace_start, trace_end, trace_result)
	
	// prepare for new trace
	trace_start[0] = trace_result[0]
	trace_start[1] = trace_result[1]
	trace_start[2] = trace_result[2]
	
	while ( ( trace_point_content = point_contents(trace_start) ) != -1 )
	{
		// prevent infinite loops, just incase
		if ( function_call_num > 90 )
			break
		
		trace_end[0] = comm_origin[0] + trace_direction[0] * ( 100.0 * function_call_num )
		trace_end[1] = comm_origin[1] + trace_direction[1] * ( 100.0 * function_call_num )
		trace_end[2] = comm_origin[2] + trace_direction[2] * ( 100.0 * function_call_num )
		
		trace_id = trace_line(Comm_id, trace_start, trace_end, trace_result)
		
		// TODO: maybe if same vec then increase loop ?
		if ( !is_same_vec(trace_start, trace_result)	// not same
			|| trace_start[2] <= trace_end[2] )	// or Z-orig is smaller
			function_call_num += 1
		
		trace_start[0] = trace_result[0] + trace_direction[0]
		trace_start[1] = trace_result[1] + trace_direction[1]
		trace_start[2] = trace_result[2] + trace_direction[2]
		
		trace_point_content_old = trace_point_content
	}
	
	if ( trace_point_content == -1 )
	{
		
		trace_end[0] = comm_origin[0] + trace_direction[0] * 100.0 * 600.0
		trace_end[1] = comm_origin[1] + trace_direction[1] * 100.0 * 600.0
		trace_end[2] = comm_origin[2] + trace_direction[2] * 100.0 * 600.0
		trace_id = trace_line(Comm_id, trace_start, trace_end, trace_result)
		
		if ( is_same_vec(trace_start, trace_result)
			&& trace_point_content_old )
		{
			trace_start[0] += trace_direction[0]
			trace_start[1] += trace_direction[1]
			trace_start[2] += trace_direction[2]
			trace_id = trace_line(Comm_id, trace_start, trace_end, trace_result)
		}
		if ( ( trace_point_content = point_contents(trace_result) ) < -1 )
		{
			trace_start[0] = trace_result[0] + ( 0.1 * corrector_x )
			trace_start[1] = trace_result[1] + ( 0.1 * corrector_y )
			trace_start[2] = trace_result[2] - 0.1
			
			keep_tracing()
		}
	}
}

slap_player( victim )
{
	new Float:vec2d[2]
	vec2d[0] = trace_direction[0]
	vec2d[1] = trace_direction[1]
	new Float:norm_vec = floatsqroot(( vec2d[0] * vec2d[0] ) + ( vec2d[1] * vec2d[1] ))
	vec2d[0] /= norm_vec
	vec2d[1] /= norm_vec
	
	new Float:velo[3]
	pev(victim, pev_velocity, velo)
	velo[0] += ( vec2d[0] * SLAP_POWER )
	velo[1] += ( vec2d[1] * SLAP_POWER )
	set_pev(victim, pev_velocity, velo)
	
	new Float:health
	pev(victim, pev_health, health)
	health -= SLAP_DAMAGE
	if ( health < 1.0 )
		health = 1.0
	
	set_pev(victim, pev_health, health)
	
	client_print(victim, print_chat, "You have been slapped by the Commander. Follow his commands!")
}

stock is_same_vec( Float:vec1[3] , Float:vec2[3] )
{
	if ( vec1[0] == vec2[0]
		&& vec1[1] == vec2[1]
		&& vec1[2] == vec2[2] )
		return 1
	
	return 0
}

//////////////////// These functions are called by other plugins to get/set variables ////////////////////
/*
*public client_help( id )
*{
*	help_add("Information", "Allows Commander to slap players like in Dungeon Keeper.")
*	help_add("Usage", "Place your mouse over him and press right mouse button.")
*}
*/
public client_advertise( id )
{
	if ( ns_is_combat() )
		return PLUGIN_HANDLED
	
	return PLUGIN_CONTINUE
}
