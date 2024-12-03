#!/bin/bash

yum update -y

echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCYP1pKWWTdPoS9V6bzRDmYZ2DkwjltneDQ6z9ZkkhcJ/4tqqRPqDKDI5RFPev7aW1HoxOzEjrC9uQou6TIUZ7JzFxxk7CRpkz+lHCfnDmjIJ1hyb3h1xhW11y4BBpYraCS0Cqs/1QS0wIaEkmicj+EO1T5nB0dCdCeLosnbNFniedxRRn9oi/Rjvr5kh+DVtCKrM6oOJCf85UWmlRj5N8iwEAxQx2TquaJhSKAkZUZP4EiY8/wWzLYRMwBO6UkX4AEDmjD+t50v3mWxR3UQQqJ2ofB30QUQqhV1h3c/BKT+f3/DcAkGtFAJGX3vQEzYexlkmj6XYQG+dHaNLjAM9nY0bKlByvf1mIFNyfH3rMVj938dZjdbteBGrBnMAUmXsWTyWgosOYxay2NCpHGD5ac5BnejapU0v5TQfy42KI17rsKh5eJjgjYBAXlTl0rBw0gJTxEX4UbiitRLJFotNscFND91xBGDx6Es6mRPrDm+mHsP2tR+B2lSNZ8dZnLHEk= jeanbraga@jean >> /home/ec2-user/.ssh/authorized_keys

yum install -y docker
service docker start
usermod -a -G docker ec2-user

export TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

docker run -d  \
  --name broker \
  -e KAFKA_NODE_ID=1 \
  -e KAFKA_PROCESS_ROLES=broker,controller \
  -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://$PUBLIC_IP:9092 \
  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT \
  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093 \
  -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
  -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 \
  -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 \
  -e KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=0 \
  -e KAFKA_NUM_PARTITIONS=3 \
  -p 9092:9092 \
  apache/kafka:latest


