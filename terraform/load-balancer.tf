### Replaces ingress and egress rules for ALB security group ###
resource "aws_security_group" "alb" {
  name_prefix = "${var.application_service_name}-alb-sg-"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from the internet"
  }

  egress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
    description     = "To Meridian app target group on EKS nodes"
  }
}

resource "aws_lb" "meridian" {
  name               = "${var.application_service_name}-alb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]
  depends_on = [
    aws_internet_gateway.main,
  ]
}

resource "aws_lb_target_group" "meridian" {
  name        = "${var.application_service_name}-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    port                = "traffic-port"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  deregistration_delay = 30
}

resource "aws_lb_listener" "meridian_http" {
  load_balancer_arn = aws_lb.meridian.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.meridian.arn
  }
}

### Allows traffic from ALB to EKS nodes on port 5000 ### 
resource "aws_security_group_rule" "nodes_from_alb" {
  type                     = "ingress"
  from_port                = 5000
  to_port                  = 5000
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow ALB to reach Meridian app port on nodes"
}
