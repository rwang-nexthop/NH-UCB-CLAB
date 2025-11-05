# Nexthop.AI SONiC CLOS Lab Configuration Script

## Overview

The `configure_bgp_docker.sh` script provides **complete automated configuration** for the SONiC CLOS lab, starting from virgin container installations.

## What It Does

### Step 1: Interface Configuration
Configures all physical interfaces and loopbacks on each device:

**spine1:**
- Ethernet0: 10.0.1.0/31 (to leaf1)
- Ethernet4: 10.0.2.0/31 (to leaf2)
- Loopback0: 1.1.1.1/32

**spine2:**
- Ethernet0: 10.0.1.2/31 (to leaf1)
- Ethernet4: 10.0.2.2/31 (to leaf2)
- Loopback0: 2.2.2.2/32

**leaf1:**
- Ethernet0: 10.0.1.1/31 (to spine1)
- Ethernet4: 10.0.1.3/31 (to spine2)
- Ethernet8: 192.168.1.1/24 (to host1)
- Loopback0: 11.11.11.11/32

**leaf2:**
- Ethernet0: 10.0.2.1/31 (to spine1)
- Ethernet4: 10.0.2.3/31 (to spine2)
- Ethernet8: 192.168.2.1/24 (to host2)
- Loopback0: 22.22.22.22/32

### Step 2: Interface Verification
Displays configured interfaces on all devices to confirm proper setup.

### Step 3: Enable BGP Daemon
- Modifies `/etc/frr/daemons` to enable `bgpd`
- Restarts FRR service on all containers
- Waits for services to stabilize

### Step 4: Configure BGP on Spines
Configures eBGP on both spine routers:
- AS 65000
- BGP neighbors pointing to both leaves
- Route redistribution for connected routes
- Disables `ebgp-requires-policy` for lab simplicity

### Step 5: Configure BGP on Leaves
Configures eBGP on both leaf routers:
- leaf1: AS 65101
- leaf2: AS 65102
- BGP neighbors pointing to both spines
- Network statements for host subnets
- Route redistribution for connected routes

### Step 6: Wait for BGP Establishment
Waits 30 seconds for BGP sessions to establish and routes to propagate.

### Step 7: Verify BGP Status
Displays BGP summary for all containers showing:
- BGP router ID
- Local AS number
- Neighbor states
- Prefix counts

### Step 8: Test Connectivity
Tests end-to-end connectivity:
- host1 (192.168.1.10) → host2 (192.168.2.10)
- host2 (192.168.2.10) → host1 (192.168.1.10)

## Usage

```bash
cd scripts
./configure_bgp_docker.sh
```

## Expected Output

The script will show:
- ✓ Success indicators for each configuration step
- Interface configurations
- BGP neighbor states (should show "Established")
- Successful ping tests between hosts

## Troubleshooting

If BGP neighbors don't establish:

1. **Check interface status:**
   ```bash
   docker exec clab-nexthop-sonic-clos-leaf1 show ip interface
   ```

2. **Verify BGP daemon is running:**
   ```bash
   docker exec clab-nexthop-sonic-clos-leaf1 service frr status
   ```

3. **Check BGP configuration:**
   ```bash
   docker exec clab-nexthop-sonic-clos-leaf1 vtysh -c "show running-config"
   ```

4. **View BGP neighbor details:**
   ```bash
   docker exec clab-nexthop-sonic-clos-leaf1 vtysh -c "show ip bgp neighbors"
   ```

5. **Check routing table:**
   ```bash
   docker exec clab-nexthop-sonic-clos-leaf1 vtysh -c "show ip route"
   ```

## Manual Configuration

If you need to manually configure a container:

```bash
# Enter the container
docker exec -it clab-nexthop-sonic-clos-leaf1 bash

# Configure interface
config interface ip add Ethernet0 10.0.1.1/31
config interface startup Ethernet0

# Enable bgpd
sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
service frr restart

# Configure BGP via vtysh
vtysh
configure terminal
router bgp 65101
 bgp router-id 11.11.11.11
 no bgp ebgp-requires-policy
 neighbor 10.0.1.0 remote-as 65000
 address-family ipv4 unicast
  network 192.168.1.0/24
  redistribute connected
 exit-address-family
exit
write memory
exit
```

## Requirements

- Containerlab deployment must be running
- Docker must be accessible
- No additional dependencies (uses `docker exec`)

## Notes

- The script is idempotent - safe to run multiple times
- Uses SONiC CLI (`config` command) for interface configuration
- Uses FRR vtysh for BGP configuration
- All configurations are saved to persistent storage

