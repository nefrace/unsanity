#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"


Player :: struct {
	using object:     Object,
	ammo:             i8,
	shoot_timer:      f32,
	reload_timer:     f32,
	velocity:         vec3,
	target:           vec3,
	look_angles:      vec2,
	cam_height:       f32,
	cam:              rl.Camera3D,
	light:            ^Light,
	bobbing:          f32,
	bobbing_timer:    f32,
	gun_down:         f32,
	gun_tween:        ^ease.Flux_Tween(f32),
	sanity:           f32,
	shoot_flash:      f32,
	is_dead:          bool,
	is_crazy:         bool,
	camera_tilt:      f32,
	snow_sound_index: int,
	game:             ^Game,
}


revolver_model: rl.Model

step_sounds: [2]rl.Sound
sound_shoot: rl.Sound
sound_reload: rl.Sound
sound_death: rl.Sound
sound_crazy: rl.Sound

player_init :: proc() {
	revolver_model = rl.LoadModel("assets/models/revolver.glb")
	step_sounds[0] = rl.LoadSound("assets/sfx/step1.ogg")
	step_sounds[1] = rl.LoadSound("assets/sfx/step2.ogg")
	sound_shoot = rl.LoadSound("assets/sfx/shoot.ogg")
	rl.SetSoundVolume(sound_shoot, 0.5)
	sound_reload = rl.LoadSound("assets/sfx/reload.ogg")
	rl.SetSoundVolume(sound_reload, 0.5)
	sound_death = rl.LoadSound("assets/sfx/death.ogg")
	sound_crazy = rl.LoadSound("assets/sfx/crazy.ogg")
}

player_free :: proc() {
	rl.UnloadModel(revolver_model)
	rl.UnloadSound(step_sounds[0])
	rl.UnloadSound(step_sounds[1])
	rl.UnloadSound(sound_shoot)
	rl.UnloadSound(sound_reload)
	rl.UnloadSound(sound_death)
	rl.UnloadSound(sound_crazy)
}

player_spawn :: proc(game: ^Game, position: vec3) -> Player {
	player := Player {
		game = game,
		radius = 0.5,
		height = 2,
		ammo = 6,
		type = Player,
		position = position,
		cam_height = 1.3,
		gun_down = 3,
		cam = rl.Camera3D{fovy = 90, up = {0, 1, 0}, projection = .PERSPECTIVE},
		light = light_new(&WorldShader, {}, 0, 20, 0.8, {1, 0.9, 0.5, 1}),
	}
	move_light(player.light, player.cam.position)
	player.cam.up = rl.Vector3Normalize({0, 1, 0})
	player.cam.target = {0, player.cam_height, 1}
	player.cam.position = position + vec3{0, player.cam_height, 0}
	// grid_add(&game.grid, &player)
	return player
}

player_die :: proc(using player: ^Player, sound: rl.Sound = sound_death) {
	if is_dead do return
	_ = ease.flux_to(&game.tweens, &(cam_height), 0.3, .Bounce_Out)
	_ = ease.flux_to(&game.tweens, &camera_tilt, 1)
	is_dead = true
	rl.EnableCursor()
	rl.PlaySound(sound_death)
	rl.StopMusicStream(game.music["nbtf"])

}

