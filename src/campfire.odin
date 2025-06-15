package main

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"


FireParticle :: struct {
	position: vec3,
	velocity: vec3,
	size:     f32,
	lifetime: f32,
	color:    rl.Color,
}
Campfire :: struct {
	using entity: Object,
	game:         ^Game,
	particles:    [20]FireParticle,
	light:        ^Light,
}

spawn_campfire :: proc(game: ^Game, pos: vec3) -> ^Campfire {
	game.campfire = Campfire {
		position = {},
		game     = game,
		type     = Campfire,
		light    = light_new(&WorldShader, {0, 0.5, 0}, 0, 30, 1, {1, 1, 1, 1}),
		radius   = 1,
		height   = 1,
	}
	using cf := &game.campfire
	grid_add(&game.grid, cf)
	for &fire in cf.particles {
		fire.position = {
			rand.float32_range(cf.position.x - cf.radius * 0.8, cf.position.x + cf.radius * 0.8),
			rand.float32_range(cf.position.y, cf.position.y + cf.radius * 0.8),
			rand.float32_range(cf.position.z - cf.radius * 0.8, cf.position.z + cf.radius * 0.8),
		}
		fire.lifetime = rand.float32_range(0, 1)
		fire.size = 1
	}
	return &game.campfire
}

campfire_update :: proc(cf: ^Campfire, delta: f32) {
	for &fire in cf.particles {
		fire.lifetime += delta
		fire.position += fire.velocity * delta
		fire.velocity += {0, 6, 0} * delta
		fire.size =
			f32(
				linalg.smootherstep(0.0, 0.3, f64(fire.lifetime) * 3) *
				linalg.smootherstep(0.3, 0.0, f64(fire.lifetime / 2)),
			) *
			0.6
		if fire.lifetime > 1 {
			fire.position = {
				rand.float32_range(
					cf.position.x - cf.radius * 0.6,
					cf.position.x + cf.radius * 0.6,
				),
				rand.float32_range(cf.position.y, cf.position.y + cf.radius * 0.1),
				rand.float32_range(
					cf.position.z - cf.radius * 0.6,
					cf.position.z + cf.radius * 0.6,
				),
			}
			fire.velocity = {0, rand.float32_range(3, 7), 0}
			fire.lifetime = 0

		}
	}
}

campfire_draw :: proc(using cf: ^Campfire) {
	rl.DrawModel(game.models["camp"], position, 0.1, rl.RED)
	for fire in particles {
		rl.DrawCubeV(fire.position, fire.size, {255, 230, 120, 110})
	}

}

