package sopl

import "core:fmt"
import "core:image"
import _ "core:image/png"
import "core:log"
import "core:math/linalg"
import "core:time"
import sdl "vendor:sdl3"
import "core:mem"

State :: struct {
	device:          ^sdl.GPUDevice,
    display:         sdl.DisplayID,
	window:          ^sdl.Window,
	pipelines:       [Shader_Type]^sdl.GPUGraphicsPipeline,
	last_tick:       time.Tick,
	dt:              f32,
	projection:      matrix[4, 4]f32,
	previous_press:  #sparse[sdl.Scancode]bool,
	current_press:   #sparse[sdl.Scancode]bool,
	default_texture: ^sdl.GPUTexture,
	default_sampler: ^sdl.GPUSampler,
	transfer_buf:    ^sdl.GPUTransferBuffer,
	index_buffer:    ^sdl.GPUBuffer,
	vertex_buffer:   ^sdl.GPUBuffer,
	clear_color:     Color,
	target_fps:      u32,
    view_matrix:     matrix[4, 4]f32,
}

Camera :: struct {
    offset: Vec2,
    zoom: f32,
    rotation: f32
}

Draw_Command :: struct {
	texture:       ^sdl.GPUTexture,
	pipeline_type: Shader_Type,
	first_index:   u32,
	index_count:   u32,
    view_matrix: matrix[4, 4]f32,
}

Physical_KeyCode :: sdl.Scancode
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

Vertex :: struct {
	pos:   Vec3,
	uv:    Vec2,
	color: [4]u8,
}

Rect :: struct {
	x, y, w, h: f32,
}

Vec3 :: [3]f32
Vec2 :: [2]f32

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

g: ^State
batch_vertices: [dynamic; MAX_VERTICES]Vertex
draw_commands: [dynamic; BATCH_QUAD_CAPACITY]Draw_Command

init_window :: proc(title: cstring, width: u32, height: u32, mode := PresentMode.VSYNC) {
	context.logger = log.create_console_logger()
	ensure(sdl.Init({.VIDEO}), string(sdl.GetError()))

	g = new(State)
	g.window = sdl.CreateWindow(title, i32(width), i32(height), {.HIGH_PIXEL_DENSITY, .RESIZABLE})
    g.display = sdl.GetPrimaryDisplay()
	g.last_tick = time.tick_now()
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

	ensure(
		sdl.SetGPUSwapchainParameters(g.device, g.window, sdl.GPUSwapchainComposition.SDR, mode),
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

update :: proc() -> bool {
	g.previous_press = g.current_press
	g.dt = f32(time.duration_seconds(time.tick_lap_time(&g.last_tick)))

	ev: sdl.Event
	for sdl.PollEvent(&ev) {
		#partial switch ev.type {
		case .QUIT:
			return true
		case .KEY_DOWN:
			if ev.key.scancode == .ESCAPE do return true
			g.current_press[ev.key.scancode] = true
		case .KEY_UP:
			g.current_press[ev.key.scancode] = false
		}
	}

	return false
}

get_delta_time :: proc() -> f32 {
	return g.dt
}

is_key_down :: proc(code: Physical_KeyCode) -> bool {
	return g.current_press[code]
}

is_key_pressed :: proc(code: Physical_KeyCode) -> bool {
	return g.current_press[code] && !g.previous_press[code]
}

clear_background :: proc(color: Color) {
	g.clear_color = color
}

set_fps :: proc(target_fps: u32) {
	g.target_fps = target_fps
}

set_camera :: proc(camera: Camera) {
    g.view_matrix =
		linalg.matrix4_translate_f32({camera.offset.x, camera.offset.y, 0}) *
		linalg.matrix4_rotate_f32(camera.rotation, {0, 0, 1}) *
		linalg.matrix4_scale_f32({camera.zoom, camera.zoom, 1})
}

add_draw_command :: proc(index_count: u32, shader_type: Shader_Type) {
	command_count := len(draw_commands)
	if command_count == 0 {
		append(
			&draw_commands,
			(Draw_Command) {
				texture = g.default_texture,
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
	   prev_command.texture == g.default_texture &&
       prev_command.view_matrix == g.view_matrix {
		prev_command.index_count += index_count
	} else {
		append(
			&draw_commands,
			(Draw_Command) {
				texture = g.default_texture,
				pipeline_type = shader_type,
                first_index = prev_command.index_count + prev_command.first_index,
				index_count = index_count,
                view_matrix = g.view_matrix
			},
		)
	}
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

	add_draw_command(u32(6 * segments), .Textured)
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

	add_draw_command(6, .Textured)
}

draw_rectangle_outline :: proc(rect: Rect, color: Color) {
    draw_rectangle({rect.x, rect.y, 1, rect.h}, color)              // left side
    draw_rectangle({rect.x + rect.w - 1, rect.y, 1, rect.h}, color) // right side
    draw_rectangle({rect.x, rect.y, rect.w, 1}, color)              // top side
    draw_rectangle({rect.x, rect.y + rect.h - 1, rect.w, 1}, color) // bottom side
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
    swap_w, swap_h: u32
	ensure(
		sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, g.window, &swapchain_tex, &swap_w, &swap_h),
		string(sdl.GetError()),
	)
    // TODO: when i dont adjust to the swap chain texture i just get stretched space which might be what i want actually
    // its true that the aspect ratio might not match but bcs im changing the projection it moves everything in the world
    // so its not one to one
    // the moment i stretch the projection im moving also stuff in my world
    // g.projection = sex_ortho(0, f32(swap_w), 0, f32(swap_h))

	if swapchain_tex == nil { 	// the window is minimaized (wayland not rly)
		ensure(sdl.SubmitGPUCommandBuffer(cmd_buf), string(sdl.GetError()))
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

    if g.target_fps > 0 {
        target_sec := 1/f64(g.target_fps)
        dt := time.duration_seconds(time.tick_since(g.last_tick))
        time.sleep((time.Duration)((target_sec - dt) * f64(time.Second)))
    }
}

Texture :: struct {
	width, height: u32,
	texture:       ^sdl.GPUTexture,
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

	sampler := sdl.CreateGPUSampler(
		g.device,
		{min_filter = .NEAREST, mag_filter = .NEAREST, mipmap_mode = .NEAREST},
	)

	return {width = u32(img.width), height = u32(img.height), texture = texture}
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
