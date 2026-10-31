/*
*Plugin: NS Team Picker
*
*Author: Doc
*Email: brlewis23@gmail.com
*Date: 3/13/2009
*
*Version: 0.1
*
*Description:
*
*   This plugin is intented to aid in picking teams with team captains for organized play.
*   It does not strictly enforce anything so do not rely on this plugin to compensate for
*   uncooperative players and it does require someone with admin access (ADMIN_SLAY flag)
*   to operate it. The primary purpose of this plugin is to provide for picking teams
*   through a menu as opposed to the lengthy and tedious process of picking teams verbally.
*
*Admin Commands:
*
*   tp_captain1 <name>      ->assigns a player as captain for team 1
*
*   tp_captain2 <name>      ->assigns a player as captain for team 2
*
*   tp_team1side <side> ("marines" OR "aliens")     ->sets team 1's side, and team 2 will be assigned
*                                                   ->the opposite side. Default is team 1 marines and
*                                                   ->team 2 aliens. So running this command is not required   
*  
*   tp_pickteams            ->Begins the team picking process. Calling this during a current team selection
*                           ->process will reset the teams and start over
*
*   tp_jointeams            ->Once both teams have been assign use this command to join players to
*                           ->their respective teams
*
*   tp_cancel               ->Disables team selection. Use this to cancel a current team selection process
*                           ->This command is automatically called when tp_jointeams is called
*
*   tp_showteams            ->This command will show the team assignments if needed after the hud text has
*                           ->gone away
*
*Team Captain Commands:
*
*   tp_pick <name>          ->A team captain can use this as an alternative to the player menu to
*                           ->choose a player for his or her team
*
*Player Commands (type in chat, say, or say_team)
*
*   /spec                   ->This command will remove the player who typed it from the list of players
*                           ->the captains will be choosing from. The player's name will be listed on the
*                            ->screen as a spectator
*
*   /play                   ->This command will put a player back into the player list if he or she used
*                           ->/spec and had a change of mind. This is not necessary for players to type
*                           ->if they have not switched their status to spectator
*                            
*How the process works:
*
*   NOTE: admins need ADMIN_SLAY to use this plugin
*
*   1) An admin needs to use  tp_captain1 and tp_captain2 to assign team captains
*
*   2) By default team 1 is marines and team 2 is aliens, if this needs to be changed
*      use tp_team1side
*
*   3) An admin needs to run tp_chooseteams to begin the team selection process
*
*   4) Once both teams are full and admin should run tp_jointeams to join players to
*      their assigned teams  
*
*   5) tp_disable is only necessary if you need to cancel the team selection process 
*/
       
       
       
       
       
       
                         
#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <ns>

// Sets the size of the teams (including the captain)
#define TEAMSIZE 6

// Set this to one and player 1 will automatically be both captains and
// a bunch of fake players will be added to the player list from which
// to choose teams
#define TESTMODE 0

new g_Team1[TEAMSIZE]
new g_Team2[TEAMSIZE]
new g_PlayerList[32]
new g_Spectators[32]
new g_TeamPickingEnabled = false
new g_Captain1 = 0
new g_Captain2 = 0
new g_Team1Side = 0
new g_Team2Side = 0
new g_AssignmentIndex = 0
new g_MenuOpen = false
new g_CurrentChoosingCaptain = 1
new g_CurrentChoosingTeam = 1
new g_CurrentMenuPage = 0

public plugin_init() 
{
	register_plugin("NS Team Picker","0.1","Doc")

	register_concmd("tp_captain1","CMD_TeamCaptain1",ADMIN_SLAY,"Sets a player as team captain 1")
	register_concmd("tp_captain2","CMD_TeamCaptain2",ADMIN_SLAY,"Sets a player as team captain 2")
	register_concmd("tp_pickteams","CMD_PickTeamsEnable",ADMIN_SLAY,"Begins the team picking process")
	register_concmd("tp_jointeams","CMD_JoinTeams",ADMIN_SLAY,"Joins assigned players to their respective teams")
	register_concmd("tp_cancel","CMD_PickTeamsDisable",ADMIN_SLAY,"Disables the team picking process")
	register_concmd("tp_team1side","CMD_Team1Side",ADMIN_SLAY,"Assigns team 1 to marines or aliens and team 2 to the opposite of team 1")
	register_concmd("tp_pick","CMD_PickPlayer",0,"Console command for captains to choose a player for their team")
	register_concmd("tp_showteams","CMD_ShowTeams",0,"Console command to display the current team assignments")
	
	register_clcmd("say", "handle_say")
	register_clcmd("say_team", "handle_say")	
		
    new keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9
    register_menucmd(register_menuid("Choose Player"), keys, "assignPlayer")
    
    if (TESTMODE == 1)
    {
        g_Captain1 = 1
        g_Captain2 = 1
    } 
}

