extends SceneTree
## Rasterize brand SVGs to PNGs (headless): godot --headless --path . -s res://tools/brand/rasterize.gd
const JOBS := [
	["res://assets/brand/icon.svg", "res://assets/brand/icon_512.png", 2.0],
	["res://assets/brand/icon.svg", "res://assets/brand/icon_256.png", 1.0],
	["res://assets/brand/icon.svg", "res://assets/brand/icon_64.png", 0.25],
	["res://assets/brand/logo_wide.svg", "res://assets/brand/logo_wide.png", 1.0],
	["res://assets/brand/logo_stacked.svg", "res://assets/brand/logo_stacked.png", 1.0],
]
func _init() -> void:
	for j in JOBS:
		var img := Image.new()
		var err := img.load_svg_from_string(FileAccess.get_file_as_string(j[0]), j[2])
		if err == OK:
			err = img.save_png(j[1])
		print("%s -> %s: %s (%dx%d)" % [j[0], j[1], error_string(err), img.get_width(), img.get_height()])
	quit()
