package sopl
//
// import "base:runtime"
// import "core:encoding/json"
// import "core:fmt"
// import "core:log"
// import "core:os"
// import "core:reflect"
//
// Sprite_Conf :: struct {
// 	frames: []Frame,
// 	meta:   Meta,
// }
//
// Frame :: struct {
// 	source_size: Frame_Size `json:"sourceSize"`,
// 	duration:    u16,
// }
//
// Frame_Size :: struct {
// 	w, h: u32,
// }
//
// Meta :: struct {
// 	format:     string,
// 	size:       Sprite_Size,
// 	frame_tags: []Frame_Tag `json:"frameTags"`,
// }
//
// Sprite_Size :: struct {
// 	w: u32,
// 	h: u32,
// }
//
// Frame_Tag :: struct {
// 	name: string,
// 	from: u8,
// 	to:   u8,
// }
//
// parse_sprite_sheet :: proc(
// 	texture_name: string,
// 	allocator := context.temp_allocator,
// ) -> (
// 	^Sprite_Sheet,
// 	bool,
// ) {
// 	texture := engine.load_texture(fmt.tprintf("./assets/%s.png", texture_name))
// 	sprite_conf_bytes, err := os.read_entire_file(
// 		fmt.tprintf("./assets/%s.json", texture_name),
// 		allocator,
// 	)
//
// 	if err != nil {
// 		log.error(err)
// 		return {}, false
// 	}
//
// 	sprite_conf: Sprite_Conf
// 	err2 := json.unmarshal(sprite_conf_bytes, &sprite_conf, json.DEFAULT_SPECIFICATION, allocator)
// 	if err2 != nil {
// 		log.error(err)
// 		return {}, false
// 	}
//     if (len(sprite_conf.frames) <= 0) {
// 		log.error("wtf bro frames where")
// 		return {}, false
// 	}
//
// 	result: Sprite_Sheet = {
// 		texture      = texture,
// 		frame_width  = sprite_conf.frames[0].source_size.w,
// 		frame_height = sprite_conf.frames[0].source_size.h,
// 	}
//
// 	for tag, id in sprite_conf.meta.frame_tags {
// 		anim_state, err3 := reflect.enum_from_name(Animation_State, tag.name)
// 		if !err3 {
// 			log.error("frame tag dosent match the animation states")
// 			return {}, false
// 		}
//
// 		durations: [MAX_CLIP_FRAMES]u16
// 		for frame, id in sprite_conf.frames[tag.from:tag.to + 1] {
// 			durations[id] = frame.duration
// 		}
// 		result.clips[anim_state] = {
// 			durations = durations,
// 			columns   = u16(tag.to - tag.from) + 1,
// 			row       = u16(id),
// 		}
// 	}
//
// 	return new_clone(result), true
// }
