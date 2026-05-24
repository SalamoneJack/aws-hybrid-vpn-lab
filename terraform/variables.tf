variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "key_pair" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
}

variable "cloud_cidr" {
  description = "CIDR block for the Cloud VPC (simulates AWS side)"
  type        = string
  default     = "10.10.0.0/16"
}

variable "onprem_cidr" {
  description = "CIDR block for the OnPrem-Sim VPC (simulates data center)"
  type        = string
  default     = "10.20.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for VPN and test instances"
  type        = string
  default     = "t2.micro"
}
