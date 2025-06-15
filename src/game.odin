package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import "core:time"
import rl "vendor:raylib"

EntityVariant :: union {
	Tree,
	Player,
	Demon,
	Campfire,
}

Object :: struct {
	position: vec3,
	radius:   f32,
	height:   f32,
	type:     typeid,
}


Tree :: struct {
	using entity: Object,
	scale:        vec3,
	rotation:     f32,
}

DownfallType :: enum {
	None,
	Snow,
	Bloodrain,
}
Downfall :: struct {
	using position: vec3,
	velocity:       vec3,
	type:           DownfallType,
}

Solid :: struct {
	position: vec3,
	radius:   f32,
	height:   f32,
}

TransitionAction :: enum {
	PILLS,
	RESTART,
	EXIT,
}

Game :: struct {
	player:         Player,
	campfire:       Campfire,
	insanity:       f32,
	timer:          f32,
	spawn_timer:    f32,
	kills:          int,
	trees:          [500]Tree,
	downfall:       [1200]Downfall,
	grid:           Grid,
	models:         map[string]rl.Model,
	meshes:         map[string]rl.Mesh,
	textures:       map[string]rl.Texture,
	materials:      map[string]rl.Material,
	shaders:        map[string]rl.Shader,
	sounds:         map[string]rl.Sound,
	music:          map[string]rl.Music,
	shaderLocs:     map[string]i32,
	tweens:         ease.Flux_Map(f32),
	eyelids_closed: f32,
	eyelids_speed:  f32,
	eyelids_action: TransitionAction,
	started:        bool,
	pause:          bool,
}
WorldShader: rl.Shader

game_load_model :: proc(game: ^Game, name: string, file: cstring) -> ^rl.Model {
	path := fmt.ctprintf("assets/models/%s", file)
	game.models[name] = rl.LoadModel(path)
	return &game.models[name]
}

game_load_texture :: proc(game: ^Game, name: string, file: cstring) -> ^rl.Texture {
	path := fmt.ctprintf("assets/models/%s", file)
	game.textures[name] = rl.LoadTexture(path)
	return &game.textures[name]
}


game_restart :: proc(using game: ^Game) {
	eyelids_speed = 5
	eyelids_action = .RESTART
}

game_start :: proc(using game: ^Game, is_restart: bool = false) {
	clear_lights()
	grid_clear(&grid)
	ease.flux_clear(&tweens)
	started = false
	pause = false
	game.player = player_spawn(game, {0, 0, -2})
	game.timer = 0
	game.insanity = 0
	PosterizerValue = max(math.remap(game.insanity, 0.3, 1, 8.0, 2.0), 3)
	game.spawn_timer = 0
	// game.eyelids_closed = 0

	// if is_restart {
	// 	game.player.shoot_flash = 3
	// }
	clear_enemies()

	spawn_campfire(game, {})

	for &tree, i in game.trees {
		tree.type = Tree
		for {
			tree.position.x = rand.float32_range(-200, 200)
			tree.position.z = rand.float32_range(-200, 200)
			if linalg.distance(tree.position, vec3{}) > 10 do break
		}
		tree.rotation = rand.float32() * 360
		tree.scale.x = rand.float32_range(0.5, 0.7)
		tree.scale.z = tree.scale.x
		tree.scale.y = rand.float32_range(0.7, 0.8)
		tree.radius = tree.scale.x * 3
		grid_add(&game.grid, &tree)
	}

	for &downfall in game.downfall {
		downfall.position = {
			rand.float32_range(-30, 30),
			rand.float32_range(0, 15),
			rand.float32_range(-30, 30),
		}

		downfall.type = .Snow
	}

	rl.SetMusicVolume(game.music["camp"], 1)
	rl.SetMusicVolume(game.music["rain"], insanity * 1.5)
	rl.SetMusicVolume(game.music["wind"], 1 - insanity)
	rl.SetMusicVolume(game.music["crazy_ambient"], insanity * 0.8)

}

