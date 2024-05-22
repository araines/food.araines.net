# OpenID Connect for GitHub Actions
module "github-oidc" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "~> 1"

  create_oidc_provider = false
  oidc_provider_arn    = "arn:aws:iam::263804027495:oidc-provider/token.actions.githubusercontent.com" # reuse the blog oidc provider
  create_oidc_role     = true
  role_name            = "${var.site_name}-github-oidc"
  role_description     = "Role assumed by the ${var.site_domain} GitHub OIDC provider"

  repositories = ["araines/${var.repository}"]
  oidc_role_attach_policies = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    aws_iam_policy.deploy.arn,
  ]
}

#TODO: Make this more specific
data "aws_iam_policy_document" "deploy" {
  statement {
    actions = ["s3:*"]
    effect  = "Allow"
    resources = [
      "arn:aws:s3:::araines-tfstate",
      "arn:aws:s3:::araines-tfstate/${var.site_domain}/terraform.tfstate",
    ]
  }

  statement {
    not_actions = [
      "iam:*",
      "organizations:*",
      "account:*",
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:DeleteServiceLinkedRole",
      "iam:ListRoles",
      "organizations:DescribeOrganization",
      "account:ListRegions",
      "account:GetAccountInformation",
      "iam:GetRole",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetOpenIDConnectProvider",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:PassRole"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deploy" {
  name        = "${var.site_name}_Deploy"
  description = "Policy allowing GitHub Actions to deploy via terraform"
  policy      = data.aws_iam_policy_document.deploy.json
}
