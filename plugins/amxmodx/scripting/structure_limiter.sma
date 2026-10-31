#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <ns>

#define MAXCOMMCHAIRS 2

public plugin_init() {
register_plugin("NS Structure Limiter","0.1","Doc")
register_impulse(58, "build_cc")
}

public build_cc(id) {
if (ns_get_build("team_command", 0) >= MAXCOMMCHAIRS) {
client_print(0, print_chat, "(StructureLimiter): Maximum number of command chairs reached")
return PLUGIN_HANDLED
}
} 