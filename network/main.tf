provider "aws" {
  region                  = "us-east-1"
  shared_credentials_file = "/home/efren/.aws/credentials"
  profile                 = "terraform"
}

terraform {
  backend "s3" {
    bucket = "terraform-eagl"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
    profile  = "terraform"
  }
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "WordpressVPC"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]  
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false
  single_nat_gateway = false
  one_nat_gateway_per_az = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "web_dmz" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "web-dmz"  
  vpc_id      = "${module.vpc.vpc_id}"
 
  ingress_with_cidr_blocks = [
    {
      rule        = "http-80-tcp"     
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
 egress_with_cidr_blocks =  [
    {
      rule        = "all-all"     
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  
}

module "rdssg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "rdssg"  
  vpc_id      = "${module.vpc.vpc_id}"

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "mysql-tcp"
      source_security_group_id = "${module.web_dmz.this_security_group_id}"
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1
  
}



