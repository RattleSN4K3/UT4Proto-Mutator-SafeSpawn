class UT4SafeSpawnMutator extends UTMutator
	config(UT4Proto_MutatorSafeSpawn)
	abstract;

`if(`notdefined(FINAL_RELEASE))
var bool bShowDebug;
var bool bShowDebugPRI;
var bool bShowDebugLinkedRI;
var bool bShowDebugReplacement;

struct TestPawnResetInfo
{
	var PlayerController Sender;
	var Pawn P;
};
`endif

//**********************************************************************************
// Workflow variables
//**********************************************************************************

`if(`notdefined(FINAL_RELEASE))
var array<Pawn> TestPawns;
var array<TestPawnResetInfo> TestReset;
`endif

var UT4SafeSpawnGameRules DamageHandler;
var() editconst class<UT4SafeSpawnGameRules> DamageHandlerClass;

var() editconst class<UT4SafeSpawnInventory> DamageHelperClass;

var bool bSpawnProtect;

var bool bInventoryApplySound;
var SoundCue InventoryWarningSound;
var SoundCue InventoryTimeoutSound;

var SoundCue RestoreSpawnSound;
var class<Actor> RestoreTransInEffect;

var() SoundCue NoSound;

//var() Material GhostMaterial;

// ---=== Customizable variables ===---

var() bool CompatibleMode;

// ---=== Config variables ===---

var() globalconfig float GhostProtectionTime;
var() globalconfig float InitialFireDelay;

//**********************************************************************************
// Inherited funtions
//**********************************************************************************

event PostBeginPlay()
{
	super.PostBeginPlay();

	// early out
	if (WorldInfo.Game == none)
		return;

	bSpawnProtect = CreateGameRules();

	if (CompatibleMode)
	{
		// safe check before adding game rules etc.
		if (GhostProtectionTime > 0 && class<UTPawn>(WorldInfo.Game.DefaultPawnClass) != none)
		{
			RestoreSpawnSound = class<UTPawn>(WorldInfo.Game.DefaultPawnClass).default.SpawnSound;
			RestoreTransInEffect = class<UTPawn>(WorldInfo.Game.DefaultPawnClass).default.TransInEffects[0];

			// Hush
			InventoryWarningSound = class<UTPawn>(WorldInfo.Game.DefaultPawnClass).default.SpawnSound;

			// Zirp (Translocate)
			InventoryTimeoutSound = class<UTPawn>(WorldInfo.Game.DefaultPawnClass).default.TeleportSound;

			bInventoryApplySound = true;
		}
	}
	else
	{
		// compatible mode is off, so we replace the Pawn
		WorldInfo.Game.DefaultPawnClass = class'UT4SafeSpawnPawn';
	}
}

function NotifyLogout(Controller Exiting)
{
	if (CompatibleMode)
	{
		RemovePRIFrom(PlayerController(Exiting));
		RemoveLinkedRIFrom(Exiting);
	}
    super.NotifyLogout(Exiting);
}

function NotifyLogin(Controller NewPlayer)
{
    Super.NotifyLogin(NewPlayer);
    if (CompatibleMode)
	{
		ConditionallyAddPRIFor(UTPlayerController(NewPlayer));
		ConditionallyAddLinkedRIFor(NewPlayer);
	}
}

/**
 * Returns true to keep this actor
 */
function bool CheckReplacement(Actor Other)
{
	`Log(name$"::CheckReplacement - Other:"@Other,bShowDebug&&bShowDebugReplacement,'UT4SafeSpawn');

	// remove the initial Enforcer reload time
	if (UTWeap_Enforcer(Other) != none)
	{
		UTWeap_Enforcer(Other).bLoaded = true;
	}

	if (CompatibleMode && UTPawn(Other) != none)
	{
		if (bInventoryApplySound)
		{
			// Remove old spawn sounds
			UTPawn(Other).SpawnSound = NoSound;

			// Remove spawn effect (for all team; no need to set others as the code checks only for the first)
			UTPawn(Other).TransInEffects[0] = none;
		}
	}
	else if (UT4SafeSpawnPawn(Other) != none)
	{
		UT4SafeSpawnPawn(Other).GhostProtectionTime = GhostProtectionTime;
		UT4SafeSpawnPawn(Other).InitialFireDelay = InitialFireDelay;
	}

	return true;
}

function DriverEnteredVehicle(Vehicle V, Pawn P)
{
	local Inventory inv;
	super.DriverEnteredVehicle(V, P);

	if (CompatibleMode && UTPawn(P) != none && HasInventory(P, inv))
	{
		//@CHECK: vehicle collsion; if the player can be killed by entering a vehicle while being ghost protected
		ProtectPlayer(UTPawn(P), false);
	}
}

function ModifyPlayer(Pawn Other)
{
	local float offset;
	super.ModifyPlayer(Other);

	// adjust spawn times so bots will ignore the bots on spawn
	//
	// as bots are generally ignoring bots with the default spawn protection,
	// this won't work for the ghost protection as we disbaling it
	//
	// WorldInfo.TimeSeconds - Pawn.SpawnTime < UTDeathMatch(WorldInfo.Game).SpawnProtectionTime)
	if (UTGame(WorldInfo.Game) != none)
	{
		offset = UTGame(WorldInfo.Game).SpawnProtectionTime;
	}
	Other.SpawnTime += (GhostProtectionTime - offset);

	if (CompatibleMode && bSpawnProtect && UTPawn(Other) != none)
	{
		// restore spawn effect
		UTPawn(Other).TransInEffects[0] = RestoreTransInEffect;

		ProtectPlayer(UTPawn(Other), true);
	}
}

function Mutate(string MutateString, PlayerController Sender)
{
	local string str, value;
`if(`notdefined(FINAL_RELEASE))
	local int i, index;
	local Pawn P, NewP;
	local PlayerReplicationInfo PRI;
	local UTBot Bot;
	local bool bMustJoinBeforeStart;
`endif

	`Log(name$"::Mutate - MutateString:"@MutateString$" - Sender:"@Sender,bShowDebug,'UT4SafeSpawn');
	super.Mutate(MutateString, Sender);

	if (Sender == none)
		return;

	str = "SafeSpawn";
	if (Left(MutateString, Len(str)) ~= str)
	{
		value = Mid(MutateString, Len(str)+1);
		if (WorldInfo.NetMode == NM_Standalone || (Sender.PlayerReplicationInfo != none && Sender.PlayerReplicationInfo.bAdmin))
		{
			class'UT4SafeSpawn'.static.ProcessCommand(Sender, value, true);
		}
		else
		{
			Sender.ClientMessage("SafeSpawn: Need to be logged in as admin.");
		}

		return;
	}

`if(`notdefined(FINAL_RELEASE))
	str = "Time";
	if (Left(MutateString, Len(str)) ~= str)
	{
		value = Mid(MutateString, Len(str)+1);
		GhostProtectionTime = float(Repl(value, ",", "."));

		Sender.ClientMessage("GhostProtectionTime changed to"@value$"s");
		return;
	}

	str = "storespawn";
	if (Left(MutateString, Len(str)) ~= str)
	{
		if (Sender.Pawn != none && Sender.Pawn.LastStartSpot != none && UTGame(WorldInfo.Game) != none)
		{
			UTGame(WorldInfo.Game).ScriptedStartSpot = Sender.Pawn.LastStartSpot;
		}
		
		Sender.ClientMessage("Scripted spawn point set.");
		return;
	}

	str = "clearspawn";
	if (Left(MutateString, Len(str)) ~= str)
	{
		if (Sender.Pawn != none && Sender.Pawn.LastStartSpot != none && UTGame(WorldInfo.Game) != none)
		{
			UTGame(WorldInfo.Game).ScriptedStartSpot = none;
		}
		
		Sender.ClientMessage("Scripted spawn point cleared.");
		return;
	}

	str = "Spawn";
	if (Left(MutateString, Len(str)) ~= str)
	{
		P = Sender.Pawn;
		if (P != none && P.LastStartSpot != none)
		{
			if (UTGame(WorldInfo.Game) != none)
			{
				if (UTGame(WorldInfo.Game).ScriptedStartSpot == none || UTGame(WorldInfo.Game).ScriptedStartSpot != P.LastStartSpot)
				{
					UTGame(WorldInfo.Game).ScriptedStartSpot = P.LastStartSpot;
				}

				Bot = UTGame(WorldInfo.Game).SpawnBot("TestPawn"@TestPawns.Length+1);
				WorldInfo.Game.RestartPlayer(Bot);
				P = Bot.Pawn;
				P.Tag = 'TestPawn';
				PRI = Bot.PlayerReplicationInfo;
				P.PlayerReplicationInfo = PRI;

				Bot.UnPossess();
				Bot.PlayerReplicationInfo = none;
				

				bMustJoinBeforeStart = UTGame(WorldInfo.Game).bMustJoinBeforeStart;
				UTGame(WorldInfo.Game).bMustJoinBeforeStart = true;
				UTGame(WorldInfo.Game).DesiredPlayerCount -= 1;
				UTGame(WorldInfo.Game).KillBot(Bot);
				UTGame(WorldInfo.Game).bMustJoinBeforeStart = bMustJoinBeforeStart;
				
				TestPawns.AddItem(P);
			}
		}

		Sender.ClientMessage("Test Pawn spawned.");
		return;
	}

	str = "Clear";
	if (Left(MutateString, Len(str)) ~= str)
	{
		foreach TestPawns(P)
		{
			P.Destroy();
		}
		
		Sender.ClientMessage("All Test Pawns killed.");
		return;
	}

	str = "Reset";
	if (Left(MutateString, Len(str)) ~= str)
	{
		index = TestReset.Find('Sender', Sender);
		if (index != INDEX_NONE && TestReset[index].P != none)
		{
			Sender.Possess(TestReset[index].P, false);
			Sender.ClientMessage("Original Pawn possessed.");
		}
		else
		{
			Sender.Pawn = none;
			WorldInfo.Game.RestartPlayer(Sender);
			Sender.ClientMessage("Respawned.");
		}

		return;
	}

	str = "Cycle";
	if (Left(MutateString, Len(str)) ~= str)
	{
		index = TestReset.Find('Sender', Sender);
		if (index == INDEX_NONE)
		{
			i = TestReset.Length;
			TestReset.Add(1);
			TestReset[i].P = Sender.Pawn;
			TestReset[i].Sender = Sender;
		}

		P = Sender.Pawn;
		TestPawns.RemoveItem(none);
		if (Sender.Pawn.Tag != 'TestPawn' && TestPawns.Length > 0)
		{
			NewP = TestPawns[0];
		}
		else
		{
			for (i=0; i<TestPawns.Length; i++)
			{
				if (Sender.Pawn == none)
				{
					NewP = TestPawns[i];
				}
				else if (Sender.Pawn == TestPawns[i])
				{
					if (i == TestPawns.Length-1)
						NewP = TestPawns[0];
					else
						NewP = TestPawns[i+1];
				}
			}
		}

		if (NewP != none)
		{
			if (NewP.InvManager.InventoryChain == none)
			{
				Sender.Pawn = none;
				WorldInfo.Game.RestartPlayer(Sender);
			}
			else
			{
				Sender.Possess(NewP, false);
			}
		}
		
		if (NewP != none && NewP != P)
			Sender.ClientMessage("View switched");
		else
			Sender.ClientMessage("New Test Pawn found");
		
		return;
	}

	str = "botcheck";
	if (Left(MutateString, Len(str)) ~= str)
	{
		if (Sender.Pawn != none)
		{
			bMustJoinBeforeStart = WorldInfo.TimeSeconds - Sender.Pawn.SpawnTime < UTDeathMatch(WorldInfo.Game).SpawnProtectionTime;
			Sender.ClientMessage("Bot fire at me?"@!bMustJoinBeforeStart);
		}
		else
		{
			Sender.ClientMessage("No pawn.");
		}
		return;
	}
	
`endif
}

//**********************************************************************************
// Delegate Callbacks
//**********************************************************************************

function OnUnProtectFire(UTPlayerController PC, UT4SafeSpawnRepInfo ClientRI)
{
	ProtectPlayer(PC != none ? UTPawn(PC.Pawn) : none, false, ClientRI);
}

function OnUnProtectPickup(UTPawn P)
{
	ProtectPlayer(P, false);
}

//**********************************************************************************
// Private funtions
//**********************************************************************************

function ConditionallyAddPRIFor(UTPlayerController PC)
{
	local UT4SafeSpawnRepInfo ClientRI;

	if (PC == none)
		return;

	`Log(name$"::ConditionallyAddPRIFor - PC:"@PC,bShowDebug&&bShowDebugPRI,'UT4SafeSpawn');
	if (!GetClientRI(PC, ClientRI)) {

		ClientRI = Spawn(class'UT4SafeSpawnRepInfo', PC);
		`Log(name$"::ConditionallyAddPRIFor - ClientRI:"@ClientRI,bShowDebug&&bShowDebugPRI,'UT4SafeSpawn');

		if (ClientRI != none)
		{
			ClientRI.InitialSetup(PC, OnUnProtectFire, InitialFireDelay);
		}
	}
}

function RemovePRIFrom(PlayerController PC)
{
	local UT4SafeSpawnRepInfo ClientRI;

	if (PC == none)
		return;

	`Log(name$"::RemovePRIFrom - PC:"@PC,bShowDebug&&bShowDebugPRI,'UT4SafeSpawn');
	if (GetClientRI(PC, ClientRI))
	{
		`Log(name$"::RemovePRIFrom - Remove ClientRI:"@ClientRI,bShowDebug&&bShowDebugPRI,'UT4SafeSpawn');
		ClientRI.Destroy();
	}
}

function ConditionallyAddLinkedRIFor(Controller C)
{
	local UT4SafeSpawnLink LinkedRI;

	if (C == none)
		return;

	`Log(name$"::ConditionallyAddLinkedRIFor - C:"@C,bShowDebug&&bShowDebugLinkedRI,'UT4SafeSpawn');
	if (!GetLinkedRI(C, LinkedRI)) {

		LinkedRI = Spawn(class'UT4SafeSpawnLink', C);
		`Log(name$"::ConditionallyAddLinkedRIFor - LinkedRI:"@LinkedRI,bShowDebug&&bShowDebugLinkedRI,'UT4SafeSpawn');
	}
}

