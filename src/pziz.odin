package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

PzizState :: enum {
	CHASE,
	DEAD,
}

Pziz :: struct {
	using enemy:        Enemy,
	animation:          rl.ModelAnimation,
	velocity:           vec3,
	frame:              f32,
	rotation:           f32,
	state:              PzizState,
	is_attacking:       bool,
	sound_pziz_screech: rl.Sound,
	sound_pziz_dead:    rl.Sound,
	sound_swing:        rl.Sound,
	sound_hit:          rl.Sound,
}

pziz_model: rl.Model
pziz_animations: []rl.ModelAnimation
pziz_animations_named: map[string]rl.ModelAnimation
sound_pziz_screech: rl.Sound
sound_pziz_dead: rl.Sound

pziz_init_resourecs :: proc() {
	// EnemyShader = rl.LoadShader(none, "assets/shaders/fshader_blooded.glsl")
	// EnemyShader = rl.LoadShader(nil, "assets/shaders/fshader.glsl")

	sound_pziz_screech = rl.LoadSound("assets/sfx/screech.ogg")
	sound_pziz_dead = rl.LoadSound("assets/sfx/demon_dead.ogg")

	pziz_path :: "assets/models/pziz.glb"
	pziz_model = rl.LoadModel(pziz_path)
	set_model_shader(&pziz_model, WorldShader)
	animation_count: i32 = 0
	animations := rl.LoadModelAnimations(pziz_path, &animation_count)
	pziz_animations = animations[:animation_count]
	for &animation, i in pziz_animations {
		valid := rl.IsModelAnimationValid(pziz_model, animation)
		fmt.printf("pziz ANIMATION %d, %b, %s\n", i, valid, animation.name)
		if valid {
			pziz_animations_named[string(animation.name[:])] = animation
		}
	}
}

pziz_free_resources :: proc() {
	rl.UnloadModelAnimations(raw_data(pziz_animations), i32(len(pziz_animations)))
	rl.UnloadModel(pziz_model)
	rl.UnloadSound(sound_pziz_screech)
	rl.UnloadSound(sound_pziz_dead)
}

pziz_spawn :: proc(game: ^Game, position: vec3) -> ^Pziz {
	pziz := new(Pziz)
	pziz.type = Enemy
	pziz.enemy_type = Pziz
	pziz.position = position
	pziz.health = 1
	pziz.radius = 1
	pziz.update = pziz_update
	pziz.draw = pziz_draw
	pziz.game = game
	pziz.state = .CHASE
	pziz.animation = pziz_animations[0]
	pziz.frame = rand.float32_range(0, 5000)
	pziz.sound_pziz_screech = rl.LoadSoundAlias(sound_pziz_screech)
	pziz.sound_pziz_dead = rl.LoadSoundAlias(sound_pziz_dead)
	pziz.sound_swing = rl.LoadSoundAlias(sound_swing)
	pziz.sound_hit = rl.LoadSoundAlias(sound_hit)
	append(&enemy_list, pziz)
	return pziz
}

pziz_update :: proc(enemy: ^Enemy, delta: f32) {
	using pziz := transmute(^Pziz)enemy
	hit_timer = max(hit_timer - delta, 0)
	frame += 60 * delta
	overframe := i32(frame) >= pziz.animation.frameCount

	diff := game.player.position - position
	dist := linalg.length(diff)
	volume := linalg.smoothstep(f32(20), f32(10), dist)
	rl.SetSoundVolume(pziz.sound_pziz_screech, volume)
	rl.SetSoundVolume(pziz.sound_pziz_dead, volume)
	rl.SetSoundVolume(pziz.sound_swing, volume)
	rl.SetSoundVolume(pziz.sound_hit, volume)

	if health <= 0 && state != .DEAD {
		state = .DEAD
		frame = 0
		grid_remove(&game.grid, pziz)
		rl.PlaySound(pziz.sound_pziz_dead)
		if rand.float32() < 0.1 && len(pills) < 2 {
			pill_spawn(position)
		}
		animation = pziz_animations[8]
	}
	switch pziz.state {
	case .CHASE:
		grid_remove(&game.grid, pziz)
		defer grid_add(&game.grid, pziz)
		if overframe {
			frame -= f32(animation.frameCount)
		}
		velocity += linalg.normalize(diff) * 5 * delta
		velocity = rl.Vector3ClampValue(velocity, 0, 5)
		position += velocity * delta
		objects := grid_query_vec2(&game.grid, position.xz, true)
		for &obj in objects {
			if obj == pziz do continue
			if obj.type == Player do continue
			diff := position - obj.position
			if obj.type == Enemy {
				en := transmute(^Enemy)obj
				if en.health <= 0 do continue
				if en.enemy_type == Pziz {
					velocity -= linalg.normalize(diff) * delta * 3
					continue
				}
			}
			if obj.type == Tree {
				diff.y = 0
			}
			dist := linalg.length(diff)
			if dist < obj.radius + radius * 2 {
				position -= linalg.normalize0(diff) * (dist - radius * 2 - obj.radius)
				velocity = linalg.projection(velocity, linalg.normalize(diff))
			}
		}
		if position.y < 0.5 {
			position.y = 0.5
			velocity.y = -velocity.y
		}
		if dist < radius + game.player.radius + 3 && !rl.IsSoundPlaying(pziz.sound_pziz_screech) {
			rl.PlaySound(pziz.sound_pziz_screech)
			frame = 0
			animation = pziz_animations[3]
		}
		rotation = -linalg.atan2(diff.y, diff.x)
	case .DEAD:
		dead_timer += delta
		if dead_timer > 10 {
			position.y -= 0.5 * delta
			if position.y <= -1 {
				enemy_free(pziz)
			}
		} else {
			velocity.xz = 0
			velocity.y -= 10 * delta
			position += velocity * delta
			if position.y <= 0.3 {
				position.y = 0.3
				velocity.y = -velocity.y * 0.3
			}

		}
		if overframe {
			frame = f32(animation.frameCount) - 1
		}


	}
	// frame = 0

	// if i32(frame) >= pziz.animation.frameCount {
	// 	frame -= f32(pziz.animation.frameCount)
	// }
}

pziz_draw :: proc(enemy: ^Enemy) {
	using pziz := transmute(^Pziz)enemy

	dist := linalg.length2(game.player.position.xz - position.xz)
	// if dist < 400 || health <= 0 {
	rl.UpdateModelAnimation(pziz_model, pziz.animation, i32(pziz.frame))
	// } else if i32(frame) % 2 == 0 {
	// rl.UpdateModelAnimation(pziz_model, pziz.animation, i32(pziz.frame))

	// }

	color := rl.RED
	if hit_timer > 0 {
		color = rl.BLACK
	}
	quat := linalg.quaternion_from_forward_and_up_f32(velocity, {0, 1, 0})
	axis, angle := rl.QuaternionToAxisAngle(quat)
	rlgl.PushMatrix()

	offset := vec3{0, -1, 0}
	if state == .DEAD {
		offset = {}
	}
	rl.DrawModelEx(pziz_model, position + offset, axis, linalg.to_degrees(angle), 0.2, color)

	rlgl.PopMatrix()


}