public clearTeams()
{
	new i
	for (i = 0; i < TEAMSIZE; i++)
	    g_Team1[i] = 0;
	for (i = 0; i < TEAMSIZE; i++)
	    g_Team2[i] = 0;	    
	for (i = 0; i < 32; i++)
	    g_PlayerList[i] = 0;
	for (i = 0; i < 32; i++)
	    g_Spectators[i] = 0;
}

public CMD_TeamCaptain1(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
		
    if (g_TeamPickingEnabled)
    {
        client_print(id, print_chat, "(TeamPicker): Cannot assign new captain during team selection process")
        return PLUGIN_HANDLED   
    }

    ChooseTeamCaptain(id, level, cid, 1)
}

public CMD_TeamCaptain2(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
    
    if (g_TeamPickingEnabled)
    {
        client_print(id, print_chat, "(TeamPicker): Cannot assign new captain during team selection process")
        return PLUGIN_HANDLED   
    }

    ChooseTeamCaptain(id, level, cid, 2)
}

public ChooseTeamCaptain(id, level, cid, captainId)
{
	new arg[32]	
	read_argv(1, arg, 31)	
	new player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF)
	
	if (!player)
		return PLUGIN_CONTINUE	
    
    if (captainId == 1)
        g_Captain1 = player
    else if (captainId == 2)
        g_Captain2 = player
        
    new captainName[32]
    get_user_name(player, captainName, 31)    
    client_print(0, print_chat, "(TeamPicker): %s has been chosen as the team %d's captain", captainName, captainId)      
    
    return PLUGIN_CONTINUE
}

public client_connect(id) 
{ 
    addToArray(g_PlayerList, id)         
} 

public client_disconnect(id) 
{ 
    removeFromArray(g_PlayerList, id)
} 

public handle_say(id)
{
	new Speech[31]
	read_args(Speech, 30)
	remove_quotes(Speech)
	
	if (equal(Speech, "/spec") || equal(Speech, "/play"))
    {
	    new playerName[64]
	    getPlayerName(id, playerName)    
 	    new foundPlayer = false
	    new i   
        for (i = 0; i < 32; i++)
        {
            if (g_Spectators[i] == id)
            {
                foundPlayer = true
                break   
            }
        }   
        
        if (equal(Speech, "/spec"))
        {
            if (!foundPlayer)
            {
                client_print(0, print_chat, "(TeamPicker): %s has chosen to be a spectator",playerName)   
                addToArray(g_Spectators, id)     
                removeFromArray(g_PlayerList, id)                  
            }
            else
            {
                client_print(id, print_chat, "(TeamPicker): you are already a spectator")
            }        
        }
        else
        {
            if (foundPlayer)
            {
                client_print(0, print_chat, "(TeamPicker): %s has chosen to be a player",playerName)   
                removeFromArray(g_Spectators, id)      
                addToArray(g_PlayerList, id) 
            }
            else
            {
                client_print(id, print_chat, "(TeamPicker): you are already designated as a player")
            }         
        }     
        
        return PLUGIN_HANDLED  
    }
    
	return PLUGIN_CONTINUE
}

public CMD_PickPlayer(id, level, cid)
{
    if (id != g_CurrentChoosingCaptain)
        return PLUGIN_HANDLED
        
	new arg[32]	
	read_argv(1, arg, 31)	
	new player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF)
	
	new i
	new valid = false
	if (player != 0) {
	    for (i = 0; i < 32; i++)
	        if (g_PlayerList[i] == player)
	            valid = true
	}
	
    if (valid)
        assignPlayerToTeam(g_CurrentChoosingTeam, player)
    else {
        new playername[64]
        getPlayerName(player, playername)
        client_print(id, print_chat, "(TeamPicker): %s is not a valid team pick, please choose another player", playername)         
    }
        
    return PLUGIN_HANDLED
}

public CMD_ShowTeams(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
		
	displayTeams(10.0)	
}

