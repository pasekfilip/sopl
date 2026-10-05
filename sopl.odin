package sopl

import "base:runtime"
import "core:fmt"
import "core:image"
import _ "core:image/png"
import "core:log"
import "core:math/linalg"
import "core:mem"
import "core:time"
import sdl "vendor:sdl3"

State :: struct {
	device:          ^sdl.GPUDevice,
	window:          ^sdl.Window,
	pipelines:       [Shader_Type]^sdl.GPUGraphicsPipeline,
	last_tick:       time.Tick,
	projection:      matrix[4, 4]f32,
	previous_press:  #sparse[sdl.Scancode]bool,
	current_press:   #sparse[sdl.Scancode]bool,
	default_texture: ^sdl.GPUTexture,
	default_sampler: ^sdl.GPUSampler,
	transfer_buf:    ^sdl.GPUTransferBuffer,
	index_buffer:    ^sdl.GPUBuffer,
	vertex_buffer:   ^sdl.GPUBuffer,
	clear_color:     Color,

	// draw_batch: [dynamic]
}

Physical_KeyCode :: sdl.Scancode
PresentMode :: sdl.GPUPresentMode

Texture :: struct {
	width, height: u32,
	texture:       ^sdl.GPUTexture,
}

//odinfmt: disable
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
//odinfmt: enable

Rect :: struct {
	x, y, width, height: f32,
}

Draw_Command :: struct {
	texture:       ^sdl.GPUTexture,
	pipeline_type: Shader_Type,
	first_index:   u32,
	index_count:   u32,
}

Vertex :: struct {
	pos:   [3]f32,
	uv:    [2]f32,
	color: [4]u8,
}

Shader_Type :: enum {
	Wireframe,
	Textured,
}

Mesh :: struct {
	vertex_buffer: ^sdl.GPUBuffer,
	index_buffer:  ^sdl.GPUBuffer,
	num_indices:   u32,
}

quad_vert := #load("shaders/spv_quad.vert")
quad_frag := #load("shaders/spv_quad.frag")

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
MAX_TRANSFER_BUFFER_SIZE :: MAX_VERTICES * size_of(Vertex)
MAX_INDICES :: BATCH_QUAD_CAPACITY * 6

init_window :: proc(title: cstring, width: u32, height: u32, mode := PresentMode.VSYNC) {
	ensure(sdl.Init({.VIDEO}), string(sdl.GetError()))

	g = new(State)
	g.window = sdl.CreateWindow(title, i32(width), i32(height), {})

	g.clear_color = WHITE
	g.device = sdl.CreateGPUDevice({.SPIRV}, ODIN_DEBUG, nil)
	ensure(sdl.ClaimWindowForGPUDevice(g.device, g.window), string(sdl.GetError()))

	g.transfer_buf = sdl.CreateGPUTransferBuffer(
		g.device,
		{usage = .UPLOAD, size = MAX_TRANSFER_BUFFER_SIZE},
	)
	g.default_texture = create_default_texture()
	g.default_sampler = sdl.CreateGPUSampler(
		g.device,
		{min_filter = .NEAREST, mag_filter = .NEAREST, mipmap_mode = .NEAREST},
	)
	g.index_buffer = create_default_indices()
	g.vertex_buffer = sdl.CreateGPUBuffer(
		g.device,
		{props = 0, size = u32(MAX_VERTICES), usage = {.VERTEX}},
	)

	for type in Shader_Type {g.pipelines[type] = setup_pipeline(type)}

	g.projection = linalg.matrix_ortho3d_f32(0, f32(width), f32(height), 0, 0, 1, false)

	ensure(
		sdl.SetGPUSwapchainParameters(g.device, g.window, sdl.GPUSwapchainComposition.SDR, mode),
		string(sdl.GetError()),
	)
}

