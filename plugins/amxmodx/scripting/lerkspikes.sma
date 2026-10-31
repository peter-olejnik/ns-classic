/* Amx Mod X script.
*
* Authors: Sandstorm (original, from "LerkSpikes")
*      White Panther ( continuing support ) (also extralevels exp list) (from "LerkSpikes")
*      #endgame ( level/point detecting codes, and ready room exploit fix ) (from "CombatBuildings")
*      XunTric (codes for buying lerk spikes) (from "Lerk Powers 1.1")
* Semi Author:      
*    Petco/Gorginator ( only edited it all together, mostly modified existing code )
*existing code by above authors. So its all thanks to the above authors. )
*    
* This file is provided as is (no warranties).
*
* This plugin gives lerk players the hidden spike attack by paying the cost.
*
* Cvars:
* lerkspike_enabled "1"    - Enables or Disables plugin
* lerkspike_default "5"    - Default weapon slot, 0 will default to off
* lerkspike_classic "1"    - Enables in classic mode
* lerkspike_combat "1"    - Enables in combat mode
* amx_lerkcombatcost "2"(default) - Point cost in combat mode
* amx_lerkclassiccost "15"(default - Resource cost in classic mode
* amx_spikelevelrequirement "1"(default - Required level to purchase Lerk Spikes in combat)
* amx_spikerefund "0"(disable/enable 0/1 option for players to get a refund on lerk spikes)
* amx_spikehiveabilityreq "0"(0-3, amount of hives or hive abilities lerk needs before being able to purchase)
*    Setting amx_spikehiveabilityreq to a 0 means that a lerk can purchase this with just bite(0 hives needed).
*     Setting amx_spikehiveabilityreq to 1 mean lerk needs spore to buy this(1 hive). Setting it to 2 means lerk needs umbra(2 hives).
*     Finally setting amx_spikehiveabilityreq to 3 means the lerk needs primal scream(3 hives) before being able to buy lerk spikes.
*    Works for both combat and classic modes.
*
* User Commands:
* say /lerkspikes - Brings Lerk Spikes buy menu
* say /spikesrefund - Brings Spikes Refund menu(this can only be used if amx_spikerefund is set to "1")
*
* Userinfo:
* spike "5"        - User preference for weapon slot, 0 is off    
*
* Modules (AMX Mod X):
* Engine, NS
*
* v1.1:
*    - Used CORRECT include file
* v1.2:
*    - Spike now appears in Slot1, like in 2.x
* v1.3:
*    - Using msgedit instead
* v1.4:
*    - Switched to AMX Mod X
*    - Added default slot cvar
*    - Added classic/combat cvars
*    - Added support for userinfo slot preference
* v1.4a:
*    - Ported to AMX Mod X v1.60 by Depot
* v1.5:
*    - Check included by Depot to prevent lerk respawning as skulk from having lerkspike (thanks White Panther)
*    - Same check prevents marines from receiving setinfo msg. Code improvements by White Panther.
* v1.6:
*    - plugin now works with latest NS and Amx Mod X ( v1.71 or above only )
*    - fixed bug where custom settings could bug weapons
*    - code improvements / clean up
* v1.61(edited version by Petco):
*    - lerk spikes needs to be purchase before use
*/
#define HELPER 1

#include <amxmodx>
#include <engine>
#include <ns>
#include <fun>
#include <amxmisc>
#include <fakemeta>
#include <helper>

/*
This is a list of each slot and their allowed positions for Spikes:
slot 0:
    0
slot 1:
    2, 7, 8, 9
slot 2:
    0, 6, 8, 9
slot 3:
    0, 2, 3, 9
slot 4:
    2, 3, 4, 5, 6, 7, 8, 9
*/

#define MAXSLOTS        5

// How fast to press F4 to go to the readyroom
#define CBUILD_F4_TIMER 2.0

new sma_name[] =    "Lerk Spike Cost"
new sma_short[] =    "LERKSPIKECOST"
new sma_version[] =    "1.61"
new sma_author[] =    "Sandstorm/White Panther/XunTric/#endgame/Petco"
new cvar_enabled[] =    "lerkspike_enabled"
new cvar_version[] =    "lerkspike_version"
new cvar_default[] =    "lerkspike_default"
new cvar_classic[] =    "lerkspike_classic"
new cvar_combat[] =    "lerkspike_combat"
new cvar_tournament[] =    "mp_tournamentmode"
new userinfo_slot[] =    "spike"
new wpn_spikes[] =    "weapon_spikegun"
new msg_help[] =     "[%s] Press %d to select your spike shooter."
new msg_setinfo[] =     "[%s] Next time, use ^"setinfo spike <slot>^" before connecting to set your slot preference."

