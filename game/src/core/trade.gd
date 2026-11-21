class_name Trade
extends RefCounted
## Barter math. Prices move with both sides' Barter skill, with how the
## trader's people regard you, and with the market (Prices.market): a city
## under siege pays for bread what it once paid for wine. Silver makes up any
## difference.


## How much more than an item's value the trader asks when you buy.
static func buy_factor(player: CharacterSheet, trader: CharacterSheet, standing: int = 0) -> float:
	var f := 1.3 + (trader.skill("barter") - player.skill("barter")) / 150.0 - standing / 200.0
	return clampf(f, 1.0, 2.5)


## What fraction of an item's value the trader pays when you sell.
static func sell_factor(player: CharacterSheet, trader: CharacterSheet, standing: int = 0) -> float:
	return clampf(1.0 / buy_factor(player, trader, standing), 0.35, 0.95)


## One item's price at this factor, in this market.
static func price(id: String, factor: float, market: Dictionary = {}) -> int:
	return maxi(1, int(round(float(DB.item(id).get("value", 0)) * factor * Prices.item_mult(market, id))))


static func value_of(inv: Inventory, factor: float, market: Dictionary = {}) -> int:
	var v := 0.0
	for id in inv.ids():
		v += float(DB.item(id).get("value", 0)) * inv.count(id) * factor * Prices.item_mult(market, id)
	return int(round(v))


## Settles a deal. Returns silver the player pays (positive) or receives
## (negative), or null if neither side can cover the difference.
static func settle(player_offer: Inventory, trader_offer: Inventory, player: CharacterSheet, trader: CharacterSheet, standing: int = 0, market: Dictionary = {}) -> Variant:
	var give := value_of(player_offer, sell_factor(player, trader, standing), market)
	var get_ := value_of(trader_offer, buy_factor(player, trader, standing), market)
	var diff := get_ - give
	if diff > 0 and player.silver < diff:
		return null
	if diff < 0:
		# The trader pays the difference in silver, as far as they can.
		diff = -mini(-diff, trader.silver)
	return diff
