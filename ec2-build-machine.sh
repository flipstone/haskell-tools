#!/usr/bin/env bash

# image: amzn2-ami-kernel-5.10-hvm-2.0.20230119.1-arm64-gp2

source ec2-build-machine.env

command=$1
shift

show_public_dns() {
  aws ec2 describe-instances --instance-ids "$1" \
    --query 'Reservations[0].Instances[0].PublicDnsName' \
    --output text
}

case "$command" in
  run)
    aws ec2 run-instances \
      --image-id ami-084237e82d7842286 \
      --subnet-id $subnet_id \
      --instance-type a1.xlarge \
      --key-name $key_name \
      --security-group-ids $security_group_ids  \
      --associate-public-ip-address \
      --count 1 \
      --block-device-mappings '{"DeviceName": "/dev/xvda", "Ebs": {"VolumeSize": 64}}' \
      --query 'Instances[0].InstanceId' \
      --output text
     ;;

  terminate)
     aws ec2 terminate-instances --instance-ids "$@"
     ;;

  show-public-dns)
    show_public_dns "$1"
    ;;

  connect)
    public_dns=$(show_public_dns "$1")
    ssh -i "$key_file" "ec2-user@$public_dns"
    ;;

  *)
    echo "Commands run|terminate"
    exit 1
    ;;
esac
