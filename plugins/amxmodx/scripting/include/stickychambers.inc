// ns-classic: the original stickychambers.inc wasn't in the old server's
// backup. Rebuilt from stickychambers.sma, which registers the native
// (plugin_natives) and defines the impulses; used by combat_buildings.sma.
// stickychambers.amxx must be loaded for SC_CreateChamber to work.

#if defined _stickychambers_included
	#endinput
#endif
#define _stickychambers_included

enum
{
	IMPULSE_OC = 91,
	IMPULSE_DC,
	IMPULSE_SC,
	IMPULSE_MC
};

// Builds a chamber for ePlayer where they aim; returns its entity, or 0
native SC_CreateChamber(ePlayer, iImpulse);
