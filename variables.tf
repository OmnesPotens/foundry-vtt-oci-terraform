variable "tenancy_ocid" {
  description = "Your OCI Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "Your OCI user OCID"
  type        = string
}

variable "rsa_private_key_path" {
  description = "Path to your RSA private key"
  type        = string
}

variable "fingerprint" {
  description = "Your OCI fingerprint"
  type        = string
}

variable "region_identifier" {
  description = "Your OCI Region ID"
  type        = string
}

variable "compute_shape" {
  description = "Compute Shape"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "boot_volume_size_in_gbs" {
  description = "Compute instance boot volume size in GBs"
  type        = string
  default     = "10"
}

variable "create_block_volume" {
  description = "Boolean flag that defines whether or not to create and attach an additional Block Volume for persistent storage in case the compute instance is disabled"
  type        = bool
  default     = false
}

variable "block_volume_name" {
  type        = string
  description = "Name of the additional Block Volume to create. This will be used to check for an existing block volume if var.create_block_volume=false"
  default     = "FoundryPersistentVolume"
}

variable "block_volume_device" {
  description = "The device on the compute instance to use for attaching the block volume"
  type        = string
  default     = "/dev/oracleoci/oraclevdb"
}

variable "foundry_volume_mount_path" {
  description = "Directory on the compute instance that the block volume will be mounted to"
  type        = string
  default     = "/foundry"
}

variable "block_volume_size_in_gbs" {
  description = "Size in GBs of block volume that will be attached to the compute instance"
  type        = string
  default     = "50"
}

variable "memory_in_gbs" {
  description = "Compute instance memory size in GBs"
  type        = string
  default     = "6"
}

variable "ocpus" {
  description = "Compute instance processing unit count"
  type        = string
  default     = "1"
}

variable "image_id" {
  description = "Explicit image_id to use. Ubuntu 20.04 image ID found at https://docs.oracle.com/en-us/iaas/images/image/6013e506-ed35-4487-a3f7-122efbbbc6ad/"
  type        = string
  default     = ""
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key that you will use to connect to your instance"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key that you will use to connect to your instance"
  type        = string
}

variable "budget_amount" {
  description = "Target budget for account in USD"
  type        = string
  default     = "1"
}

variable "alert_rule_recipients" {
  description = "Email address to be notified if budget is exceeded"
  type        = string
}

variable "user_data_path" {
  description = <<-EOT
  Path to user_data file to be used by cloud-init to run custom scripts or provide custom cloud-init configuration.
  If not set, defaults to the included userdata.sh script of this project.
  NOTE: If you DON'T want to run a userdata script, set this variable to null OR an empty string ""
EOT
  type        = string
  default     = "./files/userdata.sh"
}

variable "foundry_credentials_path" {
  description = <<-EOT
  Path to file containing Foundry credentials in the following format 'username password'.
EOT
  type        = string
  default     = "./files/.foundry_creds"
  sensitive = true
}

variable "create_bucket" {
  type        = bool
  description = "Boolean flag that defines whether or not to create an Object Storage bucket"
  default     = false
}

variable "bucket_name" {
  description = "Name of Object Storage bucket to be created and used for storing files"
  type        = string
  default     = ""
}

variable "objectstorage_namespace" {
  description = "Object Storage namespace for the compartment/tenent in use"
  type        = string
  default     = ""
}

variable "file_uploads" {
  type        = list(string)
  description = "List of absolute paths to individual files that will be uploaded to the specified bucket"
  default     = []
}

variable "folder_uploads" {
  type        = list(string)
  description = <<-EOT
  List of absolute paths to folders that will be uploaded to the specified bucket.
  All files and folders nested underneath these paths will be recursively uploaded"
EOT
  default     = []
}

variable "post_provisioning_path" {
  type        = string
  description = <<-EOT
  Path to an optional post-provisioning script. If not set, defaults to the included post-provisioning.sh script of this project.
  NOTE: If you DON'T want to run a post-provisioning script, set this variable to null OR an empty string ""
EOT
  default     = "./files/post-provisioning.sh"
}

variable "domain" {
  type        = string
  description = <<-EOT
  (Optional) A domain name which will be used by the default post-provisioning script to enable access to the Foundry server via this hostname.
  NOTE: You must configure this hostname to point to the Foundry instance's public IP address manually unless you have accounted for configuring
  this programmatically in the userdata or post-provisioning scripts.
EOT
}

variable "other_env_vars" {
  type = map(string)
  description = "(Optional) A map of any additional environment variables to add to the compute instance."
  default = {}
  sensitive = true
}
