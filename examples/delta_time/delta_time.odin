package delta_time

import s "../../"
import _ "core:image/png"
import "core:fmt"
import "core:log"

WORLD_W    :: 320
WORLD_H    :: 180
SCREEN_W   :: 1280
SCREEN_H   :: 720

main :: proc() {
    context.logger = log.create_console_logger()
	s.init_window(SCREEN_W, SCREEN_H, "delta time", {})
	defer s.close_window()

	circle_1 := [2]f32{100, 400}
	circle_2 := [2]f32{100, 600}

    texture := s.load_texture("./Player Idle 48x48.png")

    speed: f32 = 5
    frame_speed: f32 = 0.1
    elapsed: f32
    cur_frame: u8
    frame_rect := s.Rect{0, 0, f32(texture.w/10), f32(texture.h)}

    // meaning we are running the loop 144 times per second or 60 times per second
    // so if we multiple something so technically if we want animatin to move every half a second we just need
    // dt to fill half a second

	for s.update() {
        dt := s.get_delta_time()
        elapsed += dt
        if (elapsed >= frame_speed) {
            cur_frame += 1
            elapsed = 0
            if cur_frame > 9 {
                cur_frame = 0
                frame_rect.x = 0
            }

            frame_rect.x += frame_rect.w/f32(texture.w)
        }

        // if s.is_key_pressed(.W) do n += 1
		is_culled :: proc(x: f32) -> bool {return x >= WORLD_W}
		if is_culled(circle_1.x) do circle_1.x = 0
		if is_culled(circle_2.x) do circle_2.x = 0

		circle_1.x += speed * dt
		circle_2.x += speed

        w := f32(s.get_window_width())
        h := f32(s.get_window_height())

        scale := min(w/WORLD_W, h/WORLD_H)
        camera := s.Camera{
            zoom = scale
        }
        s.clear_background(s.DARKGRAY)
        s.set_camera(camera)
        s.draw_fps({0, 0})
        s.draw_texture(texture, frame_rect, {50, 50}, s.WHITE)
		s.draw_circle(circle_1, 100, s.WHITE)
		s.draw_circle(circle_2, 100, s.WHITE)
		s.present()
	}
}