create_default_texture :: proc() -> ^sdl.GPUTexture {
	white_pixel := []byte{255, 255, 255, 255}
	width, height: u32 = 1, 1
	texture_byte_size := u32(len(white_pixel) * size_of(byte))
	texture := sdl.CreateGPUTexture(
		g.device,
		{
			type = .D2,
			width = width,
			height = height,
			usage = {.SAMPLER},
			format = .R8G8B8A8_UNORM,
			layer_count_or_depth = 1,
			num_levels = 1,
		},
	)

	transfer_buf := sdl.CreateGPUTransferBuffer(
		g.device,
		{usage = .UPLOAD, size = texture_byte_size},
	)

	transfer_mem := sdl.MapGPUTransferBuffer(g.device, transfer_buf, false)
	mem.copy(transfer_mem, raw_data(white_pixel), int(texture_byte_size))
	sdl.UnmapGPUTransferBuffer(g.device, transfer_buf)

	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(g.device)
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

	sdl.UploadToGPUTexture(
		copy_pass,
		{transfer_buffer = transfer_buf, pixels_per_row = width, rows_per_layer = height},
		{texture = texture, w = width, h = height, d = 1, mip_level = 0},
		false,
	)

	sdl.EndGPUCopyPass(copy_pass)
	ensure(sdl.SubmitGPUCommandBuffer(copy_cmd_buf), string(sdl.GetError()))
	sdl.ReleaseGPUTransferBuffer(g.device, transfer_buf)

	return texture
}

create_default_indices :: proc() -> ^sdl.GPUBuffer {
	indices: [MAX_INDICES]u16
	quad_pattern := [6]u16{0, 1, 2, 0, 2, 3}
	for i := 0; i < len(indices); i += 1 {
		index := u16(i / 6) * 4 + quad_pattern[i % 6]
		indices[i] = index
	}
	indices_byte_size := len(indices) * size_of(indices[0])
	index_buffer := sdl.CreateGPUBuffer(
		g.device,
		{props = 0, size = u32(indices_byte_size), usage = {.INDEX}},
	)
	transfer_buf := sdl.CreateGPUTransferBuffer(
		g.device,
		{usage = .UPLOAD, size = u32(indices_byte_size)},
	)

	transfer_mem := sdl.MapGPUTransferBuffer(g.device, transfer_buf, false)
	mem.copy(transfer_mem, raw_data(&indices), indices_byte_size)
	sdl.UnmapGPUTransferBuffer(g.device, transfer_buf)

	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(g.device)
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

	sdl.UploadToGPUBuffer(
		copy_pass,
		{transfer_buffer = transfer_buf},
		{buffer = index_buffer, size = u32(indices_byte_size)},
		false,
	)
	sdl.EndGPUCopyPass(copy_pass)
	ensure(sdl.SubmitGPUCommandBuffer(copy_cmd_buf), string(sdl.GetError()))

	sdl.ReleaseGPUTransferBuffer(g.device, transfer_buf)
	return index_buffer
}

close_window :: proc() {
	for pipeline in g.pipelines {
		sdl.ReleaseGPUGraphicsPipeline(g.device, pipeline)
	}
	sdl.DestroyGPUDevice(g.device)
	sdl.DestroyWindow(g.window)
	sdl.Quit()
}

