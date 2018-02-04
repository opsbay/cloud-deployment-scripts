data "aws_route53_zone" "testapp_zone" {
  name = "${lookup(var.domain, var.aws-environment, var.domain["hobsons-naviancedev"])}."
}

# A DNS zone local to our VPC which will contain entries on the Naviance internal network
# since we can't delegate a zone with a private own nameservers. See:
# http://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html
resource "aws_route53_zone" "local_naviance_zone" {
  name   = "local.naviance.com."
  vpc_id = "${module.vpc.vpc_id}"
}

# The dev-environment Naviance mail server
resource "aws_route53_record" "mailcatcher_sjc_address" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "sjc2iu-mailcatcher01.${aws_route53_zone.local_naviance_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.dns_mailcatcher_sjc_address}"]
}

# The dev-environment Active Directory server
resource "aws_route53_record" "active_directory_sjc_address" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "ads-sjc.${aws_route53_zone.local_naviance_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.dns_active_directory_sjc_address}"]
}

# The prod-environment Active Directory server
resource "aws_route53_record" "active_directory_iad_address" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "ads-iad.${aws_route53_zone.local_naviance_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.dns_active_directory_iad_address}"]
}

# The prod-environment Naviance mail server
resource "aws_route53_record" "strongmail_iad_address" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "smlb.${aws_route53_zone.local_naviance_zone.name}"
  type    = "${var.aws-environment == "hobsons-naviancedev" ? "CNAME" : "A"}"
  ttl     = "300"
  records = ["${var.aws-environment == "hobsons-naviancedev" ? var.dns_strongmail_dev_iad_address : var.dns_strongmail_iad_address}"]
}

# The prod-environment eDocs Multiple Transcript Manager server
resource "aws_route53_record" "edocs_mtm_iad_address" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "iad1kpu-edocsmtm02.${aws_route53_zone.local_naviance_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.dns_edocs_mtm_iad_address}"]
}

# The prod-environment eDocs Upload API server
resource "aws_route53_record" "edocs_srcv_iad_address" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "iad1kpu-edocsrcv01.${aws_route53_zone.local_naviance_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.dns_edocs_srcv_iad_address}"]
}

# The prod-environment eDocs Internally Cached Data server
resource "aws_route53_record" "edocs_inst_iad_address" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "iad1kpu-edocsinst01.${aws_route53_zone.local_naviance_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.dns_edocs_inst_iad_address}"]
}

# The prod-environment eDocs Load Balancer (DC)
resource "aws_route53_record" "edocs_load_balancer_address" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "iad1kpu-edocs-lb.${aws_route53_zone.local_naviance_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.dns_edocs_load_balancer_address}"]
}

# The prod-environment eDocs MongoDB 01 (DC)
resource "aws_route53_record" "edocs_mongodb_01_address" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "iad1kpd-edocsmongo01.${aws_route53_zone.local_naviance_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.dns_edocs_mongodb_01_address}"]
}

# The prod-environment eDocs MongoDB 02 (DC)
resource "aws_route53_record" "edocs_mongodb_02_address" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "iad1kpd-edocsmongo02.${aws_route53_zone.local_naviance_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.dns_edocs_mongodb_02_address}"]
}

# The prod-environment eDocs MongoDB 03 (DC)
resource "aws_route53_record" "edocs_mongodb_03_address" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "iad1kpd-edocsmongo03.${aws_route53_zone.local_naviance_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.dns_edocs_mongodb_03_address}"]
}

# The prod-environment sftp server (DC)
resource "aws_route53_record" "sftp_parchments_load_balancer_address" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "parchment.${aws_route53_zone.local_naviance_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.dns_parchment_prod_address}"]
}

# The prod-environment birt server
resource "aws_route53_record" "birt_prod_cname" {
  zone_id = "${aws_route53_zone.local_naviance_zone.zone_id}"
  name    = "birt.${aws_route53_zone.local_naviance_zone.name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["tf-birt-production.papaya.naviance.com"]
}
