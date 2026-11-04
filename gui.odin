package sopl

/*
    Bcs the font is 12/6 we should prop
    scale it properly when computing from the size of the button
    TODO: Make outline on the button
    TODO: Make states nothing pressed hovered
*/
gui_button :: proc(rect: Rect, text: string, color: Color) -> bool {
    font_height := rect.h/2
    font_width := font_height/2
    draw_rectangle(rect, color)
    text_rect := Rect {
        rect.x + rect.w/2 - (font_width/2) * f32(len(text)),
        rect.y + rect.h/2 - font_height/2,
        font_width,
        font_height
    }
    draw_text(text_rect, text, WHITE)

    is_mouse_button_pressed() or_return
    mouse_pos := get_mouse_position()
    collided, _ := aabb(rect, {mouse_pos.x, mouse_pos.y, 5, 5})
    return collided
}
