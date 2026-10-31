#include <amxmodx>
#include <amxmisc>

// If you happen to have over 128 specific SteamID's specified in the icons.conf (wow), then
// change this number accordingly and recompile!
#define MAX_ADMINS    750


// global storage of icons
new ICONS[MAX_ADMINS][36];      // (32 characters max icon name + 3 for color + null)
new STEAM[MAX_ADMINS][60];      // Steam ID's
new ACCESS[26][36];             // access flag access
new NUM_ACCESS[26];

// for currently connected players
new ICON[33][36];     // icon they should display
new AUTH[33];         // player auth mask
new iSend[33];
new iCD[33];

new szConfig[256];              // config file
new loadedAdmins;
new currentAccess;

/* default for 3.1 values */
new _SI_AUTH=6;
new _SI_ICON=8;


public plugin_init() 
{
  register_clcmd("auth","authhook")
  register_message(get_user_msgid("ScoreInfo"),"hook_scoreinfo");
  set_task(30.0,"checkcd",0,"",0,"b")
  register_srvcmd("adminiconscd","cd_adminiconscheck")
  set_task(1.0,"check_cvar",_,_,_,"b")
  if (cvar_exists("sv_structurelimit"))
  {
    /* this is >= NS 3.2 */
    _SI_AUTH=7;
    _SI_ICON=10;
    register_plugin("Admin Icons (NS3.2)","3.2","sawce");
  }
  else
  {
    register_plugin("Admin Icons (NS3.1)","3.2","sawce");
  }
}
public check_cvar() {
  if (cvar_exists("cd_use_nsicon")) {
    if (get_cvar_num("cd_use_nsicon") > 0) {
      set_cvar_num("cd_use_nsicon",0);
    }
  }
}
public cd_adminiconscheck()
{
  new uid
  new id
  new auth
  new szIndex[6]
  new szAuth[6]
  new i
  read_argv(1,szIndex,5)
  read_argv(2,szAuth,5)
  uid=str_to_num(szIndex)
  auth=str_to_num(szAuth)
  for (i=1;i<=32;i++)
  {
    if (is_user_connected(i))
    {
      if (get_user_userid(i) == uid)
      {
        id=i
      }
    }
  }
  if (auth == 0)
  {
    iCD[id]=1;
  }
  else
  {
    if (iCD[id])
    {
      iCD[id]=0;
    }
  }
  return PLUGIN_HANDLED
}
public checkcd()
{
  // We loop through all players, and check their CD status
  new i
  if (get_cvar_num("cd_use_nsicon") == 0 || cvar_exists("cd_use_nsicon") == 0)
    return PLUGIN_HANDLED
  for (i=1;i<=32;i++)
  {
    if (is_user_connected(i))
    {
      server_cmd("cdstatus adminiconscd %i",get_user_userid(i))
    }
  }
  return PLUGIN_CONTINUE
}