public CMD_PickTeamsEnable(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

    if (g_Captain1 == 0 || g_Captain2 == 0) {
        client_print(id, print_chat, "(TeamPicker): Team captains have net yet been assigned, please assign team captains")   
        return PLUGIN_CONTINUE        
    }
    
    clearTeams()
    
    g_MenuOpen = false
    g_CurrentChoosingCaptain = 1
    g_CurrentChoosingTeam = 1
    g_CurrentMenuPage = 0
    g_TeamPickingEnabled = true 
    g_AssignmentIndex = 0
    
    new i
    if (TESTMODE == 1)
    {
    	for (i = 0; i < 23; i++)
	        g_PlayerList[i] = i + 1;
    }
    else
    {
        // create the list of players to choose from, exclude the 2 captains
        new players[32] 
        new playerCount, i
        get_players(players, playerCount) 
        new copyIndex = 0
        for (i = 0; i < 32; i++) 
        {
            if (i + 1 > playerCount)
                g_PlayerList[i] = 0
            else
            {    
                if (players[i] == g_Captain1 || players[i] == g_Captain2)
                    copyIndex--
                else
                    g_PlayerList[copyIndex] = players[i]
            }
         
            copyIndex++
        }
    } 
    
    g_Team1[0] = g_Captain1
    g_Team2[0] = g_Captain2   
    
    selectionProcessCycle()
        
    return PLUGIN_CONTINUE
}

public CMD_JoinTeams(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

    g_TeamPickingEnabled = false

    new i
    for (i = 0; i < TEAMSIZE; i++)
    {
        if (g_Team1Side == 1)
        {
            console_cmd(g_Team1[i], "jointeamone")
            console_cmd(g_Team2[i], "jointeamtwo")
        }
        else
        {
            console_cmd(g_Team1[i], "jointeamtwo")
            console_cmd(g_Team2[i], "jointeamone")        
        }
    } 
    
    return PLUGIN_CONTINUE        
}

public selectionProcessCycle()
{
    if (!g_TeamPickingEnabled)
        return PLUGIN_CONTINUE 
        
    updatePlayerList()  
    
    new guideText[1024]    
    format(guideText,1024,"######### Team Picker User Guide #########") 
    format(guideText,1024,"%s^n^nTeam Captains:^n",guideText) 
    format(guideText,1024,"%s^n     use the menu on your left or the console command",guideText) 
    format(guideText,1024,"%s^n     tp_pick <playername> to choose a player",guideText) 
    format(guideText,1024,"%s^n^nEveryone Else:^n",guideText) 
    format(guideText,1024,"%s^n     type /spec if you only want to spectate and",guideText) 
    format(guideText,1024,"%s^n     do not wish to be chosen by a team^n",guideText) 
    format(guideText,1024,"%s^n     type /play if you want to be eligible to play^n",guideText)
    format(guideText,1024,"%s^n     by default everyone is eligible",guideText)     
    
	set_hudmessage(200,200,255,0.2,0.2,0,0.0,3.0,0.0,0.0,3)
	show_hudmessage(0,guideText)  	    

	if (!g_MenuOpen && (g_AssignmentIndex + 1) <= (TEAMSIZE * 2) - 2)
	{
	    g_CurrentMenuPage = 0
        g_MenuOpen = true
  	    g_AssignmentIndex++      	    
	
	    if (g_AssignmentIndex == 1)
	        haveCaptainChoosePlayer(g_Captain1, 1, 0)
        else if (g_AssignmentIndex == 2 || g_AssignmentIndex == 3)
            haveCaptainChoosePlayer(g_Captain2, 2, 0)
        else
        {
            if (g_AssignmentIndex % 2 == 0)
                haveCaptainChoosePlayer(g_Captain1, 1, 0)
            else
                haveCaptainChoosePlayer(g_Captain2, 2, 0)
        }
	}    
	
    displayTeams(3.0)	    
    
    if (g_TeamPickingEnabled)
        set_task(0.5, "selectionProcessCycle")
    
    return PLUGIN_CONTINUE     
}

public updatePlayerList()
{

}

