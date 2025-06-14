package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"


Player :: struct {
	position:      vec3,
	velocity:      vec3,
	target:        vec3,
	look_angles:   vec2,
	radius:        f32,
	cam_height:    f32,
	cam:           rl.Camera3D,
	light:         ^Light,
	bobbing:       f32,
	bobbing_timer: f32,
	sanity:        f32,
	shootFlash:    f32,
	game:          ^Game,
}

player_spawn :: proc(game: ^Game, position: vec3) -> Player {
	player := Player {
		game = game,
		radius = 0.5,
		position = position,
		cam_height = 1.7,
		cam = rl.Camera3D{fovy = 90, up = {0, 1, 0}, projection = .PERSPECTIVE},
		light = light_new(&WorldShader, {}, 0, 20, 0.8, {1, 0.9, 0.5, 1}),
		sanity = 100,
	}
	rl.DisableCursor()
	return player
}

player_update :: proc(using player: ^Player, delta: f32) {
	bobbing_timer += delta
	if bobbing_timer > 2 do bobbing_timer -= 2

	if rl.IsKeyPressed(rl.KeyboardKey.Q) {
		rl.EnableCursor()
	}
	if rl.IsKeyPressed(rl.KeyboardKey.E) {
		rl.DisableCursor()
	}
	shootFlash = math.max(shootFlash - delta * 5, 0)
	rl.SetShaderValue(WorldShader, game.shaderLocs["flash"], &shootFlash, .FLOAT)
	rot :=
		linalg.quaternion_from_euler_angle_y_f32(look_angles.y) *
		linalg.quaternion_from_euler_angle_x_f32(look_angles.x)

	forward := linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{0, 0, 1})
	right := linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{1, 0, 0})
	// forward = linalg.normalize(vec3{forward.x, 0, forward.z})
	// right = linalg.normalize(vec3{right.x, 0, right.z})
	if rl.IsMouseButtonPressed(.LEFT) {
		shootFlash = 1
		ray := rl.Ray {
			position  = cam.position,
			direction = forward,
		}

		nearest: ^Enemy = nil
		dist: f32 = 9999
		for &e in enemy_list {
			if e.health <= 0 do continue
			col := rl.GetRayCollisionSphere(ray, e.position, e.radius)
			if col.hit && col.distance < dist {
				dist = col.distance
				nearest = e
			}
		}
		fmt.println(dist)
		if nearest != nil && dist > 0 {
			nearest.health = 0
		}
	}

	look_angles.y -= rl.GetMouseDelta().x * 0.0015
	look_angles.x += rl.GetMouseDelta().y * 0.0015

	moving := false
	SPEED :: 30
	if rl.IsKeyDown(.W) {
		velocity.xz += forward.xz * delta * SPEED
		moving = true
	}
	if rl.IsKeyDown(.S) {
		velocity.xz -= forward.xz * delta * SPEED
		moving = true
	}
	if rl.IsKeyDown(.D) {
		velocity.xz -= right.xz * delta * SPEED
		moving = true
	}
	if rl.IsKeyDown(.A) {
		velocity.xz += right.xz * delta * SPEED
		moving = true
	}
	velocity.xz = rl.Vector2ClampValue(velocity.xz, 0, 8)
	// damping
	velocity *= 1.0 / (1.0 + delta * 2)

	moving_factor := linalg.length2(velocity) / 25
	bobbing = linalg.sin(bobbing_timer * linalg.PI * 3) * moving_factor * 0.1

	position += velocity * delta
	rad2 := radius * radius
	for &solid in game.solids {
		trad2 := solid.radius * solid.radius
		diff := position.xz - solid.position.xz
		dist := linalg.length(diff)
		if dist < solid.radius + radius {
			position.xz -= linalg.normalize(diff) * (dist - radius - solid.radius)
		}
	}

	cam.position = position + vec3{0, cam_height + bobbing, 0}
	cam.target = cam.position + forward
	move_light(light, cam.position)
}