new CVAR_mp_tournamentmode, CVAR_lerkspike_enabled, CVAR_lerkspike_default, CVAR_lerkspike_classic, CVAR_lerkspike_combat
new is_combat
new bool:LerkSpikesTrueFalse[33]
new g_f4ing[33] = 0;

// WeaponInfo message
enum
{
    wName = 1,    // string
    wAmmoType,    // byte
    wAmmoMax,    // byte
    wUnknown,    // byte, always -1
    wDamage,    // byte
    wSlot,        // byte
    wSlotPos,    // byte
    wId,        // byte
    wFlags        // byte
}

new player_slot[33], player_custom[33], player_helped[33]

public plugin_init( )
{
    register_plugin(sma_name, sma_version, sma_author)
    register_cvar(cvar_version, sma_version, FCVAR_SERVER)

        register_clcmd("say /lerkspikes", "lerkmenucheck")
        register_clcmd("say_team /lerkspikes", "lerkmenucheck")
        register_clcmd("say /spikesrefund", "spikesrefund")
        register_clcmd("say_team /spikesrefund", "spikesrefund")
    register_clcmd("readyroom", "f4", ADMIN_ALL, "Ready Room");
    register_clcmd("menureadyroom", "cleanup", ADMIN_ALL, "Ready Room");

       register_menucmd(register_menuid("menu_lerk"),1023,"lerkmenukeys")
        register_cvar("amx_lerkcombatcost", "2", ADMIN_KICK)
    register_cvar("amx_lerkclassiccost", "15", ADMIN_KICK)
        register_cvar("amx_spikelevelrequirement", "1", ADMIN_KICK) // Required level to buy spikes(combat only)
        register_cvar("amx_spikehiveabilityreq", "0", ADMIN_KICK) // (0-3)Required hives(classic) or hive ability(combat) to purchase lerk spikes
        register_cvar("amx_spikerefund", "0", ADMIN_KICK) // 0/1 = Disable/Enable option to refund
       register_impulse(5, "cleanup");
    CVAR_lerkspike_enabled = register_cvar(cvar_enabled, "1")
    CVAR_lerkspike_default = register_cvar(cvar_default, "5")
    CVAR_lerkspike_classic = register_cvar(cvar_classic, "1")
    CVAR_lerkspike_combat = register_cvar(cvar_combat, "1")
    CVAR_mp_tournamentmode = get_cvar_pointer(cvar_tournament)
    is_combat = ns_is_combat()
    if ( is_enabled() )
    {
        register_event("WeapPickup", "spawn_lerk", "b", "1=6")
        register_message(get_user_msgid("WeaponList"), "WeaponList_msg")
    }
}
////Exp and levels checks
enum {
    XP_LEVEL_1    =     0,
    XP_LEVEL_2    =   100,
    XP_LEVEL_3    =   250,
    XP_LEVEL_4    =   450,
    XP_LEVEL_5    =   700,
    XP_LEVEL_6    =  1000,
    XP_LEVEL_7    =  1350,
    XP_LEVEL_8    =  1750,
    XP_LEVEL_9    =  2200,
    XP_LEVEL_10    =  2700,
    XP_LEVEL_11    =  3250,
    XP_LEVEL_12    =  3850,
    XP_LEVEL_13    =  4500,
    XP_LEVEL_14    =  5200,
    XP_LEVEL_15    =  5950,
    XP_LEVEL_16    =  6750,
    XP_LEVEL_17    =  7600,
    XP_LEVEL_18    =  8500,
    XP_LEVEL_19    =  9450,
    XP_LEVEL_20    = 10450,
    XP_LEVEL_21    = 11500,
    XP_LEVEL_22    = 12600,
    XP_LEVEL_23    = 13800,
    XP_LEVEL_24    = 15050,
    XP_LEVEL_25    = 16350,
    XP_LEVEL_26    = 17750,
    XP_LEVEL_27    = 19200,
    XP_LEVEL_28    = 20700,
    XP_LEVEL_29    = 22250,
    XP_LEVEL_30    = 23850,
    XP_LEVEL_31    = 25500,
    XP_LEVEL_32    = 27200,
    XP_LEVEL_33    = 28950,
    XP_LEVEL_34    = 30750,
    XP_LEVEL_35    = 32600,
    XP_LEVEL_36    = 34500,
    XP_LEVEL_37    = 36450,
    XP_LEVEL_38    = 38450,
    XP_LEVEL_39    = 40500,
    XP_LEVEL_40    = 42600,
    XP_LEVEL_41    = 44750,
    XP_LEVEL_42    = 46950,
    XP_LEVEL_43    = 49200,
    XP_LEVEL_44    = 51500,
    XP_LEVEL_45    = 53850,
    XP_LEVEL_46    = 56250,
    XP_LEVEL_47    = 58700,
    XP_LEVEL_48    = 61300,
    XP_LEVEL_49    = 63950,
    XP_LEVEL_50    = 66650
};

