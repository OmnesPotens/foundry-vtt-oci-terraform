data "oci_objectstorage_bucket" "this" {
  count = try(length(var.bucket_name) > 0 ? 1 : 0, 0)
  #Required
  name      = var.create_bucket ? oci_objectstorage_bucket.this[0].name : var.bucket_name
  namespace = var.create_bucket ? oci_objectstorage_bucket.this[0].namespace : var.objectstorage_namespace
}

resource "oci_objectstorage_bucket" "this" {
  count = var.create_bucket ? 1 : 0
  #Required
  compartment_id = var.tenancy_ocid
  name           = var.bucket_name
  namespace      = var.objectstorage_namespace
}

resource "oci_objectstorage_object" "all_files" {
  for_each = { for entry in local.file_filesets : "${entry.object_path}" => entry }
  #Required
  bucket      = var.create_bucket ? oci_objectstorage_bucket.this[0].name : var.bucket_name
  namespace   = var.objectstorage_namespace
  source      = each.value.source_path
  object      = each.value.object_path
  content_md5 = filemd5(each.value.source_path)
}

resource "oci_objectstorage_object" "all_folder_filesets" {
  for_each = { for entry in local.all_folder_filesets : "${entry.file}" => entry }
  #Required
  bucket      = var.create_bucket ? oci_objectstorage_bucket.this[0].name : var.bucket_name
  namespace   = var.objectstorage_namespace
  source      = each.value.source_path
  object      = each.value.object_path
  content_md5 = filemd5(each.value.source_path)
}
