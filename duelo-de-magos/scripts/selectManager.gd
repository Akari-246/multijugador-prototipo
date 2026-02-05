extends Node

signal deselect_all

var selected_avatar: bool = false
var avatar: Avatar = null

func select_avatar(new_avatar: Avatar):
	avatar = new_avatar
	selected_avatar = true
	deselect_all.emit()
