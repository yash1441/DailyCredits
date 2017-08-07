#include <sourcemod>
#include <clientprefs>
#include <store>

#define PLUGIN_AUTHOR "Simon"
#define PLUGIN_VERSION "1.1"

Handle g_hDailyEnable;
Handle g_hDailyCredits;
Handle g_hDailyBonus;
Handle g_hDailyCookie;
Handle g_hDailyBonusCookie;
char CurrentDate[20];
char SavedDate[MAXPLAYERS + 1][50];
char SavedBonus[MAXPLAYERS + 1][4];
bool FirstDay[MAXPLAYERS + 1] = {false,...};


public Plugin myinfo = 
{
	name = "[Store] Daily Credits",
	author = PLUGIN_AUTHOR,
	description = "Daily credits for regular players.",
	version = PLUGIN_VERSION,
	url = "yash1441@yahoo.com"
};

public void OnPluginStart()
{
	CreateConVar("store_daily_credits_version", PLUGIN_VERSION, "Daily Credits Version", FCVAR_DONTRECORD | FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_SPONLY);
	g_hDailyEnable = CreateConVar("store_daily_credits_enable", "1", "Daily Credits enable? 0 = disable, 1 = enable", 0, true, 0.0, true, 1.0);
	g_hDailyCredits = CreateConVar("store_daily_credits_amount", "10", "Amount of Credits.", 0, true, 0.0);
	g_hDailyBonus = CreateConVar("store_daily_credits_bonus", "2", "Increase in Daily Credits on consecutive days.", 0, true, 0.0);
	g_hDailyCookie = RegClientCookie("DailyCreditsDate", "Cookie for daily credits last used date.", CookieAccess_Protected);
	g_hDailyBonusCookie = RegClientCookie("DailyCreditsBonus", "Cookie for daily credits bonus.", CookieAccess_Protected);
	for(new i = MaxClients; i > 0; --i)
	{
		if (!AreClientCookiesCached(i))
			continue;
		OnClientCookiesCached(i);
	}
	RegConsoleCmd("sm_daily", Cmd_Daily);
	RegConsoleCmd("sm_dailies", Cmd_Daily);
	FormatTime(CurrentDate, sizeof(CurrentDate), "%Y%m%d"); // Save current date in variable
}

public OnClientCookiesCached(client)
{
	GetClientCookie(client, g_hDailyCookie, SavedDate[client], sizeof(SavedDate[])); // Get saved date on client connecting
	if (StrEqual(SavedDate[client], ""))
		FirstDay[client] = true;
	if ((StringToInt(SavedDate[client]) - StringToInt(CurrentDate)) > 1 || (StringToInt(SavedDate[client]) - StringToInt(CurrentDate)) < 0)
		SetClientCookie(client, g_hDailyBonusCookie, "0"); // Set daily bonus to 0 if client connected after long time or invalid time
	GetClientCookie(client, g_hDailyBonusCookie, SavedBonus[client], sizeof(SavedBonus[])); // Get saved bonus on client connecting
}

public Action Cmd_Daily(int client, int args)
{
	if (!GetConVarBool(g_hDailyEnable)) return Plugin_Handled;
	if((IsValidClient(client) && IsDailyAvailable(client)) || FirstDay[client]) // Check if daily is available
	{
		GiveCredits(client); // Give credits
	}
	return Plugin_Handled;
}

stock void GiveCredits(client)
{
	Store_SetClientCredits(client, Store_GetClientCredits(client) + GetConVarInt(g_hDailyCredits) + ReturnDailyBonus(client)); // Giving credits
	PrintToChat(client, "[Store] You just recieved your daily credits! [%i Credits]", GetConVarInt(g_hDailyCredits) + ReturnDailyBonus(client)); // Chat 
	SetClientCookie(client, g_hDailyCookie, CurrentDate); // Set saved date to today
	IntToString(StringToInt(SavedBonus[client]) + 1, SavedBonus[client], sizeof(SavedBonus[])); // Add 1 to bonus
	SetClientCookie(client, g_hDailyBonusCookie, SavedBonus[client]); // Save bonus
	Format(SavedDate[client], sizeof(SavedDate[]), CurrentDate);
}

stock bool IsDailyAvailable(int client)
{
	if (StringToInt(SavedDate[client]) - StringToInt(CurrentDate) == 1)
	{
		return true; // If saved date - current date = 1 return true
	}
	
	else if (StringToInt(SavedDate[client]) - StringToInt(CurrentDate) == 0)
	{
		PrintToChat(client, "[Daily] Come back tomorrow for your reward."); // if = 0 then tomorrow msg
		return false;
	}
	
	else return false;
}

public int ReturnDailyBonus(int client)
{
	return (StringToInt(SavedBonus[client]) * GetConVarInt(g_hDailyBonus)); // Return saved bonus x daily bonus value
}

stock bool IsValidClient(client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}
