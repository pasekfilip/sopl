package platformer

import _ "core:image/png"
import s "../../"

main :: proc() {
    width :: 1920
    height :: 1080

    s.init_window("platformer", width, height)
    defer s.close_window()

    for !s.window_should_close() {
        s.clear(s.LIGHTGRAY)
        s.draw_rectangle({x = 300, y = 200, width = 100, height = 100}, s.RED)

        s.draw_rectangle({x = 500, y = 400, width = 100, height = 100}, s.YELLOW)

        s.present()
    }
}
