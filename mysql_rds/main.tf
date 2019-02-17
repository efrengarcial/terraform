provider "aws" {
  region                  = "us-east-1"
  shared_credentials_file = "/home/efren/.aws/credentials"
  profile                 = "terraform"
}

terraform {
  backend "s3" {
    bucket = "terraform-eagl"
    key    = "mysql_rds/terraform.tfstate"
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


resource "aws_db_subnet_group" "db_subnet_group" {
  name ="db_subnet_group"  
  description = "Database subnet group for demodb"
  subnet_ids  = ["${data.terraform_remote_state.network.private_subnets_id}"]

   tags = {
    Terraform = "true"
    Environment = "dev"
  }
}


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

  vpc_security_group_ids = ["${data.terraform_remote_state.network.rdssg_security_group_id}"]

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
  subnet_ids =  ["${data.terraform_remote_state.network.private_subnets_id}"]

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

