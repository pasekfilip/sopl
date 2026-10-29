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

Packet_Game_State :: struct #packed {
    count: int
}

Packet_Input :: struct #packed {

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

    s.init_window(fmt.ctprintf("pong %s", role_names[n.role]), WIDTH, HEIGHT, .VSYNC)
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
        send_game_state()

    case .Client:
        if !n.conn_established {
            setup_client(n.host_addr, 9000)
            listen_for_welcome()
            break
        }

        listen_for_game_state()
    }
    if !n.conn_established {
        s.clear_background(s.DARKGRAY)
        s.draw_text({100,100,50,50}, strings.to_upper(role_names[n.role]))
        s.present()
        return true
    }

    if s.is_key_pressed(.U) do g.count += 1

    buf: [32]byte
    s.draw_text({50,50,20,20}, fmt.bprint(buf[:], g.count))
    s.clear_background(s.DARKGRAY)
    s.present()
    return true
}

end :: proc() {
    free_all(context.temp_allocator)
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
    n, _, err := net.recv_udp(n.socket, buf[:])
    if err != nil || n != size_of(Packet_Game_State) do return;
    g = transmute(Packet_Game_State)buf
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
