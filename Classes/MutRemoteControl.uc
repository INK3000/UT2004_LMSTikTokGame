class MutRemoteControl extends Mutator;

var RemoteUdpLink Udp;

function PostBeginPlay()
{
    Super.PostBeginPlay();

    Log("[MRC] PostBeginPlay");

    Udp = Spawn(class'RemoteUdpLink');
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

function PlayerController GetLocalPlayerController()
{
    local PlayerController PC;

    foreach DynamicActors(class'PlayerController', PC)
    {
        return PC;
    }

    return None;
}

function bool IsTeamGame()
{
    return xTeamGame(Level.Game) != None;
}

function bool IsInvasionGame()
{
    return Invasion(Level.Game) != None;
}

function bool IsDeathMatchBasedGame()
{
    return DeathMatch(Level.Game) != None;
}

function string TrimSpaces(string S)
{
    while (Len(S) > 0 && Left(S, 1) == " ")
    {
        S = Mid(S, 1);
    }

    while (Len(S) > 0 && Right(S, 1) == " ")
    {
        S = Left(S, Len(S) - 1);
    }

    return S;
}

function string GetCommandName(string FullCmd)
{
    local int SpacePos;

    FullCmd = TrimSpaces(FullCmd);
    SpacePos = InStr(FullCmd, " ");

    if (SpacePos == -1)
    {
        return FullCmd;
    }

    return Left(FullCmd, SpacePos);
}

function string GetCommandArg(string FullCmd)
{
    local int SpacePos;

    FullCmd = TrimSpaces(FullCmd);
    SpacePos = InStr(FullCmd, " ");

    if (SpacePos == -1)
    {
        return "";
    }

    return TrimSpaces(Mid(FullCmd, SpacePos + 1));
}

function string GetFirstWord(string S)
{
    local int SpacePos;

    S = TrimSpaces(S);
    SpacePos = InStr(S, " ");

    if (SpacePos == -1)
    {
        return S;
    }

    return Left(S, SpacePos);
}

function string GetSecondArg(string FullCmd)
{
    local int FirstSpacePos;
    local int SecondSpacePos;
    local string Rest;

    FullCmd = TrimSpaces(FullCmd);
    FirstSpacePos = InStr(FullCmd, " ");

    if (FirstSpacePos == -1)
    {
        return "";
    }

    Rest = TrimSpaces(Mid(FullCmd, FirstSpacePos + 1));
    SecondSpacePos = InStr(Rest, " ");

    if (SecondSpacePos == -1)
    {
        return "";
    }

    return TrimSpaces(Mid(Rest, SecondSpacePos + 1));
}

function int ParseSkillOrDefault(string S, int DefaultSkill)
{
    local int Parsed;

    if (S == "")
    {
        return DefaultSkill;
    }

    Parsed = int(S);

    if (Parsed < 0)
    {
        return 0;
    }

    if (Parsed > 7)
    {
        return 7;
    }

    return Parsed;
}

function ApplyBoostToPlayer(PlayerController PC)
{
    local xPawn P;

    if (PC == None || PC.Pawn == None)
    {
        Log("[MRC] ApplyBoostToPlayer: no player pawn");
        return;
    }

    P = xPawn(PC.Pawn);
    if (P == None)
    {
        Log("[MRC] ApplyBoostToPlayer: pawn is not xPawn");
        return;
    }

    P.Health = 300;
    P.HealthMax = 300;
    P.SuperHealthMax = 300;
    P.MaxMultiJump = 3;
    P.MultiJumpBoost = 100.0;

    PC.ClientMessage("Boost applied.");
    Log("[MRC] Boost applied to local player");
}

function StripWeaponsFromPlayer(PlayerController PC)
{
    local Inventory Inv;
    local Inventory NextInv;
    local Weapon W;

    if (PC == None || PC.Pawn == None)
    {
        Log("[MRC] StripWeaponsFromPlayer: no player pawn");
        return;
    }

    Inv = PC.Pawn.Inventory;
    while (Inv != None)
    {
        NextInv = Inv.Inventory;

        if (Weapon(Inv) != None)
        {
            PC.Pawn.DeleteInventory(Inv);
            Inv.Destroy();
        }

        Inv = NextInv;
    }

    PC.Pawn.Weapon = None;
    PC.Pawn.PendingWeapon = None;

    PC.Pawn.GiveWeapon("XWeapons.ShieldGun");

    W = Weapon(PC.Pawn.FindInventoryType(class'ShieldGun'));
    if (W != None)
    {
        PC.Pawn.Weapon = W;
    }

    PC.ClientMessage("All weapons removed. ShieldGun equipped.");
    Log("[MRC] Weapons stripped from local player");
    Log("[MRC] ShieldGun was equipped to local player");
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

                if (Weapon(Inv) != None)
                {
                    C.Pawn.DeleteInventory(Inv);
                    Inv.Destroy();
                }

                Inv = NextInv;
            }

            C.Pawn.Weapon = None;
            C.Pawn.PendingWeapon = None;
        }
    }

    Log("[MRC] Weapons stripped from all pawns");
}

