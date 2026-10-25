package main

import engine "src"
import sdl "vendor:sdl3"

gravity: f32 = 250
speed: f32 = 50
max_speed: f32 = 50
jump: f32 = 100

Entity :: struct {
	name:           string,
	health:         u16,
	translate:      [3]f32,
	scale:          [3]f32,
	rotation:       f32,
	update:         proc(e: ^Entity, input: bit_set[Keys], dt: f32),
	on_hit:         proc(e: ^Entity, e2: ^Entity),
	on_collision:   proc(e: ^Entity, e2: ^Entity, difference: [2]f32),
	visual:         Visual,
	velocity:       [2]f32,
	on_ground:      bool,
	category:       Layer,
	mask:           bit_set[Layer],
	fliped:         bool,
	attack_pressed: bool,
	is_dead:        bool,
	has_swing_hit:  bool,
	damage:         u16,
}

Visual :: union {
	Animated_Sprite,
	engine.Color,
}

Keys :: enum {
	W,
	A,
	S,
	D,
	J,
	SPACE,
	X,
}


Layer :: enum {
	Ground,
	Enemy,
	Player,
}

Hitbox :: struct {
	offset: [3]f32,
	size:   [3]f32,
}

Transition :: struct {
	to:        Animation_State,
	condition: proc(e: ^Entity) -> bool,
}

create_world :: proc() -> [dynamic]^Entity {
	all_e: [dynamic]^Entity
	append(&all_e, spawn_ground())
	return all_e
}

spawn_player :: proc(sprite_sheet: ^Sprite_Sheet) -> ^Entity {
	update_player :: proc(e: ^Entity, input: bit_set[Keys], dt: f32) {
		keys := sdl.GetKeyboardState(nil)

		if keys[sdl.Scancode.A] {
			e.fliped = true
			if e.velocity.x > -max_speed do e.velocity.x -= speed
		} else if keys[sdl.Scancode.D] {
			e.fliped = false
			if e.velocity.x < max_speed do e.velocity.x += speed
		}

		if .J in input do e.attack_pressed = true
		else do e.attack_pressed = false

		if .SPACE in input && e.on_ground == true {
			e.on_ground = false
			e.velocity.y = jump
		}
	}

	on_hit :: proc(e: ^Entity, e2: ^Entity) {
		if e.has_swing_hit do return
		e2.health -= e.damage
		e.has_swing_hit = true
	}

	player: Entity = {
		name = "Player",
		damage = 50,
		translate = {0, 0, 1},
		scale = {20, 20, 1},
		update = update_player,
		on_collision = on_collision,
		on_hit = on_hit,
		visual = Animated_Sprite{sprite_sheet = sprite_sheet, state = .Idle},
		velocity = {0, 0},
		category = .Player,
		mask = {.Ground, .Enemy},
	}

	return new_clone(player)
}

spawn_enemy :: proc(sprite_sheet: ^Sprite_Sheet) -> ^Entity {
	enemy: Entity = {
		health = 100,
		name = "enemy",
		translate = {-50, 0, 1},
		scale = {20, 20, 1},
		update = proc(e: ^Entity, input: bit_set[Keys], dt: f32) {
			if e.health <= 0 do e.is_dead = true
		},
		on_collision = on_collision,
		visual = Animated_Sprite{sprite_sheet = sprite_sheet, state = .Idle},
		velocity = {0, 0},
		category = .Enemy,
		mask = {.Ground, .Player},
	}
	return new_clone(enemy)
}

on_collision :: proc(e: ^Entity, e2: ^Entity, difference: [2]f32) {
	#partial switch e2.category {
	case .Ground:
		e.translate.y += difference.y
		e.on_ground = true
		e.velocity.y = 0
		break
	case .Enemy:
		// e.velocity.x += difference.x * 10
		break
	}
}

spawn_ground :: proc() -> ^Entity {
	ground: Entity = {
		translate = {0, -30, 1},
		scale = {200, 10, 1},
		visual = engine.Color{1, 0, 0, 1},
		category = .Ground,
		mask = {.Player, .Enemy},
	}

	return new_clone(ground)
}

delete_all_dead_entites :: proc(all_e: ^[dynamic]^Entity) {
	for e, i in all_e {
		if e.is_dead do unordered_remove(all_e, i)
	}
}
