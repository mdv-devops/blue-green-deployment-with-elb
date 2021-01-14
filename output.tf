
output "load_balancer_url" {
  value = aws_elb.lb.dns_name
}

output "cert_id" {
  value = data.aws_acm_certificate.cert.id
}

output "lb_zone_id" {
  value = aws_elb.lb.zone_id
}
