class UT4SafeSpawnInventory extends UTTimedPowerup
	config(UT4Proto_MutatorSafeSpawn)
	abstract;

`if(`notdefined(FINAL_RELEASE))
	var() bool bShowDebug;
	var() bool bShowDebugTouch;
	var() bool bShowDebugDeny;
`endif

//**********************************************************************************
// Structs
//**********************************************************************************

struct SetupInfo
{
	var UTPawn InvOwner;
	var InventoryManager InvManager;

	/** Sound played when the time nearly running out and the player is about to spawn */
	var SoundCue WarningSound;

	var float GhostProtectionTime;
};

//**********************************************************************************
// Workflow variables
//**********************************************************************************

//'''''''''''''''''''''''''
// Replication variables
//'''''''''''''''''''''''''

///** Used for properly replicate the owner (ClientGivenTo results into None for the owner somtimes) */
//var repnotify Pawn InvOwner;

var repnotify SetupInfo InvSetup;

//'''''''''''''''''''''''''
// Server variables
//'''''''''''''''''''''''''

var delegate<UT4SafeSpawn.OnUnProtectPickup> UnProtectCallback;

//'''''''''''''''''''''''''
// Client variables
//'''''''''''''''''''''''''

var bool bAlreadySetup;
var bool bPlayWarningOnce;

// -~= Visuals  ~=-

var float BarTimUsed;

var float FullPulseTime;
var bool bPulseBar;
var int PulseBarScaler;

//'''''''''''''''''''''''''
// Localization variables
//'''''''''''''''''''''''''

var localized string ProtectionActiveMessage;  	        // Ghost protection currently active
var localized string ProtectionActiveMessageWithTime;  	// Ghost protection currently active (`ts)
var localized string FireToUnProtectMessage;  	        // Press [FIRE] to remove ghost protection
var localized string TimeStringMessage;			        // `ts

//'''''''''''''''''''''''''
// Config variables
//'''''''''''''''''''''''''

var() globalconfig bool ShowTime;
var() globalconfig float BarTimeThreshold;
var() globalconfig bool WarningSound;

//**********************************************************************************
// Replication
//**********************************************************************************

replication
{
	// Things the server should send to the owning client.
	//if ( (Role==ROLE_Authority) && bNetDirty && bNetOwner )
	//	InvOwner;

	// only once to the owning client
	if ( (Role==ROLE_Authority) && bNetInitial && bNetOwner )
		InvSetup;
}

simulated event ReplicatedEvent(name VarName)
{
	//`Log(name$"::ReplicatedEvent - VarName:"@VarName,,'UT4SafeSpawn');
			
	super.ReplicatedEvent(VarName);

	//if (VarName == 'InvOwner')
	//{
	//	if (InvOwner != none)
	//	{
	//		SetOwner(InvOwner);
	//		ClientGivenTo(InvOwner, false);
	//	}
	//}
	//else
	if (VarName == 'InvSetup')
	{
		if (InvSetup.InvOwner != none && InvSetup.InvManager != none)
		{
			SetOwner(InvSetup.InvOwner);

			BarTimUsed = FMin(InvSetup.GhostProtectionTime, BarTimeThreshold);

			if (WarningSound)
			{
				// play in next tick (mainly for listen server support)
				SetTimer(0.001, false, 'ConditionalPlayWarning');
			}

			ClientSetup(InvSetup.InvOwner, false);
		}
	}
}

//**********************************************************************************
// Inherited funtions
//**********************************************************************************


/** called when TimeRemaining reaches zero */
event TimeExpired()
{
	local delegate<UT4SafeSpawn.OnUnProtectPickup> UnProtectDelegate;

	// store callback locally as it will be de-referenced in the Destroyed method
	UnProtectDelegate = UnProtectCallback;

	super.TimeExpired();

	// notify main module
	if (UnProtectDelegate != none)
	{
		UnProtectDelegate(UTPawn(Instigator));
	}
}

simulated event Destroyed()
{
	local UTPawn P;
	//local delegate<UT4SafeSpawn.OnUnProtectPickup> UnProtectDelegate;

	P = UTPawn(Owner);
	if (P == none) P = InvSetup.InvOwner;

	if (P != none)
	{
		if (Role < ROLE_Authority)
		{
			ClientSetup(P, true);
		}
		else
		{
			//// notify main module
			//if (UnProtectCallback != none)
			//{
			//	UnProtectDelegate = UnProtectCallback;
			//	UnProtectDelegate(UTPawn(Instigator));
			//}

			// clear reference
			UnProtectCallback = none;

		//	// notify server
		//	if (UnProtectCallback != none && TimeRemaining <= 0)
		//	{
		//		UnProtectDelegate = UnProtectCallback;
		//		UnProtectDelegate(UTPawn(Instigator));
		//	}
		}
	}

	Super.Destroyed();
}

function GivenTo(Pawn NewOwner, bool bDoNotActivate)
{
	local UTPawn P;

	Super.GivenTo(NewOwner, bDoNotActivate);

	P = UTPawn(NewOwner);
	if (P != None)
	{
		// we disabled the collision, we need to check whether
		// we are trying to	pick something up differently
		AddCollisionCheck(true);
	}
}

