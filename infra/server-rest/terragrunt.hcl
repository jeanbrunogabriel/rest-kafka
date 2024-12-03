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

dependency "server-kafka" {
  config_path  = "../server-kafka"
  mock_outputs = {
    public_ip = "mock_public_ip"
  }
}

include {
  path = find_in_parent_folders()
}

inputs = {
  name            = "server-rest-1"
  user_data_vars  = { "kafka_public_ip" = dependency.server-kafka.outputs.public_ip }
  subnet          = dependency.vpc.outputs.subnet.servers
  security_groups = [ dependency.vpc.outputs.security_groups.rest_sg.id ] 
}
