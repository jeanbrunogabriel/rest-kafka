variable "cidr" {
  type = string
}

variable "name" {
  type = string
}

variable "subnets" {
  type = map(object({
    cidr = string
  }))
}

variable "security_groups" {
  type = map(object({
    ingresses = list(object({
      from_port   = number
      to_port     = number
      protocol    = optional(string, "-1")
      cidr_blocks = list(string)
    }))
  }))
  default = {}
}