public authhook(id)
{
  if (iSend[id])
  {
    client_print(id,print_console,"Auth ON")
    iSend[id]=0
  }
  else
  {
    client_print(id,print_console,"Auth OFF")
    iSend[id]=1
  }
  return PLUGIN_HANDLED
}
// load icon file in plugin_precache() (so we can precache_generic the icons properly!)
public plugin_precache() 
{
  // reset all icons
  loadedAdmins=0;
  while (loadedAdmins<MAX_ADMINS)
  {
    ICONS[loadedAdmins][0]=0;
    loadedAdmins++;
  }
  loadedAdmins=0;

  currentAccess=0;
  while (currentAccess<25)
  {
    ACCESS[currentAccess][0]=0;
    NUM_ACCESS[currentAccess]=0;
    currentAccess++;
  }
  currentAccess=0;
  // store our config file
  // get file from cvar
  get_configsdir(szConfig,255); // we'll need this from this point on (to save the hash of admins)
  format(szConfig,255,"%s/icons.conf",szConfig);

  if (!file_exists(szConfig))
  {
    server_print("[ICONS] Error, can not load config file `%s`: file not found.",szConfig);
    return;
  }
  
  // hash admins up
  new curLine=0;
  new szText[256];
  new len;
  while (loadedAdmins<MAX_ADMINS && read_file(szConfig,curLine,szText,255,len)) 
  {
    // line syntax:
    // either:
    // STEAM_ID ICON
    // -or-
    // x ICON
    new szName[60]; // STEAMID length is ~40, but just incase I'm wrong :]
    new szIcon[36]; // 32 letters long, 3 letters for color + null terminator + 10 for a buffer incase
    
    szName[0]=0;
    szIcon[0]=0;
    
    // parse read data
    parse(szText,szName,59,szIcon,45);
    // verify it holds data
    if (szName[0]!=0&&szIcon[0]!=0)
    {
      mtrim(szName);
      mtrim(szIcon);
      new handled=0; // to tell the rest of the loop if its taken care of or not
      
      // ignore comments
      if (szName[0]!=';'&&szName[0]!='#')
      {
        // this is an access icon
        if (strlen(szName[0])==1)
        {
          // This is an access setting
          new axs=accessFromLetter(szName[0]);
          if (axs)
          {
            // Check if the access already has an icon assigned to it
            new iter=0;
            while (iter<currentAccess)
            {
              // it does.
              if (axs==NUM_ACCESS[iter])
              {
                if (setupIcon(szIcon))
                  copy(ACCESS[iter],35,szIcon);
                handled=1;
              }
              iter++;
            }
            if (!handled)  // not taken care of yet...
            {
              if (setupIcon(szIcon))
              {
                copy(ACCESS[currentAccess],35,szIcon);
                NUM_ACCESS[currentAccess]=axs;
                currentAccess++;
                handled=1;
              }
            }
          }
        }
        // This is a STEAM_ID icon
        else
        {
          // Check if the STEAM_ID is in the list already
          new iter=0;
          while (iter<loadedAdmins)
          {
            // Yes, it is.
            if (equal(STEAM[iter],szName))
            {
              if (setupIcon(szIcon))
                copy(ICONS[iter],35,szIcon);
              handled=1;
            }
            iter++;
          }
          // not taken care of, meaning it wasn't in list already
          if (!handled)
          {
            if (setupIcon(szIcon))
            {
              copy(STEAM[loadedAdmins],59,szName);
              copy(ICONS[loadedAdmins],35,szIcon);
              loadedAdmins++;
            }
            handled=1;
          }
        }
      }
    }
    curLine++;
  }
}

// Give the player an icon when they connect (if they deserve it)
public client_authorized(id)
{
  iSend[id]=0;
  iCD[id]=0;
  // reset old data...
  ICON[id][0]=0;
  AUTH[id]=0;
  // loop through available steam id specific icons
  new i=0;
  new szID[60];
  get_user_authid(id,szID,59);

  while (i<loadedAdmins)
  {
    // check if it matches...
    if (equal(szID,STEAM[i]))
    {
      AUTH[id]=UTIL_GetIconFromString(ICONS[i],ICON[id],35);
      if (AUTH[id]!=0) {
        if (AUTH[id]<0) AUTH[id]=0; // correct ":default:"
        return;
      }
    }
    i++;
  }
  // this player does not have a custom icon assigned to them
  // check access flags now
  i=0;
  new flags=get_user_flags(id);
  while (i<currentAccess)
  {
    // this player has access
    if (flags & NUM_ACCESS[i]) {
      AUTH[id]=UTIL_GetIconFromString(ACCESS[i],ICON[id],35);
      if (AUTH[id]!=0) {
        if (AUTH[id]<0) AUTH[id]=0; // correct ":default:"
        return;
      }
    }
    i++;
  }
  return;
}

