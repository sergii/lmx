output "staging_ipv4" {
  description = "Public IPv4 address used by Kamal as LMX_STAGING_HOST."
  value       = hcloud_server.web.ipv4_address
}

output "staging_ipv6" {
  description = "Public IPv6 address of the staging server when IPv6 is enabled."
  value       = hcloud_server.web.ipv6_address
}

output "staging_hostname" {
  description = "Public hostname used by Kamal as LMX_STAGING_HOSTNAME."
  value       = var.staging_hostname
}

output "data_volume_id" {
  description = "Hetzner Cloud ID of the persistent staging data volume."
  value       = hcloud_volume.data.id
}

output "data_volume_linux_device" {
  description = "Stable Linux device path reported by Hetzner for the data volume."
  value       = hcloud_volume.data.linux_device
}

output "data_volume_mount_path" {
  description = "Automatic Hetzner mount path for the persistent staging data volume."
  value       = "/mnt/HC_Volume_${hcloud_volume.data.id}"
}

output "ssh_command" {
  description = "Operator SSH command for the staging server."
  value       = "ssh root@${hcloud_server.web.ipv4_address}"
}
