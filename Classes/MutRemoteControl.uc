// ============================================================
//  MutRemoteControl.uc
//  Пакет: LMSGameTikTok
//
//  UDP мутатор адаптированный под LMSGame:
//    - Все спавны ботов → Team 1
//    - One-time логика убрана — LMSGame.RestartPlayer блокирует respawn
//    - Добавлена команда: setteam <0|1>
// ============================================================
class MutRemoteControl extends Mutator;

var RemoteUdpLink Udp;

function PostBeginPlay()
{
    Super.PostBeginPlay();

    Log("[MRC] PostBeginPlay");

    Udp = Spawn(class'LMSGameTikTok.RemoteUdpLink');
    if (Udp != None)
    {
        Log("[MRC] RemoteUdpLink spawned");
        Udp.OwnerMutator = self;
        Udp.Init(7779);
    }
    else
    {
        Log("[MRC] Failed to spawn RemoteUdpLink");
    }
}

// После спавна бота — назначаем его в Team 1
function AssignBotToEnemyTeam(Bot B)
{
    local LMSGame G;

    if (B == None || B.PlayerReplicationInfo == None)
        return;

    G = LMSGame(Level.Game);
    if (G != None)
    {
        G.ChangeTeam(B, 1, false);
        Log("[MRC] Bot assigned to Team 1: " $ B.PlayerReplicationInfo.PlayerName);
    }
    else
    {
        Log("[MRC] AssignBotToEnemyTeam: LMSGame not found");
    }
}

function Bot FindNewestBot(optional string PreferredName)
{
    local Controller C;
    local Bot B;
    local Bot BestMatch;
    local Bot BestAny;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        B = Bot(C);
        if (B != None && B.PlayerReplicationInfo != None)
        {
            if (BestAny == None || B.PlayerReplicationInfo.PlayerID > BestAny.PlayerReplicationInfo.PlayerID)
                BestAny = B;

            if (PreferredName != "" && (B.PlayerReplicationInfo.PlayerName ~= PreferredName))
                if (BestMatch == None || B.PlayerReplicationInfo.PlayerID > BestMatch.PlayerReplicationInfo.PlayerID)
                    BestMatch = B;
        }
    }

    if (BestMatch != None)
        return BestMatch;

    return BestAny;
}

function PlayerController GetLocalPlayerController()
{
    local PlayerController PC;

    foreach DynamicActors(class'PlayerController', PC)
        return PC;

    return None;
}

function string TrimSpaces(string S)
{
    while (Len(S) > 0 && Left(S, 1) == " ")
        S = Mid(S, 1);
    while (Len(S) > 0 && Right(S, 1) == " ")
        S = Left(S, Len(S) - 1);
    return S;
}

function string GetCommandName(string FullCmd)
{
    local int SpacePos;
    FullCmd = TrimSpaces(FullCmd);
    SpacePos = InStr(FullCmd, " ");
    if (SpacePos == -1) return FullCmd;
    return Left(FullCmd, SpacePos);
}

function string GetCommandArg(string FullCmd)
{
    local int SpacePos;
    FullCmd = TrimSpaces(FullCmd);
    SpacePos = InStr(FullCmd, " ");
    if (SpacePos == -1) return "";
    return TrimSpaces(Mid(FullCmd, SpacePos + 1));
}

function string GetFirstWord(string S)
{
    local int SpacePos;
    S = TrimSpaces(S);
    SpacePos = InStr(S, " ");
    if (SpacePos == -1) return S;
    return Left(S, SpacePos);
}

function string GetSecondArg(string FullCmd)
{
    local int FirstSpacePos;
    local int SecondSpacePos;
    local string Rest;

    FullCmd = TrimSpaces(FullCmd);
    FirstSpacePos = InStr(FullCmd, " ");
    if (FirstSpacePos == -1) return "";

    Rest = TrimSpaces(Mid(FullCmd, FirstSpacePos + 1));
    SecondSpacePos = InStr(Rest, " ");
    if (SecondSpacePos == -1) return "";

    return TrimSpaces(Mid(Rest, SecondSpacePos + 1));
}

function ApplyBoostToPlayer(PlayerController PC)
{
    local xPawn P;

    if (PC == None || PC.Pawn == None) { Log("[MRC] ApplyBoostToPlayer: no pawn"); return; }

    P = xPawn(PC.Pawn);
    if (P == None) { Log("[MRC] ApplyBoostToPlayer: not xPawn"); return; }

    P.Health = 300;
    P.HealthMax = 300;
    P.SuperHealthMax = 300;
    P.MaxMultiJump = 3;
    P.MultiJumpBoost = 100.0;

    PC.ClientMessage("Boost applied.");
    Log("[MRC] Boost applied");
}

