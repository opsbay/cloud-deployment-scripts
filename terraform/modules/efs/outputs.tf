output "edocs_mount_target" {
  value = "${aws_efs_mount_target.qa-edocs.0.dns_name}"
}

output "client_files_mount_target" {
  value = "${aws_efs_mount_target.qa-client_files.0.dns_name}"
}

output "parchment_sftp_mount_target" {
  value = "${aws_efs_mount_target.parchment_sftp.0.dns_name}"
}
