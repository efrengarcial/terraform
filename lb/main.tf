provider "aws" {
  region                  = "us-east-1"
  shared_credentials_file = "/home/efren/.aws/credentials"
  profile                 = "terraform"
}

terraform {
  backend "s3" {
    bucket = "terraform-eagl"
    key    = "lb/terraform.tfstate"
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

data "terraform_remote_state" "frontend" {
  backend = "s3"

  config {
     bucket = "terraform-eagl"
     key    = "frontend/terraform.tfstate"
     region = "us-east-1"
     profile  = "terraform"
  }
}


module "elb_http" {
  source = "terraform-aws-modules/elb/aws"

  name = "wordpres-elb"

  subnets  = ["${data.terraform_remote_state.network.public_subnets_id}"]

  security_groups = ["${data.terraform_remote_state.network.web_dmz_security_group_id}"]


  internal        = false

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "HTTP"
      lb_port           = "80"
      lb_protocol       = "HTTP"
    },
  ]

  health_check = [
    {
      target              = "HTTP:80/healthy.html"
      healthy_threshold   = 3
      unhealthy_threshold = 2
      timeout             = 2
      interval            = 5
    },
  ]

 
  // ELB attachments
  number_of_instances = 1
  instances           = ["${data.terraform_remote_state.frontend.webServer}"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}
