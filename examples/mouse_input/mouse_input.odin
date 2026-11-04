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
        ui_camera := s.Camera{
            offset = {w/2, h/2},
            zoom = 1
        }

        s.set_camera(ui_camera)
        BUTTON_W  :: 300
        BUTTON_H :: 100

        s.draw_text({-BUTTON_W/2 - 300, -BUTTON_H/2 - (3*BUTTON_H) - 50, 30, 60},"Crazy multiplayer pong!!")
        if s.gui_button({-BUTTON_W/2, -BUTTON_H/2 - BUTTON_H - 50, BUTTON_W, BUTTON_H}, "Host", s.GRAY) {}
        if s.gui_button({-BUTTON_W/2, -BUTTON_H/2, BUTTON_W, BUTTON_H}, "Client", s.GRAY) {}

        s.present()
    }
}

