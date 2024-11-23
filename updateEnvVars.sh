#!/bin/bash

echo "Select region:"
echo "1. us-east-1"
echo "2. us-east-2"
echo "3. us-west-2"
echo "4. ap-south-1"
echo "5. eu-north-1"

read -p "Enter region number: " region_number
case $region_number in
    1)
        region="us-east-1"
        ;;
    2)
        region="us-east-2"
        ;;
    3)
        region="us-west-2"
        ;;
    4)
        region="ap-south-1"
        ;;
    5)
        region="eu-north-1"
        ;;
    *)
        echo "Invalid region number. Exiting..."
        exit 1
        ;;
esac

echo "Select environment:"
echo "1. Development (us-east-1)"
echo "2. Staging (us-west-2)"
echo "3. Production (ap-south-1, eu-north-1, us-east-2)"

read -p "Enter environment number: " environment_number
case $environment_number in
    1)
        environment="development"
        ;;
    2)
        environment="staging"
        ;;
    3)
        environment="production"
        ;;
    *)
        echo "Invalid environment number. Exiting..."
        exit 1
        ;;
esac

echo "Select app type:"
echo "1. Webapp"
echo "2. Common"

read -p "Enter app type number: " app_type_number
case $app_type_number in
    1)
        app_type="webapp"
        ;;
    2)
        app_type="common"
        ;;
    *)
        echo "Invalid app type number. Exiting..."
        exit 1
        ;;
esac

# Change appName of application
appName=" "

read -p "Enter key: " key
read -p "Enter value: " value

if [ -n "$key" ] && [ -n "$value" ] && [ -n "$region" ] && [ -n "$environment" ]; then
    aws configure set cli_follow_urlparam false
    if [ "$app_type" = "common" ]; then
        parameter_name="/$environment/$app_type/$key"
        aws ssm put-parameter --region "$region" --name "$parameter_name" --value "$value" --type String --overwrite
    else
        parameter_name="/$environment/$app_type/$appName/$key"
        aws ssm put-parameter --region "$region" --name "$parameter_name" --value "$value" --type String --overwrite
    fi

    echo "Parameter added successfully:"
    echo "Parameter Path: $parameter_name"
    echo "Region: $region"
    echo "Environment: $environment"
    echo "Value: $value"
else
    echo "Input missing. Exiting..."
fi
