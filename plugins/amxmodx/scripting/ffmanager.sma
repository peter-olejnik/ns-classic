#include <amxmodx>
#include <ns>

#define PLUGIN "FFManager"
#define VERSION "0.4"
#define AUTHOR "Nut"

#define VOTETIME 	10.0		//amount of time the vote lasts
#define ENABLEVOTE 	0 		//0 = both 1 = co only 2 = ns only
#define SHOWVOTES 	1		//shows what player voted for
#define ANNOUNCEFF 	1		//display the status of FF on connect
#define YESBUTTON	5
#define NOBUTTON	6

new votesYes, votesNo
new voteRunning, voteEnded

public plugin_init() {
	
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar(PLUGIN,VERSION,FCVAR_SERVER)

	#if ENABLEVOTE == 1
	if (ns_is_combat()) {
	#endif
	
	#if ENABLEVOTE == 2
	if (!ns_is_combat()) {
	#endif

	register_menucmd(register_menuid("Friendly Fire Manager"), (1<<YESBUTTON-1)|(1<<NOBUTTON-1), "FF_VoteMenu")
	register_event("Countdown","event_countdown","a")
	
	#if ENABLEVOTE != 0
	}else{
		pause("ad")
	}
	#endif
	
}

#if ANNOUNCEFF == 1
public client_putinserver(id) {
	if (voteEnded) {
		new param[2]
		param[0] = id
		set_task(5.0,"announce_ff",1234,param,2)
	}
}

public announce_ff(param[]) {
	if (is_user_connected(param[0])) {
		new isEnabled = get_cvar_num("mp_friendlyfire")
		if (isEnabled) {
			client_print(param[0],print_chat,"[FFM]: FF is enabled.")
		}else{
			client_print(param[0],print_chat,"[FFM]: FF is disabled.")
		}
	}
}
#endif

public event_countdown() {
	startVote()
	return PLUGIN_CONTINUE
}

public startVote() {

	for (new i = 1; i < get_maxplayers(); i++) {
		if (is_user_connected(i)) {
			new menu_msg[256]
			format(menu_msg, 255,"FF Manager: ^n^nA vote for friendly fire has started.^n^n%i. Yes^n%i. No",YESBUTTON,NOBUTTON) 
			show_menu(i, (1<<YESBUTTON-1)|(1<<NOBUTTON-1), menu_msg, 15,"Friendly Fire Manager")
		}
	}
	set_task(VOTETIME,"CountVotes")
	voteRunning = 1
	voteEnded = 0
}

public FF_VoteMenu(id,key)  {

	switch(key) {
		case YESBUTTON-1: {	//yes
			if (voteRunning) {
				#if SHOWVOTES == 1
				new name[33]
				get_user_name(id,name,32)
				client_print(0,print_chat,"[FFM]: ( %s ) voted for FF.",name)
				#endif
				votesYes++
			}
			
		}
		case NOBUTTON-1:  {	//no
			if (voteRunning) {
				#if SHOWVOTES == 1
				new name[33]
				get_user_name(id,name,32)
				client_print(0,print_chat,"[FFM]: ( %s ) voted against FF.",name)
				#endif
				votesNo++
			}
		}
	}
	return PLUGIN_HANDLED 
}

public CountVotes() {
	
	if (votesYes > votesNo) {
		set_cvar_string("mp_friendlyfire","1")
		client_print(0,print_chat,"[AMXX]: The vote for FF was successful (FF enabled).")
	}else{
		set_cvar_string("mp_friendlyfire","0")
		client_print(0,print_chat,"[AMXX]: The vote for FF failed (FF disabled).")
	}
	
	//now lets reset the counters
	votesYes = 0
	votesNo = 0
	voteRunning = 0
	voteEnded = 1
}
