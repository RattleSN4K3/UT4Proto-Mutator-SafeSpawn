class UT4SafeSpawn extends Object
	config(UT4Proto_MutatorSafeSpawn);

//**********************************************************************************
// Structs
//**********************************************************************************

struct CrosshairRestoreInfo
{
	var UTWeapon Weap;

	/** Holds the image to use for the crosshair. */
	var Texture2D CrosshairImage;
};

struct WeaponRestoreInfo
{
	var Weapon Weap;

	/** Array of firing states defining available firemodes */
	var				Array<Name>					FiringStatesArray;

	/** Defines the type of fire (see Enum above) for each mode */
	var				Array<EWeaponFireType>		WeaponFireTypes;
};

struct GhostCollisionInfo
{
	var bool bSet;

	var bool bOriginalCollideActors;
	var bool bOriginalBlockActors;
	var bool bOriginalPushesRigidBodies;
	var bool bOriginalIgnoreForces;
};

//**********************************************************************************
// Config variables
//**********************************************************************************

var() config bool AllowGhostFrag; // MOVED HERE FOR EASY REFERENCING

var() config bool SwitchToThirdPerson;
var() config bool ApplyPPEffects;
var() config bool HideCrosshairTemporarely;
var() config float IgnoreInputThreshold;

//**********************************************************************************
// Workflow variables
//**********************************************************************************

var() MaterialInterface GhostMaterial;
var() string GhostMaterialString;

/** ambient sound on the pawn when Ghost protection is active */
var() SoundCue GhostAmbientSound;
var() string GhostAmbientSoundString;

var() SoundCue FireBlockedWarningSound;

/* post processing applied while holding this powerup */
var() vector PP_Scene_MidTones;
var() vector PP_Scene_Shadows;
var() vector PP_Scene_HighLights;
var() float PP_Scene_Desaturation;
var() float PP_Scene_InterpolationDuration;

//**********************************************************************************
// Delegates
//**********************************************************************************

/** Used as callback for tracking the Fire keys on client sides */
delegate OnFireInput();

delegate OnUnProtectFire(UTPlayerController PC, UT4SafeSpawnRepInfo ClientRI);
delegate OnUnProtectPickup(UTPawn P);

//**********************************************************************************
// Private static functions
//**********************************************************************************

static function MaterialInterface GetGhostMaterial()
{
	local UT4SafeSpawn def;
	if (default.GhostMaterial == none && default.GhostMaterialString != "" && GetDefaultActor(def))
	{
		def.GhostMaterial = MaterialInterface(DynamicLoadObject(default.GhostMaterialString, class'MaterialInterface'));
	}

	return default.GhostMaterial;
}

static function SoundCue GetGhostAmbientSound()
{
	local UT4SafeSpawn def;
	if (default.GhostAmbientSound == none && default.GhostAmbientSoundString != "" && GetDefaultActor(def))
	{
		def.GhostAmbientSound = SoundCue(DynamicLoadObject(default.GhostAmbientSoundString, class'SoundCue'));
	}

	return default.GhostAmbientSound;
}

static function bool GetDefaultActor(out UT4SafeSpawn def)
{
	def = UT4SafeSpawn(FindObject(default.class.GetPackageName()$".Default__"$default.class, default.class));
	return def != none;
}

//**********************************************************************************
// Static functions
//**********************************************************************************

static function SetPPEffectsFor1(UTPlayerController PC, bool bAdd, 
	optional out float InterpolationDurationAbsolute,
	optional out int PP_Scene_Changed
	);

