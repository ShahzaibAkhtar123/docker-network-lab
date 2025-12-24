#!/bin/bash
# test-lab.sh - Connectivity testing script

echo "========================================="
echo "   Docker Network Lab - Connectivity Test"
echo "========================================="
echo ""

# Function to test connectivity
test_connectivity() {
    local container=$1
    local target=$2
    local description=$3
    
    echo -n "$description: "
    if docker-compose exec "$container" ping -c 1 -W 1 "$target" > /dev/null 2>&1; then
        echo "✓ PASS"
        return 0
    else
        echo "✗ FAIL"
        return 1
    fi
}

# Run tests
echo "Running connectivity tests..."
echo ""

tests=(
    "client1 192.168.100.2 'Client1 → Router (internal)'"
    "client1 192.168.100.11 'Client1 → Client2 (same network)'"
    "client1 10.10.10.5 'Client1 → App Server (cross-network)'"
    "client1 172.20.0.10 'Client1 → Web Server (cross-network)'"
    "client1 8.8.8.8 'Client1 → Internet (NAT test)'"
    "app_server 10.10.10.2 'App Server → Router (DMZ)'"
    "app_server 8.8.8.8 'App Server → Internet (NAT test)'"
    "web_server 172.20.0.1 'Web Server → Router (external)'"
)

passed=0
failed=0

for test in "${tests[@]}"; do
    if test_connectivity $test; then
        ((passed++))
    else
        ((failed++))
    fi
done

echo ""
echo "Test Results: $passed passed, $failed failed"
echo ""

# Additional checks
echo "Additional Checks:"
echo "-----------------"
echo -n "Router IP Forwarding: "
if docker-compose exec router cat /proc/sys/net/ipv4/ip_forward | grep -q 1; then
    echo "✓ Enabled"
else
    echo "✗ Disabled"
fi

echo -n "Router NAT Configuration: "
if docker-compose exec router iptables -t nat -L POSTROUTING -n -v | grep -q MASQUERADE; then
    echo "✓ Configured"
else
    echo "✗ Missing"
fi

echo ""
if [ $failed -eq 0 ]; then
    echo "All tests passed! Lab is fully operational."
else
    echo "Some tests failed. Check network configuration."
fi
echo ""
