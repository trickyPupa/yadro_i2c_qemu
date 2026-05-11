import json
import socket
import time

SOCKET_PATH = "/tmp/qmp.sock"

def send_command(sock, cmd):
    sock.sendall(json.dumps(cmd).encode() + b'\n')
    response = b""
    while True:
        chunk = sock.recv(4096)
        if not chunk:
            break
        response += chunk
        if b'\n' in chunk:
            break
    return json.loads(response)

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(SOCKET_PATH)
send_command(sock, {"execute": "qmp_capabilities"})

while True:
    command = {
        "execute": "qom-get",
        "arguments": {
            "path": "/machine/peripheral/yadro-i2c",
            "property": "reg"
        }
    }
    response = send_command(sock, command)
    print(f"Register value: {response.get('return')}")
    time.sleep(1)