// 1                       2                    3                  4                     5                   6               7                  8                    9                10
//byte:index, short:score, short:frags, short:deaths, short:extra, byte:class, short:auth, short:team, short:health, string:custom
public hook_scoreinfo()
{
  new id=get_msg_arg_int(1);
  if (AUTH[id] && !iSend[id]) // this player should have an icon...
  {
    set_msg_arg_int(_SI_AUTH,ARG_SHORT,AUTH[id]);
    if (AUTH[id] & 512) // custom icon
    {
      set_msg_arg_string(_SI_ICON,ICON[id]);
    }
  }
  else if (iSend[id])
  {
    if (iCD[id])
      set_msg_arg_int(_SI_AUTH,ARG_SHORT,32);
    else
      set_msg_arg_int(_SI_AUTH,ARG_SHORT,0);
  }
  else
  {
    if (iCD[id])
      set_msg_arg_int(_SI_AUTH,ARG_SHORT, get_msg_arg_int(_SI_AUTH) | 32);

  }
}


// Utility functions.

accessFromLetter(l)
{
  switch (l)
  {
    case 'a': return (1<<0);
    case 'b': return (1<<1);
    case 'c': return (1<<2);
    case 'd': return (1<<3);
    case 'e': return (1<<4);
    case 'f': return (1<<5);
    case 'g': return (1<<6);
    case 'h': return (1<<7);
    case 'i': return (1<<8);
    case 'j': return (1<<9);
    case 'k': return (1<<10);
    case 'l': return (1<<11);
    case 'm': return (1<<12);
    case 'n': return (1<<13);
    case 'o': return (1<<14);
    case 'p': return (1<<15);
    case 'q': return (1<<16);
    case 'r': return (1<<17);
    case 's': return (1<<18);
    case 't': return (1<<19);
    case 'u': return (1<<20);
    case 'y': return (1<<24);
    case 'z': return (1<<25);
  }
  return 0;
}

setupIcon(icon[36])
{
  // Check for 'shortcut' names
  if (
        equal(icon,":op:")
     || equal(icon,":redop:")
     || equal(icon,":yellowop:")
     || equal(icon,":blueop:")
     || equal(icon,":default:")
     )
    return 1;




  if (equal(icon,"scoreboard",10))
    return 0;

  // do two things:
  // verify the icon exists and
  // precache it or alert the user if it does not exist


  // remove the last three characters
  new short_icon[33];
  copy(short_icon,strlen(icon)-3,icon);
  new szPath[256];
  format(szPath,255,"gfx/vgui/640_%s.tga",short_icon);
  if (!file_exists(szPath))
  {
    server_print("[ICONS] Error: Can not find icon ^"%s^" for precache.",szPath);
    return 0;
  }
  precache_generic(szPath);
  return 1;
}
mtrim(str[])
{
  new s[256];
  copy(s,255,str);
  new stop=0;
  while(str[stop]==' ')
    stop++;
  new i=0;
  if (stop)
  {
    while (str[stop]&&stop<256)
    {
      s[i]=str[stop];
      i++;
      stop++;
    }
    s[i]=0;
  }
  new t[256];
  copy(t,255,s);
  stop=strlen(s);
  stop--;
  while (s[stop]==' ')
    stop--;
  stop++; // buffer it for \0
  t[stop]=0;
  copy(str,255,t);
}
// return auth mask, byref icon
UTIL_GetIconFromString(szIn[],szOut[],size) {
  if (equal(szIn,":op:")) {
    copy(szOut,size,"");
    return 4;
  } else if (equal(szIn,":default:")) {
    copy(szOut,size,"");
    return -1;
  } else if (equal(szIn,":redop:")) {
    copy(szOut,size,"scoreboardserverop911");
    return 512;
  } else if (equal(szIn,":yellowop:")) {
    copy(szOut,size,"scoreboardserverop990");
    return 512;
  } else if (equal(szIn,":blueop:")) {
    copy(szOut,size,"scoreboardserverop028");
    return 512;
  } else {
    copy(szOut,size,szIn);
    return 512;
  }
  return 0;
}