function StripWeaponsFromPlayer(PlayerController PC)
{
    local Inventory Inv;
    local Inventory NextInv;
    local Weapon W;

    if (PC == None || PC.Pawn == None) { Log("[MRC] StripWeaponsFromPlayer: no pawn"); return; }

    Inv = PC.Pawn.Inventory;
    while (Inv != None)
    {
        NextInv = Inv.Inventory;
        if (Weapon(Inv) != None) { PC.Pawn.DeleteInventory(Inv); Inv.Destroy(); }
        Inv = NextInv;
    }

    PC.Pawn.Weapon = None;
    PC.Pawn.PendingWeapon = None;
    PC.Pawn.GiveWeapon("XWeapons.ShieldGun");

    W = Weapon(PC.Pawn.FindInventoryType(class'ShieldGun'));
    if (W != None) PC.Pawn.Weapon = W;

    PC.ClientMessage("Weapons stripped. ShieldGun equipped.");
    Log("[MRC] Weapons stripped from player");
}

function StripWeaponsFromAllPawns()
{
    local Controller C;
    local Inventory Inv;
    local Inventory NextInv;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        if (C.Pawn != None)
        {
            Inv = C.Pawn.Inventory;
            while (Inv != None)
            {
                NextInv = Inv.Inventory;
                if (Weapon(Inv) != None) { C.Pawn.DeleteInventory(Inv); Inv.Destroy(); }
                Inv = NextInv;
            }
            C.Pawn.Weapon = None;
            C.Pawn.PendingWeapon = None;
        }
    }
    Log("[MRC] Weapons stripped from all pawns");
}

function AddGenericBot(PlayerController PC)
{
    local LMSGame G;
    local Bot NewBot;

    G = LMSGame(Level.Game);
    if (G == None) { if (PC != None) PC.ClientMessage("LMSGame not found."); return; }

    G.AddBot();
    NewBot = FindNewestBot();
    if (NewBot != None) AssignBotToEnemyTeam(NewBot);

    if (PC != None) PC.ClientMessage("Bot added to Team 1.");
    Log("[MRC] Generic bot added");
}

function AddNamedStockBot(string BotName, PlayerController PC)
{
    local LMSGame G;
    local Bot NewBot;

    G = LMSGame(Level.Game);
    if (G == None) { if (PC != None) PC.ClientMessage("LMSGame not found."); return; }
    if (BotName == "") { if (PC != None) PC.ClientMessage("Usage: addnamedbot <name>"); return; }

    G.AddNamedBot(BotName);
    NewBot = FindNewestBot(BotName);
    if (NewBot != None) AssignBotToEnemyTeam(NewBot);

    if (PC != None) PC.ClientMessage("Named bot added: " $ BotName);
    Log("[MRC] Named bot added: " $ BotName);
}

function AddNamedBotWithCustomName(string BotName, string CustomName, PlayerController PC)
{
    local LMSGame G;
    local Controller C;
    local Bot B;

    G = LMSGame(Level.Game);
    if (G == None) { if (PC != None) PC.ClientMessage("LMSGame not found."); return; }
    if (BotName == "" || CustomName == "") { if (PC != None) PC.ClientMessage("Usage: addnamedbotcustom <stock> <custom>"); return; }

    G.AddNamedBot(BotName);

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        B = Bot(C);
        if (B != None && B.PlayerReplicationInfo != None &&
            (B.PlayerReplicationInfo.PlayerName ~= BotName))
        {
            B.PlayerReplicationInfo.SetPlayerName(CustomName);
            AssignBotToEnemyTeam(B);
            if (PC != None) PC.ClientMessage("Bot: " $ BotName $ " -> " $ CustomName);
            Log("[MRC] Bot renamed: " $ BotName $ " -> " $ CustomName);
            return;
        }
    }

    if (PC != None) PC.ClientMessage("Bot added, rename target not found.");
    Log("[MRC] rename target not found for " $ BotName);
}

