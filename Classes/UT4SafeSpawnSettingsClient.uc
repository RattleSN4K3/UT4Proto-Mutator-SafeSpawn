class UT4SafeSpawnSettingsClient extends UT4SafeSpawnSettings;

function SetSpecialValue(name PropertyName, string NewValue)
{
	local string CurProperty;

	if (PropertyName == 'WebAdmin_Init')
	{
		SetPropertyValue('SwitchToThirdPerson', OutputBool(class'UT4SafeSpawn'.default.SwitchToThirdPerson));
		SetPropertyValue('ApplyPPEffects', OutputBool(class'UT4SafeSpawn'.default.ApplyPPEffects));
		SetPropertyValue('HideCrosshairTemporarely', OutputBool(class'UT4SafeSpawn'.default.HideCrosshairTemporarely));
		SetPropertyValue('IgnoreInputThreshold', class'UT4SafeSpawn'.default.IgnoreInputThreshold);
		
		SetPropertyValue('ShowTime', OutputBool(class'UT4SafeSpawnInventory'.default.ShowTime));
		SetPropertyValue('BarTimeThreshold', class'UT4SafeSpawnInventory'.default.BarTimeThreshold);
		SetPropertyValue('WarningSound', OutputBool(class'UT4SafeSpawnInventory'.default.WarningSound));
	}

	else if (PropertyName == 'WebAdmin_Save')
	{
		If (GetPropertyValue('SwitchToThirdPerson', CurProperty))
			class'UT4SafeSpawn'.default.SwitchToThirdPerson = ParseBool(CurProperty);
		If (GetPropertyValue('ApplyPPEffects', CurProperty))
			class'UT4SafeSpawn'.default.ApplyPPEffects = ParseBool(CurProperty);
		If (GetPropertyValue('HideCrosshairTemporarely', CurProperty))
			class'UT4SafeSpawn'.default.HideCrosshairTemporarely = ParseBool(CurProperty);
		If (GetPropertyValue('IgnoreInputThreshold', CurProperty))
			class'UT4SafeSpawn'.default.IgnoreInputThreshold = ParseFloat(CurProperty);

		class'UT4SafeSpawn'.static.StaticSaveConfig();


		If (GetPropertyValue('ShowTime', CurProperty))
			class'UT4SafeSpawnInventory'.default.ShowTime = ParseBool(CurProperty);
		If (GetPropertyValue('BarTimeThreshold', CurProperty))
			class'UT4SafeSpawnInventory'.default.BarTimeThreshold = ParseFloat(CurProperty);
		If (GetPropertyValue('WarningSound', CurProperty))
			class'UT4SafeSpawnInventory'.default.WarningSound = ParseBool(CurProperty);

		class'UT4SafeSpawnInventory'.static.StaticSaveConfig();
	}
}

DefaultProperties
{
	Properties(0)=(PropertyID=0,Data=(Type=SDT_Int32))
	PropertyMappings(0)=(ID=0,Name="SwitchToThirdPerson",ColumnHeaderText="Switch to ThirdPerson",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(0)="Whether to switch to third person once you spawn as a ghost. The view will be reverted if the time of the protection runs out."

	Properties(1)=(PropertyID=1,Data=(Type=SDT_Int32))
	PropertyMappings(1)=(ID=1,Name="ApplyPPEffects",ColumnHeaderText="Apply PostProcessing effects",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(1)="Whether to apply post-processing effect once you spawn as a ghost. This effect will desaturate the scene. The colors will be reverted if the time of the protection runs out."

	Properties(2)=(PropertyID=2,Data=(Type=SDT_Int32))
	PropertyMappings(2)=(ID=2,Name="HideCrosshairTemporarely",ColumnHeaderText="Hide crosshair",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(2)="Whether to remove/hide the crosshair while being a ghost."

	Properties(3)=(PropertyID=10,Data=(Type=SDT_Int32))
	PropertyMappings(3)=(ID=10,Name="ShowTime",ColumnHeaderText="Show remaining time",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(3)="Whether to show a formatted time if you are a ghost."

	Properties(4)=(PropertyID=11,Data=(Type=SDT_Int32))
	PropertyMappings(4)=(ID=11,Name="BarTimeThreshold",ColumnHeaderText="Bar time threshold ",MappingType=PVMT_Ranged,MinVal=0,MaxVal=999999,RangeIncrement=1.0)
	PropertyDescriptions(4)="The time for which the barshould be drawn. If the ghost protection last 8s for instance and this value is set to 5s, the bar will not be drawn the first 3s."

	Properties(5)=(PropertyID=12,Data=(Type=SDT_Int32))
	PropertyMappings(5)=(ID=12,Name="WarningSound",ColumnHeaderText="Play warning sound",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(5)="Whether to play warning sounds when the protection is about to run out."

	Properties(6)=(PropertyID=3,Data=(Type=SDT_Float))
	PropertyMappings(6)=(ID=3,Name="IgnoreInputThreshold",ColumnHeaderText="Threshold ignoring input",MappingType=PVMT_Ranged,MinVal=-1.0,MaxVal=999999,RangeIncrement=0.2)
	PropertyDescriptions(6)="The time in seconds in which the fire input is ignored after the player respawned. This would preserve being ghost for that specific time if you press your fire-key repeatedly after being killed. Set a value lower than 0 to ignore input the full time."
}
