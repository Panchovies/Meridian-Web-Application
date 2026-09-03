resource "aws_ecr_repository" "ecr" {
  name                 = "terraform-meridian-web-application"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        # Matches k8s/deployment.yaml's revisionHistoryLimit: 20, so every
        # ReplicaSet k8s could still roll back to has a matching image in ECR.
        description = "Expire any images that are not the most recent 20"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}