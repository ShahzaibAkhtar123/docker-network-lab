#!/bin/bash
# setup-lab.sh - Full Docker Network Lab Setup
# Author: Shahzaib Akhtar

echo "========================================="
echo "   Docker Network Lab Setup"
echo "========================================="
echo ""

# Check docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo "ERROR: docker-compose is not installed!"
    echo "Install it with: sudo apt-get install docker-compose"
    exit 1
fi

# Create directories
mkdir -p config/router config/clients

# Create sysctl.conf if missing
if [ ! -f config/router/sysctl.conf ]; then
    cat > config/router/sysctl.conf << 'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
fi

# Create iptables rules if missing
if [ ! -f config/router/iptables-rules.v4 ]; then
    cat > config/router/iptables-rules.v4 << 'EOF'
*filter
:INPUT ACCEPT [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Drop DMZ → Internal
-A FORWARD -i eth0 -o eth2 -j DROP

# Allow established
-A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Internal → External
-A FORWARD -i eth2 -o eth1 -j ACCEPT

# DMZ → External
-A FORWARD -i eth0 -o eth1 -j ACCEPT

# External → DMZ limited
-A FORWARD -i eth1 -o eth0 -p tcp --dport 80 -j ACCEPT
-A FORWARD -i eth1 -o eth0 -p tcp --dport 443 -j ACCEPT
-A FORWARD -i eth1 -o eth0 -p tcp --dport 22 -j ACCEPT
COMMIT

*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]

# NAT Internal & DMZ → External
-A POSTROUTING -s 192.168.100.0/24 -o eth1 -j MASQUERADE
-A POSTROUTING -s 10.10.10.0/24 -o eth1 -j MASQUERADE
COMMIT
EOF
fi

# Pull images
echo "Pulling Docker images..."
docker-compose pull

# Start containers
echo ""
echo "Starting lab..."
docker-compose up -d

# Wait for containers
sleep 5

# Check router packages
echo ""
echo "Checking router packages..."
docker-compose exec router sh -c "apt-get update -y && apt-get install -y iptables iproute2 iputils-ping > /dev/null 2>&1"

# Detect router interfaces and IPs
echo ""
echo "Detecting router interfaces and IPs..."
ROUTER_IFS=$(docker-compose exec router ip -o -4 addr show | awk '{print $2,$4}')
EXT_IF=$(echo "$ROUTER_IFS" | grep '172.20.0.' | awk '{print $1}')
INT_IF=$(echo "$ROUTER_IFS" | grep '192.168.100.' | awk '{print $1}')
DMZ_IF=$(echo "$ROUTER_IFS" | grep '10.10.10.' | awk '{print $1}')

EXT_IP=$(echo "$ROUTER_IFS" | grep '172.20.0.' | awk '{print $2}')
INT_IP=$(echo "$ROUTER_IFS" | grep '192.168.100.' | awk '{print $2}')
DMZ_IP=$(echo "$ROUTER_IFS" | grep '10.10.10.' | awk '{print $2}')

echo "Interface mapping:"
echo "External ($EXT_IP) → $EXT_IF"
echo "Internal ($INT_IP) → $INT_IF"
echo "DMZ      ($DMZ_IP) → $DMZ_IF"

# Apply iptables
echo ""
echo "Applying iptables rules..."
docker-compose exec router sh -c "iptables-restore < /etc/iptables/rules.v4 || echo 'ERROR: Failed to load iptables rules'"

# Configure clients
echo ""
echo "Configuring clients..."
for client in client1 client2 app_server file_server; do
    echo "  Setting up $client..."
    docker-compose exec $client sh -c "\
        apk add --no-cache iproute2 iputils > /dev/null 2>&1"

    # Set DNS
    docker-compose exec $client sh -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"

    # Set default route
    if [[ "$client" == client1 || "$client" == client2 ]]; then
        docker-compose exec $client sh -c "ip route del default 2>/dev/null || true"
        docker-compose exec $client sh -c "ip route add default via ${INT_IP%/*}"
    else
        docker-compose exec $client sh -c "ip route del default 2>/dev/null || true"
        docker-compose exec $client sh -c "ip route add default via ${DMZ_IP%/*}"
    fi
done

# Lab setup complete
echo ""
echo "========================================="
echo "   Lab Setup Complete!"
echo "========================================="
echo ""
docker-compose ps
echo ""
echo "Quick test: ./test-lab.sh"
echo "Manage lab: ./manage-lab.sh"
echo ""
