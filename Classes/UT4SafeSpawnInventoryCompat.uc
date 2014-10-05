class UT4SafeSpawnInventoryCompat extends UT4SafeSpawnInventory;

//**********************************************************************************
// Workflow variables
//**********************************************************************************

//'''''''''''''''''''''''''
// Server variables
//'''''''''''''''''''''''''

var bool bWaitForLanded;
var float WaitForLandedTime;

//'''''''''''''''''''''''''
// Client variables
//'''''''''''''''''''''''''

var array<CrosshairRestoreInfo> CrosshairRestore;
var array<WeaponRestoreInfo> WeaponRestore;

var bool bOriginalNoCrosshair;

//**********************************************************************************
// Inherited funtions
//**********************************************************************************

/**
 * OwnerEvent:
 * Used to inform inventory when owner event occurs (for example jumping or weapon change)
 * set bReceiveOwnerEvents=true to receive events.
 */
function OwnerEvent(name EventName)
{
	super.OwnerEvent(EventName);
	switch (EventName)
	{
		case 'Landed':
			WaitForLandedTime = WorldInfo.TimeSeconds;
			break;

		case 'ChangedWeapon':
			if (UTInventoryManager(Instigator.InvManager) != none && UTInventoryManager(Instigator.InvManager).PreviousWeapon == none)
			{
				// bugs for clients as the event gets called immediately
				// so we need to abort this call once for the weapon change on spawn (where the previous weapon is none)
				break;
			}
			else if (bWaitForLanded || WaitForLandedTime == WorldInfo.TimeSeconds)
			{
				bWaitForLanded = false;
				break;
			}

			// fall through

		case 'FiredWeapon':
			TimeExpired();
			break;
	}
}

function GivenTo(Pawn NewOwner, bool bDoNotActivate)
{
	Super.GivenTo(NewOwner, bDoNotActivate);
	class'UT4SafeSpawn'.static.SetGhostSoundFor(UTPawn(NewOwner), true);
}

function ItemRemovedFromInvManager()
{
	super.ItemRemovedFromInvManager();
	class'UT4SafeSpawn'.static.SetGhostSoundFor(UTPawn(Instigator), false);

	// for listen server support
	ClientSetup(UTPawn(Owner), true);
}

//**********************************************************************************
// Private funtions
//**********************************************************************************

/** adds or removes our bonus from the given pawn */
simulated function ClientSetup(UTPawn P, bool bRemove)
{
	if (( !bRemove || bAlreadySetup ) && ( Role < ROLE_Authority || WorldInfo.NetMode != NM_DedicatedServer ))
	{
		bAlreadySetup = true;
		if (bLocallyOwned())
		{
			SetCrosshair(P, !bRemove);
			//BlockWeapons(P, !bRemove);

			if (!bRemove)
			{
				FixWeapons(P);
			}
		}
	}
}

simulated function SetCrosshair(UTPawn P, bool bRemoveCross)
{
	local InventoryManager TempInvManager;

	TempInvManager = P.InvManager != none ? P.InvManager : InvSetup.InvManager;
	if (TempInvManager != none)
	{
		class'UT4SafeSpawn'.static.SetCrosshairFor(TempInvManager, bRemoveCross, CrosshairRestore);
	}
}

simulated function BlockWeapons(Pawn P, bool bBlock)
{
	local Weapon Weap;
	local int i, index;

	foreach P.InvManager.InventoryActors(class'Weapon', Weap)
	{
		if (bBlock)
		{
			index = WeaponRestore.Length;
			WeaponRestore.Add(1);
			WeaponRestore[index].Weap = Weap;
			WeaponRestore[index].FiringStatesArray = Weap.FiringStatesArray;
			WeaponRestore[index].WeaponFireTypes = Weap.WeaponFireTypes;

			for (i=0; i<Weap.WeaponFireTypes.Length; i++)
			{
				Weap.WeaponFireTypes[i] = EWFT_None;
			}

			for (i=0; i<Weap.FiringStatesArray.Length; i++)
			{
				Weap.FiringStatesArray[i] = '';
			}
		}
		else
		{
			index = WeaponRestore.Find('Weap', Weap);
			if (index != INDEX_NONE)
			{
				Weap.FiringStatesArray = WeaponRestore[index].FiringStatesArray;
				Weap.WeaponFireTypes = WeaponRestore[index].WeaponFireTypes;
			}
		}
	}
}

simulated function FixWeapons(UTPawn P)
{
	local InventoryManager TempInvManager;
	local UTWeap_Enforcer Enf;
	
	if (P == none)
		return;

	TempInvManager = P.InvManager != none ? P.InvManager : InvSetup.InvManager;
	if (TempInvManager == none)
		return;

	ForEach TempInvManager.InventoryActors(class'UTWeap_Enforcer', Enf)
	{
		Enf.bLoaded = true;
	}
}

DefaultProperties
{
}
