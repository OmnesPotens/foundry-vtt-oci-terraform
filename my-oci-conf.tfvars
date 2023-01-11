### General OCI Auth
user_ocid    = ""
fingerprint  = ""
tenancy_ocid = ""

### Specifications
region_identifier       = ""
compute_shape           = "VM.Standard.A1.Flex"
boot_volume_size_in_gbs = "50"
memory_in_gbs           = "24"
ocpus                   = "4"
alert_rule_recipients   = "<your recipient email>"

### Access
rsa_private_key_path = "~/.oci/ival_rsa.pem"
ssh_private_key_path = "~/keys/fvtt-runner/oci_ssh_key_ecdsa"
ssh_public_key_path  = "~/keys/fvtt-runner/oci_ssh_key_ecdsa.pub"

### (OPTIONAL) Persistent Storage
create_block_volume      = true # recommended
block_volume_size_in_gbs = "50" # minimum is 50

### (OPTIONAL) Setup + Post-provisioning
foundry_credentials_path = ""
user_data_path           = ""
post_provisioning_path   = ""
domain                   = ""

### (OPTIONAL) Object Storage (s3)
bucket_name             = ""
objectstorage_namespace = ""
file_uploads = [
  ""
]
folder_uploads = [
  ""
]
