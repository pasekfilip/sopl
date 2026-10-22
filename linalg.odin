#+private
package sopl

sex_ortho :: proc(left, right, top, bottom: f32) -> (m: matrix[4,4]f32) {
    m = 1
    m[0, 0] =  2/f32(right - left)
    m[1, 1] = -2/f32(bottom - top)
    m[0, 3] = -1
    m[1, 3] =  1
    return
}
