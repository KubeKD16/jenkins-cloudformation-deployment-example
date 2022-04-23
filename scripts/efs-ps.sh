#!/bin/bash
EKS_CLUSTER="dev-jenkins-eks"
EKS_VPC_ID=$(aws eks describe-cluster --name $EKS_CLUSTER --query "cluster.resourcesVpcConfig.vpcId" --output text)

echo $EKS_VPC_ID
EKS_VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids $EKS_VPC_ID --query "Vpcs[].CidrBlock" --output text)

echo $EKS_VPC_CIDR
aws ec2 create-security-group --group-name efs-nfs-sg --description "Allow NFS traffic for EFS" --vpc-id $EKS_VPC_ID --output text

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups | jq '.SecurityGroups[] | select(.GroupName | contains("efs-nfs-sg")) | .GroupId' | sed "s/\"//g")
echo $SECURITY_GROUP_ID

aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 2049 --cidr $EKS_VPC_CIDR --output text

aws efs create-file-system --encrypted --tags Key=Name,Value=jenkins-eks-efs --region us-east-1

FILESYSTEM_ID=$(aws efs describe-file-systems | jq '.FileSystems[] | select(.Name | contains("jenkins-eks-efs")) | .FileSystemId' | sed "s/\"//g")

echo $FILESYSTEM_ID

subnets=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=$EKS_VPC_ID --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' | sed "s/\"//g")
echo $subnets

for subnet in ${subnets}; do
    # echo ${subnet/,}
  aws efs create-mount-target \
    --file-system-id $FILESYSTEM_ID \
    --security-group  $SECURITY_GROUP_ID \
    --subnet-id ${subnet/,} \
    --region us-east-1
done


# kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/dev/?ref=master"
# kubectl get csidrivers.storage.k8s.io







