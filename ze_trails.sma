#include <ze_core>
#include <ze_vips>
 
#define PLUGIN_VERSION "1.0.0"
 
#define TASKID        81732519124
 
#define TRAIL_ACTIVE 1
#define TRAIL_INACTIVE 0
#define TRAIL_LIFE 15
#define ACCES_FLAG  VIP_K
 
new gTrailSprite;
new gTrailRandomColor[ 33 ][ 3 ];
new bPlayerTrailStatus[ 33 ];
new Float:bflNextCheck[ 33 ];
new const gTrailSpriteIndex[] = "sprites/zbeam2.spr";
 
const IN_MOVING = IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_JUMP;
 
public plugin_init()
{
    register_plugin( "Owner Trail", PLUGIN_VERSION, "tuty" );  
    register_forward( FM_CmdStart, "forward_cmdstart" );
    register_clcmd( "say trail", "cmdMakeOwnerTrail" );
    register_clcmd( "say_team trail", "cmdMakeOwnerTrail" );
   
    RegisterHookChain(RG_CBasePlayer_Spawn, "Fw_PlayerSpawn_Post", 1);
}
 
public plugin_precache()
{
    gTrailSprite = precache_model( gTrailSpriteIndex );
}
 
public client_connect( id )
{
    bPlayerTrailStatus[ id ] = TRAIL_INACTIVE;
}
 
public Fw_PlayerSpawn_Post(id)
{
    if(get_user_flags(id) & ACCES_FLAG)
    {
        bPlayerTrailStatus[id] = TRAIL_ACTIVE;
       
        gTrailRandomColor[ id ][ 0 ] = random_num( 0, 255 );  
        gTrailRandomColor[ id ][ 1 ] = random_num( 0, 255 );  
        gTrailRandomColor[ id ][ 2 ] = random_num( 0, 255 );
       
        set_task(10.0, "change_color", id + TASKID, .flags="b");
    }
}
 
public change_color(taskid)
{
    new id = taskid - TASKID;
   
    if(!is_user_alive(id))
    {
        remove_task(taskid);
        return;
    }
   
    gTrailRandomColor[ id ][ 0 ] = random_num( 0, 255 );  
    gTrailRandomColor[ id ][ 1 ] = random_num( 0, 255 );  
    gTrailRandomColor[ id ][ 2 ] = random_num( 0, 255 );    
}
 
public cmdMakeOwnerTrail( id )
{
    if( !is_user_alive( id ) )
    {  
        client_print( id, print_chat, "[Trail] Do not use this command when you're dead!" );  
        return PLUGIN_HANDLED;
    }  
    if( !( get_user_flags( id ) & ACCES_FLAG ) )
    {  
        client_print( id, print_chat, "[Trail] No access to this command!" );  
        return PLUGIN_HANDLED;
    }
   
    if( bPlayerTrailStatus[ id ] == TRAIL_ACTIVE )
    {  
       
        client_print( id, print_chat, "[Trail] Your Trail was disabled!" );  
       
        bPlayerTrailStatus[ id ] = TRAIL_INACTIVE;  
       
        UTIL_KillBeamFollow( id );  
       
        bflNextCheck[ id ] = -5000.0;    
       
        return PLUGIN_HANDLED;
    }  
   
    if( bPlayerTrailStatus[ id ] == TRAIL_INACTIVE )
    {  
        client_print( id, print_chat, "[Trail] Trail enabled! Now you trail!" );  
       
        bPlayerTrailStatus[ id ] = TRAIL_ACTIVE;    
       
        gTrailRandomColor[ id ][ 0 ] = random_num( 0, 255 );  
        gTrailRandomColor[ id ][ 1 ] = random_num( 0, 255 );  
        gTrailRandomColor[ id ][ 2 ] = random_num( 0, 255 );    
       
        return PLUGIN_HANDLED;
    }  
   
    return PLUGIN_CONTINUE;
}
 
public forward_cmdstart( id, handle )
{
    if( !is_user_alive( id ) || bPlayerTrailStatus[ id ] == TRAIL_INACTIVE )
    {  
        return FMRES_IGNORED;
    }
   
    new iButton = get_uc( handle, UC_Buttons );
   
    if( !( iButton & IN_MOVING ) )
    {
        new Float:flGameTime = get_gametime();  
        if( bflNextCheck[ id ] < flGameTime )
        {  
            UTIL_KillBeamFollow( id );  
            UTIL_BeamFollow( id );
            bflNextCheck[ id ] = flGameTime + ( TRAIL_LIFE / 8 );  
        }
    }  
   
    return FMRES_IGNORED;
}  
 
stock UTIL_BeamFollow( const iClient )
{
    message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
    write_byte( TE_BEAMFOLLOW );
    write_short( iClient );
    write_short( gTrailSprite );
    write_byte( TRAIL_LIFE );
    write_byte( 20 );
    write_byte( gTrailRandomColor[ iClient ][ 0 ] );
    write_byte( gTrailRandomColor[ iClient ][ 1 ] );
    write_byte( gTrailRandomColor[ iClient ][ 2 ] );
    write_byte( 255 );
    message_end();
}
   
stock UTIL_KillBeamFollow( const iClient )
{
    message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
    write_byte( TE_KILLBEAM );    
    write_short( iClient );
    message_end();
}