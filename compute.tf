data "oci_core_images" "latest_ubuntu_aarch64" {
  # only create this if an image_id is not provided
  count = length(var.image_id) > 0 ? 0 : 1
  #Required
  compartment_id = var.tenancy_ocid

  #Optional
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.compute_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_core_image" "provided" {
  count    = length(var.image_id) > 0 ? 1 : 0
  image_id = var.image_id
}

resource "oci_core_instance" "foundry_instance" {
  depends_on = [
    oci_core_vcn.foundry_network,
    oci_core_subnet.public_subnet,
    oci_core_internet_gateway.foundry_internet_gateway,
    oci_core_route_table.foundry_route_table,
    oci_core_security_list.foundry_security_list
  ]

  availability_domain = local.selected_AD
  compartment_id      = var.tenancy_ocid
  display_name        = "foundry_instance"
  shape               = var.compute_shape
  state               = "RUNNING"
  ### If you don't want to use an additional block storage volume, set this to true.
  ### NOTE: Make sure you don't run terraform apply and terraform destroy without manually deleting the leftover boot volumes
  ###       If you don't manually delete them then they will be counted against your 200GB of Always Free Block Storage limit.
  preserve_boot_volume = false

  launch_options {

    #Optional
    # boot_volume_type                    = "ISCSI"
    network_type                        = "PARAVIRTUALIZED"
    is_consistent_volume_naming_enabled = true
    # remote_data_volume_type             = "ISCSI"
  }

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public_subnet.id
    display_name              = "primaryvnic"
    assign_public_ip          = true
    assign_private_dns_record = false
  }

  source_details {
    source_type             = "image"
    source_id               = local.selected_image.id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  defined_tags = { "${oci_identity_tag_namespace.foundry_tags.name}.${oci_identity_tag.app.name}" : "Foundry" }

  metadata = {
    ssh_authorized_keys = file("${var.ssh_public_key_path}")
    user_data           = try(length(var.user_data_path) > 0 ? data.template_cloudinit_config.userdata[0].rendered : null, null)
  }
}

resource "null_resource" "wait_for_cloud_init" {
  # ensure we wait for cloud-init to finish each time the instance public ip changes
  triggers = {
    public_ip = oci_core_instance.foundry_instance.public_ip
  }
  connection {
    host            = oci_core_instance.foundry_instance.public_ip
    type            = "ssh"
    user            = "ubuntu"
    private_key     = file(var.ssh_private_key_path)
    target_platform = "unix"
  }

  provisioner "remote-exec" {
    inline = [
      "if [ ! $(cloud-init status | grep -qc done) ]; then cloud-init status --wait; fi",
      "echo \"export PUBLIC_IP=${oci_core_instance.foundry_instance.public_ip}\" >> ~/.bashrc"
    ]
  }
}

resource "null_resource" "post_provisioning" {
  count = try(length(var.post_provisioning_path) > 0 ? 1 : 0, 0)
  depends_on = [
    null_resource.wait_for_cloud_init,
    oci_core_instance.foundry_instance
  ]

  triggers = {
    COMPARTMENT_ID   = var.tenancy_ocid
    INSTANCE_ID      = oci_core_instance.foundry_instance.id
    AD               = local.selected_AD
    PUBLIC_IP        = oci_core_instance.foundry_instance.public_ip
    FOUNDRY_USERNAME = local.foundry_username
    FOUNDRY_PASSWORD = local.foundry_password
    DOMAIN           = local.public_domain
  }

  connection {
    host            = oci_core_instance.foundry_instance.public_ip
    type            = "ssh"
    user            = "ubuntu"
    private_key     = file(var.ssh_private_key_path)
    target_platform = "unix"
  }
  provisioner "file" {
    destination = "/home/ubuntu/post-provisioning.sh"
    content = templatefile(var.post_provisioning_path, {
      COMPARTMENT_ID   = self.triggers.COMPARTMENT_ID
      INSTANCE_ID      = self.triggers.INSTANCE_ID
      AD               = self.triggers.AD
      PUBLIC_IP        = self.triggers.PUBLIC_IP
      FOUNDRY_USERNAME = self.triggers.FOUNDRY_USERNAME
      FOUNDRY_PASSWORD = self.triggers.FOUNDRY_PASSWORD
      DOMAIN           = self.triggers.DOMAIN
    })
  }
  provisioner "remote-exec" {
    inline = [
      "bash /home/ubuntu/post-provisioning.sh",
      "rm /home/ubuntu/post-provisioning.sh"
    ]
  }
}