function RemoveLinkedRIFrom(Controller C)
{
	local UT4SafeSpawnLink LinkedRI;

	if (C == none)
		return;

	`Log(name$"::RemoveLinkedRIFrom - C:"@C,bShowDebug&&bShowDebugLinkedRI,'UT4SafeSpawn');
	if (GetLinkedRI(C, LinkedRI))
	{
		`Log(name$"::RemoveLinkedRIFrom - Remove LinkedRI:"@LinkedRI,bShowDebug&&bShowDebugLinkedRI,'UT4SafeSpawn');
		LinkedRI.Destroy();
	}
}
	
function ProtectPlayer(UTPawn Other, bool bProtect, optional out UT4SafeSpawnRepInfo ClientRI)
{
	local PlayerController PC;
	local Inventory inv;
	local UT4SafeSpawnLink LinkedRI;

	`Log(name$"::ProtectNewPlayer - Other:"@Other,bShowDebug,'UT4SafeSpawn');

	//PC = (Other == none || !GetPC(Other, PC)) ? none : PC;
	//if (PC != none && ClientRI == none && !GetClientRI(PC, ClientRI))
	//{
	//	// Unable to find ClientRI for connected client, abort
	//	return;
	//}

	if (GetPC(Other, PC) && ClientRI == none && !GetClientRI(PC, ClientRI))
	{
		// Unable to find ClientRI for connected client, abort
		return;
	}

	if (!bProtect)
	{
		if (Other != none)
		{
			//// revert skin
			//Other.SetSkin(none);

			if (Other.Health > 0) // if not suicided
			{
				Other.PlayTeleportEffect(false, true);
			}

			// destroy inventory if there's still one
			if (HasInventory(Other, inv) && !inv.bDeleteMe && !inv.bPendingDelete)
			{
				inv.Destroy();
			}

			if (CompatibleMode)
			{
				// remove protection from any Pawn
				if (GetLinkedRI(GetController(Other), LinkedRI))
				{
					LinkedRI.NotfiyRemove();
				}

`if(`notdefined(FINAL_RELEASE))
				// for mutate bots
				else if (Other.Tag == 'TestPawn')
				{
					class'UT4SafeSpawn'.static.SetGhostFor(Other, false,, true);
					class'UT4SafeSpawn'.static.SetGhostEffectFor(Other, false);
				}
`endif

				// check if we should kill someone or die if we spawn in a colliding object
				class'UT4SafeSpawn'.static.CheckSpawnKill(Other);
			}
		}
		
		if (CompatibleMode && ClientRI != none)
		{
			ClientRI.NotifyActive();
		}
	}
	else if (Other != none)
	{
		// remove original spawn protection
		Other.DeactivateSpawnProtection();

		// Restore old spawn sounds (if another mods are calling it during the game)
		Other.SpawnSound = RestoreSpawnSound;

		// spawn inventory for Sound, Pickup check and helping messages
		GiveInventory(Other);

		if (CompatibleMode)
		{
			if (HasInventory(Other, inv) && UT4SafeSpawnInventoryCompat(inv) != none &&
				UTGame(WorldInfo.Game) != none && UTGame(WorldInfo.Game).bStartWithLockerWeaps)
			{
				UT4SafeSpawnInventoryCompat(inv).bWaitForLanded = true;
			}

			// link pawn so any other Pawn becomes a full ghost
			if (GetLinkedRI(GetController(Other), LinkedRI))
			{
				LinkedRI.NotfiyNewPawn(Other);
			}

			if (ClientRI != none)
			{
				// notify rep
				ClientRI.NotifyRespawned(Other);
			}
		}
	}
}

