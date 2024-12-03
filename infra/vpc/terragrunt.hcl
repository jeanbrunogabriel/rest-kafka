terraform {
  source = "../../modules/vpc"
}


include {
  path = find_in_parent_folders()
}

inputs = {
  name    = "rest-kafka"
  cidr    = "10.0.0.0/16" 
  subnets = {
    servers = {
      cidr = "10.0.0.0/24" 
    }
  }
  security_groups = {
    kafka_sg = {
      ingresses = [{
        from_port   = 22 
        to_port     = 22        
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      },
      {
        from_port   = 9092
        to_port     = 9092
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }]
    }
    rest_sg = {
      ingresses = [{
        from_port   = 22 
        to_port     = 22        
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      },
      {
        from_port   = 8080
        to_port     = 8080      
        protocol    = "tcp"
        cidr_blocks = ["177.182.106.49/32"]
      }]
    }
  }
}
