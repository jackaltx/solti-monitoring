#!/bin/bash

# Initialize collection
ansible-galaxy collection init jackaltx.solti_ensemble

cd jackaltx/solti_ensemble

# Create core directories
mkdir -p {data,docs,verify_output,.github/workflows}
mkdir -p molecule
mkdir -p roles

# Create verify_output/.gitignore
echo "*
!.gitignore" > verify_output/.gitignore

# Copy shared molecule configurations if monitoring exists
MONITORING_PATH="../../solti-monitoring"
if [ -d "$MONITORING_PATH/molecule/shared" ]; then
    cp -r $MONITORING_PATH/molecule/shared/* molecule/shared/
    cp $MONITORING_PATH/molecule/shared/requirements.yml molecule/shared/
fi

# Create basic role files and molecule configurations
# [Previous role creation code remains the same]

# Create capabilities.yml
# [Previous capabilities.yml content remains the same]

echo "Created solti-ensemble Galaxy collection structure"