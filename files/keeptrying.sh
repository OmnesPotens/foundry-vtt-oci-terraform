#!/bin/bash

# continue re-applying in different ADs until the compute instance is provisioned (and the full terraform succeeds)
while ! terraform apply -auto-approve --var-file=my-oci-conf.tfvars -replace=random_shuffle.ad | grep "Apply complete!"
do
  sleep 60
done

tf output