static function SetPPEffectsFor(UTPlayerController PC, bool bAdd, 
	out byte bOriginalOverridePostProcessSettings,
	out PostProcessSettings OriginalPostProcessSettingsOverride, 
	out byte PP_Scene_Changed
	)
{
	local LocalPlayer LP;
	local PostProcessSettings OverrideSettings;
	local UT4SafeSpawnRestore restore;

	// if disabled or unable to apply effects, abort
	if (PC == none || !default.ApplyPPEffects)
		return;

	LP = LocalPlayer(PC.Player);
	if (LP == none)
		return;

	if (bAdd && PP_Scene_Changed == 0)
	{
		PP_Scene_Changed = 1;
		bOriginalOverridePostProcessSettings = LP.bOverridePostProcessSettings ? 1 : 0;
		OriginalPostProcessSettingsOverride = LP.PostProcessSettingsOverride;

		OverrideSettings.Bloom_InterpolationDuration = 0.01;
		OverrideSettings.DOF_InterpolationDuration = 0.01;
		OverrideSettings.MotionBlur_InterpolationDuration = 0.01;
		OverrideSettings.Scene_InterpolationDuration = 0.01;

		OverrideSettings.Scene_HighLights += default.PP_Scene_Highlights;
		OverrideSettings.Scene_MidTones += default.PP_Scene_MidTones;
		OverrideSettings.Scene_Shadows += default.PP_Scene_Shadows;
		OverrideSettings.Scene_Desaturation += default.PP_Scene_Desaturation;

		LP.OverridePostProcessSettings(OverrideSettings, PC.WorldInfo.TimeSeconds);
	}
	else if (!bAdd && PP_Scene_Changed == 1)
	{
		PP_Scene_Changed = 0;

		if (bOriginalOverridePostProcessSettings == 1)
		{
			LP.UpdateOverridePostProcessSettings(OriginalPostProcessSettingsOverride);
		}
		else
		{
			LP.ClearPostProcessSettingsOverride();
		}
	}

	restore = class'UT4SafeSpawnRestore'.static.GetRestore();
	restore.Update(LP, PP_Scene_Changed == 1 || LP.bOverridePostProcessSettings);
}

//OLD CODE. Not working for all the maps
//static function SetPPEffectsFor(UTPlayerController PC, bool bAdd, 
//	optional out float InterpolationDurationAbsolute,
//	optional out int PP_Scene_Changed
//	)
//{
//	if (bAdd && PP_Scene_Changed == 0)
//	{
//		PP_Scene_Changed = 1;

//		if (PC.PostProcessModifier.Scene_InterpolationDuration != 0)
//		{
//			InterpolationDurationAbsolute = PC.PostProcessModifier.Scene_InterpolationDuration;
//			PC.PostProcessModifier.Scene_InterpolationDuration = default.PP_Scene_InterpolationDuration;
//		}
//		else
//		{
//			PC.PostProcessModifier.Scene_InterpolationDuration += default.PP_Scene_InterpolationDuration;
//		}

//		PC.PostProcessModifier.Scene_HighLights += default.PP_Scene_Highlights;
//		PC.PostProcessModifier.Scene_MidTones += default.PP_Scene_MidTones;
//		PC.PostProcessModifier.Scene_Shadows += default.PP_Scene_Shadows;
//		PC.PostProcessModifier.Scene_Desaturation += default.PP_Scene_Desaturation;
//	}
//	else if (!bAdd && PP_Scene_Changed == 1)
//	{
//		PP_Scene_Changed = 0;

//		if (InterpolationDurationAbsolute != 0.0)
//		{
//			PC.PostProcessModifier.Scene_InterpolationDuration = InterpolationDurationAbsolute;
//		}
//		else
//		{
//			PC.PostProcessModifier.Scene_InterpolationDuration -= default.PP_Scene_InterpolationDuration;
//		}

//		PC.PostProcessModifier.Scene_HighLights -= default.PP_Scene_Highlights;
//		PC.PostProcessModifier.Scene_MidTones -= default.PP_Scene_MidTones;
//		PC.PostProcessModifier.Scene_Shadows -= default.PP_Scene_Shadows;
//		PC.PostProcessModifier.Scene_Desaturation -= default.PP_Scene_Desaturation;
//	}
//}

