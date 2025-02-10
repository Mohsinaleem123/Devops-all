### This Playbook contains ####

- Removing directory /home/testing/dir2
- Create directory /home/testing/dir2
- Create files 'Test.txt' in /home/testing/dir1
- Listing file /home/testing/dir1/Text.txt
- Check if Test.txt contains the string "testing"
- Listing file /home/testing/dir1/Text.txt


host file
#########

[dev]
vm1 ansible_host=10.0.0.5 ansible_user=testadmin

[prod]
vm2 ansible_host=10.0.0.7 ansible_user=testadmin