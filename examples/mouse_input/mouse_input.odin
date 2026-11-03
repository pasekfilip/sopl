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
        draw_button({w/2, h/2, 300, 100}, "CLIENT", s.BLUE)
        s.present()
    }
}

draw_button :: proc(rect: s.Rect, text: string, color: s.Color) {
    // character size and height is 8 pixels does that matter ?
    s.draw_rectangle(rect, s.BLUE)
    // text_rect := s.Rect{rect.x + 20, rect.y + 20, rect.w - 20, rect.h -20 }
    // s.draw_text(text_rect, text, s.WHITE)
}