static function SetGhostFor(UTPawn P, bool bTurnOn, 
	optional out GhostCollisionInfo bOriginals,
	optional bool bUseDefault)
{
	if (P == none)
		return;

	if (bTurnOn)
	{
		bOriginals.bOriginalCollideActors = P.bCollideActors;
		bOriginals.bOriginalBlockActors = P.bBlockActors;
		bOriginals.bOriginalPushesRigidBodies = P.bPushesRigidBodies;
		bOriginals.bOriginalIgnoreForces = P.bIgnoreForces;

		P.SetCollision(false, false);
		P.SetPushesRigidBodies(false);
		if (P.CollisionComponent != None)
		{
			P.CollisionComponent.SetBlockRigidBody(false);
		}

		P.bIgnoreForces = true;
	}
	else
	{
		if (bUseDefault)
		{
			bOriginals.bOriginalCollideActors = P.default.bCollideActors;
			bOriginals.bOriginalBlockActors = P.default.bBlockActors;
			bOriginals.bOriginalPushesRigidBodies = P.default.bPushesRigidBodies;
			bOriginals.bOriginalIgnoreForces = P.default.bIgnoreForces;
		}

		if (!P.bPlayedDeath)
		{
			P.SetCollision(bOriginals.bOriginalCollideActors, bOriginals.bOriginalBlockActors);
			P.SetPushesRigidBodies(bOriginals.bOriginalPushesRigidBodies);
			if (!P.bFeigningDeath)
			{
				//@FIX: adjust the Comp's BlockRigidBody to true at this time will cause UT3 crash on suicide for instance
				//Done. This is somehow fixed, not sure why
				if (P.CollisionComponent != None)
				{
					P.CollisionComponent.SetBlockRigidBody(bOriginals.bOriginalPushesRigidBodies);
				}
			}
		}
		else if (P.Mesh != none)
		{
			P.Mesh.SetTraceBlocking(true, true);
			P.Mesh.SetActorCollision(true, false);
		}

		P.bIgnoreForces = bOriginals.bOriginalIgnoreForces;
	}

	if (P.RemoteRole != ROLE_None)
	{
		// force replicate flags if necessary
		P.SetForcedInitialReplicatedProperty(Property'Engine.Actor.bCollideActors', (P.bCollideActors == P.default.bCollideActors));
		P.SetForcedInitialReplicatedProperty(Property'Engine.Actor.bBlockActors', (P.bBlockActors == P.default.bBlockActors));
		P.SetForcedInitialReplicatedProperty(Property'Engine.Pawn.bPushesRigidBodies', (P.bPushesRigidBodies == P.default.bBlockActors));
	}
}

static function SetGhostEffectFor(UTPawn P, bool bTurnOn)
{
	local MaterialInterface Mat;
	local MaterialInstance MatInst, Instance;
	local LinearColor LinColor, NewColor, BaseColor;
	local TeamInfo Team;

	if (P == none)
		return;

	// Enable the ghost effect
	if (bTurnOn)
	{
		Mat = GetGhostMaterial();
		MatInst = MaterialInstance(Mat);
		if (MatInst != none)
		{
			Team = P.GetTeam();
			Instance = MatInst;
			if (Team != none)
			{
				LinColor = ColorToLinearColor(Team.GetTextColor());
				BaseColor = ColorToLinearColor(Team.GetHUDColor());
				BaseColor = BaseColor - MakeLinearColor(-1.0, -1.0, -1.0, 0.0);
			}
			else
			{
				LinColor = P.SpawnProtectionColor;
				BaseColor = NormalizeColor(P.SpawnProtectionColor);
			}
			BaseColor = BaseColor - MakeLinearColor(-1.0, -1.0, -1.0, 0.0);

			// Create the material instance 
			Instance = new(P) class'MaterialInstanceConstant';
			Instance.SetParent( MatInst );

			NewColor = BoostColor(LinColor, 60);
			Instance.SetVectorParameterValue('GhostGlowColor', NewColor);
			Instance.SetVectorParameterValue('GhostBaseColor', BaseColor);

			SetSkinEx( P, Instance );
		}
		else
		{
			P.SetSkin( Material(Mat) );
		}
	}
	else
	{
		// Disable ghost
		P.SetSkin( none );
	}
}

static function SetSkinEx(UTPawn P, MaterialInterface NewMaterial)
{
	local int i,Cnt;

	if (P == none)
		return;

	if ( NewMaterial == None )
	{
		// Clear the materials
		if ( P.default.Mesh.Materials.Length > 0 )
		{
			Cnt = P.Default.Mesh.Materials.Length;
			for (i=0;i<Cnt;i++)
			{
				P.Mesh.SetMaterial( i, P.Default.Mesh.GetMaterial(i) );
			}
		}
		else if (P.Mesh.Materials.Length > 0)
		{
			Cnt = P.Mesh.Materials.Length;
			for ( i=0; i < Cnt; i++ )
			{
				P.Mesh.SetMaterial(i, none);
			}
		}
	}
	else
	{
		// Set new material
		if ( P.default.Mesh.Materials.Length > 0 || P.Mesh.GetNumElements() > 0 )
		{
			Cnt = P.default.Mesh.Materials.Length > 0 ? P.default.Mesh.Materials.Length : P.Mesh.GetNumElements();
			for ( i=0; i < Cnt; i++ )
			{
				P.Mesh.SetMaterial(i, NewMaterial);
			}
		}
	}
}

