output "url" {
  value = "http://${aws_lb.service.dns_name}/"
}
