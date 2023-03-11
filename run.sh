#!/bin/bash

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

lamarr='391875474311'

clear
pgrep -x Docker >/dev/null && (printf "\n${green}Docker Daemon found!!!${reset}\n") || (printf "\n${green}Docker Daemon not found. Starting Docker...${reset}\n" && open -a Docker && sleep 30)

# Login with Lamarr admin account (The Lamarr Group)
rm logs/accounts.txt

printf "\n${green}Checking prerequsites...${reset}\n"
brew list jq || brew update && brew install jq

# Getting cross account access
aws sts assume-role --role-arn arn:aws:iam::$lamarr:role/murrayboyd-to-lamarr-cross-access --role-session-name account-$lamarr --query "Credentials" > logs/$lamarr.json;

AWS_ACCESS_KEY_ID=$(cat logs/$lamarr.json |jq -r .AccessKeyId);
AWS_SECRET_ACCESS_KEY=$(cat logs/$lamarr.json |jq -r .SecretAccessKey);
AWS_SESSION_TOKEN=$(cat logs/$lamarr.json |jq -r .SessionToken);

aws organizations list-accounts-for-parent --parent-id ou-r8uf-8e5837ve |jq -r '.Accounts |map(.Id) |join("\n")' |tee -a logs/accounts.txt

clear 
accs=""
read -p "${green}Do you want to specify accounts [n]: ${reset}" accs 
printf "\n"

dry_run="y"
are_you_sure="n"

read -p "${green}Dry Run? [y/n]: ${reset}" dry_run
printf "\n"
if [[ $dry_run != "y" ]]; then
    read -p "${green}This will Nuke recources. Are you sure? [y/n]: ${reset}" are_you_sure
    printf "\n"
fi


while read -r line; do
    if [[ $accs != "n" && $accs != "*" && $accs != ""  && ! " ${accs[@]} " =~ " ${line} " ]]; then
        continue
    fi
    echo "Assuming Role for Account $line";
    aws sts assume-role --role-arn arn:aws:iam::$line:role/lamarr-master-admin-access --role-session-name account-$line --query "Credentials" > logs/$line.json;
    cat logs/$line.json
    ACCESS_KEY_ID=$(cat logs/$line.json |jq -r .AccessKeyId);
    SECRET_ACCESS_KEY=$(cat logs/$line.json |jq -r .SecretAccessKey);
    SESSION_TOKEN=$(cat logs/$line.json |jq -r .SessionToken);
    
    cd config
    cp default-config.yaml $line.yaml;
    sed -i '' "s/000000000000/$line/g" $line.yaml;
    cd ..

    echo "Configured aws-nuke-config.yaml";
    echo "Running Nuke on Account $line";

    location=$(pwd)
    current_time=$(date "+%Y.%m.%d-%H.%M.%S")

    if [[ $dry_run != "y" && $are_you_sure == "y" ]]; then
        printf "\n${red}Running No Dry Run Nuking...${red}\n"
        # docker run --rm -v $location/config/$line.yaml:/home/aws-nuke/config.yaml -v ~/.aws:/home/aws-nuke/.aws docker.io/rebuy/aws-nuke --config /home/aws-nuke/config.yaml --access-key-id $ACCESS_KEY_ID --secret-access-key $SECRET_ACCESS_KEY --session-token $SESSION_TOKEN --force --no-dry-run --force-sleep 10 |tee -a logs/aws-nuke-$line-$current_time.log;
        docker run --rm -v $location/config/$line.yaml:/home/aws-nuke/config.yaml -v ~/.aws:/home/aws-nuke/.aws docker.io/rebuy/aws-nuke --config /home/aws-nuke/config.yaml --access-key-id $ACCESS_KEY_ID --secret-access-key $SECRET_ACCESS_KEY --session-token $SESSION_TOKEN --force --force-sleep 3 |tee -a logs/aws-nuke-$line-$current_time.log;
        printf "${reset}\n"
    else
        docker run --rm -v $location/config/$line.yaml:/home/aws-nuke/config.yaml -v ~/.aws:/home/aws-nuke/.aws docker.io/rebuy/aws-nuke --config /home/aws-nuke/config.yaml --access-key-id $ACCESS_KEY_ID --secret-access-key $SECRET_ACCESS_KEY --session-token $SESSION_TOKEN --force --force-sleep 3 |tee -a logs/aws-nuke-$line-$current_time.log;
    fi
done < logs/accounts.txt
printf "\n\n${green}Completed Nuke Process for all accounts${green}\n"
