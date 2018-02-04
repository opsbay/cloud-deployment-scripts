resource "aws_efs_file_system" "qa-edocs" {
  creation_token = "qa-edocs"

  tags {
    Name = "qa-edocs"
  }
}

resource "aws_efs_mount_target" "qa-edocs" {
  file_system_id = "${aws_efs_file_system.qa-edocs.id}"
  subnet_id      = "${var.subnets[count.index]}"
  count          = "${length(var.subnets)}"
}

resource "aws_efs_file_system" "qa-client_files" {
  creation_token = "qa-client_files"

  tags {
    Name = "qa-client_files"
  }
}

resource "aws_efs_mount_target" "qa-client_files" {
  file_system_id = "${aws_efs_file_system.qa-client_files.id}"
  subnet_id      = "${var.subnets[count.index]}"
  count          = "${length(var.subnets)}"
}

resource "aws_efs_file_system" "parchment_sftp" {
  creation_token = "parchment_sftp"

  tags {
    Name = "parchment_sftp"
  }
}

resource "aws_efs_mount_target" "parchment_sftp" {
  file_system_id = "${aws_efs_file_system.parchment_sftp.id}"
  subnet_id      = "${var.subnets[count.index]}"
  count          = "${length(var.subnets)}"
}
