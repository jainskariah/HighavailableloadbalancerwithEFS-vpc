#!/bin/bash

read -p "The vpc Name for the Project =" Publicvpc

read -p "Please enter the cidrBlock =" vpcCidrBlock

read -p "Please enter the subnet associted with the cidrbloc = " subnetipadd


echo "Creating VPC and assign tag as $Publicvpc"

vpcId=`aws ec2 create-vpc --cidr-block $vpcCidrBlock --query 'Vpc.VpcId' --output text`

aws ec2 create-tags --resources $vpcId --tags Key=Name,Value=$Publicvpc

echo "Enabling DNS Hostname for the VPC"

aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-hostnames "{\"Value\":true}"

echo "Creting Internet Gateway for the VPC"

read -p "Choose InternetGateway name = " internetgateway

internetGatewayId=`aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text`

aws ec2 create-tags --resources $internetGatewayId --tags Key=Name,Value=$internetgateway

echo " Attaching the Internet Gateway to the VPC"

aws ec2 attach-internet-gateway --internet-gateway-id $internetGatewayId --vpc-id $vpcId

echo "Creating the Subnet associated with the VPC"
aws ec2 describe-availability-zones

read -p "Please mention the subnet = " datacentersubnet

subnetid=`aws ec2 create-subnet --vpc-id $vpcId --cidr-block $subnetipadd --availability-zone $datacentersubnet --query 'Subnet.SubnetId' --output text`

read -p "Please enter the subnet name = " Publicsubnet

aws ec2 create-tags --resources $subnetid --tags Key=Name,Value=$Publicsubnet

echo "Creating RouteTable for the VPC"

read -p "Please enter the router table name = " Publicrouter

RouteTable=`aws ec2 create-route-table --vpc-id $vpcId --query 'RouteTable.RouteTableId' --output text`

aws ec2 create-tags --resources $RouteTable --tags Key=Name,Value=$Publicrouter

echo "Setting up associated-route-table"

associationId=`aws ec2 associate-route-table --route-table-id $RouteTable --subnet-id $subnetid --query 'AssociationId' --output text`

echo "Creating a route Table"

aws ec2 create-route --route-table-id $RouteTable --destination-cidr-block 0.0.0.0/0 --gateway-id $internetGatewayId

aws ec2 associate-route-table --route-table-id $RouteTable --subnet-id $subnetid

aws ec2 modify-subnet-attribute --subnet-id $subnetid --map-public-ip-on-launch

sleep 5
echo "Second subnet creation"
sleep 5

echo "Creating the Subnet associated with the VPC"
read -p "Please enter the subnet associted with the cidrbloc = " subnetipadd2
aws ec2 describe-availability-zones
read -p "Please mention the subnet = " datacentersubnet2

subnetid2=`aws ec2 create-subnet --vpc-id $vpcId --cidr-block $subnetipadd2 --availability-zone $datacentersubnet2 --query 'Subnet.SubnetId' --output text`

read -p "Please enter the subnet name = " Publicsubnet2

aws ec2 create-tags --resources $subnetid2 --tags Key=Name,Value=$Publicsubnet2

echo "Creating RouteTable for the VPC"

read -p "Please enter the router table name = " Publicrouter2

RouteTable2=`aws ec2 create-route-table --vpc-id $vpcId --query 'RouteTable.RouteTableId' --output text`

aws ec2 create-tags --resources $RouteTable2 --tags Key=Name,Value=$Publicrouter2

echo "Setting up associated-route-table"

associationId2=`aws ec2 associate-route-table --route-table-id $RouteTable2 --subnet-id $subnetid2 --query 'AssociationId' --output text`

echo "Creating a route Table"

aws ec2 create-route --route-table-id $RouteTable2 --destination-cidr-block 0.0.0.0/0 --gateway-id $internetGatewayId

aws ec2 associate-route-table --route-table-id $RouteTable2 --subnet-id $subnetid2

echo "Two seubnet is created on above script execution"

echo "Creating a security group and assigining to vpc"

read -p "First security rule name = " Firstinstance1

