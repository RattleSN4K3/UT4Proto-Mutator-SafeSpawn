class UT4SafeSpawnLink extends ReplicationInfo;

`if(`notdefined(FINAL_RELEASE))
	var bool bShowDebug;
`endif

//**********************************************************************************
// Workflow variables
//**********************************************************************************

var delegate<UT4SafeSpawn.OnUnProtectFire> UnProtectCallback;

//'''''''''''''''''''''''''
// Stored variables
//'''''''''''''''''''''''''

var UTPawn LastPawn;
var UTPawn OldPawnOwner;

//'''''''''''''''''''''''''
// Replication variables
//'''''''''''''''''''''''''

var repnotify UTPawn PawnOwner;
var GhostCollisionInfo ReplicatedOriginals;

//**********************************************************************************
// Replication
//**********************************************************************************

replication
{
	// replicate always on change even into demos
	if(bNetDirty && (Role == ROLE_Authority))
		PawnOwner, ReplicatedOriginals;
}

simulated event ReplicatedEvent(name VarName)
{
	Super.ReplicatedEvent(VarName);

	if (VarName == 'PawnOwner')
	{
		`Log(name$"::ReplicatedEvent - PawnOwner:"@PawnOwner,bShowDebug,'UT4SafeSpawn');
		if (OldPawnOwner != PawnOwner) // prevent update twice 
		{
			OldPawnOwner = PawnOwner;
			if (PawnOwner != none) LastPawn = PawnOwner;

			UpdateGhost(PawnOwner != none);
		}
	}
}

//**********************************************************************************
// Private funtions
//**********************************************************************************

simulated function UpdateGhost(bool bEnable)
{
	`Log(name$"::UpdateGhost - bEnable:"@bEnable,bShowDebug,'UT4SafeSpawn');
		
	SetGhost(bEnable);
	SetGhostEffect(bEnable);
}

//**********************************************************************************
// Public functions
//**********************************************************************************

/** ONLY CALLED SERVERSIDED */
function NotfiyNewPawn(UTPawn Other)
{
	PawnOwner = Other;

	// also apply ghost effect for ded servers (due to collision etc.)
	ReplicatedEvent('PawnOwner');
}

/** ONLY CALLED SERVERSIDED */
function NotfiyRemove()
{
	PawnOwner = none;

	// also apply ghost effect for ded servers (due to collision etc.)
	ReplicatedEvent('PawnOwner');
}

//**********************************************************************************
// Ghost protection funtions
//**********************************************************************************

simulated function SetGhost(bool bTurnOn)
{
	local GhostCollisionInfo bOriginals;
	
	if (bTurnOn)
	{
		class'UT4SafeSpawn'.static.SetGhostFor(LastPawn, true, bOriginals);

		if (Role == ROLE_Authority)
		{
			ReplicatedOriginals = bOriginals;
			ReplicatedOriginals.bSet = true;
		}
	}
	else if (ReplicatedOriginals.bSet)
	{
		`Log(name$"::SetGhost - Restore collision",bShowDebug,'UT4SafeSpawn');
		class'UT4SafeSpawn'.static.SetGhostFor(LastPawn, false, ReplicatedOriginals);
	}
}

simulated function SetGhostEffect(bool bTurnOn)
{
	class'UT4SafeSpawn'.static.SetGhostEffectFor(LastPawn, bTurnOn);
}

DefaultProperties
{
`if(`notdefined(FINAL_RELEASE))
	bShowDebug=false
`endif
}
