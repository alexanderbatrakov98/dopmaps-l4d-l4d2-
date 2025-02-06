#include <sourcemod>

#define CONFIG_PATH "configs/dopmap.ini"

ArrayList g_hTitles;
ArrayList g_hCommands;

bool g_bVoteInProgress;
char g_sMapToChange[256];
KeyValues g_kvMapList;

public Plugin myinfo = 
{
    name = "DopMaps",
    author = "Alexander Mirny",
    description = "Плагин позволяющий менять карты на дополнительные.",
    version = "1.0",
    url = "https://vk.com/id602817125"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_dmaps", Command_VoteMap);
    
    RegAdminCmd("sm_amaps", AdminCommand_MapMenu, ADMFLAG_GENERIC, "Меню для быстрой смены карты");
    
    g_hTitles = new ArrayList(256);
    g_hCommands = new ArrayList(256);
    
    LoadMapConfig();
}

void LoadMapConfig()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), CONFIG_PATH);
    
    g_kvMapList = new KeyValues("Maps");
    
    if(!g_kvMapList.ImportFromFile(path))
    {
        SetFailState("Не удалось загрузить файл конфигурации: %s", path);
        return;
    }
    
    if(!g_kvMapList.GotoFirstSubKey())
    {
        SetFailState("Конфигурационный файл пуст или имеет неверный формат!");
        return;
    }
    
    do
    {
        char mapCommand[256], mapTitle[256];
        g_kvMapList.GetSectionName(mapCommand, sizeof(mapCommand));
        g_kvMapList.GetString("title", mapTitle, sizeof(mapTitle), "Unknown Map");
        
        g_hTitles.PushString(mapTitle);
        g_hCommands.PushString(mapCommand);
        
        LogMessage("Загружена карта: %s - %s", mapCommand, mapTitle);
    }
    while(g_kvMapList.GotoNextKey());
    
    delete g_kvMapList;
    
    if(g_hTitles.Length == 0)
    {
        SetFailState("Не найдено ни одной карты в конфигурации!");
    }
}

public Action Command_VoteMap(int client, int args)
{
    if(g_bVoteInProgress)
    {
        ReplyToCommand(client, "Голосование уже проводится!");
        return Plugin_Handled;
    }

    Handle menu = CreateMenu(VoteMapMenuHandler);
    SetMenuTitle(menu, "Выберите карту для голосования");
    
    for(int i = 0; i < g_hTitles.Length; i++)
    {
        char title[256], command[256];
        g_hTitles.GetString(i, title, sizeof(title));
        g_hCommands.GetString(i, command, sizeof(command));
        AddMenuItem(menu, command, title);
    }
    
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public Action AdminCommand_MapMenu(int client, int args)
{
    if (client < 1 || !IsClientInGame(client))
    {
        PrintToServer("[SM] Меню не может быть открыто: неверный клиент.");
        return Plugin_Handled;
    }

    Handle menu = CreateMenu(AdminMenuHandler);
    SetMenuTitle(menu, "Админ меню карт");
    
    for(int i = 0; i < g_hTitles.Length; i++)
    {
        char title[256], command[256];
        g_hTitles.GetString(i, title, sizeof(title));
        g_hCommands.GetString(i, command, sizeof(command));
        AddMenuItem(menu, command, title);
    }
    
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public int AdminMenuHandler(Handle menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char mapCommand[256];
        GetMenuItem(menu, param2, mapCommand, sizeof(mapCommand));
        
        char mapTitle[256];
        if (!GetMapTitle(mapCommand, mapTitle, sizeof(mapTitle)))
        {
            PrintToChat(client, "Ошибка выбора карты!");
            return;
        }
        
        PrintToChatAll("[SM] Admin %N сменил карту на %s", client, mapTitle);
        ServerCommand("changelevel %s", mapCommand);
    }
    else if (action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

public int VoteMapMenuHandler(Handle menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char mapCommand[256];
        GetMenuItem(menu, param2, mapCommand, sizeof(mapCommand));
        
        if (g_bVoteInProgress)
        {
            PrintToChat(client, "Голосование уже начато!");
            return;
        }
        
        char mapTitle[256];
        if (!GetMapTitle(mapCommand, mapTitle, sizeof(mapTitle)))
        {
            PrintToChat(client, "Ошибка выбора карты!");
            return;
        }
        
        g_bVoteInProgress = true;
        strcopy(g_sMapToChange, sizeof(g_sMapToChange), mapCommand);
        
        Handle voteMenu = CreateMenu(Handle_Vote);
        SetMenuTitle(voteMenu, "Сменить карту на %s?", mapTitle);
        AddMenuItem(voteMenu, "yes", "За");
        AddMenuItem(voteMenu, "no", "Против");
        SetMenuExitButton(voteMenu, false);
        
        VoteMenuToAll(voteMenu, 20);
    }
    else if (action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

bool GetMapTitle(const char[] command, char[] title, int size)
{
    for (int i = 0; i < g_hCommands.Length; i++)
    {
        char buffer[256];
        g_hCommands.GetString(i, buffer, sizeof(buffer));
        
        if (StrEqual(buffer, command))
        {
            g_hTitles.GetString(i, title, size);
            return true;
        }
    }
    return false;
}

public int Handle_Vote(Handle menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        CloseHandle(menu);
        g_bVoteInProgress = false;
    }
    else if (action == MenuAction_VoteEnd)
    {
        if (param1 == 0)
        {
            PrintToChatAll("[SM] Голосование прошло! Смена карты через 5 секунд.");
            CreateTimer(5.0, Timer_ChangeMap);
        }
        else
        {
            PrintToChatAll("[SM] Игроки отвергли смену карты.");
        }
        g_bVoteInProgress = false;
    }
}

public Action Timer_ChangeMap(Handle timer)
{
    ServerCommand("changelevel %s", g_sMapToChange);
}