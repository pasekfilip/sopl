package sopl
//
// MAX_CLIP_FRAMES :: 16
//
// Animation_State :: enum {
// 	Idle,
// 	Thrust,
// 	Jump,
// 	Run,
// }
//
// Animated_Sprite :: struct {
// 	sprite_sheet:  ^Sprite_Sheet,
// 	state:         Animation_State,
// 	current_frame: u16,
// 	anim_elapsed:  f32,
// 	anim_finished: bool,
// }
//
// Sprite_Sheet :: struct {
// 	frame_width, frame_height: u32,
// 	clips:                     [Animation_State]Animation_Clip,
// 	texture:                   rb.Texture,
// }
//
// Animation_Clip :: struct {
// 	row:         u16,
// 	columns:     u16,
// 	durations:   [MAX_CLIP_FRAMES]u16,
// 	hit_frames:  bit_set[0 ..< MAX_CLIP_FRAMES],
// 	transitions: []Transition,
// 	hitbox:      Hitbox,
// }
//
// update_animation_state :: proc(e: ^Entity, v: ^Animated_Sprite) {
// 	transitions := v.sprite_sheet.clips[v.state].transitions
//
// 	for transition in transitions {
// 		if transition.condition(e) {
// 			v.state = transition.to
// 			v.anim_elapsed = 0
// 			v.current_frame = 0
// 			e.has_swing_hit = false
// 		}
// 	}
// }
//
// update_animation :: proc(v: ^Animated_Sprite, dt: f32) {
// 	current_clip := v.sprite_sheet.clips[v.state]
// 	frame_count := current_clip.columns
//
// 	v.anim_elapsed += dt * 1000
// 	elapsed := f32(current_clip.durations[v.current_frame]) <= v.anim_elapsed
// 	if elapsed {
// 		v.anim_finished = false
// 		v.anim_elapsed = 0
// 		v.current_frame += 1
// 		if v.current_frame >= frame_count {
// 			v.anim_finished = true
// 			v.current_frame = 0
// 		}
// 	}
// }
//
// texture_source :: proc(fliped: bool, v: ^Animated_Sprite) -> rb.Rect {
// 	current_clip := v.sprite_sheet.clips[v.state]
//
// 	w := f32(v.sprite_sheet.frame_width)
// 	if (fliped) do w *= -1
// 	return {
// 		x = f32(v.sprite_sheet.frame_width) * f32(v.current_frame),
// 		y = f32(v.sprite_sheet.frame_height) * f32(current_clip.row),
// 		w = w,
// 		h = f32(v.sprite_sheet.frame_height),
// 	}
// }
