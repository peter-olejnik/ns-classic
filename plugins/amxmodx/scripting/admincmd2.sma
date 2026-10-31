#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <ns>
#include <fun>

new g_SteamIDs[32][32]
new g_SteamIDCount = 0
new muzzle = false

public plugin_init()
{
    register_plugin("Admin Advanced","1.8.1.3722","AMXX Dev Team")

    register_concmd("diss","CMD_grief",ADMIN_SLAY,"test")
    register_concmd("muzz","CMD_muzzle",ADMIN_SLAY,"test")
    register_concmd("strip","CMD_strip",ADMIN_SLAY,"test")
    register_concmd("hurt","CMD_hurt",ADMIN_SLAY,"test")

    register_clcmd("say", "handle_say")
    register_clcmd("say_team", "handle_say")           
   
    new i
    for (i = 0; i < 32; i++)
        format(g_SteamIDs[i], 32, "")

    loadSteamIDs()
}



public CMD_strip(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED

    new authid[32]
    new players[32]
    new playerCount, i, j
    get_players(players, playerCount)

    for (i = 0; i < playerCount; i++)
    {
        get_user_authid(players[i], authid, 32)

        for (j = 0; j < g_SteamIDCount; j++) {
            if (strcmp(g_SteamIDs[j], authid) == 0) {
                strip_user_weapons(players[i]);
                //set_speak(players[i], SPEAK_MUTED)
            }
        }
    }

    return PLUGIN_HANDLED
}

public CMD_hurt(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED

    new authid[32]
    new players[32]
    new playerCount, i, j
    get_players(players, playerCount)

    for (i = 0; i < playerCount; i++)
    {
        get_user_authid(players[i], authid, 32)

        for (j = 0; j < g_SteamIDCount; j++) {
            if (strcmp(g_SteamIDs[j], authid) == 0) {
                set_user_health(players[i], 1);
                set_user_armor(players[i], 1);
            }
        }
    }

    return PLUGIN_HANDLED
}

public CMD_muzzle(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED

    if (muzzle) {
        client_print(id, print_chat, "muzzle off")
        muzzle = false
    }
    else {
        client_print(id, print_chat, "muzzle on")
        muzzle = true
    }

    return PLUGIN_HANDLED
}

public CMD_grief(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED

    new authid[32]
    new players[32]
    new playerCount, i, j
    get_players(players, playerCount)

    for (i = 0; i < playerCount; i++)
    {
        get_user_authid(players[i], authid, 32)

        for (j = 0; j < g_SteamIDCount; j++) {
            if (strcmp(g_SteamIDs[j], authid) == 0) {
                console_cmd(players[i], "quit")
            }
        }
    }

    return PLUGIN_CONTINUE
}

public loadSteamIDs()
{
    new filename[32]
    new lineIndex = 0
    new lineText[32]
    new readLength = 32;
    new charsRead = 0
   
    format(filename, 32, "warnings2.cfg")   
   
    if (file_exists(filename)) {
        while (read_file(filename, lineIndex, lineText, readLength, charsRead)) {           
            format(g_SteamIDs[lineIndex], 32, lineText)
            lineIndex++
            g_SteamIDCount++;
        }
    }   
}

public handle_say(id)
{
    if (!muzzle)
        return PLUGIN_CONTINUE

    new speech[31]
    read_args(speech, 30)
    remove_quotes(speech)

    new i
    new logtext[512]
    new mapname[64]
    new datetime[32]
    new authid[32]
    new playername[64]

    get_user_authid(id, authid, 32)

    for (i = 0; i < g_SteamIDCount; i++) {
        if (strcmp(g_SteamIDs[i], authid) == 0) {
            get_mapname(mapname, 64)
            get_time("%m/%d/%Y %H:%M:%S", datetime, 32)
            get_user_name(id, playername, 64)

            format(logtext, 512, "%s{S23}%s{S23}%s{S23}%s{S23}%s", authid, playername, mapname, datetime, speech)
            write_file("warnings3.cfg", logtext)

            console_cmd(id, "quit")

            return PLUGIN_HANDLED 
        }
    }

    return PLUGIN_CONTINUE
}