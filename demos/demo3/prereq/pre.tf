
provider "azurerm" {
	features {}
}

resource "azurerm_resource_group" "main" {
	name        = "demo2"
	location    = "westeurope"
}

resource "azurerm_iothub" "main" {
    name                  = "${azurerm_resource_group.main.name}-hub"
    resource_group_name   = azurerm_resource_group.main.name
    location              = azurerm_resource_group.main.location
    sku {
        name     = "S1"
        capacity = "1"
    }
}

/*

variable "principal_object_name" {}
variable "principal_object_id" {}

# ---------- Storage -----

resource "azurerm_storage_account" "storage_account" {
    name                      = "${azurerm_resource_group.main.name}storageaccount"
    resource_group_name       = azurerm_resource_group.main.name
    location                  = azurerm_resource_group.main.location
    account_tier              = "Standard"
    account_replication_type  = "LRS"
}

resource "azurerm_storage_container" "storage_container" {
    name                      = "${azurerm_resource_group.main.name}container"
    storage_account_name      = azurerm_storage_account.storage_account.name
    container_access_type     = "private"
}

# ---------- Iot Hub -----

resource "azurerm_iothub" "main" {
    name                  = "${azurerm_resource_group.main.name}-hub"
    resource_group_name   = azurerm_resource_group.main.name
    location              = azurerm_resource_group.main.location
    sku {
        name     = "S1"
        capacity = "1"
    }
    endpoint {
        type                       = "AzureIotHub.StorageContainer"
        connection_string          = azurerm_storage_account.storage_account.primary_blob_connection_string
        name                       = "StorageAccountBackupEndPoint"
        batch_frequency_in_seconds = 60
        max_chunk_size_in_bytes    = 10485760
        container_name             = azurerm_storage_container.storage_container.name
        encoding                   = "JSON"
        file_name_format           = "{iothub}/{partition}/{YYYY}/{MM}/{DD}/{HH}/{mm}"
    }    
    route {
        name                = "StorageAccountBackup"
        source              = "DeviceMessages"
        condition           = "true"
        endpoint_names      = ["StorageAccountBackupEndPoint"]
        enabled             = true
    }
    route {
        name                = "EventGrid"
        source              = "DeviceMessages"
        condition           = "true"
        endpoint_names      = ["events"]
        enabled             = true
    }
}

/*
# ---------- Time Series Insights -----

resource "azurerm_iothub_consumer_group" "iothub_tsi_consumer" {
  name                   = "${azurerm_resource_group.main.name}-consumer"
  iothub_name            = azurerm_iothub.main.name
  eventhub_endpoint_name = "events"
  resource_group_name    = azurerm_resource_group.main.name
}

resource "azurerm_iot_time_series_insights_gen2_environment" "iot_tsi" {
  name                = "${azurerm_resource_group.main.name}-tsi"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "L1"
  warm_store_data_retention_time = "P7D"  
  id_properties = ["iothub-connection-device-id"]

  storage {
    name = azurerm_storage_account.storage_account.name
    key  = azurerm_storage_account.storage_account.primary_access_key
  }
  
  provisioner "local-exec" {
    when = create
    interpreter = ["pwsh", "-Command"]
    command = <<COMMAND
        az tsi event-source iothub create `
            --consumer-group-name ${azurerm_iothub_consumer_group.iothub_tsi_consumer.name} `
            --environment-name ${azurerm_iot_time_series_insights_gen2_environment.iot_tsi.name} `
            --name iot-hub-source-1 `
            --resource-id ${azurerm_iothub.main.id} `
            --location ${azurerm_resource_group.main.location} `
            --iot-hub-name ${azurerm_iothub.main.name} `
            --key-name iothubowner `
            --resource-group ${azurerm_resource_group.main.name} `
            --shared-access-key ${azurerm_iothub.main.shared_access_policy.0.primary_key}
    COMMAND
  }
}

resource "azurerm_iot_time_series_insights_access_policy" "iot_tsi_access" {
  name                = var.principal_object_name
  principal_object_id = var.principal_object_id
  time_series_insights_environment_id = azurerm_iot_time_series_insights_gen2_environment.iot_tsi.id
  roles               = ["Contributor", "Reader"]
}
*/