game_init :: proc() -> ^Game {
	game := new(Game)
	WorldShader = rl.LoadShader(
		"assets/shaders/vshader.glsl",
		"assets/shaders/fshader_blooded.glsl",
	)
	game.tweens = ease.flux_init(f32, 16)
	grid_init(&game.grid)
	player_init()
	demon_init_resourecs()

	game.meshes["plane"] = rl.GenMeshPlane(500, 500, 250, 250)
	game.materials["planemat"] = rl.LoadMaterialDefault()
	mat := &game.materials["planemat"]
	mat.shader = WorldShader
	game.shaderLocs["view"] = rl.GetShaderLocation(WorldShader, "viewPos")
	game.shaderLocs["blood"] = rl.GetShaderLocation(WorldShader, "bloodmask")
	game.shaderLocs["ins"] = rl.GetShaderLocation(WorldShader, "insanity")
	game.shaderLocs["flash"] = rl.GetShaderLocation(WorldShader, "flash")

	game.music["wind"] = rl.LoadMusicStream("assets/sfx/wind1.ogg")
	rl.PlayMusicStream(game.music["wind"])
	game.music["camp"] = rl.LoadMusicStream("assets/sfx/fire.ogg")
	rl.PlayMusicStream(game.music["camp"])
	game.music["rain"] = rl.LoadMusicStream("assets/sfx/rain.ogg")
	rl.PlayMusicStream(game.music["rain"])
	game.music["crazy_ambient"] = rl.LoadMusicStream("assets/sfx/crazy_ambient.ogg")
	rl.PlayMusicStream(game.music["crazy_ambient"])

	pixelImg := rl.GenImageColor(1, 1, rl.WHITE)
	defer rl.UnloadImage(pixelImg)
	pixelTex := rl.LoadTextureFromImage(pixelImg)
	game.textures["pix"] = pixelTex
	bloodrdImg := rl.GenImageGradientLinear(1, 7, 0, {128, 0, 0, 0}, {180, 0, 0, 255})
	defer rl.UnloadImage(bloodrdImg)
	bloodrdTex := rl.LoadTextureFromImage(bloodrdImg)
	game.textures["bdrop"] = bloodrdTex
	bloodImg := rl.GenImagePerlinNoise(64, 64, 0, 0, 4)
	// bloodImg := rl.GenImageWhiteNoise(64, 64, 0.5)
	// bloodTex := rl.LoadTextureFromImage(bloodImg)
	bloodTex := rl.LoadTexture("assets/gfx/textures/noise.png")
	game.textures["blood"] = bloodTex
	tree := game_load_model(game, "tree", "birch.glb")
	set_model_shader(tree, WorldShader)

	rl.SetMaterialTexture(mat, .ALBEDO, bloodTex)

	cf := game_load_model(game, "camp", "campfire.glb")
	set_model_shader(cf, WorldShader)

	game_start(game)

	return game
}

game_update :: proc(using game: ^Game, delta: f32) {
	ease.flux_update(&game.tweens, f64(delta))
	if rl.IsKeyPressed(.MINUS) {
		game_start(game, true)
		return
	}
	rl.UpdateMusicStream(game.music["wind"])
	rl.UpdateMusicStream(game.music["camp"])
	rl.UpdateMusicStream(game.music["rain"])
	rl.UpdateMusicStream(game.music["crazy_ambient"])


	if eyelids_speed != 0 {
		eyelids_closed += eyelids_speed * delta
		if eyelids_closed >= 1 {
			eyelids_speed = -5
			switch eyelids_action {
			case .PILLS:
				game_use_pill(game)
			case .RESTART:
				game_start(game, true)
			case .EXIT:
				ShouldQuit = true
			}
		}
		if eyelids_closed <= 0 {
			eyelids_speed = 0
		}
	}

	if rl.IsKeyPressed(.ESCAPE) {
		if started {
			pause = !pause
			if pause {
				rl.EnableCursor()
			} else {
				rl.DisableCursor()
			}
		} else {
			ShouldQuit = true
		}
	}
	if pause {
		if rl.IsKeyPressed(.Q) do ShouldQuit = true
		if rl.IsKeyPressed(.R) do game_restart(game)
		return
	}


	campfire_update(&game.campfire, delta)
	for &downfall in game.downfall {
		diff := downfall.position - game.player.cam.position
		dist := linalg.length2(diff.xz)
		tex := game.textures["pix"]
		switch downfall.type {
		case .None:
			downfall.y -= delta
		case .Snow:
			downfall.y -= delta * 2.5
		case .Bloodrain:
			downfall.y -= delta * 25
		}
		if dist > 900 {
			downfall.position.xz -= linalg.normalize(diff.xz) * 60
		}
		if downfall.y < 0 {
			downfall.position.xz = vec2 {
				rand.float32_range(player.position.x - 30, player.position.x + 30),
				rand.float32_range(player.position.z - 30, player.position.z + 30),
			}
			downfall.y = 15
			if rand.float32() < game.insanity {
				downfall.type = .Bloodrain
			} else {
				downfall.type = .Snow
			}
		}
		if linalg.length2(diff) > 1600 {
			downfall.type = .None
			continue
		}
	}
	slice.sort_by(downfall[:], proc(a, b: Downfall) -> bool {
		if a.type == .Snow && b.type == .Bloodrain do return true
		if a.type == .Snow && b.type == .None do return true
		if a.type == .Bloodrain && b.type == .None do return true
		return false
	})

	if !started {
		if rl.IsKeyPressed(.SPACE) || rl.IsMouseButtonPressed(.LEFT) {
			started = true
			_ = ease.flux_to(&tweens, &player.cam_height, 1.7)
			_ = ease.flux_to(&tweens, &player.gun_down, 0)
			rl.DisableCursor()
			// rl.PollInputEvents()
		}

		return
	}
	timer += delta
	player_update(&game.player, delta)
	if player.is_dead do return

	// if timer > 5 {
	diff := player.position - campfire.position
	dist: f32 = linalg.length(diff)
	c: f32 =
		-linalg.smoothstep(f32(5.0), f32(1.0), dist) * 0.2 +
		linalg.smoothstep(f32(5.0), f32(25.0), dist)
	game.insanity = clamp(game.insanity + 0.04 * c * delta, 0, 1)
	if game.insanity >= 1 {
		player.is_crazy = true
		player_die(&player, sound_crazy)
	}
	rl.SetMusicVolume(game.music["camp"], linalg.smoothstep(f32(20), f32(2), dist))
	rl.SetMusicVolume(game.music["rain"], insanity * 1.5)
	rl.SetMusicVolume(game.music["wind"], 1 - insanity)
	rl.SetMusicVolume(game.music["crazy_ambient"], insanity * 0.8)
	// }
	spawn_timer += delta
	if spawn_timer > 2 {
		max_enemies: int = min(2 + int(insanity * 10) + int(timer / 30), 15)
		if len(enemy_list) < max_enemies {
			demon_spawn(
				game,
				player.position +
				rl.Vector3RotateByAxisAngle({30, 0, 0}, {0, 1, 0}, rand.float32_range(0, 360)),
			)

		}
		spawn_timer = 0
	}
	// game.insanity = 0.5
	PosterizerValue = max(math.remap(insanity, 0.3, 1, 8.0, 2.0), 3)
	playerangle := linalg.vector_normalize(player.cam.target - player.cam.position)


	#reverse for &enemy in enemy_list {
		enemy->update(delta)
	}
	slice.sort_by(enemy_list[:], proc(a, b: ^Enemy) -> bool {
		if a.enemy_type == Demon {
			ea := transmute(^Demon)a
			if b.enemy_type != Demon do return true

			eb := transmute(^Demon)b
			return int(ea.state) < int(eb.state)

		}
		return false
	})

}

