package sopl

import "core:fmt"
import "core:math"
import "core:image"
import _ "core:image/png"
import "core:log"
import "core:math/linalg"
import "core:time"
import sdl "vendor:sdl3"
import "core:mem"
import "core:strings"

g: ^State
batch_vertices: [dynamic; MAX_VERTICES]Vertex
draw_commands: [dynamic; BATCH_QUAD_CAPACITY]Draw_Command

TEMPLATE_VERTEX: [4]Vertex : {
	{pos = {0, 1, 1}, uv = {0, 1}},
	{pos = {1, 1, 1}, uv = {1, 1}},
	{pos = {1, 0, 1}, uv = {1, 0}},
	{pos = {0, 0, 1}, uv = {0, 0}},
}

BATCH_QUAD_CAPACITY :: 3000
MAX_VERTICES :: BATCH_QUAD_CAPACITY * 4
MAX_VERTICES_BYTES :: MAX_VERTICES * size_of(Vertex)
MAX_TRANSFER_BUFFER_SIZE_BYTES :: MAX_VERTICES * size_of(Vertex)
INDICES_PER_QUAD :: 6
MAX_INDICES :: BATCH_QUAD_CAPACITY * INDICES_PER_QUAD

Vec3 :: [3]f32
Vec2 :: [2]f32

Scancode :: sdl.Scancode
PresentMode :: sdl.GPUPresentMode

Color :: [4]u8
LIGHTGRAY  :: Color{ 200, 200, 200, 255 }
GRAY       :: Color{ 130, 130, 130, 255 }
DARKGRAY   :: Color{ 80, 80, 80, 255 }
YELLOW     :: Color{ 253, 249, 0, 255 }
GOLD       :: Color{ 255, 203, 0, 255 }
ORANGE     :: Color{ 255, 161, 0, 255 }
PINK       :: Color{ 255, 109, 194, 255 }
RED        :: Color{ 230, 41, 55, 255 }
MAROON     :: Color{ 190, 33, 55, 255 }
GREEN      :: Color{ 0, 228, 48, 255 }
LIME       :: Color{ 0, 158, 47, 255 }
DARKGREEN  :: Color{ 0, 117, 44, 255 }
SKYBLUE    :: Color{ 102, 191, 255, 255 }
BLUE       :: Color{ 0, 121, 241, 255 }
DARKBLUE   :: Color{ 0, 82, 172, 255 }
PURPLE     :: Color{ 200, 122, 255, 255 }
VIOLET     :: Color{ 135, 60, 190, 255 }
DARKPURPLE :: Color{ 112, 31, 126, 255 }
BEIGE      :: Color{ 211, 176, 131, 255 }
BROWN      :: Color{ 127, 106, 79, 255 }
DARKBROWN  :: Color{ 76, 63, 47, 255 }

WHITE      :: Color{ 255, 255, 255, 255 }
BLACK      :: Color{ 0, 0, 0, 255 }
BLANK      :: Color{ 0, 0, 0, 0 }
MAGENTA    :: Color{ 255, 0, 255, 255 }
RAYWHITE   :: Color{ 245, 245, 245, 255 }

State :: struct {
    device:                   ^sdl.GPUDevice,
    display:                  sdl.DisplayID,
    window:                   ^sdl.Window,
    window_width:             i32,
    window_height:            i32,
    window_scale:             f32,
    window_pixel_width:       i32,
    window_pixel_height:      i32,
    pipelines:                [Shader_Type]^sdl.GPUGraphicsPipeline,
    last_tick:                time.Tick,
    start_tick:               time.Tick,
    dt:                       f32,
    projection:               matrix[4, 4]f32,
    view_matrix:              matrix[4, 4]f32,
    pre_press:                #sparse[sdl.Scancode]bool,
    cur_press:                #sparse[sdl.Scancode]bool,
    cur_mouse_button_press:   bool,
    prev_mouse_button_press:  bool,
    mouse_pos:                Vec2,
    char_pressed:             u8,
    default_texture:          ^sdl.GPUTexture,
    default_font_texture:     ^sdl.GPUTexture,
    default_sampler:          ^sdl.GPUSampler,
    transfer_buf:             ^sdl.GPUTransferBuffer,
    index_buffer:             ^sdl.GPUBuffer,
    vertex_buffer:            ^sdl.GPUBuffer,
    clear_color:              Color,
    target_fps:               u32,
}

