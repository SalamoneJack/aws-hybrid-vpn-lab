# Deployment Evidence — aws-hybrid-vpn-lab

**Status:** LIVE — IPSec tunnel ESTABLISHED, end-to-end ping working
**Deployed:** 2026-05-28
**Region:** us-east-1
**Account:** 904474958504

## Terminal Screenshots

**`sudo ipsec statusall` — full IKE charon daemon state with IKEv2 SPIs, AES_CBC_256/HMAC_SHA2_256/MODP_2048 proposal, ESP-in-UDP tunnel installed:**

![ipsec statusall ESTABLISHED](terminal-ipsec-statusall.png)

**End-to-end ping across the encrypted tunnel — 5/5 received, 0% loss, sub-2ms RTT:**

![ping across tunnel](terminal-ping-across-tunnel.png)

## Tunnel ESTABLISHED — PROOF

```
Security Associations (2 up, 0 connecting):
cloud-to-onprem[2]: ESTABLISHED 31 seconds ago, 10.10.1.10[32.195.193.33]...13.218.2.244[13.218.2.244]
cloud-to-onprem[2]: IKEv2 SPIs: c44e880833c8ce35_i ecaa80bf310ae3f8_r*, pre-shared key reauthentication in 2 hours
cloud-to-onprem[2]: IKE proposal: AES_CBC_256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
cloud-to-onprem{1}:  INSTALLED, TUNNEL, reqid 1, ESP in UDP SPIs: c3c914e9_i cbe2b85f_o
cloud-to-onprem{1}:  AES_CBC_256/HMAC_SHA2_256_128, 0 bytes_i, 0 bytes_o, rekeying in 48 minutes
cloud-to-onprem{1}:   10.10.0.0/16 === 10.20.0.0/16
```

IKEv2 with **AES-256-CBC / SHA-256-HMAC / DH-MODP-2048**, traffic selectors `10.10.0.0/16 === 10.20.0.0/16`.

## End-to-End Ping ACROSS Tunnel

```
== From cloud-vpn (10.10.1.10) across IPSec tunnel to onprem-test (10.20.1.240) ==
PING 10.20.1.240 (10.20.1.240) 56(84) bytes of data.
64 bytes from 10.20.1.240: icmp_seq=1 ttl=63 time=1.17 ms
64 bytes from 10.20.1.240: icmp_seq=2 ttl=63 time=1.33 ms
64 bytes from 10.20.1.240: icmp_seq=3 ttl=63 time=1.30 ms
64 bytes from 10.20.1.240: icmp_seq=4 ttl=63 time=0.959 ms
64 bytes from 10.20.1.240: icmp_seq=5 ttl=63 time=0.984 ms

--- 10.20.1.240 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4006ms
rtt min/avg/max/mdev = 0.959/1.147/1.325/0.154 ms
```

**0% loss, sub-2ms RTT.** Encrypted IPSec round-trip between two VPCs proves the tunnel is operational end-to-end, not just signaling.

## What This Lab Demonstrates
Site-to-site IPSec VPN between two AWS VPCs simulating an on-prem ↔ cloud hybrid topology. Uses strongSwan with IKEv2 / AES-256 / SHA-256 / DH14. Demonstrates the foundational hybrid networking pattern that every cloud network engineer must understand.

## Architecture

```
   Cloud VPC (10.10.0.0/16)              OnPrem-Sim VPC (10.20.0.0/16)
   ┌──────────────────────┐              ┌──────────────────────┐
   │  cloud-test          │              │  onprem-test         │
   │  10.10.1.52          │              │  10.20.1.240         │
   │  i-0cbccae7feb0ca3e1 │              │  i-0352bc5741b05ca02 │
   └──────────┬───────────┘              └──────────┬───────────┘
              │                                     │
   ┌──────────┴───────────┐    IPSec tunnel    ┌────┴─────────────┐
   │  cloud-vpn (strongSwan)│ ◄═════════════►  │ onprem-vpn (strongSwan)│
   │  10.10.1.10           │  IKEv2/AES-256   │ 10.20.1.10            │
   │  EIP 32.195.193.33    │                   │ EIP 13.218.2.244      │
   │  i-098aec09585c74423  │                   │ i-04fbefb60df83d01f   │
   └───────────────────────┘                   └───────────────────────┘
```

## Resources Deployed

### VPCs
| VPC | CIDR | ID |
|---|---|---|
| Cloud | 10.10.0.0/16 | `vpc-0df8bd59bbf3185e9` |
| OnPrem-Sim | 10.20.0.0/16 | `vpc-098889a249bb52e61` |

### EC2 Instances (4× t2.micro, all running)
| Name | Role | Private IP | Instance ID |
|---|---|---|---|
| vpn-lab-cloud-vpn | strongSwan endpoint | 10.10.1.10 | `i-098aec09585c74423` |
| vpn-lab-cloud-test | test VM behind tunnel | 10.10.1.52 | `i-0cbccae7feb0ca3e1` |
| vpn-lab-onprem-vpn | strongSwan endpoint | 10.20.1.10 | `i-04fbefb60df83d01f` |
| vpn-lab-onprem-test | test VM behind tunnel | 10.20.1.240 | `i-0352bc5741b05ca02` |

### Elastic IPs
| EIP | Attached to |
|---|---|
| `32.195.193.33` | Cloud VPN endpoint |
| `13.218.2.244` | OnPrem VPN endpoint |

Plus: 4 route tables, security groups, internet gateways, key pair reference (`bgp-lab`).

## Live AWS Console Links

- **Cloud VPC:** https://us-east-1.console.aws.amazon.com/vpcconsole/home?region=us-east-1#VpcDetails:VpcId=vpc-0df8bd59bbf3185e9
- **OnPrem VPC:** https://us-east-1.console.aws.amazon.com/vpcconsole/home?region=us-east-1#VpcDetails:VpcId=vpc-098889a249bb52e61
- **All instances filtered:** https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#Instances:tag:Project=aws-hybrid-vpn-lab

## SSH Access

```powershell
ssh -i "C:\Users\Jack\Desktop\secure\bgp-lab.pem" ubuntu@32.195.193.33   # cloud-vpn
ssh -i "C:\Users\Jack\Desktop\secure\bgp-lab.pem" ubuntu@13.218.2.244    # onprem-vpn
```

## Tunnel Verification (run on either VPN instance after SSH)

```bash
sudo ipsec status              # tunnel state — expect "ESTABLISHED"
sudo ipsec statusall           # full IKE/IPSec detail
sudo tcpdump -i eth0 esp       # observe encrypted ESP packets

# From cloud-test (10.10.1.52), reach onprem-test (10.20.1.240) over the tunnel
ping 10.20.1.240
```

## Raw Evidence (this folder)

- `vpcs.json` — both VPCs
- `instances.json` — all 4 EC2s
- `eips.json` — both VPN EIPs
- `route-tables.json` — route table configuration
- `security-groups.json` — SG rules
- `terraform-outputs.json` — `terraform output -json`

## Cost
~$15-20/month (4× t2.micro + 2 EIPs). **Destroy after demo / screenshots:** `terraform destroy`.
