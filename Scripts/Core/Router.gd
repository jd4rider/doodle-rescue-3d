extends Node
## Screen navigation, kept tiny so screens never need to know about each other.

var main: Node


func go(screen: String, payload := {}) -> void:
	if main == null:
		push_warning("Router has no main scene yet")
		return
	main.show_screen(screen, payload)


func back() -> void:
	if main == null:
		return
	main.go_back()


func toast(text: String) -> void:
	if main != null:
		main.show_toast(text)
