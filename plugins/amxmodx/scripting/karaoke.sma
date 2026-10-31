/*
Visit: www.das-irren-haus.com for more information
*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <vault>


#define PLUGIN "Karaoke Mod"
#define VERSION "0.3"
#define AUTHOR "TeddyDesTodes"

#define MENU_EXIT	-3
#define	MENU_BACK	-2
#define MENU_MORE	-1

new g_ConfDir[128]
new g_sync_lrcdisplay
new g_sync_lrcdisplay2
new g_Lyr_lenght
new g_Lyr_menu
new g_Song_menu
new g_Nom_menu
new g_Vote_menu
new g_Votes[2] = 0
new g_Nom_Song[64]
new g_Block_Spam[33] = 0
new g_karaoke_running = 0

public plugin_precache(){
	get_configsdir(g_ConfDir,128)
	load_config()
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar("karaoke_version", VERSION, FCVAR_SERVER);
	register_clcmd("say /karaokemenu","view_menu",ADMIN_RESERVATION);
	register_clcmd("say /silence","mp3_stop");
	register_clcmd("say /nominate","nom_menu");
	register_clcmd("amx_karaoke","view_menu",ADMIN_RESERVATION,"opens the karaoke menu");
	register_cvar("kar_enable", "0")
	g_sync_lrcdisplay = CreateHudSyncObj()
	g_sync_lrcdisplay2 = CreateHudSyncObj()
	g_Lyr_menu = menu_create("Karaoke Menu","kar_handle")
	menu_additem(g_Lyr_menu, "start Karaoke", "0")
	menu_additem(g_Lyr_menu, "stop Karaoke", "1")
	menu_additem(g_Lyr_menu, "enable karaoke(precache)", "2")
	menu_additem(g_Lyr_menu, "disable karaoke(precache)", "3")
}
//AMXX wiki new menu sys tutorial
public song_handle(id , menu, item){
	if( item < 0 ) return PLUGIN_CONTINUE
	new cmd[64]
	new access, callback
	menu_item_getinfo(menu, item, access, cmd,63,_,_, callback)
	start_it(cmd)
	return PLUGIN_HANDLED
}
public kar_handle(id , menu, item){
	if( item < 0 ) return PLUGIN_CONTINUE
	new cmd[3]
	new access, callback
	menu_item_getinfo(menu, item, access, cmd,2,_,_, callback)
	new choice = str_to_num(cmd)
	if(choice == 0){
		menu_display(id,g_Song_menu,0)
	}else if(choice == 1){
		stop_it()
	}else if(choice == 2){
		set_cvar_num("kar_enable",1)
	}else{
		set_cvar_num("kar_enable",0)
	}
	return PLUGIN_HANDLED
}
public nom_handle(id , menu, item){
	if( item < 0 ) return PLUGIN_CONTINUE
	if(!equal(g_Nom_Song,"")){
		client_print(id,print_chat,"sorry, another vote is in progress");
		return PLUGIN_CONTINUE
	}
	new cmd[64]
	new access, callback
	menu_item_getinfo(menu, item, access, cmd,63,_,_, callback)
	g_Nom_Song = cmd
	start_vote(id,cmd)
	g_Block_Spam[id] = 1
	set_task(30.0,"block_spam",id+1024);
	return PLUGIN_HANDLED
}
public vote_handle(id,menu,item){
	if( item < 0 ) return PLUGIN_CONTINUE
	new cmd[3]
	new access, callback
	menu_item_getinfo(menu, item, access, cmd,2,_,_, callback)
	new choice = str_to_num(cmd)
	g_Votes[choice]++
	new name[33]
	get_user_name(id,name,32);
	if(choice == 0){
		client_print(0,print_chat,"%s voted for!",name)
	}else{
		client_print(0,print_chat,"%s voted against!",name)
	}
	return PLUGIN_CONTINUE
}
public block_spam(id){
	id = id-1024
	g_Block_Spam[id] = 0
}
public view_menu(id){
	if ((get_user_flags(id) & ADMIN_RCON) || (get_user_flags(id) & ADMIN_LEVEL_A))
	{
		menu_display(id,g_Lyr_menu,0)
		return PLUGIN_HANDLED
	} 
	return PLUGIN_HANDLED
	
}
public nom_menu(id){
	if(g_Block_Spam[id] == 1){
		client_print(id,print_chat,"sorry, you have to wait a bit to nominate another song!");
		return PLUGIN_CONTINUE
	}
	if(get_cvar_num("kar_enable")==0){
		client_print(id,print_chat,"sorry, karaoke isn't enabled, ask an admin!");
		return PLUGIN_CONTINUE
	}
	if(g_karaoke_running == 1){
		client_print(id,print_chat,"sorry, another karaoke is running!");
		return PLUGIN_CONTINUE
	}
	menu_display(id,g_Nom_menu,0)
	return PLUGIN_CONTINUE
}
public start_vote(id,const sng[]){
	
	new name[33]
	get_user_name(id,name,32);
	new head[128]
	format(head,127,"%s want to sing %s",name,sng);
	g_Vote_menu = menu_create(head,"vote_handle")
	menu_additem(g_Vote_menu,"Okay...","0");
	menu_additem(g_Vote_menu,"No way!!!!","1");
	new num,players[32]
	get_players(players,num,"h")
	for(new i = 0;i < num;i++){
		menu_display(players[i],g_Vote_menu,0);
	}
	set_task(10.0,"end_vote")
}

public end_vote(){
	if(g_Votes[0]>g_Votes[1]){
		start_it(g_Nom_Song);
		client_print(0,print_chat,"Vote successful! [FOR : %d AGAINST: %d]",g_Votes[0],g_Votes[1]);
	}else{
		client_print(0,print_chat,"Vote failed! [FOR : %d AGAINST: %d]",g_Votes[0],g_Votes[1]);
	}
	g_Nom_Song = ""
	g_Votes[0] = 0
	g_Votes[1] = 0
	menu_destroy(g_Vote_menu);
}
public load_config(){
	new loadfile[128]
	format(loadfile,127,"%s/karaoke.cfg",g_ConfDir)
	new file = fopen(loadfile,"r")
	g_Song_menu = menu_create("Wich song?","song_handle")
	g_Nom_menu = menu_create("wich song?","nom_handle")
	if ( !file_exists(loadfile) ){
		log_amx("Karaoke Plugin: cant find settings(karaoke.cfg)")
		menu_additem(g_Song_menu, "keine Dateien", "-3")
		return
	}
	new data[128]
	while(!feof(file)){
		fgets(file,data,127)
		new f[128],key[64]
		trim(data)
		if(equal(data,"")) continue
		strbreak(data,key,63,f,127);
		replace_all ( f, 127, "^"", "" ) 
		replace_all ( key, 63, "^"", "" ) 
		set_vaultdata(key,f);
		log_amx("Karaoke Plugin: Loaded %s as %s",f,key)
		if(get_cvar_num("kar_enable")==1)
			engfunc(EngFunc_PrecacheGeneric,f)
		menu_additem(g_Song_menu, key, key)
		menu_additem(g_Nom_menu, key, key)
		
	}
}
public mp3_stop(id){
	client_cmd(id,"mp3 stop");
}
public get_kar_run(){
	return g_karaoke_running
}
public announce(id){
	id = id -2048
	if(g_karaoke_running == 0) return PLUGIN_CONTINUE
	
	set_hudmessage(255, 255, 255, -1.0, 0.65, 0, 6.0, 5.0)
	if(id == 0){
		ShowSyncHudMsg(0, g_sync_lrcdisplay, "Okay let's go!!!!!!!!")
	}else if( id == 1){
		ShowSyncHudMsg(0, g_sync_lrcdisplay, "Attention Karaoke starting in %d second",id)
	}else{
		ShowSyncHudMsg(0, g_sync_lrcdisplay, "Attention Karaoke starting in %d seconds",id)
	}
	return PLUGIN_CONTINUE
}
public start_karaoke(str[]){
	if(g_karaoke_running == 1){
		new text[128]
		DecodeText( str[0], text, 127 )
		new file[128]
		load_lyrics(text)
		get_vaultdata(text,file,127)
		client_cmd(0,"mp3 play %s",file)
	}
}
public stop_it(){
	g_karaoke_running = 0
	client_cmd(0,"mp3 stop")
	for(new i = 0; i <g_Lyr_lenght;i++){
		remove_task(i)
	}
	for(new i = 0;i < 17;i++){
		remove_task(i+2048)
	}
	set_hudmessage(255, 255, 255, -1.0, 0.65, 0, 6.0, 5.0)
	ShowSyncHudMsg(0, g_sync_lrcdisplay, "Karaoke Aborted!!!!")
	
}
public start_it(const str[]){
	stop_it()
	g_karaoke_running = 1
	new param[ 1 ]
	param[ 0 ] = EncodeText( str )
	set_task(15.0,"start_karaoke",16+2048,param,1);
	set_task(15.0,"announce",0+2048)
	set_task(14.0,"announce",1+2048)
	set_task(13.0,"announce",2+2048)
	set_task(12.0,"announce",3+2048)
	set_task(11.0,"announce",4+2048)
	set_task(10.0,"announce",5+2048)
	set_task(5.0,"announce",10+2048)
	announce(15+2048)
	set_hudmessage(255, 255, 255, -1.0, 0.6, _, 0.2, 13.0,1.0,1.0)
	ShowSyncHudMsg(0, g_sync_lrcdisplay2, "Lied: %s",str)
}

public load_lyrics(const lfile[]){
	new loadfile[128]
	format(loadfile,128,"%s/lyrics/%s.lrc",g_ConfDir,lfile)
	log_amx("Karaoke Plugin: Lyrics file %s",loadfile)
	new file = fopen(loadfile,"rt")
	if ( !file_exists(loadfile) ){
		log_amx("Karaoke Plugin: cant find Lyric")
		return
	}
	new data[128]
	g_Lyr_lenght = 0
	while(!feof(file)){
		fgets(file,data,127)
		trim(data)
		new tme[10], text[128]
		if(containi(data,"[") == -1)
			continue
		if(containi(data,"[]") != -1)
			continue
		strtok(data,tme,9,text,127,']')
		new minu[4], sec[6]
		strtok(tme,minu,3,sec,5,':')
		new Float:t = str_to_float(sec)
		new dummy[2]
		strtok(minu,dummy,1,minu,3,'[')
		new Float:m = str_to_float(minu)
		m = m * 60
		t = t+m
		trim(text)
		//server_cmd("say time =  %f",t);
		new param[ 2 ]
		param[ 0 ] = EncodeText( text )
		param[ 1 ] = g_Lyr_lenght
		set_task(t,"show_Lyric",g_Lyr_lenght,param, 2)
		g_Lyr_lenght++
		
	}
}
public show_Lyric(const param[ 2 ]){
	
	new text[128]
	DecodeText( param[0], text, 127 )
	if(param[1]%2 == 0){
		set_hudmessage(255, 255, 255, -1.0, 0.65, _, 0.2, 5.0,1.0,1.0)
		ShowSyncHudMsg(0, g_sync_lrcdisplay, "%s",text)
	}else{
		set_hudmessage(255, 255, 255, -1.0, 0.6, _, 0.2, 5.0,1.0,1.0)
		ShowSyncHudMsg(0, g_sync_lrcdisplay2, "%s",text)
	}
	if(param[1] == g_Lyr_lenght-1)
		g_karaoke_running = 0
}
//http://forums.alliedmods.net/showpost.php?p=538299&postcount=14 
EncodeText( const text[] )
{
    return engfunc( EngFunc_AllocString, text )
}

DecodeText( const text, string[], const length )
{
    global_get( glb_pStringBase, text, string, length )
}
