class LMSGame extends xTeamGame;

// Team 0 = streamer
// Team 1 = viewers

var int StreamerTeamIndex;
var int ViewersTeamIndex;
var int StreamerKills;
var int StreamerDeaths;

// While this flag is true, newly added bots should be placed
// into the viewers team at creation time.
var bool bForceViewerBotTeam;

function InitGame(string Options, out string Error)
{
    Super.InitGame(Options, Error);

    StreamerTeamIndex = 0;
    ViewersTeamIndex = 1;
    bForceViewerBotTeam = false;

    Log("[LMS] InitGame");
}

function PostBeginPlay()
{
    Super.PostBeginPlay();
    Log("[LMS] PostBeginPlay");
}

event PostLogin(PlayerController NewPlayer)
{
    Super.PostLogin(NewPlayer);

    if (NewPlayer != None)
    {
        ChangeTeam(NewPlayer, StreamerTeamIndex, false);
        Log("[LMS] Human player moved to streamer team");
    }
}

// TeamGame uses GetBotTeam when assigning a team to a newly added bot.
// We override it so viewer bots are born directly into the viewers team.
function UnrealTeamInfo GetBotTeam(optional int TeamBots)
{
    if (bForceViewerBotTeam)
    {
        return Teams[ViewersTeamIndex];
    }

    return Super.GetBotTeam(TeamBots);
}

// Human player respawns normally.
// Bots respawn normally until they have died once.
// After death, viewer bots are marked bOutOfLives and blocked from respawn.
function RestartPlayer(Controller aPlayer)
{
    if (aPlayer == None)
    {
        return;
    }

    if (Bot(aPlayer) != None)
    {
        if (aPlayer.PlayerReplicationInfo != None &&
            aPlayer.PlayerReplicationInfo.bOutOfLives)
        {
            Log("[LMS] Bot blocked from respawn: "
                $ aPlayer.PlayerReplicationInfo.PlayerName);
            return;
        }
    }

    Super.RestartPlayer(aPlayer);
}

// When a bot dies, mark it OUT so RestartPlayer will refuse the next respawn.
function Killed(Controller Killer, Controller Killed, Pawn KilledPawn, class<DamageType> DamageType)
{
    Super.Killed(Killer, Killed, KilledPawn, DamageType);

    if (Bot(Killed) != None)
    {
        if (Killed.PlayerReplicationInfo != None)
        {
            Killed.PlayerReplicationInfo.bOutOfLives = true;
            Log("[LMS] Bot marked OUT: "
                $ Killed.PlayerReplicationInfo.PlayerName);
        }
    }
}

function ScoreKill(Controller Killer, Controller Other)
{
    Super.ScoreKill(Killer, Other);

    if (PlayerController(Killer) != None)
    {
        StreamerKills++;
    }

    if (PlayerController(Other) != None)
    {
        StreamerDeaths++;
    }
}

function bool CheckEndGame(PlayerReplicationInfo Winner, string Reason)
{
    return Super.CheckEndGame(Winner, Reason);
}

function PlayerController GetHumanPlayer()
{
    local Controller C;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        if (PlayerController(C) != None && Bot(C) == None)
        {
            return PlayerController(C);
        }
    }

    return None;
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
            if (BestAny == None ||
                B.PlayerReplicationInfo.PlayerID > BestAny.PlayerReplicationInfo.PlayerID)
            {
                BestAny = B;
            }

            if (PreferredName != "" &&
                (B.PlayerReplicationInfo.PlayerName ~= PreferredName))
            {
                if (BestMatch == None ||
                    B.PlayerReplicationInfo.PlayerID > BestMatch.PlayerReplicationInfo.PlayerID)
                {
                    BestMatch = B;
                }
            }
        }
    }

    if (BestMatch != None)
    {
        return BestMatch;
    }

    return BestAny;
}

function float NormalizeBotSkill(int SkillLevel)
{
    if (SkillLevel < 0)
    {
        return 0.0;
    }

    if (SkillLevel > 7)
    {
        return 7.0;
    }

    return float(SkillLevel);
}

function PrepareViewerBot(Bot B, optional int SkillLevel)
{
    if (B == None)
    {
        return;
    }

    if (B.PlayerReplicationInfo != None)
    {
        B.PlayerReplicationInfo.bOutOfLives = false;
        Log("[LMS] Viewer bot prepared: " $ B.PlayerReplicationInfo.PlayerName);
    }

    // Per-bot difficulty
    B.InitializeSkill(NormalizeBotSkill(SkillLevel));
    Log("[LMS] Viewer bot skill set to " $ NormalizeBotSkill(SkillLevel));
}

// Add a random viewer bot directly into the viewers team.
// Default skill = 1 (Average)
function AddViewerBot(optional int SkillLevel)
{
    local Bot B;

    bForceViewerBotTeam = true;
    AddBot();
    bForceViewerBotTeam = false;

    B = FindNewestBot();
    PrepareViewerBot(B, SkillLevel);
}

// Add a named stock viewer bot directly into the viewers team.
// Default skill = 1 (Average)
function AddNamedViewerBot(string BotName, optional int SkillLevel)
{
    local Bot B;

    if (BotName == "")
    {
        AddViewerBot(SkillLevel);
        return;
    }

    bForceViewerBotTeam = true;
    AddNamedBot(BotName);
    bForceViewerBotTeam = false;

    B = FindNewestBot(BotName);
    PrepareViewerBot(B, SkillLevel);
}

function AddNamedViewerBotWithCustomName(string BotName, string CustomName, optional int SkillLevel)
{
    local Bot B;

    if (BotName == "")
    {
        AddViewerBot(SkillLevel);
        return;
    }

    bForceViewerBotTeam = true;
    AddNamedBot(BotName);
    bForceViewerBotTeam = false;

    B = FindNewestBot(BotName);
    PrepareViewerBot(B, SkillLevel);

    if (B != None && B.PlayerReplicationInfo != None && CustomName != "")
    {
        B.PlayerReplicationInfo.SetPlayerName(CustomName);
        Log("[LMS] Named viewer bot renamed: "
            $ BotName $ " -> " $ CustomName);
    }
}

function string GetTikTokMatchStatus()
{
    return "Mode=LMSGame"
        $ " | Kills=" $ StreamerKills
        $ " | Deaths=" $ StreamerDeaths
        $ " | Time=" $ TimeLimit;
}

defaultproperties
{
    GameName="TikTok Team Survival"
    Description="Streamer vs viewer bots (no respawn for bots)"

    bScoreTeamKills=True
    bSpawnInTeamArea=True
    bBalanceTeams=False

    GoalScore=0
    TimeLimit=20
}
