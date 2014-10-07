class UT4SafeSpawnRepInfo extends ReplicationInfo;

`if(`notdefined(FINAL_RELEASE))
	var bool bShowDebug;
	var bool bShowDebugTouch;
`endif

//**********************************************************************************
// Workflow variables
//**********************************************************************************

var delegate<UT4SafeSpawn.OnUnProtectFire> UnProtectCallback;

var bool PP_Scene_Changed;

var bool bFireCalled;

//'''''''''''''''''''''''''
// Stored variables
//'''''''''''''''''''''''''

var UT4SafeSpawnInteraction ClientInteraction;
var UTPawn OldPawn;

var bool bOriginalBehindView;

var bool bOriginalCollideActors;
var bool bOriginalBlockActors;
var bool bOriginalPushesRigidBodies;
var bool bOriginalIgnoreForces;

var bool bOriginalOverridePostProcessSettings;
var PostProcessSettings OriginalPostProcessSettingsOverride;

var float PawnCounterTime;

//'''''''''''''''''''''''''
// Replication variables
//'''''''''''''''''''''''''

var bool bFireReceived;

//'''''''''''''''''''''''''
// Replication variables
//'''''''''''''''''''''''''

/** Used for proper replication with client/server functions */
var repnotify UTPlayerController PlayerOwner;

var repnotify UTPawn PawnCounter;

var float InitialFireDelay;

//**********************************************************************************
// Replication
//**********************************************************************************

replication
{
	if(bNetInitial && (Role == ROLE_Authority))
		PlayerOwner;

	if(bNetOwner && bNetDirty)
		PawnCounter, InitialFireDelay;
}

simulated event ReplicatedEvent(name VarName)
{
	`Log(name$"::ReplicatedEvent - VarName:"@VarName,bShowDebug,'UT4SafeSpawn');
			
	super.ReplicatedEvent(VarName);

	if (VarName == 'PlayerOwner')
	{
		SetOwner(PlayerOwner);
		SetupInteraction(PlayerOwner, true);
	}
	else if (VarName == 'PawnCounter')
	{
		if (PawnCounter != none && PawnCounter != OldPawn &&
			
			// check if we are watching our own Pawn
			PlayerOwner.ViewTarget == PawnCounter)
		{
			`Log(name$"::ReplicatedEvent - PawnCounter:"@PawnCounter,bShowDebug,'UT4SafeSpawn');
			OldPawn = PawnCounter;
			PawnCounterTime = WorldInfo.RealTimeSeconds;

			UpdateGhostFor(PawnCounter, true);
		}
	}
}

//**********************************************************************************
// Init functions
//**********************************************************************************

/** CALLED SERVERSIDED ONLY */
function InitialSetup(UTPlayerController PC, delegate<UT4SafeSpawn.OnUnProtectFire> UnProtectDelegate, float InInitialFireDelay)
{
	PlayerOwner = PC;
	UnProtectCallback = UnProtectDelegate;
	InitialFireDelay = InInitialFireDelay;

	// for listen servers
	if (WorldInfo.NetMode != NM_DedicatedServer && bLocallyOwned())
	{
		ReplicatedEvent('PlayerOwner');
	}
}

simulated function SetupInteraction(PlayerController PC, bool bAdd)
{
	local int i;
	local LocalPlayer LP;

	// unable to find any PC, abort
	if (PC == none)
		return;

	LP = LocalPlayer(PC.Player);
	if (LP == none) // PC is not bound to a LocalPlayer, abort
		return;

	for (i=0; i<PC.Interactions.Length;i++)
	{
		if (PC.Interactions[i].Class == class'UT4SafeSpawnInteraction')
		{
			ClientInteraction = UT4SafeSpawnInteraction(PC.Interactions[i]);
			break;
		}
	}

	if (ClientInteraction != none && bAdd)
	{
		`Log(name$"::SetupInteraction - Already setup. Only update",bShowDebug,'UT4SafeSpawn');
		ClientInteraction.Update(OnFireInput);
		return;
	}

	if (bAdd)
	{
		`Log(name$"::SetupInteraction - Add new interaction",bShowDebug,'UT4SafeSpawn');
		ClientInteraction = new class'UT4SafeSpawnInteraction';
		if (ClientInteraction != none)
		{
			ClientInteraction.Setup(PC, LP, OnFireInput);
			PC.Interactions.InsertItem(0, ClientInteraction);
		}
	}
	else
	{
		`Log(name$"::SetupInteraction - Remove interaction",bShowDebug,'UT4SafeSpawn');
		PC.Interactions.RemoveItem(ClientInteraction);
		ClientInteraction.Kill();
		ClientInteraction = none;
	}
}

//**********************************************************************************
// Delegate Callbacks
//**********************************************************************************

simulated function OnFireInput()
{
	if (bFireCalled || class'UT4SafeSpawn'.static.ShouldIgnoreInputForNow(PawnCounterTime, WorldInfo.RealTimeSeconds))
	{
		class'UT4SafeSpawn'.static.PlayFireBlockedWarningFor(PlayerOwner);
		return;
	}

	ServerFired();
	bFireCalled = true;
}

//**********************************************************************************
// Client funtions
//**********************************************************************************

