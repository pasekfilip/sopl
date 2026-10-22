package platformer

import "core:fmt"
import s "../../"

main :: proc() {
	width :: 320
	height :: 180

	s.init_window("platformer", width, height, .VSYNC)
	defer s.close_window()

    x: f32 = 0
    camera := s.Camera {
        zoom = 1
    }

    for !s.update() {
        if (s.is_key_down(.K)) do camera.zoom += 0.1
        if (s.is_key_down(.J)) do camera.zoom -= 0.1

        if (s.is_key_down(.W)) do camera.offset.y -= 5
        if (s.is_key_down(.S)) do camera.offset.y += 5
        if (s.is_key_down(.D)) do camera.offset.x += 5
        if (s.is_key_down(.A)) do camera.offset.x -= 5

        if (s.is_key_down(.E)) do camera.rotation -= 0.01
        if (s.is_key_down(.Q)) do camera.rotation += 0.01


        s.set_camera(camera)

        s.clear_background(s.DARKGRAY)
        s.draw_rectangle({500, 300, 100, 100}, s.WHITE)
        s.draw_rectangle({1000, 300, 100, 100}, s.WHITE)

        s.present()
    }
}
