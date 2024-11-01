#!/bin/bash
aws cloudformation deploy \
  --template-file CloudFormation3.yaml \
  --stack-name uppgift2 \
  --parameter-overrides \
    MasterUsername=admin \
    MasterUserPassword=Password123. \
    DBName=wordpressdb \
    WPAdminPassword=fung \
    SSHKey=ssh