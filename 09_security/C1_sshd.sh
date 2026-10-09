#!/bin/bash
# Security step C1: SSH accepts keys only, no root login, shows a reminder banner.
# Exception: Hostinger's browser terminal (it logs in as root + password from 169.254.0.1,
# a link-local address that cannot come from the internet).
#
# Lockout safety: an automatic undo runs 10 min after this script, unless cancelled with
#   sudo systemctl stop sshd-rollback.timer
#
# Run as root on the VM:  sudo bash C1_sshd.sh
# Idempotent: safe to re-run. Log: ~$SUDO_USER/09_security_C1.log
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo bash $0" >&2; exit 1; }
user_home=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
log="$user_home/09_security_C1.log"
: > "$log"
chown "${SUDO_USER:-root}:" "$log"
exec > >(tee -a "$log") 2>&1

hostinger_addr=169.254.0.1
backup="/root/sshd-backup-$(date +%F_%H%M%S)"
rollback=/root/09_security_C1_rollback.sh

echo "== Hostinger browser-terminal logins seen (last 7 days)"
journalctl -u ssh --since "-7 days" --no-pager | grep "from $hostinger_addr" | tail -3 || echo "(none in the journal)"

echo "== Backup to $backup + rollback script"
mkdir -p "$backup"
cp -a /etc/ssh/sshd_config /etc/ssh/sshd_config.d "$backup/"
cat > "$rollback" <<EOF
#!/bin/bash
# Restores the sshd config saved before C1_sshd.sh ran.
cp -a "$backup/sshd_config" /etc/ssh/sshd_config
rm -rf /etc/ssh/sshd_config.d
cp -a "$backup/sshd_config.d" /etc/ssh/sshd_config.d
systemctl reload ssh
echo "sshd config rolled back from $backup"
EOF
chmod 700 "$rollback"

echo "== Write the new config"
cat > /etc/ssh/banner <<'EOF'
H-Frank-1
  Lost your key? A backup key is on your phone: search "HFrank1".
  Locked out? Hostinger panel > VPS > Browser terminal.
EOF

# sshd keeps the first value it reads, and sshd_config.d/ is included first:
# this file wins over the main file and 50-cloud-init.conf.
cat > /etc/ssh/sshd_config.d/00-hardening.conf <<'EOF'
# Managed by bootstrap-vm 09_security/C1_sshd.sh
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
Banner /etc/ssh/banner
EOF

# Same values in the other two files, so nobody reading them is misled.
sed -i -E 's/^PasswordAuthentication yes/PasswordAuthentication no/; s/^PermitRootLogin yes/PermitRootLogin no/' \
    /etc/ssh/sshd_config /etc/ssh/sshd_config.d/50-cloud-init.conf

# Match blocks must come last: rewrite ours at the end of the main file.
sed -i '/^# BEGIN bootstrap-vm C1/,/^# END bootstrap-vm C1/d' /etc/ssh/sshd_config
cat >> /etc/ssh/sshd_config <<EOF
# BEGIN bootstrap-vm C1: Hostinger browser terminal (root + password, link-local only)
Match Address $hostinger_addr
    PasswordAuthentication yes
    PermitRootLogin yes
# END bootstrap-vm C1
EOF

echo "== Check the result before applying it"
fail=0
expect() {  # expect <connection spec> <keyword> <value>
    local got
    got=$(sshd -T -C "$1" | awk -v k="$2" '$1 == k {print $2}')
    if [ "$got" = "$3" ]; then echo "ok   $1: $2 $got"; else echo "FAIL $1: $2 is '$got', want '$3'"; fail=1; fi
}
sshd -t || fail=1
internet="user=root,host=x,addr=203.0.113.9"
hostinger="user=root,host=x,addr=$hostinger_addr"
expect "$internet" port 443
expect "$internet" passwordauthentication no
expect "$internet" kbdinteractiveauthentication no
expect "$internet" permitrootlogin no
expect "$internet" pubkeyauthentication yes
expect "$internet" banner /etc/ssh/banner
expect "$hostinger" passwordauthentication yes
expect "$hostinger" permitrootlogin yes
if [ "$fail" -ne 0 ]; then
    echo "!! Check failed: restoring the old config, nothing applied"
    bash "$rollback"
    exit 1
fi

echo "== Schedule the automatic undo (10 min), then apply"
systemctl stop sshd-rollback.timer sshd-rollback.service 2>/dev/null || true
systemctl reset-failed sshd-rollback.timer sshd-rollback.service 2>/dev/null || true
systemd-run --unit=sshd-rollback --on-active=10min /bin/bash "$rollback"
systemctl reload ssh   # open sessions are not affected

echo
echo "== Applied. Within 10 minutes:"
echo "   1. test a NEW login from the Mac, and Hostinger's browser terminal"
echo "   2. if both work, keep it:  sudo systemctl stop sshd-rollback.timer"
echo "   Otherwise do nothing: the old config comes back by itself."
