package platformer

import _ "core:image/png"
import s "../../"

main :: proc() {
    width :: 1920
    height :: 1080

    s.init_window("platformer", width, height)
    defer s.close_window()

    for !s.window_should_close() {
        s.clear(s.DARKGRAY)
        s.draw_circle({400, 400}, 100, s.WHITE)
        s.draw_circle({900, 400}, 100, s.WHITE, 64)
        s.draw_rectangle({100, 400, 100, 100}, s.YELLOW)

        s.present()
    }
}
