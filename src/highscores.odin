package main

import "core:encoding/cbor"
import "core:os"

Highscores :: struct {
	seconds:     int,
	kills:       int,
	shots:       int,
	hits:        int,
	pills:       int,
	crazy_count: int,
	death_count: int,
}

highscore_write :: proc(hs: Highscores) {
	binary, _ := cbor.marshal(hs, cbor.ENCODE_FULLY_DETERMINISTIC)
	os.write_entire_file("hs.dat", binary, true)
}

highscore_read :: proc() -> Highscores {
	binary, ok := os.read_entire_file("hs.dat")
	if !ok {
		return Highscores{}
	}
	// defer free(&binary)
	hs: Highscores
	err := cbor.unmarshal_from_bytes(binary, &hs)
	if err != nil {
		return Highscores{}
	}
	return hs
}

