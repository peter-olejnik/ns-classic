// Prints the byte offsets of NS server fields that AMX Mod X's ns module
// reads and writes (plugins/amxmodx/patches), one "Class::member offset" per
// line. builder/Dockerfile compiles it with the defines and include paths of
// ns.so, runs it and ships the output as dlls/ns.so.offsets, along with the
// GNU build ID of that ns.so, so the module can tell the two belong together.
//
// The upstream module hard-codes these offsets for NS 3.2's ns_i386.so. The
// layout of ours differs (GCC 11's std::string alone is 24 bytes, not 4).

// The standard headers first, so that the access trick below only reaches
// the NS classes
#include <algorithm>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <functional>
#include <iostream>
#include <list>
#include <map>
#include <memory>
#include <set>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#define private public
#define protected public

#include "../util/nowarnings.h"
#include "../dlls/extdll.h"
#include "../dlls/util.h"
#include "../dlls/cbase.h"
#include "../dlls/player.h"
#include "../dlls/weapons.h"
#include "AvHGamerules.h"
#include "AvHEntities.h"
#include "AvHPlayer.h"
#include "AvHMarineEquipment.h"
#include "AvHHive.h"
#include "AvHWeldable.h"
#include "AvHBasePlayerWeapon.h"

// Offset of a member from the start of a T object (the entity's private
// data). Works through base classes, unlike offsetof on these types.
#define OFFSET(T, m) (static_cast<long>(reinterpret_cast<size_t>(&reinterpret_cast<T *>(4096)->m)) - 4096)

// The module reads and writes each field with a fixed width
#define FIELD(T, m, size) do { \
		static_assert(sizeof(reinterpret_cast<T *>(0)->m) == (size), #T "::" #m " size"); \
		printf("%s::%s %ld\n", #T, #m, OFFSET(T, m)); \
	} while (0)

int main()
{
	// Players
	FIELD(AvHPlayer, mResources, 4);
	FIELD(AvHPlayer, mExperience, 4);
	FIELD(AvHPlayer, mExperienceLevelsSpent, 4);
	FIELD(AvHPlayer, mScore, 4);
	FIELD(AvHPlayer, mNumHives, 4);
	FIELD(AvHPlayer, mPurchasedCombatUpgrades, 3 * sizeof(void *));
	FIELD(AvHPlayer, mGiveCombatUpgrades, 3 * sizeof(void *));
	printf("AvHPlayer::mCombatNodes %ld\n", OFFSET(AvHPlayer, mCombatNodes));
	FIELD(AvHPlayer, m_iDeaths, 4);
	FIELD(AvHPlayer, m_rgAmmo, MAX_AMMO_SLOTS * 4);
	FIELD(AvHPlayer, m_rgpPlayerItems, MAX_ITEM_TYPES * sizeof(void *));
	FIELD(AvHPlayer, m_pActiveItem, sizeof(void *));
	FIELD(AvHPlayer, m_pLastItem, sizeof(void *));

	// Weapons
	FIELD(AvHBasePlayerWeapon, m_pNext, sizeof(void *));
	FIELD(AvHBasePlayerWeapon, m_iId, 4);
	FIELD(AvHBasePlayerWeapon, m_iClip, 4);
	FIELD(AvHBasePlayerWeapon, mRange, 4);
	FIELD(AvHBasePlayerWeapon, mDamage, 4);

	// Structures
	FIELD(AvHBaseBuildable, mBuilder, 4);
	FIELD(AvHBaseBuildable, mGhost, 1);
	FIELD(AvHMarineBaseBuildable, mEnergy, 4);
	FIELD(AvHHive, mTechnology, 4);
	FIELD(AvHWeldable, mTimeBuilt, 4);
	FIELD(AvHWeldable, mBuildTime, 4);

	// Game
	FIELD(AvHGameplay, mTeamAType, 4);
	FIELD(AvHGameplay, mTeamBType, 4);
	printf("AvHGamerules::mTeamA %ld\n", OFFSET(AvHGamerules, mTeamA));
	printf("AvHGamerules::mTeamB %ld\n", OFFSET(AvHGamerules, mTeamB));
	FIELD(AvHTeam, mTeamResources, 4);
	return 0;
}
