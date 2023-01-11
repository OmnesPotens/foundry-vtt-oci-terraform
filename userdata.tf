# Render a multi-part cloud-init config making use of the part
# above, and other source files
data "template_cloudinit_config" "userdata" {
  count         = try(length(var.user_data_path) > 0 ? 1 : 0, 0)
  gzip          = false
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    content_type = "text/x-shellscript"
    filename     = "userdata.sh"
    content = templatefile(var.user_data_path, {
      CONFIG_BUCKET = local.os_bucket
    })
  }
  # additional parts can be added here if needed
}
