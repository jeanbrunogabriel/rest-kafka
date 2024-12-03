variable "name" {
  type = string
}

variable "subnet" {
  type = string
}

variable "associate_public_ip_address" {
  type    = bool
  default = true
}

variable "security_groups" {
  type = list(string)
}

variable "user_data_vars" {
  type    = any
  default = {}
}
