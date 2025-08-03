output "nifi_public_ip" {
  description = "Public IP of the NiFi EC2"
  value       = aws_instance.nifi.public_ip
}

output "artifact_bucket" {
  description = "S3 bucket for NiFi ZIP"
  value       = aws_s3_bucket.nifi_artifacts.bucket
}
