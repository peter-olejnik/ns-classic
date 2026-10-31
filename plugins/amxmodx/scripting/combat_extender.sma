/* Combat Time Extender
* This plugin is meant to ask the players towards the end of the game if they would 
* like to extend game play time (to get more levels or something)
*
* Cvars
* extend_prop This is the percent of people you want to say yes before extending time (default 75)
* extend_time This is the amount of time (in minutes) that you want the map to extend every time (default 10)
*
* Commands
* amx_extend This is the console command any admin (with vote privaleges) can execute, to prematurely start extend combat time vote.
*
* This was made by Newbster. 
* If there are n e bugs please report them to CBribiescas@satx.rr.com
* Visit my clan website at www.j00s.com (j00s is spelt with zeros, not letters)
* Visit the clan forums at forums.j00s.com (j00s is spelt with zeros, not letters)
* Natural Selection clan Server at www.j00s.com (j00s is spelt with zeros, not letters)
*
* Known Problems:
* if game is on a map for more than one game, the combat time wont reset itself
* If n e one knows the function to catch a change map please e-mail me!!! (or post it)
* Also, if n e one know the function to catch the start of a game pleae e-mail!!! (or post it)
* 
* Changelog:
*
*   v1.1 (by Doc)
*   -added amx_forceextend command so admins with access to ADMIN_CHAT can extend combat time without taking a vote
*/
#include <amxmodx>
#include <amxmisc>

// array of votes - votes[1] is yes and votes[0] is no
new votes[2]
new Float:temp
public plugin_init() 
{
	register_plugin("Combat Extender","1.1","Newbster/Doc")
   	register_menucmd(register_menuid("voting"),1023,"voting_handler")
   	register_concmd("amx_extend","vote",ADMIN_VOTE,"Vote to extend combat time")
   	register_concmd("amx_forceextend","forceExtend",ADMIN_CHAT,"Adds 15 minutes to combat time")
   	register_cvar("extend_prop", "75")
   	register_cvar("extend_time", "15")
   	temp = float(get_cvar_num("mp_combattime")*60-300)
	set_task(temp,"vote",9678,"",0,"b")
}

public vote(id,level,cid) 
{
	if(!cmd_access(id,level,cid,1)) 
	{
	return PLUGIN_HANDLED
   	}

   	new menubody[128], keys
   	format(menubody,127,"Do you want to extend the combat time %d minutes?^n^n1. Yes ma'am^n2. No ma'am",get_cvar_num("extend_time"))
   	keys = MENU_KEY_1|MENU_KEY_2

   	// player, keys, text, hold time, title
	for(new i = 0; i <= get_playersnum(); i++)
   		show_menu(i,keys,menubody,6,"voting")

   	set_task(get_cvar_float("amx_vote_time"),"display_results")

 	return PLUGIN_HANDLED
}

public forceExtend(id,level,cid) 
{
	if(!cmd_access(id,level,cid,1)) 
	    return PLUGIN_HANDLED
	    
	set_cvar_num( "mp_combattime",(get_cvar_num("mp_combattime")+get_cvar_num("extend_time")) )    
	
	client_print(0,print_chat,"Combat time has been extended by %d minutes", get_cvar_num("extend_time"));

 	return PLUGIN_HANDLED
}

public voting_handler(id,key) 
{

   // number they pressed -> key variable
   // 1 -> 0
   // 2 -> 1
   // 3 -> 2
   // ...
   // 8 -> 7
   // 9 -> 8
   // 0 -> 9

   // if they voted yes
	if(key == 0) 
	{
		votes[0]++
   	}

 	// if they voted no
   	if(key == 1) 
   	{
      	votes[1]++
   	}

   	// if we should display their choices
   	if(get_cvar_num("amx_vote_answers")) 
   	{
      	new username[32];
      	get_user_name(id,username,31);
      	client_print(0,print_chat,"%s voted %s",username,(key == 0) ? "Yes" : "No");
   	}

}

public display_results() 
{
	client_print(0,print_chat,"Extend Combat Time %d minutes?: %i Yes || %i No",get_cvar_num("extend_time"),votes[0],votes[1])

   	new playerCount = get_playersnum ()
	new Float:temp1=float(votes[0])/float(playerCount)
 	new Float:temp2=(float(get_cvar_num("extend_prop"))/float(100))
   	if( temp1 >= temp2 )
   	{
   		set_cvar_num( "mp_combattime",(get_cvar_num("mp_combattime")+get_cvar_num("extend_time")) )
   	}
  	votes[0] = 0
  	votes[1] = 0
   	return PLUGIN_CONTINUE
} 
