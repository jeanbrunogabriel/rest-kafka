terraform {
  source = "../../modules/compute"
}

dependency "vpc" {
  config_path  = "../vpc"
  mock_outputs = {
    vpc_id          = "mock_vpc_id"
    subnet_id       = "mock_subnet_id"
    security_groups = "mock_sg"
  }
}

include {
  path = find_in_parent_folders()
}

inputs = {
  name            = "server-kafka-1"
  subnet          = dependency.vpc.outputs.subnet.servers
  security_groups = [ dependency.vpc.outputs.security_groups.kafka_sg.id ] 
}
