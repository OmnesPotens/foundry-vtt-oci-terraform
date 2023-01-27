[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Y8Y4HQWXE)
# Oracle Cloud Infrastructure (OCI) setup for Foundry VTT
This terraform code is meant to automatically build out the infrastructure you need to run a Foundry VTT instance in OCI. It was created to duplicate the instructions for creating an [Always Free OCI](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm) Foundry VTT installation found at https://foundryvtt.wiki/en/setup/hosting/always-free-oracle. At this point the code can optionally install and configure most of the software mentioned in the guide.

##### Automated:
  - [oci cli](https://github.com/oracle/oci-cli) installation and `instance_principal` authorization
- pm2, nvm, node, npm, nano and unzip installation and configuration
- FoundryVTT installation and configuration of latest stable release version
- Caddy reverse-proxy installation and configuration

You can review the included `userdata.sh`, `post-provisioning.sh` and `get_latest_fvtt.py` scripts for details on what is currently automated. Configuring a DNS for your Foundry instance is not handled due to the sheer variety of DNS options.


While I've attempted to configure the terraform config so that it conforms to the "Always Free Tier" requirements of OCI, *you are fully responsible for ensuring that no costs will be incurred*.  It is recommended to conduct a Cost Analysis after this code is deployed to ensure that all services are Always Free.  An OCI Budget and Alarm are set up as part of this code to facilitate this.

# Prerequisites
 - A valid license for [Foundry VTT](https://foundryvtt.com).
 - A new [Oracle OCI account](https://cloud.oracle.com).
 - A local installation of Terraform 1.0.8+.  Installation instructions may be found at https://learn.hashicorp.com/tutorials/terraform/install-cli
 - General understanding of Terraform, Cloud Infrastructure, Networking, Shell scripting and your Operating System.  I did all of this from a Linux workstation, it should work just fine in a Windows environment as well.

# Usage
1. Clone this repo to your system
2. Create an SSH key to use to access your instance.  This key pair will be used later to allow you to SSH into your new server so that you can set up the Foundry VTT software.  Store it wherever you store your SSH keys:
  - ssh-keygen -t rsa -N "" -b 2048 -C <your-ssh-key-name> -f <your-ssh-key-name>
3. Set up your system and Terraform for OCI - https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/tf-provider/01-summary.htm
  - Under "1. Prepare", follow "Create RSA Keys". Once you add them to Oracle, save the information under [DEFAULT] in your `~/.oci/config`, as you'll use that in a moment. NOTE: This is a separate key from the one you created in step 2.  You'll need them both.
4. Edit the "my-oci-conf.tfvars" file, supplying the values from the [DEFAULT] entry you copied in the previous step.
    Additionally, you'll find configuration settings for the OCI Shape, boot volume, memory, OCPUs, Ubuntu image ID, ssh_public_key path (this is the path for the key you created in step 2) and a variety of optional variables.  The settings in the example file will create a VM with an 50GB disk, 4 OCPUs, and 24GB Memory.  This uses up all of the available processor and memory resources of the Always Free Tier; adjust them according to your needs if you're trying to fit more stuff into this account.
5. Run `terraform init`, followed by `terraform apply -var-file=my-oci-conf.tfvars`.  If you have an understanding of terraform, review the plan to be sure it is as you expect. You'll have to answer "yes" for the proposed changes to go through.
   -  Wait a few minutes for Foundry to become available after the `terraform apply` succeeds


# What will probably happen
In my experience, it's hard to get OCI Free Tier resources - you'll probably get an error that says "Out of Capacity" when Terraform tries to create your compute instance.  The good news is that it should create the rest of the infrastructure, so you just need the compute resource.  If you're using bash, you can run the included "keeptrying.sh" script, which will try to create the compute resource every 60 seconds and will continue until it finds terraform's success message in the results, which will happen once your instance gets created and has finished fully provisioning.  This could take anywhere from hours to minutes, be patient!

# Terraform .tf files overview
availability-domains.tf:
  - creates a simple data resource for your availability domains that will be used by the other Terraform files

budget-monitor.tf:
  - creates a budget with a $1 threshold and an alert that will email the address included in my-oci-conf.tfvars

compute.tf:
  - creates the compute instance resource
  - waits for the cloud-init bootstrapper to finish running (this includes waiting for any userdata to finish)
  - optionally runs a post-provisioning script on the instance (controlled by an input variable)

identity.tf
  - creates a tag namespace and tag to mark the compute instance as a Foundry instance
  - creates a Dynamic Group which will include the created compute instance
  - creates an Identity Policy that authorizes any instances or users in the Dynamic Group to **read** and **use** various OCI services
    - NOTE: This enables usage of the oci cli tool to perform various functions as the `root` user in the included `userdata.sh` and `post-provisioning.sh` scripts. Do not remove this policy unless you do not require authenticated usage of the oci cli from the compute instance.

network.tf:
  - creates a networking infrastructure that will create a subnet (192.168.0.0/24) to hold your compute resource, an Internet Gateway, and some ingress rules that allow anyone (0.0.0.0) to communicate with your server over ports 22 (ssh), 80 (HTTP), 443 (HTTPS), and 30000 (Foundry), and the various WebRTC ports defined in the Foundry documentation

object-storage.tf
  - optionally creates an Object Storage Bucket (or uses an existing one) and Standard tier Object Storage Objects (controlled by input variables)
  - objects can be created in 2 ways:
    - supply a list of absolute **file** paths to `var.file_uploads`
    - supply a list of absolute **folder** paths to `var.folder_uploads` (All nested folders and files will be uploaded to the Object Storage Bucket)
  - Note: The Always Free tier only includes up to 20GB of combined Standard, Infrequent Access and Archive tier storage

persistent-volume.tf
  - optionally creates a Block Volume (controlled by an input variable) that will be attached, connected and mounted to the compute instance
  - creates a Backup Policy for the desired volume (uses the created Block Volume if the input variable is set to true, else uses the Boot Volume of the instance)

outputs.tf:
  - creates some data outputs

providers.tf:
  - uses the variables in my-oci-conf.tfvars to configure the OCI provider
  - creates various local variables using some complex logic
  - randomly selects from the list of Availability Domains in the OCI region

variables.tf:
  - establishes all the user variables for the other files

# Contact
If you have questions you can reach out to me at OmnesPotens#2683 on Discord.

# Credits
The initial legwork was done by MrDionysus#9673.  If it was not for MyDionysus' repository existing it would have taken quite a long time to get a handle
on how everything is meant to fit together in OCI and this huge update may not have happened otherwise.  Thanks for your work!
