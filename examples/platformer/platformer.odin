package platformer

import "core:fmt"
import s "../../"

Entity_high :: struct {

}

Entity :: struct {
    using rect: s.Rect,
    collision_offset: [2]f32,
    collision_size: [2]f32,
    update: proc(e: ^Entity),
    collision: proc(),
    color: s.Color,
    index: E_Handle,
    alive: bool
}
E_Handle :: u32

add_entity :: proc(entity: Entity) {
    index: u32
    for e in entities {
        if e.alive == false do break
        index += 1
    }
    entities[index] = entity
    entities[index].alive = true
}

remove_entity :: proc(entity: Entity) {
    entities[entity.index].alive = false
}

MAX :: 1000
GRAVITY :: 100
entities : [MAX]Entity

main :: proc() {
    init()
    for step() {}
    end()
}

init :: proc() {
    add_entity({
        rect = { x = 140, y = 90, w = 20, h = 20 },
        color = s.ORANGE,
        collision_offset = {5, 5},
        collision_size = {10, 10},
        update = proc(e: ^Entity) {
            if s.is_key_down(.D) do e.x += 1
            if s.is_key_down(.A) do e.x -= 1
            // e.y += GRAVITY * f32(s.get_delta_time())
        },
        collision = proc() {
        }
    })
    add_entity({
        rect = { x = 180, y = 90, w = 20, h = 20 },
        color = s.WHITE,
        update = proc(e: ^Entity) {
            // e.y += GRAVITY * f32(s.get_delta_time())
        },
        collision = proc() {
        }
    })
    // add_entity({
    //     rect = { x = 50, y = 150, w = 200, h = 10 },
    //     color = s.WHITE,
    //     update = proc(e: ^Entity) {
    //
    //     },
    //     collision = proc() {
    //
    //     }
    // })

    width :: 320
    height :: 180

    s.init_window("platformer", width, height, .VSYNC)
}

camera := s.Camera {
    zoom = 1
}

// so we are doing update collision draw
step :: proc() -> bool {
    for &e in entities { if !e.alive do break; e.update(&e) }

    for e, i in entities {
        if !e.alive do break;
        for e2 in entities[i + 1:] {
            if !e2.alive do break;
            fmt.println(s.aabb(recompute_collision_box(e), e2))
        }
    }

    s.set_camera(camera)
    s.clear_background(s.DARKGRAY)
    for e in entities {
        if !e.alive do break
        s.draw_rectangle(e.rect, e.color)
        s.draw_rectangle_outline(recompute_collision_box(e), s.RED)
    }
    s.present()

    return !s.update()
}

end :: proc() {
    s.close_window()
}

recompute_collision_box :: proc(e: Entity) -> s.Rect {
    return {e.x + e.collision_offset.x, e.y + e.collision_offset.y, e.collision_size.x, e.collision_size.y}
}

