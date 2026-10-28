package delta_time

import s "../../"
import _ "core:image/png"

main :: proc() {
	width :: 1920
	height :: 1080

	s.init_window("delta time", width, height, .VSYNC)
	defer s.close_window()

	circle_1 := [2]f32{100, 400}
	circle_2 := [2]f32{100, 600}

    speed: f64 = 5
	for !s.update() {
        dt := s.get_delta_time()

		is_culled :: proc(x: f32) -> bool {return x >= width}
		if is_culled(circle_1.x) do circle_1.x = 0
		if is_culled(circle_2.x) do circle_2.x = 0

		circle_1.x += speed * dt
		circle_2.x += speed

        s.clear_background(s.DARKGRAY)
		s.draw_circle(circle_1, 100, s.WHITE)
		s.draw_circle(circle_2, 100, s.WHITE)
		s.present()
	}
}
