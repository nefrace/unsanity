package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

Enemy :: struct {
	game:       ^Game,
	position:   vec3,
	radius:     f32,
	health:     f32,
	dead_timer: f32,
	active:     bool,
	update:     proc(enemy: ^Enemy, delta: f32),
	draw:       proc(enemy: ^Enemy),
}

DemonState :: enum {
	CHASE,
	ATTACK,
	DEAD,
}

Demon :: struct {
	using enemy: Enemy,
	animation:   rl.ModelAnimation,
	frame:       f32,
	rotation:    f32,
	state:       DemonState,
}

enemy_list: [dynamic]^Enemy

clear_enemies :: proc() {
	for &enemy in enemy_list {

		free(enemy)
	}
	clear(&enemy_list)
}

EnemyShader: rl.Shader

demon_model: rl.Model
demon_animations: []rl.ModelAnimation

demon_init_resourecs :: proc() {
	// EnemyShader = rl.LoadShader(none, "assets/shaders/fshader_blooded.glsl")
	// EnemyShader = rl.LoadShader(nil, "assets/shaders/fshader.glsl")
	demon_path :: "assets/models/monsterg.glb"
	demon_model = rl.LoadModel(demon_path)
	set_model_shader(&demon_model, WorldShader)
	animation_count: i32 = 0
	animations := rl.LoadModelAnimations(demon_path, &animation_count)
	demon_animations = animations[:animation_count]
	for &animation, i in demon_animations {
		valid := rl.IsModelAnimationValid(demon_model, animation)
		fmt.printf("DEMON ANIMATION %d, %b, %s\n", i, valid, animation.name)
	}
}

demon_free_resources :: proc() {
	rl.UnloadModelAnimations(raw_data(demon_animations), i32(len(demon_animations)))
	rl.UnloadModel(demon_model)
}

demon_spawn :: proc(game: ^Game, position: vec3) -> ^Demon {
	demon := new(Demon)
	demon.position = position
	demon.health = 5
	demon.active = true
	demon.radius = 2
	demon.update = demon_update
	demon.draw = demon_draw
	demon.game = game
	demon.state = .CHASE
	demon.animation = demon_animations[5]
	demon.frame = rand.float32_range(0, 5000)
	append(&enemy_list, demon)
	return demon
}

demon_update :: proc(enemy: ^Enemy, delta: f32) {
	using demon := transmute(^Demon)enemy
	frame += 60 * delta
	overframe := i32(frame) >= demon.animation.frameCount

	diff := game.player.position.xz - position.xz
	dist := linalg.length(diff)
	if health <= 0 && state != .DEAD {
		state = .DEAD
		frame = 0
		animation = demon_animations[7]
	}
	switch demon.state {
	case .CHASE:
		if overframe {
			frame -= f32(animation.frameCount)
		}
		velocity := linalg.normalize(diff) * 3
		position.xz += velocity * delta
		for &solid in game.solids {
			diff := position.xz - solid.position.xz
			dist := linalg.length(diff)
			if dist < solid.radius + radius {
				position.xz -= linalg.normalize0(diff) * (dist - radius - solid.radius)
			}
		}
		for &solid in enemy_list {
			if solid == demon do continue
			if solid.health <= 0 do continue
			diff := position.xz - solid.position.xz
			dist := linalg.length(diff)
			if dist < solid.radius + radius {
				position.xz -= linalg.normalize0(diff) * (dist - radius - solid.radius)
			}
		}
		if dist < radius + game.player.radius + 2 {
			state = .ATTACK
			frame = 0
			animation = demon_animations[6]
		}
		rotation = -linalg.atan2(diff.y, diff.x)
	case .ATTACK:
		if i32(frame) >= 50 {
			if i32(frame) == 50 && dist < radius + game.player.radius + 3 {
				game.player.velocity.xz = linalg.normalize0(diff) * 3
			}
		} else {
			rotation = -linalg.atan2(diff.y, diff.x)
		}
		if overframe {
			frame = 0
			state = .CHASE
			animation = demon_animations[5]
		}
	case .DEAD:
		if overframe {
			frame = f32(animation.frameCount) - 1
		}


	}
	// frame = 0

	// if i32(frame) >= demon.animation.frameCount {
	// 	frame -= f32(demon.animation.frameCount)
	// }
}

demon_draw :: proc(enemy: ^Enemy) {
	using demon := transmute(^Demon)enemy

	rl.UpdateModelAnimation(demon_model, demon.animation, i32(demon.frame))

	rl.DrawModelEx(demon_model, position, {0, 1, 0}, linalg.to_degrees(rotation) + 90, 0.2, rl.RED)
	// rl.DrawSphereWires(position + {0, 0.3, 0}, radius, 4, 4, rl.RED)


}