Camera :: struct {
    offset:    Vec2,
    zoom:      f32,
    rotation:  f32
}

Draw_Command :: struct {
    texture:        ^sdl.GPUTexture,
    pipeline_type:  Shader_Type,
    first_index:    u32,
    index_count:    u32,
    view_matrix:    matrix[4, 4]f32,
}

Texture :: struct {
    w, h: u32,
    texture:       ^sdl.GPUTexture,
}

Vertex :: struct {
	pos:   Vec3,
	uv:    Vec2,
	color: [4]u8,
}

Rect :: struct {
	x, y, w, h: f32,
}

init_window :: proc(width: u32, height: u32, title: cstring, mode: sdl.WindowFlags) {
	ensure(sdl.Init({.VIDEO}), string(sdl.GetError()))

	g = new(State)
	g.window = sdl.CreateWindow(title, i32(width), i32(height), mode + {.HIGH_PIXEL_DENSITY})
    g.display = sdl.GetPrimaryDisplay()
	g.last_tick = time.tick_now()
	g.start_tick = time.tick_now()
    set_camera(Camera { zoom = 1 }) 

	g.clear_color = WHITE
	g.device = sdl.CreateGPUDevice({.SPIRV}, ODIN_DEBUG, nil)
	if g.device == nil do log.error(sdl.GetError())
	ensure(sdl.ClaimWindowForGPUDevice(g.device, g.window), string(sdl.GetError()))

	g.transfer_buf = sdl.CreateGPUTransferBuffer(
		g.device,
		{usage = .UPLOAD, size = MAX_TRANSFER_BUFFER_SIZE_BYTES},
	)
	g.default_texture = create_default_texture()
	g.default_font_texture = create_default_font_texture()
	g.default_sampler = sdl.CreateGPUSampler(
		g.device,
		{min_filter = .NEAREST, mag_filter = .NEAREST, mipmap_mode = .NEAREST},
	)
	g.index_buffer = create_default_indices()
	g.vertex_buffer = sdl.CreateGPUBuffer(
		g.device,
		{props = 0, size = u32(MAX_VERTICES_BYTES), usage = {.VERTEX}},
	)

	for type in Shader_Type {g.pipelines[type] = setup_pipeline(type)}

	g.projection = sex_ortho(0, f32(width), 0, f32(height))

    // set vsync as default can be adjusted while running
	ensure(
		sdl.SetGPUSwapchainParameters(g.device, g.window, sdl.GPUSwapchainComposition.SDR, .VSYNC),
		string(sdl.GetError()),
	)
}

close_window :: proc() {
	for pipeline in g.pipelines {
		sdl.ReleaseGPUGraphicsPipeline(g.device, pipeline)
	}
	sdl.DestroyGPUDevice(g.device)
	sdl.DestroyWindow(g.window)
	sdl.Quit()
}

get_window_width :: proc() -> i32 {
    return g.window_width
}

get_window_height :: proc() -> i32 {
    return g.window_height
}

get_window_scale :: proc() -> f32 {
    return g.window_scale
}

update :: proc() -> bool {
	g.pre_press = g.cur_press
    g.char_pressed = 0
	g.prev_mouse_button_press = g.cur_mouse_button_press
	g.dt = f32(time.duration_seconds(time.tick_lap_time(&g.last_tick)))
    set_camera(Camera { zoom = 1 })

	ev: sdl.Event
	for sdl.PollEvent(&ev) {
		#partial switch ev.type {
		case .QUIT:
			return false
		case .KEY_DOWN:
			if ev.key.scancode == .ESCAPE do return false
			g.cur_press[ev.key.scancode] = true
		case .KEY_UP:
			g.cur_press[ev.key.scancode] = false
		case .TEXT_INPUT:
            g.char_pressed = ([^]u8)(ev.text.text)[0]
		case .MOUSE_MOTION:
            g.mouse_pos = {ev.motion.x, ev.motion.y}
		case .MOUSE_BUTTON_DOWN:
            g.cur_mouse_button_press = true
		case .MOUSE_BUTTON_UP:
            g.cur_mouse_button_press = false
        case .WINDOW_RESIZED, .WINDOW_SHOWN, .WINDOW_DISPLAY_SCALE_CHANGED:
            g.window_scale = sdl.GetWindowDisplayScale(g.window)
            sdl.GetWindowSizeInPixels(g.window, &g.window_width, &g.window_height)
		}
	}

	return true
}

