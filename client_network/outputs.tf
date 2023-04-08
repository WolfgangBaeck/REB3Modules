output "subnets" {
    value = azurerm_subnet.subnets
  
}

output "gateway_ip" {
  value = gateway.gateway_ip
}

output "backend_address_pool" {
    value = gateway.backend_address_pool
}
