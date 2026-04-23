class LMSGame extends xTeamGame;

var int HumanKills;

event PostLogin(PlayerController NewPlayer)
{
    Super.PostLogin(NewPlayer);
    ChangeTeam(NewPlayer, 0, false);
}

function byte PickTeam(byte Current, Controller C)
{
    if (C != None && C.IsA('AIController'))
        return 1;
    return 0;
}

function RestartPlayer(Controller aPlayer)
{
    local Bot B;

    B = Bot(aPlayer);
    if (B != None &&
        B.PlayerReplicationInfo != None &&
        B.PlayerReplicationInfo.Team != None &&
        B.PlayerReplicationInfo.Team.TeamIndex == 1 &&
        B.PlayerReplicationInfo.Deaths > 0)
    {
        return;
    }

    Super.RestartPlayer(aPlayer);
}

function Killed(Controller Killer, Controller KilledController, Pawn KilledPawn, class<DamageType> DamageType)
{
    Super.Killed(Killer, KilledController, KilledPawn, DamageType);

    if (Killer != None &&
        !Killer.IsA('AIController') &&
        KilledController != None &&
        KilledController.IsA('AIController'))
    {
        HumanKills++;
        if (PlayerController(Killer) != None)
            PlayerController(Killer).ClientMessage("Kills:" @ HumanKills);
    }

    if (KilledController != None && KilledController.IsA('AIController'))
    {
        KilledController.PlayerReplicationInfo.bOutOfLives = true;
        KilledController.Destroy();
    }
}

defaultproperties
{
    GameName="All vs Me (TikTok)"
    Description="All bots hunt the human player. Bots don't respawn. Score your kills!"
    HUDType="XInterface.HudBTeamDeathMatch"
    bForceRespawn=true
    MaxLives=0
    bBalanceTeams=false
    bPlayersBalanceTeams=false
    bSpawnInTeamArea=false
}

