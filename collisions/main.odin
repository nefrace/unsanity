package main


import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"


Buddy :: struct {
	pos:       [3]f32,
	gothit:    bool,
	hit_timer: f32,
}


Light :: struct {
	enabled:         i32,
	used:            bool,
	distanceNear:    f32,
	distanceFar:     f32,
	power:           f32,
	position:        [3]f32,
	color:           [4]f32,
	enabledLoc:      i32,
	distanceNearLoc: i32,
	distanceFarLoc:  i32,
	powerLoc:        i32,
	positionLoc:     i32,
	colorLoc:        i32,
	shader:          ^rl.Shader,
}

light_find_unused :: proc() -> (^Light, int) {
	for &light, i in lights {
		if light.enabled == 0 do return &light, i
	}
	return nil, -1
}

light_new :: proc(
	shader: ^rl.Shader,
	pos: [3]f32,
	distanceNear: f32 = 0,
	distanceFar: f32 = 10,
	power: f32 = 1,
	color: [4]f32 = {1, 1, 1, 1},
) -> ^Light {
	light, id := light_find_unused()
	if light == nil do return nil

	light.enabled = 1
	light.position = pos
	light.distanceNear = distanceNear
	light.distanceFar = distanceFar
	light.power = power
	light.color = color
	light.shader = shader

	light_set_uniforms(light, auto_cast id)
	light_update_uniforms(light)

	return light
}

light_destroy :: proc(light: ^Light) {
	light.enabled = 0
	light.used = false
	light_update_uniforms(light)
}


light_set_uniforms :: proc(light: ^Light, i: i32) {
	light.enabledLoc = rl.GetShaderLocation(light.shader^, rl.TextFormat("lights[%i].enabled", i))
	light.distanceNearLoc = rl.GetShaderLocation(
		light.shader^,
		rl.TextFormat("lights[%i].distanceNear", i),
	)
	light.distanceFarLoc = rl.GetShaderLocation(
		light.shader^,
		rl.TextFormat("lights[%i].distanceFar", i),
	)
	light.powerLoc = rl.GetShaderLocation(light.shader^, rl.TextFormat("lights[%i].power", i))
	light.positionLoc = rl.GetShaderLocation(
		light.shader^,
		rl.TextFormat("lights[%i].position", i),
	)
	light.colorLoc = rl.GetShaderLocation(light.shader^, rl.TextFormat("lights[%i].color", i))
}

light_update_uniforms :: proc(light: ^Light) {
	rl.SetShaderValue(light.shader^, light.enabledLoc, &(light.enabled), .INT)
	rl.SetShaderValue(light.shader^, light.distanceNearLoc, &(light.distanceNear), .FLOAT)
	rl.SetShaderValue(light.shader^, light.distanceFarLoc, &(light.distanceFar), .FLOAT)
	rl.SetShaderValue(light.shader^, light.powerLoc, &(light.power), .FLOAT)
	rl.SetShaderValue(light.shader^, light.enabledLoc, &(light.enabled), .INT)
	rl.SetShaderValue(light.shader^, light.enabledLoc, &(light.enabled), .INT)
	rl.SetShaderValue(light.shader^, light.positionLoc, &(light.position), .VEC3)
	rl.SetShaderValue(light.shader^, light.colorLoc, &(light.color), .VEC4)
}

move_light :: proc(light: ^Light, pos: [3]f32) {
	light.position = pos
	rl.SetShaderValue(light.shader^, light.positionLoc, &(light.position), .VEC3)
}

MAX_LIGHTS :: 32

