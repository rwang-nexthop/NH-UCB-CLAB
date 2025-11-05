# Nexthop.AI SONiC CLOS Lab - Quick Reference

**Built by Nexthop.AI** - Building the most efficient AI infrastructures

## 🚀 Deployment Commands

### Automated Deployment (Recommended)
```bash
cd scripts
./deploy_lab.sh
```

### Manual Deployment
```bash
# Deploy topology
cd topology
clab deploy -t nexthop-sonic-clos.clab.yml

# Configure BGP
cd ../scripts
./configure_bgp_docker.sh
```

### Cleanup
```bash
# Automated cleanup
cd scripts
./cleanup_lab.sh

# Manual cleanup
cd topology
clab destroy -t nexthop-sonic-clos.clab.yml --cleanup
```

## 🔍 Verification Commands

### Lab Status
```bash
cd topology
clab inspect -t nexthop-sonic-clos.clab.yml
```

### BGP Status
```bash
# Check BGP summary
docker exec clab-nexthop-sonic-clos-spine1 vtysh -c "show ip bgp summary"
docker exec clab-nexthop-sonic-clos-leaf1 vtysh -c "show ip bgp summary"

# Check BGP routes
docker exec clab-nexthop-sonic-clos-leaf1 vtysh -c "show ip bgp"

# Check routing table
docker exec clab-nexthop-sonic-clos-leaf1 vtysh -c "show ip route"

# Check BGP neighbors detail
docker exec clab-nexthop-sonic-clos-spine1 vtysh -c "show ip bgp neighbors"
```

### Interface Status
```bash
# SONiC show commands
docker exec clab-nexthop-sonic-clos-spine1 show ip interface brief
docker exec clab-nexthop-sonic-clos-spine1 show interfaces status

# Linux ip commands
docker exec clab-nexthop-sonic-clos-spine1 ip addr show
docker exec clab-nexthop-sonic-clos-spine1 ip link show
```

### Connectivity Tests
```bash
# Host to host
docker exec clab-nexthop-sonic-clos-host1 ping -c 5 192.168.2.10
docker exec clab-nexthop-sonic-clos-host2 ping -c 5 192.168.1.10

# Host to gateway
docker exec clab-nexthop-sonic-clos-host1 ping -c 3 192.168.1.1
docker exec clab-nexthop-sonic-clos-host2 ping -c 3 192.168.2.1

# Traceroute
docker exec clab-nexthop-sonic-clos-host1 traceroute 192.168.2.10

# Check host routes
docker exec clab-nexthop-sonic-clos-host1 ip route
docker exec clab-nexthop-sonic-clos-host2 ip route
```

## 📊 Traffic Monitoring

### Packet Capture
```bash
# Capture on leaf-to-host interface
docker exec clab-nexthop-sonic-clos-leaf1 tcpdump -i Ethernet8 -n
docker exec clab-nexthop-sonic-clos-leaf2 tcpdump -i Ethernet8 -n

# Capture only ICMP
docker exec clab-nexthop-sonic-clos-leaf1 tcpdump -i Ethernet8 -n icmp

# Capture on spine-to-leaf interface
docker exec clab-nexthop-sonic-clos-spine1 tcpdump -i Ethernet0 -n

# Capture with packet details
docker exec clab-nexthop-sonic-clos-leaf2 tcpdump -i Ethernet8 -n -v

# Capture specific number of packets
docker exec clab-nexthop-sonic-clos-leaf2 tcpdump -i Ethernet8 -n -c 20

# Filter by host
docker exec clab-nexthop-sonic-clos-leaf2 tcpdump -i Ethernet8 -n host 192.168.2.10

# See full packet contents
docker exec clab-nexthop-sonic-clos-leaf2 tcpdump -i Ethernet8 -n -X
```

### Generate Traffic
```bash
# Continuous ping
docker exec clab-nexthop-sonic-clos-host1 ping 192.168.2.10

# Limited ping
docker exec clab-nexthop-sonic-clos-host1 ping -c 100 192.168.2.10

# Ping with interval
docker exec clab-nexthop-sonic-clos-host1 ping -i 0.2 192.168.2.10
```

## 🔧 Configuration Commands

### Access SONiC Shell
```bash
# Interactive bash
docker exec -it clab-nexthop-sonic-clos-spine1 bash

# Interactive vtysh (FRR)
docker exec -it clab-nexthop-sonic-clos-spine1 vtysh
```

