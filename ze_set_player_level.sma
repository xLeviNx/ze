#include <ze_core>
#include <ze_levels>

#define ACCESS ADMIN_BAN

public plugin_init ()
{
	register_plugin("[ZE] Set Player Level", "1.0", "LevHost Gaming")
	register_clcmd("ze_setlevel", "Cmd_SetLevel", ACCESS, "- ze_setlevel <name> <amount>")
}

public Cmd_SetLevel(id)
{
	if (!(get_user_flags(id) & ACCESS))
	{
		client_print(id, print_console, "You have no access to that command")
		return PLUGIN_HANDLED
	}
	
	new szName[32], szAmount[10]
	
	read_argv (1, szName, charsmax (szName))
	read_argv (2, szAmount, charsmax (szAmount))
	
	new iTargetIndex = get_user_index(szName)
	
	if (!iTargetIndex)
	{
		client_print(id, print_console, "[ZE] Player not found!")
		return PLUGIN_HANDLED
	}
	
	new iLevel = str_to_num (szAmount)
	
	ze_set_user_level(iTargetIndex, iLevel)

	return PLUGIN_HANDLED
}
