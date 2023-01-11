output "selected_availability_domain" {
  value = local.selected_AD
}

output "latest_ubuntu2204_image" {
  value = {
    id           = local.selected_image.id
    display_name = local.selected_image.display_name
  }
}

output "compute_instance_id" {
  value = oci_core_instance.foundry_instance.id
}

output "compute_instance_ip" {
  value = oci_core_instance.foundry_instance.public_ip
}

output "compute_instance_boot_volume_id" {
  value = oci_core_instance.foundry_instance.boot_volume_id
}

output "dynamic_group_id" {
  value = oci_identity_dynamic_group.this.id
}

output "policy_id" {
  value = oci_identity_policy.this.id
}

resource "local_file" "ocids_state" {
  content  = <<-EOT
  compute_instance_id = ${oci_core_instance.foundry_instance.id}
  compute_instance_boot_volume_id = ${oci_core_instance.foundry_instance.boot_volume_id}
  dynamic_group_id = ${oci_identity_dynamic_group.this.id}
  policy_id = ${oci_identity_policy.this.id}
  EOT
  filename = "${path.module}/files/ocids-state.txt"
}