lights := [MAX_LIGHTS]Light{}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(900, 600, "flash")
	// rl.SetTargetFPS(60)
	// rl.ToggleBorderlessWindowed()

	checker := rl.GenImageChecked(128, 128, 32, 32, {128, 128, 128, 255}, {150, 150, 150, 255})
	defer rl.UnloadImage(checker)
	checktex := rl.LoadTextureFromImage(checker)
	defer rl.UnloadTexture(checktex)
	checkmtl := rl.LoadMaterialDefault()
	rl.SetMaterialTexture(&checkmtl, .ALBEDO, checktex)
	checkplane := rl.GenMeshPlane(30, 30, 1, 1)
	rl.GenMeshTangents(&checkplane)


	w, h := rl.GetScreenWidth(), rl.GetScreenHeight()
	pixelize: i32 = 2
	target := rl.LoadRenderTexture(w / pixelize, h / pixelize)
	posttarget := rl.LoadRenderTexture(w / pixelize, h / pixelize)

	palette := rl.LoadTexture("assets/gfx/bluem0ld-1x.png")
	rl.SetTextureFilter(palette, .POINT)

	shader := rl.LoadShaderFromMemory(vshader, fshader)
	posterizer := rl.LoadShaderFromMemory(nil, postprocess)
	poster_palette := rl.GetShaderLocation(posterizer, "texture1")
	checkmtl.shader = shader

	for i := 0; i < 4; i += 1 {
		light_new(&shader, {}, 0, 6, 0.8)
		hsvcol := rl.ColorFromHSV((f32(i) - 1.0) * 360 / 3, 1, 1)
		col := rl.ColorNormalize(hsvcol)
		if i > 0 do lights[i].color = col
		light_update_uniforms(&lights[i])
	}
	lights[0].power = 0.9
	lights[0].distanceNear = 0
	lights[0].distanceFar = 6
	light_update_uniforms(&lights[0])
	// rl.SetShaderValue(shader, lights[0].distanceNearLoc, &(lights[0].distanceNear), .FLOAT)
	// rl.SetShaderValue(shader, lights[0].powerLoc, &(lights[0].power), .FLOAT)

	// sponza := rl.LoadModel("assets/models/sponza.glb")
	// for &material in sponza.materials[:sponza.materialCount] {
	// 	material.shader = shader
	// }
	mdl := rl.LoadModel("assets/maps/cell_01.obj")
	for &material in mdl.materials[:mdl.materialCount] {
		material.shader = shader
	}
	Tri :: [3][3]f32
	Mesh :: struct {
		aabb:      [2][3]f32,
		triangles: [dynamic]Tri,
	}
	// tris := [dynamic]Tri{}
	meshes := [dynamic]Mesh{}

	// vtx := [dynamic]f32{}
	scale: f32 = 48
	for &mesh in mdl.meshes[:mdl.meshCount] {
		// mesh := mdl.meshes[mdl.meshCount-1]
		append(&meshes, Mesh{aabb = {{9999, 9999, 9999}, {-9999, -9999, -9999}}})
		m := &(meshes[len(meshes) - 1])
		fmt.printf("Mesh: %d %d\n", mesh.vertexCount, mesh.triangleCount)
		for i: i32 = 0; i < mesh.vertexCount * 3; i += 9 {
			tri := Tri{}
			for j: i32 = 0; j < 3; j += 1 {
				c := j * 3
				for k: i32 = 0; k < 3; k += 1 {
					value := mesh.vertices[i + c + k] / scale
					if value < m.aabb[0][k] {
						m.aabb[0][k] = value
					}
					if value > m.aabb[1][k] {
						m.aabb[1][k] = value
					}
					tri[j][k] = value
				}
			}
			append(
				&m.triangles,
				tri,
				// Tri {
				// 	{
				// 		mesh.vertices[i] * scale,
				// 		mesh.vertices[i + 1] * scale,
				// 		mesh.vertices[i + 2] * scale,
				// 	},
				// 	{
				// 		mesh.vertices[i + 3] * scale,
				// 		mesh.vertices[i + 4] * scale,
				// 		mesh.vertices[i + 5] * scale,
				// 	},
				// 	{
				// 		mesh.vertices[i + 6] * scale,
				// 		mesh.vertices[i + 7] * scale,
				// 		mesh.vertices[i + 8] * scale,
				// 	},
				// },
			)
			// append(&vtx, mesh.vertices[i] * scale)
		}
	}

	fmt.println("====\nMESH COUNT: ", mdl.meshCount, "\n===")
	// for tri in tris {
	// 	fmt.println(tri[0], tri[1], tri[2], sep = "\n")
	// }

	look_angles: rl.Vector2 = 0
	cam := rl.Camera3D {
		position   = {0, 2, 0},
		target     = {1, 2, 0},
		up         = {0, 1, 0},
		fovy       = 90,
		projection = .PERSPECTIVE,
	}
	vel: rl.Vector3


	rotation: f32 = 0.0

	rl.DisableCursor()

	for !rl.WindowShouldClose() {
		if rl.IsWindowResized() {
			w, h = rl.GetScreenWidth(), rl.GetScreenHeight()
			rl.UnloadRenderTexture(target)
			target = rl.LoadRenderTexture(w / pixelize, h / pixelize)
			rl.UnloadRenderTexture(posttarget)
			posttarget = rl.LoadRenderTexture(w / pixelize, h / pixelize)
		}
		// rl.UpdateCamera(&cam, .FIRST_PERSON)
		delta := rl.GetFrameTime()

		rot :=
			linalg.quaternion_from_euler_angle_y_f32(look_angles.y) *
			linalg.quaternion_from_euler_angle_x_f32(look_angles.x)

		forward := linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{0, 0, 1})
		right := linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{1, 0, 0})

		look_angles.y -= rl.GetMouseDelta().x * 0.0015
		look_angles.x += rl.GetMouseDelta().y * 0.0015

		SPEED :: 20
		RAD :: 0.5

		moving := false
		if rl.IsKeyDown(.W) {
			vel.xz += forward.xz * delta * SPEED
			moving = true
		}
		if rl.IsKeyDown(.S) {
			vel.xz -= forward.xz * delta * SPEED
			moving = true
		}
		if rl.IsKeyDown(.D) {
			vel.xz -= right.xz * delta * SPEED
			moving = true
		}
		if rl.IsKeyDown(.A) {
			vel.xz += right.xz * delta * SPEED
			moving = true
		}
		vel.xz = rl.Vector2ClampValue(vel.xz, 0, 3)

		if rl.IsKeyDown(.E) do vel.y += delta * SPEED
		if rl.IsKeyDown(.Q) do vel.y -= delta * SPEED

		// gravity
		vel.y -= delta * 10 * (vel.y < 0.0 ? 2 : 1)

		if rl.IsKeyPressed(.SPACE) do vel.y = 8

		// damping
		vel *= 1.0 / (1.0 + delta * 2)

		campos := cam.position + {0, -0.4, 0}
		// Collide
		for mesh in meshes {
			// if cam.position.x + RAD < mesh.aabb[0].x &&
			//    cam.position.y + RAD < mesh.aabb[0].y &&
			//    cam.position.z + RAD < mesh.aabb[0].z &&
			//    cam.position.x - RAD > mesh.aabb[1].x &&
			//    cam.position.y - RAD > mesh.aabb[1].y &&
			//    cam.position.z - RAD > mesh.aabb[1].z {continue}


			for t in mesh.triangles {
				closest := closest_point_on_triangle(campos, t[0], t[1], t[2])
				diff := campos - closest
				dist := linalg.length(diff)
				normal := diff / dist
				// diff.xz *= 2
				dist = linalg.length(diff)

				rl.DrawCubeV(closest, 0.05, dist > RAD ? rl.ORANGE : rl.WHITE)

				if dist <= RAD {
					// cam.position += normal * (RAD - dist)
					cam.position = closest + normal * RAD - {0, -0.4, 0}
					// project velocity to the normal plane, if moving towards it
					vel_normal_dot := linalg.dot(vel, normal)
					if vel_normal_dot < 0 {
						vel -= normal * vel_normal_dot
						if normal.y > 0.6 && !moving {
							vel.xz = rl.Vector2MoveTowards(vel.xz, {}, 35 * delta)
							vel.y = 0
						}
					}
				}
			}
		}

		cam.position += vel * delta
		cam.target = cam.position + forward


		rotation += delta
		rl.BeginTextureMode(target)
		rl.ClearBackground(rl.BLACK)
		rl.BeginMode3D(cam)
		for &light, i in lights[1:] {
			if light.enabled == 0 do continue
			color: [4]u8 = {
				u8(light.color.r * 255),
				u8(light.color.g * 255),
				u8(light.color.b * 255),
				u8(light.color.a * 255),
			}
			move_light(
				&light,
				{
					math.cos_f32(rotation + (f32(i) / f32(3)) * math.PI * 2) * 3,
					2,
					-1.5 + math.sin_f32(rotation + (f32(i) / f32(3)) * math.PI * 2) * 3,
				},
			)
			rl.DrawSphere(light.position, 0.1, transmute(rl.Color)color)
		}
		move_light(&lights[0], cam.position)
		// for &tri in tris {
		// 	rl.DrawSphere(tri[0], 0.5, rl.WHITE)
		// 	rl.DrawSphere(tri[1], 0.5, rl.WHITE)
		// 	rl.DrawSphere(tri[2], 0.5, rl.WHITE)
		// 	rl.DrawTriangle3D(tri[0], tri[1], tri[2], rl.RED)
		// }
		// for mesh in meshes {
		// 	// rl.DrawBoundingBox(rl.BoundingBox{min = mesh.aabb[0], max = mesh.aabb[1]}, rl.RED)
		// 	for &tri in mesh.triangles {
		// 		// rl.DrawSphere(tri[0], 0.5, rl.WHITE)
		// 		// rl.DrawSphere(tri[1], 0.5, rl.WHITE)
		// 		// rl.DrawSphere(tri[2], 0.5, rl.WHITE)
		// 		// rl.DrawTriangle3D(tri[0], tri[1], tri[2], {255, 255, 255, 10})
		// 	}
		// }
		rl.BeginShaderMode(shader)
		rl.DrawModelEx(mdl, {}, {}, 0, 1 / scale, rl.WHITE)

		rl.EndShaderMode()
		rl.EndMode3D()
		rl.EndTextureMode()
		// rl.BeginDrawing()
		rl.BeginTextureMode(posttarget)
		rl.BeginShaderMode(posterizer)
		rl.SetShaderValueTexture(posterizer, poster_palette, palette)
		rl.DrawTexture(target.texture, 0, 0, rl.WHITE)
		rl.EndShaderMode()
		rl.EndTextureMode()

		rl.BeginDrawing()
		rl.DrawTexturePro(
			posttarget.texture,
			rl.Rectangle{0, 0, f32(w / pixelize), f32(h / pixelize)},
			{0, 0, f32(w), f32(h)},
			{},
			0,
			rl.WHITE,
		)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()
	}
}


