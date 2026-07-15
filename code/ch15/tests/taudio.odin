// Headless tests for the synthesizer: the sounds are arithmetic, so
// their invariants are checkable without an audio device.

package tests

import "core:testing"
import crypt "../src"

@(test)
a_tone_is_the_right_length_and_fades_to_silence :: proc(t: ^testing.T) {
	tone := crypt.tone(440, 440, 0.5, .Sine, volume = 0.5)
	defer delete(tone)
	testing.expect_value(t, len(tone), 22050) // half a second at 44100 Hz
	testing.expect(t, abs(tone[len(tone) - 1]) < 500) // envelope ends near zero
	peak := 0
	for s in tone {
		peak = max(peak, abs(int(s)))
	}
	testing.expect(t, peak > 10_000)  // and it is not silence
	testing.expect(t, peak <= 16_000) // 0.5 volume of 32000
}

@(test)
pure_shapes_are_deterministic :: proc(t: ^testing.T) {
	a := crypt.tone(440, 220, 0.1, .Square)
	defer delete(a)
	b := crypt.tone(440, 220, 0.1, .Square)
	defer delete(b)
	testing.expect_value(t, len(a), len(b))
	for s, i in a {
		testing.expect_value(t, s, b[i])
	}
}

@(test)
mix_takes_the_length_of_the_longest_track_and_clips_politely :: proc(t: ^testing.T) {
	long := crypt.tone(200, 200, 0.3, .Square, volume = 0.9)
	defer delete(long)
	short := crypt.tone(400, 400, 0.1, .Square, volume = 0.9)
	defer delete(short)
	m := crypt.mix(long, short)
	defer delete(m)
	testing.expect_value(t, len(m), len(long))
	for s in m {
		testing.expect(t, abs(int(s)) <= 32000) // saturating add never wraps
	}
}

@(test)
the_wav_wrapper_writes_a_well_formed_header :: proc(t: ^testing.T) {
	samples := crypt.tone(440, 440, 0.1, .Sine)
	defer delete(samples)
	wav := crypt.build_wav(samples[:])
	defer delete(wav)
	testing.expect_value(t, len(wav), 44 + len(samples) * 2)
	testing.expect(t, wav[0] == 'R' && wav[1] == 'I' &&
	                  wav[2] == 'F' && wav[3] == 'F')
	testing.expect(t, wav[8] == 'W' && wav[9] == 'A' &&
	                  wav[10] == 'V' && wav[11] == 'E')
	// sample rate field, little endian, at offset 24
	rate := int(wav[24]) | (int(wav[25]) << 8) |
	        (int(wav[26]) << 16) | (int(wav[27]) << 24)
	testing.expect_value(t, rate, 44100)
}
