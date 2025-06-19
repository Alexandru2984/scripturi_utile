import socket
import threading
from datetime import datetime
from queue import Queue
import sys
import io


sys.stdin = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8')
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')


def scan_port(ip: str, port: int, timeout: float = 1.0) -> bool:
    """Scanează un port pe o adresă IP specificată."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(timeout)
            result = sock.connect_ex((ip, port))
            return result == 0
    except socket.error:
        return False

def worker(ip: str, port_queue: Queue, open_ports: list, timeout: float) -> None:
    """Funcția executată de fiecare thread pentru scanarea porturilor."""
    while not port_queue.empty():
        port = port_queue.get()
        if scan_port(ip, port, timeout):
            open_ports.append(port)
        port_queue.task_done()

def port_scanner(ip_address: str, ports: list[int], num_threads: int = 100, timeout: float = 1.0) -> None:
    """Scanează o listă de porturi pe o adresă IP folosind multiple thread-uri."""
    print(f"\n[*] Început scanare porturi pentru {ip_address} la {datetime.now()}")
    
    port_queue = Queue()
    for port in ports:
        port_queue.put(port)
    
    open_ports = []
    threads = []
    
    for _ in range(num_threads):
        thread = threading.Thread(
            target=worker,
            args=(ip_address, port_queue, open_ports, timeout)
        )
        thread.daemon = True
        thread.start()
        threads.append(thread)
    
    try:
        port_queue.join()
    except KeyboardInterrupt:
        print("\n[!] Scanare întreruptă de utilizator")
        return
    
    print(f"\n[*] Scanare terminată la {datetime.now()}")
    
    if open_ports:
        print("[+] Porturi deschise găsite:")
        for port in sorted(open_ports):
            print(f"  - Port {port}: OPEN")
    else:
        print("[-] Nu s-au găsit porturi deschise în intervalul specificat.")

if __name__ == "__main__":
    COMMON_PORTS = [
        20, 21, 22, 23, 25, 53, 67, 68, 80, 110, 
        135, 137, 138, 139, 443, 445, 3389, 8080
    ]
    try:
        target_ip = input("Introduceți adresa IP țintă: ")
        port_scanner(target_ip, COMMON_PORTS)
    except KeyboardInterrupt:
        print("\n[!] Program întrerupt de utilizator")
    except Exception as e:
        print(f"[!] Eroare neașteptată: {e}")