resource "random_password" "database" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "database_url" {
  name        = "/${local.service_name}/database/url"
  description = "Database connection string for ${local.service_name} RDS instance."
  type        = "SecureString"
  value       = "postgresql://${aws_db_instance.postgres.username}:${random_password.database.result}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
}

resource "aws_security_group" "rds" {
  name        = "${local.service_name}-rds"
  description = "RDS Security group for ${local.service_name}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Allow postgres traffic from EC2 instances"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.service_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.service_name}-rds"
  }
}

resource "aws_db_subnet_group" "default" {
  name_prefix = "${local.service_name}-rds"
  subnet_ids  = data.aws_subnets.default.ids

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "postgres" {
  db_name                = local.service_name
  identifier             = local.service_name
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "14.4"
  instance_class         = "db.t3.micro"
  multi_az               = false
  password               = random_password.database.result
  port                   = 5432
  storage_encrypted      = true
  storage_type           = "gp2"
  username               = local.service_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.default.id
  skip_final_snapshot    = true
}
