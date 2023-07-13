#!/bin/bash
set -eu
# set -x

if [ -f .api.sh ]; then source .api.sh; fi

function remove_all_dns_entries() {
    # get all dns entries
    s=$(curl --request GET \
        --url https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" --silent)
    declare -a record_ids=($(echo $s | jq -r ".result[].id"))
    declare -a domain_names=($(echo $s | jq -r ".result[].name"))
    # echo -e "get DNS records ${record_ids[@]}"
    
    n=$((${#record_ids[@]}-1))
    for id in `seq 0 $n`; do
        # echo -e $id ${record_ids[$id]} ${domain_names[$id]};
        if [[ ${domain_names[$id]} == "fastscp-"*".fastscp.com" ]]; then
            result=$(curl --request DELETE \
                --url https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${record_ids[$id]} \
                --header 'Content-Type: application/json' \
                --header "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
                --silent | jq .success)
            echo -e "removed $id ${record_ids[$id]} ${domain_names[$id]} ${result}"
        fi    
    done
}

remove_all_dns_entries;