window_should_close :: proc() -> bool {
	g.previous_press = g.current_press
	g.last_tick = time.tick_now()

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

is_key_down :: proc(code: Physical_KeyCode) -> bool {
	return g.current_press[code]
}

is_key_pressed :: proc(code: Physical_KeyCode) -> bool {
	return g.current_press[code] && !g.previous_press[code]
}

get_delta_time :: proc() -> f32 {
	return f32(time.tick_since(g.last_tick) / time.Second)
}

create_quad_mesh :: proc() -> Mesh {
	vertices: []Vertex = {
		{pos = {-0.5, -0.5, 1}, uv = {0, 1}, color = {0, 0, 0, 255}},
		{pos = {0.5, -0.5, 1}, uv = {1, 1}, color = {0, 0, 0, 255}},
		{pos = {0.5, 0.5, 1}, uv = {1, 0}, color = {0, 0, 0, 255}},
		{pos = {-0.5, 0.5, 1}, uv = {0, 0}, color = {0, 0, 0, 255}},
	}

	indices: []u32 = {0, 1, 2, 0, 2, 3}
	return create_mesh(vertices, indices)
}

create_mesh :: proc(vertices: []Vertex, indices: []u32) -> Mesh {
	vertices_byte_size := len(vertices) * size_of(Vertex)
	indices_byte_size := len(indices) * size_of(indices[0])
	transfer_buffer_size := u32(vertices_byte_size) + u32(indices_byte_size)

	vertex_buffer := sdl.CreateGPUBuffer(
		g.device,
		{props = 0, size = u32(vertices_byte_size), usage = {.VERTEX}},
	)

	index_buffer := sdl.CreateGPUBuffer(
		g.device,
		{props = 0, size = u32(indices_byte_size), usage = {.INDEX}},
	)

	transfer_buf := sdl.CreateGPUTransferBuffer(
		g.device,
		{usage = .UPLOAD, size = transfer_buffer_size},
	)

	transfer_mem := sdl.MapGPUTransferBuffer(g.device, transfer_buf, false)
	mem.copy(transfer_mem, raw_data(vertices), vertices_byte_size)

	index_dest := mem.ptr_offset((^Vertex)(transfer_mem), len(vertices))
	mem.copy(index_dest, raw_data(indices), indices_byte_size)

	sdl.UnmapGPUTransferBuffer(g.device, transfer_buf)

	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(g.device)
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

	sdl.UploadToGPUBuffer(
		copy_pass,
		{transfer_buffer = transfer_buf},
		{buffer = vertex_buffer, size = u32(vertices_byte_size)},
		false,
	)
	sdl.UploadToGPUBuffer(
		copy_pass,
		{transfer_buffer = transfer_buf, offset = u32(vertices_byte_size)},
		{buffer = index_buffer, size = u32(indices_byte_size)},
		false,
	)

	sdl.EndGPUCopyPass(copy_pass)
	ensure(sdl.SubmitGPUCommandBuffer(copy_cmd_buf), string(sdl.GetError()))

	sdl.ReleaseGPUTransferBuffer(g.device, transfer_buf)

	return Mesh {
		vertex_buffer = vertex_buffer,
		index_buffer = index_buffer,
		num_indices = u32(len(indices)),
	}
}

destroy_mesh :: proc(mesh: Mesh) {
	sdl.ReleaseGPUBuffer(g.device, mesh.vertex_buffer)
	sdl.ReleaseGPUBuffer(g.device, mesh.index_buffer)
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
		sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, g.window, &swapchain_tex, nil, nil),
		string(sdl.GetError()),
	)
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

	for draw_command in draw_commands {
		sdl.BindGPUGraphicsPipeline(render_pass, g.pipelines[draw_command.pipeline_type])
		sdl.BindGPUFragmentSamplers(
			render_pass,
			0,
			&(sdl.GPUTextureSamplerBinding {
					sampler = g.default_sampler,
					texture = draw_command.texture,
				}),
			1,
		)

		sdl.DrawGPUIndexedPrimitives(
			render_pass,
			draw_command.index_count,
			1,
			draw_command.first_index,
			0,
			0,
		)
	}


	sdl.EndGPURenderPass(render_pass)
	ensure(sdl.SubmitGPUCommandBuffer(cmd_buf), string(sdl.GetError()))
	draw_commands = {}
	batch_vertices = {}
}

clear :: proc(color: Color) {
	g.clear_color = color
}

