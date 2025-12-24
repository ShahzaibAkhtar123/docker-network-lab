#!/bin/bash
# reset-lab.sh - Complete lab reset

echo "========================================="
echo "   Docker Network Lab - Complete Reset"
echo "========================================="
echo ""

echo "This will remove ALL lab containers and networks."
read -p "Are you sure? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Stopping and removing containers..."
    docker-compose down
    
    echo "Removing Docker networks..."
    docker network rm docker-network-lab_ext_net \
                       docker-network-lab_int_net \
                       docker-network-lab_dmz_net 2>/dev/null || true
    
    echo "Cleaning up..."
    docker system prune -f
    
    echo ""
    echo "Lab has been completely reset."
    echo "Run './setup-lab.sh' to start fresh."
else
    echo "Reset cancelled."
fi
