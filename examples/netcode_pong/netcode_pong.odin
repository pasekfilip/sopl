package netcode_pong

import "core:fmt"
import "core:mem"
import "core:os"
import "core:net"
import "core:strings"
import s "../../"

WIDTH    :: 1280
HEIGHT   :: 720
HELLO    :: string("hello")
WELCOME  :: string("welcome")
PADDLE_WIDTH :: 10
PADDLE_HEIGHT :: 60

BUTTON_W      :: 300
BUTTON_H      :: 100
INPUT_W       :: 700
INPUT_H       :: 100
BUTTON_COLOR  :: s.MAROON
GAP           :: 20

g: Packet_Game_State
n: Network_State

Network_State :: struct {
    role:                    Network_Role,
    socket:                  net.UDP_Socket,
    endpoint:                net.Endpoint,
    host_addr:               [15]u8,
    conn_established:        bool
}

Network_Role :: enum {
    None,
    Host,
    Client
}

Paddle :: struct {
    using rect: s.Rect,
    speed:      f32,
    velocity:   s.Vec2,
    update: proc(p: ^Paddle, keys: Packet_Input, dt: f32)
}

Ball :: struct {
    using rect: s.Rect,
    velocity:   s.Vec2,
    alive:      bool
}

Packet_Game_State :: struct #packed {
    p1:         Paddle,
    p2:         Paddle,
    ball:       Ball,
    p1_points:  u8,
    p2_points:  u8
}

Input :: enum {
    W,
    S
}

Packet_Input :: struct #packed {
    input: bit_set[Input]
}

main :: proc() {
    init()
    for step() {}
    end()
}

init :: proc() {
    g.p1 = Paddle {
        rect = {10, 185, PADDLE_WIDTH, PADDLE_HEIGHT},
        speed = 200,
        update = proc(p: ^Paddle, keys: Packet_Input, dt: f32) {
            if s.is_key_down(.W) do p.y -= p.speed * dt
            if s.is_key_down(.S) do p.y += p.speed * dt
        }
    }
    g.p2 = Paddle {
        rect = {WIDTH - PADDLE_WIDTH - 10, 185, PADDLE_WIDTH, PADDLE_HEIGHT},
        speed = 200,
        update = proc(p: ^Paddle, keys: Packet_Input, dt: f32) {
            if .W in keys.input do p.y -= p.speed * dt
            if .S in keys.input do p.y += p.speed * dt
        }
    }

    s.init_window(WIDTH, HEIGHT, "pong af", {})
}

/*
Click host u are in wating queue
Click client u get an input where u type the ip
*/
step :: proc() -> bool {
    if !s.update() {
        return false
    }

    w := f32(s.get_window_width())
    h := f32(s.get_window_height())

    s.clear_background(s.DARKGRAY)
    s.stack_layout({w/2, h/2}, GAP)

    switch n.role {
    case .None:
        mouse_pos := s.get_mouse_position()
        s.draw_rectangle({mouse_pos.x, mouse_pos.y, 5, 5}, s.WHITE)

        title := "Crazy multiplayer pong!!"
        text_pos := s.move_cursor(s.get_text_size(10, len(title)))
        s.draw_text({text_pos.x, text_pos.y}, title, 10)

        if s.gui_button(s.move_cursor({BUTTON_W, BUTTON_H}), "Host", BUTTON_COLOR) {
            n.role = .Host
        }
        if s.gui_button(s.move_cursor({BUTTON_W, BUTTON_H}), "Client", BUTTON_COLOR) {
            n.role = .Client
        }
        if s.gui_button(s.move_cursor({BUTTON_W, BUTTON_H}), "Exit", BUTTON_COLOR) {
            s.close_window()
        }

        s.present()
        return true
    
    case .Host:
        if !n.conn_established {
            if n.socket == 0 {
                n.socket = bind_udp_socket("0.0.0.0", 9000)
                net.set_blocking(n.socket, false)
            }
            listen_for_hello()

            mouse_pos := s.get_mouse_position()
            s.draw_rectangle({mouse_pos.x, mouse_pos.y, 5, 5}, s.WHITE)

            title := "Crazy multiplayer pong!!"
            text_pos := s.move_cursor(s.get_text_size(10, len(title)))
            s.draw_text({text_pos.x, text_pos.y}, title, 10)

            wating_text := "Wating for client"
            text_pos = s.move_cursor(s.get_text_size(5, len(wating_text)))
            s.draw_text({text_pos.x, text_pos.y}, wating_text, 5, s.YELLOW)
            if s.gui_button(s.move_cursor({BUTTON_W, BUTTON_H}), "Cancel", BUTTON_COLOR) {
                n.role = .None
                n.socket = 0
                net.close(n.socket)
            }

            s.present()
            return true
        }

        buf: [size_of(Packet_Input)]u8 
        input: Packet_Input
        for {
            responds_size, _, err := net.recv_udp(n.socket, buf[:])
            if err == .Would_Block do break
            if responds_size != size_of(Packet_Input) do break
            input = transmute(Packet_Input)buf

            g.p2.update(&g.p2, input, s.get_delta_time())
        }

        g.p1.update(&g.p1, {}, s.get_delta_time())
        if !g.ball.alive {
            g.ball = Ball {
                rect = {WIDTH/2, HEIGHT/2, 5, 5},
                alive = true,
                velocity = {-200, 0},
            }
        }
        g.ball.x += g.ball.velocity.x * s.get_delta_time()
        g.ball.y += g.ball.velocity.y * s.get_delta_time()

        p1_collision, _ := s.aabb(g.ball.rect, g.p1.rect)
        p2_collision, _ := s.aabb(g.ball.rect, g.p2.rect)

        p1_gate_collision := g.ball.x <= 0
        p2_gate_collision := g.ball.x >= WIDTH

        top_bounce_collision    := g.ball.y <= 0
        bottom_bounce_collision := g.ball.y >= HEIGHT

        if top_bounce_collision || bottom_bounce_collision {
            g.ball.velocity.y *= -1
        }

        if p1_collision {
            y_diff := g.ball.y - (g.p1.y + g.p1.h/2)
            g.ball.velocity.y += 10 * y_diff
            g.ball.velocity.x *= -1.1
        }
        if p2_collision {
            y_diff := g.ball.y - (g.p2.y + g.p2.h/2)
            g.ball.velocity.y += 10 * y_diff
            g.ball.velocity.x *= -1.1
        }

        if p1_gate_collision {
            g.ball.alive = false
            g.p2_points += 1
        }
        if p2_gate_collision {
            g.ball.alive = false
            g.p1_points += 1
        }
        send_game_state()

    case .Client:
        if !n.conn_established {
            if n.socket == 0 {
                n.socket, _ = net.make_unbound_udp_socket(.IP4)
                net.set_blocking(n.socket, false)
            }

            rect := s.move_cursor({INPUT_W, INPUT_H})
            count := s.gui_input({rect.x, rect.y}, rect.h, n.host_addr[:])
            if s.gui_button(s.move_cursor({BUTTON_W, BUTTON_H}), "Connect", BUTTON_COLOR) {
                send_hello_to(string(n.host_addr[:count]), 9000)
            }
            if s.gui_button(s.move_cursor({BUTTON_W, BUTTON_H}), "Cancel", BUTTON_COLOR) {
                n.role = .None
                net.close(n.socket)
            }

            listen_for_welcome()
            s.present()
            return true
        }
        input_packet: Packet_Input
        if s.is_key_down(.W) do input_packet.input += {.W}
        if s.is_key_down(.S) do input_packet.input += {.S}

        buf := transmute([size_of(Packet_Input)]u8)input_packet
        net.send_udp(n.socket, buf[:], n.endpoint)

        listen_for_game_state()
    }


    s.clear_background(s.DARKGRAY)

    s.draw_text({260, 0}, fmt.tprint(g.p1_points), 20)
    s.draw_text({325, 0}, fmt.tprint(g.p2_points), 20)

    s.draw_rectangle({315, 0, 5, 390}, s.WHITE, 0)
    s.draw_rectangle(g.p1.rect, s.SKYBLUE)
    s.draw_rectangle(g.p2.rect, s.MAROON)

    s.draw_circle({g.ball.x, g.ball.y}, g.ball.w, s.YELLOW)

    s.present()
    free_all(context.temp_allocator)
    return true
}

