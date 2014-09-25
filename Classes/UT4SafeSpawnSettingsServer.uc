class UT4SafeSpawnSettingsServer extends UT4SafeSpawnSettings;

function SetSpecialValue(name PropertyName, string NewValue)
{
	local string CurProperty;

	if (PropertyName == 'WebAdmin_Init')
	{
		SetPropertyValue('GhostProtectionTime', class'UT4SafeSpawnMutator'.default.GhostProtectionTime);
		SetPropertyValue('InitialFireDelay', class'UT4SafeSpawnMutator'.default.InitialFireDelay);
		
		SetPropertyValue('AllowGhostFrag', OutputBool(class'UT4SafeSpawn'.default.AllowGhostFrag));
	}

	else if (PropertyName == 'WebAdmin_Save')
	{
		If (GetPropertyValue('GhostProtectionTime', CurProperty))
			class'UT4SafeSpawnMutator'.default.GhostProtectionTime = ParseFloat(CurProperty);

		If (GetPropertyValue('InitialFireDelay', CurProperty))
			class'UT4SafeSpawnMutator'.default.InitialFireDelay = ParseFloat(CurProperty);

		// save config
		class'UT4SafeSpawnMutator'.static.StaticSaveConfig();


		If (GetPropertyValue('AllowGhostFrag', CurProperty))
			class'UT4SafeSpawn'.default.AllowGhostFrag = ParseBool(CurProperty);
		
		class'UT4SafeSpawn'.static.StaticSaveConfig();
	}
}

DefaultProperties
{
	Properties(0)=(PropertyID=0,Data=(Type=SDT_Float))
	PropertyMappings(0)=(ID=0,Name="GhostProtectionTime",ColumnHeaderText="Ghost Protection time",MappingType=PVMT_Ranged,MinVal=0,MaxVal=999999,RangeIncrement=1)
	PropertyDescriptions(0)="The amout of time a player is protected by being a ghost."

	Properties(1)=(PropertyID=1,Data=(Type=SDT_Int32))
	PropertyMappings(1)=(ID=1,Name="AllowGhostFrag",ColumnHeaderText="Allow Ghost frags",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(1)="Whether to allow fragging enemy players by spawning inside their character."

	Properties(2)=(PropertyID=2,Data=(Type=SDT_Float))
	PropertyMappings(2)=(ID=2,Name="InitialFireDelay",ColumnHeaderText="Initial fire delay",MappingType=PVMT_Ranged,MinVal=0,MaxVal=999999,RangeIncrement=0.2)
	PropertyDescriptions(2)="The delay in seconds a player has to wait after being an active player before being able to shoot."
}