game_use_pill :: proc(using game: ^Game) {
	insanity = 0.0
	timer = 0.0

	for &df in downfall {
		df.type = .Snow
	}

}

game_draw :: proc(using game: ^Game) {
	rl.BeginMode3D(player.cam)
	player_draw(&player)
	// rl.DrawGrid(30, game.grid.cell_size)
	rl.BeginShaderMode(WorldShader)
	rl.SetShaderValue(WorldShader, shaderLocs["view"], &game.player.cam.position, .VEC3)
	rl.SetShaderValue(WorldShader, shaderLocs["ins"], &game.insanity, .FLOAT)
	// rl.SetShaderValue(MainShader, bloodLoc, &bloodTex, .SAMPLER2D)
	rl.SetShaderValueTexture(WorldShader, shaderLocs["blood"], textures["blood"])

	playerangle := linalg.vector_normalize(player.cam.target - player.cam.position)
	rl.DrawModelEx(models["demon"], {}, {0, 1, 0}, 0, 0.5, {255, 0, 0, 255})

	rl.DrawCube({0, 0, 0}, -1000, 1000, 1000, rl.RED)
	rl.DrawMesh(meshes["plane"], materials["planemat"], rl.Matrix(1))
	for &tree in game.trees {
		diff := tree.position - game.player.cam.position
		if linalg.length2(diff) > 1600 do continue
		// if linalg.vector_dot(diff, playerangle) < 0 do continue

		rl.DrawModelEx(
			models["tree"],
			tree.position,
			{0, 1, 0},
			tree.rotation,
			tree.scale,
			rl.WHITE,
		)
		// rl.DrawMesh(
		// 	models["tree"].meshes[0],
		// 	materials["planemat"],
		// 	rl.Matrix(1) * rl.MatrixTranslate(tree.position.x, tree.position.y, tree.position.z),
		// )
	}


	dfdraw: for &df in downfall {
		switch df.type {
		case .None:
			break dfdraw
		case .Snow:
			rl.DrawBillboard(player.cam, textures["pix"], df.position, 0.1, rl.WHITE)
		// rl.DrawCubeV(df.position, 0.1, rl.WHITE)
		// rl.DrawPoint3D(df.position, rl.WHITE)
		case .Bloodrain:
			rl.DrawBillboard(player.cam, textures["bdrop"], df.position, 0.8, rl.WHITE)
		// rl.DrawCubeV(df.position, {0.1, 0.5, 0.1}, {120, 0, 0, 255})
		}
	}


	for &enemy in enemy_list {
		diff := enemy.position - game.player.cam.position
		if linalg.length2(diff) > 1600 do continue
		// if linalg.vector_dot(diff, playerangle) < 0 do continue
		enemy->draw()
	}


	campfire_draw(&game.campfire)

	rl.EndShaderMode()

	rl.EndMode3D()

	text: cstring
	dimensions: vec2
	if !player.is_dead {
		if started && !pause {
			rl.DrawCircleLines(GameSize.x / 2, GameSize.y / 2, 5, rl.WHITE)
			text = fmt.ctprintf("БЕЗУМИЕ: %3.1f%%", insanity * 100)
			dimensions := rl.MeasureTextEx(UIFont, text, 20, 1)
			rl.DrawTextEx(UIFont, text, {10, f32(GameSize.y) - dimensions.y - 10}, 20, 1, rl.BLACK)
			if player.reload_timer > 0 {
				text = "ПЕРЕЗАРЯДКА..."
			} else {
				text = fmt.ctprintf("%d / 6", player.ammo)
			}
			dimensions = rl.MeasureTextEx(UIFont, text, 20, 1)
			rl.DrawTextEx(
				UIFont,
				text,
				{f32(GameSize.x) - dimensions.x - 10, f32(GameSize.y) - dimensions.y - 10},
				20,
				1,
				rl.BLACK,
			)
		}
		if !started {
			draw_text_centered("UnSanity", {GameSizeF.x / 2, 30}, 30, 3, rl.WHITE)
			draw_text_centered(
				"НАЖМИТЕ [ОГОНЬ] ЧТОБЫ НАЧАТЬ\nИЛИ [ESCAPE] ЧТОБЫ ВЫЙТИ",
				GameSizeF / 2,
				20,
				1,
				rl.WHITE,
			)
		}
		if pause {
			draw_text_centered("ПАУЗА", {GameSizeF.x / 2, 30}, 30, 3, rl.WHITE)
			draw_text_centered(
				"НАЖМИТЕ [ESCAPE] ЧТОБЫ ПРОДОЛЖИТЬ\n[R] ДЛЯ РЕСТАРТА\n[Q] ЧТОБЫ ВЫЙТИ",
				GameSizeF / 2,
				20,
				1,
				rl.WHITE,
			)

		}
	} else {
		color := rl.RED
		text = "ВЫ МЕРТВЫ"
		if player.is_crazy {
			color = rl.WHITE
			text = "ВЫ СОШЛИ С УМА"
		}
		draw_text_centered(text, GameSizeF / 2, 30, 2, color)

		draw_text_centered(
			"НАЖМИТЕ [ОГОНЬ] ЧТОБЫ ПРОСНУТЬСЯ",
			{GameSizeF.x / 2, GameSizeF.y - 20},
			16,
			1,
			color,
		)
	}

	rl.DrawRectangleV({}, {f32(GameSize.x), f32(GameSize.y) / 2 * eyelids_closed}, rl.BLACK)
	rl.DrawRectangleV(
		{0, f32(GameSize.y) - f32(GameSize.y) / 2 * eyelids_closed},
		{f32(GameSize.x), f32(GameSize.y) / 2 * eyelids_closed},
		rl.BLACK,
	)
	free_all(context.temp_allocator)
}

