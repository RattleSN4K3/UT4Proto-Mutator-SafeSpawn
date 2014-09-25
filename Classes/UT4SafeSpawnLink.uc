class UT4SafeSpawnLink extends ReplicationInfo;

//**********************************************************************************
// Workflow variables
//**********************************************************************************

var delegate<UT4SafeSpawn.OnUnProtectFire> UnProtectCallback;

//'''''''''''''''''''''''''
// Stored variables
//'''''''''''''''''''''''''

var UTPawn LastPawn;
var UTPawn OldPawnOwner;

var bool bOriginalCollideActors;
var bool bOriginalBlockActors;
var bool bOriginalPushesRigidBodies;
var bool bOriginalIgnoreForces;

//'''''''''''''''''''''''''
// Replication variables
//'''''''''''''''''''''''''

var repnotify UTPawn PawnOwner;

//**********************************************************************************
// Replication
//**********************************************************************************

replication
{
	// replicate always on change even into demos
	if(bNetDirty && (Role == ROLE_Authority))
		PawnOwner;
}

simulated event ReplicatedEvent(name VarName)
{
	Super.ReplicatedEvent(VarName);

	if (VarName == 'PawnOwner')
	{
		`Log(name$"::ReplicatedEvent - PawnOwner:"@PawnOwner,,'UT4SafeSpawn');
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
	`Log(name$"::UpdateGhost - bEnable:"@bEnable,,'UT4SafeSpawn');
		
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
	local SetGhostForOut bOriginals;
	
	bOriginals.bOriginalCollideActors = bOriginalCollideActors;
	bOriginals.bOriginalBlockActors = bOriginalBlockActors;
	bOriginals.bOriginalPushesRigidBodies = bOriginalPushesRigidBodies;
	bOriginals.bOriginalIgnoreForces = bOriginalIgnoreForces;

	class'UT4SafeSpawn'.static.SetGhostFor(LastPawn, bTurnOn, bOriginals);

	bOriginalCollideActors = bOriginals.bOriginalCollideActors;
	bOriginalBlockActors = bOriginals.bOriginalBlockActors;
	bOriginalPushesRigidBodies = bOriginals.bOriginalPushesRigidBodies;
	bOriginalIgnoreForces = bOriginals.bOriginalIgnoreForces;
}

simulated function SetGhostEffect(bool bTurnOn)
{
	class'UT4SafeSpawn'.static.SetGhostEffectFor(LastPawn, bTurnOn);
}

DefaultProperties
{
}
