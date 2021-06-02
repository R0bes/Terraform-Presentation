
variable "device_name" {
    default = "demo2-device"
}
variable "hub_name" {
    default = "demo2-hub"
}
resource "null_resource" "device_twin" {
    triggers = {
        create_command = "az iot hub device-identity create -n ${var.hub_name} -d ${var.device_name}"
        destroy_command = "az iot hub device-identity delete -n ${var.hub_name} -d ${var.device_name}"
    }
    provisioner "local-exec" {
        when = create
        interpreter = ["pwsh" , "-Command"]
        command = self.triggers.create_command
    }
    provisioner "local-exec" {
        when = destroy
        interpreter = ["pwsh" , "-Command"]
        command = self.triggers.destroy_command
    }
}