output "vnet_id" {
  value = azurerm_virtual_network.example_vnet.id
}

output "subnet1_id" {
  value = azurerm_subnet.example_subnet1.id
}

output "vnet_name" {
  value = azurerm_virtual_network.example_vnet.name
}

output "subnet1_name" {
  value = azurerm_subnet.example_subnet1.name
}

output "vnet_address_space" {
  value = azurerm_virtual_network.example_vnet.address_space
}

output "subnet1_address_prefix" {
  value = azurerm_subnet.example_subnet1.address_prefixes[0]
}
