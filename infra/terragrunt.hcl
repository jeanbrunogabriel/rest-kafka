remote_state {
    backend = "s3"
    config = {
        bucket = "rest-kafka-bucket"
        region = "us-east-1"
        key = "${path_relative_to_include()}/terraform.tfstate"
        dynamodb_table = "instance-terraform-lock"
        encrypt = true
        profile = "jeanbraga"
        disable_bucket_update = true 
    }
}
