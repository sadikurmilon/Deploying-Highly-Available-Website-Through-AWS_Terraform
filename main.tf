# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
  access_key    = var.aws_access_key
  secret_key    = var.aws_secret_key
}

resource "aws_vpc" "lb-vpc" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
     tags={
         Name = "aws_vpc"
     }
}
/*
  Public Subnet1
*/
resource "aws_subnet" "ca-central-1a-public" {
    vpc_id = aws_vpc.lb-vpc.id

    cidr_block = var.public_subnet_cidr1
    availability_zone = "ca-central-1a"

    tags ={
        Name = "Public Subnet1"
       }
}
/*
  Public Subnet2
*/
resource "aws_subnet" "ca-central-1b-public" {
    vpc_id = aws_vpc.lb-vpc.id

    cidr_block = var.public_subnet_cidr2
    availability_zone = "ca-central-1b"

    tags ={
        Name = "Public Subnet2"
       }
}
/*
  Private Subnet1
*/
resource "aws_subnet" "ca-central-1a-private" {
    vpc_id = aws_vpc.lb-vpc.id

    cidr_block = var.private_subnet_cidr1
    availability_zone = "ca-central-1a"

     tags ={
         Name = "Private Subnet1"
      }
}
/*
  Private Subnet2
*/
resource "aws_subnet" "ca-central-1b-private" {
    vpc_id = aws_vpc.lb-vpc.id

    cidr_block = var.private_subnet_cidr2
    availability_zone = "ca-central-1b"

     tags ={
         Name = "Private Subnet2"
      }
}

resource "aws_internet_gateway" "lb-igw" {
    vpc_id = aws_vpc.lb-vpc.id
}
resource "aws_route_table" "ca-central-1a-public" {
    vpc_id = aws_vpc.lb-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.lb-igw.id
    }

     tags {
         Name = "AWS_Route_table1"
     }
}

resource "aws_route_table_association" "ca-central-1a-public" {
    subnet_id = aws_subnet.ca-central-1a-public.id
    route_table_id = aws_route_table.ca-central-1a-public.id
}
resource "aws_route_table" "ca-central-1b-public" {
    vpc_id = aws_vpc.lb-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.lb-igw.id
    }

     tags {
         Name = "Aws_Route_Table2"
     }
}

resource "aws_route_table_association" "ca-central-1b-public" {
    subnet_id = aws_subnet.ca-central-1b-public.id
    route_table_id = aws_route_table.ca-central-1b-public.id
}

/*
  NAT Instance
*/
resource "aws_security_group" "web-sg" {
    name = "gfngn"
    description = "Allow traffic to pass from the private subnet to the internet"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    

    vpc_id = aws_vpc.lb-vpc.id
    

     tags ={
         Name = "LB-SG"
     }
}

resource "aws_instance" "web1" {
    ami = "ami-096d77a47ff179807" # this is a special ami preconfigured to do NAT
    availability_zone = "ca-central-1a"
    instance_type = "t2.micro"
    user_data = <<EOF
		#! /bin/bash
        
		echo <h1> Sadikur server</h1> >> /var/html/index
	EOF
    key_name = var.aws_key_name
    vpc_security_group_ids = [aws_security_group.web-sg.id]
    subnet_id = aws_subnet.ca-central-1a-private.id
    associate_public_ip_address = false
    source_dest_check = false

     tags {
         Name = "Web Server1"
     }
}
resource "aws_instance" "web2" {
    ami = "${lookup(var.amis, var.aws_region)}"
    availability_zone = "ca-central-1b"
    instance_type = "t2.micro"
    key_name = "${var.aws_key_name}"
    vpc_security_group_ids = ["${aws_security_group.web-sg.id}"]
    subnet_id = "${aws_subnet.ca-central-1b-private.id}"
    associate_public_ip_address = false
    source_dest_check = false


     tags {
         Name = "Web Server 2"
     }
}
resource "aws_elb" "test-lb" {
  name = "ELB"
  security_groups = [aws_security_group.lb-sg.id]
  instances = [aws_instance.web1.id, aws_instance.web2.id]
  subnets = [aws_subnet.ca-central-1a-public.id,aws_subnet.ca-central-1b-public.id]
  

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port      = 8080
    instance_protocol  = "http"
    lb_port            = 8080
    lb_protocol        = "http"
    
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/index.html"
    interval            = 5
  }

  
  
  tags = {
    Name = "ELB-TEST"
  }
}
resource "aws_security_group" "lb-sg" {
    name = "vpc_web"
    description = "Allow incoming HTTP connections."

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    

    vpc_id = "${aws_vpc.lb-vpc.id}"

     tags={
         Name = "LB-SG221"
     }
}








