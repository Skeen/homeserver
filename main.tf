terraform {
  required_providers {
    sops = {
      source = "carlpett/sops"
      version = "1.0.0"
    }
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "1.44.1"
    }
    hetznerdns = {
      source = "timohirt/hetznerdns"
      version = "2.2.0"
    }
  }
}

provider "sops" {}

data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

provider "hetznerdns" {
  apitoken = data.sops_file.secrets.data["hetzner_dns_token"]
}

resource "hetznerdns_zone" "dns_zone" {
    name = "awful.engineer"
    ttl = 3600
}

locals {
  github_pages_a = [
    "185.199.108.153",
    "185.199.109.153",
    "185.199.110.153",
    "185.199.111.153",
  ]
  github_pages_aaaa = [
    "2606:50c0:8000::153",
    "2606:50c0:8001::153",
    "2606:50c0:8002::153",
    "2606:50c0:8003::153",
  ]
}

resource "hetznerdns_record" "www" {
    zone_id = hetznerdns_zone.dns_zone.id
    name = "www"
    ttl = 60
    type = each.value["type"]
    value = each.value["value"]

    for_each = merge({
      for ip in local.github_pages_a: ip => {
        type = "A",
        value = ip
      }
    }, {
      for ip in local.github_pages_aaaa: ip => {
        type = "AAAA",
        value = ip
      }
    }
  )
}

resource "hetznerdns_record" "ns" {
    zone_id = hetznerdns_zone.dns_zone.id
    name = "@"
    ttl = 60
    type = "NS"
    value = each.key

    for_each = toset([
      "helium.ns.hetzner.de.",
      "oxygen.ns.hetzner.com.",
      "hydrogen.ns.hetzner.com.",
    ])
}

resource "hetznerdns_record" "matrix" {
    zone_id = hetznerdns_zone.dns_zone.id
    name = each.key
    ttl = 60
    type = "CNAME"
    value = each.value

    for_each = {
      "chat.matrix": "awfulengineer.element.io.",
      "matrix": "awfulengineer.ems.host."
    }
}

resource "hetznerdns_record" "wildcard" {
    zone_id = hetznerdns_zone.dns_zone.id
    name = "*"
    ttl = 60
    type = "CNAME"
    value = "awful.engineer"
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = data.sops_file.secrets.data["hetzner_cloud_token"]
}

resource "hcloud_ssh_key" "morphine" {
  name       = "morphine"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDUcHrd+lfdEU/HIhhQ8XKc3TSeum4aL/n4LoAWmBFDLX9J7dbi7Wo2dZIm1eREoWbMilL7vp+aq8bT+IeMcRREoJ+XRIXB7F/jFO55NtjRpACKaaFXSvH9c1RcMuW1XS3ZvK944jKTsas/bObqU1ICo/LgPchwxhk6lb1JcblIIkS18zOvm/i7vb1BK63uBGy6GEwn8d+QFp9NgKbsKb3osG3mQ7VokYEt8WVyssPcahyZe+LP49LJpGOtbCewCGHnk6oAXoOHcAJknJaeQoHAZrl8NEa8JBrOkR6p/+nJSb/HoAfnkReMXNTjlzVitVNC+lkkr9CefiGtufm68qIr skeen@morphine"
}

resource "hcloud_server" "homeserver" {
  name        = "homeserver"
  image       = "debian-11"
  server_type = "cx11"
  datacenter  = "hel1-dc2"

  ssh_keys = [hcloud_ssh_key.morphine.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  user_data = file("homeserver-cloud-init.yaml")
}

resource "hetznerdns_record" "root" {
    zone_id = hetznerdns_zone.dns_zone.id
    name = "@"
    ttl = 60
    type = each.key
    value = each.value

    for_each = {
      "A": hcloud_server.homeserver.ipv4_address,
      "AAAA": hcloud_server.homeserver.ipv6_address,
    }
}
