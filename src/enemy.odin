package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

Enemy :: struct {
	using object: Object,
	enemy_type:   typeid,
	game:         ^Game,
	health:       f32,
	dead_timer:   f32,
	hit_timer: f32,
	update:       proc(enemy: ^Enemy, delta: f32),
	draw:         proc(enemy: ^Enemy),
}


enemy_list: [dynamic]^Enemy

enemy_damage :: proc(enemy: ^Enemy, dmg: f32) {
	enemy.health -= dmg
	enemy.hit_timer = 0.1
}

enemy_free :: proc(enemy: ^Enemy) {
	for &en, i in enemy_list {
		if en == enemy {
			unordered_remove(&enemy_list, i)
			free(enemy)
		}
	}
}

clear_enemies :: proc() {
	for &enemy in enemy_list {

		free(enemy)
	}
	clear(&enemy_list)
}

