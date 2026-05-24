data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Cloud VPC ────────────────────────────────────────────────────────────────

resource "aws_vpc" "cloud" {
  cidr_block           = var.cloud_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "vpn-lab-cloud" }
}

resource "aws_internet_gateway" "cloud" {
  vpc_id = aws_vpc.cloud.id
  tags   = { Name = "vpn-lab-cloud-igw" }
}

resource "aws_subnet" "cloud_public" {
  vpc_id            = aws_vpc.cloud.id
  cidr_block        = cidrsubnet(var.cloud_cidr, 8, 1)
  availability_zone = "${var.region}a"
  tags              = { Name = "vpn-lab-cloud-public" }
}

resource "aws_route_table" "cloud" {
  vpc_id = aws_vpc.cloud.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloud.id
  }

  # Route onprem traffic through the VPN instance ENI
  route {
    cidr_block           = var.onprem_cidr
    network_interface_id = aws_network_interface.cloud_vpn.id
  }

  tags = { Name = "vpn-lab-cloud-rt" }
}

resource "aws_route_table_association" "cloud" {
  subnet_id      = aws_subnet.cloud_public.id
  route_table_id = aws_route_table.cloud.id
}

# ── Cloud VPN Instance (strongSwan) ─────────────────────────────────────────

resource "aws_security_group" "cloud_vpn" {
  name        = "vpn-lab-cloud-vpn-sg"
  description = "Allow IKE (500), NAT-T (4500), ESP (50), SSH, and cross-VPC ICMP"
  vpc_id      = aws_vpc.cloud.id

  ingress {
    description = "IKE"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NAT-T"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ESP (IPSec data)"
    from_port   = -1
    to_port     = -1
    protocol    = "50"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP from both VPCs"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.cloud_cidr, var.onprem_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "vpn-lab-cloud-vpn-sg" }
}

resource "aws_network_interface" "cloud_vpn" {
  subnet_id         = aws_subnet.cloud_public.id
  private_ips       = [cidrhost(cidrsubnet(var.cloud_cidr, 8, 1), 10)]
  source_dest_check = false # Required: allows forwarding packets for other hosts
  security_groups   = [aws_security_group.cloud_vpn.id]
  tags              = { Name = "vpn-lab-cloud-vpn-eni" }
}

resource "aws_eip" "cloud_vpn" {
  network_interface = aws_network_interface.cloud_vpn.id
  tags              = { Name = "vpn-lab-cloud-eip" }
}

resource "aws_instance" "cloud_vpn" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_pair

  network_interface {
    network_interface_id = aws_network_interface.cloud_vpn.id
    device_index         = 0
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y strongswan strongswan-pki libcharon-extra-plugins
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
  EOF
  )

  tags = { Name = "vpn-lab-cloud-vpn" }
}

# ── Cloud Test EC2 (ping source/target) ─────────────────────────────────────

resource "aws_security_group" "cloud_test" {
  name        = "vpn-lab-cloud-test-sg"
  description = "Allow ICMP from both VPCs and SSH"
  vpc_id      = aws_vpc.cloud.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.cloud_cidr, var.onprem_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "vpn-lab-cloud-test-sg" }
}

resource "aws_instance" "cloud_test" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_pair
  subnet_id                   = aws_subnet.cloud_public.id
  vpc_security_group_ids      = [aws_security_group.cloud_test.id]
  associate_public_ip_address = true
  tags                        = { Name = "vpn-lab-cloud-test" }
}

# ── OnPrem-Sim VPC ───────────────────────────────────────────────────────────

resource "aws_vpc" "onprem" {
  cidr_block           = var.onprem_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "vpn-lab-onprem" }
}

resource "aws_internet_gateway" "onprem" {
  vpc_id = aws_vpc.onprem.id
  tags   = { Name = "vpn-lab-onprem-igw" }
}

resource "aws_subnet" "onprem_public" {
  vpc_id            = aws_vpc.onprem.id
  cidr_block        = cidrsubnet(var.onprem_cidr, 8, 1)
  availability_zone = "${var.region}a"
  tags              = { Name = "vpn-lab-onprem-public" }
}

resource "aws_route_table" "onprem" {
  vpc_id = aws_vpc.onprem.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.onprem.id
  }

  route {
    cidr_block           = var.cloud_cidr
    network_interface_id = aws_network_interface.onprem_vpn.id
  }

  tags = { Name = "vpn-lab-onprem-rt" }
}

resource "aws_route_table_association" "onprem" {
  subnet_id      = aws_subnet.onprem_public.id
  route_table_id = aws_route_table.onprem.id
}

# ── OnPrem-Sim VPN Instance (strongSwan) ─────────────────────────────────────

resource "aws_security_group" "onprem_vpn" {
  name        = "vpn-lab-onprem-vpn-sg"
  description = "Allow IKE, NAT-T, ESP, SSH, and cross-VPC ICMP"
  vpc_id      = aws_vpc.onprem.id

  ingress {
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "50"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.cloud_cidr, var.onprem_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "vpn-lab-onprem-vpn-sg" }
}

resource "aws_network_interface" "onprem_vpn" {
  subnet_id         = aws_subnet.onprem_public.id
  private_ips       = [cidrhost(cidrsubnet(var.onprem_cidr, 8, 1), 10)]
  source_dest_check = false
  security_groups   = [aws_security_group.onprem_vpn.id]
  tags              = { Name = "vpn-lab-onprem-vpn-eni" }
}

resource "aws_eip" "onprem_vpn" {
  network_interface = aws_network_interface.onprem_vpn.id
  tags              = { Name = "vpn-lab-onprem-eip" }
}

resource "aws_instance" "onprem_vpn" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_pair

  network_interface {
    network_interface_id = aws_network_interface.onprem_vpn.id
    device_index         = 0
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y strongswan strongswan-pki libcharon-extra-plugins
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
  EOF
  )

  tags = { Name = "vpn-lab-onprem-vpn" }
}

# ── OnPrem-Sim Test EC2 ───────────────────────────────────────────────────────

resource "aws_security_group" "onprem_test" {
  name        = "vpn-lab-onprem-test-sg"
  description = "Allow ICMP from both VPCs and SSH"
  vpc_id      = aws_vpc.onprem.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.cloud_cidr, var.onprem_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "vpn-lab-onprem-test-sg" }
}

resource "aws_instance" "onprem_test" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_pair
  subnet_id                   = aws_subnet.onprem_public.id
  vpc_security_group_ids      = [aws_security_group.onprem_test.id]
  associate_public_ip_address = true
  tags                        = { Name = "vpn-lab-onprem-test" }
}
