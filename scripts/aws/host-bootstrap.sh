#!/usr/bin/env bash
# EC2 user data for the Feedwatch host (Amazon Linux 2023, arm64). Installs Docker and Compose, adds
# swap, clones this repo, and runs deploy.sh. Access is through SSM Session Manager only.
set -euxo pipefail
dnf install -y docker git
systemctl enable --now docker
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL https://github.com/docker/compose/releases/download/v2.40.3/docker-compose-linux-aarch64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap defaults 0 0' >> /etc/fstab
fi
mkdir -p /opt/feedwatch
[ -d /opt/feedwatch/platform ] || git clone --quiet https://github.com/ayenisholah/feedwatch-platform /opt/feedwatch/platform
bash /opt/feedwatch/platform/scripts/aws/deploy.sh
