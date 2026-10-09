#!/bin/bash
# Security step C2: firewall. Block everything coming in, except SSH (TCP 443),
# Tailscale (UDP 41641 + anything on tailscale0), loopback, ICMP,
# and replies to the VM's own traffic. IPv4 + IPv6. Outgoing traffic is not filtered.
#
# Uses its own nftables table only: Tailscale's rules are left alone.
#
# Lockout safety: an automatic undo runs 10 min after this script, unless cancelled with
#   sudo systemctl stop fw-rollback.timer
#
# Run as root on the VM:  sudo bash C2_firewall.sh
# Idempotent: safe to re-run. Log: ~$SUDO_USER/09_security_C2.log
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo bash $0" >&2; exit 1; }
user_home=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
log="$user_home/09_security_C2.log"
: > "$log"
chown "${SUDO_USER:-root}:" "$log"
exec > >(tee -a "$log") 2>&1

conf=/etc/nftables.conf
backup="/root/nftables.conf.backup-$(date +%F_%H%M%S)"
rollback=/root/09_security_C2_rollback.sh

echo "== Backup + rollback script"
if [ -e "$conf" ]; then cp -a "$conf" "$backup"; else backup=""; fi
cat > "$rollback" <<EOF
#!/bin/bash
# Undoes C2_firewall.sh: removes the firewall table, stops loading it at boot.
nft delete table inet vm_firewall 2>/dev/null || true
systemctl disable nftables 2>/dev/null || true
if [ -n "$backup" ]; then cp -a "$backup" "$conf"; else rm -f "$conf"; fi
echo "firewall rolled back"
EOF
chmod 700 "$rollback"

echo "== Write $conf"
# Never 'flush ruleset' here (Debian's default does): it would also wipe
# Tailscale's rules whenever nftables.service is (re)started.
cat > "$conf" <<'EOF'
#!/usr/sbin/nft -f
# Managed by bootstrap-vm 09_security/C2_firewall.sh
table inet vm_firewall {}
delete table inet vm_firewall
table inet vm_firewall {
    chain input {
        type filter hook input priority filter; policy drop;
        ct state established,related accept
        ct state invalid drop
        iifname "lo" accept
        iifname "tailscale0" accept
        meta l4proto { icmp, ipv6-icmp } accept
        tcp dport 443 accept comment "SSH"
        udp dport 41641 accept comment "Tailscale direct connections"
    }
}
EOF

echo "== Schedule the automatic undo (10 min)"
systemctl stop fw-rollback.timer fw-rollback.service 2>/dev/null || true
systemctl reset-failed fw-rollback.timer fw-rollback.service 2>/dev/null || true
systemd-run --unit=fw-rollback --on-active=10min /bin/bash "$rollback"

echo "== Install nftables (keeps the config above)"
if ! dpkg -s nftables >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 \
        -o Dpkg::Options::=--force-confold install -y nftables
fi

echo "== Check, then apply"
nft -c -f "$conf"
nft -f "$conf"
systemctl enable nftables   # load it at boot

echo "== Check the VM still works"
fail=0
check() {  # check <label> <command...>
    local label=$1; shift
    if "$@" >/dev/null 2>&1; then echo "ok   $label"; else echo "FAIL $label"; fail=1; fi
}
sleep 3
check "DNS"                        resolvectl query deb.debian.org
check "outgoing HTTPS"             curl -sS --max-time 10 -o /dev/null https://deb.debian.org/
check "Tailscale running"          tailscale status --peers=false
check "dashboard (local)"          curl -sS --max-time 5 -o /dev/null http://127.0.0.1:8098/
if [ "$fail" -ne 0 ]; then
    echo "!! A check failed: undoing the firewall now"
    bash "$rollback"
    exit 1
fi
nft list table inet vm_firewall

echo
echo "== Applied. Within 10 minutes:"
echo "   1. tell Claude 'applied' (it tests SSH, Tailscale, the dashboard from the Mac)"
echo "   2. if all good, keep it:  sudo systemctl stop fw-rollback.timer"
echo "   Otherwise do nothing: the firewall is removed by itself."
