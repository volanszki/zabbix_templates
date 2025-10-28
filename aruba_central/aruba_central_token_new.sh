#!/bin/bash

basedir=central
source $basedir/variables

curl -s --noproxy '*' -v --cookie-jar $basedir/cookie --location --request POST "$base_url/oauth2/authorize/central/api/login?client_id=$client_id" \
--header "Content-Type: application/json" \
--data-raw "{
    \"username\": \"$account_username\",
    \"password\": \"$account_password\"
}" > $basedir/result1.raw 2>&1

grep 'Added cookie' $basedir/result1.raw > $basedir/result1.filtered

csrftoken=$(grep csrftoken $basedir/result1.filtered | awk -F '"' '{print $2}')
session=$(grep session $basedir/result1.filtered | awk -F '"' '{print $2}')

curl -s --noproxy '*' --request POST "$base_url/oauth2/authorize/central/api?client_id=$client_id&response_type=code&scope=all" \
--header "Content-Type: application/json" \
--header "Cookie: session=$session" \
--header "X-CSRF-Token: $csrftoken" \
--data-raw "{
\"customer_id\": \"$customer_id\"
}" > $basedir/result2.raw

auth_code=$(cat $basedir/result2.raw | jq -r .auth_code)

curl -s --noproxy '*' --request POST "$base_url/oauth2/token" \
--header "Content-Type: application/json" \
--data "{
    \"client_id\": \"${client_id}\",
    \"client_secret\": \"${client_secret}\",
    \"grant_type\": \"authorization_code\",
    \"code\": \"${auth_code}\"         
}" > $basedir/result3.raw

refresh_token=$(cat $basedir/result3.raw | jq -r .refresh_token)
access_token=$(cat $basedir/result3.raw | jq -r .access_token)

if [ "$refresh_token" == "null" ]; then
    echo "something went wrong... exiting now"
    exit 1
fi

echo $access_token > $basedir/token_access.latest
echo $refresh_token > $basedir/token_refresh.latest

echo "access_token: $access_token"
echo "refresh_token: $refresh_token"

curl -s --request POST \
--url "$zabbix_url/api_jsonrpc.php" \
--header "Authorization: Bearer $zabbix_api_token" \
--header "Content-Type: application/json-rpc" \
--data "{\"jsonrpc\": \"2.0\",\"method\": \"usermacro.update\",\"params\": {\"hostmacroid\": \"${zabbix_macro_id}\",\"value\": \"${access_token_new}\"},\"id\": 1}"

rm -f $basedir/cookie
