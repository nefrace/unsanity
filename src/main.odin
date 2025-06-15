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


set_model_shader :: proc(model: ^rl.Model, shader: rl.Shader) {
	for &material in model.materials[:model.materialCount] {
		material.shader = shader
	}
}
TitleFont: rl.Font
UIFont: rl.Font
FontPath :: "assets/font.ttf"

ShouldQuit := false
drawfps := false


Posterizer: rl.Shader
PosterizerLoc: i32
PosterizerValue: f32 = 8.0

Pixelize: i32 = 2
GameSize: [2]i32
GameSizeF: [2]f32

codepoints: [dynamic]rune
init_codepoints :: proc() {
	for r in 'A' ..= 'Z' do append(&codepoints, r)
	for r in 'a' ..= 'z' do append(&codepoints, r)
	for r in 'А' ..= 'Я' do append(&codepoints, r)
	for r in 'а' ..= 'я' do append(&codepoints, r)
	for r in '0' ..= '9' do append(&codepoints, r)
	spec := [?]rune {
		'-',
		'=',
		'+',
		':',
		'/',
		'.',
		',',
		'!',
		'@',
		'#',
		'$',
		'%',
		'^',
		'&',
		'*',
		'(',
		')',
		'{',
		'}',
		'[',
		']',
	}
	for r in spec do append(&codepoints, r)
}

main :: proc() {
	init_codepoints()
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	// rl.SetTargetFPS(10)

	rl.InitWindow(1200, 800, "UnSanity")
	rl.SetExitKey(.KEY_NULL)
	rl.InitAudioDevice()
	// rlgl.DisableBackfaceCulling()
	defer rl.CloseWindow()
	defer rl.CloseAudioDevice()
	w, h := rl.GetScreenWidth(), rl.GetScreenHeight()
	GameSize = {w, h} / Pixelize
	GameSizeF = {f32(GameSize.x), f32(GameSize.y)}

	target := rl.LoadRenderTexture(GameSize.x, GameSize.y)
	defer rl.UnloadRenderTexture(target)

	posttarget := rl.LoadRenderTexture(GameSize.x, GameSize.y)
	defer rl.UnloadRenderTexture(target)

	Posterizer = rl.LoadShader(nil, "assets/shaders/posterizer.glsl")
	PosterizerLoc = rl.GetShaderLocation(Posterizer, "posterize")
	defer rl.UnloadShader(Posterizer)

	TitleFont = rl.LoadFontEx(FontPath, 40, raw_data(codepoints[:]), i32(len(codepoints)))
	UIFont = rl.LoadFontEx(FontPath, 30, raw_data(codepoints[:]), i32(len(codepoints)))
	rl.SetTextureFilter(UIFont.texture, .TRILINEAR)

	game := game_init()
	defer game_free(game)


	for !rl.WindowShouldClose() && !ShouldQuit {
		if rl.IsWindowResized() {
			w, h = rl.GetScreenWidth(), rl.GetScreenHeight()
			GameSize = {w, h} / Pixelize
			GameSizeF = {f32(GameSize.x), f32(GameSize.y)}
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
			{0, 0, GameSizeF.x, GameSizeF.y},
			{0, 0, f32(w), f32(h)},
			{},
			0,
			rl.WHITE,
		)
		if rl.IsKeyPressed(.F1) do drawfps = !drawfps
		if drawfps {
			rl.DrawFPS(10, 10)
		}
		rl.EndDrawing()

	}


}

