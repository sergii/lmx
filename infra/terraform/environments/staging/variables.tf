variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "staging"
}

variable "server_name" {
  description = "Hetzner Cloud server name."
  type        = string
  default     = "lmx-staging"
}

variable "server_type" {
  description = "Hetzner Cloud server type."
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Hetzner Cloud location."
  type        = string
  default     = "hel1"
}

variable "image" {
  description = "Hetzner Cloud server image."
  type        = string
  default     = "ubuntu-24.04"
}

variable "staging_hostname" {
  description = "Public DNS hostname that Kamal will serve for staging."
  type        = string

  validation {
    condition     = length(trimspace(var.staging_hostname)) > 0
    error_message = "staging_hostname must not be empty."
  }
}

variable "ssh_public_key" {
  description = "Public SSH key injected into the staging server for Kamal/operator access."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.ssh_public_key)) > 0
    error_message = "ssh_public_key must not be empty."
  }
}

variable "ssh_source_ips" {
  description = "CIDR ranges allowed to reach SSH. Use explicit values; GitHub-hosted runners may require public SSH with key-only authentication."
  type        = list(string)

  validation {
    condition     = length(var.ssh_source_ips) > 0
    error_message = "ssh_source_ips must include at least one CIDR."
  }
}

variable "volume_size_gb" {
  description = "Persistent staging data volume size in GiB."
  type        = number
  default     = 50

  validation {
    condition     = var.volume_size_gb >= 10
    error_message = "Hetzner Cloud Volumes must be at least 10 GiB."
  }
}

variable "volume_delete_protection" {
  description = "Protect the persistent data volume from accidental deletion."
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "Enable public IPv6 on the staging server."
  type        = bool
  default     = true
}

variable "extra_labels" {
  description = "Additional labels applied to Hetzner resources."
  type        = map(string)
  default     = {}
}
