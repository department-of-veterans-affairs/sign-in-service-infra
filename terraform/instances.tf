locals {
  ec2_user_data = templatefile("files/userdata.sh", {
    ecs_cluster_name = local.service_name,
  })
}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

data "aws_ami" "ecs" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ecs_ami.value]
  }

  owners = ["amazon"]
}

resource "aws_launch_template" "service" {
  name                                 = local.service_name
  image_id                             = data.aws_ami.ecs.image_id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t3.nano"
  ebs_optimized                        = true
  vpc_security_group_ids               = [aws_security_group.service_ec2.id]
  user_data                            = base64encode(local.ec2_user_data)

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 20
      volume_type           = "gp2"
      delete_on_termination = "true"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.service_ec2.name
  }

  monitoring {
    enabled = true
  }
}

data "aws_default_tags" "asg" {}

resource "aws_autoscaling_group" "service" {
  name_prefix               = local.service_name
  target_group_arns         = [aws_lb_target_group.service_ecs.arn]
  desired_capacity          = 2
  min_size                  = 2
  max_size                  = 2
  vpc_zone_identifier       = data.aws_subnets.default.ids
  health_check_grace_period = 60
  health_check_type         = "EC2"
  termination_policies      = ["OldestLaunchTemplate"]

  launch_template {
    id      = aws_launch_template.service.id
    version = aws_launch_template.service.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  lifecycle {
    ignore_changes        = [desired_capacity, load_balancers, target_group_arns]
    create_before_destroy = true
  }

  dynamic "tag" {
    for_each = data.aws_default_tags.asg.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.service.id
  lb_target_group_arn    = aws_lb_target_group.service_ecs.arn
}

resource "aws_security_group" "service_ec2" {
  name        = "${local.service_name}-ec2"
  description = "${local.service_name} EC2"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${local.service_name}-ec2"
  }
}

resource "aws_security_group_rule" "allow_from_lb" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "TCP"
  source_security_group_id = aws_security_group.service_lb.id
  security_group_id        = aws_security_group.service_ec2.id
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.service_ec2.id
}

resource "aws_iam_instance_profile" "service_ec2" {
  name = "service-ec2"
  role = aws_iam_role.service_ec2.name
}

resource "aws_iam_role" "service_ec2" {
  name        = "${local.service_name}-ec2"
  description = "Allow ${local.service_name} EC2 instances access to AWS resources"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${local.service_name}-ec2"
  }
}

resource "aws_iam_role_policy_attachment" "service_ecs_container_role" {
  role       = aws_iam_role.service_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