end :: proc() {
    s.close_window()
}

listen_for_hello :: proc() {
    buf: [len(HELLO)]u8
    _, remote_endpoint, err_recv := net.recv_udp(n.socket, buf[:])
    if err_recv != nil {
        fmt.println("Failed to recive data", err_recv)
        return
    }
    n.endpoint = remote_endpoint
    fmt.println(buf[:])

    if string(buf[:]) == HELLO {
        n.conn_established = true

        buf := transmute([]u8)WELCOME
        _, err_send := net.send_udp(n.socket, buf, n.endpoint)
        if err_send != nil {
            fmt.println("Fail to send WELCOME message", err_send)
            return
        }
    }
}

send_hello_to :: proc(ip: string, port: int) {
    host_addr, ok := net.parse_ip4_address(ip)
    if !ok {
        fmt.println("Failed to parse IP address")
        return
    }
    n.endpoint = net.Endpoint {
        address = host_addr,
        port    = port
    }

    buf := transmute([]u8)HELLO
    _, err_send := net.send_udp(n.socket, buf, n.endpoint)
    if err_send != nil {
        fmt.println("Failed to send data", err_send)
    }
}

listen_for_welcome :: proc() {
    buf: [len(WELCOME)]u8
    _, _, err_recv := net.recv_udp(n.socket, buf[:])
    if err_recv != nil {
        // fmt.println("Failed to recive data", err_recv)
        return
    }
    if string(buf[:]) == WELCOME {
        n.conn_established = true
        fmt.println("we got welcome")
    }
}

send_game_state :: proc() {
    buf := mem.ptr_to_bytes(&g)
    _, err := net.send_udp(n.socket, buf, n.endpoint)
    if err != nil {
        fmt.println("Fail to send game state", err)
        return
    }
}

listen_for_game_state :: proc() {
    buf: [size_of(Packet_Game_State)]u8
    for {
        n, _, err := net.recv_udp(n.socket, buf[:])
        if err == .Would_Block do break
        if err != nil || n != size_of(Packet_Game_State) do return;
        g = transmute(Packet_Game_State)buf
    }
}

send_client_input :: proc() {
    s.is_key_down(.W)
    s.is_key_down(.S)
}

bind_udp_socket :: proc(ip: string, port: int) -> net.UDP_Socket {
    addr, ok := net.parse_ip4_address(ip)
    if !ok {
        fmt.println("Failed to parse IP address")
        return {}
    }

    sock, err := net.make_bound_udp_socket(addr, port)
    if err != nil {
        fmt.println("Failed to make bound UDP socket", err)
        return {}
    }

    fmt.printfln("Listening on UDP: %s", ip, port)
    return sock
}
