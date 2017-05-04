#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <csgoitems>
#include <clientprefs>

#include <multicolors>

#pragma newdecls required

#define MK_LENGTH 128
#define MK_FLAG 32

bool g_bDebug = false;

int g_iMusicKit[MAXPLAYERS + 1] =  { -1, ... };
int g_iSite[MAXPLAYERS + 1] =  { 0, ... };

ConVar g_cMessage = null;
ConVar g_cShowDisableMusicKits = null;

Handle g_hMusicKitCookie = null;

char g_sConfig[PLATFORM_MAX_PATH + 1] = "";

public Plugin myinfo = 
{
	name = "Music Kits",
	author = "Franc1sco franug",
	description = "",
	version = "1.0",
	url = "http://steamcommunity.com/id/franug"
};

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sConfig, sizeof(g_sConfig), "configs/musickits.cfg");
	
	LoadTranslations("musickits.phrases");
	
	RegConsoleCmd("sm_music", Command_Music);
	
	g_hMusicKitCookie = RegClientCookie("musickits_cookie", "Cookie for Music Kit Def Index", CookieAccess_Private);
	
	g_cMessage = CreateConVar("musickits_show_message", "1", "Show message on music kit selection", _, true, 0.0, true, 1.0);
	g_cShowDisableMusicKits = CreateConVar("musickits_show_disabled_musickits", "1", "Show disabled music kits (for user without flag)", _, true, 0.0, true, 1.0);
	
	HookEvent("player_spawn", Event_Player);
	HookEvent("player_death", Event_Player);
	HookEvent("round_start", Event_Round);
	HookEvent("round_end", Event_Round);
	
	
	for (int i = 0; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			OnClientCookiesCached(i);
		}
	}
	
	if(CSGOItems_AreItemsSynced())
	{
		UpdateMusicKitConfig();
	}
}

public void CSGOItems_OnItemsSynced()
{
	UpdateMusicKitConfig();
}

public void OnClientCookiesCached(int client)
{
	if (IsClientValid(client))
	{
		char sDefIndex[8];
		GetClientCookie(client, g_hMusicKitCookie, sDefIndex, sizeof(sDefIndex));
		
		int iDefIndex = StringToInt(sDefIndex);
		if(iDefIndex > 0)
		{
			g_iMusicKit[client] = iDefIndex;
			SetEntProp(client, Prop_Send, "m_unMusicID", g_iMusicKit[client]);
		}
	}
}

public Action Event_Player(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsClientValid(client))
	{
		if(g_iMusicKit[client] > 0)
		{
			SetEntProp(client, Prop_Send, "m_unMusicID", g_iMusicKit[client]);
		}
	}
}

public Action Event_Round(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientValid(i))
		{
			if(g_iMusicKit[i] > 0)
			{
				SetEntProp(i, Prop_Send, "m_unMusicID", g_iMusicKit[i]);
			}
		}
	}
}

public Action Command_Music(int client, int args)
{
	if(!IsClientValid(client))
	{
		return Plugin_Handled;
	}
	
	ShowMusicKitsMenu(client);
	
	return Plugin_Continue;
}

public int Menu_MusicKits(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char sDefIndex[MK_LENGTH];
		menu.GetItem(param, sDefIndex, sizeof(sDefIndex));
		g_iMusicKit[client] = StringToInt(sDefIndex);
		SetClientCookie(client, g_hMusicKitCookie, sDefIndex);
		
		if (g_cMessage.BoolValue)
		{
			char sDisplay[MK_LENGTH];
			CSGOItems_GetMusicKitDisplayNameByDefIndex(g_iMusicKit[client], sDisplay, sizeof(sDisplay));
			CPrintToChat(client, "%T", "Music Kit Choosed", client, sDisplay);
		}
		
		g_iSite[client] = menu.Selection;
		
		SetEntProp(client, Prop_Send, "m_unMusicID", g_iMusicKit[client]);
		RequestFrame(Frame_OpenMenu, GetClientUserId(client));
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void Frame_OpenMenu(any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (IsClientValid(client))
	{
		ShowMusicKitsMenu(client);
	}
}

bool IsClientValid(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
		{
			return true;
		}
	}
	
	return false;
}

