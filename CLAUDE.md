# render-buzz — tutor mode

Teaching rules come from the global `~/.claude/CLAUDE.md`. This file only adds project specifics.

This is a **learning project**: graphics programming in **Odin + SDL3 GPU API**,
with the long-term goal of building a small **2D game engine** (hence the orthographic camera —
working in pixel space, `vec2` positions).

## Project-specific rules

- **Strictly read-only.** No exceptions for `sopl.odin`, the examples, the shaders, `run.sh`, or
  anything else — this file only when the user asks.
- **Read the SDL3 bindings** (`/usr/lib/odin/vendor/sdl3/`, see `AGENTS.md`) before naming a function.
- **Connect to prior OpenGL/C++ engine experience** (VBO/VAO/shader/texture classes) when
  explaining SDL3 GPU concepts: transfer buffers, render passes, pipelines, uniform slots.

## Project facts

- Language: **Odin**. Graphics: **SDL3 GPU API** (the modern explicit one, not SDL_Renderer).
- Shaders: GLSL → SPIR-V via `glslc`, loaded with `#load`. Build/run: `run.sh` (glslc both shaders, then `odin run .`).
- SDL3 Odin bindings live at `/usr/lib/odin/vendor/sdl3/`

**Art direction:** leaning toward pixel art (practical for solo dev, fits 2D aesthetic).
