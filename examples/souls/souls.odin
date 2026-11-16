package platformer

import "core:fmt"
import "core:log"
import "base:intrinsics"
import s "../../"

WORLD_W    :: 320
WORLD_H    :: 180
SCREEN_W   :: 1280
SCREEN_H   :: 720
GRAVITY    :: 300
MAX        :: 1000

E_Handle :: u32
Rect :: s.Rect
Vec2 :: s.Vec2

entities:  [MAX]Entity
clips:     [Animation]Clip
g:         Game_State 

Game_State :: struct {
    p1_index: u32
}

Entity :: struct {
    using              rect:        s.Rect,
    collision_offset:  [2]f32,
    collision_size:    [2]f32,
    velocity:          [2]f32,
    update:            proc(e: ^Entity, dt: f32),
    on_collision:      proc(e: ^Entity, e2: ^Entity),
    clip:              Clip,
    frame:             u16,
    elapsed:           f32,
    color:             s.Color,
    category:          Layer,
    mask:              bit_set[Layer],
    on_ground:         bool,
    index:             E_Handle,
    alive:             bool
}

/* 
Clip should be frames of single animation e.g Attack
i think that it should prop be some src rectangle
*/
Clip :: struct {
    tex:          s.Texture,
    frame_count:  u16,
    frame_w:      u16,
    frame_h:      u16,
    duration:    f32,
    pivot:        Vec2
}

Animation :: enum {
    Idle,
    Walk,
    Attack,
    Jump,
    Roll
}

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

main :: proc() {
    context.logger = log.create_console_logger()
    init()
    for step() {}
    end()
}

init :: proc() {
    s.init_window(SCREEN_W, SCREEN_H, "souls", {})
    s.set_fps(30)

    idle := s.load_texture("./Player Idle 48x48.png")
    clips[.Idle] = {
        tex = idle,
        frame_count = 10,
        frame_w = idle.w/10,
        frame_h = idle.h,
        duration = 0.1,
        pivot = Vec2{f32(idle.w/(10*2)), f32(idle.h)*(5/6.)}
    }

    walk := s.load_texture("./PlayerWalk 48x48.png")
    clips[.Walk] = {
        tex = walk,
        frame_count = 8,
        frame_w = walk.w/8,
        frame_h = walk.h,
        duration = 0.1,
        pivot = Vec2{f32(idle.w/(8*2)), f32(idle.h)*(5/6.)}
    }

    g.p1_index = add_entity({
        rect = {x = 140, y = 90, w = f32(walk.w/8), h = f32(walk.h)},
        color = s.WHITE,
        collision_offset = {-5, -20},
        collision_size = {10, 20},
        category = .Player,
        mask = {.Ground},
        clip = clips[.Idle],
        update = proc(e: ^Entity, dt: f32) {
            if s.is_key_down(.D) do e.x += 200 * dt
            if s.is_key_down(.A) do e.x -= 200 * dt

            if e.on_ground && s.is_key_pressed(.SPACE) {
                e.on_ground = false
                e.velocity.y -= 200
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

    // add_entity({
    //     rect = { x = 180, y = 90, w = 20, h = 20 },
    //     color = s.WHITE,
    //     category = .Player,
    //     mask = {.Ground},
    //     update = proc(e: ^Entity, dt: f32) { },
    //     on_collision = proc(e: ^Entity, e2: ^Entity) {
    //     }
    // })

    add_entity({
        rect = { x = 0, y = WORLD_H - 10, w = WORLD_W, h = 10 },
        color = s.WHITE,
        collision_offset = {0, 0},
        collision_size = {WORLD_W, 10},
        category = .Ground,
        mask = {.Player},
        update = proc(e: ^Entity, dt: f32) { },
        on_collision = proc(e: ^Entity, e2: ^Entity) { }
    })
}

step :: proc() -> bool {
    s.update() or_return

    // 1. entity phsycis udpate
    for &e in entities {
        if !e.alive do break
        e.update(&e, s.get_delta_time()) 
        if e.category == .Player do apply_physics(&e, s.get_delta_time())
    }

    // 2. collison check
    for &e, i in entities {
        if !e.alive do break;
        for &e2 in entities[i + 1:] {
            if !e2.alive do break;
            if e.category not_in e2.mask do continue
            e.on_ground = false
            collided, overflow := s.aabb(recompute_collision_box(e), recompute_collision_box(e2)) 
            if collided {
                e.on_collision(&e, &e2)
                PUSH_BACK_VEL :: 10
                e.velocity.y -= overflow.y * PUSH_BACK_VEL * s.get_delta_time()
            }
        }
    }

    // i think that i will adjus the size of the draw box in the animation
    // bcs the draw box can be even bigger its fine it only draws nothing else
    //3. update animation ? (i think i should update the animation after changes in positon and state of entities)
    for &e in entities {
        e.alive or_break
        #partial switch e.category  {
        case .Player:
            e.elapsed += s.get_delta_time()
            if (e.elapsed >= e.clip.duration) {
                e.frame += 1
                e.elapsed = 0
                if e.frame > e.clip.frame_count -1 do e.frame = 0
            }
        }
    }

    //4. draw
    w := f32(s.get_window_width())
    h := f32(s.get_window_height())

    scale := min(w/WORLD_W, h/WORLD_H)
    p1 := entities[g.p1_index]
    camera := s.Camera{
        zoom = scale
    }
    s.clear_background(s.DARKGRAY)
    s.set_camera(camera)

    s.draw_fps({0,0})

    for e in entities {
        e.alive or_break
        #partial switch e.category  {
        case .Player:
            frame_rec := Rect{f32(e.clip.frame_w * e.frame), 0, f32(e.clip.frame_w), f32(e.clip.frame_h)}
            s.draw_texture(e.clip.tex, frame_rec, e.rect, e.clip.pivot)
        case .Ground:
            s.draw_rectangle(e.rect, e.color)
        }
        s.draw_rectangle_outline(recompute_collision_box(e), s.RED)
    }

    s.present()
    return true
}

end :: proc() {
    s.close_window()
}

apply_physics :: proc(e: ^Entity, dt: f32) {
	if !e.on_ground do e.velocity.y += GRAVITY * dt
	// if abs(e.velocity.x) > 0 {
	// 	e.velocity.x *= 0.9
	// }
	// if abs(e.velocity.x) < 10 {
	// 	e.velocity.x = 0
	// }

	// e.x += e.velocity.x * dt
	e.y += e.velocity.y * dt
}

recompute_collision_box :: proc(e: Entity) -> s.Rect {
    return {e.x + e.collision_offset.x, e.y + e.collision_offset.y, e.collision_size.x, e.collision_size.y}
}