void ShowMusicKitsMenu(int client)
{
	
	Menu menu = new Menu(Menu_MusicKits);
	
	if (g_iMusicKit[client] > 0)
	{
		char sDisplay[MK_LENGTH];
		CSGOItems_GetMusicKitDisplayNameByDefIndex(g_iMusicKit[client], sDisplay, sizeof(sDisplay));
		
		menu.SetTitle("%T", "Choose a Music Kit Currently", client, sDisplay);
	}
	else
	{
		menu.SetTitle("%T", "Choose a Music Kit", client);
	}
	
	menu.AddItem("0", "No Kit");
	
	for (int i = 0; i <= CSGOItems_GetMusicKitCount(); i++)
	{
		int defIndex = CSGOItems_GetMusicKitDefIndexByMusicKitNum(i);
		
		char sDisplayName[MK_LENGTH];
		CSGOItems_GetMusicKitDisplayNameByDefIndex(defIndex, sDisplayName, sizeof(sDisplayName));
		
		if(strlen(sDisplayName) < 1)
			continue;
		
		char sFlags[32];
		GetMusicKitFlags(defIndex, sFlags, sizeof(sFlags));
		
		bool bFlag = HasFlags(client, sFlags);
		
		if (g_bDebug)
		{
			PrintToChat(client, "%s ([%d] [%s (%d)] [%d])", sDisplayName, defIndex, sFlags, strlen(sFlags), bFlag);
		}
		
		char sKey[MK_LENGTH];
		IntToString(defIndex, sKey, sizeof(sKey));
		
		if (bFlag && g_iMusicKit[client] != defIndex)
		{
			menu.AddItem(sKey, sDisplayName);
		}
		else if (g_iMusicKit[client] == defIndex || (!bFlag && g_cShowDisableMusicKits.BoolValue))
		{
			menu.AddItem(sKey, sDisplayName, ITEMDRAW_DISABLED);
		}
	}
	
	menu.ExitButton = true;
	menu.DisplayAt(client, g_iSite[client], MENU_TIME_FOREVER);
}

void UpdateMusicKitConfig()
{
	KeyValues kvConf = new KeyValues("MusicKits");
	
	if (!kvConf.ImportFromFile(g_sConfig))
	{
		ThrowError("Can' find or read the file %s...", g_sConfig);
		return;
	}
	
	for (int i = 0; i <= CSGOItems_GetMusicKitCount(); i++)
	{
		int defIndex = CSGOItems_GetMusicKitDefIndexByMusicKitNum(i);
		
		char sDisplayName[MK_LENGTH];
		CSGOItems_GetMusicKitDisplayNameByDefIndex(defIndex, sDisplayName, sizeof(sDisplayName));
		
		char sKey[MK_LENGTH];
		IntToString(defIndex, sKey, sizeof(sKey));
		
		bool bFound = false;
			
		bFound = kvConf.JumpToKey(sKey, false);
		
		if (!bFound)
		{
			kvConf.JumpToKey(sKey, true);
			kvConf.SetString("name", sDisplayName);
			kvConf.SetNum("defIndex", defIndex);
			
			LogMessage("Music Kit %s [%d] added!", sDisplayName, defIndex);
		}
		
		kvConf.Rewind();
	}
	
	kvConf.ExportToFile(g_sConfig);
	delete kvConf;
}

void GetMusicKitFlags(int defIndex, char[] flags, int size)
{
	KeyValues kvConf = new KeyValues("MusicKits");
	
	if (!kvConf.ImportFromFile(g_sConfig))
	{
		ThrowError("Can' find or read the file %s...", g_sConfig);
		return;
	}
	
	char sBuffer[12];
	IntToString(defIndex, sBuffer, sizeof(sBuffer));
	
	kvConf.JumpToKey(sBuffer);
	kvConf.GetString("flag", flags, size);
	
	delete kvConf;
}

bool HasFlags(int client, char[] flags)
{
	if(strlen(flags) == 0)
	{
		return true;
	}
	
	int iFlags = GetUserFlagBits(client);
	
	if (iFlags & ADMFLAG_ROOT)
	{
		return true;
	}
	
	AdminFlag aFlags[16];
	FlagBitsToArray(ReadFlagString(flags), aFlags, sizeof(aFlags));
	
	for (int i = 0; i < sizeof(aFlags); i++)
	{
		if (iFlags & FlagToBit(aFlags[i]))
		{
			return true;
		}
	}
	
	return false;
}
