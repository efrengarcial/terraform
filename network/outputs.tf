
output "web_dmz_security_group_id" {
  value = "${module.web_dmz.this_security_group_id}"
}
output "rdssg_security_group_id" {
  value = "${module.rdssg.this_security_group_id}"
}

output "public_subnet_us_east_1a" {
  value = "${element(module.vpc.public_subnets,0)}"
}

output "private_subnets_id" {
  value = "${module.vpc.public_subnets}"
}

