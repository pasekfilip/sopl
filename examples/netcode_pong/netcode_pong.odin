package netcode_pong

import "core:fmt"
import "core:mem"
import "core:os"
import "core:net"
import "core:strings"
import s "../../"

WIDTH    :: 640
HEIGHT   :: 390
HELLO    :: string("hello")
WELCOME  :: string("welcome")
PADDLE_WIDTH :: 10
PADDLE_HEIGHT :: 60

role_names := [Network_Role]string {
    .Host   = "host",
    .Client = "client"
}

g: Packet_Game_State
n: Network_State

Network_State :: struct {
    role:                    Network_Role,
    socket:                  net.UDP_Socket,
    endpoint:                net.Endpoint,
    host_addr:               string,
    conn_established:        bool
}

Network_Role :: enum {
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
    if len(os.args) < 2 {
        fmt.eprintln("Supply <host|client>")
        os.exit(1)
    }
    if len(os.args) < 3 {
        fmt.eprintln("Supply ip")
        os.exit(1)
    }

    parse_role :: proc(s: string) -> (role: Network_Role, ok: bool) {
        for name, r in role_names {
            if strings.equal_fold(s, name) do return r, true
        }
        return {}, false
    }

    ok: bool
    n.role, ok = parse_role(os.args[1])
    if !ok {
        fmt.eprintln("Coudnt parse argv <host|client>")
        os.exit(1)
    }
    n.host_addr = os.args[2]

    switch n.role {
    case .Host:
        n.socket = bind_udp_socket("0.0.0.0", 9000)
    case .Client:
        // TODO use make_unbound_udp_socket
        n.socket = bind_udp_socket("0.0.0.0", 0)
    }

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

    s.init_window(WIDTH, HEIGHT, fmt.ctprintf("pong %s", role_names[n.role]), .VSYNC)
}

step :: proc() -> bool {
    if !s.update() {
        return false
    }

    switch n.role {
    case .Host:
        if !n.conn_established {
            setup_host()
            break
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
            setup_client(n.host_addr, 9000)
            listen_for_welcome()
            break
        }
        input_packet: Packet_Input
        if s.is_key_down(.W) do input_packet.input += {.W}
        if s.is_key_down(.S) do input_packet.input += {.S}

        buf := transmute([size_of(Packet_Input)]u8)input_packet
        net.send_udp(n.socket, buf[:], n.endpoint)

        listen_for_game_state()
    }

    if !n.conn_established {
        s.clear_background(s.DARKGRAY)
        s.draw_text({100,100,50,50}, strings.to_upper(role_names[n.role]))
        s.present()
        return true
    }

    s.clear_background(s.DARKGRAY)

    s.draw_text({260, 0, 50, 50}, fmt.tprint(g.p1_points))
    s.draw_text({325, 0, 50, 50}, fmt.tprint(g.p2_points))

    s.draw_rectangle({315, 0, 5, 390}, s.WHITE, 0)
    s.draw_rectangle(g.p1.rect, s.SKYBLUE)
    s.draw_rectangle(g.p2.rect, s.MAROON)

    s.draw_circle({g.ball.x, g.ball.y}, g.ball.w, s.YELLOW)

    s.present()
    free_all(context.temp_allocator)
    return true
}

end :: proc() {
    // net.close(sock)
    s.close_window()
}

setup_host :: proc() {
    buf: [len(HELLO)]u8
    _, remote_endpoint, err_recv := net.recv_udp(n.socket, buf[:])
    if err_recv != nil {
        fmt.println("Failed to recive data", err_recv)
        return
    }
    n.endpoint = remote_endpoint

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

setup_client :: proc(ip: string, port: int) {
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
        fmt.println("Failed to recive data", err_recv)
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
    net.set_blocking(sock, false)

    fmt.printfln("Listening on UDP: %s", ip, port)
    return sock
}
