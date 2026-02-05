extends TextureButton

@export var avatar: Avatar
@export var selected_color: Color = Color.GREEN
@export var highlighted_color: Color = Color.YELLOW
@export var selected: bool = false

func _ready() -> void:
	if avatar:
		texture_normal = avatar.image
	SelectManager.deselect_all.connect(deselect)

func _on_mouse_entered() -> void:
	if not selected:
		highlight()

func _on_mouse_exited() -> void:
	if not selected:
		highlight(false)

func _on_pressed() -> void:
	if selected:
		SelectManager.selected_avatar = false
		SelectManager.avatar = null
		selected = false
		highlight(false)
	else:
		SelectManager.select_avatar(avatar)
		selected = true
		highlight()

func highlight(shader_enabled: bool = true):
	#if material:
		#material.set_shader_parameter("outline_color", selected_color if selected else highlighted_color)
		#material.set_shader_parameter("enabled", shader_enabled)
	if shader_enabled:
		modulate = selected_color if selected else highlighted_color
	else:
		modulate = selected_color

func deselect() -> void:
	selected = false
	highlight(false)
