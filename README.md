# HomeLab Setup

## Introduction

The purpose of this repo is, selfishly, to document the setup and configuration I have outside of my network as a reference point in the future. Unselfishly I hope putting this in a public space will help others who are attempting to do a similar setup (high level defined below) be able to do so in a way that's easier than my learning epxerience and to have as a reference point of a working configuration.

### Goals of the configuration:
1. To host a personal website/blog site via Kubernetes (I specifically chose k3s) and expose the website to the internet moderately securely
2. To have the flexibliity to setup multiple different sites/services with a single domain by using the kubernetes ingress
3. To leverage letsencrypt to rollout and keep up to date a valid TLS certificate for the exposed sites and services
4. Decent web interface/gui to view and manage kubernetes
5. Ability to scale pods up or down across nodes

### What's doing the work:
- Kubernetes = [K3S](https://k3s.io/)
- Load Balancer = Since this is not a cloud configuration, using [metallb](https://metallb.universe.tf/) makes the most sense
- NFS = Needed to scale website app servers across worker nodes
- [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) = [nginx](https://github.com/kubernetes/ingress-nginx) - Serves as reverse proxy for kubernetes services and can serve content based on domain name used
- TLS Website certificates = Both [cert-manager](https://github.com/cert-manager/cert-manager) and [lets encrypt](https://letsencrypt.org/how-it-works/)

Network accessible service IPs will be assigned via MetalLB and yamls (i.e. using 192.168.1.200-210). Network router dhcp reservation space must be updated to accomodate the range used or IP conflicts will occur.

# sftp client shell script
 - Configuration file should be stored in /etc/sftp.conf
 - CANNOT have any filenames with ' -' in them
