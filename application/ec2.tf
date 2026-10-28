data "aws_ssm_parameter" "ubuntu_ami" {
  name = var.ec2_ssm_ami_path
}

resource "aws_instance" "app" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = var.ec2_instance_type

  subnet_id              = aws_subnet.public.id
  iam_instance_profile   = aws_iam_instance_profile.app_ec2.name
  vpc_security_group_ids = [aws_security_group.app.id]

  associate_public_ip_address = true
  monitoring                  = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ec2_root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${local.resource_prefix}-root"
    }
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y software-properties-common

    add-apt-repository -y universe
    apt-get update

    apt-get install -y \
      docker.io \
      docker-compose-v2 \
      docker-buildx \
      git

    systemctl enable --now docker

    mkdir -p /opt/videoapp
    chown ubuntu:ubuntu /opt/videoapp
  EOF

  tags = {
    Name = "${local.resource_prefix}-ec2"
  }

  depends_on = [
    aws_route_table_association.public,
    aws_iam_role_policy_attachment.ssm_core,
    aws_iam_role_policy_attachment.app_runtime
  ]

  lifecycle {
    ignore_changes = [ami]
  }
}