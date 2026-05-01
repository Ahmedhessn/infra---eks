output "instances" {
  value = {
    master = {
      id         = aws_instance.master.id
      private_ip = aws_instance.master.private_ip
    }
    workers = [
      for w in aws_instance.worker : {
        id         = w.id
        private_ip = w.private_ip
      }
    ]
  }
}

output "security_group_id" {
  value = aws_security_group.k8s.id
}

