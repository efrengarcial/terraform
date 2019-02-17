provider "aws" {
  region                  = "us-east-1"
  shared_credentials_file = "/home/efren/.aws/credentials"
  profile                 = "terraform"
}

terraform {
  backend "s3" {
    bucket = "terraform-eagl"
    key    = "frontend/terraform.tfstate"
    region = "us-east-1"
    profile  = "terraform"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config {
     bucket = "terraform-eagl"
     key    = "network/terraform.tfstate"
     region = "us-east-1"
     profile  = "terraform"
  }
}


locals {
  instance-userdata = <<EOF
#!/bin/bash
yum install httpd php php-mysql -y
cd /var/www/html
echo "healthy" > healthy.html
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/
rm -rf wordpress
rm -rf latest.tar.gz
chmod -R 755 wp-content
chown -R apache:apache wp-content
wget https://s3.amazonaws.com/bucketforwordpresslab-donotdelete/htaccess.txt
mv htaccess.txt .htaccess
chkconfig httpd on

EOF
}

resource "aws_iam_role" "wordpress_role" {
  name = "wordpress-role"

  assume_role_policy = "${file("assumerolepolicy.json")}"
}


resource "aws_iam_role_policy_attachment" "AmazonS3FullAccess" {
    role               = "${aws_iam_role.wordpress_role.name}"
    policy_arn         = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "wordpress_profile" {
  name  = "wordpress_profile"
  role = "${aws_iam_role.wordpress_role.name}"
}


module "ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  
  name                   = "webServer"
  ami                    = "ami-035be7bafff33b6b6"
  instance_type          = "t2.micro"
  key_name               = "MyEC2KeyPair"
  monitoring             = false
  associate_public_ip_address = true
  vpc_security_group_ids = ["${data.terraform_remote_state.network.web_dmz_security_group_id}" ]
  subnet_id              = "${data.terraform_remote_state.network.public_subnet_us_east_1a}"
  
 iam_instance_profile = "${aws_iam_instance_profile.wordpress_profile.name}"
  
  user_data = "${local.instance-userdata}"

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}
