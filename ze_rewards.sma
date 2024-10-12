#include <ze_core>
#include <ze_levels>
#include <amx_settings_api>

#define MIN_RANDOM_COINS 0
#define MAX_RANDOM_COINS 500

#define MIN_XP 10
#define MAX_XP 100

new Array:aUsedSteams, bool:g_bCoins[33], bool:g_bXP[33]

public plugin_init()
{
	register_plugin("Get Escape Coins", "1.0", "LevHost Gaming")

	register_clcmd("say /free", "Get_Coins_Cmd_Handler");
	register_clcmd("say_team /free", "Get_Coins_Cmd_Handler");
	
	aUsedSteams = ArrayCreate(34)
}

public Get_Coins_Cmd_Handler(id)
{
	if (!is_user_connected(id))
		return
	
	if (!IsPlayerInArray(aUsedSteams, id))
	{
		new iRandomReward_Coins = random_num(MIN_RANDOM_COINS, MAX_RANDOM_COINS)
		new iRandomReward_XP = random_num(MIN_XP, MAX_XP)
		
		switch(random_num(0,1))
		{
			case 0:
			{
				new iUserCoins = ze_get_user_coins(id)
				
				ze_set_user_coins(id, iUserCoins + iRandomReward_Coins)
				g_bCoins[id] = true
			}
			case 1:
			{
				new iUserEXP = ze_get_user_xp(id)
				
				ze_set_user_xp(id, iUserEXP + iRandomReward_XP)
				g_bXP[id] = true
			}
		}
		
		if (iRandomReward_Coins > 0 && iRandomReward_XP > 0)
		{
			if (g_bCoins[id])
			{
				ze_colored_print(id, "!tCongratulations, you received !g%i !tEscape Coins !y(Try again next map)", iRandomReward_Coins)
			}
			else
			{
				ze_colored_print(id, "!tCongratulations, you received !g%i !tXP !y(Try again next map)", iRandomReward_XP)
			}
		}
		else if (iRandomReward_Coins < 0 && iRandomReward_XP < 0)
		{
			if (g_bCoins[id])
			{
				ze_colored_print(id, "!tOh, sorry you lost !g%i !tEscape Coins !y(Try again next map)", iRandomReward_Coins)
			}
			else
			{
				ze_colored_print(id, "!tOh, sorry you lost !g%i !tXP !y(Try again next map)", iRandomReward_XP)
			}
		}
		else if (iRandomReward_Coins > 0 && iRandomReward_XP < 0)
		{
			if (g_bCoins[id])
			{
				ze_colored_print(id, "!tCongratulations, you received !g%i !tEscape Coins !y(Try again next map)", iRandomReward_Coins)
			}
			else
			{
				ze_colored_print(id, "!tOh, sorry you lost !g%i !tXP !y(Try again next map)", iRandomReward_XP)
			}
		}
		else if (iRandomReward_Coins < 0 && iRandomReward_XP > 0)
		{
			if (g_bCoins[id])
			{
				ze_colored_print(id, "!tOh, sorry you lost !g%i !tEscape Coins !y(Try again next map)", iRandomReward_Coins)
			}
			else
			{
				ze_colored_print(id, "!tCongratulations, you received !g%i !tXP !y(Try again next map)", iRandomReward_XP)
			}
		}
		else
		{
			ze_colored_print(id, "!tOh, sorry you earned/lost nothing !y(Try again next map)")
		}
		
		new szSteamId[34]
		get_user_authid(id, szSteamId, charsmax(szSteamId))
		
		ArrayPushString(aUsedSteams, szSteamId)
	}
	else
	{
		ze_colored_print(id, "!tYou already used it, try again next map.")
	}
}

stock IsPlayerInArray(Array:aSteamArray, id)
{
    new szAuthId[34], szSavedAuthId[34];
   
    get_user_authid(id, szAuthId, charsmax(szAuthId))
   
    for(new i = 0; i < ArraySize(aSteamArray); i++)
    {
        ArrayGetString(aSteamArray, i, szSavedAuthId, charsmax(szSavedAuthId))
       
        if (equal(szSavedAuthId, szAuthId))
        {
            return true
        }
    }
   
    return false
}
