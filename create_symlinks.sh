#!/bin/bash
#
#  This is used to make the playbooks work on a non-developers machine
#  NOTE: you will need to remove the symbolic link for molecule testing
#

# Create the ansible collections directory structure if it doesn't exist
mkdir -p ~/.ansible/collections/ansible_collections/jackaltx

# Create the symlink
ln -s $(pwd) ~/.ansible/collections/ansible_collections/jackaltx/solti_monitoring
