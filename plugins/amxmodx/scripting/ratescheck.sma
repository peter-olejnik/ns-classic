/* AMX Mod script
 *
 * RatesCheck v1.60 by pRED*
 * -------------------------
 * 
 * Prints the rates all all connected players into the console
 * Rates checked are cl_cmdrate, cl_updaterate, rate, ex_interp
 *
 * Admin commands
 *      rates_list         - displays a list of all players and their rates
 */

#include <amxmodx>
#include <amxmisc>

#define ADMIN_LEVEL ADMIN_CHAT

new name[32][32]
new rate[32][32]
new updaterate[32][32]
new steamid[35][32]
new cmdrate[32][32]
new interp[32][32]
new players[32]
new num

public plugin_init() {
    
    register_plugin("Rates Checker", "1.61", "pRED*")
 
    register_concmd("rates_list", "rates_list", ADMIN_LEVEL, "Display rates for all players.")
  
    return PLUGIN_CONTINUE
}


public rates_list(id, level, cid) {
    
    //Check if the user has the required access level
    if (!cmd_access(id,level,cid,1)) 
        return PLUGIN_HANDLED    

    //Print an info line to the users console
    client_print(id, print_console, "Generating Rates List...")   

   //Retrieve the rate information
    getrates(id) 
    
    
    
    //Wait 1 second for all query_client_cvar calls to finish the print rate info to console
    set_task(1.0, "printrates", id, "", 0, "a", 1)
    
      
    return PLUGIN_HANDLED
} 


public cmdrate_result_func(id,const cvar[],const value[],const param[])
{
    copy(cmdrate[param[0]],31,value)

}

public interp_result_func(id,const cvar[],const value[], const param[])
{
    copy(interp[param[0]],31,value)

}

public getrates(id)
{
    //Get Number of players in the server
    get_players(players,num,"c") 
       
    //Loop for all players and retrieve rate info
    for (new i[1] = 0; i[0] < num; ++i[0]) {
       
	query_client_cvar(players[i[0]],"cl_cmdrate","cmdrate_result_func",1,i)
	query_client_cvar(players[i[0]],"ex_interp","interp_result_func",1,i)

        set_task(0.5, "getinforates", i[0], "", 0, "a", 1)      //Wait for 0.5 seconds for cvar quering to finish then get the rest of the info  
		
    }

}


public getinforates(i)
{
    get_user_name(players[i], name[i], 31)
    get_user_authid(players[i], steamid[i], 34);
    get_user_info(players[i], "rate", rate[i], 31) 
    get_user_info(players[i], "cl_updaterate", updaterate[i], 31)
}

public printrates(id)
{  	
    //Print an info line to the users console
    client_print(id, print_console, "Id Name SteamId Rate Updaterate Cmdrate Ex_Interp")     

    //Loop for all players and print rates info
    for (new i = 0; i < num; ++i) {
	client_print(id, print_console, "#%d %s %s %s %s %s %s",players[i],name[i], steamid[i], rate[i], updaterate[i], cmdrate[i], interp[i])
    
    }

}
