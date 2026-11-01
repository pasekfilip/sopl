package build

import "core:os"
import "core:fmt"
import "core:time"
import "core:strings"


main :: proc() {
    files, err := os.read_all_directory_by_path("./shaders", context.allocator)
    defer os.file_info_slice_delete(files, context.allocator)

    spv_times := make(map[string]time.Time, context.temp_allocator)
    for f in files {
        if strings.has_suffix(f.name, ".spv") {
            spv_times[strings.trim_suffix(f.name, ".spv")] = f.modification_time
        }
    }

    for f in files {
        (!strings.has_suffix(f.name, ".spv")) or_continue
        spv_time, found := spv_times[f.name]
        if !found || time.diff(spv_time, f.modification_time) > 0 {
            fmt.println("Needs rebuild: ",f.name)
            dst := strings.concatenate({"shaders/", f.name, ".spv"}, context.temp_allocator)
            src := strings.concatenate({"shaders/", f.name}, context.temp_allocator)

            state, stdout, stderr, err := os.process_exec(
                {command = {"glslc", src, "-o", dst }},
                context.temp_allocator
            )
        }
    }
}
