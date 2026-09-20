class_name RoyaleInventory
extends RefCounted

signal changed

const SLOT_COUNT := 5
var slots: Array[Dictionary] = []
var selected_slot := 0
var ammo := {"light":0, "medium":0, "shells":0, "heavy":0, "rockets":0}
var resources := {"wood":0, "stone":0, "metal":0}

func _init() -> void:
	for i in SLOT_COUNT:
		slots.append({})

func add_weapon(item: Dictionary) -> bool:
	var empty := _first_empty_slot()
	if empty < 0: return false
	var entry := item.duplicate(true)
	entry.kind = "weapon"
	entry.loaded = int(entry.magazine)
	slots[empty] = entry
	ammo[entry.ammo] = int(ammo.get(entry.ammo, 0)) + int(ItemDatabase.AMMO_START.get(entry.ammo, 0))
	changed.emit()
	return true

func add_consumable(id: String, amount: int = 1) -> bool:
	var data: Dictionary = ItemDatabase.CONSUMABLES.get(id, {}).duplicate(true)
	if data.is_empty(): return false
	for slot in slots:
		if slot.get("kind", "") == "consumable" and slot.get("id", "") == id and int(slot.quantity) < int(data.stack):
			slot.quantity = mini(int(data.stack), int(slot.quantity) + amount)
			changed.emit()
			return true
	var empty := _first_empty_slot()
	if empty < 0: return false
	data.kind = "consumable"
	data.id = id
	data.quantity = mini(amount, int(data.stack))
	slots[empty] = data
	changed.emit()
	return true

func add_ammo(type: String, amount: int) -> void:
	ammo[type] = int(ammo.get(type, 0)) + amount
	changed.emit()

func add_resource(type: String, amount: int) -> void:
	resources[type] = clampi(int(resources.get(type, 0)) + amount, 0, 999)
	changed.emit()

func spend_resource(type: String, amount: int) -> bool:
	if int(resources.get(type, 0)) < amount: return false
	resources[type] -= amount
	changed.emit()
	return true

func select(index: int) -> void:
	selected_slot = clampi(index, 0, SLOT_COUNT - 1)
	changed.emit()

func selected() -> Dictionary:
	return slots[selected_slot]

func reload_selected() -> bool:
	var item := selected()
	if item.get("kind", "") != "weapon": return false
	var needed := int(item.magazine) - int(item.loaded)
	var available := int(ammo.get(item.ammo, 0))
	var moved := mini(needed, available)
	if moved <= 0: return false
	item.loaded += moved
	ammo[item.ammo] -= moved
	changed.emit()
	return true

func consume_selected(user) -> bool:
	var item := selected()
	if item.get("kind", "") != "consumable": return false
	if item.has("health"):
		user.health = minf(float(item.get("health_cap", 100.0)), user.health + float(item.health))
	if item.has("shield"):
		user.shield = minf(float(item.get("shield_cap", 100.0)), user.shield + float(item.shield))
	item.quantity -= 1
	if int(item.quantity) <= 0: slots[selected_slot] = {}
	changed.emit()
	return true

func swap_slots(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= SLOT_COUNT or b >= SLOT_COUNT: return
	var temp := slots[a]
	slots[a] = slots[b]
	slots[b] = temp
	changed.emit()

func _first_empty_slot() -> int:
	for i in slots.size():
		if slots[i].is_empty(): return i
	return -1
