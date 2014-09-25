class UT4SafeSpawnGameRules extends GameRules;

var class<Inventory> InventoryCheckClass;

private function bool HasInventory(Pawn Other, optional out Inventory inv)
{
	inv = Other.FindInventoryType(InventoryCheckClass, true);
	return (inv != none);
}

function NetDamage(int OriginalDamage, out int Damage, pawn Injured, Controller InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	super.NetDamage(OriginalDamage, Damage, Injured, InstigatedBy, HitLocation, Momentum, DamageType);
	
	// check if the player helds the Damage helper inventory
	// which will block the damage
	if (!DamageType.default.bCausedByWorld && HasInventory(Injured))
	{
		Momentum = vect(0,0,0);
		Damage = 0;
	}
}

/** OverridePickupQuery()
 * when pawn wants to pickup something, gamerules given a chance to modify it.  If this function
 * returns true, bAllowPickup will determine if the object can be picked up.
 * @param Other the Pawn that wants the item
 * @param ItemClass the Inventory class the Pawn can pick up
 * @param Pickup the Actor containing that item (this may be a PickupFactory or it may be a DroppedPickup)
 * @param bAllowPickup (out) whether or not the Pickup actor should give its item to Other (0 == false, anything else == true)
 * @return whether or not to override the default behavior with the value of
 */
function bool OverridePickupQuery(Pawn Other, class<Inventory> ItemClass, Actor Pickup, out byte bAllowPickup)
{
	local Inventory inv;

	if (HasInventory(Other, inv))
	{
		// don't disable ghost protection if player attempted to pickup
		// Health packs if they aren't adding health (if not SuperHealth)

		if (UTHealthPickupFactory(Pickup) != none && (!UTHealthPickupFactory(Pickup).bSuperHeal || Other.Health != Other.HealthMax))
		{
			super.OverridePickupQuery(Other, ItemClass, Pickup, bAllowPickup);
			bAllowPickup = 0;
			return true;
		}

		// also ammo packs shouldn't remove protection
		if (UTAmmoPickupFactory(Pickup) == none)
		{
			// destroy inventory if there's still one
			if (!inv.bDeleteMe && !inv.bPendingDelete)
			{
				if (UTTimedPowerup(inv) != none)
					UTTimedPowerup(inv).TimeExpired(); // call TimeExpired to trigger PowerupOver sound
				else
					inv.Destroy();
			}
		}
	}

	return super.OverridePickupQuery(Other, ItemClass, Pickup, bAllowPickup);
}


DefaultProperties
{
}
