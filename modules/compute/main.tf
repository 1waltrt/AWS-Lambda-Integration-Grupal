locals {
  name = "${var.project}-${var.environment}"
}

# ── Empaquetado ──────────────────────────────────────────────────────────────
# Antes de plan/apply se debe correr scripts/build-lambdas.sh (npm install).
data "archive_file" "upload" {
  type        = "zip"
  source_dir  = var.upload_source_dir
  output_path = "${var.build_dir}/upload-lambda.zip"
}

data "archive_file" "crop" {
  type        = "zip"
  source_dir  = var.crop_source_dir
  output_path = "${var.build_dir}/crop-lambda.zip"
}

# ── Log groups ───────────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "upload" {
  name              = "/aws/lambda/${local.name}-upload"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "crop" {
  name              = "/aws/lambda/${local.name}-crop"
  retention_in_days = var.log_retention_days
}

# ── IAM: upload-lambda-role ──────────────────────────────────────────────────
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "upload" {
  name               = "${local.name}-upload-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

resource "aws_iam_role_policy_attachment" "upload_basic" {
  role       = aws_iam_role.upload.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "upload_vpc" {
  role       = aws_iam_role.upload.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "upload" {
  name = "s3-put-uploads"
  role = aws_iam_role.upload.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${var.bucket_arn}/uploads/*"
    }]
  })
}

# ── IAM: crop-lambda-role ────────────────────────────────────────────────────
resource "aws_iam_role" "crop" {
  name               = "${local.name}-crop-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

resource "aws_iam_role_policy_attachment" "crop_basic" {
  role       = aws_iam_role.crop.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "crop_vpc" {
  role       = aws_iam_role.crop.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "crop" {
  name = "s3-sqs-crop"
  role = aws_iam_role.crop.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadOriginals"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${var.bucket_arn}/uploads/*"
      },
      {
        Sid      = "WriteProcessed"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.bucket_arn}/processed/*"
      },
      {
        Sid    = "ConsumeQueue"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = var.queue_arn
      }
    ]
  })
}

# ── upload-lambda ────────────────────────────────────────────────────────────
resource "aws_lambda_function" "upload" {
  function_name = "${local.name}-upload"
  role          = aws_iam_role.upload.arn
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  architectures = ["x86_64"]
  memory_size   = 256
  timeout       = 30

  filename         = data.archive_file.upload.output_path
  source_code_hash = data.archive_file.upload.output_base64sha256

  reserved_concurrent_executions = var.reserved_concurrency

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_upload_id]
  }

  environment {
    variables = {
      S3_BUCKET        = var.bucket_name
      UPLOAD_PREFIX    = "uploads/"
      MAX_UPLOAD_BYTES = tostring(var.max_upload_bytes)
    }
  }

  lifecycle {
    precondition {
      condition     = fileexists("${var.upload_source_dir}/node_modules/busboy/package.json")
      error_message = "Falta node_modules en src/upload-lambda. Ejecuta ./scripts/build-lambdas.sh antes de plan/apply."
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.upload,
    aws_iam_role_policy_attachment.upload_basic,
    aws_iam_role_policy_attachment.upload_vpc,
    aws_iam_role_policy.upload,
  ]
}

# ── crop-lambda ──────────────────────────────────────────────────────────────
resource "aws_lambda_function" "crop" {
  function_name = "${local.name}-crop"
  role          = aws_iam_role.crop.arn
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  architectures = ["x86_64"]
  memory_size   = 512
  timeout       = 60

  filename         = data.archive_file.crop.output_path
  source_code_hash = data.archive_file.crop.output_base64sha256

  reserved_concurrent_executions = var.reserved_concurrency

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_crop_id]
  }

  environment {
    variables = {
      S3_BUCKET        = var.bucket_name
      PROCESSED_PREFIX = "processed/"
    }
  }

  lifecycle {
    precondition {
      condition     = fileexists("${var.crop_source_dir}/node_modules/sharp/package.json")
      error_message = "Falta node_modules en src/crop-lambda. Ejecuta ./scripts/build-lambdas.sh antes de plan/apply."
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.crop,
    aws_iam_role_policy_attachment.crop_basic,
    aws_iam_role_policy_attachment.crop_vpc,
    aws_iam_role_policy.crop,
  ]
}

# ── SQS -> crop-lambda ───────────────────────────────────────────────────────
resource "aws_lambda_event_source_mapping" "crop_from_sqs" {
  event_source_arn        = var.queue_arn
  function_name           = aws_lambda_function.crop.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]
  enabled                 = true
}
