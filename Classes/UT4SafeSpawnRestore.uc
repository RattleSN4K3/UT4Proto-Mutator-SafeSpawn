class UT4SafeSpawnRestore extends UIDataStore;

var LocalPlayer OriginalLP;
var bool bOriginalOverriden;

static function UT4SafeSpawnRestore GetRestore()
{
	local DataStoreClient DSClient;
	local UT4SafeSpawnRestore DS;

	DSClient = class'UIInteraction'.static.GetDataStoreClient();
	if ( DSClient != None )
	{
		DS = UT4SafeSpawnRestore(DSClient.FindDataStore(default.Tag));
		if (DS == none)
		{
			DS = DSClient.CreateDataStore(default.Class);
			DSClient.RegisterDataStore(DS);
		}
	}

	return DS;
}

function Update(LocalPlayer LP, bool bOverriden)
{
	OriginalLP = LP;
	bOriginalOverriden = bOverriden;
}

/**
 * Called when the current map is being unloaded.  Cleans up any references which would prevent garbage collection.
 *
 * @return	TRUE indicates that this data store should be automatically unregistered when this game session ends.
 */
function bool NotifyGameSessionEnded()
{
	`Log(name$"::NotifyGameSessionEnded",,'UT4SafeSpawn');
	`Log(name$"::NotifyGameSessionEnded",,'UT4SafeSpawn');
	`Log(name$"::NotifyGameSessionEnded",,'UT4SafeSpawn');
	`Log(name$"::NotifyGameSessionEnded",,'UT4SafeSpawn');
	`Log(name$"::NotifyGameSessionEnded",,'UT4SafeSpawn');
	`Log(name$"::NotifyGameSessionEnded",,'UT4SafeSpawn');
	`Log(name$"::NotifyGameSessionEnded",,'UT4SafeSpawn');
	`Log(name$"::NotifyGameSessionEnded",,'UT4SafeSpawn');
	`Log(name$"::NotifyGameSessionEnded",,'UT4SafeSpawn');

	if (OriginalLP != none && bOriginalOverriden)
	{
		`Log(name$"::NotifyGameSessionEnded - Restoring PP",,'UT4SafeSpawn');
		OriginalLP.ClearPostProcessSettingsOverride();
	}

	OriginalLP = none;

	// game state data stores should always be unregistered when the match is over.
	return true;
}

DefaultProperties
{
	Tag=UT4Proto_MutatorSafeSpawn
}
