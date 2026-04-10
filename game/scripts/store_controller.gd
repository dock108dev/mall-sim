## Base controller for all store types, providing shared slot, fixture, and area queries.
class_name StoreController
extends Node

var store_type: String = ""

var _slots: Array[Node] = []
var _fixtures: Array[Node] = []
var _register_area: Area3D = null
var _entry_area: Area3D = null


func _ready() -> void:
	_collect_fixtures()
	_collect_slots()
	_collect_areas()
	_build_decorations()


## Returns all ShelfSlot children across all fixtures.
func get_all_slots() -> Array[Node]:
	return _slots


## Returns slots that currently hold an item.
func get_occupied_slots() -> Array[Node]:
	var occupied: Array[Node] = []
	for slot: Node in _slots:
		if slot.has_method("is_occupied") and slot.is_occupied():
			occupied.append(slot)
	return occupied


## Returns slots that are currently empty.
func get_empty_slots() -> Array[Node]:
	var empty: Array[Node] = []
	for slot: Node in _slots:
		if not slot.has_method("is_occupied") or not slot.is_occupied():
			empty.append(slot)
	return empty


## Finds a slot by its slot_id property, or null if not found.
func get_slot_by_id(slot_id: String) -> Node:
	for slot: Node in _slots:
		if slot.get("slot_id") == slot_id:
			return slot
	return null


## Returns the register interaction zone, or null if none found.
func get_register_area() -> Area3D:
	return _register_area


## Returns the store entrance zone, or null if none found.
func get_entry_area() -> Area3D:
	return _entry_area


## Returns null by default; subclasses override to provide management UI.
func get_management_ui() -> Control:
	return null


## Returns the number of fixture parent nodes in this store.
func get_fixture_count() -> int:
	return _fixtures.size()


func _collect_fixtures() -> void:
	_fixtures.clear()
	for child: Node in get_children():
		if child.is_in_group("fixture"):
			_fixtures.append(child)


func _collect_slots() -> void:
	_slots.clear()
	for fixture: Node in _fixtures:
		for child: Node in fixture.get_children():
			if child.is_in_group("shelf_slot") or child.get("slot_id") != null:
				_slots.append(child)


func _collect_areas() -> void:
	for child: Node in get_children():
		if child is Area3D:
			if child.is_in_group("register_area"):
				_register_area = child as Area3D
			elif child.is_in_group("entry_area"):
				_entry_area = child as Area3D


func _build_decorations() -> void:
	if store_type.is_empty():
		return
	var node_ref: Variant = self
	if node_ref is Node3D:
		StoreDecorationBuilder.build(node_ref as Node3D, store_type)