get_xp(index){
  return floatround(ns_get_exp(index));
}

get_level(id) {
  new xp = get_xp(id);

  if (xp > XP_LEVEL_50)   return 50;
  if (xp > XP_LEVEL_49)   return 49;
  if (xp > XP_LEVEL_48)   return 48;
  if (xp > XP_LEVEL_47)   return 47;
  if (xp > XP_LEVEL_46)   return 46;
  if (xp > XP_LEVEL_45)   return 45;
  if (xp > XP_LEVEL_44)   return 44;
  if (xp > XP_LEVEL_43)   return 43;
  if (xp > XP_LEVEL_42)   return 42;
  if (xp > XP_LEVEL_41)   return 41;
  if (xp > XP_LEVEL_40)   return 40;
  if (xp > XP_LEVEL_39)   return 39;
  if (xp > XP_LEVEL_38)   return 38;
  if (xp > XP_LEVEL_37)   return 37;
  if (xp > XP_LEVEL_36)   return 36;
  if (xp > XP_LEVEL_35)   return 35;
  if (xp > XP_LEVEL_34)   return 34;
  if (xp > XP_LEVEL_33)   return 33;
  if (xp > XP_LEVEL_32)   return 32;
  if (xp > XP_LEVEL_31)   return 31;
  if (xp > XP_LEVEL_30)   return 30;
  if (xp > XP_LEVEL_29)   return 29;
  if (xp > XP_LEVEL_28)   return 28;
  if (xp > XP_LEVEL_27)   return 27;
  if (xp > XP_LEVEL_26)   return 26;
  if (xp > XP_LEVEL_25)   return 25;
  if (xp > XP_LEVEL_24)   return 24;
  if (xp > XP_LEVEL_23)   return 23;
  if (xp > XP_LEVEL_22)   return 22;
  if (xp > XP_LEVEL_21)   return 21;
  if (xp > XP_LEVEL_20)   return 20;
  if (xp > XP_LEVEL_19)   return 19;
  if (xp > XP_LEVEL_18)   return 18;
  if (xp > XP_LEVEL_17)   return 17;
  if (xp > XP_LEVEL_16)   return 16;
  if (xp > XP_LEVEL_15)   return 15;
  if (xp > XP_LEVEL_14)   return 14;
  if (xp > XP_LEVEL_13)   return 13;
  if (xp > XP_LEVEL_12)   return 12;
  if (xp > XP_LEVEL_11)   return 11;
  if (xp > XP_LEVEL_10)   return 10;
  if (xp > XP_LEVEL_9)   return 9;
  if (xp > XP_LEVEL_8)   return 8;
  if (xp > XP_LEVEL_7)   return 7;
  if (xp > XP_LEVEL_6)   return 6;
  if (xp > XP_LEVEL_5)   return 5;
  if (xp > XP_LEVEL_4)   return 4;
  if (xp > XP_LEVEL_3)   return 3;
  if (xp > XP_LEVEL_2)   return 2;
  return 1;
}

////End of Exp and level checks

