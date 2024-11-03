#!/bin/bash
aws cloudformation deploy \
  --template-file CloudFormation.yaml \
  --stack-name uppgift2 \
  --parameter-overrides \
    AdminIP=0.0.0.0/0 \
    SSHKey=ssh \
    MasterUsername=rdsusername \
    MasterUserPassword=kodtillrds \
    DBName=wordpressdbnamn \
    WPTitle=wordpresstitel \
    WPAdminUser=wordpressuser \
    WPAdminPassword=wordpresskod \
    WPAdminEmail=admin@mail.se
