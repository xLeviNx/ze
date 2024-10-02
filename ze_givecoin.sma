#include <ze_core>
 
#define ACCESS ADMIN_BAN
 
public plugin_init ()
{
    register_plugin("[ZE] Give Escape Coins", "1.0", "LevHost Gaming")
    register_clcmd("ze_giveec", "Cmd_GiveEC", ACCESS, "- ze_giveec <name> <amount>")
}
 
public Cmd_GiveEC(id)
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
   
    if (!is_user_connected(iTargetIndex))
        return PLUGIN_HANDLED
   
    new iECAmount = str_to_num (szAmount)
   
    ze_set_user_coins(iTargetIndex, ze_get_user_coins(iTargetIndex) + iECAmount)
    return PLUGIN_HANDLED
}