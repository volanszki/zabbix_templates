#!/bin/bash

basedir=central
source $basedir/variables

refresh_token_current=$(cat $basedir/token_refresh.latest | tr -d '\n')
refresh_token_new=""

curl -s --noproxy '*' --request POST "$base_url/oauth2/token?client_id=$client_id&client_secret=$client_secret&grant_type=refresh_token&refresh_token=$refresh_token_current" > $basedir/result4.raw

refresh_token_new=$(cat $basedir/result4.raw | jq -r .refresh_token)
access_token_new=$(cat $basedir/result4.raw | jq -r .access_token)
expires_in=$(cat $basedir/result4.raw | jq -r .expires_in)

if [ "$refresh_token_new" == "null" ]; then
    echo "something went wrong... exiting now"
    exit 1
fi

echo $access_token_new > $basedir/token_access.latest
echo $refresh_token_new > $basedir/token_refresh.latest

echo "access_token: $access_token_new"
echo "refresh_token: $refresh_token_new"
echo "expires_in: $expires_in"

curl -s --request POST \
--url "$zabbix_url/api_jsonrpc.php" \
--header "Authorization: Bearer $zabbix_api_token" \
--header "Content-Type: application/json-rpc" \
--data "{\"jsonrpc\": \"2.0\",\"method\": \"usermacro.update\",\"params\": {\"hostmacroid\": \"${zabbix_macro_id}\",\"value\": \"${access_token_new}\"},\"id\": 1}"
