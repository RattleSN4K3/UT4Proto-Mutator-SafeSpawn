/** Only used for debugging */

class UT4SafeSpawnPawn extends UTPawn;

`if(`notdefined(FINAL_RELEASE))
	var() bool bShowDebug;
	var() bool bShowDebugFire;
`endif

//**********************************************************************************
// Workflow variables
//**********************************************************************************

//'''''''''''''''''''''''''
// Server variables
//'''''''''''''''''''''''''

var float GhostProtectionTime;
var bool bGhostAbortVehicleCheck;

var float InitialFireDelay;

var bool bCheckWeaponPutDown;
var float CheckWeaponPutDownTime;

//'''''''''''''''''''''''''
// Client variables
//'''''''''''''''''''''''''

var byte OldEnableGhost;
var UTPlayerController OldController;

//'''''''''''''''''''''''''
// Replication variables
//'''''''''''''''''''''''''

var repnotify bool bProtectionOver;
var bool bFireDelayRanout;

/** 0=not replicated; 255=off; else=on */
var repnotify byte EnableGhost;

//'''''''''''''''''''''''''
// Stored variables
//'''''''''''''''''''''''''

var bool PP_Scene_Changed;

var bool bCrosshairRemoved;
var array<CrosshairRestoreInfo> CrosshairRestore;

var bool bOriginalBehindView;

var GhostCollisionInfo StoredOriginals;

var bool bOriginalOverridePostProcessSettings;
var PostProcessSettings OriginalPostProcessSettingsOverride;

var float PawnCounterTime;

//**********************************************************************************
// Replication
//**********************************************************************************

replication
{
	if ( bNetDirty)
		bProtectionOver, bFireDelayRanout;
	if ( bNetDirty)
		EnableGhost;
}

simulated event ReplicatedEvent(name VarName)
{
	local bool bGhost;
	local UTPlayerController UTPC;
	//`Log(name$"::ReplicatedEvent - VarName:"@VarName,,'UT4SafeSpawn');

	super.ReplicatedEvent(VarName);

	if (VarName == 'bProtectionOver')
	{
		UpdateGhost(!bProtectionOver);
	}
	else
	if (VarName == 'EnableGhost')
	{
		if (EnableGhost != 0 && OldEnableGhost != EnableGhost)
		{
			OldEnableGhost = EnableGhost;
			bGhost = EnableGhost == 1;
			PawnCounterTime = WorldInfo.RealTimeSeconds;
			
			UTPC = OldController != none ? OldController : UTPlayerController(Controller);
			SetThirdPerson(UTPC, bGhost);
			SetPPEffects(UTPC, bGhost);

			// store PC
			OldController = UTPC;

			if (WorldInfo.NetMode == NM_Client || !bGhost)
			{
				UpdateGhost(bGhost);
				CheckCrosshair();
			}
		}
	}
}

//**********************************************************************************
// Inherited funtions
//**********************************************************************************

function PossessedBy(Controller C, bool bVehicleTransition)
{
	Super.PossessedBy(C, bVehicleTransition);
	ActivateSpawnProtection();
}

function AddDefaultInventory()
{
	super.AddDefaultInventory();

	if (!bProtectionOver && InvManager != none)
	{
		SetCrosshair(self, true);
		GiveInventory(self, true);

		bCheckWeaponPutDown = true;
		CheckWeaponPutDownTime = WorldInfo.RealTimeSeconds;
	}
}

// SetPuttingDownWeapon is the only way to interfere the weapon change
simulated function SetPuttingDownWeapon(bool bNowPuttingDownWeapon)
{
	if (Role == ROLE_Authority && !bProtectionOver && bNowPuttingDownWeapon)
	{
		if (bCheckWeaponPutDown && WorldInfo.RealTimeSeconds - CheckWeaponPutDownTime > 1.0)
		{
			DeactivateSpawnProtection();
		}
	}

	super.SetPuttingDownWeapon(bNowPuttingDownWeapon);
}

