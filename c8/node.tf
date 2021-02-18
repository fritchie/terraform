provider "libvirt" {
	uri = "qemu:///system"
}

variable "hosts" {
	default = 1
}

variable "hostname_format" {
	type    = string
	default = "c8-n%02d"
}

resource "libvirt_volume" "base_vol" {
	count  = var.hosts
	name   = "${format(var.hostname_format, count.index + 1)}"
	format = "qcow2"
	source = "/mnt/libvirt/CentOS-8-GenericCloud-8.1.1911-20200113.3.x86_64.qcow2"
	pool   = "default"
}

data "template_file" "user_data" {
	count    = var.hosts
	template = file("${path.module}/cloud_init_c8_n${count.index + 1}.cfg")
}

resource "libvirt_cloudinit_disk" "cloud_init" {
	count     = var.hosts
	name      = "cloudinit_c8_n${count.index + 1}.iso"
	user_data = data.template_file.user_data[count.index].rendered
	pool      = "default"
}

resource "libvirt_domain" "c8-n" {
	count     = var.hosts
	name      = format(var.hostname_format, count.index + 1)
	memory    = "1024"
	vcpu      = 2
	cloudinit = libvirt_cloudinit_disk.cloud_init[count.index].id

	cpu = {
		mode = "host-passthrough"
	}


	network_interface {
		bridge = "br0"
	}

	disk {
		volume_id = element(libvirt_volume.base_vol.*.id, count.index)
		scsi      = "true"
	}

	xml {
		xslt = file("${path.module}/disk_caching.xsl")
	}

	console {
		type        = "pty"
		target_type = "serial"
		target_port = "1"
	}
}

terraform {
  required_version = ">= 0.12"
}
