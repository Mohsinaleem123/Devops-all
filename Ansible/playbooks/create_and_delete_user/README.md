### This Playbook contains ####

- Creating users 'user1, user2'
- Listing created users
- Listing groups with above users
- Deleting above created user 'user1'
- Listing users after deletion


host file
#########

[dev]
vm1 ansible_host=10.0.0.5 ansible_user=testadmin

[prod]
vm2 ansible_host=10.0.0.7 ansible_user=testadmin
