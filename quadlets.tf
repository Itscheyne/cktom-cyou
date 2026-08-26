locals {
  prod3_quadlet_files = toset([
    "13ft.container",
    "activepieces.container",
    "docker-socket-proxy.container",
    "internal.network",
    "netdata.container",
    "netdatacache.volume",
    "netdatalib.volume",
    "nextcloud.container",
    "semaphore.container",
    "stash.container",
    "traefik.container",
  ])
}

resource "null_resource" "prod3_quadlets" {
  for_each = local.prod3_quadlet_files

  triggers = {
    content = filesha256("${path.module}/quadlet/${each.value}")
  }

  connection {
    type  = "ssh"
    host  = var.prod3_host
    user  = "prodmin"
    agent = true
  }

  provisioner "file" {
    source      = "${path.module}/quadlet/${each.value}"
    destination = "/etc/containers/systemd/${each.value}"
  }

  provisioner "remote-exec" {
    inline = [
      "systemctl daemon-reload",
    ]
  }
}
