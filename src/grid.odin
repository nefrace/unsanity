package main

import "core:fmt"
import "core:math"
import "core:slice"

Object_List :: [dynamic]^Object

CellCoords :: bit_field i64 {
	x: i32 | 32,
	y: i32 | 32,
}

Cell :: struct {
	objects: [dynamic]^Object,
}

Grid :: struct {
	cell_size: f32,
	cells:     map[CellCoords]Object_List,
}

grid_init :: proc(grid: ^Grid) {
	grid.cell_size = 10
}

grid_world_to_local :: proc(grid: ^Grid, coords: vec2) -> CellCoords {
	return CellCoords {
		x = i32(math.floor(coords.x / grid.cell_size)),
		y = i32(math.floor(coords.y / grid.cell_size)),
	}
}

grid_local_to_world :: proc(grid: ^Grid, coords: CellCoords) -> vec2 {
	return vec2{f32(coords.x) * grid.cell_size, f32(coords.y) * grid.cell_size}
}

grid_clear :: proc(grid: ^Grid) {
	clear(&grid.cells)
}

grid_free :: proc(grid: ^Grid) {
	grid_clear(grid)
	delete(grid.cells)
	// free(grid)
}

grid_remove :: proc(grid: ^Grid, object: ^Object) {
	coords := grid_world_to_local(grid, object.position.xz)

	if cell, ok := grid.cells[coords]; ok {
		#reverse for &obj, i in grid.cells[coords] {
			if obj == object {
				unordered_remove(&grid.cells[coords], i)
				break
			}
		}
		if len(grid.cells[coords]) == 0 {
			delete(grid.cells[coords])
			delete_key(&grid.cells, coords)
		}
	}

}

grid_add :: proc(grid: ^Grid, object: ^Object) {
	coords := grid_world_to_local(grid, object.position.xz)


	if cell, ok := grid.cells[coords]; !ok {
		grid.cells[coords] = make([dynamic]^Object)
	}


	append(&(grid.cells[coords]), object)
}

grid_query_coords :: proc(
	grid: ^Grid,
	coords: CellCoords,
	neighbors := false,
	allocator := context.temp_allocator,
) -> []^Object {
	cell, ok := grid.cells[coords]
	if !ok && !neighbors {
		return {}
	}
	obj := make([dynamic]^Object, allocator)

	if ok do append(&obj, ..cell[:])

	if neighbors {
		offsets := [8][2]i32{{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}}
		for offset in offsets {
			c := coords
			c.x += offset.x
			c.y += offset.y
			objs := grid_query_coords(grid, c, false, allocator)
			append(&obj, ..objs[:])
		}
	}

	return obj[:]

}

grid_query_vec2 :: proc(
	grid: ^Grid,
	pos: vec2,
	neighbors := false,
	allocator := context.temp_allocator,
) -> []^Object {
	coords := grid_world_to_local(grid, pos)
	return grid_query_coords(grid, coords, neighbors, allocator)
}

grid_query :: proc {
	grid_query_coords,
	grid_query_vec2,
}

