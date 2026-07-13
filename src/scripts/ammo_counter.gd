extends Control

@onready var magazine_label: Label = $HBox/VBox/MagazineLabel
@onready var total_label: Label = $HBox/VBox/TotalLabel

func _ready() -> void:
	pass

func update_ammo(magazine: int, inventory_ammo: int, _ammo_type: String) -> void:
	if magazine_label and total_label:
		magazine_label.text = str(magazine)
		total_label.text = str(inventory_ammo)
