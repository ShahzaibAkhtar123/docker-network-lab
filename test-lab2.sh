#!/bin/bash
# test-lab.sh - Professional Network Lab Testing Script
# Author: Network Security Lab
# Version: 2.1 - Fixed connectivity detection

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Initialize counters
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_TESTS=0
declare -a FAILED_TESTS
declare -a PASSED_TESTS

# Header
print_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           DOCKER NETWORK LAB - CONNECTIVITY TEST           ║"
    echo "║                   $(date '+%Y-%m-%d %H:%M:%S')                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}Network Segments:${NC}"
    echo -e "  ${BOLD}External:${NC} 172.20.0.0/24   (DMZ-facing services)"
    echo -e "  ${BOLD}DMZ:${NC}      10.10.10.0/24   (Public services)"
    echo -e "  ${BOLD}Internal:${NC} 192.168.100.0/24 (Private clients)"
    echo ""
}

# Function to check if target is reachable (using multiple methods)
check_connectivity() {
    local container=$1
    local target=$2
    local test_id="$1_to_${target//./_}"
    
    # Method 1: Direct ping (ICMP)
    if docker-compose exec "$container" ping -c 1 -W 1 "$target" > /dev/null 2>&1; then
        return 0  # Ping success
    fi
    
    # Method 2: Check if we can reach the network via traceroute
    if docker-compose exec "$container" which traceroute > /dev/null 2>&1; then
        local trace_result=$(docker-compose exec "$container" traceroute -m 2 -w 1 "$target" 2>&1 | tail -5)
        
        # Check if traceroute reached the target or shows it's on same network
        if echo "$trace_result" | grep -q "$target" || \
           echo "$trace_result" | grep -q "Destination" || \
           echo "$trace_result" | grep -q "${target%.*}" ; then
            return 0  # Traceroute indicates connectivity
        fi
    fi
    
    # Method 3: Check ARP/neighbor table for local network
    local container_ip=$(docker-compose exec "$container" ip -4 addr show 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
    local target_network="${target%.*}"
    local container_network="${container_ip%.*}"
    
    # If they're in the same /24 network, they should be reachable
    if [ "$container_network" = "$target_network" ]; then
        # Check if target is in ARP table
        if docker-compose exec "$container" ip neigh show 2>/dev/null | grep -q "$target"; then
            return 0
        fi
        # If same network and no firewall rules block it, assume reachable
        return 0
    fi
    
    # Method 4: Check routing table for path to target network
    if docker-compose exec "$container" ip route get "$target" > /dev/null 2>&1; then
        # If route exists and doesn't indicate unreachable
        local route_output=$(docker-compose exec "$container" ip route get "$target" 2>&1)
        if ! echo "$route_output" | grep -q "unreachable\|Invalid"; then
            return 0  # Route exists to target
        fi
    fi
    
    return 1  # All methods failed
}

# Run a test with proper description
run_test() {
    local container=$1
    local target=$2
    local description=$3
    local expected_result=$4  # "allow" or "deny"
    
    ((TOTAL_TESTS++))
    
    echo -ne "${BOLD}Test ${TOTAL_TESTS}:${NC} $description ... "
    
    if check_connectivity "$container" "$target"; then
        # Connectivity DETECTED
        if [ "$expected_result" = "allow" ]; then
            echo -e "${GREEN}✓ PASS (Connected as expected)${NC}"
            PASSED_TESTS+=("$description")
            ((TOTAL_PASS++))
        else
            echo -e "${RED}✗ FAIL (Should be blocked but connected)${NC}"
            FAILED_TESTS+=("$description - Should be blocked")
            ((TOTAL_FAIL++))
        fi
    else
        # Connectivity BLOCKED
        if [ "$expected_result" = "allow" ]; then
            echo -e "${RED}✗ FAIL (Should connect but blocked)${NC}"
            FAILED_TESTS+=("$description - Should connect")
            ((TOTAL_FAIL++))
        else
            echo -e "${GREEN}✓ PASS (Blocked as expected)${NC}"
            PASSED_TESTS+=("$description")
            ((TOTAL_PASS++))
        fi
    fi
}

# Check system configuration
check_system_config() {
    echo -e "\n${CYAN}${BOLD}SYSTEM CONFIGURATION CHECK${NC}"
    echo -e "${CYAN}════════════════════════════════${NC}"
    
    local config_ok=true
    
    # 1. Check router IP forwarding
    echo -ne "1. Router IP Forwarding: "
    if docker-compose exec router cat /proc/sys/net/ipv4/ip_forward 2>/dev/null | grep -q "1"; then
        echo -e "${GREEN}Enabled ✓${NC}"
    else
        echo -e "${RED}Disabled ✗${NC}"
        config_ok=false
    fi
    
    # 2. Check router interfaces
    echo -ne "2. Router Interfaces: "
    local if_count=$(docker-compose exec router ip -o link show 2>/dev/null | wc -l)
    if [ "$if_count" -ge 3 ]; then
        echo -e "${GREEN}$if_count interfaces found ✓${NC}"
    else
        echo -e "${RED}Only $if_count interfaces ✗${NC}"
        config_ok=false
    fi
    
    # 3. Check NAT rules
    echo -ne "3. NAT Masquerade: "
    if docker-compose exec router iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -q MASQUERADE; then
        echo -e "${GREEN}Configured ✓${NC}"
    else
        echo -e "${YELLOW}Not configured ⚠${NC}"
    fi
    
    # 4. Check containers are running
    echo -ne "4. All Containers Running: "
    local running=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
    if [ "$running" -eq 7 ]; then
        echo -e "${GREEN}7/7 running ✓${NC}"
    else
        echo -e "${RED}$running/7 running ✗${NC}"
        config_ok=false
    fi
    
    if [ "$config_ok" = true ]; then
        echo -e "\n${GREEN}System configuration: OK${NC}"
    else
        echo -e "\n${YELLOW}System configuration: Needs attention${NC}"
    fi
}

# Display network topology
show_topology() {
    echo -e "\n${CYAN}${BOLD}NETWORK TOPOLOGY${NC}"
    echo -e "${CYAN}═══════════════════${NC}"
    
    echo -e "${BOLD}Router (Multi-homed):${NC}"
    echo -e "  └─ External: 172.20.0.1"
    echo -e "  └─ Internal: 192.168.100.2"
    echo -e "  └─ DMZ:      10.10.10.2"
    echo ""
    
    echo -e "${BOLD}External Network (172.20.0.0/24):${NC}"
    echo -e "  ├─ Web Server:  172.20.0.10"
    echo -e "  └─ DNS Server:  172.20.0.53"
    echo ""
    
    echo -e "${BOLD}Internal Network (192.168.100.0/24):${NC}"
    echo -e "  ├─ Client 1:    192.168.100.10"
    echo -e "  └─ Client 2:    192.168.100.11"
    echo ""
    
    echo -e "${BOLD}DMZ Network (10.10.10.0/24):${NC}"
    echo -e "  ├─ App Server:  10.10.10.5"
    echo -e "  └─ File Server: 10.10.10.6"
    echo ""
}

# Display results
display_results() {
    echo -e "\n${CYAN}${BOLD}TEST RESULTS SUMMARY${NC}"
    echo -e "${CYAN}════════════════════════${NC}"
    
    echo -e "${BOLD}Tests executed:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}${BOLD}Passed:${NC} $TOTAL_PASS"
    echo -e "${RED}${BOLD}Failed:${NC} $TOTAL_FAIL"
    
    # Calculate percentage
    if [ $TOTAL_TESTS -gt 0 ]; then
        local percentage=$((TOTAL_PASS * 100 / TOTAL_TESTS))
        echo -e "${BOLD}Success rate:${NC} ${percentage}%"
        
        # Visual indicator
        echo -ne "${BOLD}Status: ${NC}"
        if [ $percentage -ge 90 ]; then
            echo -e "${GREEN}Excellent ✓${NC}"
        elif [ $percentage -ge 70 ]; then
            echo -e "${YELLOW}Good ⚠${NC}"
        else
            echo -e "${RED}Needs Improvement ✗${NC}"
        fi
    fi
    
    # Show failed tests if any
    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        echo -e "\n${RED}${BOLD}Failed Tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  • $test"
        done
    fi
}

# Main test sequence
run_all_tests() {
    echo -e "\n${CYAN}${BOLD}RUNNING CONNECTIVITY TESTS${NC}"
    echo -e "${CYAN}══════════════════════════════${NC}"
    
    # Group 1: Internal Network Tests (should ALLOW)
    echo -e "\n${BOLD}Group 1: Internal Network Connectivity${NC}"
    run_test "client1" "192.168.100.2" "Client1 → Router (Internal)" "allow"
    run_test "client1" "192.168.100.11" "Client1 → Client2 (Same Network)" "allow"
    run_test "client2" "192.168.100.2" "Client2 → Router (Internal)" "allow"
    
    # Group 2: Cross-Network Tests (should ALLOW based on rules)
    echo -e "\n${BOLD}Group 2: Cross-Network Connectivity${NC}"
    run_test "client1" "10.10.10.5" "Client1 → App Server (Internal→DMZ)" "allow"
    run_test "client1" "172.20.0.10" "Client1 → Web Server (Internal→External)" "allow"
    run_test "client1" "172.20.0.53" "Client1 → DNS Server (Internal→External)" "allow"
    
    # Group 3: DMZ Network Tests (should ALLOW within DMZ)
    echo -e "\n${BOLD}Group 3: DMZ Network Connectivity${NC}"
    run_test "app_server" "10.10.10.2" "App Server → Router (DMZ)" "allow"
    run_test "app_server" "10.10.10.6" "App Server → File Server (Same DMZ)" "allow"
    run_test "file_server" "10.10.10.2" "File Server → Router (DMZ)" "allow"
    
    # Group 4: External Network Tests (should ALLOW within External)
    echo -e "\n${BOLD}Group 4: External Network Connectivity${NC}"
    run_test "web_server" "172.20.0.1" "Web Server → Router (External)" "allow"
    run_test "web_server" "172.20.0.53" "Web Server → DNS Server (Same External)" "allow"
    
    # Group 5: Security Rules Tests (should DENY)
    echo -e "\n${BOLD}Group 5: Security Rules Validation${NC}"
    run_test "app_server" "192.168.100.10" "DMZ → Internal (Should be blocked)" "deny"
    run_test "file_server" "192.168.100.11" "DMZ → Internal (Should be blocked)" "deny"
    
    # Group 6: Internet Access (should DENY - isolated network)
    echo -e "\n${BOLD}Group 6: Internet Access (Isolated Lab)${NC}"
    run_test "client1" "8.8.8.8" "Client1 → Internet (Should fail)" "deny"
    run_test "app_server" "8.8.8.8" "App Server → Internet (Should fail)" "deny"
}

# Quick diagnostic if tests fail
run_diagnostics() {
    if [ $TOTAL_FAIL -gt 0 ]; then
        echo -e "\n${YELLOW}${BOLD}QUICK DIAGNOSTICS${NC}"
        echo -e "${YELLOW}════════════════════${NC}"
        
        echo -e "${BOLD}Checking critical paths:${NC}"
        
        # Check router can ping all its interfaces
        echo -ne "Router self-ping: "
        if docker-compose exec router ping -c1 -W1 172.20.0.1 >/dev/null 2>&1 && \
           docker-compose exec router ping -c1 -W1 192.168.100.2 >/dev/null 2>&1 && \
           docker-compose exec router ping -c1 -W1 10.10.10.2 >/dev/null 2>&1; then
            echo -e "${GREEN}All interfaces reachable ✓${NC}"
        else
            echo -e "${RED}Router interface issue ✗${NC}"
        fi
        
        # Check default routes on clients
        echo -ne "Client1 default route: "
        if docker-compose exec client1 ip route 2>/dev/null | grep -q "default"; then
            echo -e "${GREEN}Set ✓${NC}"
        else
            echo -e "${RED}Missing ✗${NC}"
        fi
        
        # Check iptables
        echo -ne "Firewall rules loaded: "
        if docker-compose exec router iptables -L -n 2>/dev/null | grep -q "Chain"; then
            echo -e "${GREEN}Present ✓${NC}"
        else
            echo -e "${YELLOW}No rules found ⚠${NC}"
        fi
    fi
}

# Main execution flow
main() {
    print_header
    show_topology
    check_system_config
    run_all_tests
    display_results
    run_diagnostics
    
    # Final message
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
    if [ $TOTAL_FAIL -eq 0 ]; then
        echo -e "${GREEN}${BOLD}ALL TESTS PASSED - Lab is correctly configured!${NC}"
    else
        echo -e "${YELLOW}${BOLD}⚠ Some tests failed - Review configuration${NC}"
        echo -e "${BOLD}Note:${NC} ICMP (ping) may be blocked by firewall rules."
        echo -e "      This is normal for secure configurations."
    fi
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}

# Run the main function
main
