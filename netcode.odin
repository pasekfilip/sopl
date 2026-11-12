package sopl
/*
    TODO: could be its own package 
    bcs it can exists standalone
*/ 

import "core:strings"
import "core:net"
import "core:log"

DEFAULT_HOST_IP    :: net.IP4_Address{0, 0, 0, 0}
DEFAULT_HOST_PORT  :: 9000
HELLO              :: string("hello")
WELCOME            :: string("welcome")

@(private="file")
s: Network_State

Network_State :: struct {
    role:      Network_Role,
    socket:    net.UDP_Socket,
    endpoint:  net.Endpoint,
}

Network_Role :: enum {
    None,
    Host,
    Client
}

set_network_role :: proc(role: Network_Role) {
    s.role = role
}

set_endpoint :: proc(ip: []u8) -> bool {
    addr, ok := net.parse_ip4_address(string(ip))
    if !ok {
        log.error("Failed to parse IP address")
        return false
    }
    s.endpoint = {
        address = addr,
        port =   DEFAULT_HOST_PORT
    }
    return true
}

get_network_role :: proc() -> Network_Role {
    return s.role
}

unbind_socket :: proc() {
    s.socket = 0
    net.close(s.socket)
}

setup_client :: proc() -> bool {
    ok: bool
    if s.socket == 0 {
        s.socket, ok = bind_client_socket()
    }
    if s.endpoint == {} do return false
    send_hello()
    return listen_for_welcome()
}

bind_client_socket :: proc() -> (net.UDP_Socket, bool) {
    sock, err := net.make_unbound_udp_socket(.IP4)
    if err != nil {
        log.error("Failed to make unbound UDP socket", err)
        return {}, false
    }
    net.set_blocking(sock, false)

    log.info("Bound client socket")
    return sock, true
}

send_hello :: proc() {
    buf := transmute([]u8)HELLO
    _, err_send := net.send_udp(s.socket, buf, s.endpoint)
    if err_send != nil {
        log.error("Failed to send data", err_send)
    }
    log.info("We have send hello to the host")
}

listen_for_welcome :: proc() -> bool {
    buf: [len(WELCOME)]u8
    n, _, err_recv := net.recv_udp(s.socket, buf[:])
    switch {
    case err_recv == .Would_Block:
        return false
    case string(buf[:]) != WELCOME:
        log.error("Recived bytes dont match welcome")
        return false
    case err_recv != nil:
        log.error("Failed to recive data", err_recv)
        return false
    }

    log.info("We got welcome from client")
    return true
}

setup_host :: proc() -> bool {
    ok: bool
    if s.socket == 0 {
        s.socket, ok = bind_host_socket()
    }
    ok, s.endpoint = listen_for_hello()
    ok or_return
    return send_welcome()
}

bind_host_socket :: proc() -> (net.UDP_Socket, bool) {
    sock, err := net.make_bound_udp_socket(DEFAULT_HOST_IP, DEFAULT_HOST_PORT)
    if err != nil {
        log.error("Failed to make bound UDP socket", err)
        return {}, false
    }
    net.set_blocking(sock, false)

    log.info("Bound host socket")
    return sock, true
}

listen_for_hello :: proc() -> (bool, net.Endpoint) {
    buf: [len(HELLO)]u8
    n, remote_endpoint, err_recv := net.recv_udp(s.socket, buf[:])
    switch {
    case err_recv == .Would_Block:
        return false, {}
    case err_recv != nil:
        log.error("Failed to recive data", err_recv)
        return false, {}
    case string(buf[:]) != HELLO:
        log.error("Recived bytes dont match hello")
        return false, {}
    }

    return true, remote_endpoint
}

send_welcome :: proc() -> bool {
    buf := transmute([]u8)WELCOME
    _, err_send := net.send_udp(s.socket, buf, s.endpoint)
    if err_send != nil {
        log.error("Fail to send WELCOME message", err_send)
        return false
    }
    return true
}
