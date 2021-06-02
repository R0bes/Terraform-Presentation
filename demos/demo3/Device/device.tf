
locals {
    create = "create"
    destroy = "delete"
    commands = toset( [ local.create, local.destroy ] )
}

resource "local_file" "script_template" {
    filename = "device_script.ps1.tmpl"
    content = <<SCRIPT
        $success=$False
        $inc=0
        while(!$success -and $inc -lt 25) {
            $inc = $inc+1
            try {
                $res = az iot hub device-identity $${command} -n '${var.iot_hub}' -d '${var.name}' 2>$1
                if ($res -And !($res -Match "ERROR")) {
                    $success=$True
                }
            }
            catch [Exception]
            {
                echo "An Error occured."
                echo $_.Exception.GetType().FullName, $_.Exception.Message
            } 
        }      
        echo "Output: $res" 
        SCRIPT
}

data "template_file" "command_scripts" {
    for_each = local.commands
    template = local_file.script_template.content
    vars = {
        command = each.key
    }
}

resource "null_resource" "device" {
    triggers = { 
        create_command =  data.template_file.command_scripts[local.create].rendered 
        destroy_command =  data.template_file.command_scripts[local.destroy].rendered 
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