/* 
   Terraform plan to build an arbritary testing CEPH infrastructure platform 
   containing nodes (osds) and monitors within a Cloudstack or Cosmic environment.
*/


provider "cloudstack" {
  api_url          = "https://"
  api_key          = "api_key_goes_here"
  secret_key       = "secret_key_goes_here"
}

variable "instances" {
  default = {
    num_mon = 3
    num_node = 3
    num_osd = 6
  }
}

variable "offering" {
  default = {
    service = "service_offering_goes_here"
    network = "network_offering_goes_here"
    vpc = "vpc_offering_id_goes_here"
  }
}

variable "template" {
  default = "os_template_goes_here"
}

variable "zone" {
  default = "zone_goes_here"
}

variable "keypair" {
  default = "ssh_key_pair_goes_here"
}

variable "acl" {
  default = "network_acl_goes_here"
}

variable "cidr" {
  default = {
    vpc = "192.168.0.0/16"
    client = "192.168.1.0/24"
    cluster = "192.168.2.0/24"
  }
}

resource "cloudstack_vpc" "ceph" {
  name             = "ceph"
  cidr             = "${var.cidr["vpc"]}"
  vpc_offering     = "${var.offering["vpc"]}"
  zone             = "${var.zone}"
}

resource "cloudstack_network" "client_network" {
  name             = "ceph-client-network"
  cidr             = "${var.cidr["client"]}"
  vpc_id           = "${cloudstack_vpc.ceph.id}"
  zone             = "${var.zone}"
  network_offering = "${var.offering["network"]}"
  acl_id           = "${var.acl}"
}

resource "cloudstack_network" "cluster_network" {
  name             = "ceph-cluster-network"
  cidr             = "${var.cidr["cluster"]}"
  vpc_id           = "${cloudstack_vpc.ceph.id}"
  zone             = "${var.zone}"
  network_offering = "${var.offering["network"]}"
  acl_id           = "${var.acl}"
}

resource "cloudstack_instance" "ceph_mon" {
  count            = "${var.instances["num_mon"]}"
  name             = "ceph-mon-${count.index + 1}"
  service_offering = "${var.offering["service"]}"
  network_id       = "${cloudstack_network.client_network.id}"
  template         = "${var.template}"
  zone             = "${var.zone}"
  keypair          = "${var.keypair}"
  ip_address       = "${cidrhost(var.cidr["client"], count.index + 10)}"
  expunge          = true
}

resource "cloudstack_instance" "ceph_node" {
  count            = "${var.instances["num_node"]}"
  name             = "ceph-node-${count.index + 1}"
  service_offering = "${var.offering["service"]}"
  network_id       = "${cloudstack_network.client_network.id}"
  template         = "${var.template}"
  zone             = "${var.zone}"
  keypair          = "${var.keypair}"
  ip_address       = "${cidrhost(var.cidr["client"], count.index + 100)}"
  expunge          = true
}

resource "cloudstack_nic" "cluster_network" {
  count              = "${var.instances["num_node"]}"
  network_id         = "${cloudstack_network.cluster_network.id}"
  virtual_machine_id = "${element(cloudstack_instance.ceph_node.*.id, count.index)}"
  ip_address         = "${cidrhost(var.cidr["cluster"], count.index + 100)}"
}

resource "cloudstack_disk" "ceph_osd" {
  count              = "${var.instances["num_osd"]}"
  name               = "OSD-${count.index + 1}"
  attach             = "true"
  disk_offering      = "MCC.v1-20GB"
  virtual_machine_id = "${element(cloudstack_instance.ceph_node.*.id, count.index)}"
  zone               = "${var.zone}"
}
