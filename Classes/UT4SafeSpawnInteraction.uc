class UT4SafeSpawnInteraction extends Interaction;

`if(`notdefined(FINAL_RELEASE))
	var bool bShowDebug;
`endif

//**********************************************************************************
// Variables
//**********************************************************************************

var LocalPlayer LP;
var PlayerController PlayerOwner;

var bool bInitialized;
var bool bReInitialize;

var private const array<string> FireCommands;
//var name EscapeKey;
var array<name> FireKeys;
var array<name> DefaultFireKeys;

var bool bFireCalled;
var bool bTackKeyInput;
var bool bSuckOnce;
var delegate<UT4SafeSpawn.OnFireInput> FireCallback;

//**********************************************************************************
// Inherited funtions
//**********************************************************************************

/**
 * Called when the current map is being unloaded.  Cleans up any references which would prevent garbage collection.
 */
function NotifyGameSessionEnded()
{
	`Log(name$"::NotifyGameSessionEnded",bShowDebug,'UT4SafeSpawn');
	`Log(name$"::NotifyGameSessionEnded - Clear objects",bShowDebug,'UT4SafeSpawn');

	// Clear reference
	FireCallback = none;

	LP = none;
	PlayerOwner = none;
}

//**********************************************************************************
// Init functions
//**********************************************************************************

function Setup(PlayerController InPC, LocalPlayer InPlayer, delegate<UT4SafeSpawn.OnFireInput> FireDelegate)
{
	`Log(name$"::Initialize",bShowDebug,'UT4SafeSpawn');

	PlayerOwner = InPC;
	LP = InPlayer;
	FireCallback = FireDelegate;

	if (!bInitialized)
	{
		FireKeys = GetKeys(PlayerOwner);
	}

	Disable('Tick');

	bInitialized = true;
	bReInitialize = false;
}

function Kill()
{
	bInitialized = false;
	NotifyGameSessionEnded();
}

//**********************************************************************************
// Delegates
//**********************************************************************************

/**
 * Provides script-only child classes the opportunity to handle input key events received from the viewport.
 * This delegate is ONLY called when input is being routed natively from the GameViewportClient
 * (i.e. NOT when unrealscript calls the InputKey native unrealscript function on this Interaction).
 *
 * @param	ControllerId	the controller that generated this input key event
 * @param	Key				the name of the key which an event occured for (KEY_Up, KEY_Down, etc.)
 * @param	EventType		the type of event which occured (pressed, released, etc.)
 * @param	AmountDepressed	for analog keys, the depression percent.
 * @param	bGamepad		input came from gamepad (ie xbox controller)
 *
 * @return	return TRUE to indicate that the input event was handled.  if the return value is TRUE, the input event will not
 *			be processed by this Interaction's native code.
 */
function bool OnInputKey( int ControllerId, name Key, EInputEvent EventType, optional float AmountDepressed=1.f, optional bool bGamepad )
{
	local delegate<UT4SafeSpawn.OnFireInput> FireDelegate;

	`Log(name$"::OnInputKey - ControllerId:"@ControllerId@" - Key:"@Key@" - EventType:"@EventType@" - AmountDepressed:"@AmountDepressed@" - bGamepad:"@bGamepad,bShowDebug,'UT4SafeSpawn');

	if (bTackKeyInput && FireCallback != none && FireKeys.Find(Key) != INDEX_NONE)
	{
		switch (EventType)
		{
		case IE_Pressed:
	//	case IE_Repeat:
	//	case IE_DoubleClick:
			if (!bFireCalled)
			{
				bFireCalled = true;
				bSuckOnce = true;

				// initially called on press, but moved to on release
				//FireDelegate = FireCallback;
				//FireDelegate();
			}
		
			return true;
			
		case IE_Released:
			if (bFireCalled && bSuckOnce)
			{
				bSuckOnce = false;
				bFireCalled = false;

				// call delegated function in order to trigger the Fire event
				FireDelegate = FireCallback;
				FireDelegate();

				return true;
			}
		}
	}

	return false;
}

//**********************************************************************************
// Exec
//**********************************************************************************

exec function SafeSpawn(optional string command)
{
	class'UT4SafeSpawn'.static.ProcessCommand(PlayerOwner, command);
}

//**********************************************************************************
// Private functions
//**********************************************************************************

function BlockInput(bool bBlock)
{
	if (bBlock)
	{
		bTackKeyInput = true;
		bFireCalled = false;
		bSuckOnce = false;
	}
	else
	{
		bTackKeyInput = false;
	}
}

//**********************************************************************************
// Private functions
//**********************************************************************************

function array<name> GetKeys(PlayerController PC)
{
	local int BindIndex, CommandIndex;
	local KeyBind Bind;
	local bool bKeySet;
	local array<name> keysm;

	if (PC == none)
		return DefaultFireKeys;

	if (PC.PlayerInput == none)
		return DefaultFireKeys;

	for(BindIndex = PC.PlayerInput.Bindings.Length-1;BindIndex >= 0;BindIndex--)
	{
		Bind = PC.PlayerInput.Bindings[BindIndex];

		// ignore xbox keybindings
		if (Left(Bind.Name, 4) ~= "Xbox")
			continue;

		for(CommandIndex=0; CommandIndex<FireCommands.Length; CommandIndex++)
		{
			if(Bind.Command ~= FireCommands[CommandIndex])
			{
				keysm.AddItem(Bind.Name);
				bKeySet = true;
			}
		}
	}

	if (bKeySet)
	{
		return keysm;
	}

	return DefaultFireKeys;
}

DefaultProperties
{
`if(`notdefined(FINAL_RELEASE))
	bShowDebug=false
`endif

	OnReceivedNativeInputKey=OnInputKey

	FireCommands.Add("GBA_Fire")
	FireCommands.Add("GBA_AltFire")

	DefaultFireKeys.Add("LeftMouseButton")
	DefaultFireKeys.Add("RightMouseButton")

}
