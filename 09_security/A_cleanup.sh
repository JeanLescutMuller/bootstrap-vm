#!/bin/bash
# Security step A: close what no longer needs to be public (Jupyter, nginx, LLMNR),
# and keep logs bounded. No lockout risk: SSH and Tailscale are not touched.
#
# Run as root on the VM:  sudo bash A_cleanup.sh
# Idempotent: safe to re-run. Log: ~$SUDO_USER/09_security_A.log
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo bash $0" >&2; exit 1; }
user_home=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
log="$user_home/09_security_A.log"
: > "$log"
chown "${SUDO_USER:-root}:" "$log"
exec > >(tee -a "$log") 2>&1
today=$(date +%F)

echo "== A1 Jupyter: stop, disable, delete the unit"
for unit in jupyterlab.service jupyterhub.service; do
    if [ -e "/etc/systemd/system/$unit" ]; then
        systemctl disable --now "$unit" || true
        rm -f "/etc/systemd/system/$unit"
        echo "removed $unit"
    fi
done
if [ -e /etc/init.d/jupyterhub ]; then
    update-rc.d -f jupyterhub remove
    rm -f /etc/init.d/jupyterhub
    echo "removed /etc/init.d/jupyterhub"
fi
systemctl daemon-reload
# /opt/anaconda3 is kept on purpose (only Jupyter goes).

echo "== A2 nginx: archive its logs, then purge it"
if [ -d /var/log/nginx ] && [ ! -e "/root/nginx-logs-$today.tar.gz" ]; then
    tar -czf "/root/nginx-logs-$today.tar.gz" -C /var/log nginx
    echo "logs archived to /root/nginx-logs-$today.tar.gz"
fi
nginx_pkgs=$(dpkg-query -W -f='${Package} ${db:Status-Abbrev}\n' 2>/dev/null \
    | awk '$1 ~ /^(lib)?nginx/ && $2 ~ /^[ir]/ {print $1}')
if [ -n "$nginx_pkgs" ]; then
    # shellcheck disable=SC2086
    DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 purge -y $nginx_pkgs
fi
# Leftovers dpkg does not own: bootstrap-vm's location.d/conf.d files, the home page.
rm -rf /etc/nginx /var/www /var/log/nginx

echo "== A3 LLMNR off (port 5355)"
mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nLLMNR=no\n' > /etc/systemd/resolved.conf.d/no-llmnr.conf
systemctl restart systemd-resolved
sleep 2
if resolvectl query github.com >/dev/null 2>&1; then
    echo "DNS ok after restart"
else
    echo "DNS failed after restart: restarting tailscaled to re-push its DNS"
    systemctl restart tailscaled
    sleep 5
    resolvectl query github.com >/dev/null && echo "DNS ok" || echo "!! DNS STILL BROKEN"
fi

echo "== A4 logrotate + unattended-upgrades"
dpkg -s logrotate >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y logrotate
apt-config dump APT::Periodic::Unattended-Upgrade
systemctl is-active apt-daily-upgrade.timer

echo "== A5 delete the port 80 audit leftovers"
rm -rf "$user_home/port80_audit" "$user_home/port80_collect.sh"

echo "== Result: listening ports (expect public: TCP 443, UDP 41641 only)"
ss -ltnuH | awk '{print $1, $5}' | sort -u
echo "== done"
