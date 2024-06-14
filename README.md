# https://identity.plus

## Requirements for Identity Plus POC:
- A small VPC, which is secured from the outside world so you can comfortably log in via SSH into VMs.
- A LAN to connect all the VMs in the VPC

- Provision 3 VMs, 1GB RAM and 30GB disk should be sufficient, basically to fit the OS. 
- x86 64bit architectures and the scripts are configured for Ubuntu base images.

- The machines will need docker environment, but they are configured in the scripts: https://github.com/IdentityPlus/instant-mtls/tree/master/Instant%20mTLS%20Demo

- The VPC needs to have an internet exit (egress to connect to Identity Plus)

- One of the VMs, the mTLS Gateway needs a public IP to expose port 443 to the general Internet (it will use mTLS).

About 1.5 to 2 hours time to walk through the steps comfortably and allow time for questions and answers.