// Player has connected
public client_connect( id )
{
    if ( !is_enabled() )
        return PLUGIN_CONTINUE
    
    new str_slot[3]
    player_helped[id] = 0
    get_user_info(id, userinfo_slot, str_slot, 2)
    if ( !str_slot[0] )
    {
        player_slot[id] = clamp(get_pcvar_num(CVAR_lerkspike_default), 1, MAXSLOTS)
        player_custom[id] = 0
    }else
    {
        player_slot[id] = clamp(str_to_num(str_slot), 1, MAXSLOTS)
        player_custom[id] = 1
    }
    
    return PLUGIN_CONTINUE
}

//////////////Checks to see if player can buy spikes or not.
//////////////Code and format by XunTric (from "Lerk Powers" plugin):
public lerkmenucheck(id)
{
    if(get_cvar_num("lerkspike_enabled") <= 0) {
        return PLUGIN_HANDLED
    }

    if(ns_get_class(id) != CLASS_LERK) {
        client_print(id, print_chat, "You are not a Lerk!")
        return PLUGIN_HANDLED
    }

    if(LerkSpikesTrueFalse[id] == true) {
        client_print(id, print_chat, "You already have Lerk Spikes!")
        return PLUGIN_HANDLED
    }

    if(ns_get_hive_ability(id) < get_cvar_num("amx_spikehiveabilityreq") ) {
        client_print(id, print_chat, "You need level %d hive abilty before purchasing Lerk Spikes!", get_cvar_num("amx_spikehiveabilityreq"))
        return PLUGIN_HANDLED
    }


    if(is_combat == 0 ) {
        if(get_cvar_num("lerkspike_classic") <= 0 )
        {
            client_print(id, print_chat, "Spikes are not enabled in classic mode!")
            return PLUGIN_HANDLED
        }

        if(ns_get_res(id) < get_cvar_num("amx_lerkclassiccost"))
        {
            client_print(id, print_chat, "You dont have enough resources for Lerk Spikes! (You need %d resources)", get_cvar_num("amx_lerkclassiccost"))
            return PLUGIN_HANDLED
        }
    }

    if(is_combat == 1 ) {
        if(get_cvar_num("lerkspike_combat") <= 0 )
        {
            client_print(id, print_chat, "Spikes are not enabled in combat mode!")
            return PLUGIN_HANDLED
        }

        if((get_level(id) - ns_get_points(id) - 1) < get_cvar_num("amx_lerkcombatcost"))
        {
            client_print(id, print_chat, "You dont have enough points for Lerk Spikes! (You need %d points)", get_cvar_num("amx_lerkcombatcost"))
            return PLUGIN_HANDLED
        }
        if(get_cvar_num("amx_spikelevelrequirement") > get_level(id))
        {
            client_print(id, print_chat, "You need more levels! (You need to be level %d to purchase Lerk Spikes )", get_cvar_num("amx_spikelevelrequirement"))
            return PLUGIN_HANDLED
        }
    }


    lerkmenu(id)
    
    return PLUGIN_HANDLED
}

public lerkmenu(id)
{
    new menu[192]
    new keys = MENU_KEY_1|MENU_KEY_2
    if(is_combat == 0 ) {
    format(menu, 191, "Buy Lerk Spikes? [Cost: %d resource(s)]^n^n1. Yes^n2. No" , get_cvar_num("amx_lerkclassiccost") )
    }
    if(is_combat == 1 ) {
    format(menu, 191, "Buy Lerk Spikes? [Cost: %d point(s)]^n^n1. Yes^n2. No" , get_cvar_num("amx_lerkcombatcost") )
    }
    show_menu(id, keys, menu, -1, "menu_lerk")
    
    return PLUGIN_CONTINUE
}

public lerkmenukeys(id, key)
{
    if(key == 0) {
         lerkspikescost(id)
    }

    if(key >= 1) {
     return PLUGIN_HANDLED
    }

    return PLUGIN_HANDLED
}

public lerkspikescost(id)
{
    if(get_cvar_num("lerkspike_enabled") <= 0) {
         return PLUGIN_HANDLED
    }

    client_print(id, print_chat, "You bought Lerk Spikes!")


    if(is_combat == 0 ) {
        ns_set_res(id, ns_get_res(id) - get_cvar_num("amx_lerkclassiccost"))
    }

    if(is_combat == 1 ) {
        ns_set_points(id, ns_get_points(id) + get_cvar_num("amx_lerkcombatcost"))
    }

    ns_give_item(id, wpn_spikes)
    if ( !player_helped[id] )
        help_player(id)


    LerkSpikesTrueFalse[id] = true
    
    return PLUGIN_HANDLED
}
////////////End of code and format by XunTric (from "Lerk Powers" plugin)

