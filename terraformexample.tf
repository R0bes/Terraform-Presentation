

#####################
#	  Variables   	#
#####################

variable "region" {
  type = string
}

variable "context" {
    type = string
    validation {
        condition     = length(var.context) <= 10
        error_message = "Variable context must be less then 11 characters long."
    }
}

variable "environment" {
    type = string
    validation {
        condition     = length(var.environment) <= 5
        error_message = "Variable context must be less then 6 characters long."
    }
}

variable "tags" {
    type    = map(string)
    default = {}
}

variable "principal_object_ids" {
    type    = list(object({ name=string, id=string }))
    default = []
}


#####################
#	   Locals  	  	#
#####################

locals {  
    context = var.context
    context_ = var.context == "" ? "" : "${var.context}-"
  
    env = var.environment
    _env = var.environment == "" ? "" : "-${var.environment}"

    tags = merge(var.tags, { "context" : var.context })
    
    # Raspberry Pi Device config
    raspberry_device_name    = "RaspberryPi"
    raspberry_device_query   = <<QUERY
        SELECT *
        INTO powerbiout
        FROM iothubin
        Where IotHub.ConnectionDeviceId ='RaspberryPi'
        QUERY

    # Conveyor Belt Device config
    belt_device_name         = "ConveyorBelt"
    belt_device_query        = <<QUERY
        WITH AnomalyDetectionStep AS
        (
            SELECT
                EVENTENQUEUEDUTCTIME AS time,
                CAST(vibration AS float) AS vibe,
                AnomalyDetection_SpikeAndDip(CAST(vibration AS float), 95, 120, 'spikesanddips') OVER(LIMIT DURATION(second, 120)) AS SpikeAndDipScores,
                *
            FROM iothubin
            Where IotHub.ConnectionDeviceId = 'ConveyorBelt'
        )
        SELECT
            time, 
            vibe, 
            CAST(GetRecordPropertyValue(SpikeAndDipScores, 'Score') AS float) AS SpikeAndDipScore,
            CAST(GetRecordPropertyValue(SpikeAndDipScores, 'IsAnomaly') AS bigint) AS IsSpikeAndDipAnomaly,
            *
        INTO powerbiout
        FROM AnomalyDetectionStep
        QUERY
    
    belt_device_function_dir    = "../../../../../Source/GFT.ConveyorBelt.Simulator/GFT.ConveyorBelt.Serverless"
    belt_device_function_query  = <<QUERY
        WITH AnomalyDetectionStep AS
        (
            SELECT
                CAST (EVENTENQUEUEDUTCTIME AS datetime) AS time,
                CAST (GetRecordPropertyValue(AnomalyDetection_SpikeAndDip(CAST(vibration AS float), 95, 120, 'spikesanddips') OVER(LIMIT DURATION(second, 120)), 'IsAnomaly') AS bigint) AS IsAnomaly,
                System.Timestamp() AS now
            FROM iothubin
            Where IotHub.ConnectionDeviceId ='ConveyorBelt'
        )
        SELECT  time, IsAnomaly
        INTO callbackapp
        FROM AnomalyDetectionStep 
        WHERE IsAnomaly=1  AND time>=DATEADD (hour , -1, now)
        QUERY

    # collectoins for better handling
    device_names = toset([ local.raspberry_device_name, local.belt_device_name ])
    device_queries = tomap({
        (local.raspberry_device_name) = local.raspberry_device_query
        (local.belt_device_name)      = local.belt_device_query
    })
}




#####################
#      Resources    #
#####################

# ---------- Resource Group ----------

resource "azurerm_resource_group" "main" {
    name        = "${local.context_}resource_group${local._env}"
    location    = var.region
}


# ---------- Main Storage ------------

resource "azurerm_storage_account" "storage_account" {
    name                      = "${local.context}main${local.env}"
    resource_group_name       = azurerm_resource_group.main.name
    location                  = azurerm_resource_group.main.location
    account_tier              = "Standard"
    account_replication_type  = "LRS"
}

resource "azurerm_storage_container" "storage_container" {
    name                      = "${local.context}container${local.env}"
    storage_account_name      = azurerm_storage_account.storage_account.name
    container_access_type     = "private"
}


# ---------- IoT - Hub ---------------