static function LinearColor NormalizeColor(LinearColor LC)
{
	local vector v;
	v.X = LC.R;
	v.Y = LC.G;
	v.Z = LC.B;

	v = Normal(v);
	return MakeLinearColor(v.X, v.Y, v.Z, 1.0);
}

static function LinearColor BoostColor(LinearColor LC, float strength)
{
	local vector v;
	v.X = LC.R**4;
	v.Y = LC.G**4;
	v.Z = LC.B**4;

	v = Normal(v);
	v *= strength;
	return MakeLinearColor(v.X, v.Y, v.Z, 1.0);
}

static function SetGhostSoundFor(UTPawn P, bool bTurnOn)
{
	if (P == none)
		return;

	// Enable the ghost effect
	if (bTurnOn)
	{
		// a silent ambient sound
		P.SetPawnAmbientSound(GetGhostAmbientSound());
	}
	else
	{
		// clear ambient sound
		P.SetPawnAmbientSound(none);
	}
}

static function SetCrosshairFor(InventoryManager InvManager, bool bRemoveCross, out array<CrosshairRestoreInfo> CrosshairRestore)
{
	local UTWeapon Weap;
	local int index;

	// if disabled, abort
	if (!default.HideCrosshairTemporarely)
		return;

	foreach InvManager.InventoryActors(class'UTWeapon', Weap)
	{
		if (bRemoveCross)
		{
			index = CrosshairRestore.Length;
			CrosshairRestore.Add(1);
			CrosshairRestore[index].Weap = Weap;
			CrosshairRestore[index].CrosshairImage = Weap.CrosshairImage;

			Weap.CrosshairImage = none;
		}
		else
		{
			index = CrosshairRestore.Find('Weap', Weap);
			if (index != INDEX_NONE)
			{
				Weap.CrosshairImage = CrosshairRestore[index].CrosshairImage;
			}
		}
	}

	if (!bRemoveCross)
	{
		CrosshairRestore.Length = 0;
	}
}

static function SetThirdPersonFor(UTPlayerController UTPC, bool bEnable, optional out byte bOriginalBehindView)
{

	// if disabled or unable to switch view, abort
	if (!default.SwitchToThirdPerson || UTPC == none || !UTPC.IsLocalPlayerController())
		return;

	if (bEnable)
	{
		bOriginalBehindView = UTPC.default.bBehindView ? 1 : 0;
		UTPC.SetBehindView(true);
	}
	else
	{
		if (UTVehicle(UTPC.Pawn) == none && UTPawn(UTPC.Pawn) != none && UTPawn(UTPC.Pawn).bFeigningDeath && UTPC.Pawn.IsInState('FeigningDeath'))
		{
			UTPC.SetBehindView(true);
		}
		else
		{
			UTPC.SetBehindView(UTPC.default.bBehindView || bOriginalBehindView == 1);
		}
	}
}

static function CheckSpawnKill(UTPawn Other)
{
	local UTPawn P;
	local UTVehicle V;
	local Controller Killer;

	local Vector Diff;
	local float DiffZ;

	if (Other == none)
		return;

	//@TODO: add other collision check

	// if cylinder is penetrating a vehicle, kill the pawn to prevent exploits
	foreach Other.CollidingActors(class'UTVehicle', V, Other.GetCollisionRadius(),, true)
	{
		if (Other.IsOverlapping(V))
		{
			if (V.Controller != None)
			{
				Killer = V.Controller;
			}
			else if (V.Instigator != None)
			{
				Killer = V.Instigator.Controller;
			}

			Other.Died(Killer, V.RanOverDamageType, Other.Location);
			break;
		}
	}

	// spawn frag enemies or die if teammates
	foreach Other.CollidingActors(class'UTPawn', P, 2*Other.GetCollisionRadius() + 8) // increased collision check
	{
		if (P != Other) 
		{
			Diff = Other.Location - P.Location;
			DiffZ = Diff.Z;
			Diff.Z = 0;
			if ( (Abs(DiffZ) < P.GetCollisionHeight() + 2 * Other.GetCollisionHeight() )
				&& (VSize(Diff) < P.GetCollisionRadius() + Other.GetCollisionRadius() + 10) ) // a small bigger radius than telefrag
			{
				if ( default.AllowGhostFrag && !Other.WorldInfo.Game.GameReplicationInfo.OnSameTeam(P,Other))
				{
					P.Died(Other.Controller, class'UTDmgType_Telefrag', Other.Location);
				}
				else
				{
					Other.Died(Other.Controller, class'DamageType', Other.Location);
				}
				break;
			}
		}
	}
}

