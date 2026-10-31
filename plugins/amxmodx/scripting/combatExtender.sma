
#include <amxmodx>
#include <amxmisc>
#include <ns>

/* Combat eXtender by Xenocidal Skulk
* This plugin is provided as is and without any warrenty implied or otherwise
* and is released under the  Creative Commons Attribution-Non-Commericial-Share
* Alike licence, details available at http://creativecommons.org/licenses/by-nc-sa/2.0/uk/
*
* In addition to the CC-BY-NA-SA licence, this orignal file MUST be distributed with
* any derivative works.
*
* Updated 3 Dec 2008
* You can contact me via e-mail <psychogiant[ats]hotmail[dot]com> or via the
* NS BAD Clan forums located at http://nsbadclan.org/ (User: Ant)
*
* Last Update 4/15/2009 by Doc
*   -added amx_forceextend
*   -modified vote options to be 6 and 7 as opposed to 1 and 2
*/


#define VOTE_PERCENT_NEEDED 0.60
#define VOTE_PERCENT_NEEDED_STRING "60"

new playerCount, loopVar, Float:voteTime;
new players[32];
new votes[3]; // 0 = total, 1 = extend, 2 = end

#define EXTEND 15      //Time to extend in mins
#define CHECK 5      //How long left in game (in mins) to display the extend option

public plugin_init(){
   register_plugin("Combat eXtender","1.3.19","Xenocidal Skulk/Doc");
   
   register_concmd("amx_forceextend","forceExtend",ADMIN_LEVEL_A,"Adds 15 minutes to combat time")
   
    new keys = MENU_KEY_6|MENU_KEY_7
    register_menucmd(register_menuid("Do you wish to extend the Combat Time?"), keys, "menu_handler")   
}
public round_start(){
   voteTime=float((get_cvar_num("mp_combattime")-CHECK)*60);
   set_task(Float:voteTime,"extendTime",2681);
}

public round_end(){
   remove_task(2681);
}

public extendTime(){
   if(!ns_is_combat()) return PLUGIN_HANDLED;

    new menu[256]
    new keys = MENU_KEY_6|MENU_KEY_7

    format(menu, 255, "Do you wish to extend the Combat Time?^n") 
    format(menu, 255, "%s^n6. Yes",menu)    
    format(menu, 255, "%s^n7. No",menu)    

    show_menu(0, keys, menu)    

   set_task(Float:10.0,"vote_results");
   return PLUGIN_HANDLED;
}

public menu_handler(id, key) { 
   new playerName[32];
   get_user_name(id,playerName,31);
   
   key++;

   votes[0]++;

    if (key == 6) {
         votes[1]++;
         client_print(id,print_chat,"[Combat eXtender] You have voted to extend the map.");
         client_print(0,print_console,"[Combat eXtender] %s has voted to extend the map. (Total %i of %i)",playerName,votes[1],votes[0]);
    }
    else if (key == 7) {
         votes[2]++;
         client_print(id,print_chat,"[Combat eXtender] You have voted not to extend the map");
         client_print(0,print_console,"[Combat eXtender] %s has voted not to extend the map. (Total %i of %i)",playerName,votes[2],votes[0]);
    }

   return PLUGIN_HANDLED
}

public vote_results() {

    new yesPercentage[2]    
    float_to_str((float(votes[1]) / float(votes[0]))*100, yesPercentage, 2) 

    if (float(votes[1])/float(votes[0]) >= VOTE_PERCENT_NEEDED) {
      set_cvar_num("mp_combattime",get_cvar_num("mp_combattime")+EXTEND);
      voteTime = (float(EXTEND*60)-10);
      set_task(Float:voteTime,"extendTime",2681);
      client_print(0,print_chat,"[Combat eXtender]Combat time has been extended by %i mins.",EXTEND);
      //client_print(0,print_chat,"[Combat eXtender]%i out of %i voted to extend",votes[1],votes[0]);      
      
      client_print(0,print_chat,"[Combat eXtender] %s percent voted to extend, %s percent is required to extend",yesPercentage,VOTE_PERCENT_NEEDED_STRING);
      
      client_print(0,print_console,"[Combat eXtender]Combat time has been extended by %i mins. %i out of %i voted to extend",EXTEND,votes[1],votes[0]);
   }else{
      client_print(0,print_chat,"[Combat eXtender]Combat time has NOT been extended.");
      //client_print(0,print_chat,"[Combat eXtender]%i out %i voted not to extend",votes[2],votes[0]);
      
      client_print(0,print_chat,"[Combat eXtender] %s percent voted to extend, %s percent is required to extend",yesPercentage,VOTE_PERCENT_NEEDED_STRING);
      
      client_print(0,print_console,"[Combat eXtender]Combat time not extended. %i out of %i voted not to extend",votes[2],votes[0]);
   }

   //Clear used variables
   votes[0] = votes[1] = votes[2] = playerCount = loopVar = 0;

   return PLUGIN_HANDLED;
}

public forceExtend(id,level,cid) 
{
	if(!cmd_access(id,level,cid,1)) 
	    return PLUGIN_HANDLED
	    
	set_cvar_num( "mp_combattime",(get_cvar_num("mp_combattime")+15) )    
	
	client_print(0,print_chat,"Combat time has been extended by %d minutes", 15)
	
	new authid[32], name[32]

	get_user_authid(id, authid, 31)
	get_user_name(id, name, 31)	
	
	log_amx("mp_combattime was extended for 15 minutes by : ^"%s<%d><%s><>^"", name, get_user_userid(id), authid)
	
 	return PLUGIN_HANDLED
}
