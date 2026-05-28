# Architecture Diagram

Add your draw.io architecture diagram here as `architecture.png`.

## Suggested draw.io Elements

- Two VPC boxes (Cloud: 10.10.0.0/16, OnPrem-Sim: 10.20.0.0/16)
- Subnet boxes within each VPC
- EC2 instances (strongSwan VPN + test instance in each VPC)
- Bidirectional arrow between VPN instances labeled "IKEv2 / IPSec / AES-256"
- Elastic IPs on each VPN instance
- Route table entries shown as callouts
- Internet Gateway on each VPC

## Export

Export as PNG at 1200px wide, save as `docs/architecture.png`.
Update the README image reference: `![Architecture](docs/architecture.png)`
