#!/bin/bash
# lab-info.sh - Display Docker Lab network info
# Author: Your Name
# Usage: ./lab-info.sh

echo "============================================"
echo " Docker Network Lab - Container Network Info"
echo "============================================"
echo ""

# List of all containers
containers=(router client1 client2 app_server file_server web_server dns_server)

for c in "${containers[@]}"; do
    echo "----------------------------------------"
    echo "Container: $c"
    echo "----------------------------------------"
    
    # Print container IP addresses
    echo "IP Addresses:"
    docker-compose exec $c sh -c "ip -4 addr show | grep inet | awk '{print \$2}'" 2>/dev/null
    
    # Print network interfaces
    echo "Network Interfaces:"
    docker-compose exec $c sh -c "ip link show | awk '{print \$2}' | tr -d ':'" 2>/dev/null
    
    # Print routing table
    echo "Routing Table:"
    docker-compose exec $c sh -c "ip route show" 2>/dev/null
    
    echo ""
done

echo "============================================"
echo "Docker Lab Network Info Complete"
echo "============================================"
