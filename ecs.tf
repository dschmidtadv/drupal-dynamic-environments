# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = var.ecs_cluster_name
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [
    aws_ecs_capacity_provider.on_demand.name,
    aws_ecs_capacity_provider.spot.name
  ]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.on_demand.name
    weight            = 100 - var.spot_instance_percentage
    base              = 1 # At least 1 on-demand instance for base UAT
  }

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.spot.name
    weight            = var.spot_instance_percentage
  }
}

# Security Group for ECS Hosts
resource "aws_security_group" "ecs_hosts" {
  name_prefix = "${var.project_name}-ecs-hosts-"
  description = "Security group for ECS container hosts"
  vpc_id      = data.aws_vpc.existing.id

  # Allow traffic from ALB
  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-hosts"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Launch Template for On-Demand instances
resource "aws_launch_template" "ecs_on_demand" {
  name_prefix   = "${var.project_name}-ecs-on-demand-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.ecs_instance_type

  iam_instance_profile {
    name = data.aws_iam_instance_profile.ecs_host.name
  }

  vpc_security_group_ids = [aws_security_group.ecs_hosts.id]

  monitoring {
    enabled = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-ecs-on-demand"
      Type = "on-demand"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Launch Template for Spot instances
resource "aws_launch_template" "ecs_spot" {
  name_prefix   = "${var.project_name}-ecs-spot-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.ecs_instance_type

  iam_instance_profile {
    name = data.aws_iam_instance_profile.ecs_host.name
  }

  vpc_security_group_ids = [aws_security_group.ecs_hosts.id]

  monitoring {
    enabled = true
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price          = ""
      spot_instance_type = "one-time"
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=true >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-ecs-spot"
      Type = "spot"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for On-Demand instances
resource "aws_autoscaling_group" "ecs_on_demand" {
  name_prefix         = "${var.project_name}-ecs-on-demand-"
  vpc_zone_identifier = local.subnet_ids
  min_size            = 1
  max_size            = var.ecs_asg_max_size
  desired_capacity    = max(1, floor(var.ecs_asg_desired_capacity * (100 - var.spot_instance_percentage) / 100))

  launch_template {
    id      = aws_launch_template.ecs_on_demand.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-on-demand"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

# Auto Scaling Group for Spot instances
resource "aws_autoscaling_group" "ecs_spot" {
  name_prefix         = "${var.project_name}-ecs-spot-"
  vpc_zone_identifier = local.subnet_ids
  min_size            = 0
  max_size            = var.ecs_asg_max_size
  desired_capacity    = max(0, floor(var.ecs_asg_desired_capacity * var.spot_instance_percentage / 100))

  launch_template {
    id      = aws_launch_template.ecs_spot.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-spot"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

# ECS Capacity Provider for On-Demand
resource "aws_ecs_capacity_provider" "on_demand" {
  name = "${var.project_name}-on-demand"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_on_demand.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 10
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }

  tags = {
    Name = "${var.project_name}-on-demand"
  }
}

# ECS Capacity Provider for Spot
resource "aws_ecs_capacity_provider" "spot" {
  name = "${var.project_name}-spot"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_spot.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 10
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }

  tags = {
    Name = "${var.project_name}-spot"
  }
}

# Scheduled Action: Scale to Zero (8 PM ET / Midnight UTC)
resource "aws_autoscaling_schedule" "scale_down_on_demand" {
  scheduled_action_name  = "${var.project_name}-scale-down-on-demand"
  min_size               = 0
  max_size               = var.ecs_asg_max_size
  desired_capacity       = 0
  recurrence             = var.scale_to_zero_schedule
  autoscaling_group_name = aws_autoscaling_group.ecs_on_demand.name
}

resource "aws_autoscaling_schedule" "scale_down_spot" {
  scheduled_action_name  = "${var.project_name}-scale-down-spot"
  min_size               = 0
  max_size               = var.ecs_asg_max_size
  desired_capacity       = 0
  recurrence             = var.scale_to_zero_schedule
  autoscaling_group_name = aws_autoscaling_group.ecs_spot.name
}

# Scheduled Action: Scale Up (7 AM ET / 11 AM UTC)
resource "aws_autoscaling_schedule" "scale_up_on_demand" {
  scheduled_action_name  = "${var.project_name}-scale-up-on-demand"
  min_size               = 1
  max_size               = var.ecs_asg_max_size
  desired_capacity       = max(1, floor(var.ecs_asg_desired_capacity * (100 - var.spot_instance_percentage) / 100))
  recurrence             = var.scale_up_schedule
  autoscaling_group_name = aws_autoscaling_group.ecs_on_demand.name
}

resource "aws_autoscaling_schedule" "scale_up_spot" {
  scheduled_action_name  = "${var.project_name}-scale-up-spot"
  min_size               = 0
  max_size               = var.ecs_asg_max_size
  desired_capacity       = max(0, floor(var.ecs_asg_desired_capacity * var.spot_instance_percentage / 100))
  recurrence             = var.scale_up_schedule
  autoscaling_group_name = aws_autoscaling_group.ecs_spot.name
}