present :: proc() {
	mem_ptr := sdl.MapGPUTransferBuffer(g.device, g.transfer_buf, true)
	mem.copy(mem_ptr, raw_data(&batch_vertices), len(batch_vertices) * size_of(Vertex))
	sdl.UnmapGPUTransferBuffer(g.device, g.transfer_buf)

	cmd_buf := sdl.AcquireGPUCommandBuffer(g.device)
	copy_pass := sdl.BeginGPUCopyPass(cmd_buf)

	sdl.UploadToGPUBuffer(
		copy_pass,
		{transfer_buffer = g.transfer_buf},
		{buffer = g.vertex_buffer, size = u32(len(batch_vertices) * size_of(Vertex))},
		false,
	)
	sdl.EndGPUCopyPass(copy_pass)

	swapchain_tex: ^sdl.GPUTexture
	ensure(
		sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, g.window, &swapchain_tex, nil , nil),
		string(sdl.GetError()),
	)
    g.projection = sex_ortho(0, f32(g.window_width), 0, f32(g.window_height))

	if swapchain_tex == nil { 	// the window is minimaized (wayland not rly)
		ensure(sdl.SubmitGPUCommandBuffer(cmd_buf), string(sdl.GetError()))
        clear(&draw_commands)
        clear(&batch_vertices)
        free_all(context.temp_allocator)
	}

	color_target := sdl.GPUColorTargetInfo {
		texture     = swapchain_tex,
		load_op     = .CLEAR,
		clear_color = (sdl.FColor)(linalg.array_cast(g.clear_color, f32) / 255),
		store_op    = .STORE,
	}

	render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)
	sdl.BindGPUVertexBuffers(render_pass, 0, &(sdl.GPUBufferBinding{buffer = g.vertex_buffer}), 1)
	sdl.BindGPUIndexBuffer(render_pass, {buffer = g.index_buffer}, ._16BIT)
	sdl.PushGPUVertexUniformData(cmd_buf, 0, &g.projection, size_of(g.projection))

	for &dc in draw_commands {
		sdl.BindGPUGraphicsPipeline(render_pass, g.pipelines[dc.pipeline_type])
        sdl.PushGPUVertexUniformData(cmd_buf, 1, &dc.view_matrix, size_of(dc.view_matrix))
		sdl.BindGPUFragmentSamplers(
			render_pass,
			0,
			&(sdl.GPUTextureSamplerBinding {
					sampler = g.default_sampler,
					texture = dc.texture,
				}),
			1,
		)

		sdl.DrawGPUIndexedPrimitives(
			render_pass,
			dc.index_count,
			1,
			dc.first_index,
			0,
			0,
		)
	}

	sdl.EndGPURenderPass(render_pass)
	ensure(sdl.SubmitGPUCommandBuffer(cmd_buf), string(sdl.GetError()))
    clear(&draw_commands)
    clear(&batch_vertices)
    free_all(context.temp_allocator)

    if g.target_fps > 0 {
        target_sec := 1/f64(g.target_fps)
        dt := time.duration_seconds(time.tick_since(g.last_tick))
        time.sleep((time.Duration)((target_sec - dt) * f64(time.Second)))
    }
}

get_delta_time :: proc() -> f32 {
	return g.dt
}

get_ticks :: proc() -> f64 {
	return time.duration_seconds(time.tick_since(g.start_tick))
}

get_fps :: proc() -> string {
    return fmt.tprintf("%.0f", 1/g.dt)
}

get_text_width :: proc(font_scale, text_len: int) -> f32 {
    return f32(font_scale) * DEFAULT_FONT_WIDTH * f32(text_len)
}

get_text_size :: proc(font_scale, text_len: int) -> Vec2 {
    return {
        f32(font_scale) * DEFAULT_FONT_WIDTH * f32(text_len),
        f32(font_scale) * DEFAULT_FONT_HEIGHT
    }
}

is_key_down :: proc(code: Scancode) -> bool {
	return g.cur_press[code]
}

is_key_pressed :: proc(code: Scancode) -> bool {
	return g.cur_press[code] && !g.pre_press[code]
}

start_text_input :: proc() -> bool {
    return sdl.StartTextInput(g.window)
}

stop_text_input :: proc() -> bool {
    return sdl.StopTextInput(g.window)
}

get_char_pressed :: proc() -> u8 {
    return g.char_pressed
}

get_mouse_position :: proc() -> Vec2 {
    scale := get_window_scale()
    return {(g.mouse_pos.x * scale) - g.view_matrix[3][0], (g.mouse_pos.y * scale) - g.view_matrix[3][1]}
}

