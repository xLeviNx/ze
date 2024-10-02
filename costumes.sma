#include <amxmodx>
#include <amxmisc>
#include <cs_player_models_api>
#include <hamsandwich>
#include <fakemeta>
#include <nvault>
#include <sqlx>
#include ze_core

#define PLUGIN "CSO Costumes"
#define VERSION "1.0"
#define AUTHOR "LevHost Gaming"

#define ZP_SUPPORT

#if defined ZP_SUPPORT
	#include <ze_core>
#endif

#if !defined client_disconnected
	#define client_disconnected client_disconnect
#endif

#define PREFIX_CHAT "!g[ZE Player Customizer]!n"
#define PREFIX_MENU "\r[ZE Player Customizer]"

#define MAX_COSTUMES 257

#if defined ZP_SUPPORT
	new Total_Skin = 1
#else
	new Total_SkinCT = 1, Total_SkinTR = 1
#endif

new File[64], Total_Head = 1, Total_Back = 1, Total_Pelvis = 1
new Handle:g_SqlTuple, g_Error[512], g_Vault, g_szAuthID[33][35]

enum _:Configuration
{
	Cash_per_Kill,
	Saving_Method,
	Host[128],
	User[128],
	Pass[128],
	Db[128],
	Table[128],
	Vault[128],
	ZP43_Support
}

enum _:Vars
{
	g_name[128],
	g_price,
	g_model[128],
	g_anim,
	g_preview[128]
}

enum _:Vars2
{
#if defined ZP_SUPPORT
	g_skin,
	g_acquiredSkin[MAX_COSTUMES],
#else
	g_skinct,
	g_skintr,
	g_acquiredSkinCT[MAX_COSTUMES],
	g_acquiredSkinTR[MAX_COSTUMES],
#endif
	g_head,
	g_back,
	g_pelvis,
	g_cash,
	g_buying,
	g_costume,
	g_CostumeModelHead,
	g_CostumeModelBack,
	g_CostumeModelPelvis,
	g_acquiredHead[MAX_COSTUMES],
	g_acquiredBack[MAX_COSTUMES],
	g_acquiredPelvis[MAX_COSTUMES],
	bool:is_connected,
	bool:is_bot_or_hltv
}

#if defined ZP_SUPPORT
	new Costumes_Skin[MAX_COSTUMES][Vars]
#else
	new Costumes_SkinCT[MAX_COSTUMES][Vars], Costumes_SkinTR[MAX_COSTUMES][Vars]
#endif

new Costumes_Head[MAX_COSTUMES][Vars], Costumes_Back[MAX_COSTUMES][Vars], Costumes_Pelvis[MAX_COSTUMES][Vars], g_vars[33][Vars2], g_settings[Configuration]

#if defined ZP_SUPPORT
	const y = 1; const z = 3
#else
	const y = 2; const z = 4
#endif

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_dictionary("cso_costumes.txt")

	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	register_event("DeathMsg", "Event_DeathMsg", "a")

	register_clcmd("say /skins", "clcmd_costumes")
	register_clcmd("say_team /skins", "clcmd_costumes")
	register_clcmd("skins", "clcmd_costumes")
	register_clcmd("say /levbucks", "clcmd_cash")
	register_clcmd("say_team /levbucks", "clcmd_cash")
	register_clcmd("levbucks", "clcmd_cash")
	register_concmd("costumes_give_cash", "Cmd_GiveCash", ADMIN_RCON, "<nick|#userid> <amount>")

	if(g_settings[Saving_Method] != 0)
	{
		register_event("TextMsg", "Save_Data", "a", "2=#Game_Commencing", "2=#Game_will_restart_in")
		register_event("SendAudio", "Save_Data", "a", "2=%!MRAD_terwin", "2=%!MRAD_ctwin", "2=%!MRAD_rounddraw")
		register_forward(FM_Sys_Error, "Save_Data")
		register_forward(FM_GameShutdown, "Save_Data")
		register_forward(FM_ServerDeactivate, "Save_Data")

		switch(g_settings[Saving_Method])
		{
			case 1: Nvault_Init()
			case 2: MySql_Init()
		}
	}
}

public plugin_precache()
{
	new cfgDir[32]
	get_configsdir(cfgDir, charsmax(cfgDir))
	formatex(File, charsmax(File), "%s/costumes.ini", cfgDir)

	Load_Configuration(0)
	Load_Costumes()

#if defined ZP_SUPPORT
	for(new i = 1; i < Total_Skin; i++)
	{
		precache_player_model(Costumes_Skin[i][g_model])
	}
#else
	for(new i = 1; i < Total_SkinCT; i++)
	{
		precache_player_model(Costumes_SkinCT[i][g_model])
	}
	/*for(new i = 1; i < Total_SkinTR; i++)
	{
		precache_player_model(Costumes_SkinTR[i][g_model])
	}*/
#endif

	for(new i = 1; i < Total_Head; i++)
	{
		precache_model(Costumes_Head[i][g_model])
	}

	for(new i = 1; i < Total_Back; i++)
	{
		precache_model(Costumes_Back[i][g_model])
	}

	for(new i = 1; i < Total_Pelvis; i++)
	{
		precache_model(Costumes_Pelvis[i][g_model])
	}
}

public plugin_end()
{
	switch(g_settings[Saving_Method])
	{
		case 1: nvault_close(g_Vault)
		case 2: SQL_FreeHandle(g_SqlTuple)
	}
}

