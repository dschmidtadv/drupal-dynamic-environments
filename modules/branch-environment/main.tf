locals {
  # Sanitize branch name for use in DNS (replace underscores with hyphens, lowercase)
  dns_safe_branch = lower(replace(var.branch_name, "_", "-"))

  # Full hostname for this branch
  hostname = "${local.dns_safe_branch}.${var.domain_suffix}"

  # Unique identifier for this branch environment
  env_identifier = "${var.project_name}-${local.dns_safe_branch}"
}

# CloudWatch Log Group for this branch
resource "aws_cloudwatch_log_group" "branch" {
  name              = "/ecs/${local.env_identifier}"
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name   = local.env_identifier
      Branch = var.branch_name
    }
  )
}

# ECS Task Definition for Drupal
resource "aws_ecs_task_definition" "drupal" {
  family                   = local.env_identifier
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.drupal_cpu
  memory                   = var.drupal_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "drupal"
      image     = var.drupal_image
      cpu       = var.drupal_cpu
      memory    = var.drupal_memory
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 0 # Dynamic port mapping
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DRUPAL_SITE_NAME"
          value = var.branch_name
        },
        {
          name  = "DRUPAL_DATABASE_HOST"
          value = var.aurora_endpoint
        },
        {
          name  = "DRUPAL_DATABASE_NAME"
          value = var.aurora_database_name
        },
        {
          name  = "DRUPAL_DATABASE_PORT"
          value = "3306"
        },
        {
          name  = "DRUPAL_S3_BUCKET"
          value = var.s3_bucket_name
        },
        {
          name  = "DRUPAL_BRANCH"
          value = var.branch_name
        },
        {
          name  = "DRUPAL_BASE_URL"
          value = "https://${local.hostname}"
        }
      ]

      secrets = [
        {
          name      = "DRUPAL_DATABASE_USER"
          valueFrom = "${var.aurora_secret_arn}:username::"
        },
        {
          name      = "DRUPAL_DATABASE_PASSWORD"
          valueFrom = "${var.aurora_secret_arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.branch.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "drupal"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name   = local.env_identifier
      Branch = var.branch_name
    }
  )
}

# Target Group for this branch
resource "aws_lb_target_group" "branch" {
  name_prefix = substr(replace(local.dns_safe_branch, "-", ""), 0, 6)
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,301,302,403"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name   = local.env_identifier
      Branch = var.branch_name
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Listener Rule for this branch
resource "aws_lb_listener_rule" "branch" {
  listener_arn = var.alb_listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.branch.arn
  }

  condition {
    host_header {
      values = [local.hostname]
    }
  }

  tags = merge(
    var.tags,
    {
      Name   = local.env_identifier
      Branch = var.branch_name
    }
  )
}

# ECS Service for this branch
resource "aws_ecs_service" "drupal" {
  name            = local.env_identifier
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.drupal.arn
  desired_count   = var.desired_count

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
  health_check_grace_period_seconds  = 60

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_hosts_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.branch.arn
    container_name   = "drupal"
    container_port   = 80
  }

  # Use capacity provider strategy from cluster
  capacity_provider_strategy {
    capacity_provider = "${var.project_name}-on-demand"
    weight            = 50
    base              = 0
  }

  capacity_provider_strategy {
    capacity_provider = "${var.project_name}-spot"
    weight            = 50
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = merge(
    var.tags,
    {
      Name   = local.env_identifier
      Branch = var.branch_name
    }
  )

  depends_on = [
    aws_lb_listener_rule.branch
  ]
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "drupal" {
  max_capacity       = 5
  min_capacity       = 0 # Allow scaling to zero when no traffic
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.drupal.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU-based
resource "aws_appautoscaling_policy" "drupal_cpu" {
  name               = "${local.env_identifier}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.drupal.resource_id
  scalable_dimension = aws_appautoscaling_target.drupal.scalable_dimension
  service_namespace  = aws_appautoscaling_target.drupal.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory-based
resource "aws_appautoscaling_policy" "drupal_memory" {
  name               = "${local.env_identifier}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.drupal.resource_id
  scalable_dimension = aws_appautoscaling_target.drupal.scalable_dimension
  service_namespace  = aws_appautoscaling_target.drupal.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - ALB Request Count (Traffic-Based Scaling to Zero)
resource "aws_appautoscaling_policy" "drupal_alb_requests" {
  name               = "${local.env_identifier}-alb-requests"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.drupal.resource_id
  scalable_dimension = aws_appautoscaling_target.drupal.scalable_dimension
  service_namespace  = aws_appautoscaling_target.drupal.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${var.alb_arn_suffix}/${aws_lb_target_group.branch.arn_suffix}"
    }
    target_value = 10.0 # Target 10 requests per minute per task

    # Scale in aggressively when no traffic
    scale_in_cooldown  = 300 # 5 minutes of low traffic before scaling down
    scale_out_cooldown = 60  # Scale out quickly when traffic arrives
  }
}

# Data source for current region
data "aws_region" "current" {}
