#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>

#undef REQUIRE_PLUGIN
#tryinclude <basecomm>
#tryinclude <sourcecomms>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "6.5.1"

public Plugin myinfo = 
{
    name = "[TF2] Chat Annotations",
    author = "HowToPlayMeow",
    description = "Display an annotation above players' heads when they chat.",
    version = PLUGIN_VERSION,
    url = "https://github.com/HowToPlayMeow/TF2-Chat-Annotations"
};

enum
{
    plugin_enabled,
    annotation_range,
    annotation_show_range,
    annotation_show_msg,
    annotation_show_cmd,
    annotation_interval,
    annotation_life,
    annotation_limit,
    annotation_max_len,
    annotation_remove,
    annotation_block,

    MAX_CONVARS
}

ConVar g_ConVars[MAX_CONVARS];

Handle  g_hTimerAnn = null;
char    g_cLastMsg[MAXPLAYERS+1][256];
int     g_iAnnID[MAXPLAYERS+1];
int     g_iAnnIDMeow = 1;
int     g_iBaseComm = 0;
int     g_iSourceComms = 0;
bool    g_bAnnIsTeam[MAXPLAYERS+1];
bool    g_bViewerSee[MAXPLAYERS+1][MAXPLAYERS+1];
bool    g_bPlayerMoved[MAXPLAYERS+1];
float   g_flAnnN[MAXPLAYERS+1];
float   g_flLastPos[MAXPLAYERS+1][3];
float   g_flLastAng[MAXPLAYERS+1][3];
float   g_flCachePos[MAXPLAYERS+1][3];

