### This Playbook contains ####

- Removing directory /home/testing/dir1
- Create directory /home/testing/dir1
- Create files 'File_empty, File_with_content' in /home/testing/dir1
- Listing directory /home/testing/
- Listing directory /home/testing/dir1/
- Changing file ownership, group and permissions of (File_empty)
- Changing file ownership, group and permissions of (File_with_content)
- Listing directory /home/testing/ 
- Listing directory /home/testing/dir1/ to check permissions affected or not


host file
#########

[dev]
vm1 ansible_host=10.0.0.5 ansible_user=testadmin

[prod]
vm2 ansible_host=10.0.0.7 ansible_user=testadmin
