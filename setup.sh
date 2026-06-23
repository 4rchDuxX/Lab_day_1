#!/bin/bash
set -e

echo "[1/3] Instaluji system balicky..."
sudo apt-get update -q
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q nmap tshark curl wget

echo "[2/3] Instaluji TruffleHog..."
curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sudo sh -s -- -b /usr/local/bin

echo "[3/3] Stahuji pcap soubor..."
wget -q https://wiki.wireshark.org/uploads/27707187aeb30df68e70c8fb9d614981/http.cap -O lab_02_network/http.cap

echo "HOTOVO!"