// When touched by an actor.
event Touch( Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal )
{
	`Log(name$"::Touch - Other:"@Other$" - OtherComp:"@OtherComp,bShowDebug&&bShowDebugTouch,'UT4SafeSpawn');

	if (Instigator == Other)
		return;

	// Allow picking up items
	if (PickupFactory(Other) != none || DroppedPickup(Other) != none || (UTCarriedObject(Other) != none && UTCarriedObject(Other).ValidHolder(Owner)))
	{
		Other.Touch(Owner, Owner.CollisionComponent, HitLocation, -HitNormal);
	}

	// Allow other actors (like Jumppads) as they all react on the Touch event
	if (UTJumpPad(Other) != none || 
		Objective(Other) != none ||
		PlayerStart(Other) != none ||
		Teleporter(Other) != none ||
		UTOnslaughtNodeTeleporter(Other) != none ||
		UTVehicleFactory(Other) != none
		)
	{
		Other.Touch(Owner, Owner.CollisionComponent, HitLocation, -HitNormal);
	}
}

// Removed applying any PP effect fot this inventory as the PPs are done in the interaction code (as it is persistent)
simulated function AdjustPPEffects(Pawn P, bool bRemove);

simulated function DisplayPowerup(Canvas Canvas, UTHud HUD, float ResolutionScale,out float YPos)
{
	local string str, timestring;
	local float CenterX/*, CenterY*/;
	local float Width, Top;
	local float SpaceX, SpaceY;
	local float Perc, Scaler, Pulser;
	local float alpha;
	local Color GhostColor;

	if (TimeRemaining <= 0 || InvSetup.GhostProtectionTime <= 0.0)
		return;

	Pulser = 1.0;
	alpha = 127;

	CenterX = Canvas.SizeX * 0.5;
	//CenterY = Canvas.SizeY * 0.5;

	Width = Canvas.SizeY * 0.4;
	Top = Canvas.SizeY * 0.62;
	
	if (HUD.UTOwnerPRI != none && !HUD.UTOwnerPRI.bOnlySpectator)
	{
		HUD.DisplayHUDMessage(FireToUnProtectMessage, 0.05, 0.15);
	}

	// draw hint

	// set new text rendering for hint
	Canvas.Font = HUD.GetFontSizeIndex(2);

	if (ShowTime)
		str = ProtectionActiveMessage;
	else
	{
		str = Repl(ProtectionActiveMessageWithTime, "`t", int(InvSetup.GhostProtectionTime));
	}
	Canvas.TextSize(str, SpaceX, SpaceY);

	// first draw drop shadow string
	Canvas.DrawColor = HUD.BlackColor;
	Canvas.SetPos(CenterX - (0.5*SpaceX), Top);
	Canvas.CurX += 2;Canvas.CurY += 2;
	Canvas.DrawTextClipped(str, true);

	// now draw string with normal color
	Canvas.DrawColor = HUD.LightGoldColor;
	Canvas.SetPos(CenterX - (0.5*SpaceX), Top);
	Canvas.DrawTextClipped(str, true);

	// only draw the bar for the remaining time specified by BarTimeThreshold
	if (TimeRemaining > BarTimeThreshold)
	{
		if (ShowTime)
		{
			timestring = class'UTHUD'.static.FormatTime(TimeRemaining+1);
			Canvas.TextSize(timestring, SpaceX, Scaler);

			// first draw drop shadow string
			Canvas.DrawColor = HUD.BlackColor;
			Canvas.SetPos(CenterX - (0.5*SpaceX), Top+SpaceY);
			Canvas.CurX += 2;Canvas.CurY += 2;
			Canvas.DrawTextClipped(timestring, true);

			// now draw string with normal color
			Canvas.DrawColor = HUD.WhiteColor;
			Canvas.DrawColor = HUD.WhiteColor;
			Canvas.SetPos(CenterX - (0.5*SpaceX), Top+SpaceY);
			Canvas.DrawTextClipped(timestring, true);
		}

		return;
	}

	// adjust Top for Bar position
	Top += SpaceY;

	// calculate the width for the fading bar
	Perc = FClamp( TimeRemaining / BarTimeThreshold, 0.0, 1.0);

	Scaler = 0.6;
	if (Perc >= 0.6)
		GhostColor = MakeColor(0,255,0);
	else if (Perc >= 0.25)
	{
		Scaler = 0.1;
		GhostColor = MakeColor(255,255,0);
	}
	else
	{
		GhostColor = MakeColor(255,0,0);
		Perc = 0.25+0.75*(1-(Perc/0.25));
		Scaler = -1.0;
	}
	Scaler = FClamp(1-Perc-Scaler, 0.0, 1.0);
	
	GhostColor.A = alpha;

	// calc bar height
	Canvas.Font = class'Engine'.static.GetTinyFont();
	Canvas.TextSize("[]", SpaceX, SpaceY);

	// Draw background
	Canvas.SetDrawColor(127,127,127,127);
	if (bPulseBar) Canvas.DrawColor.A = 127*Pulser;
	Canvas.SetPos(CenterX - (0.5*Width), Top);
	Canvas.DrawRect(Width, SpaceY);

	// Draw borders
	Canvas.SetDrawColor(255,255,255,255);
	Canvas.SetPos(CenterX - (0.5*Width)-2, Top);
	Canvas.DrawRect(2, SpaceY);
	Canvas.SetPos(CenterX + (0.5*Width), Top);
	Canvas.DrawRect(2, SpaceY);

	// draw bar
	Scaler = FMax(1, Scaler*SpaceY);
	Canvas.DrawColor = GhostColor;
	Canvas.SetPos(CenterX - (0.5*Perc*Width), Top + 0.5*(SpaceY-Scaler));
	Canvas.DrawRect(Perc*Width, Scaler);

	// render time
	Canvas.TextSize(TimeStringMessage, SpaceX, SpaceY);
	Canvas.SetPos(CenterX + (0.5*Width) + 2*SpaceX, Top /*- SpaceY*0.15*/);
	Canvas.DrawTextRA(Repl(TimeStringMessage, "`t", int(TimeRemaining+1)));
}