public displayTeams(time_period)
{
    new captain1[32], captain2[32]   
    get_user_name(g_Captain1, captain1, 31)    
    get_user_name(g_Captain2, captain2, 31)      
    
    new displayText[1024]
    new displayText2[1024]
    new team1Text[32], team2Text[32];
    
    if (g_Team1Side == 1)
    {
        format(team1Text,255,"Marines") 
        format(team2Text,255,"Aliens") 
    }
    else if (g_Team2Side == 2)
    {
        format(team1Text,255,"Aliens") 
        format(team2Text,255,"Marines")    
    }
    else
    {
        format(team1Text,255,"Marines") 
        format(team2Text,255,"Aliens")   
    }

    new teamPlayerName[64]
    
    if (g_MenuOpen)
    {
        new captainName[64]
        getPlayerName(g_CurrentChoosingCaptain, captainName)
        format(displayText,1024,"STATUS: Team %d captain (%s), pick a player",g_CurrentChoosingTeam,captainName)       
    }
    else
    {
        format(displayText,1024,"STATUS: Team picking complete") 
    }       
   
    format(displayText,1024,"%s^n^n========= Team 1 (%s) =========",displayText,team1Text) 
    new i
    for (i = 0; i < TEAMSIZE; i++)
    {
        getPlayerName(g_Team1[i], teamPlayerName)
        format(displayText,1024,"%s^n%d. %s",displayText,(i + 1),teamPlayerName)
        if (i == 0)
            format(displayText,1024,"%s %s",displayText,"(Captain)")   
    }
    
	set_hudmessage(200,200,255,0.6,0.2,0,0.0,time_period,0.0,0.0,1)
	show_hudmessage(0,displayText)	    
    
    format(displayText2,1024,"========= Team 2 (%s) =========",team2Text) 
    for (i = 0; i < TEAMSIZE; i++)
    {
        getPlayerName(g_Team2[i], teamPlayerName)
        format(displayText2,1024,"%s^n%d. %s",displayText2,(i + 1),teamPlayerName)
        if (i == 0)
            format(displayText2,1024,"%s %s",displayText2,"(Captain)")          
    }       
    
    format(displayText2,1024,"%s^n^n========= Spectators =========",displayText2) 
    for (i = 0; i < 32; i++) 
    {
        if (g_Spectators[i] == 0)
            break
        
        getPlayerName(g_Spectators[i], teamPlayerName) 
        format(displayText2,1024,"%s^n%d. %s",displayText2,(i + 1),teamPlayerName)    
    }
    
	set_hudmessage(200,200,255,0.6,0.5,0,0.0,time_period,0.0,0.0,4)
	show_hudmessage(0,displayText2)	    
}

public CMD_PickTeamsDisable(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

    g_TeamPickingEnabled = false
    
    return PLUGIN_CONTINUE
}

public CMD_Team1Side(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
		
		
    if (g_TeamPickingEnabled)
    {
        client_print(id, print_chat, "(TeamPicker): Cannot assign team 1 side during team selection process")
        return PLUGIN_HANDLED   
    }
    
	new arg[32]	
	read_argv(1, arg, 31)	
	
	new marineText[] = "marines"
	new alienText[] = "aliens"
	
	if (strcmp(arg, marineText, 1) == 0)
	{
	    g_Team1Side = 1
	    g_Team2Side = 2
	}
	else if (strcmp(arg, alienText, 1) == 0)
	{
	    g_Team1Side = 2
	    g_Team2Side = 1
	}
	else
        client_print(id, print_chat, "(TeamPicker): Invalid team assignment, valid options are 'marines' and 'aliens'")	
        
    return PLUGIN_CONTINUE       
}

public assignPlayer(id, key)
{   
    // map actual key pressed to logical key pressed
    if (key == 9)
        key = 0
    else
        key++        

    // If 8 or 9 is pressed (for back or more), recall menu function with
    // increased or decreased page index, then exit this function
    if (key == 9) {
        g_CurrentMenuPage++
        haveCaptainChoosePlayer(g_CurrentChoosingCaptain, g_CurrentChoosingTeam, g_CurrentMenuPage)     
        return PLUGIN_CONTINUE   
    }
    else if (key == 8 && g_CurrentMenuPage > 0)
    {
        g_CurrentMenuPage--
        haveCaptainChoosePlayer(g_CurrentChoosingCaptain, g_CurrentChoosingTeam, g_CurrentMenuPage)
        return PLUGIN_CONTINUE  
    }
    else if (key == 8)
    {
        haveCaptainChoosePlayer(g_CurrentChoosingCaptain, g_CurrentChoosingTeam, 0)
        return PLUGIN_CONTINUE
    }
    
    assignPlayerToTeam(g_CurrentChoosingTeam, g_PlayerList[key + (7 * g_CurrentMenuPage) + (1 * g_CurrentMenuPage)])
        
    return PLUGIN_CONTINUE
}

