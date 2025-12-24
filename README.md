# Docker Network Security Lab

## PROJECT OVERVIEW
A Docker-based network security lab that simulates enterprise network architecture with three security zones: External, DMZ, and Internal networks. Perfect for learning firewall configurations, network segmentation, and security best practices.

## QUICK START

### PREREQUISITES
- Docker Engine installed
- Docker Compose installed
- Linux/macOS/WSL2 environment

### INSTALLATION COMMANDS
# Clone and enter directory
git clone https://github.com/yourusername/docker-network-lab.git
cd docker-network-lab

# Make scripts executable
chmod +x *.sh

# Setup the lab (takes 2-3 minutes)
./setup-lab.sh

# Test connectivity
./test-lab.sh

# Or run advanced tests
./test-lab2.sh

## BASIC COMMANDS
### START/STOP LAB
# Start all containers
docker-compose up -d

# Stop all containers
docker-compose down

# Restart specific container
docker-compose restart router

# View container logs
docker-compose logs -f router

### TESTING COMMANDS

# Basic connectivity test
./test-lab.sh

# Advanced test with diagnostics
./test-lab2.sh

# Quick lab info
./lab-info.sh

# Reset everything (WARNING: deletes all)
./reset-lab.sh


### TROUBLESHOOTING COMMANDS
\`\`\`bash
# Check router configuration
docker-compose exec router iptables -L -n -v
docker-compose exec router ip route show
docker-compose exec router cat /proc/sys/net/ipv4/ip_forward

# Test connectivity manually
docker-compose exec client1 ping 192.168.100.2
docker-compose exec app_server ping 10.10.10.2

# Check container status
docker-compose ps
docker-compose logs router

## NETWORK ARCHITECTURE

### IP ADDRESSES

EXTERNAL NETWORK (172.20.0.0/24)
├── Router:      172.20.0.1
├── Web Server:  172.20.0.10
└── DNS Server:  172.20.0.53

DMZ NETWORK (10.10.10.0/24)
├── Router:      10.10.10.2
├── App Server:  10.10.10.5
└── File Server: 10.10.10.6

INTERNAL NETWORK (192.168.100.0/24)
├── Router:      192.168.100.2
├── Client 1:    192.168.100.10
└── Client 2:    192.168.100.11

### SECURITY RULES
ALLOWED TRAFFIC:
├── Internal → DMZ → External
├── External → DMZ (ports 80, 443, 22 only)
└── All internal network communication

BLOCKED TRAFFIC:
├── DMZ → Internal (security policy)
└── External → Internal (direct)

NAT CONFIGURATION:
├── Internal → External: MASQUERADE
└── DMZ → External: MASQUERADE

## FILE DESCRIPTIONS

### docker-compose.yml
Defines three isolated networks and seven containers. Sets up static IPs, network interfaces, and container configurations. Uses Ubuntu for router and Alpine for lightweight clients.

### setup-lab.sh
Automated setup script. Creates config files, pulls images, starts containers, configures router interfaces, applies firewall rules, sets up client routing and DNS.

### test-lab.sh
Basic connectivity tester. Pings between all network segments, validates firewall rules, checks NAT configuration, provides clear pass/fail results.

### test-lab2.sh
Advanced professional tester. Uses multiple detection methods (ping, traceroute, routing), color-coded output, system validation, diagnostics, topology visualization.

### reset-lab.sh
Complete lab cleanup. Stops/removes containers, deletes networks, prunes Docker system. Has interactive confirmation to prevent accidental deletion.

### lab-info.sh
Quick status display. Shows running containers, IP addresses, network assignments, container status and resource usage.

### config/router/iptables-rules.v4
Firewall configuration. Defines traffic rules between networks, implements security policies, configures NAT, controls allowed ports.

### config/router/sysctl.conf
Kernel parameters. Enables IP forwarding on router, configures network settings essential for packet forwarding between networks.

## LEARNING EXERCISES

### EXERCISE 1: BASIC CONNECTIVITY

./test-lab.sh
docker-compose exec router iptables -L -n -v
docker-compose exec client1 ip route


### EXERCISE 2: MODIFY FIREWALL
1. Edit config/router/iptables-rules.v4
2. Allow DMZ to ping Internal
3. Apply: docker-compose exec router iptables-restore < /etc/iptables/rules.v4
4. Test: docker-compose exec app_server ping 192.168.100.10

### EXERCISE 3: ADD NEW SERVICE
1. Add service to docker-compose.yml
2. Place in appropriate network zone
3. Test connectivity
4. Adjust firewall as needed

### EXERCISE 4: TRAFFIC MONITORING
docker-compose exec router tcpdump -i any -n
docker-compose exec router conntrack -L


## TROUBLESHOOTING

### COMMON ISSUES & SOLUTIONS

1. CONTAINERS NOT STARTING:
docker-compose logs router
docker system prune -f
./reset-lab.sh && ./setup-lab.sh
2. CONNECTIVITY PROBLEMS:
# Check forwarding
docker-compose exec router cat /proc/sys/net/ipv4/ip_forward

# Verify firewall
docker-compose exec router iptables -L FORWARD -n -v

# Check routes
docker-compose exec client1 ip route

3. PERMISSION ERRORS:

chmod +x *.sh
sudo usermod -aG docker $USER


## LEARNING OUTCOMES

After this lab, you will be able to:
- Configure multi-homed routers in Docker
- Implement enterprise firewall rules
- Understand network segmentation
- Troubleshoot network issues
- Design secure architectures
- Use Docker for network simulation

## PROJECT SCOPE

### EDUCATIONAL TOOL
Provides hands-on networking experience for students and professionals in a safe, containerized environment.

### TARGET AUDIENCE
- Students (CS, networking, cybersecurity)
- IT professionals transitioning roles
- DevOps engineers
- Cybersecurity enthusiasts

### TECHNICAL COVERAGE
- Container networking (Docker bridge)
- Firewall configuration (iptables)
- Network segmentation (3-tier)
- Routing & NAT
- Automated testing

## DEVELOPER

**Shahzaib Akhtar**
Network Security Enthusiast & Developer

- Primary developer and architect
- Designed entire lab structure
- Implemented firewall rules and testing framework
- Created comprehensive documentation

## CREDITS & ACKNOWLEDGMENTS

### TECHNOLOGY
- Docker Community for container platform
- Linux Foundation for networking tools
- Alpine Linux for lightweight images
- Ubuntu for router base

### EDUCATIONAL RESOURCES
- Network security course materials
- Online cybersecurity communities
- Open source networking projects

### INSPIRATION
- University networking labs
- Professional certifications (CCNA, Security+)
- Real-world security challenges

## ADDITIONAL RESOURCES

- Docker Networking: docs.docker.com/network/
- iptables Tutorial: www.netfilter.org/documentation/
- Linux Networking Commands: www.tecmint.com/linux-network-commands/

## CONTRIBUTING

1. Fork repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Open Pull Request

## LICENSE

MIT License - Open source and free to use, modify, distribute.

## SUPPORT

If helpful, please:
- Star on GitHub
- Share with others
- Report issues
- Suggest improvements
- Contribute code/docs

---

**Happy Learning!** 🚀

*"The only way to learn networking is to do networking."* - Network Engineers'

**Version:** 1.0  
**Last Updated:** December 2025  
**Status:** Actively Maintained  
**Author:** Shahzaib Akhtar

