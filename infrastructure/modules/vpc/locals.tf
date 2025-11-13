# Network ACL rules for public and private subnets
locals {
  public_network_acls = {
    public_inbound_http = [
      {
        description = "allow inbound HTTP traffic"
        rule_number = 100
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
    public_inbound_https = [
      {
        description = "allow inbound HTTPS traffic"
        rule_number = 110
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
    public_inbound_ssh = [
      {
        description = "allow inbound SSH traffic"
        rule_number = 120
        rule_action = "allow"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_block  = var.personal_ip
      },
    ]
    public_inbound_other = [
      {
        description = "deny all other inbound traffic"
        rule_number = 130
        rule_action = "deny"
        from_port   = 0
        to_port     = 0
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      }
    ]
    public_outbound_all = [
      {
        description = "allow all outbound traffic"
        rule_number = 100
        rule_action = "allow"
        from_port   = 0
        to_port     = 0
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      }
    ]
  }
  
  private_network_acls = {
    private_inbound_all = [
      {
        description = "allow inbound traffic from within the VPC"
        rule_number = 100
        rule_action = "allow"
        from_port   = 0
        to_port     = 0
        protocol    = "tcp"
        cidr_block  = var.vpc_cidr
      }
    ],
    private_inbound_other = [
      {
        description = "deny all other inbound traffic"
        rule_number = 110
        rule_action = "deny"
        from_port   = 0
        to_port     = 0
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      }
    ],
    private_outbound_all = [
      {
        description = "allow all outbound traffic"
        rule_number = 100
        rule_action = "allow"
        from_port   = 0
        to_port     = 0
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      }
    ]
  }
}