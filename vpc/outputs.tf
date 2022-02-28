output "food_vpc_id" {
  value = aws_vpc.food-vpc.id
}

output "subnet_ids" {
  value = toset([
    aws_subnet.food-subnet-public-a.id,
    aws_subnet.food-subnet-public-b.id
  ])
}

output "route_table_private" {
  value = aws_route_table.food-private-routetable
}

output "route_table_public" {
  value = aws_route_table.food-public-routetable
}
