package platformer

import "core:fmt"
import s "../../"

main :: proc() {
    r1 := s.Rect {
        x = 140,
        y = 90,
        w = 20,
        h = 20,
    }

    r2 := s.Rect {
        x = 180,
        y = 90,
        w = 20,
        h = 20,
    }

    s.aabb(r1, r2)

	width :: 320
	height :: 180

	s.init_window("platformer", width, height, .VSYNC)
	defer s.close_window()

    x: f32 = 0
    camera := s.Camera {
        zoom = 1
    }

    for !s.update() {
        s.set_camera(camera)

        s.clear_background(s.DARKGRAY)

        s.draw_rectangle(r1, s.ORANGE)
        s.draw_rectangle(r2, s.WHITE)

        s.present()
    }
}