resource "azurerm_iothub" "main" {
    name                  = "${local.context_}hub${local._env}"
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


# ---------- Time Series Insights -----

resource "azurerm_storage_account" "tsi_storage_account" {
  name                      = "${local.context}tsistorage${local.env}"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  account_tier              = "Standard"
  account_replication_type  = "LRS"
}

resource "azurerm_iothub_consumer_group" "iothub_tsi_consumer" {
  name                   = "${local.context}tsiconsumergroup${local.env}"
  iothub_name            = azurerm_iothub.main.name
  eventhub_endpoint_name = "events"
  resource_group_name    = azurerm_resource_group.main.name
}

resource "azurerm_iot_time_series_insights_gen2_environment" "iot_tsi" {
  name                = "${local.context}tsi${local.env}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "L1"
  warm_store_data_retention_time = "P7D"  
  id_properties = ["iothub-connection-device-id"]

  storage {
    name = azurerm_storage_account.tsi_storage_account.name
    key  = azurerm_storage_account.tsi_storage_account.primary_access_key
  }
  
  provisioner "local-exec" {
    when = create
    interpreter = ["pwsh", "-Command"]
    command = "az tsi event-source iothub create --consumer-group-name ${azurerm_iothub_consumer_group.iothub_tsi_consumer.name} --environment-name ${azurerm_iot_time_series_insights_gen2_environment.iot_tsi.name} --name iot-hub-source-1 --resource-id ${azurerm_iothub.main.id} --location ${azurerm_resource_group.main.location} --iot-hub-name ${azurerm_iothub.main.name} --key-name iothubowner --resource-group ${azurerm_resource_group.main.name} --shared-access-key ${azurerm_iothub.main.shared_access_policy.0.primary_key}"
  }
}

resource "azurerm_iot_time_series_insights_access_policy" "iot_tsi_access" {
  count               = length(var.principal_object_ids)
  name                = var.principal_object_ids[count.index].name
  principal_object_id = var.principal_object_ids[count.index].id
  time_series_insights_environment_id = azurerm_iot_time_series_insights_gen2_environment.iot_tsi.id
  roles               = ["Contributor", "Reader"]
}



# ---------- Devices -----------------

module "devices" {
    for_each    = local.device_names
    source      = "./Modules/Device"
    depends_on  = [ azurerm_iothub.main ]
    name        = each.key
    iot_hub     = azurerm_iothub.main.name
}



# ---------- Powerbi Stream Analytics -----

resource "local_file" "powerbi_datasources" {
    for_each    = local.device_names
    filename    = "${each.key}.powerbi.datasource.json"
    content     = <<JSON
            {
                "type": "PowerBI",
                "properties": {
                    "dataset": "${local.context_}dataset${local._env}.${each.key}",
                    "table":"devicedata",
                    "refreshToken": "someRefreshToken==",
                    "tokenUserPrincipalName": "filledlater@gft.com",
                    "tokenUserDisplayName": "To be Renewed",
                    "groupId": "",
                    "groupName": "My workspace"
                }
            }
        JSON
}

module "powerbi_stream_analytics_job" {
    for_each                = local.device_names
    source				    = "./Modules/StreamAnalytics"
    depends_on              = [ azurerm_iot_time_series_insights_gen2_environment.iot_tsi ] # workaround for longer delay to iot hub
    job_name			    = "${local.context_}${each.key}-asa${local._env}"
    location			    = azurerm_resource_group.main.location
    resoucre_group		    = azurerm_resource_group.main.name
    iothub				    = azurerm_iothub.main.name
    iothub_policy_key	    = azurerm_iothub.main.shared_access_policy[0].primary_key
    iothub_policy_name	    = azurerm_iothub.main.shared_access_policy[0].key_name
    endpoint			    = "events"
    input_name			    = "iothubin"
    query                   = local.device_queries[each.key]
    output_datasource       = local_file.powerbi_datasources[each.key].filename
}



# ---------- Anomaly Callback  -----

module "aomaly_callback" {
    depends_on              = [azurerm_resource_group.main, azurerm_iothub.main]
    source                  = "./Modules/AzureFunction"
    device                  = local.belt_device_name
    name                    = "AnomalyDetected"
    query                   = local.belt_device_function_query
    dir                     = local.belt_device_function_dir
    location                = azurerm_resource_group.main.location
    resource_group          = azurerm_resource_group.main.name
    iothub_name             = azurerm_iothub.main.name
    storage_name            = "${local.context}fastg${length(substr(local.belt_device_name, 0, 24-length(local.context)-length(local.env)-length("fastg")))}${local.env}"
    hub_policy_name         = "${local.context_}fa-policy${local.belt_device_name}${local._env}"
    app_insight_name        = "${local.context_}fainsights${local.belt_device_name}${local._env}"
    plan_name               = "${local.context_}fa-service-plan${local.belt_device_name}${local._env}"
    app_name                = "${local.context_}anomaly-callback${local.belt_device_name}${local._env}"
    job_name                = "${local.context_}acb-asa-job-${local.belt_device_name}${local._env}"
    iothub_primary_key      = azurerm_iothub.main.shared_access_policy[0].primary_key
    iothub_key_name         = azurerm_iothub.main.shared_access_policy[0].key_name
    iothub_event_endpoint   = "events"
}


# ---------- Data Explorer  -----

resource "azurerm_kusto_cluster" "adx_cluster" {
    name                = "${local.context}adxcluster${local.env}"
    resource_group_name = azurerm_resource_group.main.name
    location            = azurerm_resource_group.main.location
    sku {
        name     = "Dev(No SLA)_Standard_E2a_v4"
        capacity = 1
    }
}

resource "azurerm_kusto_database" "iot_database" {
    name                    = "${local.context}iotdb${local.env}"
    resource_group_name     = azurerm_resource_group.main.name
    location                = azurerm_resource_group.main.location
    cluster_name            = azurerm_kusto_cluster.adx_cluster.name
    hot_cache_period        = "P7D"
    soft_delete_period      = "P31D"
}



# seems to be no need to assign access
#resource "azurerm_kusto_database_principal_assignment" "adx_access" {
#    count                 = length(var.principal_object_ids)
#    name                  = "adx${var.principal_object_ids[count.index].name}"
#    tenant_id             = data.azurerm_client_config.current.tenant_id
#    principal_id          = var.principal_object_ids[count.index].id
#    name                    = "adxaccess"
#    resource_group_name     = azurerm_resource_group.main.name  
#    cluster_name            = azurerm_kusto_cluster.adx_cluster.name
#    database_name           = azurerm_kusto_database.iot_database.name
#    principal_type          = "User"
#    role                    = "Admin"
#}