// addbot             -> skill 1
// addbot 0           -> Novice
// addbot 7           -> Godlike
function AddGenericBot(PlayerController PC, optional int SkillLevel)
{
    local LMSGame TTG;
    local DeathMatch DM;

    TTG = LMSGame(Level.Game);
    if (TTG != None)
    {
        TTG.AddViewerBot(SkillLevel);

        if (PC != None)
        {
            PC.ClientMessage("Viewer bot added. Skill=" $ SkillLevel);
        }

        Log("[MRC] Viewer bot added via LMSGame. Skill=" $ SkillLevel);
        return;
    }

    DM = DeathMatch(Level.Game);
    if (DM == None)
    {
        if (PC != None)
        {
            PC.ClientMessage("Current game does not support stock AddBot.");
        }

        Log("[MRC] AddGenericBot: DeathMatch(Level.Game) is None");
        return;
    }

    DM.AddBot();

    if (PC != None)
    {
        PC.ClientMessage("Bot added. Fallback mode does not set per-bot skill.");
    }

    Log("[MRC] Generic bot added via DeathMatch fallback");
}

// addnamedbot Gorge      -> skill 1
// addnamedbot Gorge 5    -> Masterful
function AddNamedStockBot(string BotName, PlayerController PC, optional int SkillLevel)
{
    local LMSGame TTG;
    local DeathMatch DM;

    if (BotName == "")
    {
        if (PC != None)
        {
            PC.ClientMessage("Usage: addnamedbot <stock bot name> [skill 0..7]");
        }

        Log("[MRC] AddNamedStockBot: empty bot name");
        return;
    }

    TTG = LMSGame(Level.Game);
    if (TTG != None)
    {
        TTG.AddNamedViewerBot(BotName, SkillLevel);

        if (PC != None)
        {
            PC.ClientMessage("Named viewer bot requested: " $ BotName $ " Skill=" $ SkillLevel);
        }

        Log("[MRC] Named viewer bot requested via LMSGame: " $ BotName $ " Skill=" $ SkillLevel);
        return;
    }

    DM = DeathMatch(Level.Game);
    if (DM == None)
    {
        if (PC != None)
        {
            PC.ClientMessage("Current game does not support stock AddNamedBot.");
        }

        Log("[MRC] AddNamedStockBot: DeathMatch(Level.Game) is None");
        return;
    }

    DM.AddNamedBot(BotName);

    if (PC != None)
    {
        PC.ClientMessage("Named bot requested. Fallback mode does not set per-bot skill.");
    }

    Log("[MRC] Named bot requested via DeathMatch fallback: " $ BotName);
}

function AddNamedBotWithCustomName(string BotName, string CustomName, PlayerController PC, optional int SkillLevel)
{
    local LMSGame TTG;
    local DeathMatch DM;
    local Controller C;
    local Bot B;

    if (BotName == "" || CustomName == "")
    {
        if (PC != None)
        {
            PC.ClientMessage("Usage: addnamedbotcustom <stock bot name> <custom name> [skill 0..7]");
        }

        Log("[MRC] AddNamedBotWithCustomName: missing arguments");
        return;
    }

    TTG = LMSGame(Level.Game);
    if (TTG != None)
    {
        TTG.AddNamedViewerBotWithCustomName(BotName, CustomName, SkillLevel);

        if (PC != None)
        {
            PC.ClientMessage("Viewer bot added: " $ BotName $ " -> " $ CustomName $ " Skill=" $ SkillLevel);
        }

        Log("[MRC] Viewer bot added and renamed via LMSGame: " $ BotName $ " -> " $ CustomName $ " Skill=" $ SkillLevel);
        return;
    }

    DM = DeathMatch(Level.Game);
    if (DM == None)
    {
        if (PC != None)
        {
            PC.ClientMessage("Current game does not support stock AddNamedBot.");
        }

        Log("[MRC] AddNamedBotWithCustomName: DeathMatch(Level.Game) is None");
        return;
    }

    DM.AddNamedBot(BotName);

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        B = Bot(C);
        if (B != None && B.PlayerReplicationInfo != None)
        {
            if (B.PlayerReplicationInfo.PlayerName ~= BotName)
            {
                B.PlayerReplicationInfo.SetPlayerName(CustomName);

                if (PC != None)
                {
                    PC.ClientMessage("Bot added: " $ BotName $ " -> " $ CustomName);
                }

                Log("[MRC] Named bot added and renamed via fallback: " $ BotName $ " -> " $ CustomName);
                return;
            }
        }
    }

    if (PC != None)
    {
        PC.ClientMessage("Bot added, but rename target was not found.");
    }

    Log("[MRC] AddNamedBotWithCustomName: rename target not found for " $ BotName);
}

