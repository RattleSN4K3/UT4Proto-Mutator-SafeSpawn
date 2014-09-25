class UT4SafeSpawnSettings extends Settings
	abstract;

var localized array<string> PropertyDescriptions;

function string GetSpecialValue(name PropertyName)
{
	local int i;
	local string ret;
	local string propstr;

	propstr = string(PropertyName);
	i = InStr(propstr, "_");
	if (i != INDEX_NONE && Left(propstr, i) ~= "PropertyDescription")
	{
		propstr = Mid(propstr, i+1);
		i = PropertyMappings.Find('Name', name(propstr));
		if (i != INDEX_NONE)
		{
			ret = PropertyDescriptions[i];
		}
	}

	return ret;
}

function SetPropertyValue(name PropertyName, coerce string PropertyValue)
{
	SetPropertyFromStringByName(PropertyName, PropertyValue);
}

function bool GetPropertyValue(name PropertyName, out string PropertyValue)
{
	local int PropId;
	if (GetPropertyId(PropertyName, PropId) && HasProperty(PropId))
	{
		PropertyValue = GetPropertyAsString(PropId);
		return true;
	}
	
	return false;
}

function string OutputBool(bool value)
{
	return value ? "1" : "0";
}

function bool ParseBool(string value, optional bool defaultvalue = false)
{
	local string tmp;
	tmp = Locs(value);
	switch (tmp)
	{
		case "1":
		case "true":
		case "on":
		case "yes":
			return true;
			break;

		case "0":
		case "false":
		case "off":
		case "no":
			return false;
			break;

		default:
			return defaultvalue;
	}
}

function float ParseFloat(string value)
{
	if (InStr(value, ",", false) != INDEX_NONE)
	{
		value = Repl(value, ",", "."); 
	}

	return float(value);
}

DefaultProperties
{
}
