#!/bin/bash
#change the value of the parameters for your wp env.
aws cloudformation deploy \
  --template-file CloudFormation.yaml \
  --stack-name uppgift2 \
  --parameter-overrides \
    AdminIP=0.0.0.0/0 \
    SSHKey=ssh \
    MasterUsername=admin \
    MasterUserPassword=Password123. \
    DBName=wordpressdb \
    WPTitle=Awsesome \
    WPAdminUser=admin \
    WPAdminPassword=password \
    WPAdminEmail=sample@mail.com