/** called on the owning client just before the pickup is dropped or destroyed */
client reliable function ClientSetActive()
{
	`Log(name$"::ClientSetActive",bShowDebug,'UT4SafeSpawn');
	UpdateGhostFor(OldPawn, false);
}

client reliable function ClientUnblockInput()
{
	`Log(name$"::ClientUnblockInput",bShowDebug,'UT4SafeSpawn');
	bFireCalled = false;
	ClientInteraction.BlockInput(false);
}

//**********************************************************************************
// Server funtions
//**********************************************************************************

/** called on the owning client just before the pickup is dropped or destroyed */
server reliable function ServerFired()
{
	local delegate<UT4SafeSpawn.OnUnProtectFire> UnProtectDelegate;

	`Log(name$"::ServerFired",bShowDebug,'UT4SafeSpawn');
	if (!bFireReceived && UnProtectCallback != none)
	{
		bFireReceived = true;

		UnProtectDelegate = UnProtectCallback;
		UnProtectDelegate(PlayerOwner, self);
	}
}

//**********************************************************************************
// Public funtions
//**********************************************************************************

/** CALLED SERVERSIDED ONLY */
function NotifyRespawned(UTPawn Other)
{
	PawnCounter = Other;

	bFireReceived = false;
	ClearTimer('StopBlockingFire');

	// for listen servers
	if (WorldInfo.NetMode != NM_DedicatedServer && bLocallyOwned())
	{
		ReplicatedEvent('PawnCounter');
	}
}

/** CALLED SERVERSIDED ONLY */
function NotifyActive()
{
	`Log(name$"::NotifyActive",bShowDebug,'UT4SafeSpawn');
	ClientSetActive();

	SetTimer(FMax(0.001, InitialFireDelay), false, 'StopBlockingFire');
}

//**********************************************************************************
// Timed funtions
//**********************************************************************************

function StopBlockingFire()
{
	ClientUnblockInput();
}
 
//**********************************************************************************
// Private funtions
//**********************************************************************************

simulated function UpdateGhostFor(UTPawn P, bool bEnable)
{
	SetThirdPerson(PlayerOwner, bEnable);
	SetPPEffects(PlayerOwner, bEnable);

	if (bEnable)
	{
		ClientInteraction.BlockInput(true);
	}
}

//**********************************************************************************
// Ghost protection funtions
//**********************************************************************************

/** applies and removes any post processing effects while holding this item */
simulated function SetPPEffects(UTPlayerController PC, bool bAdd)
{
	local byte iOriginalOverridePostProcessSettings, iPP_Scene_Changed;
	if (PC == None)
		return;

	iPP_Scene_Changed = PP_Scene_Changed ? 1 : 0;
	iOriginalOverridePostProcessSettings = bOriginalOverridePostProcessSettings ? 1 : 0;
	class'UT4SafeSpawn'.static.SetPPEffectsFor(PC, bAdd, iOriginalOverridePostProcessSettings, OriginalPostProcessSettingsOverride, iPP_Scene_Changed);
	PP_Scene_Changed = iPP_Scene_Changed == 1;
	bOriginalOverridePostProcessSettings = iOriginalOverridePostProcessSettings == 1;
}

simulated function SetGhost(UTPawn P, bool bTurnOn)
{
	local GhostCollisionInfo bOriginals;
	if (P == none)
		return;
	
	bOriginals.bOriginalCollideActors = bOriginalCollideActors;
	bOriginals.bOriginalBlockActors = bOriginalBlockActors;
	bOriginals.bOriginalPushesRigidBodies = bOriginalPushesRigidBodies;
	bOriginals.bOriginalIgnoreForces = bOriginalIgnoreForces;

	class'UT4SafeSpawn'.static.SetGhostFor(P, bTurnOn, bOriginals);

	bOriginalCollideActors = bOriginals.bOriginalCollideActors;
	bOriginalBlockActors = bOriginals.bOriginalBlockActors;
	bOriginalPushesRigidBodies = bOriginals.bOriginalPushesRigidBodies;
	bOriginalIgnoreForces = bOriginals.bOriginalIgnoreForces;
}

simulated function SetGhostEffect(UTPawn P, bool bTurnOn)
{
	if (P != none)
	{
		class'UT4SafeSpawn'.static.SetGhostEffectFor(P, bTurnOn);
	}
}

simulated function SetThirdPerson(UTPlayerController PC, bool bEnable)
{
	local byte TempOriginalBehindView;
	if (PC == none)
		return;

	TempOriginalBehindView = bOriginalBehindView ? 1 : 0;
	class'UT4SafeSpawn'.static.SetThirdPersonFor(PC, bEnable, TempOriginalBehindView);
	bOriginalBehindView = TempOriginalBehindView == 1;
}

//**********************************************************************************
// Utils
//**********************************************************************************

// For use with listen servers
final function bool bLocallyOwned()
{
	if (WorldInfo.NetMode != NM_DedicatedServer && Owner != none && LocalPlayer(PlayerController(Owner).Player) != none)
		return True;

	return False;
}

DefaultProperties
{
`if(`notdefined(FINAL_RELEASE))
	bShowDebug=true
	bShowDebugTouch=true
`endif

	// Inherited
	bOnlyRelevantToOwner=true
	bAlwaysRelevant=false

	NetPriority=1.1
}
