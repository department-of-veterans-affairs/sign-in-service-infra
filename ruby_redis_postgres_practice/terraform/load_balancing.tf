resource "aws_lb" "service" {
  name            = local.service_name
  security_groups = [aws_security_group.service_lb.id]
  subnets         = data.aws_subnets.default.ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.service.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_ecs.arn
  }
}

resource "aws_lb_target_group" "service_ecs" {
  name = "${local.service_name}-ecs"

  deregistration_delay = 10
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = data.aws_vpc.default.id

  health_check {
    healthy_threshold   = 3
    interval            = 10
    path                = "/health"
    timeout             = 5
    unhealthy_threshold = 3
  }
}

resource "aws_security_group" "service_lb" {
  name   = "${local.service_name}-alb"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.service_name}-alb"
  }
}
