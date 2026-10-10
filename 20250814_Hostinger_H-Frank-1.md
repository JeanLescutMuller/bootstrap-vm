This is a log of what has been succesfully done/deployed (and can be repeated) for :
- Provider : Hostinger
- Type : EC2 (t2 instance)
- Debian 12
- Jupyterlab (no JupyterHub, no Shell-in-a-box, etc...)


### 1. Create VM + Connect + Setup user & sshd
`ssh root@{ip}` # root password: in the password manager (never in this repo)

Then :
```bash

# Add Enrices
useradd -m -p '{HASHED PASSWORD, see: openssl passwd -6}' -s /bin/bash enrices
usermod -aG sudo enrices

# Setup ssh on port 443 & Disable root login
SSHD_CONF="/etc/ssh/sshd_config"
# You can do `grep -v -e '^#' -e '^$' $SSHD_CONF` to check the conf without comments or empty lines
# Weird thing : We observe that `PasswordAuthentication no` but we just connected using root+password...

update_or_append() {
    local field="$1"      # e.g., "PasswordAuthentication"
    local separator="$2"  # e.g., " " or "="
    local value="$3"      # e.g., "yes"
    local filename="$4"   # file to update

    local full_line="${field}${separator}${value}"

    if grep -q -E "^\s*#?\s*${field}\s*" "$filename"; then
        echo "Changing ${field} to '${value}' in ${filename}"
        sudo sed -i -E "s|^\s*#?\s*${field}\s*.*|${full_line}|" "$filename"
    else
        echo "Appending '${full_line}' to ${filename}"
        echo "$full_line" | sudo tee -a "$filename" > /dev/null
    fi
}

update_or_append "PasswordAuthentication" " " "yes" "$SSHD_CONF"
update_or_append "Port" " " "443" "$SSHD_CONF"
update_or_append "PermitRootLogin" " " "no" "$SSHD_CONF"

grep -v -e '^#' -e '^$' $SSHD_CONF

service sshd restart
service sshd status
```

Important : Do NOT exit this terminal/SSH connection yet, and test a new ssh on another Terminal
```bash
ssh -p 443 enrices@...
```

### 2. Install basic binaries & Clone this project

Make yourself root :
```bash
sudo su
```

And then from root :
```bash
cd # go to home
apt update && apt install -y git vim tree telnet wget
git clone https://github.com/JeanLescutMuller/DataScience_stack_server.git
cd ./DataScience_stack_server
```

### 3. Setting up .bashrc for users :

```bash
# For root :
chmod +x ./01_unix_helpers/root/usr/sbin/adduser2
chmod +x ./01_unix_helpers/root/usr/bin/configurebashrc
cp -R ./01_unix_helpers/root/* /
configurebashrc # root
# host_color=31 configurebashrc # for PROD environment (make hostname RED)
source ~/.bashrc
sudo -u enrices configurebashrc # 👨‍💻 Perso
# Note : I didnt do it for user "admin" since I am using "enrices" as a user (Added it in the user data script)

# Changing the hostname :
hostnamectl set-hostname H-Frank-1 # Change this
```

### 4. Installing Nginx :

```bash
apt install -y nginx
systemctl enable nginx
service nginx status
```

