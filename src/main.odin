package main


import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

vec2 :: [2]f32
vec3 :: [3]f32

Entity :: struct {
	position: vec3,
	velocity: vec3,
	size:     vec3,
}

set_model_shader :: proc(model: ^rl.Model, shader: rl.Shader) {
	for &material in model.materials[:model.materialCount] {
		material.shader = shader
	}
}

Posterizer: rl.Shader
PosterizerLoc: i32
PosterizerValue: f32 = 8.0

Pixelize: i32 = 2
GameSize: [2]i32

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	// rl.SetTargetFPS(10)

	rl.InitWindow(1200, 800, "UnSanity")
	rlgl.DisableBackfaceCulling()
	defer rl.CloseWindow()
	w, h := rl.GetScreenWidth(), rl.GetScreenHeight()
	GameSize = {w, h} / Pixelize

	target := rl.LoadRenderTexture(GameSize.x, GameSize.y)
	defer rl.UnloadRenderTexture(target)

	posttarget := rl.LoadRenderTexture(GameSize.x, GameSize.y)
	defer rl.UnloadRenderTexture(target)

	Posterizer = rl.LoadShader(nil, "assets/shaders/posterizer.glsl")
	PosterizerLoc = rl.GetShaderLocation(Posterizer, "posterize")
	defer rl.UnloadShader(Posterizer)

	game := game_init()
	defer game_free(game)

	for !rl.WindowShouldClose() {
		if rl.IsWindowResized() {
			w, h := rl.GetScreenWidth(), rl.GetScreenHeight()
			GameSize = {w, h} / Pixelize
			rl.UnloadRenderTexture(target)
			target = rl.LoadRenderTexture(GameSize.x, GameSize.y)
			rl.UnloadRenderTexture(posttarget)
			posttarget = rl.LoadRenderTexture(GameSize.x, GameSize.y)
		}
		delta := rl.GetFrameTime()
		game_update(game, delta)


		rl.BeginTextureMode(target)
		rl.ClearBackground(rl.BLACK)

		game_draw(game)

		rl.EndTextureMode()

		rl.BeginTextureMode(posttarget)
		rl.BeginShaderMode(Posterizer)
		rl.SetShaderValue(Posterizer, PosterizerLoc, &PosterizerValue, .FLOAT)
		rl.DrawTexture(target.texture, 0, 0, rl.WHITE)
		rl.EndShaderMode()
		rl.EndTextureMode()


		rl.BeginDrawing()
		rl.DrawTexturePro(
			posttarget.texture,
			rl.Rectangle{0, 0, f32(GameSize.x), f32(GameSize.y)},
			{0, 0, f32(w), f32(h)},
			{},
			0,
			rl.WHITE,
		)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()

	}


}

