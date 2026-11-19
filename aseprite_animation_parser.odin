package sopl

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"
import "core:reflect"

Sprite_Conf :: struct {
	frames: []Frame,
	meta:   Meta,
}

Frame :: struct {
	source_size: Frame_Size `json:"sourceSize"`,
	duration:    u16,
}

Frame_Size :: struct {
	w, h: u32
}

Meta :: struct {
	format:     string,
	size:       Sprite_Size,
	frame_tags: []Frame_Tag `json:"frameTags"`
}

Sprite_Size :: struct {
	w, h: u32
}

Frame_Tag :: struct {
	name: string,
	from, to: u16
}

parse_sprite_sheet :: proc(texture_path, metadata_path: string, $Enum_Type: typeid, allocator := context.temp_allocator) -> (Sprite_Sheet, bool) {
	texture := load_texture(texture_path)
	sprite_conf_bytes, read_err := os.read_entire_file(metadata_path, allocator)
	if read_err != nil {log.error(read_err); return {}, false}

	sprite_conf: Sprite_Conf
	unmarshal_err := json.unmarshal(sprite_conf_bytes, &sprite_conf, json.DEFAULT_SPECIFICATION, allocator)
	if unmarshal_err != nil {log.error(unmarshal_err); return {}, false}
    if (len(sprite_conf.frames) <= 0) { log.error("Wtf bro frames where?"); return {}, false }

    result := Sprite_Sheet {
		texture = texture
	}

    uu i dont have to do any compution bcs the frames have the where
    on the texture there are so maybe i could just create the rect

	for tag, id in sprite_conf.meta.frame_tags {
		state, ok := reflect.enum_from_name(Enum_Type, tag.name)
		if !ok {log.error("Frame tag dosent match the animation states"); return {}, false}

		result.clips[state] = {
            columns = tag.to - tag.from + 1,
            row = id,
		}
	}

	return result, true
}