function AddOneTimeBot(string BotName, PlayerController PC)
{
    local LMSGame G;
    local Bot NewBot;

    G = LMSGame(Level.Game);
    if (G == None) { if (PC != None) PC.ClientMessage("LMSGame not found."); return; }

    if (BotName == "")
    {
        G.AddBot();
        NewBot = FindNewestBot();
    }
    else
    {
        G.AddNamedBot(BotName);
        NewBot = FindNewestBot(BotName);
    }

    if (NewBot == None || NewBot.PlayerReplicationInfo == None)
    {
        if (PC != None) PC.ClientMessage("One-time bot spawn failed.");
        Log("[MRC] AddOneTimeBot: bot not found after spawn");
        return;
    }

    AssignBotToEnemyTeam(NewBot);

    if (PC != None) PC.ClientMessage("One-time bot spawned: " $ NewBot.PlayerReplicationInfo.PlayerName);
    Log("[MRC] One-time bot spawned: " $ NewBot.PlayerReplicationInfo.PlayerName);
}

function SetMyName(PlayerController PC, string NewName)
{
    if (PC == None || PC.PlayerReplicationInfo == None) return;
    if (NewName == "") { PC.ClientMessage("Usage: setmyname <name>"); return; }

    PC.PlayerReplicationInfo.SetPlayerName(NewName);
    PC.ClientMessage("Name set to: " $ NewName);
    Log("[MRC] Player name: " $ NewName);
}

function SetMyTeam(PlayerController PC, string TeamIndexStr)
{
    local LMSGame G;
    local int TeamIndex;

    G = LMSGame(Level.Game);
    if (G == None) { if (PC != None) PC.ClientMessage("LMSGame not found."); return; }

    TeamIndex = int(TeamIndexStr);
    if (TeamIndex != 0 && TeamIndex != 1) { if (PC != None) PC.ClientMessage("Usage: setteam <0|1>"); return; }

    G.ChangeTeam(PC, TeamIndex, false);
    if (PC != None) PC.ClientMessage("Team set to " $ TeamIndex);
    Log("[MRC] Player team set to " $ TeamIndex);
}

function ShowStatus(PlayerController PC)
{
    local string Msg;
    local LMSGame G;

    G = LMSGame(Level.Game);
    Msg = "GameClass=" $ String(Level.Game.Class);

    if (G != None)
        Msg = Msg $ " | Mode=LMSGame | HumanKills=" $ G.HumanKills;
    else
        Msg = Msg $ " | LMSGame not found";

    if (PC != None) PC.ClientMessage(Msg);
    Log("[MRC] " $ Msg);
}

function ExecuteExternalCommand(string FullCmd, PlayerController PC)
{
    local string Cmd;
    local string Arg;
    local string Arg2;

    FullCmd = TrimSpaces(FullCmd);
    Cmd     = GetCommandName(FullCmd);
    Arg     = GetCommandArg(FullCmd);
    Arg2    = GetSecondArg(FullCmd);

    Log("[MRC] Cmd='" $ Cmd $ "' Arg='" $ Arg $ "'");

    if (Cmd ~= "boost")             { ApplyBoostToPlayer(PC);                                      return; }
    if (Cmd ~= "stripme")           { StripWeaponsFromPlayer(PC);                                  return; }
    if (Cmd ~= "stripall")          { StripWeaponsFromAllPawns();                                  return; }
    if (Cmd ~= "addbot")            { AddGenericBot(PC);                                           return; }
    if (Cmd ~= "addnamedbot")       { AddNamedStockBot(Arg, PC);                                   return; }
    if (Cmd ~= "addnamedbotcustom") { AddNamedBotWithCustomName(GetFirstWord(Arg), Arg2, PC);      return; }
    if (Cmd ~= "onetimebot")        { AddOneTimeBot(Arg, PC);                                      return; }
    if (Cmd ~= "setmyname")         { SetMyName(PC, Arg);                                          return; }
    if (Cmd ~= "setteam")           { SetMyTeam(PC, Arg);                                          return; }
    if (Cmd ~= "status")            { ShowStatus(PC);                                              return; }

    if (PC != None) PC.ClientMessage("Unknown command: " $ FullCmd);
    Log("[MRC] Unknown command: " $ FullCmd);
}

function Mutate(string MutateString, PlayerController Sender)
{
    Log("[MRC] Mutate: " $ MutateString);
    ExecuteExternalCommand(MutateString, Sender);
    Super.Mutate(MutateString, Sender);
}

defaultproperties
{
    GroupName="StreamControl"
    FriendlyName="Remote Control (UDP) — LMS"
    Description="Control LMSGame via UDP commands"
}

