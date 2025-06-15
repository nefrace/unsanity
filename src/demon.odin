package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"


DemonState :: enum {
	CHASE,
	ATTACK,
	DEAD,
}

Demon :: struct {
	using enemy:       Enemy,
	animation:         rl.ModelAnimation,
	frame:             f32,
	rotation:          f32,
	state:             DemonState,
	size:              f32,
	speed:             f32,
	sound_demon_growl: rl.Sound,
	sound_demon_dead:  rl.Sound,
	sound_swing:       rl.Sound,
	sound_hit:         rl.Sound,
}

demon_model: rl.Model
demon_animations: []rl.ModelAnimation
demon_animations_named: map[string]rl.ModelAnimation
sound_demon_growl: rl.Sound
sound_demon_dead: rl.Sound
sound_swing: rl.Sound
sound_hit: rl.Sound

demon_init_resourecs :: proc() {
	// EnemyShader = rl.LoadShader(none, "assets/shaders/fshader_blooded.glsl")
	// EnemyShader = rl.LoadShader(nil, "assets/shaders/fshader.glsl")

	sound_demon_growl = rl.LoadSound("assets/sfx/demon_attack.ogg")
	sound_demon_dead = rl.LoadSound("assets/sfx/demon_dead.ogg")
	sound_swing = rl.LoadSound("assets/sfx/swing.ogg")
	sound_hit = rl.LoadSound("assets/sfx/hurt.ogg")

	demon_path :: "assets/models/monsterc.glb"
	demon_model = rl.LoadModel(demon_path)
	set_model_shader(&demon_model, WorldShader)
	animation_count: i32 = 0
	animations := rl.LoadModelAnimations(demon_path, &animation_count)
	demon_animations = animations[:animation_count]
	for &animation, i in demon_animations {
		valid := rl.IsModelAnimationValid(demon_model, animation)
		fmt.printf("DEMON ANIMATION %d, %b, %s\n", i, valid, animation.name)
		if valid {
			demon_animations_named[string(animation.name[:])] = animation
		}
	}
}

demon_free_resources :: proc() {
	rl.UnloadModelAnimations(raw_data(demon_animations), i32(len(demon_animations)))
	rl.UnloadModel(demon_model)
	rl.UnloadSound(sound_demon_growl)
	rl.UnloadSound(sound_demon_dead)
	rl.UnloadSound(sound_swing)
	rl.UnloadSound(sound_hit)
}

demon_spawn :: proc(game: ^Game, position: vec3) -> ^Demon {
	demon := new(Demon)
	demon.type = Enemy
	demon.enemy_type = Demon
	demon.position = position
	demon.size = rand.float32_range(0.3, 1.3)
	demon.health = math.remap_clamped(demon.size, 0.3, 1.3, 0.5, 4)
	demon.speed = math.remap_clamped(demon.size, 0.3, 1.3, 5.0, 1.0)
	demon.radius = 2 * demon.size
	demon.update = demon_update
	demon.draw = demon_draw
	demon.game = game
	demon.state = .CHASE
	demon.animation = demon_animations[7]
	demon.frame = rand.float32_range(0, 5000)
	demon.sound_demon_growl = rl.LoadSoundAlias(sound_demon_growl)
	demon.sound_demon_dead = rl.LoadSoundAlias(sound_demon_dead)
	demon.sound_swing = rl.LoadSoundAlias(sound_swing)
	demon.sound_hit = rl.LoadSoundAlias(sound_hit)
	append(&enemy_list, demon)
	return demon
}

demon_update :: proc(enemy: ^Enemy, delta: f32) {
	using demon := transmute(^Demon)enemy
	hit_timer = max(hit_timer - delta, 0)
	frame += 60 * delta * speed
	overframe := i32(frame) >= demon.animation.frameCount

	diff := game.player.position.xz - position.xz
	dist := linalg.length(diff)
	volume := linalg.smoothstep(f32(20), f32(0), dist)
	rl.SetSoundVolume(demon.sound_demon_growl, volume)
	rl.SetSoundVolume(demon.sound_demon_dead, volume)
	rl.SetSoundVolume(demon.sound_swing, volume)
	rl.SetSoundVolume(demon.sound_hit, volume)

	if health <= 0 && state != .DEAD {
		state = .DEAD
		frame = 0
		grid_remove(&game.grid, demon)
		rl.PlaySound(demon.sound_demon_dead)
		if rand.float32() < 0.1 && len(pills) < 2 {
			pill_spawn(position)
		}
		animation = demon_animations[5]
	}
	switch demon.state {
	case .CHASE:
		grid_remove(&game.grid, demon)
		defer grid_add(&game.grid, demon)
		if overframe {
			frame -= f32(animation.frameCount)
		}
		velocity := linalg.normalize(diff) * 3
		position.xz += velocity * delta * speed
		objects := grid_query_vec2(&game.grid, position.xz, true)
		for &obj in objects {
			if obj == demon do continue
			if obj.type == Demon {
				demon := transmute(^Enemy)obj
				if demon.health <= 0 do continue
			}
			diff := position.xz - obj.position.xz
			dist := linalg.length(diff)
			if dist < obj.radius + radius {
				position.xz -= linalg.normalize0(diff) * (dist - radius - obj.radius)
			}
		}
		if dist < radius + game.player.radius + 1 {
			state = .ATTACK
			rl.PlaySound(demon.sound_demon_growl)
			frame = 0
			animation = demon_animations[4]
		}
		rotation = -linalg.atan2(diff.y, diff.x)
	case .ATTACK:
		if i32(frame) >= 50 {
			if i32(frame) == 50 {
				rl.PlaySound(demon.sound_swing)
				if dist < radius + game.player.radius + 2 {
					game.player.velocity.xz = linalg.normalize0(diff) * 3
					// rl.CloseWindow()
					rl.PlaySound(demon.sound_hit)
					player_die(&game.player)
				}
			}
		} else {
			rotation = -linalg.atan2(diff.y, diff.x)
		}
		if overframe {
			frame = 0
			state = .CHASE
			animation = demon_animations[7]
		}
	case .DEAD:
		dead_timer += delta
		if dead_timer > 10 {
			position.y -= 0.5 * delta
			if position.y <= -1 {
				enemy_free(demon)
			}
		}
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

	dist := linalg.length2(game.player.position.xz - position.xz)
	// if dist < 400 || health <= 0 {
	rl.UpdateModelAnimation(demon_model, demon.animation, i32(demon.frame))
	// } else if i32(frame) % 2 == 0 {
	// rl.UpdateModelAnimation(demon_model, demon.animation, i32(demon.frame))

	// }

	color := rl.RED
	if hit_timer > 0 {
		color = rl.BLACK
	}
	rl.DrawModelEx(
		demon_model,
		position,
		{0, 1, 0},
		linalg.to_degrees(rotation) + 90,
		0.2 * demon.size,
		color,
	)
	// rl.DrawSphereWires(position + {0, 0.3, 0}, radius, 4, 4, rl.RED)


}

