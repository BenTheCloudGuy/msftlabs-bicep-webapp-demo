#!/bin/bash
# GitHub Self-Hosted Runner Installation Script
# Runs on Ubuntu 22.04

set -e

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install required packages
sudo apt-get install -y \
    curl \
    wget \
    git \
    jq \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Bicep CLI
az bicep install

# Install Node.js 18 LTS
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Create runner user
sudo useradd -m -s /bin/bash runner
sudo usermod -aG docker runner

# Create runner directory
sudo mkdir -p /opt/actions-runner
sudo chown -R runner:runner /opt/actions-runner

# Download and extract GitHub Actions runner
cd /opt/actions-runner
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//')
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
sudo chown -R runner:runner /opt/actions-runner

# Note: The runner still needs to be configured with the repository URL and token
# This should be done separately using:
# sudo -u runner ./config.sh --url https://github.com/YOUR_ORG/YOUR_REPO --token YOUR_TOKEN
# sudo ./svc.sh install
# sudo ./svc.sh start

echo "GitHub Actions Runner base installation complete!"
echo "Configure the runner with your repository URL and token to finish setup."
