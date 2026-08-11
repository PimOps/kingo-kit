# Fast development over SSH with VMware Fusion

The fastest Kingo Kit development workflow is to keep the repository and Docker containers inside the Ubuntu VM while using the macOS terminal or an SSH-capable editor. SSH avoids repeatedly switching into the VMware window and also provides secure tunnels to the web applications that bind to `127.0.0.1` inside Ubuntu.

## 1. Configure VMware networking

Shut down the VM before changing its virtual hardware. In VMware Fusion, open **Virtual Machine > Settings > Network Adapter** and make sure the adapter is connected.

For development on one Mac, **Share with my Mac** (NAT) is the recommended mode. The VM receives a private address, retains internet access through the Mac, and is not presented as a separate computer to the rest of the physical network.

**Bridged Networking** is an alternative when NAT does not allow the connection. The VM then appears as another computer on the same LAN as the Mac. This is convenient but exposes the VM directly to that network, so avoid it on untrusted or public Wi-Fi. Broadcom describes the available Fusion networking modes in [Understanding networking types in VMware Fusion](https://knowledge.broadcom.com/external/article/303393/understanding-networking-types-in-vmware.html).

Start the VM after selecting the network mode.

## 2. Install and enable SSH in Ubuntu

Run these commands in the Ubuntu VM:

```bash
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
systemctl status ssh --no-pager
```

The status should be `active (running)`. Ubuntu's official [OpenSSH server guide](https://documentation.ubuntu.com/server/how-to/security/openssh-server/) contains additional configuration and security options.

If Ubuntu's firewall is active, allow SSH:

```bash
sudo ufw status
sudo ufw allow OpenSSH
```

The second command is only needed when UFW is enabled. It opens TCP port 22; see Ubuntu's [firewall documentation](https://documentation.ubuntu.com/server/how-to/security/firewalls/).

## 3. Find the VM address

In Ubuntu, run:

```bash
hostname -I
```

Use the private IPv4 address, commonly something like `192.168.x.x` or `172.16.x.x`. If several addresses are shown, this command gives a clearer list:

```bash
ip -4 -brief address
```

Do not use `127.0.0.1`, a Docker bridge such as `172.17.0.1`, or an address belonging to a disconnected interface. The main interface is commonly named `ens33`, `ens160`, or `eth0`.

VMware normally assigns the address using DHCP, so it can change after changing network modes or recreating the VM. Re-run `hostname -I` when a previously working connection stops.

## 4. Connect from the Mac

Open Terminal on macOS and substitute the Ubuntu username and address:

```bash
ssh pim@192.168.123.45
```

Confirm the host fingerprint on the first connection, then enter the Ubuntu account password. Once connected, verify the session:

```bash
hostname
cd ~/kingo-kit
./kingo status
```

An SSH login is also a fresh Linux login session. It should therefore pick up the `docker` group correctly:

```bash
id -nG
docker ps
```

## 5. Configure key-based login

On the Mac, create an Ed25519 key if one does not already exist:

```bash
ssh-keygen -t ed25519 -C "kingo-vm-development"
```

Accept the default location and use a passphrase. Copy the public key to Ubuntu. If `ssh-copy-id` is installed on the Mac:

```bash
ssh-copy-id pim@192.168.123.45
```

The following standard SSH command works when `ssh-copy-id` is unavailable:

```bash
cat ~/.ssh/id_ed25519.pub | ssh pim@192.168.123.45 \
  'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys'
```

Test the key before making any SSH server authentication changes:

```bash
ssh pim@192.168.123.45
```

## 6. Add a convenient SSH alias and app tunnels

Add this entry to `~/.ssh/config` on the Mac, replacing the address and username:

```sshconfig
Host kingo-vm
    HostName 192.168.123.45
    User pim
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ControlMaster auto
    ControlPath ~/.ssh/kingo-%C
    ControlPersist 10m

    LocalForward 8888 127.0.0.1:8888
    LocalForward 7860 127.0.0.1:7860
    LocalForward 5678 127.0.0.1:5678
    LocalForward 3000 127.0.0.1:3000
    LocalForward 8978 127.0.0.1:8978
    LocalForward 6333 127.0.0.1:6333
    LocalForward 6334 127.0.0.1:6334
    LocalForward 5432 127.0.0.1:5432
```

Connect using the short name:

```bash
ssh kingo-vm
```

While that SSH connection is open, the Kingo Kit services are available in the Mac browser at their normal addresses:

- JupyterLab: <http://localhost:8888>
- Langflow: <http://localhost:7860>
- n8n: <http://localhost:5678>
- Metabase: <http://localhost:3000>
- CloudBeaver: <http://localhost:8978>
- Qdrant dashboard: <http://localhost:6333/dashboard>
- Qdrant gRPC: `localhost:6334`
- PostgreSQL: `localhost:5432`

These tunnels preserve Kingo Kit's safer `BIND_ADDRESS=127.0.0.1` default. There is no need to expose the classroom services to the LAN with `0.0.0.0`.

If one of those ports is already in use on the Mac, remove that `LocalForward` entry or change only its first port number. For example, `LocalForward 13000 127.0.0.1:3000` makes Metabase available at `http://localhost:13000` on the Mac.

## 7. Fast daily workflow

Connect and work inside the VM:

```bash
ssh kingo-vm
cd ~/kingo-kit
git pull
./kingo up
```

For quick non-interactive operations from the Mac:

```bash
ssh kingo-vm 'cd ~/kingo-kit && ./kingo status'
ssh kingo-vm 'cd ~/kingo-kit && ./kingo health metabase'
ssh kingo-vm 'cd ~/kingo-kit && git pull && ./kingo up'
```

An editor with remote SSH support can open `~/kingo-kit` directly inside Ubuntu. In that arrangement, the editor interface runs on the Mac while its terminal, Git operations, language tools, and file access run in the VM. This avoids copying the repository between macOS and Ubuntu and ensures code is tested in the same environment students use.

For commands that should survive a dropped SSH connection, use `tmux`:

```bash
sudo apt install -y tmux
tmux new -s kingo
```

Detach with `Ctrl+B`, then `D`. Reconnect later with:

```bash
tmux attach -t kingo
```

## Troubleshooting

### Connection times out

In Ubuntu:

```bash
systemctl status ssh --no-pager
hostname -I
sudo ss -lntp | grep ':22'
sudo ufw status
```

On the Mac:

```bash
nc -vz 192.168.123.45 22
```

Check that Fusion's network adapter is connected and that the IP address has not changed. If NAT remains unreachable, shut down the VM and try Bridged Networking.

### Permission denied

Use verbose client output to identify whether password or key authentication failed:

```bash
ssh -v kingo-vm
```

On Ubuntu, inspect the SSH service log:

```bash
sudo journalctl -u ssh --since "10 minutes ago"
```

### Host identification changed

This is expected if the VM was reinstalled at the same address, but investigate unexpected changes before removing the saved key. For a VM you intentionally reinstalled:

```bash
ssh-keygen -R 192.168.123.45
```

If the SSH alias was previously used, also run:

```bash
ssh-keygen -R kingo-vm
```

### The SSH connection works but a forwarded app does not

Check the Kingo Kit service from the SSH session:

```bash
cd ~/kingo-kit
./kingo status
./kingo health metabase
```

Also confirm that no other process on the Mac is already using the selected local port.