is_mouse_button_down :: proc() -> bool {
    return g.cur_mouse_button_press
}

is_mouse_button_pressed :: proc() -> bool {
    return g.cur_mouse_button_press && !g.prev_mouse_button_press
}

clear_background :: proc(color: Color) {
	g.clear_color = color
}

set_fps :: proc(target_fps: u32) {
	g.target_fps = target_fps
}

hide_cursor :: proc() -> bool {
    return sdl.HideCursor()
}

set_camera :: proc(camera: Camera) {
    g.view_matrix =
		linalg.matrix4_translate_f32({camera.offset.x, camera.offset.y, 0}) *
		linalg.matrix4_rotate_f32(camera.rotation, {0, 0, 1}) *
		linalg.matrix4_scale_f32({camera.zoom, camera.zoom, 1})
}

draw_texture :: proc(tex: Texture, src: Rect, pos: Vec2, tint: Color) {
    model_matrix :=
        linalg.matrix4_translate_f32({pos.x, pos.y, 0}) *
        linalg.matrix4_scale_f32({src.w, src.h, 1})

    /*
        what im getting in w and h im getting img width / frames 
        that means that im getting single size of the image

        i have the single size of the image ok
        so if i say single image size/whole image size i should get the thing i want prop
    */

    vertices := TEMPLATE_VERTEX
    for &vertex in vertices {
        vertex.color = tint
        vertex.pos = (model_matrix * [4]f32{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}).xyz
        vertex.uv *= {src.w/f32(tex.w), src.h/f32(tex.h)}
        vertex.uv += {src.x, src.y}
        append(&batch_vertices, vertex)
    }

    add_draw_command(6, tex.texture, .Textured)
}

// One segment is one quad
draw_circle :: proc(position: Vec2, r: f32, color: Color, segments := 16) {
	model_matrix :=
		linalg.matrix4_translate_f32({position.x, position.y, 0}) *
		linalg.matrix4_scale_f32({r, r, 1})

	rad: f32 = 0
	for i in 0 ..< segments {
		f_vertex := Vertex {
			pos   = {0, 0, 1},
			uv    = {0, 1},
			color = color,
		}
		f_vertex.pos = (model_matrix * [4]f32{f_vertex.pos.x, f_vertex.pos.y, f_vertex.pos.z, 1}).xyz
		append(&batch_vertices, f_vertex)
		rad -= linalg.PI / f32(segments)
		for i in 0 ..< 3 {
			rad += linalg.PI / f32(segments)
			vertex := Vertex {
				pos   = {linalg.cos(rad), linalg.sin(rad), 1},
				uv    = {0, 1},
				color = color,
			}
			vertex.pos = (model_matrix * [4]f32{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}).xyz
			append(&batch_vertices, vertex)
		}
	}

	add_draw_command(u32(6 * segments), g.default_texture, .Textured)
}

draw_rectangle_outline :: proc(rect: Rect, color: Color) {
    draw_rectangle({rect.x, rect.y, 1, rect.h}, color)              // left side
    draw_rectangle({rect.x + rect.w - 1, rect.y, 1, rect.h}, color) // right side
    draw_rectangle({rect.x, rect.y, rect.w, 1}, color)              // top side
    draw_rectangle({rect.x, rect.y + rect.h - 1, rect.w, 1}, color) // bottom side
}

draw_rectangle :: proc(rect: Rect, color: Color, rotation: f32 = 0) {
    model_matrix :=
        linalg.matrix4_translate_f32({rect.x, rect.y, 0}) *
        linalg.matrix4_rotate_f32(rotation, {0, 0, 1}) *
        linalg.matrix4_scale_f32({rect.w, rect.h, 1})

	vertices := TEMPLATE_VERTEX
	for &vertex in vertices {
		vertex.color = color
		vertex.pos = (model_matrix * [4]f32{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}).xyz
		append(&batch_vertices, vertex)
	}

	add_draw_command(6, g.default_texture, .Textured)
}

draw_fps :: proc(pos: Vec2) {
    draw_text(get_fps(), pos, 2)
}