//**********************************************************************************
// Public funtions
//**********************************************************************************

function SetupInventory(UTPawn Other, SoundCue InWarningSound, float InGhostProtectionTime, delegate<UT4SafeSpawn.OnUnProtectPickup> UnProtectDelegate)
{
	local SetupInfo LocalSetup;

	TimeRemaining = InGhostProtectionTime;
	UnProtectCallback = UnProtectDelegate;
	
	// replicate setup variables to client
	LocalSetup.GhostProtectionTime = InGhostProtectionTime;
	LocalSetup.WarningSound = InWarningSound;
	LocalSetup.InvOwner = Other;
	LocalSetup.InvManager = Other.InvManager;

	InvSetup = LocalSetup;
	if (WorldInfo.NetMode != NM_DedicatedServer && bLocallyOwned())
	{
		ReplicatedEvent('InvSetup');
	}
}

//**********************************************************************************
// Private funtions
//**********************************************************************************

/** Serversided only */
function AddCollisionCheck(bool add)
{
	local PrimitiveComponent OrgComp, Comp;
	 
	if (add)
	{
		OrgComp = Owner.CollisionComponent;
		Comp = new(self) OrgComp.Class(OrgComp);
		AttachComponent(Comp);
		Comp.SetActorCollision(true, false);
		CollisionComponent = Comp;
		SetCollision(true, false, false);

		SetLocation(Instigator.Location);
		SetBase(Instigator);
	}
	else 
	{
		SetCollision(false, false, false);
		DetachComponent(CollisionComponent);
		CollisionComponent = none;

		SetBase(none);
	}
}

/** adds or removes our bonus from the given pawn */
simulated function ClientSetup(UTPawn P, bool bRemove);

simulated function ConditionalPlayWarning()
{
	if (bPlayWarningOnce)
	{
		PlayWarningSound();
		bPlayWarningOnce = false;
	}

	if (TimeRemaining > 10.0)
	{
		bPlayWarningOnce = true;
		SetTimer(TimeRemaining - 10.0, false, GetFuncName());
	}
	if (TimeRemaining > 5.0)
	{
		bPlayWarningOnce = true;
		SetTimer(TimeRemaining - 5.0, false, GetFuncName());
	}
	else
	{
		 if (TimeRemaining < 2.0)
		 {
			PlayWarningSound();
			SetTimer(0.65, false, GetFuncName());
		 }
		 else
		 {
			bPlayWarningOnce = true;
			SetTimer(1.5, false, GetFuncName());
		 }		
	}
}

simulated function PlayWarningSound()
{
	local Actor Other;
	
	Other = Owner == none ? Instigator : Owner;
	if (Other != none && InvSetup.WarningSound != none)
	{
		Other.PlaySound(InvSetup.WarningSound);
	}
}

//**********************************************************************************
// Utils
//**********************************************************************************

// For use with listen servers
final simulated function bool bLocallyOwned()
{
	local Controller C;

	if (Owner == none)
		return false;

	if (Pawn(Owner) != none)
		C = Pawn(Owner).Controller;
	else
		C = Controller(Owner);

	if (WorldInfo.NetMode != NM_DedicatedServer && C != none && PlayerController(C) != none && LocalPlayer(PlayerController(C).Player) != none)
		return True;

	return False;
}

DefaultProperties
{
`if(`notdefined(FINAL_RELEASE))
	bShowDebug=true
	bShowDebugTouch=false
	bShowDebugDeny=false
`endif

	TimeRemaining=10.0 // just a default value, TimeRemaing gets setup by the mutator

	bReceiveOwnerEvents=true
	bDropOnDeath=false
	bDropOnDisrupt=false


	// Localization
	ProtectionActiveMessage="Ghost protection currently active"
	ProtectionActiveMessageWithTime="Ghost protection currently active (`ts)"
	FireToUnProtectMessage="Press [FIRE] to remove ghost protection"
	TimeStringMessage="`ts"


	// Localization
	ShowTime=true
	BarTimeThreshold=5.0
	WarningSound=true
}
