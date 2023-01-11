resource "oci_core_volume_backup_policy" "foundry_free_backup_policy" {
  #Required
  compartment_id = var.tenancy_ocid

  #Optional
  display_name = "Foundry-Backup"
  schedules {
    #Required
    backup_type = "INCREMENTAL"
    period      = "ONE_DAY"
    # maintain 1 daily backup
    retention_seconds = 86400

    #Optional
    hour_of_day = 9
    time_zone   = "UTC"
  }
  schedules {
    #Required
    backup_type = "INCREMENTAL"
    period      = "ONE_WEEK"
    # maintain 2 weekly backups
    retention_seconds = 1209600

    #Optional
    day_of_week = "MONDAY"
    hour_of_day = 9
    time_zone   = "UTC"
  }
  schedules {
    #Required
    backup_type = "INCREMENTAL"
    period      = "ONE_MONTH"
    # maintain 2 monthly backups
    retention_seconds = 5184000

    #Optional
    day_of_month = 1
    hour_of_day  = 9
    time_zone    = "UTC"
  }
}

data "oci_core_volumes" "foundry_persistent" {
  count = try(length(var.block_volume_name) > 0 ? 1 : 0, 0)
  #Optional
  compartment_id = var.tenancy_ocid
  display_name   = var.create_block_volume ? oci_core_volume.foundry_persistent[0].display_name : var.block_volume_name
  state          = var.create_block_volume ? oci_core_volume.foundry_persistent[0].state : "Available"
}

resource "oci_core_volume" "foundry_persistent" {
  count = var.create_block_volume ? 1 : 0
  #Required
  compartment_id = var.tenancy_ocid

  availability_domain  = local.selected_AD
  display_name         = var.block_volume_name
  is_auto_tune_enabled = false
  size_in_gbs          = var.block_volume_size_in_gbs
  vpus_per_gb          = 10
}

resource "oci_core_volume_attachment" "this" {
  depends_on = [
    null_resource.wait_for_cloud_init
  ]
  #Required
  attachment_type = "iscsi"
  instance_id     = oci_core_instance.foundry_instance.id
  volume_id       = data.oci_core_volumes.foundry_persistent[0].volumes[0].id

  #Optional
  device                            = var.block_volume_device
  display_name                      = "${var.block_volume_name}Attachment"
  is_agent_auto_iscsi_login_enabled = false

  connection {
    host            = oci_core_instance.foundry_instance.public_ip
    type            = "ssh"
    user            = "ubuntu"
    private_key     = file(var.ssh_private_key_path)
    target_platform = "unix"
  }

  # register and connect the iSCSI block volume to the instance's guest OS
  provisioner "remote-exec" {
    inline = [
      "sudo iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}",
      "sudo iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic",
      "sudo iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l",
    ]
  }
  # initialize partition and file system
  provisioner "remote-exec" {
    inline = [
      "set -x",
      "export DEVICE_ID=${var.block_volume_device}",
      "export HAS_MSDOS_PARTITION=$(sudo partprobe -d -s $${DEVICE_ID} | grep -c msdos)",
      "if [ $HAS_MSDOS_PARTITION -eq 1 ] ; then",
      "  (echo 'g'; echo 'n'; echo ''; echo ''; echo ''; echo 'w';) | sudo fdisk $${DEVICE_ID}",
      "  while [ ! -e $${DEVICE_ID}1 ] ; do sleep 1; done",
      "  sudo mkfs.xfs $${DEVICE_ID}1",
      "fi"
    ]
  }
  # mount the partition
  provisioner "remote-exec" {
    inline = [
      "set -x",
      "export DEVICE_ID=${var.block_volume_device}",
      "sudo mkdir -p ${var.foundry_volume_mount_path}",
      "export UUID=$(sudo /usr/sbin/blkid -s UUID -o value $${DEVICE_ID}1)",
      "echo 'UUID=$${UUID} ${var.foundry_volume_mount_path} xfs defaults,_netdev,nofail 0 2' | sudo tee -a /etc/fstab",
      # mounts all disks in /etc/fstab
      # "sudo mount -a",
      "sudo mount $${DEVICE_ID}1 ${var.foundry_volume_mount_path}"
    ]
  }
}

resource "null_resource" "unmount_disconnect_volume" {
  triggers = {
    public_ip        = oci_core_instance.foundry_instance.public_ip
    private_key      = file(var.ssh_private_key_path)
    attachment_state = oci_core_volume_attachment.this.state
    device           = var.block_volume_device
    mount_path       = var.foundry_volume_mount_path
    iqn              = oci_core_volume_attachment.this.iqn
    ipv4             = oci_core_volume_attachment.this.ipv4
    port             = oci_core_volume_attachment.this.port
  }

  connection {
    host            = self.triggers.public_ip
    type            = "ssh"
    user            = "ubuntu"
    private_key     = self.triggers.private_key
    target_platform = "unix"
  }

  # cleanly unmount and disconnect the volume when the volume attachment is destroyed
  provisioner "remote-exec" {
    when = destroy
    # on_failure = "continue"
    inline = [
      "set -x",
      "export DEVICE_ID=${self.triggers.device}",
      "export UUID=$(sudo /usr/sbin/blkid -s UUID -o value $${DEVICE_ID}1)",
      "sudo umount ${self.triggers.mount_path}",
      "if [[ $UUID ]] ; then",
      # remove line containing UUID from /etc/fstab
      "  sudo sed -i.bak '/UUID='$${UUID}/c\\ /etc/fstab",
      "fi",
      "sudo iscsiadm -m node -T ${self.triggers.iqn} -p ${self.triggers.ipv4}:${self.triggers.port} -u",
      "sudo iscsiadm -m node -o delete -T ${self.triggers.iqn} -p ${self.triggers.ipv4}:${self.triggers.port}",
    ]
  }
}

resource "oci_core_volume_backup_policy_assignment" "foundry" {
  depends_on = [
    data.oci_core_volumes.foundry_persistent
  ]
  #Required
  asset_id  = local.volume_id
  policy_id = oci_core_volume_backup_policy.foundry_free_backup_policy.id
}
