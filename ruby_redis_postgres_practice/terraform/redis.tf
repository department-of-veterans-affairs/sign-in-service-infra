resource "aws_ssm_parameter" "redis_url" {
  name        = "/${local.service_name}/redis/url"
  description = "Redis connection string for ${local.service_name} redis instance."
  type        = "SecureString"
  value       = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}"
}

resource "aws_elasticache_subnet_group" "redis" {
  description = "ElastiCache ${local.service_name}-redis subnet"
  name        = "${local.service_name}-redis"
  subnet_ids  = data.aws_subnets.default.ids
}

resource "aws_security_group" "redis" {
  description = "ElastiCache Redis ${local.service_name} Security Group"
  name        = "${local.service_name}-redis"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${local.service_name}-redis"
  }
}

resource "aws_security_group_rule" "redis_service" {
  security_group_id        = aws_security_group.redis.id
  type                     = "ingress"
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.service_ec2.id
  from_port                = 6379
  to_port                  = 6379
}

resource "aws_elasticache_replication_group" "redis" {
  description                = "Replication group for ${local.service_name}"
  replication_group_id       = local.service_name
  engine                     = "redis"
  engine_version             = "7.0"
  parameter_group_name       = "default.redis7"
  node_type                  = "cache.t3.micro"
  num_cache_clusters         = 0
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  lifecycle {
    ignore_changes = [num_cache_clusters]
  }
}
