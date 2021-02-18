provider "libvirt" {
	uri = "qemu:///system"
}

variable "hosts" {
	default = 1
}

variable "hostname_format" {
	type    = string
	default = "ceph-osd%02d"
}

resource "libvirt_volume" "base_vol" {
	count  = var.hosts
	name   = "${format(var.hostname_format, count.index + 1)}"
	format = "qcow2"
	source = "/mnt/libvirt/CentOS-8-GenericCloud-8.1.1911-20200113.3.x86_64.qcow2"
	pool   = "default"
}

resource "libvirt_volume" "data_vol" {
	count  = var.hosts
	name   = "${format(var.hostname_format, count.index + 1)}-data"
	format = "raw"
	pool   = "default"
	size   = 10737418240
}

#resource "libvirt_volume" "db_vol" {
#	count  = var.hosts
#	name   = "${format(var.hostname_format, count.index + 1)}-db"
#	format = "raw"
#	pool   = "default"
#	size   = 524288000
#}

#resource "libvirt_volume" "wal_vol" {
#	count  = var.hosts
#	name   = "${format(var.hostname_format, count.index + 1)}-wal"
#	format = "raw"
#	pool   = "default"
#	size   = 104857600
#}


data "template_file" "user_data" {
	count    = var.hosts
	template = file("${path.module}/cloud_init_osd${count.index + 1}.cfg")
}

resource "libvirt_cloudinit_disk" "cloud_init" {
	count     = var.hosts
	name      = "cloudinit_osd${count.index + 1}.iso"
	user_data = data.template_file.user_data[count.index].rendered
	pool      = "default"
}

resource "libvirt_domain" "ceph-osd" {
	count     = var.hosts
	name      = format(var.hostname_format, count.index + 1)
	memory    = "4096"
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

	disk {
		volume_id = element(libvirt_volume.data_vol.*.id, count.index)
		scsi      = "true"
	}

#	disk {
#		volume_id = element(libvirt_volume.db_vol.*.id, count.index)
#		scsi      = "true"
#	}
#
#	disk {
#		volume_id = element(libvirt_volume.wal_vol.*.id, count.index)
#		scsi      = "true"
#	}

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
