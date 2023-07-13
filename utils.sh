#!/bin/bash


if [ -f .api.sh ]; then source .api.sh; fi

function remove_all_dns_entries() {
    # get all dns entries
    s=$(curl --request GET \
        --url https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer ${cloudflare_api_token}" \
        --silent)
    record_ids=$(echo $s | jq -r ".result[].id")
    # echo -e "get DNS records ${record_ids[@]}"
    
    for id in ${record_ids[@]}; do
        echo -e ${id};
        result=$(curl --request DELETE \
            --url https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records/${id} \
            --header 'Content-Type: application/json' \
            --header "Authorization: Bearer ${cloudflare_api_token}" \
            --silent | jq .success)
        echo -e "removed dns record ${id} result ${result}"
    done
}


