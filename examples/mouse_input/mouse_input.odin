package mouse_input

import "core:fmt"
import s "../.."

Vec2 :: s.Vec2

main :: proc() {
    s.init_window(1280, 780, "mouse", {.RESIZABLE})

    for s.update() {
        w := f32(s.get_window_width())
        h := f32(s.get_window_height())
        
        s.clear_background(s.DARKGRAY)
        if gui_button({(w/2) - 150, (h/2) -50, 300, 100}, "HOST", s.BLUE) {
            s.draw_text({100, 100, 20, 20}, "YES", s.WHITE)
        }
        s.present()
    }
}

// lets add normal hover pressed
gui_button :: proc(rect: s.Rect, text: string, color: s.Color) -> bool {
    FONT_SIZE :: 16
    s.draw_rectangle(rect, color)
    text_rect := s.Rect{rect.x + rect.w/2 - (FONT_SIZE/2)*f32(len(text)), rect.y + rect.h/2 - 8, FONT_SIZE, FONT_SIZE}
    s.draw_text(text_rect, text, s.WHITE)

    s.is_mouse_button_pressed() or_return
    mouse_pos := s.get_mouse_position()
    collided, _ := s.aabb(rect, {mouse_pos.x, mouse_pos.y, 5, 5})
    return collided
}
