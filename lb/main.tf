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


resource "aws_lb" "alb" {  
  name            = "alb"  
  subnets         = ["${data.terraform_remote_state.network.public_subnets_id}"]
  security_groups = ["${data.terraform_remote_state.network.web_dmz_security_group_id}"]
  internal        = false 
  idle_timeout    = 60   
  tags = {
    Terraform = "true"
    Environment = "dev"
  } 
}

resource "aws_lb_target_group" "alb_target_group" {  
  name     = "alb-target-group"  
  port     = "80"  
  protocol = "HTTP"  
  vpc_id      = "${data.terraform_remote_state.network.vpc_id}"
 
  tags {    
    name = "alb_target_group"
	Terraform = "true"
    Environment = "dev"
  }   
  stickiness {    
    type            = "lb_cookie"    
    cookie_duration = 1800    
    enabled         = true 
  }   
  health_check {    
    healthy_threshold   = 3    
    unhealthy_threshold = 2    
    timeout             = 2    
    interval            = 5    
    path                = "/healthy.html"    
    port                = 80
  }
}

resource "aws_lb_listener" "alb_listener" {  
  load_balancer_arn = "${aws_lb.alb.arn}"  
  port              = 80  
  protocol          = "HTTP"
  
  default_action {    
    target_group_arn = "${aws_lb_target_group.alb_target_group.arn}"
    type             = "forward"  
  }
}

