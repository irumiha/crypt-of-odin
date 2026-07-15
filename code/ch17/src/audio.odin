// Every sound in the game, synthesized from arithmetic at startup.
// No files, no licensing, no asset pipeline: a square wave is a loop
// and an if. This is the sfxr/chiptune lineage, in miniature.
//
// The synth builds 16-bit mono samples, wraps them in a WAV header
// by hand (44 bytes of 1991-vintage file format), and hands them to
// raylib. Music is the same trick streamed on a loop.

package crypt

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

SAMPLE_RATE :: 44100

Shape :: enum {
	Square, Sine, Triangle, Noise,
}

Sfx :: enum {
	Swing, Hit, Coin, Heart, Power, Unlock,
	Stairs, Kill, Game_Over, Start, Roar, Victory,
}

Audio_Bank :: struct {
	sounds:     [Sfx]rl.Sound,
	music:      rl.Music,
	music_data: []u8, // the stream reads from this; keep it alive
}

tone :: proc(freq_start, freq_end, duration: f32, shape: Shape,
             volume: f32 = 0.5,
             allocator := context.allocator) -> [dynamic]i16 {
	// One note: frequency slides from start to end, amplitude decays
	// linearly to silence. Enough knobs for every effect we need.
	n := int(duration * SAMPLE_RATE)
	samples := make([dynamic]i16, 0, n, allocator)
	phase: f32
	for i in 0 ..< n {
		t := f32(i) / f32(n)
		freq := freq_start + (freq_end - freq_start) * t
		phase += freq / SAMPLE_RATE
		raw: f32
		switch shape {
		case .Square:   raw = 1 if math.mod(phase, 1) < 0.5 else -1
		case .Sine:     raw = math.sin(phase * 2 * math.PI)
		case .Triangle: raw = abs(math.mod(phase, 1) - 0.5) * 4 - 1
		case .Noise:    raw = rand.float32_range(0, 2) - 1
		}
		envelope := 1 - t // linear fade-out
		append(&samples, i16(raw * envelope * volume * 32000))
	}
	return samples
}

mix :: proc(tracks: ..[dynamic]i16,
            allocator := context.allocator) -> [dynamic]i16 {
	// Overlays tracks sample-by-sample (saturating, crudely).
	longest := 0
	for tr in tracks {
		longest = max(longest, len(tr))
	}
	out := make([dynamic]i16, longest, allocator)
	for tr in tracks {
		for s, i in tr {
			out[i] = i16(clamp(i32(out[i]) + i32(s), -32000, 32000))
		}
	}
	return out
}

build_wav :: proc(samples: []i16,
                  allocator := context.allocator) -> [dynamic]u8 {
	// A minimal WAV: 44-byte RIFF header, then the PCM data. Little
	// endian throughout, which x86 gives us for free.
	add32 :: proc(s: ^[dynamic]u8, v: u32) {
		append(s, u8(v & 0xff), u8((v >> 8) & 0xff),
		       u8((v >> 16) & 0xff), u8((v >> 24) & 0xff))
	}
	add16 :: proc(s: ^[dynamic]u8, v: u16) {
		append(s, u8(v & 0xff), u8((v >> 8) & 0xff))
	}
	out := make([dynamic]u8, 0, 44 + len(samples) * 2, allocator)
	data_size := u32(len(samples) * 2)
	append(&out, "RIFF")
	add32(&out, 36 + data_size)
	append(&out, "WAVE")
	append(&out, "fmt ")
	add32(&out, 16)              // fmt chunk size
	add16(&out, 1)               // PCM
	add16(&out, 1)               // mono
	add32(&out, SAMPLE_RATE)
	add32(&out, SAMPLE_RATE * 2) // byte rate
	add16(&out, 2)               // block align
	add16(&out, 16)              // bits per sample
	append(&out, "data")
	add32(&out, data_size)
	for s in samples {
		append(&out, u8(u16(s) & 0xff), u8((u16(s) >> 8) & 0xff))
	}
	return out
}

@(private = "file")
to_sound :: proc(samples: [dynamic]i16) -> rl.Sound {
	samples := samples
	wav := build_wav(samples[:], context.temp_allocator)
	delete(samples) // the WAV bytes carry the data from here
	wave := rl.LoadWaveFromMemory(".wav", raw_data(wav), i32(len(wav)))
	sound := rl.LoadSoundFromWave(wave)
	rl.UnloadWave(wave) // the sound made its own copy
	return sound
}

