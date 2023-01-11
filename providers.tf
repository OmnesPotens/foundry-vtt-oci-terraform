terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
    random = {
      source = "hashicorp/random"
    }
    local = {
      source = "hashicorp/local"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  private_key_path = var.rsa_private_key_path
  fingerprint      = var.fingerprint
  region           = var.region_identifier
}

locals {
  have_foundry_creds   = try(length(var.foundry_credentials_path) > 0 ? true : false, false)
  foundry_creds        = try(length(var.foundry_credentials_path) > 0 ? sensitive(file(var.foundry_credentials_path)) : "", "")
  foundry_username     = local.have_foundry_creds ? sensitive(split(" ", "${local.foundry_creds}")[0]) : ""
  foundry_password     = local.have_foundry_creds ? sensitive(split(" ", "${local.foundry_creds}")[1]) : ""
  volume_id            = try(length(var.block_volume_name) > 0 ? data.oci_core_volumes.foundry_persistent[0].volumes[0].id : oci_core_instance.foundry_instance.boot_volume_id, oci_core_instance.foundry_instance.boot_volume_id)
  use_bucket           = try(length(var.bucket_name) > 0 || var.create_bucket ? true : false, false)
  os_bucket            = local.use_bucket ? data.oci_objectstorage_bucket.this[0].name : ""
  public_domain        = try(length(var.domain) > 0 ? var.domain : oci_core_instance.foundry_instance.public_ip, oci_core_instance.foundry_instance.public_ip)
  have_file_filesets   = try(length(var.file_uploads[0]) > 0 ? true : false, false)
  have_folder_filesets = try(length(var.folder_uploads[0]) > 0 ? true : false, false)

  file_filesets = local.have_file_filesets ? distinct(flatten([for file in var.file_uploads : {
    source_path = file
    object_path = basename(file)
  }])) : []

  folder_filesets = local.have_folder_filesets ? distinct(flatten([for folder in var.folder_uploads : fileset(folder, "**")])) : []
  all_folder_filesets = local.have_folder_filesets ? distinct(flatten([
    for folder in var.folder_uploads : [
      for file in local.folder_filesets : {
        source_path = "${folder}/${file}"
        object_path = join("/", [basename(folder), file])
        file        = file
      }
    ]
  ])) : []
  selected_image = length(var.image_id) > 0 ? data.oci_core_image.provided[0] : data.oci_core_images.latest_ubuntu_aarch64[0].images[0]
  selected_AD    = random_shuffle.ad.result[0]
}

# Randomly select an AD
resource "random_shuffle" "ad" {
  input        = data.oci_identity_availability_domains.ads.availability_domains[*].name
  result_count = 1
}