Load_Configuration(MySQL_to_Nvault)
{
	if(file_exists(File))
	{
		new sfLineData[256], Config[32], Value[128], value
		new file = fopen(File, "rt")

		while(file && !feof(file))
		{
			fgets(file, sfLineData, charsmax(sfLineData))

			if(sfLineData[0] == ';' || strlen(sfLineData) <= 2 || (sfLineData[0] == '/' && sfLineData[1] == '/'))
			{
				continue
			}

			parse(sfLineData, Config, charsmax(Config), Value, charsmax(Value))
			value = str_to_num(Value)

			if(MySQL_to_Nvault)
			{
				if(equal(Config, "VAULT"))
				{
					if(!Value[0])
					{
						server_print("[CSO Costumes] No Vault name was defined! Continuing with the default setting: ^"cso_costumes^".")
						copy(g_settings[Vault], charsmax(g_settings[Vault]), "cso_costumes")
					}
					else
					{
						copy(g_settings[Vault], charsmax(g_settings[Vault]), Value)
					}

					Nvault_Init()
					break
				}
				else
				{
					continue
				}
			}

			if(equal(Config, "CASH_PER_KILL"))
			{
				if(value <= 0)
				{
					server_print("[CSO Costumes] Cash per kill is less than or equal to 0! Continuing with the default setting: 5.")
					g_settings[Cash_per_Kill] = 5
				}
				else
				{
					g_settings[Cash_per_Kill] = value
				}

				continue
			}
			else if(equal(Config, "SAVING_METHOD"))
			{
				switch(value)
				{
					case 0..2: g_settings[Saving_Method] = value
					default:
					{
						server_print("[CSO Costumes] No valid saving system was defined! Continuing without saving system.")
						g_settings[Saving_Method] = 0
					}
				}

				continue
			}
			else if(equal(Config, "ZP43_SUPPORT"))
			{
			#if defined ZP_SUPPORT
				switch(value)
				{
					case 0,1: g_settings[ZP43_Support] = value
					default:
					{
						server_print("[CSO Costumes] No valid input was defined! Continuing without Zombie Plague 4.3 Support.")
						g_settings[ZP43_Support] = 0
					}
				}
			#else
				if(value >= 1)
				{
					server_print("[CSO Costumes] You need to edit the source code and uncomment ^"#define ZP_SUPPORT^" in order to support Zombie Plague 4.3 (line 13).")
				}
			#endif

				continue
			}

			switch(g_settings[Saving_Method])
			{
				case 0: break
				case 1:
				{
					if(equal(Config, "VAULT"))
					{
						if(!Value[0])
						{
							server_print("[CSO Costumes] No Vault name was defined! Continuing with the default setting: ^"cso_costumes^".")
							copy(g_settings[Vault], charsmax(g_settings[Vault]), "cso_costumes")
						}
						else
						{
							copy(g_settings[Vault], charsmax(g_settings[Vault]), Value)
						}

						break
					}
				}
				case 2:
				{
					if(equal(Config, "HOST"))
					{
						if(!Value[0])
						{
							server_print("[CSO Costumes] No Hostname was defined! Continuing with nVault saving system.")
							g_settings[Saving_Method] = 1
						}
						else
						{
							copy(g_settings[Host], charsmax(g_settings[Host]), Value)
						}
					}
					else if(equal(Config, "USER"))
					{
						if(!Value[0])
						{
							server_print("[CSO Costumes] No Username was defined! Continuing with nVault saving system.")
							g_settings[Saving_Method] = 1
						}
						else
						{
							copy(g_settings[User], charsmax(g_settings[User]), Value)
						}
					}
					else if(equal(Config, "PASSWORD"))
					{
						copy(g_settings[Pass], charsmax(g_settings[Pass]), Value)
					}
					else if(equal(Config, "DATABASE"))
					{
						if(!Value[0])
						{
							server_print("[CSO Costumes] No Database name was defined! Continuing with nVault saving system.")
							g_settings[Saving_Method] = 1
						}
						else
						{
							copy(g_settings[Db], charsmax(g_settings[Db]), Value)
						}
					}
					else if(equal(Config, "TABLE"))
					{
						if(!Value[0])
						{
							server_print("[CSO Costumes] No Table name was defined! Continuing with the default setting: ^"cso_costumes^".")
							copy(g_settings[Table], charsmax(g_settings[Table]), "cso_costumes")
						}
						else
						{
							copy(g_settings[Table], charsmax(g_settings[Table]), Value)
						}

						break
					}
				}
			}
		}

		if(file && !MySQL_to_Nvault)
		{
			server_print("[CSO Costumes] Configuration loaded")
			fclose(file)
		}
	}
	else
	{
		set_fail_state("File ^"costumes.ini^" is missing! Plugin stopped.")
	}
}

Load_Costumes()
{
	if(file_exists(File))
	{
		new sfLineData[256], Costume[10], CostumeName[128], CostumePrice[10], CostumeModel[128], CostumeAnim[10], CostumePreview[128], TotalCostumes = 0
		new file = fopen(File, "rt")

		while(file && !feof(file))
		{
			fgets(file, sfLineData, charsmax(sfLineData))

			if(sfLineData[0] != '"')
			{
				continue
			}

			parse(sfLineData, Costume, charsmax(Costume), CostumeName, charsmax(CostumeName), CostumePrice, charsmax(CostumePrice), CostumeModel, charsmax(CostumeModel), CostumeAnim, charsmax(CostumeAnim), CostumePreview, charsmax(CostumePreview))

		#if defined ZP_SUPPORT
			if(equal(Costume, "SkinCT") || equal(Costume, "SkinTR"))
			{
				copy(Costumes_Skin[Total_Skin][g_name], charsmax(Costumes_Skin[][g_name]), CostumeName)
				Costumes_Skin[Total_Skin][g_price] = str_to_num(CostumePrice)
				copy(Costumes_Skin[Total_Skin][g_model], charsmax(Costumes_Skin[][g_model]), CostumeModel)
				copy(Costumes_Skin[Total_Skin][g_preview], charsmax(Costumes_Skin[][g_model]), CostumePreview)

				Total_Skin += 1
				TotalCostumes += 1
			}
		#else
			if(equal(Costume, "SkinCT"))
			{
				copy(Costumes_SkinCT[Total_SkinCT][g_name], charsmax(Costumes_SkinCT[][g_name]), CostumeName)
				Costumes_SkinCT[Total_SkinCT][g_price] = str_to_num(CostumePrice)
				copy(Costumes_SkinCT[Total_SkinCT][g_model], charsmax(Costumes_SkinCT[][g_model]), CostumeModel)
				copy(Costumes_SkinCT[Total_SkinCT][g_preview], charsmax(Costumes_SkinCT[][g_preview]), CostumePreview)

				Total_SkinCT += 1
				TotalCostumes += 1
			}
			else if(equal(Costume, "SkinTR"))
			{
				copy(Costumes_SkinTR[Total_SkinTR][g_name], charsmax(Costumes_SkinTR[][g_name]), CostumeName)
				Costumes_SkinTR[Total_SkinTR][g_price] = str_to_num(CostumePrice)
				copy(Costumes_SkinTR[Total_SkinTR][g_model], charsmax(Costumes_SkinTR[][g_model]), CostumeModel)
				copy(Costumes_SkinTR[Total_SkinTR][g_preview], charsmax(Costumes_SkinTR[][g_preview]), CostumePreview)

				Total_SkinTR += 1
				TotalCostumes += 1
			}
		#endif
			else if(equal(Costume, "Head"))
			{
				copy(Costumes_Head[Total_Head][g_name], charsmax(Costumes_Head[][g_name]), CostumeName)
				Costumes_Head[Total_Head][g_price] = str_to_num(CostumePrice)
				copy(Costumes_Head[Total_Head][g_model], charsmax(Costumes_Head[][g_model]), CostumeModel)
				Costumes_Head[Total_Head][g_anim] = str_to_num(CostumeAnim)
				copy(Costumes_Head[Total_Head][g_preview], charsmax(Costumes_Head[][g_preview]), CostumePreview)

				Total_Head += 1
				TotalCostumes += 1
			}
			else if(equal(Costume, "Back"))
			{
				copy(Costumes_Back[Total_Back][g_name], charsmax(Costumes_Back[][g_name]), CostumeName)
				Costumes_Back[Total_Back][g_price] = str_to_num(CostumePrice)
				copy(Costumes_Back[Total_Back][g_model], charsmax(Costumes_Back[][g_model]), CostumeModel)
				Costumes_Back[Total_Back][g_anim] = str_to_num(CostumeAnim)
				copy(Costumes_Back[Total_Back][g_preview], charsmax(Costumes_Back[][g_preview]), CostumePreview)

				Total_Back += 1
				TotalCostumes += 1
			}
			else if(equal(Costume, "Pelvis"))
			{
				copy(Costumes_Pelvis[Total_Pelvis][g_name], charsmax(Costumes_Pelvis[][g_name]), CostumeName)
				Costumes_Pelvis[Total_Pelvis][g_price] = str_to_num(CostumePrice)
				copy(Costumes_Pelvis[Total_Pelvis][g_model], charsmax(Costumes_Pelvis[][g_model]), CostumeModel)
				Costumes_Pelvis[Total_Pelvis][g_anim] = str_to_num(CostumeAnim)
				copy(Costumes_Pelvis[Total_Pelvis][g_preview], charsmax(Costumes_Pelvis[][g_preview]), CostumePreview)

				Total_Pelvis += 1
				TotalCostumes += 1
			}

			if(TotalCostumes >= MAX_COSTUMES-1)
			{
				server_print("[CSO Costumes] Costumes limit reached [%d]", MAX_COSTUMES-1)
				break
			}
		}

		if(file)
		{
			server_print("[CSO Costumes] %d Costumes loaded", TotalCostumes)
			fclose(file)
		}
	}
}

#if defined ZP_SUPPORT
public ze_user_infected(id)
{
	if(!g_vars[id][is_connected] || g_vars[id][is_bot_or_hltv])
	{
		return
	}

	if(g_settings[ZP43_Support])
	{
		cs_reset_player_model(id)

	}
	reset_costume(id, 0)
	//reset_costume(id, 1)
	//reset_costume(id, 2)
	//reset_costume(id, 3)
	
}

public ze_user_humanized(id)
{
	if(!g_vars[id][is_connected] || g_vars[id][is_bot_or_hltv])
	{
		return
	}

	if(id)
	{
		/*if(g_settings[ZP43_Support])
		{
			cs_reset_player_model(id)
		}*/

		//reset_costume(id, 1)
		//reset_costume(id, 2)
		//reset_costume(id, 3)
	}
	else
	{
		checkCostumes(id, 0)
		checkCostumes(id, 1)
		checkCostumes(id, 2)
		checkCostumes(id, 3)
	}
}

public ZP43_checkCostumes(id)
{
	checkCostumes(id, 0)
	checkCostumes(id, 1)
	checkCostumes(id, 2)
	checkCostumes(id, 3)
}
#endif

public Nvault_Init()
{
	g_Vault = nvault_open(g_settings[Vault])

	if(g_Vault == INVALID_HANDLE)
	{
		g_settings[Saving_Method] = 0
		server_print("[CSO Costumes] Failed to use nVault saving system! Continuing without saving system.")
		nvault_close(g_Vault)
	}
}

public Load_Nvault(id)
{
	new szCash[64]; formatex(szCash, charsmax(szCash), "%sCash", g_szAuthID[id])

	g_vars[id][g_cash] = nvault_get(g_Vault, szCash)

#if defined ZP_SUPPORT
	new szSkin[64]; formatex(szSkin, charsmax(szSkin), "%sSkin", g_szAuthID[id])

	g_vars[id][g_skin] = nvault_get(g_Vault, szSkin)

	if(g_vars[id][g_skin] >= Total_Skin)
	{
		g_vars[id][g_skin] = 0
	}

	for(new i = 1; i < Total_Skin; i++)
	{
		new szKey[64]; formatex(szKey, charsmax(szKey), "%sSkin%d", g_szAuthID[id], i)
		g_vars[id][g_acquiredSkin][i] = nvault_get(g_Vault, szKey)
	}
#else
	new szSkinCT[64]; formatex(szSkinCT, charsmax(szSkinCT), "%sSkinCT", g_szAuthID[id])
	new szSkinTR[64]; formatex(szSkinTR, charsmax(szSkinTR), "%sSkinTR", g_szAuthID[id])

	g_vars[id][g_skinct] = nvault_get(g_Vault, szSkinCT)
	g_vars[id][g_skintr] = nvault_get(g_Vault, szSkinTR)

	if(g_vars[id][g_skinct] >= Total_SkinCT)
	{
		g_vars[id][g_skinct] = 0
	}

	if(g_vars[id][g_skintr] >= Total_SkinTR)
	{
		g_vars[id][g_skintr] = 0
	}

	for(new i = 1; i < Total_SkinCT; i++)
	{
		new szKey[64]; formatex(szKey, charsmax(szKey), "%sSkinCT%d", g_szAuthID[id], i)
		g_vars[id][g_acquiredSkinCT][i] = nvault_get(g_Vault, szKey)
	}

	for(new i = 1; i < Total_SkinTR; i++)
	{
		new szKey[64]; formatex(szKey, charsmax(szKey), "%sSkinTR%d", g_szAuthID[id], i)
		g_vars[id][g_acquiredSkinTR][i] = nvault_get(g_Vault, szKey)
	}
#endif

	new szHead[64]; formatex(szHead, charsmax(szHead), "%sHead", g_szAuthID[id])
	new szBack[64]; formatex(szBack, charsmax(szBack), "%sBack", g_szAuthID[id])
	new szPelvis[64]; formatex(szPelvis, charsmax(szPelvis), "%sPelvis", g_szAuthID[id])

	g_vars[id][g_head] = nvault_get(g_Vault, szHead)
	g_vars[id][g_back] = nvault_get(g_Vault, szBack)
	g_vars[id][g_pelvis] = nvault_get(g_Vault, szPelvis)

	if(g_vars[id][g_head] >= Total_Head)
	{
		g_vars[id][g_head] = 0
	}

	if(g_vars[id][g_back] >= Total_Back)
	{
		g_vars[id][g_back] = 0
	}

	if(g_vars[id][g_pelvis] >= Total_Pelvis)
	{
		g_vars[id][g_pelvis] = 0
	}

	for(new i = 1; i < Total_Head; i++)
	{
		new szKey[64]; formatex(szKey, charsmax(szKey), "%sHead%d", g_szAuthID[id], i)
		g_vars[id][g_acquiredHead][i] = nvault_get(g_Vault, szKey)
	}

	for(new i = 1; i < Total_Back; i++)
	{
		new szKey[64]; formatex(szKey, charsmax(szKey), "%sBack%d", g_szAuthID[id], i)
		g_vars[id][g_acquiredBack][i] = nvault_get(g_Vault, szKey)
	}

	for(new i = 1; i < Total_Pelvis; i++)
	{
		new szKey[64]; formatex(szKey, charsmax(szKey), "%sPelvis%d", g_szAuthID[id], i)
		g_vars[id][g_acquiredPelvis][i] = nvault_get(g_Vault, szKey)
	}
}

public Save_Nvault(id)
{
	new szCash[64]; formatex(szCash, charsmax(szCash), "%sCash", g_szAuthID[id])
	new szCash1[11]; num_to_str(g_vars[id][g_cash], szCash1, charsmax(szCash1))

	nvault_pset(g_Vault, szCash, szCash1)

#if defined ZP_SUPPORT
	new szSkin[64]; formatex(szSkin, charsmax(szSkin), "%sSkin", g_szAuthID[id])
	new szSkin1[11]; num_to_str(g_vars[id][g_skin], szSkin1, charsmax(szSkin1))

	nvault_pset(g_Vault, szSkin, szSkin1)

	for(new i = 1; i < Total_Skin; i++)
	{
		new szKey[64]; formatex(szKey, charsmax(szKey), "%sSkin%d", g_szAuthID[id], i)
		new szKey2[2]; num_to_str(g_vars[id][g_acquiredSkin][i], szKey2, charsmax(szKey2))
		nvault_pset(g_Vault, szKey, szKey2)
	}
#else
	new szSkinCT[64]; formatex(szSkinCT, charsmax(szSkinCT), "%sSkinCT", g_szAuthID[id])
	new szSkinCT1[11]; num_to_str(g_vars[id][g_skinct], szSkinCT1, charsmax(szSkinCT1))

	new szSkinTR[64]; formatex(szSkinTR, charsmax(szSkinTR), "%sSkinTR", g_szAuthID[id])
	new szSkinTR1[11]; num_to_str(g_vars[id][g_skintr], szSkinTR1, charsmax(szSkinTR1))

	nvault_pset(g_Vault, szSkinCT, szSkinCT1)
	nvault_pset(g_Vault, szSkinTR, szSkinTR1)

	for(new i = 1; i < Total_SkinCT; i++)
	{
		new szKey[64]; formatex(szKey, charsmax(szKey), "%sSkinCT%d", g_szAuthID[id], i)
		new szKey2[2]; num_to_str(g_vars[id][g_acquiredSkinCT][i], szKey2, charsmax(szKey2))
		nvault_pset(g_Vault, szKey, szKey2)
	}

	for(new i = 1; i < Total_SkinTR; i++)
	{
		new szKey[64]; formatex(szKey, charsmax(szKey), "%sSkinTR%d", g_szAuthID[id], i)
		new szKey2[2]; num_to_str(g_vars[id][g_acquiredSkinTR][i], szKey2, charsmax(szKey2))
		nvault_pset(g_Vault, szKey, szKey2)
	}
#endif

	new szHead[64]; formatex(szHead, charsmax(szHead), "%sHead", g_szAuthID[id])
	new szHead1[11]; num_to_str(g_vars[id][g_head], szHead1, charsmax(szHead1))

	new szBack[64]; formatex(szBack, charsmax(szBack), "%sBack", g_szAuthID[id])
	new szBack1[11]; num_to_str(g_vars[id][g_back], szBack1, charsmax(szBack1))

	new szPelvis[64]; formatex(szPelvis, charsmax(szPelvis), "%sPelvis", g_szAuthID[id])
	new szPelvis1[11]; num_to_str(g_vars[id][g_pelvis], szPelvis1, charsmax(szPelvis1))

	nvault_pset(g_Vault, szHead, szHead1)
	nvault_pset(g_Vault, szBack, szBack1)
	nvault_pset(g_Vault, szPelvis, szPelvis1)

	for(new i = 1; i < Total_Head; i++)
	{
		new szKey[64]; formatex(szKey, charsmax(szKey), "%sHead%d", g_szAuthID[id], i)
		new szKey2[2]; num_to_str(g_vars[id][g_acquiredHead][i], szKey2, charsmax(szKey2))
		nvault_pset(g_Vault, szKey, szKey2)
	}

	for(new i = 1; i < Total_Back; i++)
	{
		new szKey[64]; formatex(szKey, charsmax(szKey), "%sBack%d", g_szAuthID[id], i)
		new szKey2[2]; num_to_str(g_vars[id][g_acquiredBack][i], szKey2, charsmax(szKey2))
		nvault_pset(g_Vault, szKey, szKey2)
	}

	for(new i = 1; i < Total_Pelvis; i++)
	{
		new szKey[64]; formatex(szKey, charsmax(szKey), "%sPelvis%d", g_szAuthID[id], i)
		new szKey2[2]; num_to_str(g_vars[id][g_acquiredPelvis][i], szKey2, charsmax(szKey2))
		nvault_pset(g_Vault, szKey, szKey2)
	}
}

public MySql_Init()
{
	g_SqlTuple = SQL_MakeDbTuple(g_settings[Host], g_settings[User], g_settings[Pass], g_settings[Db])

	new ErrorCode,Handle:SqlConnection = SQL_Connect(g_SqlTuple,ErrorCode, g_Error, charsmax(g_Error))
	if(SqlConnection == Empty_Handle)
	{
		log_amx(g_Error)
		g_settings[Saving_Method] = 1
		server_print("[CSO Costumes] Failed to use MySQL saving system! Continuing with nVault saving system.")
		SQL_FreeHandle(g_SqlTuple)
		Load_Configuration(1)
		return
	}

	static len; len = 0
	static szTemp[8192]

#if defined ZP_SUPPORT
	len += formatex(szTemp[len], charsmax(szTemp), "CREATE TABLE IF NOT EXISTS `%s` (\
	`Id` INT(11) AUTO_INCREMENT PRIMARY KEY, `SteamID` varchar(35), `Cash` INT(11),\
	`Skin` INT(11), `Head` INT(11), `Back` INT(11), `Pelvis` INT(11)", g_settings[Table])

	for(new i = 1; i < Total_Skin; i++)
	{
		len += formatex(szTemp[len], charsmax(szTemp), ",`Skin%d` INT(1)", i)
	}
#else
	len += formatex(szTemp[len], charsmax(szTemp), "CREATE TABLE IF NOT EXISTS `%s` (\
	`Id` INT(11) AUTO_INCREMENT PRIMARY KEY, `SteamID` varchar(35), `Cash` INT(11),\
	`SkinCT` INT(11), `SkinTR` INT(11), `Head` INT(11), `Back` INT(11), `Pelvis` INT(11)", g_settings[Table])

	for(new i = 1; i < Total_SkinCT; i++)
	{
		len += formatex(szTemp[len], charsmax(szTemp), ",`SkinCT%d` INT(1)", i)
	}

	for(new i = 1; i < Total_SkinTR; i++)
	{
		len += formatex(szTemp[len], charsmax(szTemp), ",`SkinTR%d` INT(1)", i)
	}
#endif

	for(new i = 1; i < Total_Head; i++)
	{
		len += formatex(szTemp[len], charsmax(szTemp), ",`Head%d` INT(1)", i)
	}

	for(new i = 1; i < Total_Back; i++)
	{
		len += formatex(szTemp[len], charsmax(szTemp), ",`Back%d` INT(1)", i)
	}

	for(new i = 1; i < Total_Pelvis; i++)
	{
		len += formatex(szTemp[len], charsmax(szTemp), ",`Pelvis%d` INT(1)", i)
	}

	len += formatex(szTemp[len], charsmax(szTemp), ")")

	new Handle:Queries
	Queries = SQL_PrepareQuery(SqlConnection, szTemp)

	if(!SQL_Execute(Queries))
	{
		SQL_QueryError(Queries, g_Error, charsmax(g_Error))
		log_amx(g_Error)
		g_settings[Saving_Method] = 1
		server_print("[CSO Costumes] Failed to use MySQL saving system! Continuing with nVault saving system.")
		SQL_FreeHandle(g_SqlTuple)
		Load_Configuration(1)
		return
	}

	SQL_FreeHandle(Queries)
	SQL_FreeHandle(SqlConnection)

	MySql_Init2()
}

public MySql_Init2()
{
	new szTemp[128], Data[1]; Data[0] = 1

	formatex(szTemp, charsmax(szTemp), "SELECT * FROM `%s`", g_settings[Table])
	SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", szTemp, Data, sizeof(Data))
}

public Load_MySql(id)
{
	new szTemp[256], Data[1]; Data[0] = id

	formatex(szTemp, charsmax(szTemp), "SELECT * FROM `%s` WHERE (`%s`.`SteamID` = '%s')", g_settings[Table], g_settings[Table], g_szAuthID[id])
	SQL_ThreadQuery(g_SqlTuple, "register_client", szTemp, Data, sizeof(Data))
}

public register_client(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
	switch(FailState)
	{
		case TQUERY_CONNECT_FAILED: log_amx("Load - Could not connect to SQL database. [%d] %s", Errcode, Error)
		case TQUERY_QUERY_FAILED: log_amx("Load - Query failed. [%d] %s", Errcode, Error)
	}

	new id; id = Data[0]

	if(SQL_NumResults(Query) < 1)
	{
		if(equal(g_szAuthID[id], "ID_PENDING"))
		{
			return
		}

		static len; len = 0
		new szTemp[128], Data[1]; Data[0] = 0

		len += formatex(szTemp[len], charsmax(szTemp), "INSERT INTO `%s` (`SteamID`) VALUES ('%s')", g_settings[Table], g_szAuthID[id])

		SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", szTemp, Data, sizeof(Data))

		Save_MySql(id)
	}
	else
	{
		new query; query = 2

		g_vars[id][g_cash] = SQL_ReadResult(Query, query); query++

	#if defined ZP_SUPPORT
		g_vars[id][g_skin] = SQL_ReadResult(Query, query); query++

		if(g_vars[id][g_skin] >= Total_Skin)
		{
			g_vars[id][g_skin] = 0
		}

		for(new i = 1; i < Total_Skin; i++)
		{
			new szname[20]; formatex(szname, charsmax(szname), "Skin%d", i)
			new num = SQL_FieldNameToNum(Query, szname)

			g_vars[id][g_acquiredSkin][i] = SQL_ReadResult(Query, num)
		}
	#else
		g_vars[id][g_skinct] = SQL_ReadResult(Query, query); query++
		g_vars[id][g_skintr] = SQL_ReadResult(Query, query); query++

		if(g_vars[id][g_skinct] >= Total_SkinCT)
		{
			g_vars[id][g_skinct] = 0
		}

		if(g_vars[id][g_skintr] >= Total_SkinTR)
		{
			g_vars[id][g_skintr] = 0
		}

		for(new i = 1; i < Total_SkinCT; i++)
		{
			new szname[20]; formatex(szname, charsmax(szname), "SkinCT%d", i)
			new num = SQL_FieldNameToNum(Query, szname)

			g_vars[id][g_acquiredSkinCT][i] = SQL_ReadResult(Query, num)
		}

		for(new i = 1; i < Total_SkinTR; i++)
		{
			new szname[20]; formatex(szname, charsmax(szname), "SkinTR%d", i)
			new num = SQL_FieldNameToNum(Query, szname)

			g_vars[id][g_acquiredSkinTR][i] = SQL_ReadResult(Query, num)
		}
	#endif

		g_vars[id][g_head] = SQL_ReadResult(Query, query); query++
		g_vars[id][g_back] = SQL_ReadResult(Query, query); query++
		g_vars[id][g_pelvis] = SQL_ReadResult(Query, query); query++

		if(g_vars[id][g_head] >= Total_Head)
		{
			g_vars[id][g_head] = 0
		}

		if(g_vars[id][g_back] >= Total_Back)
		{
			g_vars[id][g_back] = 0
		}

		if(g_vars[id][g_pelvis] >= Total_Pelvis)
		{
			g_vars[id][g_pelvis] = 0
		}

		for(new i = 1; i < Total_Head; i++)
		{
			new szname[20]; formatex(szname, charsmax(szname), "Head%d", i)
			new num = SQL_FieldNameToNum(Query, szname)

			g_vars[id][g_acquiredHead][i] = SQL_ReadResult(Query, num)
		}

		for(new i = 1; i < Total_Back; i++)
		{
			new szname[20]; formatex(szname, charsmax(szname), "Back%d", i)
			new num = SQL_FieldNameToNum(Query, szname)

			g_vars[id][g_acquiredBack][i] = SQL_ReadResult(Query, num)
		}

		for(new i = 1; i < Total_Pelvis; i++)
		{
			new szname[20]; formatex(szname, charsmax(szname), "Pelvis%d", i)
			new num = SQL_FieldNameToNum(Query, szname)

			g_vars[id][g_acquiredPelvis][i] = SQL_ReadResult(Query, num)
		}
	}
}

public Save_MySql(id)
{
	static szTemp[8192]
	new Data[1]; Data[0] = 0
	static len; len = 0

#if defined ZP_SUPPORT
	len += formatex(szTemp[len], charsmax(szTemp), "UPDATE `%s` SET `Cash` = '%i', `Skin` = '%i', `Head` = '%i',\
	`Back` = '%i', `Pelvis` = '%i'", g_settings[Table], g_vars[id][g_cash], g_vars[id][g_skin], g_vars[id][g_head], g_vars[id][g_back], g_vars[id][g_pelvis])

	for(new i = 1; i < Total_Skin; i++)
	{
		len += formatex(szTemp[len], charsmax(szTemp), ",`Skin%d` = '%i'", i, g_vars[id][g_acquiredSkin][i])
	}
#else
	len += formatex(szTemp[len], charsmax(szTemp), "UPDATE `%s` SET `Cash` = '%i', `SkinCT` = '%i', `SkinTR` = '%i', `Head` = '%i', `Back` = '%i',\
	`Pelvis` = '%i'", g_settings[Table], g_vars[id][g_cash], g_vars[id][g_skinct], g_vars[id][g_skintr], g_vars[id][g_head], g_vars[id][g_back], g_vars[id][g_pelvis])

	for(new i = 1; i < Total_SkinCT; i++)
	{
		len += formatex(szTemp[len], charsmax(szTemp), ",`SkinCT%d` = '%i'", i, g_vars[id][g_acquiredSkinCT][i])
	}

	for(new i = 1; i < Total_SkinTR; i++)
	{
		len += formatex(szTemp[len], charsmax(szTemp), ",`SkinTR%d` = '%i'", i, g_vars[id][g_acquiredSkinTR][i])
	}
#endif

	for(new i = 1; i < Total_Head; i++)
	{
		len += formatex(szTemp[len], charsmax(szTemp), ",`Head%d` = '%i'", i, g_vars[id][g_acquiredHead][i])
	}

	for(new i = 1; i < Total_Back; i++)
	{
		len += formatex(szTemp[len], charsmax(szTemp), ",`Back%d` = '%i'", i, g_vars[id][g_acquiredBack][i])
	}

	for(new i = 1; i < Total_Pelvis; i++)
	{
		len += formatex(szTemp[len], charsmax(szTemp), ",`Pelvis%d` = '%i'", i, g_vars[id][g_acquiredPelvis][i])
	}

	formatex(szTemp[len], charsmax(szTemp), " WHERE `%s`.`SteamID` = '%s';", g_settings[Table], g_szAuthID[id])

	SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", szTemp, Data, sizeof(Data))
}

public IgnoreHandle(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
	new VerifyCostumes; VerifyCostumes = Data[0]

	if(VerifyCostumes)
	{
		new Data1[1]; Data1[0] = 0

	#if defined ZP_SUPPORT
		for(new i = 1; i < Total_Skin; i++)
		{
			new szname[20]; formatex(szname, charsmax(szname), "Skin%d", i)
			new num = SQL_FieldNameToNum(Query, szname)

			if(num == -1)
			{
				new szTemp[128]; formatex(szTemp, charsmax(szTemp), "ALTER TABLE `%s` ADD COLUMN `%s` INT(1) NOT NULL", g_settings[Table], szname)
				SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", szTemp, Data1, sizeof(Data1))
			}
		}
	#else
		for(new i = 1; i < Total_SkinCT; i++)
		{
			new szname[20]; formatex(szname, charsmax(szname), "SkinCT%d", i)
			new num = SQL_FieldNameToNum(Query, szname)

			if(num == -1)
			{
				new szTemp[128]; formatex(szTemp, charsmax(szTemp), "ALTER TABLE `%s` ADD COLUMN `%s` INT(1) NOT NULL", g_settings[Table], szname)
				SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", szTemp, Data1, sizeof(Data1))
			}
		}

		for(new i = 1; i < Total_SkinTR; i++)
		{
			new szname[20]; formatex(szname, charsmax(szname), "SkinTR%d", i)
			new num = SQL_FieldNameToNum(Query, szname)

			if(num == -1)
			{
				new szTemp[128]; formatex(szTemp, charsmax(szTemp), "ALTER TABLE `%s` ADD COLUMN `%s` INT(1) NOT NULL", g_settings[Table], szname)
				SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", szTemp, Data1, sizeof(Data1))
			}
		}
	#endif

		for(new i = 1; i < Total_Head; i++)
		{
			new szname[20]; formatex(szname, charsmax(szname), "Head%d", i)
			new num = SQL_FieldNameToNum(Query, szname)

			if(num == -1)
			{
				new szTemp[128]; formatex(szTemp, charsmax(szTemp), "ALTER TABLE `%s` ADD COLUMN `%s` INT(1) NOT NULL", g_settings[Table], szname)
				SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", szTemp, Data1, sizeof(Data1))
			}
		}

		for(new i = 1; i < Total_Back; i++)
		{
			new szname[20]; formatex(szname, charsmax(szname), "Back%d", i)
			new num = SQL_FieldNameToNum(Query, szname)

			if(num == -1)
			{
				new szTemp[128]; formatex(szTemp, charsmax(szTemp), "ALTER TABLE `%s` ADD COLUMN `%s` INT(1) NOT NULL", g_settings[Table], szname)
				SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", szTemp, Data1, sizeof(Data1))
			}
		}

		for(new i = 1; i < Total_Pelvis; i++)
		{
			new szname[20]; formatex(szname, charsmax(szname), "Pelvis%d", i)
			new num = SQL_FieldNameToNum(Query, szname)

			if(num == -1)
			{
				new szTemp[128]; formatex(szTemp, charsmax(szTemp), "ALTER TABLE `%s` ADD COLUMN `%s` INT(1) NOT NULL", g_settings[Table], szname)
				SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", szTemp, Data1, sizeof(Data1))
			}
		}
	}

	SQL_FreeHandle(Query)
}

public Save_Data()
{
	if(g_settings[Saving_Method] != 0)
	{
		new players[32], num, player
		get_players(players, num, "ch")

		for(new i = 0; i < num; i++)
		{
			player = players[i]

			switch(g_settings[Saving_Method])
			{
				case 1: Save_Nvault(player)
				case 2: Save_MySql(player)
			}
		}
	}
}

public client_disconnected(id)
{
	g_vars[id][is_connected] = false

	if(g_vars[id][is_bot_or_hltv])
	{
		g_vars[id][is_bot_or_hltv] = false
		return
	}

	switch(g_settings[Saving_Method])
	{
		case 1: Save_Nvault(id)
		case 2: Save_MySql(id)
	}
}

public client_authorized(id)
{
	if(is_user_bot(id) || is_user_hltv(id))
	{
		g_vars[id][is_bot_or_hltv] = true
		return
	}

	reset_vars(id)

	if(g_settings[Saving_Method] != 0)
	{
		get_user_authid(id, g_szAuthID[id], charsmax(g_szAuthID[]))

		switch(g_settings[Saving_Method])
		{
			case 1: Load_Nvault(id)
			case 2: Load_MySql(id)
		}
	}
}

public client_putinserver(id)
{
	g_vars[id][is_connected] = true
}

public fw_PlayerSpawn_Post(id)
{
	if(is_user_alive(id) && !g_vars[id][is_bot_or_hltv])
	{
		if(g_settings[ZP43_Support])
		{
			set_task(0.1, "ZP43_checkCostumes", id)
		}
		else
		{
			checkCostumes(id, 0)
			checkCostumes(id, 1)
			checkCostumes(id, 2)
			checkCostumes(id, 3)
		}
	}
}

public Event_DeathMsg()
{
	new attacker = read_data(1)
	new victim = read_data(2)

	if(attacker == victim || attacker == 0 || !g_vars[attacker][is_connected] || !g_vars[victim][is_connected] || g_vars[attacker][is_bot_or_hltv])
	{
		return
	}

	new victimname[32]
	get_user_name(victim, victimname, charsmax(victimname))

	//ColorChat(attacker, "%L", attacker, "KILL_PLAYER", g_settings[Cash_per_Kill], victimname)
	g_vars[attacker][g_cash] += g_settings[Cash_per_Kill]
}

public clcmd_costumes(id)
{
	show_menu_costumes(id)

	return PLUGIN_HANDLED
}

public clcmd_inventory(id)
{
	show_menu_inventory(id)

	return PLUGIN_HANDLED
}

public clcmd_shop(id)
{
	show_menu_shop(id)

	return PLUGIN_HANDLED
}

public clcmd_deactivate(id)
{
#if defined ZP_SUPPORT
	g_vars[id][g_skin] = 0
#else
	g_vars[id][g_skinct] = 0
	g_vars[id][g_skintr] = 0
#endif

	g_vars[id][g_head] = 0
	g_vars[id][g_back] = 0
	g_vars[id][g_pelvis] = 0

	checkCostumes(id, 0)
	reset_costume(id, 1)
	reset_costume(id, 2)
	reset_costume(id, 3)

	ColorChat(id, "%L", id, "DEACTIVATED_COSTUMES")

	return PLUGIN_HANDLED
}

public clcmd_cash(id)
{
	ColorChat(id, "%L", id, "CASH", g_vars[id][g_cash])

	return PLUGIN_HANDLED
}

public Cmd_GiveCash(id, iLevel, iCid)
{
	if(!cmd_access(id, iLevel, iCid, 3))
	{
		return PLUGIN_HANDLED
	}

	new szPlayer[32]
	read_argv(1, szPlayer, charsmax(szPlayer))

	new iPlayer = cmd_target(id, szPlayer, 0)

	if(!iPlayer || g_vars[iPlayer][is_bot_or_hltv])
	{
		return PLUGIN_HANDLED
	}

	new szName[2][32], szAmount[10]
	read_argv(2, szAmount, charsmax(szAmount))
	get_user_name(id, szName[0], charsmax(szName[]))
	get_user_name(iPlayer, szName[1], charsmax(szName[]))

	new szKey[32], iCash = str_to_num(szAmount)
	g_vars[iPlayer][g_cash] += iCash

	if(g_vars[iPlayer][g_cash] < 0)
	{
		g_vars[iPlayer][g_cash] = 0
	}

	if(iCash >= 0)
	{
		copy(szKey, charsmax(szKey), "GIVE_CASH")
	}
	else
	{
		copy(szKey, charsmax(szKey), "TAKE_CASH")
		iCash *= -1
	}

	ColorChat(0, "%L", id, szKey, szName[0], iCash, szName[1])
	return PLUGIN_HANDLED
}

public menu_costumes(id, menu, item)
{
	switch(item)
	{
		case 0: show_menu_inventory(id)
		case 1: show_menu_shop(id)
	}

	menu_destroy(menu)
	return PLUGIN_HANDLED
}

show_menu_costumes(id)
{
	new msgm[128], msg1[32], msg2[32], msgexit[32]
	formatex(msgm, charsmax(msgm), "%s \y%L", PREFIX_MENU, id, "COSTUMES")
	formatex(msg1, charsmax(msg1), "%L", id, "INVENTORY")
	formatex(msg2, charsmax(msg2), "%L", id, "SHOP")
	formatex(msgexit, charsmax(msgexit), "%L", id, "MENU_EXIT")

	new menu = menu_create(msgm, "menu_costumes")

	menu_additem(menu, msg1, "0", 0)
	menu_additem(menu, msg2, "1", 0)

	menu_setprop(menu, MPROP_EXITNAME, msgexit)

	menu_display(id, menu, 0)
}

public menu_inventory(id, menu, item)
{
	switch(item)
	{
		case 0..z:
		{
		#if defined ZP_SUPPORT
			if(Total_Skin == 1 && item == 0 || Total_Head == 1 && item == 1 || Total_Back == 1 && item == 2 || Total_Pelvis == 1 && item == 3)
			{
				ColorChat(id, "%L", id, "NOT_AVAILABLE", id, item > -1 ? item > 0 ? item > 1 ? item > 2 ? "COSTUME_PELVIS" : "COSTUME_BACK" : "COSTUME_HEAD" : "COSTUME_SKIN" : "")
				show_menu_inventory(id)
			}
		#else
			if(Total_SkinCT == 1 && item == 0 || Total_SkinTR == 1 && item == 1 || Total_Head == 1 && item == 2 || Total_Back == 1 && item == 3 || Total_Pelvis == 1 && item == 4)
			{
				ColorChat(id, "%L", id, "NOT_AVAILABLE", id, item > -1 ? item > 0 ? item > 1 ? item > 2 ? item > 3 ? "COSTUME_PELVIS" : "COSTUME_BACK" : "COSTUME_HEAD" : "COSTUME_SKINTR" : "COSTUME_SKINCT" : "")
				show_menu_inventory(id)
			}
		#endif
			else
			{
				g_vars[id][g_costume] = item
				show_menu_costumeinv(id)
			}
		}
		case z+1:
		{
			clcmd_deactivate(id)
			show_menu_inventory(id)
		}
		case MENU_EXIT:
		{
			if(g_vars[id][is_connected])
			{
				show_menu_costumes(id)
			}
		}
	}

	menu_destroy(menu)
	return PLUGIN_HANDLED
}

show_menu_inventory(id)
{
	new msgm[128], msghead[32], msgback[32], msgpelvis[32], msg1[64], msgexit[32]
	formatex(msgm, charsmax(msgm), "%s \y%L", PREFIX_MENU, id, "INVENTORY")
	formatex(msghead, charsmax(msghead), "%L", id, "COSTUME_HEAD")
	formatex(msgback, charsmax(msgback), "%L", id, "COSTUME_BACK")
	formatex(msgpelvis, charsmax(msgpelvis), "%L", id, "COSTUME_PELVIS")
	formatex(msg1, charsmax(msg1), "%L", id, "DEACTIVATE_ALLCOSTUMES")
	formatex(msgexit, charsmax(msgexit), "%L", id, "MENU_EXIT")

	new menu = menu_create(msgm, "menu_inventory")

#if defined ZP_SUPPORT
	new msgskin[32]; formatex(msgskin, charsmax(msgskin), "%L", id, "COSTUME_SKIN")

	menu_additem(menu, msgskin, "0", 0)
	menu_additem(menu, msghead, "1", 0)
	menu_additem(menu, msgback, "2", 0)
	menu_additem(menu, msgpelvis, "3", 0)
	menu_additem(menu, msg1, "4", 0)
#else
	new msgskinct[32], msgskintr[32]
	formatex(msgskinct, charsmax(msgskinct), "%L", id, "COSTUME_SKINCT")
	formatex(msgskintr, charsmax(msgskintr), "%L", id, "COSTUME_SKINTR")

	menu_additem(menu, msgskinct, "0", 0)
	menu_additem(menu, msgskintr, "1", 0)
	menu_additem(menu, msghead, "2", 0)
	menu_additem(menu, msgback, "3", 0)
	menu_additem(menu, msgpelvis, "4", 0)
	menu_additem(menu, msg1, "5", 0)
#endif

	menu_setprop(menu, MPROP_EXITNAME, msgexit)

	menu_display(id, menu, 0)
}

public menu_costumeinv(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		if(g_vars[id][is_connected])
		{
			show_menu_inventory(id)
		}

		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	if(item == 0)
	{
	#if defined ZP_SUPPORT
		if(!g_vars[id][g_skin] && g_vars[id][g_costume] == 0 || !g_vars[id][g_head] && g_vars[id][g_costume] == 1 || !g_vars[id][g_back] && g_vars[id][g_costume] == 2 || !g_vars[id][g_pelvis] && g_vars[id][g_costume] == 3)
		{
			ColorChat(id, "%L", id, "ALREADY_DEACTIVATED")
		}
	#else
		if(!g_vars[id][g_skinct] && g_vars[id][g_costume] == 0 || !g_vars[id][g_skintr] && g_vars[id][g_costume] == 1 || !g_vars[id][g_head] && g_vars[id][g_costume] == 2 || !g_vars[id][g_back] && g_vars[id][g_costume] == 3 || !g_vars[id][g_pelvis] && g_vars[id][g_costume] == 4)
		{
			ColorChat(id, "%L", id, "ALREADY_DEACTIVATED")
		}
	#endif
		else
		{
			switch(g_vars[id][g_costume])
			{
			#if defined ZP_SUPPORT
				case 0:
				{
					g_vars[id][g_skin] = 0
					checkCostumes(id, 0)
				}
			#else
				case 0:
				{
					g_vars[id][g_skinct] = 0
					checkCostumes(id, 0)
				}
				case 1:
				{
					g_vars[id][g_skintr] = 0
					checkCostumes(id, 0)
				}
			#endif
				case y:
				{
					g_vars[id][g_head] = 0
					reset_costume(id, 1)
				}
				case y+1:
				{
					g_vars[id][g_back] = 0
					reset_costume(id, 2)
				}
				case y+2:
				{
					g_vars[id][g_pelvis] = 0
					reset_costume(id, 3)
				}
			}

			#if defined ZP_SUPPORT
				ColorChat(id, "%L", id, "DEACTIVATE_COSTUME", id, g_vars[id][g_costume] > -1 ? g_vars[id][g_costume] > 0 ? g_vars[id][g_costume] > 1 ? g_vars[id][g_costume] > 2 ? "COSTUME_PELVIS" : "COSTUME_BACK" : "COSTUME_HEAD" : "COSTUME_SKIN" : "")
			#else
				ColorChat(id, "%L", id, "DEACTIVATE_COSTUME", id, g_vars[id][g_costume] > -1 ? g_vars[id][g_costume] > 0 ? g_vars[id][g_costume] > 1 ? g_vars[id][g_costume] > 2 ? g_vars[id][g_costume] > 3 ? "COSTUME_PELVIS" : "COSTUME_BACK" : "COSTUME_HEAD" : "COSTUME_SKINTR" : "COSTUME_SKINCT" : "")
			#endif
		}
	}
	else
	{
		new keyc = 1

		switch(g_vars[id][g_costume])
		{
		#if defined ZP_SUPPORT
			case 0:
			{
				for(new i = 1; i < Total_Skin; i++)
				{
					if(!g_vars[id][g_acquiredSkin][i])
					{
						continue
					}

					if(keyc == item)
					{
						if(g_vars[id][g_skin] == i)
						{
							ColorChat(id, "%L", id, "ALREADY_ACTIVATED")
						}
						else
						{
							g_vars[id][g_skin] = i
							checkCostumes(id, 0)
							ColorChat(id, "%L", id, "ACTIVATE_COSTUME", Costumes_Skin[i][g_name])
						}

						break
					}

					keyc++
				}
			}
		#else
			case 0:
			{
				for(new i = 1; i < Total_SkinCT; i++)
				{
					if(!g_vars[id][g_acquiredSkinCT][i])
					{
						continue
					}

					if(keyc == item)
					{
						if(g_vars[id][g_skinct] == i)
						{
							ColorChat(id, "%L", id, "ALREADY_ACTIVATED")
						}
						else
						{
							g_vars[id][g_skinct] = i
							checkCostumes(id, 0)
							ColorChat(id, "%L", id, "ACTIVATE_COSTUME", Costumes_SkinCT[i][g_name])
						}

						break
					}

					keyc++
				}
			}
			case 1:
			{
				for(new i = 1; i < Total_SkinTR; i++)
				{
					if(!g_vars[id][g_acquiredSkinTR][i])
					{
						continue
					}

					if(keyc == item)
					{
						if(g_vars[id][g_skintr] == i)
						{
							ColorChat(id, "%L", id, "ALREADY_ACTIVATED")
						}
						else
						{
							g_vars[id][g_skintr] = i
							checkCostumes(id, 0)
							ColorChat(id, "%L", id, "ACTIVATE_COSTUME", Costumes_SkinTR[i][g_name])
						}

						break
					}

					keyc++
				}
			}
		#endif
			case y:
			{
				for(new i = 1; i < Total_Head; i++)
				{
					if(!g_vars[id][g_acquiredHead][i])
					{
						continue
					}

					if(keyc == item)
					{
						if(g_vars[id][g_head] == i)
						{
							ColorChat(id, "%L", id, "ALREADY_ACTIVATED")
						}
						else
						{
							g_vars[id][g_head] = i
							checkCostumes(id, 1)
							ColorChat(id, "%L", id, "ACTIVATE_COSTUME", Costumes_Head[i][g_name])
						}

						break
					}

					keyc++
				}
			}
			case y+1:
			{
				for(new i = 1; i < Total_Back; i++)
				{
					if(!g_vars[id][g_acquiredBack][i])
					{
						continue
					}

					if(keyc == item)
					{
						if(g_vars[id][g_back] == i)
						{
							ColorChat(id, "%L", id, "ALREADY_ACTIVATED")
						}
						else
						{
							g_vars[id][g_back] = i
							checkCostumes(id, 2)
							ColorChat(id, "%L", id, "ACTIVATE_COSTUME", Costumes_Back[i][g_name])
						}

						break
					}

					keyc++
				}
			}
			case y+2:
			{
				for(new i = 1; i < Total_Pelvis; i++)
				{
					if(!g_vars[id][g_acquiredPelvis][i])
					{
						continue
					}

					if(keyc == item)
					{
						if(g_vars[id][g_pelvis] == i)
						{
							ColorChat(id, "%L", id, "ALREADY_ACTIVATED")
						}
						else
						{
							g_vars[id][g_pelvis] = i
							checkCostumes(id, 3)
							ColorChat(id, "%L", id, "ACTIVATE_COSTUME", Costumes_Pelvis[i][g_name])
						}

						break
					}

					keyc++
				}
			}
		}
	}

	show_menu_costumeinv(id)
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

show_menu_costumeinv(id)
{
	new msgm[128], msg[128], msg1[16], msgactivated[32], msgback[32], msgnext[32], msgexit[32], item = 1
#if defined ZP_SUPPORT
	formatex(msgm, charsmax(msgm), "%s \y%L: %L^n\r", PREFIX_MENU, id, "INVENTORY", id, g_vars[id][g_costume] > -1 ? g_vars[id][g_costume] > 0 ? g_vars[id][g_costume] > 1 ? g_vars[id][g_costume] > 2 ? "COSTUME_PELVIS" : "COSTUME_BACK" : "COSTUME_HEAD" : "COSTUME_SKIN" : "")
#else
	formatex(msgm, charsmax(msgm), "%s \y%L: %L^n\r", PREFIX_MENU, id, "INVENTORY", id, g_vars[id][g_costume] > -1 ? g_vars[id][g_costume] > 0 ? g_vars[id][g_costume] > 1 ? g_vars[id][g_costume] > 2 ? g_vars[id][g_costume] > 3 ? "COSTUME_PELVIS" : "COSTUME_BACK" : "COSTUME_HEAD" : "COSTUME_SKINTR" : "COSTUME_SKINCT" : "")
#endif
	formatex(msgactivated, charsmax(msgactivated), " \r[%L]", id, "ACTIVATED")
	formatex(msgback, charsmax(msgback), "%L", id, "MENU_BACK")
	formatex(msgnext, charsmax(msgnext), "%L", id, "MENU_NEXT")
	formatex(msgexit, charsmax(msgexit), "%L", id, "MENU_EXIT")

	new menu = menu_create(msgm, "menu_costumeinv")

	formatex(msg, charsmax(msg), "%L", id, "COSTUME_NONE")
	menu_additem(menu, msg, "0", 0)

	switch(g_vars[id][g_costume])
	{
	#if defined ZP_SUPPORT
		case 0:
		{
			for(new i = 1; i < Total_Skin; i++)
			{
				if(!g_vars[id][g_acquiredSkin][i])
				{
					continue
				}

				formatex(msg, charsmax(msg), "%s%s", Costumes_Skin[i][g_name], g_vars[id][g_skin] == i ? msgactivated : "")
				num_to_str(item, msg1, charsmax(msg1))
				menu_additem(menu, msg, msg1, 0)

				item++
			}
		}
	#else
		case 0:
		{
			for(new i = 1; i < Total_SkinCT; i++)
			{
				if(!g_vars[id][g_acquiredSkinCT][i])
				{
					continue
				}

				formatex(msg, charsmax(msg), "%s%s", Costumes_SkinCT[i][g_name], g_vars[id][g_skinct] == i ? msgactivated : "")
				num_to_str(item, msg1, charsmax(msg1))
				menu_additem(menu, msg, msg1, 0)

				item++
			}
		}
		case 1:
		{
			for(new i = 1; i < Total_SkinTR; i++)
			{
				if(!g_vars[id][g_acquiredSkinTR][i])
				{
					continue
				}

				formatex(msg, charsmax(msg), "%s%s", Costumes_SkinTR[i][g_name], g_vars[id][g_skintr] == i ? msgactivated : "")
				num_to_str(item, msg1, charsmax(msg1))
				menu_additem(menu, msg, msg1, 0)

				item++
			}
		}
	#endif
		case y:
		{
			for(new i = 1; i < Total_Head; i++)
			{
				if(!g_vars[id][g_acquiredHead][i])
				{
					continue
				}

				formatex(msg, charsmax(msg), "%s%s", Costumes_Head[i][g_name], g_vars[id][g_head] == i ? msgactivated : "")
				num_to_str(item, msg1, charsmax(msg1))
				menu_additem(menu, msg, msg1, 0)

				item++
			}
		}
		case y+1:
		{
			for(new i = 1; i < Total_Back; i++)
			{
				if(!g_vars[id][g_acquiredBack][i])
				{
					continue
				}

				formatex(msg, charsmax(msg), "%s%s", Costumes_Back[i][g_name], g_vars[id][g_back] == i ? msgactivated : "")
				num_to_str(item, msg1, charsmax(msg1))
				menu_additem(menu, msg, msg1, 0)

				item++
			}
		}
		case y+2:
		{
			for(new i = 1; i < Total_Pelvis; i++)
			{
				if(!g_vars[id][g_acquiredPelvis][i])
				{
					continue
				}

				formatex(msg, charsmax(msg), "%s%s", Costumes_Pelvis[i][g_name], g_vars[id][g_pelvis] == i ? msgactivated : "")
				num_to_str(item, msg1, charsmax(msg1))
				menu_additem(menu, msg, msg1, 0)

				item++
			}
		}
	}

	if(item == 1)
	{
	#if defined ZP_SUPPORT
		ColorChat(id, "%L", id, "NO_COSTUME", id, g_vars[id][g_costume] > -1 ? g_vars[id][g_costume] > 0 ? g_vars[id][g_costume] > 1 ? g_vars[id][g_costume] > 2 ? "COSTUME_PELVIS" : "COSTUME_BACK" : "COSTUME_HEAD" : "COSTUME_SKIN" : "")
	#else
		ColorChat(id, "%L", id, "NO_COSTUME", id, g_vars[id][g_costume] > -1 ? g_vars[id][g_costume] > 0 ? g_vars[id][g_costume] > 1 ? g_vars[id][g_costume] > 2 ? g_vars[id][g_costume] > 3 ? "COSTUME_PELVIS" : "COSTUME_BACK" : "COSTUME_HEAD" : "COSTUME_SKINTR" : "COSTUME_SKINCT" : "")
	#endif
		show_menu_inventory(id)
		menu_destroy(menu)
		return
	}

	menu_setprop(menu, MPROP_BACKNAME, msgback)
	menu_setprop(menu, MPROP_NEXTNAME, msgnext)
	menu_setprop(menu, MPROP_EXITNAME, msgexit)

	menu_display(id, menu, 0)
}

public menu_shop(id, menu, item)
{
	switch(item)
	{
		case 0..z:
		{
		#if defined ZP_SUPPORT
			if(Total_Skin == 1 && item == 0 || Total_Head == 1 && item == 1 || Total_Back == 1 && item == 2 || Total_Pelvis == 1 && item == 3)
			{
				ColorChat(id, "%L", id, "NOT_AVAILABLE", id, item > -1 ? item > 0 ? item > 1 ? item > 2 ? "COSTUME_PELVIS" : "COSTUME_BACK" : "COSTUME_HEAD" : "COSTUME_SKIN" : "")
				show_menu_shop(id)
			}
		#else
			if(Total_SkinCT == 1 && item == 0 || Total_SkinTR == 1 && item == 1 || Total_Head == 1 && item == 2 || Total_Back == 1 && item == 3 || Total_Pelvis == 1 && item == 4)
			{
				ColorChat(id, "%L", id, "NOT_AVAILABLE", id, item > -1 ? item > 0 ? item > 1 ? item > 2 ? item > 3 ? "COSTUME_PELVIS" : "COSTUME_BACK" : "COSTUME_HEAD" : "COSTUME_SKINTR" : "COSTUME_SKINCT" : "")
				show_menu_shop(id)
			}
		#endif
			else
			{
				g_vars[id][g_costume] = item
				show_menu_costumeshop(id)
			}
		}
		case MENU_EXIT:
		{
			if(g_vars[id][is_connected])
			{
				show_menu_costumes(id)
			}
		}
	}

	menu_destroy(menu)
	return PLUGIN_HANDLED
}

show_menu_shop(id)
{
	new msgm[128], msghead[32], msgback[32], msgpelvis[32], msgexit[32]
	formatex(msgm, charsmax(msgm), "%s \y%L^n\w%L: \r%d", PREFIX_MENU, id, "SHOP", id, "MENU_CASH", g_vars[id][g_cash])
	formatex(msghead, charsmax(msghead), "%L", id, "COSTUME_HEAD")
	formatex(msgback, charsmax(msgback), "%L", id, "COSTUME_BACK")
	formatex(msgpelvis, charsmax(msgpelvis), "%L", id, "COSTUME_PELVIS")
	formatex(msgexit, charsmax(msgexit), "%L", id, "MENU_EXIT")

	new menu = menu_create(msgm, "menu_shop")

#if defined ZP_SUPPORT
	new msgskin[32]; formatex(msgskin, charsmax(msgskin), "%L", id, "COSTUME_SKIN")

	menu_additem(menu, msgskin, "0", 0)
	menu_additem(menu, msghead, "1", 0)
	menu_additem(menu, msgback, "2", 0)
	menu_additem(menu, msgpelvis, "3", 0)
#else
	new msgskinct[32], msgskintr[32]
	formatex(msgskinct, charsmax(msgskinct), "%L", id, "COSTUME_SKINCT")
	formatex(msgskintr, charsmax(msgskintr), "%L", id, "COSTUME_SKINTR")

	menu_additem(menu, msgskinct, "0", 0)
	menu_additem(menu, msgskintr, "1", 0)
	menu_additem(menu, msghead, "2", 0)
	menu_additem(menu, msgback, "3", 0)
	menu_additem(menu, msgpelvis, "4", 0)
#endif

	menu_setprop(menu, MPROP_EXITNAME, msgexit)

	menu_display(id, menu, 0)
}

public menu_costumeshop(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		if(g_vars[id][is_connected])
		{
			show_menu_shop(id)
		}

		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new key = item+1

#if defined ZP_SUPPORT
	if(g_vars[id][g_costume] == 0 && g_vars[id][g_acquiredSkin][key] || g_vars[id][g_costume] == 1 && g_vars[id][g_acquiredHead][key] || g_vars[id][g_costume] == 2 && g_vars[id][g_acquiredBack][key] || g_vars[id][g_costume] == 3 && g_vars[id][g_acquiredPelvis][key])
	{
		ColorChat(id, "%L", id, "ALREADY_HAVECOSTUME")
		show_menu_costumeshop(id)
	}
#else
	if(g_vars[id][g_costume] == 0 && g_vars[id][g_acquiredSkinCT][key] || g_vars[id][g_costume] == 1 && g_vars[id][g_acquiredSkinTR][key] || g_vars[id][g_costume] == 2 && g_vars[id][g_acquiredHead][key] || g_vars[id][g_costume] == 3 && g_vars[id][g_acquiredBack][key] || g_vars[id][g_costume] == 4 && g_vars[id][g_acquiredPelvis][key])
	{
		ColorChat(id, "%L", id, "ALREADY_HAVECOSTUME")
		show_menu_costumeshop(id)
	}
#endif
	else
	{
		g_vars[id][g_buying] = key
		show_menu_buycostume(id)
	}

	menu_destroy(menu)
	return PLUGIN_HANDLED
}

show_menu_costumeshop(id)
{
	new msgm[128], msg[128], msg1[16], msg2[64], msgacquired[32], msgback[32], msgnext[32], msgexit[32]
#if defined ZP_SUPPORT
	formatex(msgm, charsmax(msgm), "%s \y%L: %L^n\w%L: \r%d^n", PREFIX_MENU, id, "SHOP", id, g_vars[id][g_costume] > -1 ? g_vars[id][g_costume] > 0 ? g_vars[id][g_costume] > 1 ? g_vars[id][g_costume] > 2 ? "COSTUME_PELVIS" : "COSTUME_BACK" : "COSTUME_HEAD" : "COSTUME_SKIN" : "", id, "MENU_CASH", g_vars[id][g_cash])
#else
	formatex(msgm, charsmax(msgm), "%s \y%L: %L^n\w%L: \r%d^n", PREFIX_MENU, id, "SHOP", id, g_vars[id][g_costume] > -1 ? g_vars[id][g_costume] > 0 ? g_vars[id][g_costume] > 1 ? g_vars[id][g_costume] > 2 ? g_vars[id][g_costume] > 3 ? "COSTUME_PELVIS" : "COSTUME_BACK" : "COSTUME_HEAD" : "COSTUME_SKINTR" : "COSTUME_SKINCT" : "", id, "MENU_CASH", g_vars[id][g_cash])
#endif
	formatex(msgacquired, charsmax(msgacquired), "[%L]", id, "ACQUIRED")
	formatex(msgback, charsmax(msgback), "%L", id, "MENU_BACK")
	formatex(msgnext, charsmax(msgnext), "%L", id, "MENU_NEXT")
	formatex(msgexit, charsmax(msgexit), "%L", id, "MENU_EXIT")

	new menu = menu_create(msgm, "menu_costumeshop")

	switch(g_vars[id][g_costume])
	{
	#if defined ZP_SUPPORT
		case 0:
		{
			for(new i = 1; i < Total_Skin; i++)
			{
				formatex(msg2, charsmax(msg2), "[%L: %d]", id, "PRICE", Costumes_Skin[i][g_price])
				formatex(msg, charsmax(msg), "%s%s \r%s", g_vars[id][g_acquiredSkin][i] ? "\d" : "", Costumes_Skin[i][g_name], g_vars[id][g_acquiredSkin][i] ? msgacquired : msg2)
				num_to_str(i-1, msg1, charsmax(msg1))
				menu_additem(menu, msg, msg1, 0)
			}
		}
	#else
		case 0:
		{
			for(new i = 1; i < Total_SkinCT; i++)
			{
				formatex(msg2, charsmax(msg2), "[%L: %d]", id, "PRICE", Costumes_SkinCT[i][g_price])
				formatex(msg, charsmax(msg), "%s%s \r%s", g_vars[id][g_acquiredSkinCT][i] ? "\d" : "", Costumes_SkinCT[i][g_name], g_vars[id][g_acquiredSkinCT][i] ? msgacquired : msg2)
				num_to_str(i-1, msg1, charsmax(msg1))
				menu_additem(menu, msg, msg1, 0)
			}
		}
		case 1:
		{
			for(new i = 1; i < Total_SkinTR; i++)
			{
				formatex(msg2, charsmax(msg2), "[%L: %d]", id, "PRICE", Costumes_SkinTR[i][g_price])
				formatex(msg, charsmax(msg), "%s%s \r%s", g_vars[id][g_acquiredSkinTR][i] ? "\d" : "", Costumes_SkinTR[i][g_name], g_vars[id][g_acquiredSkinTR][i] ? msgacquired : msg2)
				num_to_str(i-1, msg1, charsmax(msg1))
				menu_additem(menu, msg, msg1, 0)
			}
		}
	#endif
		case y:
		{
			for(new i = 1; i < Total_Head; i++)
			{
				formatex(msg2, charsmax(msg1), "[%L: %d]", id, "PRICE", Costumes_Head[i][g_price])
				formatex(msg, charsmax(msg), "%s%s \r%s", g_vars[id][g_acquiredHead][i] ? "\d" : "", Costumes_Head[i][g_name], g_vars[id][g_acquiredHead][i] ? msgacquired : msg2)
				num_to_str(i-1, msg1, charsmax(msg1))
				menu_additem(menu, msg, msg1, 0)
			}
		}
		case y+1:
		{
			for(new i = 1; i < Total_Back; i++)
			{
				formatex(msg2, charsmax(msg2), "[%L: %d]", id, "PRICE", Costumes_Back[i][g_price])
				formatex(msg, charsmax(msg), "%s%s \r%s", g_vars[id][g_acquiredBack][i] ? "\d" : "", Costumes_Back[i][g_name], g_vars[id][g_acquiredBack][i] ? msgacquired : msg2)
				num_to_str(i-1, msg1, charsmax(msg1))
				menu_additem(menu, msg, msg1, 0)
			}
		}
		case y+2:
		{
			for(new i = 1; i < Total_Pelvis; i++)
			{
				formatex(msg2, charsmax(msg2), "[%L: %d]", id, "PRICE", Costumes_Pelvis[i][g_price])
				formatex(msg, charsmax(msg), "%s%s \r%s", g_vars[id][g_acquiredPelvis][i] ? "\d" : "", Costumes_Pelvis[i][g_name], g_vars[id][g_acquiredPelvis][i] ? msgacquired : msg2)
				num_to_str(i-1, msg1, charsmax(msg1))
				menu_additem(menu, msg, msg1, 0)
			}
		}
	}

	menu_setprop(menu, MPROP_BACKNAME, msgback)
	menu_setprop(menu, MPROP_NEXTNAME, msgnext)
	menu_setprop(menu, MPROP_EXITNAME, msgexit)

	menu_display(id, menu, 0)
}

public menu_buycostume(id, menu, item)
{
	switch(item)
	{
		case 0:
		{
			show_motd_costume(id)
			show_menu_buycostume(id)
		}
		case 1:
		{
			switch(g_vars[id][g_costume])
			{
			#if defined ZP_SUPPORT
				case 0:
				{
					if(g_vars[id][g_cash] >= Costumes_Skin[g_vars[id][g_buying]][g_price])
					{
						g_vars[id][g_cash] -= Costumes_Skin[g_vars[id][g_buying]][g_price]
						g_vars[id][g_acquiredSkin][g_vars[id][g_buying]] = 1
						g_vars[id][g_skin] = g_vars[id][g_buying]
						checkCostumes(id, 0)

						ColorChat(id, "%L", id, "BOUGHT_COSTUME", Costumes_Skin[g_vars[id][g_buying]][g_name])
						ColorChat(id, "%L", id, "BOUGHT_COSTUME2")
					}
					else
					{
						ColorChat(id, "%L", id, "NO_CASH")
					}
				}
			#else
				case 0:
				{
					if(g_vars[id][g_cash] >= Costumes_SkinCT[g_vars[id][g_buying]][g_price])
					{
						g_vars[id][g_cash] -= Costumes_SkinCT[g_vars[id][g_buying]][g_price]
						g_vars[id][g_acquiredSkinCT][g_vars[id][g_buying]] = 1
						g_vars[id][g_skinct] = g_vars[id][g_buying]
						checkCostumes(id, 0)

						ColorChat(id, "%L", id, "BOUGHT_COSTUME", Costumes_SkinCT[g_vars[id][g_buying]][g_name])
						ColorChat(id, "%L", id, "BOUGHT_COSTUME2")
					}
					else
					{
						ColorChat(id, "%L", id, "NO_CASH")
					}
				}
				case 1:
				{
					if(g_vars[id][g_cash] >= Costumes_SkinTR[g_vars[id][g_buying]][g_price])
					{
						g_vars[id][g_cash] -= Costumes_SkinTR[g_vars[id][g_buying]][g_price]
						g_vars[id][g_acquiredSkinTR][g_vars[id][g_buying]] = 1
						g_vars[id][g_skintr] = g_vars[id][g_buying]
						checkCostumes(id, 0)

						ColorChat(id, "%L", id, "BOUGHT_COSTUME", Costumes_SkinTR[g_vars[id][g_buying]][g_name])
						ColorChat(id, "%L", id, "BOUGHT_COSTUME2")
					}
					else
					{
						ColorChat(id, "%L", id, "NO_CASH")
					}
				}
			#endif
				case y:
				{
					if(g_vars[id][g_cash] >= Costumes_Head[g_vars[id][g_buying]][g_price])
					{
						g_vars[id][g_cash] -= Costumes_Head[g_vars[id][g_buying]][g_price]
						g_vars[id][g_acquiredHead][g_vars[id][g_buying]] = 1
						g_vars[id][g_head] = g_vars[id][g_buying]
						checkCostumes(id, 1)

						ColorChat(id, "%L", id, "BOUGHT_COSTUME", Costumes_Head[g_vars[id][g_buying]][g_name])
						ColorChat(id, "%L", id, "BOUGHT_COSTUME2")
					}
					else
					{
						ColorChat(id, "%L", id, "NO_CASH")
					}
				}
				case y+1:
				{
					if(g_vars[id][g_cash] >= Costumes_Back[g_vars[id][g_buying]][g_price])
					{
						g_vars[id][g_cash] -= Costumes_Back[g_vars[id][g_buying]][g_price]
						g_vars[id][g_acquiredBack][g_vars[id][g_buying]] = 1
						g_vars[id][g_back] = g_vars[id][g_buying]
						checkCostumes(id, 2)

						ColorChat(id, "%L", id, "BOUGHT_COSTUME", Costumes_Back[g_vars[id][g_buying]][g_name])
						ColorChat(id, "%L", id, "BOUGHT_COSTUME2")
					}
					else
					{
						ColorChat(id, "%L", id, "NO_CASH")
					}
				}
				case y+2:
				{
					if(g_vars[id][g_cash] >= Costumes_Pelvis[g_vars[id][g_buying]][g_price])
					{
						g_vars[id][g_cash] -= Costumes_Pelvis[g_vars[id][g_buying]][g_price]
						g_vars[id][g_acquiredPelvis][g_vars[id][g_buying]] = 1
						g_vars[id][g_pelvis] = g_vars[id][g_buying]
						checkCostumes(id, 3)

						ColorChat(id, "%L", id, "BOUGHT_COSTUME", Costumes_Pelvis[g_vars[id][g_buying]][g_name])
						ColorChat(id, "%L", id, "BOUGHT_COSTUME2")
					}
					else
					{
						ColorChat(id, "%L", id, "NO_CASH")
					}
				}
			}

			show_menu_costumeshop(id)
		}
		case MENU_EXIT:
		{
			if(g_vars[id][is_connected])
			{
				show_menu_costumeshop(id)
			}
		}
	}

	menu_destroy(menu)
	return PLUGIN_HANDLED
}

show_menu_buycostume(id)
{
	new msgm[256], msgpreview[32], msgbuy[32], msgcancel[32]
	formatex(msgpreview, charsmax(msgpreview), "%L", id, "PREVIEW")
	formatex(msgbuy, charsmax(msgbuy), "%L", id, "BUY")
	formatex(msgcancel, charsmax(msgcancel), "%L", id, "CANCEL_PURCHASE")

	switch(g_vars[id][g_costume])
	{
	#if defined ZP_SUPPORT
		case 0: formatex(msgm, charsmax(msgm), "%s \y%L: %L^n\w%L: \r%s^n\w%L: \r%d", PREFIX_MENU, id, "SHOP", id, "COSTUME_SKIN", id, "COSTUME", Costumes_Skin[g_vars[id][g_buying]][g_name], id, "PRICE", Costumes_Skin[g_vars[id][g_buying]][g_price])
	#else
		case 0: formatex(msgm, charsmax(msgm), "%s \y%L: %L^n\w%L: \r%s^n\w%L: \r%d", PREFIX_MENU, id, "SHOP", id, "COSTUME_SKINCT", id, "COSTUME", Costumes_SkinCT[g_vars[id][g_buying]][g_name], id, "PRICE", Costumes_SkinCT[g_vars[id][g_buying]][g_price])
		case 1: formatex(msgm, charsmax(msgm), "%s \y%L: %L^n\w%L: \r%s^n\w%L: \r%d", PREFIX_MENU, id, "SHOP", id, "COSTUME_SKINTR", id, "COSTUME", Costumes_SkinTR[g_vars[id][g_buying]][g_name], id, "PRICE", Costumes_SkinTR[g_vars[id][g_buying]][g_price])
	#endif
		case y: formatex(msgm, charsmax(msgm), "%s \y%L: %L^n\w%L: \r%s^n\w%L: \r%d", PREFIX_MENU, id, "SHOP", id, "COSTUME_HEAD", id, "COSTUME", Costumes_Head[g_vars[id][g_buying]][g_name], id, "PRICE", Costumes_Head[g_vars[id][g_buying]][g_price])
		case y+1: formatex(msgm, charsmax(msgm), "%s \y%L: %L^n\w%L: \r%s^n\w%L: \r%d", PREFIX_MENU, id, "SHOP", id, "COSTUME_BACK", id, "COSTUME", Costumes_Back[g_vars[id][g_buying]][g_name], id, "PRICE", Costumes_Back[g_vars[id][g_buying]][g_price])
		case y+2: formatex(msgm, charsmax(msgm), "%s \y%L: %L^n\w%L: \r%s^n\w%L: \r%d", PREFIX_MENU, id, "SHOP", id, "COSTUME_PELVIS", id, "COSTUME", Costumes_Pelvis[g_vars[id][g_buying]][g_name], id, "PRICE", Costumes_Pelvis[g_vars[id][g_buying]][g_price])
	}

	new menu = menu_create(msgm, "menu_buycostume")

	menu_additem(menu, msgpreview, "0", 0)
	menu_additem(menu, msgbuy, "1", 0)

	menu_setprop(menu, MPROP_EXITNAME, msgcancel)

	menu_display(id, menu, 0)
}

public show_motd_costume(id)
{
	new motd[512], motd_name[128]

	switch(g_vars[id][g_costume])
	{
	#if defined ZP_SUPPORT
		case 0:
		{
			formatex(motd, charsmax(motd), "<html><head><style>img{display:block;margin-top:125px;margin-left:auto;margin-right:auto;}</style></head><body style=^"margin:0px;background:#000000;^"><img src=^"%s^"></body></html>", Costumes_Skin[g_vars[id][g_buying]][g_preview])
			formatex(motd_name, charsmax(motd_name), "%s", Costumes_Skin[g_vars[id][g_buying]][g_name])
		}
	#else
		case 0:
		{
			formatex(motd, charsmax(motd), "<html><head><style>img{display:block;margin-top:125px;margin-left:auto;margin-right:auto;}</style></head><body style=^"margin:0px;background:#000000;^"><img src=^"%s^"></body></html>", Costumes_SkinCT[g_vars[id][g_buying]][g_preview])
			formatex(motd_name, charsmax(motd_name), "%s", Costumes_SkinCT[g_vars[id][g_buying]][g_name])
		}
		case 1:
		{
			formatex(motd, charsmax(motd), "<html><head><style>img{display:block;margin-top:125px;margin-left:auto;margin-right:auto;}</style></head><body style=^"margin:0px;background:#000000;^"><img src=^"%s^"></body></html>", Costumes_SkinTR[g_vars[id][g_buying]][g_preview])
			formatex(motd_name, charsmax(motd_name), "%s", Costumes_SkinTR[g_vars[id][g_buying]][g_name])
		}
	#endif
		case y:
		{
			formatex(motd, charsmax(motd), "<html><head><style>img{display:block;margin-top:125px;margin-left:auto;margin-right:auto;}</style></head><body style=^"margin:0px;background:#000000;^"><img src=^"%s^"></body></html>", Costumes_Head[g_vars[id][g_buying]][g_preview])
			formatex(motd_name, charsmax(motd_name), "%s", Costumes_Head[g_vars[id][g_buying]][g_name])
		}
		case y+1:
		{
			formatex(motd, charsmax(motd), "<html><head><style>img{display:block;margin-top:125px;margin-left:auto;margin-right:auto;}</style></head><body style=^"margin:0px;background:#000000;^"><img src=^"%s^"></body></html>", Costumes_Back[g_vars[id][g_buying]][g_preview])
			formatex(motd_name, charsmax(motd_name), "%s", Costumes_Back[g_vars[id][g_buying]][g_name])
		}
		case y+2:
		{
			formatex(motd, charsmax(motd), "<html><head><style>img{display:block;margin-top:125px;margin-left:auto;margin-right:auto;}</style></head><body style=^"margin:0px;background:#000000;^"><img src=^"%s^"></body></html>", Costumes_Pelvis[g_vars[id][g_buying]][g_preview])
			formatex(motd_name, charsmax(motd_name), "%s", Costumes_Pelvis[g_vars[id][g_buying]][g_name])
		}
	}

	show_motd(id, motd, motd_name)
}

reset_vars(id)
{
	g_vars[id][g_cash] = 0

#if defined ZP_SUPPORT
	g_vars[id][g_skin] = 0

	for(new i = 1; i < Total_Skin; i++)
	{
		g_vars[id][g_acquiredSkin][i] = 0
	}
#else
	g_vars[id][g_skinct] = 0
	g_vars[id][g_skintr] = 0

	for(new i = 1; i < Total_SkinCT; i++)
	{
		g_vars[id][g_acquiredSkinCT][i] = 0
	}

	for(new i = 1; i < Total_SkinTR; i++)
	{
		g_vars[id][g_acquiredSkinTR][i] = 0
	}
#endif

	g_vars[id][g_head] = 0
	g_vars[id][g_back] = 0
	g_vars[id][g_pelvis] = 0

	for(new i = 1; i < Total_Head; i++)
	{
		g_vars[id][g_acquiredHead][i] = 0
	}

	for(new i = 1; i < Total_Back; i++)
	{
		g_vars[id][g_acquiredBack][i] = 0
	}

	for(new i = 1; i < Total_Pelvis; i++)
	{
		g_vars[id][g_acquiredPelvis][i] = 0
	}
}

checkCostumes(id, key)
{
	if(!is_user_alive(id))
	{
		return
	}

#if defined ZP_SUPPORT
	if(ze_user_humanized(id) || ze_is_user_zombie(id) ||ze_is_user_nemesis(id))
	{
		return
	}
#endif

	switch(key)
	{
		case 0:
		{
		#if defined ZP_SUPPORT
			if(g_vars[id][g_skin] == 0)
			{
				cs_reset_player_model(id)
			}
			else
			{
				cs_set_player_model(id, Costumes_Skin[g_vars[id][g_skin]][g_model])
			}
		#else
			switch(get_user_team(id))
			{
				case 1:
				{
					if(g_vars[id][g_skintr] == 0)
					{
						cs_reset_player_model(id)
					}
					else
					{
						cs_set_player_model(id, Costumes_SkinTR[g_vars[id][g_skintr]][g_model])
					}
				}
				case 2:
				{
					if(g_vars[id][g_skinct] == 0)
					{
						cs_reset_player_model(id)
					}
					else
					{
						cs_set_player_model(id, Costumes_SkinCT[g_vars[id][g_skinct]][g_model])
					}
				}
			}
		#endif
		}
		case 1:
		{
			reset_costume(id, 1)

			if(g_vars[id][g_head] != 0)
			{
				make_costume(id, Costumes_Head[g_vars[id][g_head]][g_model], 1, Costumes_Head[g_vars[id][g_head]][g_anim])
			}
		}
		case 2:
		{
			reset_costume(id, 2)

			if(g_vars[id][g_back] != 0)
			{
				make_costume(id, Costumes_Back[g_vars[id][g_back]][g_model], 2, Costumes_Back[g_vars[id][g_back]][g_anim])
			}
		}
		case 3:
		{
			reset_costume(id, 3)

			if(g_vars[id][g_pelvis] != 0)
			{
				make_costume(id, Costumes_Pelvis[g_vars[id][g_pelvis]][g_model], 3, Costumes_Pelvis[g_vars[id][g_pelvis]][g_anim])
			}
		}
	}
}

make_costume(id, model[], part, anim)
{
	if(!is_user_alive(id))
	{
		return
	}

	switch(part)
	{
		case 1:
		{
			g_vars[id][g_CostumeModelHead] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

			set_pev(g_vars[id][g_CostumeModelHead], pev_movetype, MOVETYPE_FOLLOW)
			set_pev(g_vars[id][g_CostumeModelHead], pev_aiment, id)
			set_pev(g_vars[id][g_CostumeModelHead], pev_rendermode, kRenderNormal)
			engfunc(EngFunc_SetModel, g_vars[id][g_CostumeModelHead], model)
			set_pev(g_vars[id][g_CostumeModelHead], pev_body, anim)
			set_pev(g_vars[id][g_CostumeModelHead], pev_sequence, anim)
			set_pev(g_vars[id][g_CostumeModelHead], pev_animtime, get_gametime())
			set_pev(g_vars[id][g_CostumeModelHead], pev_framerate, 1.0)
		}
		case 2:
		{
			g_vars[id][g_CostumeModelBack] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

			set_pev(g_vars[id][g_CostumeModelBack], pev_movetype, MOVETYPE_FOLLOW)
			set_pev(g_vars[id][g_CostumeModelBack], pev_aiment, id)
			set_pev(g_vars[id][g_CostumeModelBack], pev_rendermode, kRenderNormal)
			engfunc(EngFunc_SetModel, g_vars[id][g_CostumeModelBack], model)
			set_pev(g_vars[id][g_CostumeModelBack], pev_body, anim)
			set_pev(g_vars[id][g_CostumeModelBack], pev_sequence, anim)
			set_pev(g_vars[id][g_CostumeModelBack], pev_animtime, get_gametime())
			set_pev(g_vars[id][g_CostumeModelBack], pev_framerate, 1.0)
		}
		case 3:
		{
			g_vars[id][g_CostumeModelPelvis] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

			set_pev(g_vars[id][g_CostumeModelPelvis], pev_movetype, MOVETYPE_FOLLOW)
			set_pev(g_vars[id][g_CostumeModelPelvis], pev_aiment, id)
			set_pev(g_vars[id][g_CostumeModelPelvis], pev_rendermode, kRenderNormal)
			engfunc(EngFunc_SetModel, g_vars[id][g_CostumeModelPelvis], model)
			set_pev(g_vars[id][g_CostumeModelPelvis], pev_body, anim)
			set_pev(g_vars[id][g_CostumeModelPelvis], pev_sequence, anim)
			set_pev(g_vars[id][g_CostumeModelPelvis], pev_animtime, get_gametime())
			set_pev(g_vars[id][g_CostumeModelPelvis], pev_framerate, 1.0)
		}
	}
}

reset_costume(id, number)
{
	if(!is_user_alive(id))
	{
		return
	}

	switch(number)
	{
		case 1:
		{
			fm_set_entity_visibility(g_vars[id][g_CostumeModelHead], 0)
			g_vars[id][g_CostumeModelHead] = 0
		}
		case 2:
		{
			fm_set_entity_visibility(g_vars[id][g_CostumeModelBack], 0)
			g_vars[id][g_CostumeModelBack] = 0
		}
		case 3:
		{
			fm_set_entity_visibility(g_vars[id][g_CostumeModelPelvis], 0)
			g_vars[id][g_CostumeModelPelvis] = 0
		}
	}
}

stock ColorChat(const id, const szInput[], any:...)
{
	new iPlayers[32], iCount = 1
	static szMessage[191]
	vformat(szMessage, charsmax(szMessage), szInput, 3)
	format(szMessage[0], charsmax(szMessage), "%s %s", PREFIX_CHAT, szMessage)

	replace_all(szMessage, charsmax(szMessage), "!g", "^4")
	replace_all(szMessage, charsmax(szMessage), "!n", "^1")
	replace_all(szMessage, charsmax(szMessage), "!t", "^3")

	if(id)
	{
		iPlayers[0] = id
	}
	else
	{
		get_players(iPlayers, iCount, "ch")
	}

	for(new i, iPlayer; i < iCount; i++)
	{
		iPlayer = iPlayers[i]

		if(g_vars[iPlayer][is_connected])
		{
			message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, iPlayer)
			write_byte(iPlayer)
			write_string(szMessage)
			message_end()
		}
	}
}

stock fm_set_entity_visibility(index, visible = 1)
{
	set_pev(index, pev_effects, visible == 1 ? pev(index, pev_effects) & ~EF_NODRAW : pev(index, pev_effects) | EF_NODRAW)

	return 1
}

stock precache_player_model(szModel[])
{
	static szFile[128]
	formatex(szFile, charsmax(szFile), "models/player/%s/%s.mdl", szModel, szModel)
	precache_model(szFile)
	replace(szFile, charsmax(szFile), ".mdl", "T.mdl")

	if(file_exists(szFile))
	{
		precache_model(szFile)
	}
}