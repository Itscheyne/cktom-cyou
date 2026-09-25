locals {
  prod3_quadlet_files_list = fileset("${path.module}/quadlet", "*")
  quadlets_cloudinit = [
    for f in local.prod3_quadlet_files_list : {
      path        = f == "ov.conf" ? "/tmp/ov.conf" : "/home/prodmin/.config/containers/systemd/${f}"
      owner       = "prodmin:prodmin"
      permissions = "0644"
      encoding    = "b64"
      content     = base64encode(file("${path.module}/quadlet/${f}"))
    }
  ]
}

resource "proxmox_virtual_environment_file" "prod3_vendor_data" {
  provider     = proxmox.node3
  node_name    = "node3"
  datastore_id = "datapool0"
  content_type = "snippets"

  source_raw {
    file_name = "prod3-quadlets-cloudinit.yaml"
    data      = <<CLOUDCONFIG
#cloud-config
write_files:
%{for q in local.quadlets_cloudinit~}
  - path: ${q.path}
    owner: ${q.owner}
    permissions: '${q.permissions}'
    encoding: ${q.encoding}
    content: ${q.content}
%{endfor~}

runcmd:
  - sudo mkdir -p /var/opt/openviking/data
  - sudo chown -R prodmin:prodmin /var/opt/openviking/data
  - sudo mv /tmp/ov.conf /var/opt/openviking/data/ov.conf || true
  - sudo -u prodmin bash -c 'export XDG_RUNTIME_DIR=/run/user/$(id -u prodmin); systemctl --user daemon-reload'
%{for f in local.prod3_quadlet_files_list~}
%{if replace(f, "\\.\\w+$", "") != f && f != "ov.conf"~}
  - sudo -u prodmin bash -c 'export XDG_RUNTIME_DIR=/run/user/$(id -u prodmin); systemctl --user restart ${replace(replace(replace(replace(f, ".container", ".service"), ".pod", ".service"), ".network", ".service"), ".volume", ".service")}'
%{endif~}
%{endfor~}
CLOUDCONFIG
  }
}