// draw_texture :: proc(tex: ^Texture, source: Rect, destination: Rect, rotation: f32) {
// 	sdl.BindGPUGraphicsPipeline(render_pass, g.pipelines[.Textured])
// 	sdl.BindGPUVertexBuffers(
// 		render_pass,
// 		0,
// 		&(sdl.GPUBufferBinding{buffer = g.mesh.vertex_buffer}),
// 		1,
// 	)
// 	sdl.BindGPUIndexBuffer(render_pass, {buffer = g.mesh.index_buffer}, ._32BIT)
// 	model_matrix :=
// 		linalg.matrix4_translate_f32({destination.x, destination.y, 0}) *
// 		linalg.matrix4_rotate_f32(rotation, {0, 0, 1}) *
// 		linalg.matrix4_scale_f32({destination.width, destination.height, 1})
// 	sdl.PushGPUVertexUniformData(g.cmd_buf, 1, &model_matrix, size_of(matrix[4, 4]f32))
//
// 	Sprite_Offset :: struct {
// 		scale:  [2]f32,
// 		offset: [2]f32,
// 	}
// 	sprite_offset := &Sprite_Offset {
// 		scale = {source.width / f32(tex.width), source.height / f32(tex.height)},
// 		offset = {(source.x - min(source.width, 0)) / f32(tex.width), source.y / f32(tex.height)},
// 	}
// 	sdl.PushGPUVertexUniformData(g.cmd_buf, 2, sprite_offset, size_of(Sprite_Offset))
// 	sdl.BindGPUFragmentSamplers(
// 		render_pass,
// 		0,
// 		&(sdl.GPUTextureSamplerBinding{sampler = g.default_sampler, texture = tex.texture}),
// 		1,
// 	)
//
// 	sdl.DrawGPUIndexedPrimitives(render_pass, g.mesh.num_indices, 1, 0, 0, 0)
// }


draw_rectangle :: proc(destination: Rect, color: Color, rotation: f32 = 0) {
	model_matrix :=
		linalg.matrix4_translate_f32({destination.x, destination.y, 0}) *
		linalg.matrix4_rotate_f32(rotation, {0, 0, 1}) *
		linalg.matrix4_scale_f32({destination.width, destination.height, 1})

	vertices := TEMPLATE_VERTEX
	for &vertex, index in vertices {
		vertex.color = color
		vertex.pos = (model_matrix * [4]f32{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}).xyz
		append(&batch_vertices, vertex)
	}

	command_count := len(draw_commands)
	if command_count == 0 {
		append(
			&draw_commands,
			(Draw_Command) {
				texture = g.default_texture,
				pipeline_type = .Textured,
				first_index = 0,
				index_count = 6,
			},
		)
		return
	}

	previous_command := &draw_commands[command_count - 1]
	if previous_command.pipeline_type == .Textured &&
	   previous_command.texture == g.default_texture {
		previous_command.index_count += 6
	} else {
		append(
			&draw_commands,
			(Draw_Command) {
				texture = g.default_texture,
				pipeline_type = .Textured,
				first_index = previous_command.index_count,
				index_count = 6,
			},
		)
	}
}

// draw_rectangle_lines :: proc(destination: Rect, color: Color, rotation: f32) {
// 	sdl.BindGPUGraphicsPipeline(render_pass, g.pipelines[.Wireframe])
// 	sdl.BindGPUVertexBuffers(
// 		render_pass,
// 		0,
// 		&(sdl.GPUBufferBinding{buffer = g.mesh.vertex_buffer}),
// 		1,
// 	)
// 	sdl.BindGPUIndexBuffer(render_pass, {buffer = g.mesh.index_buffer}, ._32BIT)
// 	model_matrix :=
// 		linalg.matrix4_translate_f32({destination.x, destination.y, 0}) *
// 		linalg.matrix4_rotate_f32(rotation, {0, 0, 1}) *
// 		linalg.matrix4_scale_f32({destination.width, destination.height, 1})
// 	sdl.PushGPUVertexUniformData(g.cmd_buf, 1, &model_matrix, size_of(matrix[4, 4]f32))
// 	color := color
// 	sdl.PushGPUFragmentUniformData(g.cmd_buf, 0, &color, size_of([4]f32))
//
// 	sdl.DrawGPUIndexedPrimitives(render_pass, g.mesh.num_indices, 1, 0, 0, 0)
// }

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

