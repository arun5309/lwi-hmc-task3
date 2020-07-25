provider "aws" {
	region="ap-south-1"
	profile="adminuser_profile"
}


# Main vpc
resource "aws_vpc" "main_vpc" {
	cidr_block="192.168.0.0/16"
	instance_tenancy="default"

	tags = {
		Name="main_vpc"
	}
}

# Private subnet
resource "aws_subnet" "private_subnet" {
	vpc_id=aws_vpc.main_vpc.id
	cidr_block="192.168.0.0/24"
	availability_zone="ap-south-1a"
	tags = {
		Name="private_subnet"
	}
}

# Public subnet
resource "aws_subnet" "public_subnet" {
	vpc_id=aws_vpc.main_vpc.id
	cidr_block="192.168.1.0/24"
	map_public_ip_on_launch="true"
	availability_zone="ap-south-1b"
	tags = {
		Name="public_subnet"
	}
}

# Internet gateway
resource "aws_internet_gateway" "main_ig" {
	vpc_id=aws_vpc.main_vpc.id
	tags = {
		Name="main_ig"
	}
}

# Routing table
resource "aws_route_table" "main_rt" {
	vpc_id=aws_vpc.main_vpc.id
	tags = {
		Name="main_rt"
	}
}

# Associate routing table

resource "aws_route" "priv_route" {
	route_table_id=aws_route_table.main_rt.id
	destination_cidr_block="0.0.0.0/0"
	gateway_id=aws_internet_gateway.main_ig.id
}

resource "aws_route_table_association" "pub_sn_assoc" {
	subnet_id=aws_subnet.public_subnet.id
	route_table_id=aws_route_table.main_rt.id
}

# RSA keypair for ssh

resource "tls_private_key" "main_key" {
	algorithm="RSA"
}

module "key_pair" {
	source="terraform-aws-modules/key-pair/aws"
	key_name="main_key"
	public_key=tls_private_key.main_key.public_key_openssh
}

# Security group

# Security group for worpress

resource "aws_security_group" "wp_sg" {
	name="wp_sg"
	vpc_id=aws_vpc.main_vpc.id
	
	ingress {
		description="Allow ssh on port 22"
		from_port=0
		to_port=22
		protocol="tcp"
		cidr_blocks=["0.0.0.0/0"]
	}

	ingress {
		description="Allow http on port 80"
		from_port=0
		to_port=80
		protocol="tcp"
		cidr_blocks=["0.0.0.0/0"]
	}

	egress {
		from_port=0
		to_port=0
		protocol="-1"
		cidr_blocks=["0.0.0.0/0"]
	}
	
	tags = {
		Name="wp_sg"
	}
}

# Security group for mysql

resource "aws_security_group" "mysql_sg" {
	name="mysql_sg"
	vpc_id=aws_vpc.main_vpc.id
	
	ingress {
		description="Allow ssh on port 22"
		from_port=22
		to_port=22
		protocol="tcp"
		cidr_blocks=[aws_subnet.public_subnet.cidr_block]
	}

	ingress {
		description="TLS on port 3306"
		from_port=3306
		to_port=3306
		protocol="tcp"
		cidr_blocks=[aws_subnet.public_subnet.cidr_block]
	}

	ingress {
		from_port=-1
		to_port=-1
		protocol="icmp"
		cidr_blocks=[aws_subnet.public_subnet.cidr_block]
	}

	egress {
		from_port=0
		to_port=0
		protocol="-1"
		cidr_blocks=["0.0.0.0/0"]
	}

	tags = {
		Name="mysql_sg"
	}
}

# EC2 instances

# EC2 instance for worpress

resource "aws_instance" "wp_instance" {
	ami="ami-004a955bfb611bf13"
	instance_type="t2.micro"
	subnet_id=aws_subnet.public_subnet.id
	vpc_security_group_ids=[aws_security_group.wp_sg.id]
	key_name="main_key"
	tags = {
		Name="wp_instance"
	}
}

# EC2 instance for mysql

resource "aws_instance" "mysql_instance" {
	ami="ami-08706cb5f68222d09"
	instance_type="t2.micro"
	subnet_id=aws_subnet.private_subnet.id
	vpc_security_group_ids=[aws_security_group.mysql_sg.id]
	key_name="main_key"
	tags = {
		Name="mysql_instance"
	}
}

