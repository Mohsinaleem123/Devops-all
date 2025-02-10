### This Playbook contains ####

- Creating users 'user3, user4'
- Listing created users
- Listing groups with above users
- Adding users 'user3, user4' to groups 'sudo,video,audio'
- Listing groups after adding users
- Deleting above created users 'user3,user4'
- Listing users after deletion


host file
#########

[dev]
vm1 ansible_host=10.0.0.5 ansible_user=testadmin

[prod]
vm2 ansible_host=10.0.0.7 ansible_user=testadmin