draw_text_centered :: proc(
	text: cstring,
	position: vec2,
	size: f32,
	spacing: f32,
	color: rl.Color,
) {
	dimensions := rl.MeasureTextEx(UIFont, text, size, spacing)
	rl.DrawTextEx(UIFont, text, position - dimensions / 2, size, spacing, color)

}

game_free :: proc(game: ^Game) {

	grid_free(&game.grid)
	for m in game.models {
		rl.UnloadModel(game.models[m])
	}
	delete(game.models)
	for m in game.textures {
		rl.UnloadTexture(game.textures[m])
	}
	delete(game.textures)
	for m in game.meshes {
		rl.UnloadMesh(game.meshes[m])
	}
	delete(game.meshes)
	for m in game.materials {
		rl.UnloadMaterial(game.materials[m])
	}
	delete(game.materials)
	for m in game.shaders {
		rl.UnloadShader(game.shaders[m])
	}
	for m in game.sounds {
		rl.UnloadSound(game.sounds[m])
	}
	delete(game.sounds)
	for m in game.music {
		rl.UnloadMusicStream(game.music[m])
	}
	delete(game.music)
	delete(game.shaders)
	demon_free_resources()
	ease.flux_destroy(game.tweens)
	player_free()


	// rl.UnloadShader(WorldShader)

	// clear_enemies()
}

