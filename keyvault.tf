#Create KeyVault ID
resource "random_id" "kvname" {
  byte_length = 5
  prefix      = "kv-${var.client_name}-"
}
#Keyvault Creation
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kvOne" {
  name                        = random_id.kvname.hex
  location                    = azurerm_resource_group.appgrp.location
  resource_group_name         = azurerm_resource_group.appgrp.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = [
      "Get",
    ]
    secret_permissions = [
      "Get", "Backup", "Delete", "List", "Purge", "Recover", "Restore", "Set",
    ]
    storage_permissions = [
      "Get",
    ]
  }
  tags = var.common_tags
}

#Create KeyVault VM password
resource "random_password" "vmpassword" {
  length  = 20
  special = true
}
#Create Key Vault Secret
resource "azurerm_key_vault_secret" "vmpassword" {
  name         = "vmpassword"
  value        = random_password.vmpassword.result
  key_vault_id = azurerm_key_vault.kvOne.id
  tags         = var.common_tags
  depends_on = [
    azurerm_key_vault.kvOne
  ]
}
