
resource "aws_iam_role" "fg_role" {
  name = "fg_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })


}

resource "aws_iam_policy" "fg_policy" {
  name        = "fg_policy"
  path        = "/"
  description = "FG aws_iam_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:Get*",
          "s3:List*"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::ukhsa-poc-temp-bucket/*"
      },
    ]
  })
}




resource "aws_iam_role_policy_attachment" "fg-attach" {
  role       = aws_iam_role.fg_role.name
  policy_arn = aws_iam_policy.fg_policy.arn
}

module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "1.14.0"

  create_bus = false

  create_role       = false
  role_name         = "dev-ecsTaskExecutionRole"
  attach_ecs_policy = true
  rules = {
    crons = {
      description         = "Trigger for a ECS"
      schedule_expression = "cron(59 23 * * ? *)"
    }
  }

  targets = {
    crons = [
      {
        name            = "orders"
        arn             = module.aws_ecs_cluster.cluster.arn
        attach_role_arn = aws_iam_role.fg_role.arn

        ecs_target = {
          launch_type         = "FARGATE"
          task_count          = 1
          task_definition_arn = aws_ecs_task_definition.main[each.key]
          network_configuration = { #unsure about this option but it was mandatory 
            subnets = ["subnet-0b97afd609a79dd1e", "subnet-0830990056289d692"]
          }
        }
      }
    ]

  }
}

