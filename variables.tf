variable "access_key" {
default = "XXXTEAHT76NXXXXXX"                                    #sample values only
}
variable "secret_key" {
default = "XXXX3EYMQJQEE0TCqjXXXXXXXXXXXXX"                      #sample values only
}

variable "aws_default_user" {
  default = "ec2-user"
}

variable "region" {
  default = "us-east-1"                                         #Suppose US-East-1 Region or N.Virginia
}

variable "ami-id" {
  default = "ami-XXXX5b7915ba****"                              #sample only - ami needed is for Ubuntu Linux 20
}

variable "instance-type" {
  default = "t2.micro"
}

variable "private_key" {
default = "cat-ec2-instance.key"
}

variable "public_key" {
default = "cat-ec2-instance.pub"
}


variable "availability_zone" {
  default = "us-east-1"
}

variable "emails" {
  default = "catlynmadera11@gmail.com"
}

variable "environment_tag" {
  description = "Environment Tag"
  default = "DEV"                                                         #suppose its provision on Dev Environment
}
