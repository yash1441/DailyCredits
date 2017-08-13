#pragma semicolon 1

#define PLUGIN_AUTHOR "Simon"
#define PLUGIN_VERSION "1.6"

#include <sourcemod>
#include <sdktools>
#include <store>

#pragma newdecls required

Database db;
ConVar g_hDailyEnable;
ConVar g_hDailyCredits;
ConVar g_hDailyBonus;
ConVar g_hDailyMax;
char CurrentDate[20];

public Plugin myinfo = 
{
	name = "[Store] Daily Credits",
	author = PLUGIN_AUTHOR,
	description = "Daily credits for regular players with MySQL support.",
	version = PLUGIN_VERSION,
	url = "yash1441@yahoo.com"
};

public void OnPluginStart()
{
	CreateConVar("store_daily_credits_version", PLUGIN_VERSION, "Daily Credits Version", FCVAR_DONTRECORD | FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_SPONLY);
	g_hDailyEnable = CreateConVar("store_daily_credits_enable", "1", "Daily Credits enable? 0 = disable, 1 = enable", 0, true, 0.0, true, 1.0);
	g_hDailyCredits = CreateConVar("store_daily_credits_amount", "10", "Amount of Credits.", 0, true, 0.0);
	g_hDailyBonus = CreateConVar("store_daily_credits_bonus", "2", "Increase in Daily Credits on consecutive days.", 0, true, 0.0);
	g_hDailyMax = CreateConVar("store_daily_credits_max", "50", "Max credits that you can get daily.", 0, true, 0.0);
	RegConsoleCmd("sm_daily", Cmd_Daily);
	RegConsoleCmd("sm_dailies", Cmd_Daily);
	FormatTime(CurrentDate, sizeof(CurrentDate), "%Y%m%d"); // Save current date in variable
	InitializeDB();
}

public void InitializeDB()
{
	char Error[255];
	db = SQL_Connect("dailycredits", true, Error, sizeof(Error));
	SQL_SetCharset(db, "utf8");
	if(db == INVALID_HANDLE)
	{
		SetFailState(Error);
	}
	SQL_TQuery(db, SQLErrorCheckCallback, "CREATE TABLE IF NOT EXISTS players (steam_id VARCHAR(20) UNIQUE, last_connect INT(12), bonus_amount INT(12));");
}

public Action Cmd_Daily(int client, int args)
{
	if (!GetConVarBool(g_hDailyEnable)) return Plugin_Handled;
	if (!IsValidClient(client)) return Plugin_Handled;
	char steamId[32];
	if(GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId)))
	{
		char buffer[200];
		Format(buffer, sizeof(buffer), "SELECT * FROM players WHERE steam_id = '%s'", steamId);
		SQL_LockDatabase(db);
		DBResultSet query = SQL_Query(db, buffer);
		SQL_UnlockDatabase(db);
		if (SQL_GetRowCount(query) == 0)
		{
			delete query;
			GiveCredits(client, true);
		}
		else
		{
			delete query;
			GiveCredits(client, false);
		}
	}
	else LogError("Failed to get Steam ID");
	
	return Plugin_Handled;
}

stock void GiveCredits(int client, bool FirstTime)
{
	char buffer[200];
	char steamId[32];
	if(GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId)))
	{
		if (FirstTime)
		{
			Store_SetClientCredits(client, Store_GetClientCredits(client) + GetConVarInt(g_hDailyCredits));
			PrintToChat(client, "[Store] You just recieved your daily credits! [%i Credits]", GetConVarInt(g_hDailyCredits));
			Format(buffer, sizeof(buffer), "INSERT IGNORE INTO players (steam_id, last_connect, bonus_amount) VALUES ('%s', %d, 1)", steamId, StringToInt(CurrentDate));
			SQL_TQuery(db, SQLErrorCheckCallback, buffer);
		}
		else
		{
			Format(buffer, sizeof(buffer), "SELECT * FROM players WHERE steam_id = '%s'", steamId);
			SQL_LockDatabase(db);
			DBResultSet query = SQL_Query(db, buffer);
			SQL_UnlockDatabase(db);
			SQL_FetchRow(query);
			int date2 = SQL_FetchInt(query, 1);
			int bonus = SQL_FetchInt(query, 2);
			delete query;
			int date1 = StringToInt(CurrentDate);
			if ((date1 - date2) == 1)
			{
				int TotalCredits = GetConVarInt(g_hDailyCredits) + (bonus * GetConVarInt(g_hDailyBonus));
				if (TotalCredits > GetConVarInt(g_hDailyMax)) TotalCredits = GetConVarInt(g_hDailyMax);
				Store_SetClientCredits(client, Store_GetClientCredits(client) + TotalCredits);
				PrintToChat(client, "[Store] You just recieved your daily credits! [%i Credits]", TotalCredits);
				Format(buffer, sizeof(buffer), "UPDATE players SET last_connect = %i, bonus_amount = %i WHERE steamid = '%s'", date1, bonus + 1, steamId);
				SQL_TQuery(db, SQLErrorCheckCallback, buffer);
			}
			else if ((date1 - date2) == 0)
			{
				PrintToChat(client, "[Store] Come back tomorrow for your reward.");
			}
			else if ((date1 - date2) > 1)
			{
				PrintToChat(client, "[Store] Your daily credits streak of %i days ended!", bonus);
				Store_SetClientCredits(client, Store_GetClientCredits(client) + GetConVarInt(g_hDailyCredits));
				PrintToChat(client, "[Store] You just recieved your daily credits! [%i Credits]", GetConVarInt(g_hDailyCredits));
				Format(buffer, sizeof(buffer), "UPDATE players SET last_connect = %i, bonus_amount = 1 WHERE steamid = '%s'", date1, steamId);
				SQL_TQuery(db, SQLErrorCheckCallback, buffer);
			}
		}
	}
	else LogError("Failed to get Steam ID");
}

stock bool IsValidClient(int client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (!StrEqual(error, ""))
		LogError(error);
}