#+private
package sopl

import "core:image"
import _ "core:image/png"
import sdl "vendor:sdl3"
import "core:mem"

Shader_Type :: enum {
	Wireframe,
	Textured,
}

quad_vert := #load("shaders/spv_quad.vert")
quad_frag := #load("shaders/spv_quad.frag")

font_atlas := #load("text-atlas.png")

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

create_default_texture :: proc() -> ^sdl.GPUTexture {
	white_pixel := []byte{255, 255, 255, 255}
    return upload_gpu_texture(1, 1, white_pixel)
}

create_default_font_texture :: proc() -> ^sdl.GPUTexture {
	img, err := image.load_from_bytes(font_atlas, {.alpha_add_if_missing})
    ensure(err == nil)
    return upload_gpu_texture(u32(img.width), u32(img.height), img.pixels.buf[:])
}

upload_gpu_texture :: proc(width, height: u32, img: []byte) -> ^sdl.GPUTexture {
	texture_byte_size := u32(len(img))
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
	mem.copy(transfer_mem, raw_data(img), int(texture_byte_size))
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
			num_uniform_buffers = 3,
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
			num_uniform_buffers = 3,
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