function class<UT4SafeSpawnInventory> GetInventory()
{
	return DamageHelperClass;
}

function bool HasInventory(Pawn Other, optional out Inventory inv)
{
	inv = Other.FindInventoryType(GetInventory(), false);
	return (inv != none);
}

function bool GiveInventory(UTPawn Other)
{
	local UT4SafeSpawnInventory Inv;
	local class<UT4SafeSpawnInventory> InvClass;
	
	if (Other == none || Other.InvManager == none || HasInventory(Other))
	{
		return false;
	}

	InvClass = GetInventory();
	inv = Spawn(InvClass);
	if (inv != none && bInventoryApplySound)
	{
		inv.PowerupOverSound = InventoryTimeoutSound;

		// Set the time first
		inv.TimeRemaining = GhostProtectionTime;

		// Add the inventory (which also updates TimeRemaining for clients)
		Other.InvManager.AddInventory(Inv, false);

		// setup (which sets time and replicates sound cue)
		inv.SetupInventory(Other, InventoryWarningSound, GhostProtectionTime, OnUnProtectPickup);

		return true;
	}

	return false;
}

function bool CreateGameRules()
{
	local GameRules G;

	// Destory old one first
	if (DamageHandler != none)
	{
		DestroyGameRules(WorldInfo.Game.GameRulesModifiers, DamageHandler);
		DamageHandler = none;
	}

	// Add GameRule
	WorldInfo.Game.AddGameRules(DamageHandlerClass);

	// Find added GameRule
	for (G=WorldInfo.Game.GameRulesModifiers; G != none; G = G.NextGameRules)
	{
		DamageHandler = UT4SafeSpawnGameRules(G);
		if (DamageHandler != none)
		{
			DamageHandler.InventoryCheckClass = class'UT4SafeSpawnInventory';
			return true;
		}
	}

	return false;
}

