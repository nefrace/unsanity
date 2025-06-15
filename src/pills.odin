package main


import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

Pill :: struct {
	using object: Object,
	timer:        f32,
}

pills: [dynamic]Pill
pill_model: rl.Model
pill_sound: rl.Sound

pills_init :: proc() {
	pill_model = rl.LoadModel("assets/models/pills.glb")
	set_model_shader(&pill_model, WorldShader)
	pill_sound = rl.LoadSound("assets/sfx/glug.ogg")
}

pills_free :: proc() {
	rl.UnloadModel(pill_model)
	rl.UnloadSound(pill_sound)
}

pill_spawn :: proc(position: vec3) {
	pill := Pill {
		position = position,
		radius   = 1,
		type     = Pill,
	}
	append(&pills, pill)
}

pill_destroy :: proc(pill: ^Pill) {
	for &p, i in pills {
		if &p == pill {
			unordered_remove(&pills, i)
			break
		}
	}
}

pills_clear :: proc() {
	clear(&pills)
}

pill_update :: proc(pill: ^Pill, delta: f32) {
	pill.timer += delta
}

pill_draw :: proc(pill: ^Pill) {
	// fmt.println("drawing pill", pill.position)
	bob := linalg.sin(pill.timer * linalg.PI * 2) * 0.3
	rl.DrawModelEx(
		pill_model,
		pill.position + {0, 1 + bob, 0},
		{0, 1, 0},
		linalg.to_degrees(pill.timer * linalg.PI),
		0.1,
		rl.RED,
	)
}