function GiveInventory(UTPawn Other, bool bAdd)
{
	local UT4SafeSpawnInventory Inv;
	if (bAdd)
	{
		inv = Spawn(class'UT4SafeSpawnInventoryStand');

		// Set the time first
		inv.TimeRemaining = GhostProtectionTime;

		// Add the inventory (which also updates TimeRemaining for clients)
		Other.InvManager.AddInventory(Inv, false);

		// setup (which sets time and replicates sound cue)
		inv.SetupInventory(Other, default.SpawnSound, GhostProtectionTime, OnInventoryTimout);
	}
	else
	{
		// destroy inventory if there's still one
		inv = UT4SafeSpawnInventory(FindInventoryType(class'UT4SafeSpawnInventoryStand'));
		if (inv != none && !inv.bDeleteMe && !inv.bPendingDelete)
		{
			inv.TimeExpired();
		}
	}
}

/* BecomeViewTarget
	Called by Camera when this actor becomes its ViewTarget */
simulated event BecomeViewTarget( PlayerController PC )
{
	Super.BecomeViewTarget(PC);

	if (!bProtectionOver && LocalPlayer(PC.Player) != None)
	{
		SetThirdPerson(UTPlayerController(PC), true);
	}
}

function bool Died(Controller Killer, class<DamageType> damageType, vector HitLocation)
{
	local bool ret;
	ret = super.Died(Killer, DamageType, HitLocation);

	if (!bProtectionOver)
	{
		UpdateGhost(false);
	}

	return ret;
}

simulated function TurnOffPawn()
{
	super.TurnOffPawn();

	// for clients to disable ghost effect if the ghost dies (somehow)
	if (!bProtectionOver)
	{
		UpdateGhost(false);
	}
}

//Note: as Pawn::DrawHUD is not called anymore when using UTPlayerController (see UTPlayerController::DrawHUD),
//      we have have to remove the crosshair differently

/////** Hook called from HUD actor. Gives access to HUD and Canvas */
////simulated function DrawHUD( HUD H )

/**
 * Pawn starts firing!
 * Called from PlayerController::StartFiring
 * Network: Local Player
 *
 * @param	FireModeNum		fire mode number
 */
