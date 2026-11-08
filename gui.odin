package sopl

import "core:fmt"
import "core:bytes"

DEFAULT_FONT_COLUMNS :: 16
DEFAULT_FONT_ROWS    :: 8
DEFAULT_FONT_HEIGHT  :: 12
DEFAULT_FONT_WIDTH   :: 6

sl: Stack_Layout

Stack_Layout :: struct {
    pos:     Vec2,
    cursor,  gap: f32
}

/*
    TODO: not sure if the font is int scaled rn
    TODO: Make outline on the button
*/
gui_button :: proc(rect: Rect, text: string, color: Color) -> bool {
    mouse_pos := get_mouse_position()
    collided, _ := aabb(rect, {mouse_pos.x, mouse_pos.y, 5, 5})

    hover_alpha := color.a
    if collided do hover_alpha = 126

    font_scale := rect.h/24
    draw_rectangle(rect, {color.r, color.g, color.b, hover_alpha})

    text_pos_x := rect.x + rect.w/2 - (DEFAULT_FONT_WIDTH*font_scale/2) * f32(len(text)) 
    text_pos_y := rect.y + rect.h/2 - (DEFAULT_FONT_HEIGHT*font_scale)/2
    draw_text({text_pos_x, text_pos_y}, text, u32(font_scale), {WHITE.r, WHITE.g, WHITE.b, hover_alpha})

    is_mouse_button_pressed() or_return
    return collided
}

/*
    The input width is based on the text_buf lenght
*/
gui_input :: proc(pos: Vec2, height: f32, text_buf: []u8) {
    font_scale := u32(height/12)
    text_size := get_text_size(int(font_scale), len(text_buf))
    mouse_pos := get_mouse_position()

    // the font_scale add is to add single pixel at the back of the input
    input_rect := Rect{pos.x, pos.y, text_size.x + f32(font_scale), height}
    collided, _ := aabb(input_rect, {mouse_pos.x, mouse_pos.y, 5, 5})
    draw_rectangle(input_rect, GRAY)

    text_count := bytes.index_byte(text_buf, 0)
    if text_count == -1 do text_count = len(text_buf)
    draw_text({pos.x, pos.y}, string(text_buf[:text_count]), font_scale)

    if !collided { stop_text_input(); return }
    start_text_input()
    char := get_char_pressed()

    if is_key_pressed(.BACKSPACE) && text_count != 0 {
        text_buf[text_count - 1] = 0
    }

    if text_count < len(text_buf) {
        ticks := int(get_ticks() * 2)
        if ticks % 2 == 0 {
            draw_rectangle({
                pos.x + f32(DEFAULT_FONT_WIDTH * font_scale) * f32(text_count), pos.y + height - text_size.y/8,
                f32(DEFAULT_FONT_WIDTH * font_scale),
                text_size.y/8
            }, WHITE)
        }

        text_buf[text_count] = char
    }
}

show_center :: proc() {
    w := f32(get_window_width())
    h := f32(get_window_height())

    draw_rectangle({w/2 - 1, 0, 2, h}, WHITE)
    draw_rectangle({0, h/2 - 1, w, 2}, WHITE)
}

stack_layout :: proc(pos: Vec2, gap: f32) {
    sl.pos = pos
    sl.cursor = 0
    sl.gap = gap
}

move_cursor :: proc(size: Vec2) -> Rect {
    result := Rect{
        sl.pos.x - size.x/2,
        sl.pos.y - size.y/2 + sl.cursor,
        size.x,
        size.y
    }
    sl.cursor += size.y + sl.gap
    return result
}