@(private = "file")
crypt_theme :: proc() -> [dynamic]i16 {
	// Eight bars of A-minor gloom at 120 bpm: a pulsing square bass and
	// a sine arpeggio. Three sine waves in a trench coat, but it loops.
	EIGHTH :: 0.25 // seconds per eighth note
	A2 :: 110.0
	// Chord roots (Am, Am, F, G), as multiples of A2.
	roots := [4]f32{1.0, 1.0, 1.3348, 1.4983}
	arpeggio := [4]f32{1.0, 1.1892, 1.4983, 2.0} // minor-ish spread
	out: [dynamic]i16
	for bar in 0 ..< 8 {
		root := A2 * roots[(bar / 2) % len(roots)]
		for step in 0 ..< 8 {
			bass := tone(root / 2, root / 2, EIGHTH, .Square,
			             volume = 0.10, allocator = context.temp_allocator)
			lead := tone(root * arpeggio[step % 4],
			             root * arpeggio[step % 4], EIGHTH, .Sine,
			             volume = 0.13, allocator = context.temp_allocator)
			note := mix(bass, lead, allocator = context.temp_allocator)
			append(&out, ..note[:])
		}
	}
	return out
}

load_audio_bank :: proc() -> (bank: Audio_Bank) {
	// Synthesizes the entire soundscape. Takes a few milliseconds; the
	// crypt's audio budget is one proc.
	bank.sounds[.Swing] = to_sound(tone(900, 200, 0.10, .Noise, 0.30))
	bank.sounds[.Hit] = to_sound(tone(180, 70, 0.18, .Square, 0.40))
	bank.sounds[.Coin] = to_sound(tone(900, 1500, 0.09, .Sine, 0.35))
	bank.sounds[.Heart] = to_sound(tone(500, 900, 0.16, .Sine, 0.35))
	// The tone buffers fed into mix are intermediates: mix copies their
	// samples and to_sound frees only the mixed track, so they go on the
	// temp allocator (same as crypt_theme's notes) or they'd leak.
	bank.sounds[.Power] = to_sound(mix(
		tone(400, 400, 0.08, .Square, 0.25, context.temp_allocator),
		tone(600, 600, 0.16, .Square, 0.18, context.temp_allocator)))
	bank.sounds[.Unlock] = to_sound(tone(400, 1200, 0.45, .Triangle, 0.35))
	bank.sounds[.Stairs] = to_sound(tone(500, 180, 0.35, .Triangle, 0.35))
	bank.sounds[.Kill] = to_sound(tone(600, 60, 0.22, .Noise, 0.35))
	bank.sounds[.Game_Over] = to_sound(tone(220, 40, 0.9, .Square, 0.35))
	bank.sounds[.Roar] = to_sound(mix(
		tone(130, 40, 0.55, .Square, 0.40, context.temp_allocator),
		tone(600, 90, 0.55, .Noise, 0.18, context.temp_allocator)))
	victory := tone(523, 523, 0.12, .Sine, 0.35)
	append(&victory, ..tone(659, 659, 0.12, .Sine, 0.35,
	                        context.temp_allocator)[:])
	append(&victory, ..tone(784, 784, 0.30, .Sine, 0.35,
	                        context.temp_allocator)[:]) // C, E, G: the tonic earned
	bank.sounds[.Victory] = to_sound(victory)
	bank.sounds[.Start] = to_sound(mix(
		tone(440, 440, 0.1, .Square, 0.2, context.temp_allocator),
		tone(660, 660, 0.22, .Square, 0.15, context.temp_allocator)))
	theme := crypt_theme()
	bank.music_data = build_wav(theme[:])[:]
	delete(theme)
	bank.music = rl.LoadMusicStreamFromMemory(
		".wav", raw_data(bank.music_data), i32(len(bank.music_data)))
	return
}

destroy_audio_bank :: proc(bank: ^Audio_Bank) {
	// Stop the stream before pulling its WAV bytes out from under it.
	for sound in bank.sounds {
		rl.UnloadSound(sound)
	}
	rl.UnloadMusicStream(bank.music)
	delete(bank.music_data)
}

play :: proc(bank: ^Audio_Bank, sfx: Sfx) {
	rl.PlaySound(bank.sounds[sfx])
}

start_music :: proc(bank: ^Audio_Bank) {
	rl.PlayMusicStream(bank.music)
	rl.SetMusicVolume(bank.music, 0.6)
}

audio_update :: proc(bank: ^Audio_Bank) {
	// Music streams in small buffers; somebody has to keep pouring.
	rl.UpdateMusicStream(bank.music)
}