function DestroyGameRules(out GameRules BaseG, GameRules ToDelete)
{
	local GameRules G;

	// remove game rules list
	if ( BaseG == ToDelete )
	{
		BaseG = ToDelete.NextGameRules;
	}
	else if ( BaseG != None )
	{
		for ( G=BaseG; G!=none; G=G.NextGameRules )
		{
			if ( G.NextGameRules == ToDelete )
			{
				G.NextGameRules = ToDelete.NextGameRules;
				break;
			}
		}
	}
}

function bool GetPC(Pawn P, out PlayerController PC)
{
	if (P == none)
		return false;

	PC = UTPlayerController(P.Controller);
	if (PC == None && P.DrivenVehicle != None)
	{
		PC = UTPlayerController(P.DrivenVehicle.Controller);
	}

	return PC != none;
}

function Controller GetController(Pawn P)
{
	local Controller C;
	if (P == none)
		return none;

	C = P.Controller;
	if (C == none && P.DrivenVehicle != none)
	{
		C = P.DrivenVehicle.Controller;
	}

	return C;
}

function bool GetClientRI(PlayerController PC, out UT4SafeSpawnRepInfo out_ClientRI)
{
	foreach PC.ChildActors(class'UT4SafeSpawnRepInfo', out_ClientRI)
		break;

	return out_ClientRI != none;
}

function bool GetLinkedRI(Controller C, out UT4SafeSpawnLink out_LinkedRI)
{
	if (C != none)
	{
		foreach C.ChildActors(class'UT4SafeSpawnLink', out_LinkedRI)
		{
			break;
		}
	}

	return out_LinkedRI != none;
}

Defaultproperties
{
	`if(`notdefined(FINAL_RELEASE))
		bShowDebug=true
		bShowDebugPRI=true
		bShowDebugLinkedRI=true
		bShowDebugReplacement=false
	`endif

	Begin object Class=SoundCue Name=MyNoSound
	end object
	NoSound=MyNoSound

	DamageHandlerClass=class'UT4SafeSpawnGameRules'
	DamageHelperClass=class'UT4SafeSpawnInventoryCompat'

	CompatibleMode=false

	// --- Config ---
	
	GhostProtectionTime=6.0
}