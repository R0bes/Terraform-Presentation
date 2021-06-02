
module "devices" {
    source      = "./Device"
    for_each    = toset(["demo3-device1"])
    name        = each.key
    iot_hub     = "demo2-hub"
}


/*
module "device1" {
    source   = "./Device"
    name     = "demo2-device1"
    iot_hub  = "demo2-hub"
}

module "device2" {
    source   = "./Device"
    name     = "demo2-device2"
    iot_hub  = "demo2-hub"
}
*/