Go to [http://{ip}:80] and check the page (Not HTTPS, HTTP !)

### 5. Generating Home Page :
```bash
cp -R ./03_nginx/root/var/www /var/
chmod +x /var/www/update_index.sh
/var/www/update_index.sh
```
If possible, go to [http://ip_of_the_vm:80] and check the page (Not HTTPS, HTTP !)


### 6. Installing Anaconda

```bash
apt install -y bzip2
export tempdir='/tmp'
```

- Go to https://repo.anaconda.com/archive and copy link of most recent installer.
- Note : the default installation path is `/root/anaconda3`, but you cannot use a non-root-service if we choose this. On internet, `/opt/anaconda3` is very popular, so keeping this instead.

```bash
url="https://repo.anaconda.com/archive/Anaconda3-2025.06-1-Linux-x86_64.sh" # Please update that 
wget $url -O $tempdir/Anaconda.sh
bash $tempdir/Anaconda.sh -b -p /opt/anaconda3 # Agreeing with License, installing to /opt/anaconda3
rm $tempdir/Anaconda.sh # To be clean (and the installer is big !)
```

Group for permissions :
```bash
groupadd anaconda_users
chown -R root:anaconda_users /opt/anaconda3
# Adding users to the group :
usermod -aG anaconda_users enrices
```

### 7. Configuring Jupyterlab :
```bash
cp ./04_jupyter/root/opt/anaconda3/etc/jupyter/jupyter_lab_config.py /opt/anaconda3/etc/jupyter/
```

### 8 Test JupyterLab directly (without reverse proxy)
For example, using port 80 :
```bash
service nginx stop

# Then :
/opt/anaconda3/bin/jupyter lab --config=/opt/anaconda3/etc/jupyter/jupyter_lab_config.py --no-browser --port=80

# Go to the webpage of the server (HTTP, TCP 80) and check on /jupyter/
# For example http://18.138.212.239/jupyter/
```

### 9 Setup Nginx reverse-proxy for JupyterLab

```bash
# Adding "include /etc/nginx/location.d/*.conf" inside "sites-available/default"
sed -i $'/listen \\[::\\]:80 default_server;/a\\\n\\\n\\\tinclude /etc/nginx/location.d/*.conf;' /etc/nginx/sites-available/default

cp ./04_jupyter/root/etc/nginx/conf.d/websocket_map.conf /etc/nginx/conf.d/
mkdir -p /etc/nginx/location.d/
cp ./04_jupyter/root/etc/nginx/location.d/jupyter.conf /etc/nginx/location.d/

nginx -t # to test configuration
service nginx restart
service nginx status
```

### 10. Testing JupyterLab with Proxy :
`/opt/anaconda3/bin/jupyter lab --config=/opt/anaconda3/etc/jupyter/jupyter_lab_config.py --no-browser`
Then :
- go to {ip}
- Then go to {ip}/jupyter/ 


### 11. Adding logo link on home page :

```bash
mkdir -p /var/www/html/html_links/
cp ./04_jupyter/root/var/www/html/html_links/jupyter.html /var/www/html/html_links/
mkdir -p /var/www/html/res/logos
cp ./04_jupyter/root/var/www/html/res/logos/jupyter.png /var/www/html/res/logos/
/var/www/update_index.sh
```


### 12. Setting up Jupyterhub/JupyterLab service :

```bash
appname="jupyterlab"
cp ./04_jupyter/root/etc/systemd/system/$appname.service /etc/systemd/system/
service $appname start
service $appname status
systemctl enable $appname.service # to start on boot
```

### 13. Configure git & JupyterLab-git extension

```bash
git config --global pull.rebase false
git config --global user.name "Jean Lescut-Muller"
git config --global user.email "jean.lescut@gmail.com"

exit # go back to your non-privileged account

# Configure GIT :
git config --global pull.rebase false
git config --global user.name "Jean Lescut-Muller"
git config --global user.email "jean.lescut@gmail.com"

# Install Jupyterlab GIT Extension
sudo /opt/anaconda3/bin/pip install --upgrade jupyterlab jupyterlab-git
sudo chown -R root:anaconda_users /opt/anaconda3/ # 2025-08: I am assuming owner group changed for some folders. This command normally takes a bit of time.
sudo reboot
```

### 14. Change color and Server-label Jupyterlab :

```bash
sudo su
cd ~/DataScience_stack_server/
path='/opt/anaconda3/share/jupyter/lab/themes/@jupyterlab/theme-dark-extension/index.css'
server_name=$(hostname)
color_text='#b8b8ff'  # Light Purple
color_border='#7b3dd2' # Purple

# Making a backup
cp $path "$path.backup"
# Replacing "layout-color3" by our value "$color_border"
sed -i "/--jp-layout-color3:/c\  --jp-layout-color3: $color_border;" $path
# Exporting variables so we can use envsubst below (into a temp file)
export server_name color_text
envsubst < 04_jupyter/server_label.css.template > $tempdir/server_label.css
# Adding the content of the temp file in the css
sed -i $'/:root/{e cat $tempdir/server_label.css\n}' $path 
```

### 15. Dark theme for Jupyterlab :
I actually just changed it in the GUI...

### 16. Security hardening (2026-10-09)

Jupyter and nginx removed; SSH keys only; firewall. See `09_security/` and the README section "Security hardening". Steps 1, 4-12 above describe the original setup and are superseded on this VM: `PermitRootLogin`/`PasswordAuthentication` are now `no` (except Hostinger's browser terminal), and nothing listens on port 80 or 8000.

| Public port | Now |
|---|---|
| TCP 443 | SSH, keys only (`HFrank1-from-MacbookPro`, `HFrank1-backup`; `HFrank1-from-GCP-mho`, rsync-only, removed 2026-10-10 with multi-host-orchestrator: GCP reaches the VM through GitHub only) |
| UDP 41641 | Tailscale |
| anything else | blocked (`/etc/nftables.conf`, table `inet vm_firewall`) |
