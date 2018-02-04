resource "aws_waf_web_acl" "waf_acl_count" {
  name        = "tf-waf-stack-count"
  metric_name = "tfwafstackcount"

  default_action {
    type = "ALLOW"
  }

  rules {
    action {
      type = "ALLOW"
    }

    priority = 2
    rule_id  = "${var.cf-waf-stack-whitelist-rule}"
  }

  rules {
    action {
      type = "COUNT"
    }

    priority = 3
    rule_id  = "${var.cf-waf-stack-blacklist-rule}"
  }

  rules {
    action {
      type = "COUNT"
    }

    priority = 4
    rule_id  = "${var.cf-waf-stack-auto-block-rule}"
  }

  rules {
    action {
      type = "COUNT"
    }

    priority = 5
    rule_id  = "${var.cf-waf-stack-waf-ip-reputation-lists-rule-1}"
  }

  rules {
    action {
      type = "COUNT"
    }

    priority = 6
    rule_id  = "${var.cf-waf-stack-bad-bot-rule}"
  }

  rules {
    action {
      type = "COUNT"
    }

    priority = 7
    rule_id  = "${var.cf-waf-stack-waf-ip-reputation-lists-rule-2}"
  }

  rules {
    action {
      type = "COUNT"
    }

    priority = 8
    rule_id  = "${var.cf-waf-stack-sql-injection-rule}"
  }

  rules {
    action {
      type = "COUNT"
    }

    priority = 9
    rule_id  = "${var.cf-waf-stack-xss-rule}"
  }
}
