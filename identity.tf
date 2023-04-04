resource "oci_identity_tag_namespace" "foundry_tags" {
  #Required
  compartment_id = var.tenancy_ocid
  description    = "Custom tags for Foundry"
  name           = "Foundry-Tags"
  is_retired     = false
}

resource "oci_identity_tag" "app" {
  #Required
  description      = "Tag that marks this resource as being related to the Foundry app's functionality within OCI."
  name             = "app"
  tag_namespace_id = oci_identity_tag_namespace.foundry_tags.id
  is_cost_tracking = false
  is_retired       = false
}

resource "oci_identity_dynamic_group" "this" {
  #Required
  compartment_id = var.tenancy_ocid
  description    = "Dynamic group for Foundry instances to enable using OCI services"
  matching_rule  = "All { instance.id = '${oci_core_instance.foundry_instance.id}', tag.${oci_identity_tag_namespace.foundry_tags.name}.${oci_identity_tag.app.name}.value = 'Foundry' }"
  name           = "FoundryServiceAccess"
}

resource "oci_identity_policy" "this" {
  #Required
  compartment_id = var.tenancy_ocid
  description    = "Grants Foundry instance(s) access to various OCI services based on Dynamic Group membership. Relies on configuring instance_principal auth on the instance(s)."
  name           = "FoundryDynamicInstancePolicy"
  statements = compact(concat([
    "Allow dynamic-group 'Default'/'${oci_identity_dynamic_group.this.name}' to use volume-family in tenancy",
    "Allow dynamic-group 'Default'/'${oci_identity_dynamic_group.this.name}' to use instance-family in tenancy",
    "Allow dynamic-group 'Default'/'${oci_identity_dynamic_group.this.name}' to read buckets in tenancy",
    "Allow dynamic-group 'Default'/'${oci_identity_dynamic_group.this.name}' to read repos in tenancy"
  ], length(local.os_bucket) > 0 ? ["Allow dynamic-group 'Default'/'${oci_identity_dynamic_group.this.name}' to manage objects in tenancy where all {target.bucket.name='${local.os_bucket}'}"] : []))
}
