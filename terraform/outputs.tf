output "cloud_vpn_eip" {
  description = "Public IP of the Cloud VPN (strongSwan) instance"
  value       = aws_eip.cloud_vpn.public_ip
}

output "onprem_vpn_eip" {
  description = "Public IP of the OnPrem-Sim VPN (strongSwan) instance"
  value       = aws_eip.onprem_vpn.public_ip
}

output "cloud_test_private_ip" {
  description = "Private IP of the Cloud test EC2 (use as ping target)"
  value       = aws_instance.cloud_test.private_ip
}

output "onprem_test_private_ip" {
  description = "Private IP of the OnPrem-Sim test EC2 (use as ping target)"
  value       = aws_instance.onprem_test.private_ip
}

output "ssh_cloud_vpn" {
  description = "SSH command for the Cloud VPN instance"
  value       = "ssh -i ~/.ssh/${var.key_pair}.pem ubuntu@${aws_eip.cloud_vpn.public_ip}"
}

output "ssh_onprem_vpn" {
  description = "SSH command for the OnPrem-Sim VPN instance"
  value       = "ssh -i ~/.ssh/${var.key_pair}.pem ubuntu@${aws_eip.onprem_vpn.public_ip}"
}

output "ipsec_config_hint" {
  description = "Reminder: configure /etc/ipsec.conf on both instances using these IPs"
  value       = "Cloud EIP: ${aws_eip.cloud_vpn.public_ip} | OnPrem EIP: ${aws_eip.onprem_vpn.public_ip} — see README for full ipsec.conf"
}
