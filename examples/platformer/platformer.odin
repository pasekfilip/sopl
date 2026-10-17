package platformer

import "core:fmt"
import s "../../"

main :: proc() {
	width :: 1920
	height :: 1080

	s.init_window("platformer", width, height, .VSYNC)
	defer s.close_window()

    for !s.window_should_close() {
        s.clear_background(s.DARKGRAY)

        // s.draw_rectangle({0, 0, 1200, 50}, s.WHITE)
        s.draw_circle({300, 300}, 100, s.WHITE)

        s.present()
    }
}
