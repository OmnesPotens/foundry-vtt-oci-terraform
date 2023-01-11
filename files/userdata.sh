#!/bin/bash -x
### Log all user-data to multiple locations
exec > >(tee /var/log/userdata.log|logger -t user-data -s 2>/dev/console) 2>&1
export VISUAL=nano
export DEBIAN_FRONTEND=noninteractive
cat <<-'EOF' >> ~/.bashrc
export VISUAL=nano
export DEBIAN_FRONTEND=noninteractive
EOF

apt update -y
apt upgrade -y
apt-get update -y
apt-get upgrade -y
apt-get install -y nano jq unzip expect

iptables -I INPUT 6 -m state --state NEW -p tcp --match multiport --dports 80,443,30000,33478,49152:65535 -j ACCEPT
netfilter-persistent save

### install oci-cli
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -c --accept-all-defaults

cat <<-EOF >> ~/.bashrc
export OCI_CLI_AUTH=instance_principal
export CONFIG_BUCKET="${CONFIG_BUCKET}"
EOF
export OCI_CLI_AUTH=instance_principal
/root/bin/oci os ns get

### copy config bucket files to config dir
if [[ -z "${CONFIG_BUCKET}" ]]; then
  echo "CONFIG_BUCKET not set, skipping bulk-download."
else
  /root/bin/oci os object bulk-download -bn ${CONFIG_BUCKET} --dest-dir /home/ubuntu/foundry/ --overwrite --parallel-operations-count 1000
fi
chown -R ubuntu /home/ubuntu