player_update :: proc(using player: ^Player, delta: f32) {
	bobbing_timer += delta
	if bobbing_timer > 2 do bobbing_timer -= 2
	grid_remove(&game.grid, player)
	defer grid_add(&game.grid, player)

	shoot_flash = math.max(shoot_flash - delta * 5, 0)
	shoot_timer = math.max(shoot_timer - delta, 0)
	if reload_timer > 0 {
		reload_timer -= delta
		if reload_timer <= 0 {
			ammo = 6
			gun_tween = ease.flux_to(&game.tweens, &gun_down, 0, .Back_Out, 300 * time.Millisecond)
		}
	}
	rl.SetShaderValue(WorldShader, game.shaderLocs["flash"], &shoot_flash, .FLOAT)
	rot :=
		linalg.quaternion_from_euler_angle_y_f32(look_angles.y) *
		linalg.quaternion_from_euler_angle_x_f32(look_angles.x)

	forward := linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{0, 0, 1})
	right := linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{1, 0, 0})
	// forward = linalg.normalize(vec3{forward.x, 0, forward.z})
	// right = linalg.normalize(vec3{right.x, 0, right.z})
	//
	if !is_dead {
		if rl.IsMouseButtonPressed(.LEFT) && shoot_timer <= 0 && reload_timer <= 0 && ammo > 0 {
			ammo -= 1
			shoot_timer = 0.3
			shoot_flash = 1
			rl.PlaySound(sound_shoot)
			player_shoot(player)
		}
		if rl.IsKeyPressed(.R) && ammo < 6 && shoot_timer <= 0 && reload_timer <= 0 {
			gun_tween = ease.flux_to(&game.tweens, &gun_down, 1, .Back_Out, 300 * time.Millisecond)
			rl.PlaySound(sound_reload)
			reload_timer = 3
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
		if bobbing <= -0.08 {
			if !rl.IsSoundPlaying(step_sounds[0]) {
				rl.PlaySound(step_sounds[0])

			}
		}

		position += velocity * delta
		rad2 := radius * radius
		coords := grid_world_to_local(&game.grid, position.xz)
		objs := grid_query(&game.grid, coords, true)
		for &obj in objs {
			if obj.type == Enemy {
				e := transmute(^Enemy)obj
				if e.health <= 0 do continue
			}
			diff := position.xz - obj.position.xz
			dist := linalg.length(diff)
			if dist < obj.radius + radius {
				position.xz -= linalg.normalize(diff) * (dist - radius - obj.radius)
			}
		}
	} else {
		if camera_tilt >= 0.9 {
			if rl.IsMouseButtonPressed(.LEFT) {
				game_restart(game)
			}
		}
	}
	for &pill in pills {
		diff := position.xz - pill.position.xz
		dist: f32 = linalg.length(diff)
		if dist < 1 {
			pill_destroy(&pill)
			rl.PlaySound(pill_sound)
			game.eyelids_speed = 5
			game.eyelids_action = .PILLS
			break
		}
	}
	cam.up = rl.Vector3Normalize({0 + camera_tilt, 1 + camera_tilt, 0})
	cam.position = position + vec3{0, cam_height + bobbing, 0}
	cam.target = cam.position + forward
	move_light(light, cam.position)
}

player_draw :: proc(using player: ^Player) {


	// if reload_timer <= 0 { 	// Revolver
	rlgl.PushMatrix()
	rlgl.Translatef(cam.position.x, cam.position.y - bobbing * 0.1, cam.position.z)
	rlgl.Rotatef(linalg.to_degrees(look_angles.y), 0, 1, 0)
	rlgl.Rotatef(linalg.to_degrees(look_angles.x), 1, 0, 0)
	rlgl.PushMatrix()
	rlgl.Translatef(-0.3, -0.1, 1.0)
	rlgl.Rotatef(-90, 1, 0, 0)
	if shoot_timer > 0.28 {
		rl.DrawCylinder({}, 0.01, 0.1, 0.3, 7, rl.YELLOW)
	}
	rlgl.PopMatrix()
	rlgl.Translatef(-0.1 * gun_down, -0.5 * gun_down - 1 * camera_tilt, -0.1 * gun_down)
	rlgl.Rotatef(-gun_down * 40, 1, 0, 0)
	rlgl.Rotatef(-shoot_timer / 0.3 * 45, 1, 0, 0)
	rlgl.Translatef(0, shoot_timer * 0.3, -shoot_timer)
	rl.DrawModel(revolver_model, {-0.3, -0.3, 0.3}, 0.3, rl.WHITE)
	rlgl.PopMatrix()
	// }
}


player_shoot :: proc(using player: ^Player) {
	rot :=
		linalg.quaternion_from_euler_angle_y_f32(look_angles.y) *
		linalg.quaternion_from_euler_angle_x_f32(look_angles.x)
	forward := linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{0, 0, 1})
	right := linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{1, 0, 0})
	ray := rl.Ray {
		position  = cam.position,
		direction = linalg.normalize0(forward),
	}

	nearest: ^Object = nil
	dist: f32 = 9999

	pos := position.xz
	travel: f32 = 0
	// obj := make([dynamic]^Object, context.temp_allocator)
	for travel < 30 {
		objs := grid_query(&game.grid, pos, true)
		col: rl.RayCollision
		traveling: for &o in objs {
			switch o.type {
			case Enemy:
				e := transmute(^Enemy)o
				if e.health <= 0 do continue traveling
				col = rl.GetRayCollisionSphere(ray, o.position, o.radius)

			case Tree:
				t := transmute(^Tree)o
				mat :=
					rl.MatrixTranslate(t.position.x, t.position.y, t.position.z) *
					rl.MatrixRotateY(linalg.to_radians(t.rotation)) *
					rl.MatrixScale(t.scale.x, t.scale.y, t.scale.z)
				col = rl.GetRayCollisionMesh(ray, game.models["tree"].meshes[0], mat)
			}

			if col.hit && col.distance < dist {
				dist = col.distance
				nearest = o
			}
		}
		if nearest != nil && dist > 0 {
			if nearest.type == Enemy {
				e := transmute(^Enemy)nearest
				enemy_damage(e, 1)
			}
			break
		}
		travel += game.grid.cell_size / 2
		pos += ray.direction.xz * game.grid.cell_size / 2

	}

}

