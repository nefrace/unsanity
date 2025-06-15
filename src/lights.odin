package main

import rl "vendor:raylib"


Light :: struct {
	enabled:         i32,
	used:            bool,
	distanceNear:    f32,
	distanceFar:     f32,
	power:           f32,
	position:        [3]f32,
	color:           [4]f32,
	enabledLoc:      i32,
	distanceNearLoc: i32,
	distanceFarLoc:  i32,
	powerLoc:        i32,
	positionLoc:     i32,
	colorLoc:        i32,
	shader:          ^rl.Shader,
}

light_find_unused :: proc() -> (^Light, int) {
	for &light, i in lights {
		if light.enabled == 0 do return &light, i
	}
	return nil, -1
}

light_new :: proc(
	shader: ^rl.Shader,
	pos: [3]f32,
	distanceNear: f32 = 0,
	distanceFar: f32 = 10,
	power: f32 = 1,
	color: [4]f32 = {1, 1, 1, 1},
) -> ^Light {
	light, id := light_find_unused()
	if light == nil do return nil

	light.enabled = 1
	light.position = pos
	light.distanceNear = distanceNear
	light.distanceFar = distanceFar
	light.power = power
	light.color = color
	light.shader = shader

	light_set_uniforms(light, auto_cast id)
	light_update_uniforms(light)

	return light
}

light_destroy :: proc(light: ^Light) {
	if light.enabled == 0 do return
	light.enabled = 0
	light.used = false
	light_update_uniforms(light)
}


light_set_uniforms :: proc(light: ^Light, i: i32) {
	light.enabledLoc = rl.GetShaderLocation(light.shader^, rl.TextFormat("lights[%i].enabled", i))
	light.distanceNearLoc = rl.GetShaderLocation(
		light.shader^,
		rl.TextFormat("lights[%i].distanceNear", i),
	)
	light.distanceFarLoc = rl.GetShaderLocation(
		light.shader^,
		rl.TextFormat("lights[%i].distanceFar", i),
	)
	light.powerLoc = rl.GetShaderLocation(light.shader^, rl.TextFormat("lights[%i].power", i))
	light.positionLoc = rl.GetShaderLocation(
		light.shader^,
		rl.TextFormat("lights[%i].position", i),
	)
	light.colorLoc = rl.GetShaderLocation(light.shader^, rl.TextFormat("lights[%i].color", i))
}

light_update_uniforms :: proc(light: ^Light) {
	rl.SetShaderValue(light.shader^, light.enabledLoc, &(light.enabled), .INT)
	rl.SetShaderValue(light.shader^, light.distanceNearLoc, &(light.distanceNear), .FLOAT)
	rl.SetShaderValue(light.shader^, light.distanceFarLoc, &(light.distanceFar), .FLOAT)
	rl.SetShaderValue(light.shader^, light.powerLoc, &(light.power), .FLOAT)
	rl.SetShaderValue(light.shader^, light.enabledLoc, &(light.enabled), .INT)
	rl.SetShaderValue(light.shader^, light.enabledLoc, &(light.enabled), .INT)
	rl.SetShaderValue(light.shader^, light.positionLoc, &(light.position), .VEC3)
	rl.SetShaderValue(light.shader^, light.colorLoc, &(light.color), .VEC4)
}

move_light :: proc(light: ^Light, pos: [3]f32) {
	light.position = pos
	rl.SetShaderValue(light.shader^, light.positionLoc, &(light.position), .VEC3)
}

clear_lights :: proc() {
	for &light in lights {
		light_destroy(&light)
	}
}

MAX_LIGHTS :: 32

lights := [MAX_LIGHTS]Light{}