### BGP Configuration (Manual)
```bash
# Enter vtysh and configure
docker exec -it clab-nexthop-sonic-clos-spine1 vtysh

# Inside vtysh:
configure terminal
router bgp 65000
  bgp router-id 1.1.1.1
  neighbor 10.0.1.1 remote-as 65101
  address-family ipv4 unicast
    redistribute connected
  exit-address-family
exit
write memory
```

### Interface Configuration (Manual)
```bash
# Configure interface
docker exec clab-nexthop-sonic-clos-spine1 config interface ip add Ethernet0 10.0.1.0/31

# Configure loopback
docker exec clab-nexthop-sonic-clos-spine1 config loopback add Loopback0
docker exec clab-nexthop-sonic-clos-spine1 config interface ip add Loopback0 1.1.1.1/32

# Bring interface up
docker exec clab-nexthop-sonic-clos-spine1 config interface startup Ethernet0
```

### FRR Service Management
```bash
# Check FRR status
docker exec clab-nexthop-sonic-clos-spine1 service frr status

# Restart FRR
docker exec clab-nexthop-sonic-clos-spine1 service frr restart

# Enable BGP daemon
docker exec clab-nexthop-sonic-clos-spine1 sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
docker exec clab-nexthop-sonic-clos-spine1 service frr restart
```

## 🐛 Troubleshooting Commands

### Fix Host Routes
```bash
# Remove mgmt network default route
docker exec clab-nexthop-sonic-clos-host1 ip route del default via 172.20.20.1 dev eth0

# Add data network default route
docker exec clab-nexthop-sonic-clos-host1 ip route add default via 192.168.1.1 dev eth1
```

### Bring Up Interfaces
```bash
# Bring up containerlab eth interfaces
docker exec clab-nexthop-sonic-clos-spine1 ip link set eth1 up
docker exec clab-nexthop-sonic-clos-spine1 ip link set eth2 up

# Check interface status
docker exec clab-nexthop-sonic-clos-spine1 ip link show
```

### Check Logs
```bash
# Container logs
docker logs clab-nexthop-sonic-clos-spine1

# FRR logs
docker exec clab-nexthop-sonic-clos-spine1 cat /var/log/frr/bgpd.log
docker exec clab-nexthop-sonic-clos-spine1 cat /var/log/frr/zebra.log

# System logs
docker exec clab-nexthop-sonic-clos-spine1 tail -f /var/log/syslog
```

### Reset Configuration
```bash
# Re-run configuration script
cd scripts
./configure_bgp_docker.sh

# Or redeploy everything
./cleanup_lab.sh
./deploy_lab.sh
```

## 📋 Container Names

- **Spines:** `clab-nexthop-sonic-clos-spine1`, `clab-nexthop-sonic-clos-spine2`
- **Leaves:** `clab-nexthop-sonic-clos-leaf1`, `clab-nexthop-sonic-clos-leaf2`
- **Hosts:** `clab-nexthop-sonic-clos-host1`, `clab-nexthop-sonic-clos-host2`

## 🌐 IP Addresses

### Spine-Leaf Links
- spine1 ↔ leaf1: 10.0.1.0/31 (spine1: .0, leaf1: .1)
- spine1 ↔ leaf2: 10.0.2.0/31 (spine1: .0, leaf2: .1)
- spine2 ↔ leaf1: 10.0.1.2/31 (spine2: .2, leaf1: .3)
- spine2 ↔ leaf2: 10.0.2.2/31 (spine2: .2, leaf2: .3)

### Loopbacks
- spine1: 1.1.1.1/32
- spine2: 2.2.2.2/32
- leaf1: 11.11.11.11/32
- leaf2: 22.22.22.22/32

### Host Networks
- host1: 192.168.1.10/24 (gateway: 192.168.1.1 on leaf1)
- host2: 192.168.2.10/24 (gateway: 192.168.2.1 on leaf2)

## 🔑 Key Files

- **Topology:** `topology/nexthop-sonic-clos.clab.yml`
- **Configs:** `configs/{spine1,spine2,leaf1,leaf2}/config_db.json`
- **Scripts:**
  - `scripts/deploy_lab.sh` - Automated deployment
  - `scripts/configure_bgp_docker.sh` - BGP configuration
  - `scripts/cleanup_lab.sh` - Cleanup and destroy