function AddOneTimeBot(string BotName, PlayerController PC, optional int SkillLevel)
{
    if (BotName == "")
    {
        AddGenericBot(PC, SkillLevel);
        return;
    }

    AddNamedStockBot(BotName, PC, SkillLevel);
}

function SetMyName(PlayerController PC, string NewName)
{
    if (PC == None || PC.PlayerReplicationInfo == None)
    {
        Log("[MRC] SetMyName: no PlayerReplicationInfo");
        return;
    }

    if (NewName == "")
    {
        PC.ClientMessage("Usage: setmyname <new name>");
        return;
    }

    PC.PlayerReplicationInfo.SetPlayerName(NewName);
    PC.ClientMessage("Your name is now: " $ NewName);
    Log("[MRC] Local player name changed to: " $ NewName);
}

function ShowStatus(PlayerController PC)
{
    local string Msg;
    local LMSGame TTG;

    TTG = LMSGame(Level.Game);
    if (TTG != None)
    {
        Msg = TTG.GetTikTokMatchStatus();
    }
    else
    {
        Msg = "GameClass=" $ String(Level.Game.Class);

        if (IsInvasionGame())
        {
            Msg = Msg $ " | Mode=Invasion";
        }
        else if (IsTeamGame())
        {
            Msg = Msg $ " | Mode=TeamGame";
        }
        else if (IsDeathMatchBasedGame())
        {
            Msg = Msg $ " | Mode=DeathMatchBased";
        }
        else
        {
            Msg = Msg $ " | Mode=Other";
        }
    }

    if (PC != None)
    {
        PC.ClientMessage(Msg);
    }

    Log("[MRC] " $ Msg);
}

function ExecuteExternalCommand(string FullCmd, PlayerController PC)
{
    local string Cmd;
    local string Arg;
    local string Arg2;
    local string StockBotName;
    local string CustomBotName;
    local string SkillArg;
    local int SkillLevel;

    FullCmd = TrimSpaces(FullCmd);
    Cmd = GetCommandName(FullCmd);
    Arg = GetCommandArg(FullCmd);
    Arg2 = GetSecondArg(FullCmd);

    Log("[MRC] ExecuteExternalCommand: Full='" $ FullCmd $ "' Cmd='" $ Cmd $ "' Arg='" $ Arg $ "'");

    if (Cmd ~= "boost")
    {
        ApplyBoostToPlayer(PC);
        return;
    }

    if (Cmd ~= "stripme")
    {
        StripWeaponsFromPlayer(PC);
        return;
    }

    if (Cmd ~= "stripall")
    {
        StripWeaponsFromAllPawns();
        return;
    }

    if (Cmd ~= "addbot")
    {
        SkillLevel = ParseSkillOrDefault(Arg, 1);
        AddGenericBot(PC, SkillLevel);
        return;
    }

    if (Cmd ~= "addnamedbot")
    {
        StockBotName = GetFirstWord(Arg);
        SkillArg = GetSecondArg(FullCmd);
        SkillLevel = ParseSkillOrDefault(SkillArg, 1);

        AddNamedStockBot(StockBotName, PC, SkillLevel);
        return;
    }

    if (Cmd ~= "addnamedbotcustom")
    {
        StockBotName = GetFirstWord(Arg);
        CustomBotName = Arg2;
        SkillLevel = ParseSkillOrDefault(GetSecondArg(Arg), 1);

        AddNamedBotWithCustomName(StockBotName, CustomBotName, PC, SkillLevel);
        return;
    }

    if (Cmd ~= "onetimebot")
    {
        if (Arg == "")
        {
            SkillLevel = 1;
        }
        else
        {
            SkillLevel = ParseSkillOrDefault(GetSecondArg(FullCmd), 1);
        }

        StockBotName = GetFirstWord(Arg);
        AddOneTimeBot(StockBotName, PC, SkillLevel);
        return;
    }

    if (Cmd ~= "setmyname")
    {
        SetMyName(PC, Arg);
        return;
    }

    if (Cmd ~= "status")
    {
        ShowStatus(PC);
        return;
    }

    if (PC != None)
    {
        PC.ClientMessage("Unknown command: " $ FullCmd);
    }

    Log("[MRC] Unknown command: " $ FullCmd);
}

function Mutate(string MutateString, PlayerController Sender)
{
    Log("[MRC] Mutate called: " $ MutateString);
    ExecuteExternalCommand(MutateString, Sender);
    Super.Mutate(MutateString, Sender);
}

defaultproperties
{
    GroupName="StreamControl"
    FriendlyName="05_Remote Control (UDP)"
    Description="Control game via UDP commands"
}
