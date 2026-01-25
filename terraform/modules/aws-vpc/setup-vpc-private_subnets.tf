resource "aws_vpc" "privatelink" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "private" {
  count = var.subnet_count

  vpc_id            = aws_vpc.privatelink.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.new_bits, count.index)
  availability_zone = local.available_zones[count.index]

  tags = {
    Name          = "${var.vpc_name}-private-subnet-${count.index + 1}"
    Type          = "private"
    AvailableZone = local.available_zones[count.index]
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.privatelink.id

  tags = {
    Name        = "${var.vpc_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = var.subnet_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