setup_pipeline :: proc(shader_type: Shader_Type) -> ^sdl.GPUGraphicsPipeline {
	vert_shader: ^sdl.GPUShader
	frag_shader: ^sdl.GPUShader

	vertex_attributes: []sdl.GPUVertexAttribute = {
		{location = 0, buffer_slot = 0, format = .FLOAT3, offset = 0},
		{location = 1, buffer_slot = 0, format = .FLOAT2, offset = u32(offset_of(Vertex, uv))},
		{
			location = 2,
			buffer_slot = 0,
			format = .UBYTE4_NORM,
			offset = u32(offset_of(Vertex, color)),
		},
	}

	pipeline: ^sdl.GPUGraphicsPipeline

	switch shader_type {
	case .Wireframe:
		vert_shader = load_shader(
			g.device,
			quad_vert,
			.VERTEX,
			num_uniform_buffers = 2,
			num_samplers = 0,
		)
		frag_shader = load_shader(
			g.device,
			quad_frag,
			.FRAGMENT,
			num_uniform_buffers = 1,
			num_samplers = 1,
		)

		pipeline = create_pipeline(vert_shader, frag_shader, vertex_attributes, .LINE)
		break

	case .Textured:
		vert_shader = load_shader(
			g.device,
			quad_vert,
			.VERTEX,
			num_uniform_buffers = 2,
			num_samplers = 0,
		)
		frag_shader = load_shader(
			g.device,
			quad_frag,
			.FRAGMENT,
			num_uniform_buffers = 1,
			num_samplers = 1,
		)

		pipeline = create_pipeline(vert_shader, frag_shader, vertex_attributes, .FILL)
		break
	}

	sdl.ReleaseGPUShader(g.device, vert_shader)
	sdl.ReleaseGPUShader(g.device, frag_shader)

	return pipeline
}

create_pipeline :: proc(
	vert_shader: ^sdl.GPUShader,
	frag_shader: ^sdl.GPUShader,
	vertex_attributes: []sdl.GPUVertexAttribute,
	fill_mode: sdl.GPUFillMode,
) -> ^sdl.GPUGraphicsPipeline {
	return sdl.CreateGPUGraphicsPipeline(
		g.device,
		{
			vertex_shader = vert_shader,
			fragment_shader = frag_shader,
			primitive_type = .TRIANGLELIST,
			target_info = {
				num_color_targets = 1,
				color_target_descriptions = &(sdl.GPUColorTargetDescription) {
					format = sdl.GetGPUSwapchainTextureFormat(g.device, g.window),
					blend_state = {
						enable_blend = true,
						src_color_blendfactor = .SRC_ALPHA,
						dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
						color_blend_op = .ADD,
						src_alpha_blendfactor = .ONE,
						dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
						alpha_blend_op = .ADD,
					},
				},
			},
			rasterizer_state = {fill_mode = fill_mode},
			vertex_input_state = {
				vertex_buffer_descriptions = raw_data(
					[]sdl.GPUVertexBufferDescription {
						{
							slot = 0,
							pitch = size_of(Vertex),
							input_rate = .VERTEX,
							instance_step_rate = 0,
						},
					},
				),
				num_vertex_buffers = 1,
				num_vertex_attributes = u32(len(vertex_attributes)),
				vertex_attributes = raw_data(vertex_attributes),
			},
		},
	)
}

load_shader :: proc(
	device: ^sdl.GPUDevice,
	code: []u8,
	stage: sdl.GPUShaderStage,
	num_uniform_buffers: u32,
	num_samplers: u32,
) -> ^sdl.GPUShader {
	return sdl.CreateGPUShader(
		device,
		{
			code_size = len(code),
			code = raw_data(code),
			entrypoint = "main",
			format = {.SPIRV},
			stage = stage,
			num_uniform_buffers = num_uniform_buffers,
			num_samplers = num_samplers,
		},
	)
}
