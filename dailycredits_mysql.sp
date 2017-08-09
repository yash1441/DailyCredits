#pragma semicolon 1

#define PLUGIN_AUTHOR "Simon"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <store>

#pragma newdecls required

Database db;
Handle g_hDailyEnable;
Handle g_hDailyCredits;
Handle g_hDailyBonus;
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
	RegConsoleCmd("sm_daily", Cmd_Daily);
	RegConsoleCmd("sm_dailies", Cmd_Daily);
	FormatTime(CurrentDate, sizeof(CurrentDate), "%Y%m%d"); // Save current date in variable
	InitializeDB();
}

public void InitializeDB()
{
	char Error[255];
	db = SQL_Connect("dailycredits", true, Error, sizeof(Error));
	if(db == INVALID_HANDLE)
	{
		SetFailState(Error);
	}
	SQL_LockDatabase(db);
	SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS players (steam_id TEXT, last_connect INTEGER, bonus_amount INTEGER);");
	SQL_UnlockDatabase(db);
}

public Action Cmd_Daily(int client, int args)
{
	if (!GetConVarBool(g_hDailyEnable)) return Plugin_Handled;
	if (!IsValidClient(client)) return Plugin_Handled;
	char steamId[32];
	GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
	char buffer[200];
	Format(buffer, sizeof(buffer), "SELECT * FROM players WHERE steam_id = '%s'", steamId);
	DBResultSet query = SQL_Query(db, buffer);
	if (query == null)
	{
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		GiveCredits(client, true);
	}
	else
	{
		GiveCredits(client, false);
		delete query;
	}
	return Plugin_Handled;
}

stock void GiveCredits(int client, bool FirstTime)
{
	char buffer[200];
	char steamId[32];
	GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
	if (FirstTime)
	{
		int temp = 1;
		Store_SetClientCredits(client, Store_GetClientCredits(client) + GetConVarInt(g_hDailyCredits));
		PrintToChat(client, "[Store] You just recieved your daily credits! [%i Credits]", GetConVarInt(g_hDailyCredits));
		Format(buffer, sizeof(buffer), "INSERT INTO players VALUES ('%s', '%i', '%i')", steamId, CurrentDate, temp);
	}
	else
	{
		char connection[50];
		int bonus;
		Format(buffer, sizeof(buffer), "SELECT * FROM players WHERE steam_id = '%s'", steamId);
		DBResultSet query = SQL_Query(db, buffer);
		SQL_FetchRow(query);
		SQL_FetchString(query, 1, connection, sizeof(connection));
		bonus = SQL_FetchInt(query, 2);
		delete query;
		int date1 = StringToInt(CurrentDate);
		int date2 = StringToInt(connection);
		if ((date1 - date2) == 1)
		{
			int calc_bonus = bonus * GetConVarInt(g_hDailyBonus);
			Store_SetClientCredits(client, Store_GetClientCredits(client) + GetConVarInt(g_hDailyCredits) + calc_bonus);
			PrintToChat(client, "[Store] You just recieved your daily credits! [%i Credits]", GetConVarInt(g_hDailyCredits) + calc_bonus);
			Format(buffer, sizeof(buffer), "UPDATE players SET last_connect = '%s', bonus_amount = '%i' WHERE steamid = '%s'", CurrentDate, bonus + 1, steamId);
			SQL_FastQuery(db, buffer);
		}
		else if ((date1 - date2) == 0)
		{
			PrintToChat(client, "[Daily] Come back tomorrow for your reward.");
		}
		else if ((date1 - date2) > 1)
		{
			PrintToChat(client, "[Daily] Your daily credits streak of %i days ended!", bonus);
			Store_SetClientCredits(client, Store_GetClientCredits(client) + GetConVarInt(g_hDailyCredits));
			PrintToChat(client, "[Store] You just recieved your daily credits! [%i Credits]", GetConVarInt(g_hDailyCredits));
			Format(buffer, sizeof(buffer), "UPDATE players SET last_connect = '%s', bonus_amount = '1' WHERE steamid = '%s'", CurrentDate, steamId);
			SQL_FastQuery(db, buffer);
		}
	}
}

stock bool IsValidClient(int client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}