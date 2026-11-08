package mouse_input

import "core:fmt"
import s "../.."

BUTTON_W      :: 300
BUTTON_H      :: 100
INPUT_W       :: 700
INPUT_H       :: 100
BUTTON_COLOR  :: s.MAROON
GAP           :: 20

ui: UI
ip_addr: [15]u8

Vec2 :: s.Vec2
Rect :: s.Rect

UI :: enum {
    None,
    Client,
    Host
}

main :: proc() {
    s.init_window(1280, 720, "mouse", {})
    s.hide_cursor()

    for s.update() {
        w := f32(s.get_window_width())
        h := f32(s.get_window_height())

        s.clear_background(s.DARKGRAY)
        mouse_pos := s.get_mouse_position()
        s.draw_rectangle({mouse_pos.x, mouse_pos.y, 5, 5}, s.WHITE)

        s.stack_layout({w/2, h/2}, GAP)

        title := "Crazy multiplayer pong!!"
        text_pos := s.move_cursor(s.get_text_size(10, len(title)))
        s.draw_text({text_pos.x, text_pos.y}, title, 10)
        s.draw_text({0, 0}, fmt.tprint(ui), 10)
        switch ui {
        case .None:
            if s.gui_button(s.move_cursor({BUTTON_W, BUTTON_H}), "Host", BUTTON_COLOR) {
                ui = .Host
            }
            if s.gui_button(s.move_cursor({BUTTON_W, BUTTON_H}), "Client", BUTTON_COLOR) {
                ui = .Client
            }
        case .Host:
            wating_text := "Wating for client"
            text_pos := s.move_cursor(s.get_text_size(5, len(wating_text)))
            s.draw_text({text_pos.x, text_pos.y}, wating_text, 5, s.YELLOW)
            if s.gui_button(s.move_cursor({BUTTON_W, BUTTON_H}), "Cancel", BUTTON_COLOR) {
                ui = .None
            }
        case .Client:
            rect := s.move_cursor({INPUT_W, INPUT_H})
            s.gui_input({rect.x, rect.y}, rect.h, ip_addr[:])
            if s.gui_button(s.move_cursor({BUTTON_W, BUTTON_H}), "Cancel", BUTTON_COLOR) {
                ui = .None
            }
        }
        if s.gui_button(s.move_cursor({BUTTON_W, BUTTON_H}), "Exit", BUTTON_COLOR) {
            s.close_window()
        }

        s.present()
    }
}