static function PlayFireBlockedWarningFor(PlayerController PlayerOwner)
{
	if (PlayerOwner != none)
	{
		PlayerOwner.PlaySound(default.FireBlockedWarningSound, true);
	}
}

static function ProcessCommand(PlayerController Sender, string command, optional bool IsServer)
{
	local string str;
	local array<string> Pieces;
	local Settings Setts;
	local int i;
	local name PropertyName;

	local string PropertyText, PropertyValue, PropertyDesc;
	if (Sender == none)
		return;

	if (Command == "")
	{
		if (!IsServer)
		{
			Setts = new class'UT4SafeSpawnSettingsClient';
			Setts.SetSpecialValue('WebAdmin_Init', "");
			Sender.ClientMessage("Client settings");
			Sender.ClientMessage("--------------");
			for (i=0; i<Setts.PropertyMappings.Length; i++)
			{
				str = Setts.GetPropertyAsStringByName(Setts.PropertyMappings[i].Name);
				str = Setts.PropertyMappings[i].Name $":"@str;
				Sender.ClientMessage(str);
			}
			Sender.ClientMessage(" ");
		}

		if (Sender.WorldInfo.NetMode == NM_Client)
			Sender.ClientMessage("Local setting:");
		else
			Sender.ClientMessage("Server setting:");
		Sender.ClientMessage("--------------");
		Setts = new class'UT4SafeSpawnSettingsServer';
		Setts.SetSpecialValue('WebAdmin_Init', "");
		for (i=0; i<Setts.PropertyMappings.Length; i++)
		{
			str = Setts.GetPropertyAsStringByName(Setts.PropertyMappings[i].Name);
			str = Setts.PropertyMappings[i].Name $":"@str;
			Sender.ClientMessage(str);
		}
	}
	else
	{
		ParseStringIntoArray(command, Pieces, " ", true);
		if (Pieces.Length == 1)
		{
			Setts = new class'UT4SafeSpawnSettingsClient';
			Setts.SetSpecialValue('WebAdmin_Init', "");
			if (GetSettingsPropertyValues(Setts, name(Pieces[0]), PropertyText, PropertyValue, PropertyDesc))
			{
				if (IsServer)
				{
					Sender.ClientMessage("You cannot retrieve client settings from the server. Use the command without the 'mutate ' prefix.");
				}
				else
				{
					str = PropertyText$" = "$PropertyValue;
					Sender.ClientMessage(str);
					Sender.ClientMessage(PropertyDesc);
				}
				return;
			}
			
			Setts = new class'UT4SafeSpawnSettingsServer';
			Setts.SetSpecialValue('WebAdmin_Init', "");
			if (GetSettingsPropertyValues(Setts, name(Pieces[0]), PropertyText, PropertyValue, PropertyDesc))
			{
				if (Sender.WorldInfo.NetMode == NM_Client)
					Sender.ClientMessage("Local setting:");
				else
					Sender.ClientMessage("Server setting:");

				str = PropertyText$" = "$PropertyValue;
				Sender.ClientMessage(str);
				Sender.ClientMessage(PropertyDesc);
				return;
			}

			Sender.ClientMessage("No variable with the given name found.");
		}
		else if (Pieces.Length == 2)
		{
			Setts = new class'UT4SafeSpawnSettingsClient';
			Setts.SetSpecialValue('WebAdmin_Init', "");

			PropertyName = name(Pieces[0]);
			if (GetSettingsPropertyValues(Setts, PropertyName))
			{
				if (IsServer)
				{
					Sender.ClientMessage("You cannot change client settings on the server. Use the command without the 'mutate ' prefix.");
					return;
				}
				else if (SetSettingsPropertyValues(Setts, PropertyName, Pieces[1]))
				{
					str = "Value for `k set to `v.";
					str = Repl(str, "`k", PropertyName);
					str = Repl(str, "`v", Pieces[1]);
					Sender.ClientMessage(str);
					return;
				}
			}
			
			Setts = new class'UT4SafeSpawnSettingsServer';
			Setts.SetSpecialValue('WebAdmin_Init', "");
			if (GetSettingsPropertyValues(Setts, PropertyName))
			{
				if (Sender.WorldInfo.NetMode == NM_Client)
				{
					Sender.ClientMessage("You need to use the 'mutate ' prefix to change values from the server.");
				}
				else if (SetSettingsPropertyValues(Setts, PropertyName, Pieces[1]))
				{
					str = "Value for `k set to `v.";
					str = Repl(str, "`k", PropertyName);
					str = Repl(str, "`v", Pieces[1]);
					Sender.ClientMessage(str);
				}
				
				return;
			}

			Sender.ClientMessage("No variable with the given name found.");
		}
	}

}