// A player has spawned as a lerk
public spawn_lerk( id )
{
    if ( ns_get_class(id) == CLASS_LERK )
    {
        if ( is_enabled() )
        {
                if(LerkSpikesTrueFalse[id] == true)
            {
                ns_give_item(id, wpn_spikes)
                if ( !player_helped[id] )
                    help_player(id)
               }
        }
    }
}

// Moves the spike attack to the proper weapon slot
public WeaponList_msg( msgid , dest , id )
{
    new weaponname[64]
    get_msg_arg_string(wName, weaponname, 63)
    if ( equal(weaponname, wpn_spikes) )
    {
        set_msg_arg_int(wSlot, ARG_BYTE, player_slot[id] - 1)
        new pos
        switch ( player_slot[id] )
        {
            case 1:
                pos = 0
            case 2:
                pos = 7
            case 3:
                pos = 0
            case 4:
                pos = 0
            case 5:
                pos = 2
        }
        set_msg_arg_int(wSlotPos, ARG_BYTE, pos)
    }
    return PLUGIN_CONTINUE
}

// Return if plugin is enabled
is_enabled( )
{
    if ( get_pcvar_num(CVAR_mp_tournamentmode) )
        return 0

    if ( !get_pcvar_num(CVAR_lerkspike_enabled) )
        return 0

    if ( !get_pcvar_num(CVAR_lerkspike_combat) && is_combat )
        return 0

    if ( !get_pcvar_num(CVAR_lerkspike_classic) && !is_combat )
        return 0

    return 1
}

// Help the player
help_player( id )
{
    player_helped[id] = 1
    client_print(id, print_chat, msg_help, sma_short, player_slot[id])
    if ( !player_custom[id] )
        client_print(id, print_chat, msg_setinfo, sma_short)
}

// Code from #endgame's combatbuildings plugin:
// Reset lerk spikes after ready rooming
public f4(id){
  if(g_f4ing[id])
    cleanup(id);
  else{
    new params[1];
    params[0] = id;
    g_f4ing[id] = 1;
    set_task(CBUILD_F4_TIMER, "abortf4", 0, params, 1);
  }
}

public abortf4(params[], id){
  new player = params[0];
  g_f4ing[player] = 0;
}

public cleanup(id){
    g_f4ing[id] = 0;
    LerkSpikesTrueFalse[id] = false
    return PLUGIN_CONTINUE;
}

// Reset lerk Spikes after disconnect
public client_disconnect(id){
    g_f4ing[id] = 0;
    LerkSpikesTrueFalse[id] = false
    return PLUGIN_CONTINUE;
}


/////Lerk Spikes refund
public spikesrefund(id){
    
    if(get_cvar_num("amx_spikerefund") <= 0 || is_combat == 0) {
            client_print(id, print_chat, "Refund on Lerk Spikes is not enabled or this is not combat mode.")
        return PLUGIN_HANDLED
    }
    if (LerkSpikesTrueFalse[id]){

        if(ns_get_class(id) != CLASS_LERK && ns_get_class(id) != CLASS_GESTATE) {
            LerkSpikesTrueFalse[id] = false
            ns_set_points(id, ns_get_points(id) - get_cvar_num("amx_lerkcombatcost"))
            client_print(id, print_chat, "You traded back your Lerk Spikes and received %d points as a refund. ", get_cvar_num("amx_lerkcombatcost"))
        }
        else
        {
            client_print(id, print_chat, "You cannot obtain a refund while you are a Lerk or while gestating.")
            client_print(id, print_chat, "Try again when you respawn as a skulk.")
        }
    }
    else
    {
        client_print(id, print_chat, "You don't have Lerk Spikes to obtain a refund on.")
    }
        return PLUGIN_HANDLED

}

public client_help(id){
  help_add("Information","This plugin allows Lerks to purchase spike shooters.")
  help_add("Usage","You must have Primal Scream and Level 5 to get spikes.")
  help_add("Commands","Say /lerkspikes to buy spikes or /spikesrefund to cash them out.")
}