read -p "Second security rule name = " Secondinstance2

securitygroupid=`aws ec2 create-security-group --group-name $Firstinstance1 --description "port 22 allowed" --vpc-id $vpcId --query 'GroupId' --output text`

aws ec2 authorize-security-group-ingress --group-id $securitygroupid --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $securitygroupid --protocol tcp --port 80 --cidr 0.0.0.0/0

securitygroupid2=`aws ec2 create-security-group --group-name $Secondinstance2 --description "port 22 allowed from internal" --query 'GroupId' --output text`

aws ec2 authorize-security-group-ingress --group-id $securitygroupid2 --protocol tcp --port 22 --cidr $subnetipadd
aws ec2 authorize-security-group-ingress --group-id $securitygroupid2 --protocol tcp --port 80 --cidr $subnetipadd
aws ec2 authorize-security-group-ingress --group-id $securitygroupid2 --protocol tcp --port 443 --cidr $subnetipadd
echo "Ec2 instance setup and launch"

aws ec2 modify-subnet-attribute --subnet-id $subnetid2 --map-public-ip-on-launch

read -p "Please mention the ec2instance name = " MyInstance1
echo "setting up ec2 instance with additional ebs and mounting"

aws ec2 run-instances --image-id ami-02ccb28830b645a41 --subnet-id $subnetid --key-name awsofficekey --security-group-ids $securitygroupid --instance-type t2.micro --placement AvailabilityZone=us-east-2a --block-device-mappings DeviceName=/dev/sdb,Ebs={VolumeSize=1} --count 1 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=clivolume}]' "ResourceType=instance,Tags=[{Key=Name,Value=$MyInstance1}]" --user-data file:///home/jain/install.txt

echo "Creating second instance"
read -p "Please mention the ec2instancename = " MyInstance2

aws ec2 run-instances --image-id ami-02ccb28830b645a41 --subnet-id $subnetid2 --key-name awsofficekey --security-group-ids $securitygroupid --instance-type t2.micro --placement AvailabilityZone=us-east-2b --block-device-mappings DeviceName=/dev/sdb,Ebs={VolumeSize=1} --count 1 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=clivolume}]' "ResourceType=instance,Tags=[{Key=Name,Value=$MyInstance2}]" --user-data file:///home/jain/install.txt

Instance1ID=`aws ec2 describe-instances --filters "Name=tag:Name,Values=$MyInstance1" --output text --query 'Reservations[*].Instances[*].InstanceId'`
Instance2ID=`aws ec2 describe-instances --filters "Name=tag:Name,Values=$MyInstance2" --output text --query 'Reservations[*].Instances[*].InstanceId'`

echo "The first Instance ID is $Instance1ID"
echo "The second Instance ID is $Instance2ID"
echo "list all availability zones to Create Load balancer"
aws ec2 describe-availability-zones

read -p "Please mention the subnet = " zone1
read -p "Please mention the subnet = " zone2
read -p "Please mention the subnet = " zone3

echo "Setting up Load-balancer"
read -p "Please mention the Loadbalancername = " loadbalancer

aws elb create-load-balancer --load-balancer-name $loadbalancer --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --subnets $subnetid
securityruleID=`aws elb describe-load-balancers --load-balancer-name $loadbalancer --query 'LoadBalancerDescriptions[*].SecurityGroups' --output text`


aws elb attach-load-balancer-to-subnets --load-balancer-name $loadbalancer --subnets $subnetid2 
#aws elb enable-availability-zones-for-load-balancer --load-balancer-name $loadbalancer --availability-zones $zone1 $zone2 $zone3

aws elb register-instances-with-load-balancer --load-balancer-name $loadbalancer --instances $Instance1ID $Instance2ID
aws elb configure-health-check --load-balancer-name $loadbalancer --health-check Target=HTTP:80/index.php,Interval=10,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3
aws elb modify-load-balancer-attributes --load-balancer-name $loadbalancer --load-balancer-attributes "{\"CrossZoneLoadBalancing\":{\"Enabled\":true}}"