public void OnPluginStart() 
{
    CreateConVar("sm_cvann_version", PLUGIN_VERSION, "Version of TF2Chat Annotations.", FCVAR_NOTIFY | FCVAR_DONTRECORD);
    
    g_ConVars[plugin_enabled]        = CreateConVar("sm_cvann_enable", "1", "TF2Chat Annotations. (1 = Enable, 0 = Disable)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_ConVars[annotation_range]      = CreateConVar("sm_cvann_range", "25", "Distance to See Annotations.", FCVAR_NONE, true, 0.0);
    g_ConVars[annotation_show_range] = CreateConVar("sm_cvann_show_range", "0", "Show Distance to speaker in Annotations. (1 = Enable, 0 = Disable)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_ConVars[annotation_show_msg]   = CreateConVar("sm_cvann_show_msg", "1", "Allow Players to See their own Chat Annotation. (1 = Enable, 0 = Disable)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_ConVars[annotation_show_cmd]   = CreateConVar("sm_cvann_show_cmd", "1", "Command Visibility. (0 = Hide ! and /, 1 = Show !, 2 = Show /, 3 = Show ! and /)", FCVAR_NONE, true, 0.0, true, 3.0);
    g_ConVars[annotation_interval]   = CreateConVar("sm_cvann_interval", "0.5", "Update interval for checking Annotation Visibility.", FCVAR_NONE, true, 0.5);
    g_ConVars[annotation_life]       = CreateConVar("sm_cvann_lifetime", "10.0", "How long Message stays visible (Seconds).", FCVAR_NONE, true, 0.0);
    g_ConVars[annotation_limit]      = CreateConVar("sm_cvann_limit", "5", "Maximum Number of Annotations shown at same time. (0 = Unlimited)", FCVAR_NONE, true, 0.0);
    g_ConVars[annotation_max_len]    = CreateConVar("sm_cvann_maxlen", "64", "Maximum Length of Chat Message shown in Annotations.", FCVAR_NONE, true, 0.0, true, 128.0);
    g_ConVars[annotation_remove]     = CreateConVar("sm_cvann_entity_remove", "1900", "Remove All Annotations if Entity count reaches this.", FCVAR_NONE, true, 0.0, true, 2048.0);
    g_ConVars[annotation_block]      = CreateConVar("sm_cvann_entity_block", "2000", "Block New Annotations if Entity count reaches this.", FCVAR_NONE, true, 0.0, true, 2048.0);

    HookEvent("player_spawn", Event_PlayerSpawn_Death);
    HookEvent("player_death", Event_PlayerSpawn_Death);

    AutoExecConfig(true, "tf_chat_annotations");
    StartAnnotation();
}

public void OnMapStart()
{
    StartAnnotation();
}

public void OnPluginEnd()
{
    StopAnnotation();
}

public void OnMapEnd()
{
    StopAnnotation();
}

public void OnClientPutInServer(int client)
{
    HideAnnotation(client);
}

public void OnClientDisconnect(int client)
{
    HideAnnotation(client);
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
    switch (condition)
    {
        case TFCond_Cloaked, TFCond_Disguised, TFCond_Disguising, TFCond_DisguisedAsDispenser:
        {
            if (client > 0 && IsClientInGame(client))
                HideAnnotation(client);
        }
    }
}

void StartAnnotation()
{
    g_iBaseComm    = LibraryExists("basecomm") ? 1 : 0;
    g_iSourceComms = LibraryExists("sourcecomms") ? 1 : 0;

    float interval = g_ConVars[annotation_interval].FloatValue;
    if (g_hTimerAnn == null)
        g_hTimerAnn = CreateTimer(interval, UpdateAnnotation, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void StopAnnotation()
{
    RemoveAnnotationAll();

    g_iBaseComm = 0;
    g_iSourceComms = 0;

    if (g_hTimerAnn != null)
    {
        delete g_hTimerAnn;
        g_hTimerAnn = null;
    }
}

public void Event_PlayerSpawn_Death(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client))
        HideAnnotation(client);
}

bool IsServerCrashImminent()
{
    int entities = GetEntityCount();
    int remove = g_ConVars[annotation_remove].IntValue;
    int block = g_ConVars[annotation_block].IntValue;
    
    if (remove > 0 && remove <= 2048 && entities >= remove)
        RemoveAnnotationAll();

    if (block > 0 && block <= 2048 && entities >= block)
        return false;

    return true;
}

bool ShowAnnotationPossible(int client)
{
    if (client <= 0 || !IsClientInGame(client))
        return false;

    if (TF2_IsPlayerInCondition(client, TFCond_Cloaked) || TF2_IsPlayerInCondition(client, TFCond_Disguised) || TF2_IsPlayerInCondition(client, TFCond_Disguising) || TF2_IsPlayerInCondition(client, TFCond_DisguisedAsDispenser))
        return false;

    return true;
}

bool ShowAnnotationAllowed(int client)
{
    #if defined _basecomm_included
    if (g_iBaseComm == 1)
    {
        if (BaseComm_IsClientGagged(client))
            return false;
    }
    #endif

    #if defined _sourcecomms_included
    if (g_iSourceComms == 1)
    {
        int NOPE = view_as<int>(SourceComms_GetClientGagType(client));
        if (NOPE == 1 || NOPE == 3)
            return false;
    }
    #endif

    return true;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
    bool enable = g_ConVars[plugin_enabled].BoolValue;
    float range = g_ConVars[annotation_range].FloatValue;
    float life = g_ConVars[annotation_life].FloatValue;
    int cmd = g_ConVars[annotation_show_cmd].IntValue;
    int maxlen = g_ConVars[annotation_max_len].IntValue;

    if (!enable || !IsServerCrashImminent())
        return;

    if (range <= 0.0 || life <= 0.0 || maxlen <= 0)
        return;

    if (!ShowAnnotationPossible(client) || !ShowAnnotationAllowed(client) || !IsPlayerAlive(client))
        return;

    char buffer[256];
    strcopy(buffer, sizeof(buffer), sArgs);
    StripQuotes(buffer);
    TrimString(buffer);

    ReplaceString(buffer, sizeof(buffer), "%", "﹪");
    ReplaceString(buffer, sizeof(buffer), "&", "﹠");

    if (buffer[0] == '\0')
        return;

    if (cmd < 3)
    {
        switch (cmd)
        {
            case 0:
                if (buffer[0] == '!' || buffer[0] == '/') return;
            case 1:
                if (buffer[0] == '/') return;
            case 2:
                if (buffer[0] == '!') return;
        }
    }

    if (strlen(buffer) > maxlen)
        buffer[maxlen] = '\0';

    bool isTeam = StrEqual(command, "say_team");
    DisplayAnnotation(client, isTeam, buffer, life);
}

void DisplayAnnotation(int client, bool isTeam, const char[] sArgs, float life)
{
    HideAnnotation(client);

    g_bAnnIsTeam[client] = isTeam;
    g_iAnnIDMeow = (g_iAnnIDMeow % 0x7FFFFFFF) + 1;
    g_iAnnID[client] = g_iAnnIDMeow;

    strcopy(g_cLastMsg[client], sizeof(g_cLastMsg[]), sArgs);
    g_flAnnN[client] = GetGameTime() + life;
}

public Action UpdateAnnotation(Handle timer)
{
    bool enable = g_ConVars[plugin_enabled].BoolValue;
    float range = g_ConVars[annotation_range].FloatValue * 40.0;
    float rangeSqr = range * range;
    float now = GetGameTime();
    int activeTalkers[MAXPLAYERS+1];
    int activeCount = 0;

    if (!enable)
        return Plugin_Continue;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        g_bPlayerMoved[i] = IsClientInMotion(i);
        GetClientEyePosition(i, g_flCachePos[i]);

        if (g_iAnnID[i] != 0)
        {
            if (!ShowAnnotationPossible(i) || g_flAnnN[i] <= now)
                HideAnnotation(i);
            else
                activeTalkers[activeCount++] = i;
        }
    }

    if (activeCount == 0)
        return Plugin_Continue;

    for (int t = 0; t < activeCount; t++)
    {
        int talker = activeTalkers[t];
        bool talkerMoved = g_bPlayerMoved[talker];

        for (int viewer = 1; viewer <= MaxClients; viewer++)
        {
            if (!IsClientInGame(viewer) || IsFakeClient(viewer))
                continue;

            YouSeeAnnotation(viewer, talker, talkerMoved, g_bPlayerMoved[viewer], rangeSqr, now);
        }
    }
    return Plugin_Continue;
}

bool IsClientInMotion(int client)
{
    if (!IsClientInGame(client))
        return false;

    float pos[3], ang[3];
    GetClientAbsOrigin(client, pos);
    GetClientEyeAngles(client, ang);

    if (GetVectorDistance(pos, g_flLastPos[client], true) > 4.0 || GetVectorDistance(ang, g_flLastAng[client], true) > 1.0)
    {
        for (int i = 0; i < 3; i++) 
        { 
            g_flLastPos[client][i] = pos[i];
            g_flLastAng[client][i] = ang[i];
        }
        return true;
    }
    return false;
}

void YouSeeAnnotation(int viewer, int talker, bool talkerMoved, bool viewerMoved, float rangeSqr, float now)
{
    if (!IsClientInGame(viewer) || IsFakeClient(viewer))
        return;

    bool seesArgs = g_ConVars[annotation_show_msg].BoolValue;
    if (viewer == talker && !seesArgs)
        return;

    if (g_bAnnIsTeam[talker] && GetClientTeam(talker) != GetClientTeam(viewer))
        return;

    if (!talkerMoved && !viewerMoved && g_bViewerSee[viewer][talker])
        return;

    if (GetVectorDistance(g_flCachePos[talker], g_flCachePos[viewer], true) > rangeSqr)
    {
        if (g_bViewerSee[viewer][talker])
        { 
            HideAnnotationReal(talker, viewer);
            g_bViewerSee[viewer][talker] = false;
        }
        return;
    }

    float ang[3], dir[3], vec[3];
    GetClientEyeAngles(viewer, ang);
    GetAngleVectors(ang, dir, NULL_VECTOR, NULL_VECTOR); 
    MakeVectorFromPoints(g_flCachePos[viewer], g_flCachePos[talker], vec);
    NormalizeVector(vec, vec);

    if (GetVectorDotProduct(dir, vec) < 0.0)
    {
        if (g_bViewerSee[viewer][talker])
        {
            HideAnnotationReal(talker, viewer);
            g_bViewerSee[viewer][talker] = false;
        }
        return;
    }

    TR_TraceRayFilter(g_flCachePos[viewer], g_flCachePos[talker], MASK_VISIBLE, RayType_EndPoint, TraceRayIgnoreClients, viewer);

    if (!TR_DidHit())
    {
        if (!g_bViewerSee[viewer][talker] && !MaxAnnotation(viewer))
        {
            ShowAnnotation(talker, viewer, g_flAnnN[talker] - now);
            g_bViewerSee[viewer][talker] = true;
        }
    }
    else if (g_bViewerSee[viewer][talker])
    {
        HideAnnotationReal(talker, viewer);
        g_bViewerSee[viewer][talker] = false;
    }
}

public bool TraceRayIgnoreClients(int entity, int mask, any data)
{
    if (entity == data)
        return false;

    if (entity > 0 && entity <= MaxClients)
        return false;

    return true;
}

bool MaxAnnotation(int viewer) 
{
    int count = 0;
    int oldestTalker = -1;
    int limit = g_ConVars[annotation_limit].IntValue;
    float life = g_ConVars[annotation_life].FloatValue;
    float time = GetGameTime() + life;

    if (limit <= 0)
        return false;
    
    for (int t = 1; t <= MaxClients; t++)
    {
        if (g_bViewerSee[viewer][t])
        {
            if (t == viewer)
                continue;

            count++;

            if (g_flAnnN[t] < time)
            {
                time = g_flAnnN[t];
                oldestTalker = t;
            }
        }
    }

    if (count < limit)
        return false;

    if (oldestTalker != -1)
    {
        HideAnnotationReal(oldestTalker, viewer);
        g_bViewerSee[viewer][oldestTalker] = false;
        return false;
    }
    return true;
}

void ShowAnnotation(int client, int viewer, float life)
{
    if (!IsClientInGame(client) || !IsClientInGame(viewer))
        return;

    Event event = CreateEvent("show_annotation");
    bool show = g_ConVars[annotation_show_range].BoolValue;

    if (event)
    {
        event.SetInt("follow_entindex", client);
        event.SetInt("id", g_iAnnID[client]);
        event.SetString("text", g_cLastMsg[client]);
        event.SetFloat("lifetime", life);
        event.SetBool("show_distance", show);
        event.FireToClient(viewer);
    }
}

void HideAnnotation(int client)
{
    if (g_iAnnID[client] != 0)
        HideAnnotationReal(client, 0);

    g_iAnnID[client] = 0;
    g_flAnnN[client] = 0.0;
    g_bAnnIsTeam[client] = false;

    for (int i = 1; i <= MaxClients; i++)
        g_bViewerSee[i][client] = false;
}

void HideAnnotationReal(int client, int viewer)
{
    Event event = CreateEvent("hide_annotation");
    if (!event) return;

    event.SetInt("follow_entindex", client);
    event.SetInt("id", g_iAnnID[client]);

    if (viewer > 0 && IsClientInGame(viewer))
        event.FireToClient(viewer);
    else
        event.Fire();
}

void RemoveAnnotationAll()
{
    for (int i = 1; i <= MaxClients; i++)
        HideAnnotation(i);
}