vshader: cstring = #load("../assets/shaders/vshader.glsl", cstring)
fshader: cstring = #load("../assets/shaders/fshader.glsl", cstring)
postprocess: cstring = #load("../assets/shaders/posterizer.glsl", cstring)


// Real Time collision detection 5.1.5
closest_point_on_triangle :: proc(p, a, b, c: rl.Vector3) -> rl.Vector3 {
	// Check if P in vertex region outside A
	ab := b - a
	ac := c - a
	ap := p - a
	d1 := linalg.dot(ab, ap)
	d2 := linalg.dot(ac, ap)
	if d1 <= 0.0 && d2 <= 0.0 do return a // barycentric coordinates (1,0,0)
	// Check if P in vertex region outside B
	bp := p - b
	d3 := linalg.dot(ab, bp)
	d4 := linalg.dot(ac, bp)
	if d3 >= 0.0 && d4 <= d3 do return b // barycentric coordinates (0,1,0)
	// Check if P in edge region of AB, if so return projection of P onto AB
	vc := d1 * d4 - d3 * d2
	if vc <= 0.0 && d1 >= 0.0 && d3 <= 0.0 {
		v := d1 / (d1 - d3)
		return a + v * ab // barycentric coordinates (1-v,v,0)
	}
	// Check if P in vertex region outside C
	cp := p - c
	d5 := linalg.dot(ab, cp)
	d6 := linalg.dot(ac, cp)
	if d6 >= 0.0 && d5 <= d6 do return c // barycentric coordinates (0,0,1)
	// Check if P in edge region of AC, if so return projection of P onto AC
	vb := d5 * d2 - d1 * d6
	if vb <= 0.0 && d2 >= 0.0 && d6 <= 0.0 {
		w := d2 / (d2 - d6)
		return a + w * ac // barycentric coordinates (1-w,0,w)
	}
	// Check if P in edge region of BC, if so return projection of P onto BC
	va := d3 * d6 - d5 * d4
	if va <= 0.0 && (d4 - d3) >= 0.0 && (d5 - d6) >= 0.0 {
		w := (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return b + w * (c - b) // barycentric coordinates (0,1-w,w)
	}
	// P inside face region. Compute Q through its barycentric coordinates (u,v,w)
	denom := 1.0 / (va + vb + vc)
	v := vb * denom
	w := vc * denom
	return a + ab * v + ac * w // = u*a + v*b + w*c, u = va * denom = 1.0-v-w
}