draw_text :: proc(text: string, pos: Vec2, font_scale: u32, color := WHITE) {
    font_height := f32(DEFAULT_FONT_HEIGHT * font_scale)
    font_width  := f32(DEFAULT_FONT_WIDTH * font_scale)
    bytes := transmute([]u8)text
    for b, i in bytes {
        model_matrix :=
            linalg.matrix4_translate_f32({pos.x + font_width * f32(i), pos.y, 0}) *
            linalg.matrix4_scale_f32({font_width, font_height, 1})
        vertices := TEMPLATE_VERTEX
        glyph_index := b-32
        glyph_index_x := f32(glyph_index%DEFAULT_FONT_COLUMNS)
        glyph_index_y := f32(glyph_index/DEFAULT_FONT_COLUMNS)
        uv_scale := Vec2{1./DEFAULT_FONT_COLUMNS, 1./DEFAULT_FONT_ROWS}
        uv_offset := Vec2{glyph_index_x, glyph_index_y} * uv_scale
        for &vertex in vertices {
            vertex.color = color
            vertex.pos = (model_matrix * [4]f32{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}).xyz
            vertex.uv *= uv_scale
            vertex.uv += uv_offset
            append(&batch_vertices, vertex)
        }
        add_draw_command(6, g.default_font_texture, .Textured)
    }
}

add_draw_command :: proc(index_count: u32, texture: ^sdl.GPUTexture, shader_type: Shader_Type) {
	command_count := len(draw_commands)
	if command_count == 0 {
		append(
			&draw_commands,
			(Draw_Command) {
				texture = texture,
				pipeline_type = shader_type,
				first_index = 0,
				index_count = index_count,
                view_matrix = g.view_matrix
			},
		)
		return
	}

	prev_command := &draw_commands[command_count - 1]
    if prev_command.pipeline_type == shader_type &&
            prev_command.texture == texture &&
            prev_command.view_matrix == g.view_matrix {
        prev_command.index_count += index_count
	} else {
        append(
            &draw_commands,
            (Draw_Command) {
                texture = texture,
                pipeline_type = shader_type,
                first_index = prev_command.index_count + prev_command.first_index,
                index_count = index_count,
                view_matrix = g.view_matrix
            },
        )
	}
}

load_texture :: proc(path: string) -> Texture {
	img, err := image.load_from_file(path, {.alpha_add_if_missing})
	if (err != nil) {
		log.error(err)
		return {}
	}

	texture := sdl.CreateGPUTexture(
		g.device,
		{
			type = .D2,
			width = u32(img.width),
			height = u32(img.height),
			usage = {.SAMPLER},
			format = .R8G8B8A8_UNORM,
			layer_count_or_depth = 1,
			num_levels = 1,
		},
	)
	texture_byte_size := img.width * img.height * 4

	transfer_buf := sdl.CreateGPUTransferBuffer(
		g.device,
		{usage = .UPLOAD, size = u32(img.width * img.height * 4)},
	)

	transfer_mem := sdl.MapGPUTransferBuffer(g.device, transfer_buf, false)
	mem.copy(transfer_mem, raw_data(img.pixels.buf), int(texture_byte_size))
	sdl.UnmapGPUTransferBuffer(g.device, transfer_buf)

	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(g.device)
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

	sdl.UploadToGPUTexture(
		copy_pass,
		{
			transfer_buffer = transfer_buf,
			pixels_per_row = u32(img.width),
			rows_per_layer = u32(img.height),
		},
		{texture = texture, w = u32(img.width), h = u32(img.height), d = 1, mip_level = 0},
		false,
	)

	sdl.EndGPUCopyPass(copy_pass)
	ensure(sdl.SubmitGPUCommandBuffer(copy_cmd_buf), string(sdl.GetError()))
	sdl.ReleaseGPUTransferBuffer(g.device, transfer_buf)

	return {w = u32(img.width), h = u32(img.height), texture = texture}
}

AABB :: struct {
        t,b,l,r: f32
    }
// axis aligned bounding box
aabb :: proc(r1: Rect, r2: Rect) -> (bool, Vec2) {
    r1_s := AABB {
        t = r1.y,
        b = r1.y + r1.h,
        l = r1.x,
        r = r1.x + r1.w 
    }
    r2_s := AABB {
        t = r2.y,
        b = r2.y + r2.h,
        l = r2.x,
        r = r2.x + r2.w 
    }

    collided := r1_s.r >= r2_s.l && r2_s.r >= r1_s.l &&
                r1_s.b >= r2_s.t && r2_s.b >= r1_s.t 

    overflow_x: f32 = 0
    overflow_y := r1_s.b - r2_s.t

    return collided, {overflow_x, overflow_y}
}
