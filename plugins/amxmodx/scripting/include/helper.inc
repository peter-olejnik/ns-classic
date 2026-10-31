// ns-classic: the original helper.inc (mE's "Helper" 2.0, me_helper.amxx)
// wasn't in the old server's backup. Rebuilt from the compiled plugins that
// used it: help_add calls the public help_add of the plugin named "Helper"
// through callfunc (is_plugin_loaded, get_func_id, callfunc_begin_i,
// callfunc_push_str twice, callfunc_end). me_helper.amxx is shipped
// precompiled in plugins/amxmodx/prebuilt/.
//
// A plugin that uses it has these publics, which Helper calls:
//   client_help(id)       call help_add(title, text) for each help section
//   client_advertise(id)  return PLUGIN_CONTINUE to be listed for this player

#if defined _helper_included
	#endinput
#endif
#define _helper_included

#include <amxmodx>

// Adds one section ("Information", "Usage", ...) to the help being shown;
// only works inside client_help. Does nothing without Helper.
stock help_add(const title[], const text[])
{
	new plugin = is_plugin_loaded("Helper")
	if (plugin < 0)
		return 0

	new func = get_func_id("help_add", plugin)
	if (func < 0 || callfunc_begin_i(func, plugin) != 1)
		return 0

	callfunc_push_str(title, false)
	callfunc_push_str(text, false)
	return callfunc_end()
}
