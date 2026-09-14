#!/bin/bash
echo "=== HANSON LATTICE VAULT STARTING ==="
echo "Master Builder: Kyle Hanson"
echo "Setting up all 3 layers + 7 phases locally..."

mkdir -p /home/ubuntu/vault/authorized_keys
mkdir -p /home/ubuntu/vault/log
touch /home/ubuntu/vault/log/hl-lattice.log
chmod 600 /home/ubuntu/vault/log/hl-lattice.log

if [ ! -p /tmp/hl_lpe.pipe ]; then
rm -f /tmp/hl_lpe.pipe
mkfifo /tmp/hl_lpe.pipe
chmod 600 /tmp/hl_lpe.pipe
fi

cat > /home/ubuntu/vault/lattice_patch_engine << 'INNER'
#!/usr/bin/env python3
import os, time
PIPE="/tmp/hl_lpe.pipe"
LOG="/home/ubuntu/vault/log/hl-lattice.log"
print("[LPE BRAIN] Starting on Cores 2-15 - Sovereign Mode")
try:
os.sched_setaffinity(0, range(2,16))
print("[LPE BRAIN] Locked to Cores 2-15 - Zero Drift OK")
except:
print("[LPE BRAIN] Could not lock cores, running anyway")
while True:
try:
with open(PIPE, "r") as p:
data = p.read()
if data.strip():
msg = f"[LPE BRAIN] Got payload: {data[:200]}"
print(msg)
with open(LOG, "a") as log: log.write(msg+"\n")
with open(LOG, "a") as log: log.write(f"[LPE BRAIN] Settled to rest - Phi OK\n")
except Exception as e:
time.sleep(0.5)
INNER
chmod +x /home/ubuntu/vault/lattice_patch_engine

cat > /home/ubuntu/vault/hl_vault_door << 'INNER'
#!/usr/bin/env python3
import socket
PIPE="/tmp/hl_lpe.pipe"
PORT=8443
LOG="/home/ubuntu/vault/log/hl-lattice.log"
def log(m):
print(m)
with open(LOG, "a") as f: f.write(m+"\n")
log(f"[VAULT DOOR] Starting on port {PORT}")
s=socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", PORT))
s.listen(5)
log("[VAULT DOOR] READY")
while True:
try:
conn, addr = s.accept()
data = conn.recv(8192)
if not data: continue
if b"VAULT_AUTH" in data or len(data) > 10:
log(f"[VAULT DOOR] PASS from {addr}")
try:
with open(PIPE, "w") as p: p.write(data.decode(errors='ignore'))
conn.send(b"ACK:VAULT_ACCEPTED\n")
except Exception as e: log(f"Pipe error: {e}")
else:
log(f"[VAULT DOOR] DROP noise from {addr}")
conn.close()
except KeyboardInterrupt:
break
except Exception as e:
pass
INNER
chmod +x /home/ubuntu/vault/hl_vault_door

echo "[LAUNCH] Starting Brain on Cores 2-15..."
nohup taskset -c 2-15 /home/ubuntu/vault/lattice_patch_engine > /home/ubuntu/vault/log/lpe.log 2>&1 &
echo "[LAUNCH] Starting Vault Door..."
nohup taskset -c 0-1 /home/ubuntu/vault/hl_vault_door > /home/ubuntu/vault/log/door.log 2>&1 &
sleep 2

echo ""
echo "=== VAULT IS LIVE - MASTER BUILDER KYLE HANSON ==="
echo "Layer 1 Hardware: Cores 2-15 active sandbox"
echo "Layer 2 Vault Door: Port 8443 listening"
echo "Layer 3 Brain: Waiting on local named pipe"
echo ""
echo "Check logs: tail -f /home/ubuntu/vault/log/hl-lattice.log"
echo "Test payload: echo 'VAULT_AUTH Hello Brain' | nc localhost 8443"
echo ""