simulated function StartFire(byte FireModeNum)
{
	if (!bProtectionOver /*&& Role < ROLE_Authority*/)
	{
		if (class'UT4SafeSpawn'.static.ShouldIgnoreInputForNow(PawnCounterTime, WorldInfo.RealTimeSeconds))
		{
			`Log(name$"::StartFire - IGNORE FireModeNum:"@FireModeNum,bShowDebug&&bShowDebugFire,'UT4SafeSpawn');
			class'UT4SafeSpawn'.static.PlayFireBlockedWarningFor(PlayerController(Controller));
		}
		else
		{
			`Log(name$"::StartFire - OFF FireModeNum:"@FireModeNum,bShowDebug&&bShowDebugFire,'UT4SafeSpawn');
			ServerSkipProtection();
		}

		return;
	}

	if (!bFireDelayRanout)
	{
		`Log(name$"::StartFire - IDLE FireModeNum:"@FireModeNum,bShowDebug&&bShowDebugFire,'UT4SafeSpawn');
		class'UT4SafeSpawn'.static.PlayFireBlockedWarningFor(PlayerController(Controller));
		return;
	}

	`Log(name$"::StartFire - ON FireModeNum:"@FireModeNum,bShowDebug&&bShowDebugFire,'UT4SafeSpawn');
	Super.StartFire(FireModeNum);
}

function bool StopFiring()
{
	if (!bProtectionOver)
	{
		`Log(name$"::StopFiring - OFF",bShowDebug&&bShowDebugFire,'UT4SafeSpawn');
		return false;
	}

	if (!bFireDelayRanout)
	{
		`Log(name$"::StartFire - IDLE",bShowDebug&&bShowDebugFire,'UT4SafeSpawn');
		return false;
	}

	`Log(name$"::StartFire - ON ",bShowDebug&&bShowDebugFire,'UT4SafeSpawn');
	return super.StopFiring();
}

function PlayTeleportEffect(bool bOut, bool bSound)
{
	// prevent the initial spawn effect when the protection is on

	if (bProtectionOver)
	{
		Super.PlayTeleportEffect( bOut, bSound );
	}
	else
	{
		super(Pawn).PlayTeleportEffect( bOut, bSound );
	}
}

function DeactivateSpawnProtection()
{
	super.DeactivateSpawnProtection();

	if (!bProtectionOver)
	{
		bProtectionOver = true;
		GiveInventory(self, false);

		// only play spawn effect if not suicided or killed
		if (Health > 0)
		{
			PlayTeleportEffect(false, true);
		}

		UpdateGhost(false);

		SetTimer(FMax(0.001, InitialFireDelay), false, 'StopBlockingFire');
	}
}

simulated event StartDriving(Vehicle V)
{
	bGhostAbortVehicleCheck = true;
	Super.StartDriving(V);
}

//**********************************************************************************
// Delegate Callbacks
//**********************************************************************************

function OnInventoryTimout(UTPawn P)
{
	DeactivateSpawnProtection();
}

//**********************************************************************************
// Exec
//**********************************************************************************

exec function SafeSpawn(optional string command)
{
	class'UT4SafeSpawn'.static.ProcessCommand(PlayerController(Controller), command);
}

//**********************************************************************************
// Server functions
//**********************************************************************************

reliable server function ServerSkipProtection()
{
	if (Role == ROLE_Authority && Controller != None)
	{
		DeactivateSpawnProtection();
	}
}

//**********************************************************************************
// Timer callbacks
//**********************************************************************************

function StopBlockingFire()
{
	// replicate the flag
	bFireDelayRanout = true;
}

//**********************************************************************************
// Private funtions
//**********************************************************************************

simulated function UpdateGhost(bool bEnable)
{
	`Log(name$"::UpdateGhost - bEnable:"@bEnable,bShowDebug,'UT4SafeSpawn');
		
	SetGhost(bEnable);
	SetGhostEffect(bEnable);
	SetGhostSound(bEnable);
	FixWeapons(bEnable);
	
	if (Role == ROLE_Authority)
	{
		EnableGhost = bEnable ? 1 : 255;
		if (WorldInfo.NetMode != NM_DedicatedServer) ReplicatedEvent('EnableGhost');

		if (!bEnable && !bGhostAbortVehicleCheck)
		{
			class'UT4SafeSpawn'.static.CheckSpawnKill(self);
		}
	}
}

simulated function FixWeapons(bool bEnable)
{
	local UTWeap_Enforcer Enf;
	
	if (!bEnable || Role == ROLE_Authority)
		return;
	
	if (InvManager == none)
	{
		// Manager not replicated yet, start timer to check for constantly
		SetTimer(0.1, false, GetFuncName());
		return;
	}

	ForEach InvManager.InventoryActors(class'UTWeap_Enforcer', Enf)
	{
		Enf.bLoaded = true;
	}
}

function ActivateSpawnProtection()
{
	if (!bProtectionOver)
	{
		UpdateGhost(true);
	}
}

//**********************************************************************************
// Ghost protection funtions
//**********************************************************************************

simulated function SetThirdPerson(UTPlayerController UTPC, bool bEnable)
{
	local byte TempOriginalBehindView;
	if (UTPC == none)
		return;

	TempOriginalBehindView = bOriginalBehindView ? 1 : 0;
	class'UT4SafeSpawn'.static.SetThirdPersonFor(UTPC, bEnable, TempOriginalBehindView);
	bOriginalBehindView = TempOriginalBehindView == 1;
}

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

simulated function SetGhost(bool bTurnOn)
{
	class'UT4SafeSpawn'.static.SetGhostFor(self, bTurnOn, StoredOriginals);
}

simulated function SetGhostEffect(bool bTurnOn)
{
	class'UT4SafeSpawn'.static.SetGhostEffectFor(self, bTurnOn);
}

simulated function SetGhostSound(bool bTurnOn)
{
	class'UT4SafeSpawn'.static.SetGhostSoundFor(self, bTurnOn);
}

simulated function CheckCrosshair()
{
	if (InvManager == none)
	{
		// Manager not replicated yet, start timer to check for constantly
		SetTimer(0.1, false, GetFuncName());
		return;
	}

	SetCrosshair(self, EnableGhost == 1);
}

simulated function bool SetCrosshair(UTPawn P, bool bRemoveCross)
{
	if (bCrosshairRemoved && bRemoveCross)
		return true;

	if (InvManager == none)
		return false;

	bCrosshairRemoved = true;
	class'UT4SafeSpawn'.static.SetCrosshairFor(InvManager, bRemoveCross, CrosshairRestore);

	return true;
}

DefaultProperties
{
`if(`notdefined(FINAL_RELEASE))
	bShowDebug=true
	bShowDebugFire=false
`endif
}
