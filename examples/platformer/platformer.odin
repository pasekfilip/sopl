package platformer

import "core:fmt"
import s "../../"

Entity :: struct {
    using rect:         s.Rect,
    collision_offset:   [2]f32,
    collision_size:     [2]f32,
    velocity:           [2]f32,
    update:             proc(e: ^Entity, dt: f32),
    on_collision:       proc(e: ^Entity, e2: ^Entity),
    color:              s.Color,
	category:           Layer,
	mask:               bit_set[Layer],
    on_ground:          bool,
    index:              E_Handle,
    alive:              bool
}
E_Handle :: u32

Layer :: enum {
	Ground,
	Enemy,
	Player,
}

add_entity :: proc(entity: Entity) -> u32 {
    index: u32
    for e in entities {
        if e.alive == false do break
        index += 1
    }
    entities[index] = entity
    entities[index].alive = true
    return index
}

remove_entity :: proc(entity: Entity) {
    entities[entity.index].alive = false
}

WIDTH :: 320
HEIGHT :: 180
MAX :: 1000
GRAVITY :: 10
entities: [MAX]Entity
p1_index: u32

main :: proc() {
    init()
    for step() {}
    end()
}

init :: proc() {
    p1_index = add_entity({
        rect = { x = 140, y = 90, w = 20, h = 20 },
        color = s.ORANGE,
        collision_offset = {5, 5},
        collision_size = {10, 15},
        category = .Player,
        mask = {.Ground},
        update = proc(e: ^Entity, dt: f32) {
            if s.is_key_down(.D) do e.x += 100 * dt
            if s.is_key_down(.A) do e.x -= 100 * dt

            if e.on_ground && s.is_key_pressed(.SPACE) {
                e.on_ground = false
                e.velocity.y -= 300
            }
        },
        on_collision = proc(e: ^Entity, e2: ^Entity) {
            #partial switch e2.category {
            case .Ground:
                e.on_ground = true
                e.velocity.y = 0
            break
            }
        }
    })

    add_entity({
        rect = { x = 180, y = 90, w = 20, h = 20 },
        color = s.WHITE,
        category = .Player,
        mask = {.Ground},
        update = proc(e: ^Entity, dt: f32) { },
        on_collision = proc(e: ^Entity, e2: ^Entity) {
        }
    })
    add_entity({
        rect = { x = 50, y = 150, w = 500, h = 10 },
        color = s.WHITE,
        collision_offset = {0, 0},
        collision_size = {500, 10},
        category = .Ground,
        mask = {.Player},
        update = proc(e: ^Entity, dt: f32) { },
        on_collision = proc(e: ^Entity, e2: ^Entity) { }
    })


    s.init_window("platformer", WIDTH, HEIGHT, .VSYNC)
}

// so we are doing update collision draw
step :: proc() -> bool {
    for &e in entities {
        if !e.alive do break
        e.update(&e, s.get_delta_time()) 
        if e.category == .Player do apply_physics(&e, s.get_delta_time())
    }

    for &e, i in entities {
        if !e.alive do break;
        for &e2 in entities[i + 1:] {
            if !e2.alive do break;
            if e.category not_in e2.mask do continue
            e.on_ground = false
            if s.aabb(recompute_collision_box(e), recompute_collision_box(e2)) {
                e.on_collision(&e, &e2)
            }
        }
    }

    p1 := entities[p1_index]
    camera := s.Camera{
        offset = {-p1.x + WIDTH/2, -p1.y + HEIGHT/2},
        zoom = 1
    }

    s.clear_background(s.DARKGRAY)
    s.set_camera(camera)
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

apply_physics :: proc(e: ^Entity, dt: f32) {
	if !e.on_ground do e.velocity.y += GRAVITY
	if abs(e.velocity.x) > 0 {
		e.velocity.x *= 0.9
	}
	if abs(e.velocity.x) < 10 {
		e.velocity.x = 0
	}

	e.x += e.velocity.x * dt
	e.y += e.velocity.y * dt
}

recompute_collision_box :: proc(e: Entity) -> s.Rect {
    return {e.x + e.collision_offset.x, e.y + e.collision_offset.y, e.collision_size.x, e.collision_size.y}
}