public assignPlayerToTeam(teamID, playerID)
{
    // mark menu as being closed so next team can choose
    g_MenuOpen = false

    // create temporary team list from appropriate global team list
    new i
    new TempTeam[TEAMSIZE]
    if (teamID == 1)
        TempTeam = g_Team1
    else
        TempTeam = g_Team2
        
    // assign chosen player to corresponding team player list from global player list
    new playerChosenID
    new tmpPlayerName[64]
    for (i = 0; i < TEAMSIZE; i++)
    {
        if (TempTeam[i] == 0)
        {
            TempTeam[i] = playerID
            playerChosenID = TempTeam[i]
            getPlayerName(playerChosenID, tmpPlayerName)
            client_print(0, print_chat, "(TeamPicker): Team %d has picked %s",g_CurrentChoosingTeam,tmpPlayerName)   
            break
        }
    }    
    
    // remove chosen player from global player list
    new newPlayerList[32]
    new copyIndex = 0
    for (i = 0; i < 32; i++)
    {
        if (g_PlayerList[i] == 0)
            break
            
        if (g_PlayerList[i] == playerChosenID)
            copyIndex--
        else
            newPlayerList[copyIndex] = g_PlayerList[i]        
        
        copyIndex++
    }    
    g_PlayerList = newPlayerList    
    
    // assign newly created team player list to approprate global team list
    if (g_CurrentChoosingTeam == 1)
        g_Team1 = TempTeam
    else
        g_Team2 = TempTeam  
}

public haveCaptainChoosePlayer(captainID, teamID, page)
{
    new menu[256]
    new keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9

    g_CurrentChoosingCaptain = captainID
    g_CurrentChoosingTeam = teamID

    format(menu, 255, "Choose Player (Team %d)^n", teamID)
    new i
    new playerName[64]
    new innerIndex
   
    // create player option menu
    for (i = 0 + (page * 7) + (page * 1); i <= ((page + 1) * 7) + (page * 1); i++)
    {
        innerIndex = i - (page * 7) - (page * 1)
    
        if (g_PlayerList[i] == 0)
            break
        getPlayerName(g_PlayerList[i], playerName)
        format(menu, 255, "%s^n%d. %s",menu,innerIndex,playerName)    
    }
    
    // add back and more option if needed
    if (page > 0)
    {
        format(menu, 255, "%s^n8. <<(back)",menu)  
    }
    else
    {
        format(menu, 255, "%s^n8.",menu) 
    } 
    if (g_PlayerList[i + 1] != 0)
    {
        format(menu, 255, "%s^n9. >>(more)",menu)  
    }

    show_menu(captainID, keys, menu)    
}

public getPlayerName(id, name[64])
{
    if (TESTMODE == 0)
    {
        if (id != 0)
        {
            new playername[18] 
            get_user_name(id, playername, 17) 
            name = playername
        }
        else
            format(name,255,"")
    }
    else
    {
        new tmp[64]
        if (id == 0)
            format(tmp, 255, "")
        else if (id == 1)
            format(tmp, 255, "Bob")
        else if (id == 2)
            format(tmp, 255, "Bill")
        else if (id == 3)
            format(tmp, 255, "Cindy")
        else if (id == 4)
            format(tmp, 255, "Jason")
        else if (id == 5)
            format(tmp, 255, "Rob")
        else if (id == 6)
            format(tmp, 255, "Mindy")
        else if (id == 7)
            format(tmp, 255, "Malia")
        else if (id == 8)
            format(tmp, 255, "Brian")
        else if (id == 9)
            format(tmp, 255, "Paul")
        else if (id == 10)
            format(tmp, 255, "Amber")
        else if (id == 11)
            format(tmp, 255, "Tiffany")    
        else if (id == 12)
            format(tmp, 255, "Matt")
        else if (id == 13)
            format(tmp, 255, "Lauren")
        else if (id == 14)
            format(tmp, 255, "Tim")
        else if (id == 15)
            format(tmp, 255, "McLovin")   
        else if (id == 16)
            format(tmp, 255, "Kathy")
        else if (id == 17)
            format(tmp, 255, "John")
        else if (id == 18)
            format(tmp, 255, "Cartman")
        else if (id == 19)
            format(tmp, 255, "Peter")    
        else if (id == 20)
            format(tmp, 255, "Loius")
        else if (id == 21)
            format(tmp, 255, "Chris")
        else if (id == 22)
            format(tmp, 255, "Homer")
        else if (id == 23)
            format(tmp, 255, "Marge")                                                        
        else
            format(tmp, 255, "")        
            
        name = tmp
    }
}

/***************** Array Utility Functions *****************/

public addToArray(array[32], value)
{
    new i
    for (i = 0; i < 32; i++)
    {
        if (array[i] == 0)
        {
            array[i] = value
            break
        }                
    } 
}

public removeFromArray(array[32], value)
{
    new newArray[32]
    new copyIndex = 0
    new i
    for (i = 0; i < 32; i++)
    {
        if (array[i] == 0)
            break
            
        if (array[i] == value)
            copyIndex--
        else
            newArray[copyIndex] = array[i]        
        
        copyIndex++
    }    
    array = newArray    
}