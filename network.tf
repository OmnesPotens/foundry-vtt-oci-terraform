resource "oci_core_vcn" "foundry_network" {
  cidr_blocks    = ["192.168.0.0/23", "172.31.0.0/16"]
  compartment_id = var.tenancy_ocid
  display_name   = "foundry"
  dns_label      = "foundry"
  is_ipv6enabled = true
}

resource "oci_core_subnet" "public_subnet" {
  cidr_block        = "192.168.0.0/24"
  compartment_id    = var.tenancy_ocid
  vcn_id            = oci_core_vcn.foundry_network.id
  display_name      = "foundrypublicsubnet"
  ipv6cidr_blocks   = [for cidr in oci_core_vcn.foundry_network.ipv6cidr_blocks : cidrsubnet(cidr, 8, 81)]
  security_list_ids = [oci_core_security_list.foundry_security_list.id]
  route_table_id    = oci_core_route_table.foundry_route_table.id
  dhcp_options_id   = oci_core_vcn.foundry_network.default_dhcp_options_id
}

resource "oci_core_internet_gateway" "foundry_internet_gateway" {
  compartment_id = var.tenancy_ocid
  display_name   = "foundryIG"
  vcn_id         = oci_core_vcn.foundry_network.id
}

resource "oci_core_route_table" "foundry_route_table" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.foundry_network.id
  display_name   = "foundryRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.foundry_internet_gateway.id
  }
}

resource "oci_core_security_list" "foundry_security_list" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.foundry_network.id
  display_name   = "foundrySecurityList"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
  egress_security_rules {
    protocol    = "all"
    destination = "::/0"
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = true
    description = "SSH"

    tcp_options {
      max = "22"
      min = "22"
    }
  }
  ingress_security_rules {
    protocol    = "6"
    source      = "::/0"
    stateless   = true
    description = "SSH"

    tcp_options {
      max = "22"
      min = "2"
    }
  }

  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = true

    tcp_options {
      max = "80"
      min = "80"
    }
  }
  ingress_security_rules {
    protocol    = "6"
    source      = "::/0"
    stateless   = true
    description = "HTTP"

    tcp_options {
      max = "80"
      min = "80"
    }
  }

  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = true

    tcp_options {
      max = "443"
      min = "443"
    }
  }
  ingress_security_rules {
    protocol    = "6"
    source      = "::/0"
    stateless   = true
    description = "HTTPS"

    tcp_options {
      max = "443"
      min = "443"
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = true
    description = "Foundry"

    tcp_options {
      max = "30000"
      min = "30000"
    }
  }
  ingress_security_rules {
    protocol    = "6"
    source      = "::/0"
    stateless   = true
    description = "Foundry"

    tcp_options {
      max = "30000"
      min = "30000"
    }
  }

  ingress_security_rules {
    protocol    = "17"
    source      = "0.0.0.0/0"
    stateless   = true
    description = "Open WebRTC"

    udp_options {
      max = "33478"
      min = "33478"
    }
  }

  ingress_security_rules {
    protocol    = "17"
    source      = "::/0"
    stateless   = true
    description = "Open WebRTC"

    udp_options {
      max = "33478"
      min = "33478"
    }
  }

  ingress_security_rules {
    protocol    = "17"
    source      = "0.0.0.0/0"
    stateless   = true
    description = "Open WebRTC"

    udp_options {
      max = "65535"
      min = "49152"
    }
  }
  ingress_security_rules {
    protocol    = "17"
    source      = "::/0"
    stateless   = true
    description = "Open WebRTC"

    udp_options {
      max = "65535"
      min = "49152"
    }
  }

}
