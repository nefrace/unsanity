package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"


Tree :: struct {
	position: vec3,
	scale:    vec3,
	radius:   f32,
	rotation: f32,
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

Campfire :: struct {
	position: vec3,
	light:    ^Light,
	radius:   f32,
}

Solid :: struct {
	position: vec3,
	radius:   f32,
	height:   f32,
}


Game :: struct {
	player:     Player,
	campfire:   Campfire,
	insanity:   f32,
	timer:      f32,
	trees:      [500]Tree,
	downfall:   [1200]Downfall,
	solids:     [dynamic]Solid,
	models:     map[string]rl.Model,
	meshes:     map[string]rl.Mesh,
	textures:   map[string]rl.Texture,
	materials:  map[string]rl.Material,
	shaders:    map[string]rl.Shader,
	shaderLocs: map[string]i32,
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

game_init :: proc() -> ^Game {
	WorldShader = rl.LoadShader(
		"assets/shaders/vshader.glsl",
		"assets/shaders/fshader_blooded.glsl",
	)
	game := new(Game)
	game^ = {
		player = player_spawn(game, {0, 0, -2}),
	}
	tree := game_load_model(game, "tree", "birch.glb")
	set_model_shader(tree, WorldShader)

	demon_init_resourecs()

	clear_enemies()


	// demon := game_load_model(game, "demon", "demon.glb")
	// set_model_shader(demon, GameShader)

	game.meshes["plane"] = rl.GenMeshPlane(500, 500, 250, 250)
	game.materials["planemat"] = rl.LoadMaterialDefault()
	mat := &game.materials["planemat"]
	mat.shader = WorldShader
	game.shaderLocs["view"] = rl.GetShaderLocation(WorldShader, "viewPos")
	game.shaderLocs["blood"] = rl.GetShaderLocation(WorldShader, "bloodmask")
	game.shaderLocs["ins"] = rl.GetShaderLocation(WorldShader, "insanity")
	game.shaderLocs["flash"] = rl.GetShaderLocation(WorldShader, "flash")

	cf := game_load_model(game, "camp", "campfire.glb")
	set_model_shader(cf, WorldShader)

	game.campfire = Campfire {
		position = {},
		light    = light_new(&WorldShader, {0, 0.5, 0}, 0, 30, 1, {1, 1, 1, 1}),
		radius   = 1,
	}
	append(
		&game.solids,
		Solid{position = game.campfire.position, radius = game.campfire.radius, height = 0.4},
	)


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

	rl.SetMaterialTexture(mat, .ALBEDO, bloodTex)

	for &tree, i in game.trees {

		for linalg.distance(tree.position, vec3{}) < 10 {
			tree.position.x = rand.float32_range(-200, 200)
			tree.position.z = rand.float32_range(-200, 200)
		}
		tree.rotation = rand.float32() * 360
		tree.scale.x = rand.float32_range(0.5, 0.7)
		tree.scale.z = tree.scale.x
		tree.scale.y = rand.float32_range(0.7, 1.3)
		tree.radius = tree.scale.x * 3
		append(
			&game.solids,
			Solid{position = tree.position, radius = tree.scale.x * 2, height = 30},
		)
	}

	for &downfall in game.downfall {
		downfall.position = {
			rand.float32_range(-30, 30),
			rand.float32_range(0, 15),
			rand.float32_range(-30, 30),
		}

		downfall.type = .Snow
	}

	for i := 0; i < 20; i += 1 {
		demon_spawn(game, {rand.float32_uniform(-30, 30), 0, rand.float32_uniform(-30, 30)})
	}


	return game
}

game_update :: proc(using game: ^Game, delta: f32) {
	timer += delta
	player_update(&game.player, delta)
	if rl.IsKeyPressed(.F) {
		game_use_pill(game)
	}

	if timer > 20 {
		game.insanity += delta * 0.05
	}
	game.insanity = 0.5
	PosterizerValue = max(math.remap(insanity, 0.3, 1, 8.0, 2.0), 3)
	playerangle := linalg.vector_normalize(player.cam.target - player.cam.position)
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


	for &enemy in enemy_list {
		enemy->update(delta)
	}

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
	// rl.DrawGrid(30, 1)
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
		enemy->draw()
	}

	rl.DrawModel(models["camp"], campfire.position, 0.1, rl.RED)


	rl.EndShaderMode()
	rl.EndMode3D()
	rl.DrawCircleLines(GameSize.x / 2, GameSize.y / 2, 5, rl.WHITE)
	// rl.DrawText(rl.TextFormat("%f", insanity), 50, 50, 20, rl.RED)
	free_all(context.temp_allocator)
}


game_free :: proc(game: ^Game) {

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
	delete(game.shaders)
	delete(game.solids)
	demon_free_resources()

	// rl.UnloadShader(WorldShader)

	// clear_enemies()
}

