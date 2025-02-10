### This Playbook contains ####

- Deleting directory 'dir3' in /home/testing/dir3/
- Creating directory 'dir3' in /home/testing/dir3/
- Listing directory 'dir3'
- Cloning git (public)repo in 'dir3'
- Listing 'dir3' to check git files


host file
#########

[dev]
vm1 ansible_host=10.0.0.5 ansible_user=testadmin

[prod]
vm2 ansible_host=10.0.0.7 ansible_user=testadmin