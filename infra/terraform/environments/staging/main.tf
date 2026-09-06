locals {
  labels = merge(
    {
      app         = "lmx"
      environment = var.environment
      managed_by  = "terraform"
    },
    var.extra_labels
  )
}

resource "hcloud_ssh_key" "deploy" {
  name       = "${var.server_name}-deploy"
  public_key = trimspace(var.ssh_public_key)
  labels     = local.labels
}

resource "hcloud_firewall" "web" {
  name   = "${var.server_name}-web"
  labels = local.labels

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.ssh_source_ips
    description = "SSH for Kamal and operators"
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0",
    ]
    description = "HTTP for TLS bootstrap and redirect"
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0",
    ]
    description = "HTTPS staging traffic"
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0",
    ]
    description = "ICMP diagnostics"
  }
}

resource "hcloud_server" "web" {
  name         = var.server_name
  image        = var.image
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.deploy.id]
  firewall_ids = [hcloud_firewall.web.id]
  backups      = false
  labels       = local.labels
  user_data    = templatefile("${path.module}/cloud-init.yaml.tftpl", {})

  public_net {
    ipv4_enabled = true
    ipv6_enabled = var.enable_ipv6
  }
}

resource "hcloud_volume" "data" {
  name              = "${var.server_name}-data"
  size              = var.volume_size_gb
  server_id         = hcloud_server.web.id
  automount         = true
  format            = "ext4"
  delete_protection = var.volume_delete_protection
  labels            = local.labels
}
