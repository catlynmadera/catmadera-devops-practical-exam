output "ELB_DNS_Name" {
  value = "${aws_lb.ec2-instance-elb.dns_name}"
}
