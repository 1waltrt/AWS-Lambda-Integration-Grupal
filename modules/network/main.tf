data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  public_cidrs  = [cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2)]
  private_cidrs = [cidrsubnet(var.vpc_cidr, 8, 11), cidrsubnet(var.vpc_cidr, 8, 12)]
}

# ── VPC + IGW ────────────────────────────────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${local.name}-igw" }
}

# ── Subnets ──────────────────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = { Name = "${local.name}-public-${count.index == 0 ? "a" : "b"}" }
}

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = { Name = "${local.name}-private-${count.index == 0 ? "a" : "b"}" }
}

# ── NAT (1 o 2 según entorno) ────────────────────────────────────────────────
resource "aws_eip" "nat" {
  count = var.nat_gateway_count

  domain = "vpc"

  tags = { Name = "${local.name}-nat-eip-${count.index == 0 ? "a" : "b"}" }
}

resource "aws_nat_gateway" "this" {
  count = var.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = { Name = "${local.name}-nat-${count.index == 0 ? "a" : "b"}" }

  depends_on = [aws_internet_gateway.this]
}

# ── Rutas ────────────────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${local.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = 2

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[min(count.index, var.nat_gateway_count - 1)].id
  }

  tags = { Name = "${local.name}-private-rt-${count.index == 0 ? "a" : "b"}" }
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ── Security groups ──────────────────────────────────────────────────────────
resource "aws_security_group" "upload_lambda" {
  name        = "sg-upload-lambda-${local.name}"
  description = "upload-lambda: sin inbound, egress 443 a S3 y SQS endpoints"
  vpc_id      = aws_vpc.this.id

  tags = { Name = "sg-upload-lambda" }
}

resource "aws_security_group" "crop_lambda" {
  name        = "sg-crop-lambda-${local.name}"
  description = "crop-lambda: sin inbound, egress 443 a S3 y SQS endpoints"
  vpc_id      = aws_vpc.this.id

  tags = { Name = "sg-crop-lambda" }
}

resource "aws_security_group" "vpce_sqs" {
  name        = "sg-vpce-sqs-${local.name}"
  description = "Interface endpoint de SQS: 443 desde las Lambdas"
  vpc_id      = aws_vpc.this.id

  tags = { Name = "sg-vpce-sqs" }
}

# Egress 443 -> prefix list del S3 Gateway Endpoint
resource "aws_vpc_security_group_egress_rule" "upload_to_s3" {
  security_group_id = aws_security_group.upload_lambda.id
  description       = "HTTPS a S3 via gateway endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
}

resource "aws_vpc_security_group_egress_rule" "crop_to_s3" {
  security_group_id = aws_security_group.crop_lambda.id
  description       = "HTTPS a S3 via gateway endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
}

# Egress 443 -> SG del endpoint de SQS
resource "aws_vpc_security_group_egress_rule" "upload_to_sqs" {
  security_group_id            = aws_security_group.upload_lambda.id
  description                  = "HTTPS al interface endpoint de SQS"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.vpce_sqs.id
}

resource "aws_vpc_security_group_egress_rule" "crop_to_sqs" {
  security_group_id            = aws_security_group.crop_lambda.id
  description                  = "HTTPS al interface endpoint de SQS"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.vpce_sqs.id
}

# Ingress 443 en el endpoint de SQS desde las Lambdas
resource "aws_vpc_security_group_ingress_rule" "vpce_from_upload" {
  security_group_id            = aws_security_group.vpce_sqs.id
  description                  = "HTTPS desde sg-upload-lambda"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.upload_lambda.id
}

resource "aws_vpc_security_group_ingress_rule" "vpce_from_crop" {
  security_group_id            = aws_security_group.vpce_sqs.id
  description                  = "HTTPS desde sg-crop-lambda"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.crop_lambda.id
}

# ── VPC Endpoints ────────────────────────────────────────────────────────────
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ImagesBucketOnly"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject"]
      Resource  = "${var.bucket_arn}/*"
    }]
  })

  tags = { Name = "${local.name}-vpce-s3" }
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce_sqs.id]
  private_dns_enabled = true

  tags = { Name = "${local.name}-vpce-sqs" }
}
