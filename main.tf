resource "azurerm_resource_group" "appgrp" {
  name     = "${var.settings.basestack}-${var.settings.environemnt}"
  location = var.location
}

resource "azurerm_virtual_network" "appnetwork" {
  name                = "${var.settings.basestack}-${var.settings.environemnt}-${var.virtual_network.name}"
  location            = azurerm_resource_group.appgrp.location
  resource_group_name = azurerm_resource_group.appgrp.name
  address_space       = [var.virtual_network.address_space]
}

resource "azurerm_private_dns_zone" "dbdnszone" {
  name                = "${var.client_name}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.appgrp.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dnsvnetlink" {
  name                  = "${var.client_name}-VnetZone.com"
  private_dns_zone_name = azurerm_private_dns_zone.dbdnszone.name
  virtual_network_id    = azurerm_virtual_network.appnetwork.id
  resource_group_name   = azurerm_resource_group.appgrp.name
}


module "client_network" {
  source               = "./client_network"
  location             = var.location
  resource_group_name  = azurerm_resource_group.appgrp.name
  virtual_network_name = azurerm_virtual_network.appnetwork.name
  client_name          = var.client_name
  subnet_size          = var.subnet_size
  address_prefix       = var.virtual_network.address_prefix
  settings             = var.settings
  tags                 = var.common_tags
}


module "storage" {
  source              = "./storage"
  resource_group_name = azurerm_resource_group.appgrp.name
  location            = azurerm_resource_group.appgrp.location
  settings            = var.settings
  private_containers  = var.private_containers
  public_containers   = var.public_containers
  tags                = var.common_tags
}


module "virtualmachines" {
  source                                       = "./virtualmachines"
  location                                     = var.location
  resource_group_name                          = azurerm_resource_group.appgrp.name
  virtual_network_name                         = azurerm_virtual_network.appnetwork.name
  client_name                                  = var.client_name
  subnet_id                                    = module.client_network.subnets["Frontend"].id
  application_gateway_backend_address_pool_ids = [for element in tolist(module.client_network.backend_address_pool) : (element.name == "backend-pool") ? element.id : ""]
  number_of_machines                           = var.number_of_machines
  settings                                     = var.settings
  vm_password                                  = random_password.vmpassword.result
  tags                                         = var.common_tags
  depends_on = [
    module.client_network,
    azurerm_key_vault.kvOne
  ]
}

locals {
  databases = {
    management = {
      name      = "mgmt"
      collation = "en_US.utf8"
      charset   = "utf8"
    }
    reporting = {
      name      = "reports"
      collation = "en_US.utf8"
      charset   = "utf8"
    }
  }

}

module "dbservers" {
  source              = "./databases"
  location            = var.location
  resource_group_name = azurerm_resource_group.appgrp.name
  client_name         = var.client_name
  db_version          = var.db_version
  db_subnet_id        = module.client_network.subnets["DB-Delegated"].id
  private_dns_zone_id = azurerm_private_dns_zone.dbdnszone.id
  admin_login         = var.admin_login
  admin_pwd           = var.admin_pwd
  zone                = "1"
  storage             = var.storage
  sku_name            = "GP_Standard_D4s_v3"
  server_databases    = local.databases
  settings            = var.settings
  tags                = var.common_tags
  depends_on          = [
      azurerm_private_dns_zone_virtual_network_link.dnsvnetlink,
      module.client_network,
      azurerm_key_vault.kvOne]
}


