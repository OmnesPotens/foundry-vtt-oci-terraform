#!/bin/bash -x
exec > >(sudo tee /tmp/post-provisioning.log) 2>&1
mkdir -p ~/foundry/tools/.nvm

### Ensure we install nvm and pyenv under our Foundry dir so that the persistent volume maintains stores them
export NVM_DIR="$HOME/foundry/tools/.nvm"
export PYENV_ROOT="$HOME/foundry/tools/.pyenv"

### install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

### install pyenv deps
sudo apt-get install -y make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

### install pyenv
curl https://pyenv.run | bash

### use pyenv now and add to .bashrc for future shells
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
cat <<-'EOF' >>~/.bashrc
export PYENV_ROOT="$HOME/foundry/tools/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF

### Export useful env vars to the root user's .bashrc
### You can login as the root user to perform operations with the oci cli
sudo bash -c "cat <<-EOF >> /root/.bashrc
export AD=\"${AD}\"
export COMPARTMENT_ID=\"${COMPARTMENT_ID}\"
export INSTANCE_ID=\"${INSTANCE_ID}\"
export PUBLIC_IP=\"${PUBLIC_IP}\"
export DOMAIN=\"${DOMAIN}\"
EOF"
echo "export PUBLIC_IP=\"${PUBLIC_IP}\"" >>~/.bashrc
echo "export DOMAIN=\"${DOMAIN}\"" >>~/.bashrc
export DOMAIN="${DOMAIN}"
export INSTANCE_ID="${INSTANCE_ID}"

### install node and pm2
nvm install --lts node && nvm use --lts
npm install pm2 -g
pm2 --version && echo "pm2 installed successfully"
### Allow pm2 to start and stop Foundry when the instance restarts
pm2 startup
### Get the directory of the highest node version installed
latest_node=$(ls -v /home/ubuntu/foundry/tools/.nvm/versions/node/ | tail -n 1)
pm2_path="/home/ubuntu/foundry/tools/.nvm/versions/node/$${latest_node}/lib/node_modules/pm2/bin/pm2"
sudo env PATH=$PATH:/usr/bin $${pm2_path} startup systemd -u ubuntu --hp /home/ubuntu

mkdir -p ~/foundry/fvtt/
mkdir -p ~/foundry/src/
cd ~/foundry/ && echo "Moved to foundry dir"

pyenv install -f 3.10.6
pyenv virtualenv 3.10.6 foundry-py
### set the local pyenv and install needed libs for running get_latest_fvtt.py
pyenv local foundry-py
pip install requests-html

### Get latest FoundryVTT
if [ -z "${FOUNDRY_USERNAME}" ] && [ -z "${FOUNDRY_PASSWORD}" ]; then
  echo "Foundry credentials were not provided, skipping Foundry setup and exiting."
  exit 0
fi

rm ./FoundryVTT-*.zip
### Do NOT remove the extra space in front of this line, it will avoid storing the credentials in bash_history. This is a security precaution
 echo "${FOUNDRY_USERNAME} ${FOUNDRY_PASSWORD}" >.foundry_creds
python ./operations/get_latest_fvtt.py .foundry_creds && rm .foundry_creds
### Extract Foundry files into src/ dir
unzip -o ./FoundryVTT-*.zip -d ~/foundry/src/
rm ./FoundryVTT-*.zip

### Set Foundry to be managed by pm2 so that Foundry will always be running, even in the case where the instance has been restarted
pm2 start "node /home/ubuntu/foundry/src/resources/app/main.js --dataPath=/home/ubuntu/foundry/fvtt/" --name foundry
if pm2 list | grep "foundry" | grep -q "online"; then
  echo "pm2 is now managing Foundry"
fi

### Check if Foundry is up and running
curl -o /dev/null -Isw '%%{http_code}\n' "http://$${PUBLIC_IP}:30000" && pm2 save

### Install Caddy to use as a reverse proxy
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
sudo rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt-get install -y caddy

### Modify the Caddyfile to include a reverse proxy to Foundry
sudo bash -c "cat <<-EOF >/etc/caddy/Caddyfile
### This replaces the existing content in /etc/caddy/Caddyfile

### A CONFIG SECTION FOR YOUR DOMAIN
${DOMAIN} {
    @http {
      protocol http
    }
    redir @http https://${DOMAIN}
    # PROXY ALL REQUEST TO PORT 30000
    reverse_proxy localhost:30000
    encode zstd gzip
}

### Refer to the Caddy docs for more information:
### https://caddyserver.com/docs/caddyfile
EOF"
### Stop and restart Caddy to pick up the new settings
sudo service caddy stop
sudo service caddy restart

### Tell Foundry that we are running behind a reverse proxy by changing the options.json file
cd /home/ubuntu/foundry/fvtt/Config/ && echo "Moved into Foundry Config dir"
tmp=$(mktemp)
jq '(.proxySSL?) = true | (.proxyPort?) = 443' options.json >"$tmp" && mv "$tmp" options.json

### Check if Foundry is up and running via the supplied HOSTNAME on port 443
curl -o /dev/null -Isw '%%{http_code}\n' "https://${DOMAIN}:443" && pm2 save

### Reboot the instance
sudo bash -c "/root/bin/oci compute instance action --action RESET --instance-id ${INSTANCE_ID} --auth instance_principal"
