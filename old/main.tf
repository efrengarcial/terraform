provider "aws" {
  region                  = "us-east-1"
  shared_credentials_file = "/home/efren/.aws/credentials"
  profile                 = "terraform"
}

locals {
  instance-userdata = <<EOF
#!/bin/bash
export PATH=$PATH:/usr/local/bin
which pip >/dev/null
if [ $? -ne 0 ];
then
  echo 'PIP NOT PRESENT'
  if [ -n "$(which yum)" ]; 
  then
    yum install -y python-pip
  else 
    apt-get -y update && apt-get -y install python-pip
  fi
else 
  echo 'PIP ALREADY PRESENT'
fi
EOF
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "WordpressVPC"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]  
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
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

module "ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  
  name                   = "webServer"
  ami                    = "ami-035be7bafff33b6b6"
  instance_type          = "t2.micro"
  key_name               = "MyEC2KeyPair"
  monitoring             = false
  associate_public_ip_address = true
  vpc_security_group_ids = ["${module.web_dmz.this_security_group_id}" ]
  subnet_id              = "${element(module.vpc.public_subnets,0)}"
  user_data = "${local.instance-userdata}"

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

# *********************************************************************************************************************************************

resource "aws_db_subnet_group" "db_subnet_group" {
  name ="db_subnet_group"  
  description = "Database subnet group for demodb"
  subnet_ids  = ["${element(module.vpc.private_subnets,0)}","${element(module.vpc.private_subnets,1)}"]

   tags = {
    Terraform = "true"
    Environment = "dev"
  }
}


# **********************************************************************************************************************************************


module "mysql_rds" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "demodb"

  engine            = "mysql"
  engine_version    = "5.7.23"
  instance_class    = "db.t2.micro"
  allocated_storage = 5

  name     = "demodb"
  username = "user"
  password = "pegasso1"
  port     = "3306"

  #availability_zone = "us-east-1a"
  multi_az = true
  
  iam_database_authentication_enabled = false

  vpc_security_group_ids = ["${module.rdssg.this_security_group_id}"]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"
  backup_retention_period = 0       

  # Enhanced Monitoring - see example for details on how to create the role
  # by yourself, in case you don't want to create it automatically
  # monitoring_interval = "30"
  # monitoring_role_name = "MyRDSMonitoringRole"
  # create_monitoring_role = true
  
  create_db_subnet_group = false
  create_db_parameter_group = false
  create_db_option_group = false
  
  db_subnet_group_name = "db_subnet_group"
  parameter_group_name = "default.mysql5.7"
  option_group_name = "default:mysql-5-7"	
  
  
  # subnet group
  subnet_ids = ["${element(module.vpc.private_subnets,0)}","${element(module.vpc.private_subnets,1)}"]

  # DB parameter group
  family = "mysql5.7"

  # DB option group
  major_engine_version = "5.7"

  # Snapshot name upon DB deletion
  final_snapshot_identifier = "demodb"

  # Database Deletion Protection
  deletion_protection = false

  parameters = [
    {
      name = "character_set_client"
      value = "utf8"
    },
    {
      name = "character_set_server"
      value = "utf8"
    }
  ]

  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"

      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT"
        },
        {
          name  = "SERVER_AUDIT_FILE_ROTATIONS"
          value = "37"
        },
      ]
    },
  ]
  
  tags = {
    Terraform = "true"
    Environment = "dev"
  }

}