static function bool SetSettingsPropertyValues(Settings Setts, out name PropertyName, coerce string PropertyValue)
{
	local int index;

	index = Setts.PropertyMappings.Find('Name', PropertyName);
	if (index != INDEX_NONE)
	{
		Setts.SetPropertyFromStringByName(PropertyName, PropertyValue);
		Setts.SetSpecialValue('WebAdmin_Save', "");
		return true;
	}

	return false;
}

static function bool GetSettingsPropertyValues(Settings Setts, name PropertyName, 
	optional out string PropertyText,
	optional out string PropertyValue,
	optional out string PropertyDesc,
	optional out int PropertyId)
{
	PropertyId = Setts.PropertyMappings.Find('Name', PropertyName);
	if (PropertyId != INDEX_NONE)
	{
		PropertyText = Setts.PropertyMappings[PropertyId].ColumnHeaderText;
		PropertyValue = Setts.GetPropertyAsStringByName(PropertyName);
		PropertyDesc = Setts.GetSpecialValue(name("PropertyDescription_"$PropertyName));
		return true;
	}

	return false;
}

static function bool ShouldIgnoreInputForNow(float StoredTime, float CurrentTime)
{
	if (default.IgnoreInputThreshold < 0)
	{
		return true;
	}

	return (StoredTime + default.IgnoreInputThreshold > CurrentTime);
}

DefaultProperties
{
	FireBlockedWarningSound=SoundCue'A_Gameplay.ONS.A_GamePlay_ONS_CoreImpactShieldedCue'


`if(`notdefined(FINAL_RELEASE))
	//GhostAmbientSound=SoundCue'A_Pickups_Powerups.PowerUps.A_Powerup_Berzerk_PowerLoopCue'
	GhostAmbientSound=SoundCue'UT4Proto_MutatorSafeSpawnContent.Sound.A_Ghost_LoopCue'
`else
	//GhostAmbientSound=SoundCue'A_Pickups_Powerups.PowerUps.A_Powerup_Berzerk_PowerLoopCue'
	GhostAmbientSoundString="UT4Proto_MutatorSafeSpawn.Sound.A_Ghost_LoopCue"
`endif
	

	//GhostMaterial=Material'Envy_Effects.Level.M_Strident_Figures_2'
`if(`notdefined(FINAL_RELEASE))
	GhostMaterial=MaterialInterface'UT4Proto_MutatorSafeSpawnContent.Material.MI_Ghost'
`else
	GhostMaterialString="UT4Proto_MutatorSafeSpawn.Material.MI_Ghost"
`endif

	PP_Scene_InterpolationDuration=1.5
	PP_Scene_Highlights=(X=-0.8,Y=-0.8,Z=-0.8)
	PP_Scene_MidTones=(X=-0.3,Y=-0.3,Z=-0.3)
	PP_Scene_Shadows=(X=0.008,Y=0.008,Z=0.008);
	PP_Scene_Desaturation=0.65

	//OLD VALUES FOR OLD CODE
	//PP_Scene_InterpolationDuration=1.5
	//PP_Scene_Highlights=(X=-0.4,Y=-0.4,Z=-0.4)
	//PP_Scene_MidTones=(X=-0.3,Y=-0.3,Z=-0.3)
	//PP_Scene_Shadows=(X=0.005,Y=0.005,Z=0.005);
	//PP_Scene_Desaturation=0.35
	

	// --- Config ---
	
	//Server
	AllowGhostFrag=true

	//Client
	SwitchToThirdPerson=True
	ApplyPPEffects=True
	HideCrosshairTemporarely=True
	IgnoreInputThreshold=0.0
}
