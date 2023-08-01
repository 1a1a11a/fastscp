#!/bin/bash

set -eu
# set -x

# dependency
# jq, python3, parallel, wget, curl

# WARNING: this script will expose your data to the public, so only use it to transfer public data
# To solve the security issue: 
# 1. use a private cloudflare account
# 2. set your own HTTP server password
# 3. use HTTPS


# load config
if [ -f ./api.sh ]; then source ./api.sh; fi
# load private config if exists
if [ -f ./priv/api.sh ]; then source ./priv/api.sh; fi


SRC_PATH=$(dirname $(readlink -f $0))

verbose=0
has_cleanup=0
server="src"    # start the web server at the src side
server_pid=0   # the pid of the web server, used to kill the server
server_port=8880 # https://developers.cloudflare.com/fundamentals/get-started/reference/network-ports/
parallel_download=1


function usage() {
    echo "example: bash $0 ./ user@remote:/path/to/dest/"
}

function log() {
    echo $@;
    echo $(date) $@ >> /tmp/fastscp.log
}

function log_info() {
    log "$@"
}

function log_debug() {
    if [[ ${verbose} == 1 ]]; then
        log "$@"
    fi
}

function log_warn() {
    log $@
}

function log_error() {
    log $@
    exit 1
}





# parse args
if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage
    exit 1
fi

# skip -r
if [[ $1 == "-r" ]]; then 
    shift;
fi

src_path=$1
dest_user=$(echo $2 | cut -d@ -f1)
if [[ "${dest_user}" == "${2}" ]]; then
    log_error "please specify the dest user, e.g. user@remote:/path/to/dest/"
fi
dest=$(echo $2 | cut -d@ -f2 | cut -d: -f1)
dest_path=$(echo $2 | cut -d@ -f2 | cut -d: -f2)
shift;shift;


while [ $# -gt 0 ]; do
    case $1 in
        -w | --server )           shift
            server=$1
        ;;
        -v | --verbose )    verbose=1
        ;;
        -h | --help )           usage
            exit
        ;;
        * )                     usage
            exit 1
    esac
    shift
done



function cleanup() {
    if [[ ${has_cleanup} == 1 ]]; then
        return;
    fi

    # when killing the python webserver, we will trigger ERR and 
    # enter cleanup more than once
    has_cleanup=1

    if [[ ${server_pid} != 0 ]]; then 
        log_info stop server pid ${server_pid};
        # FIX: somehow a new python process is started after killing the old one
        kill -9 ${server_pid};
        pkill -f "http.server ${server_port}";
    fi

    if [[ -n ${ZONE_ID:-} && -n ${ZONE:-} && -n ${CLOUDFLARE_API_TOKEN:-} ]]; then
        remove_dns || true;
    fi
}
trap cleanup SIGINT
trap cleanup ERR;


export src_ip=$(curl ifconfig.me --silent)
# export dest_ip=$(ssh ${dest_user}@${dest} "curl ifconfig.me --silent")

if [[ ${server} == "src" ]]; then
    server_ip=${src_ip}

    # setup a HTTP server locally
    pkill -f "http.server ${server_port}" 2> /dev/null || true;
    cd ${src_path};
    python3 -m http.server ${server_port} --bind 0.0.0.0 2>/dev/null &
    server_pid=$!

    still_running=$(sleep 2; ps -ef | grep ${server_pid} | grep -v grep | wc -l)
    if [[ ${still_running} == 0 ]]; then
        server_pid=0
        log_error "server is not started";
    else
        log_debug "server pid ${server_pid}";
    fi
else
    server_ip=${dest_ip}

    ssh ${dest_user}@${dest} "python3 -m http.server ${server_port} --bind 0.0.0.0 > /tmp/fastscp.server.log" &

fi


# add a new record, usage add_dns zone_id token src_ip
function add_dns() {
    zoneid=$1
    cloudflare_api_token=$2
    subdomain_name=$3
    src_ip=$4

    s=$(curl --request POST \
        --url https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer ${cloudflare_api_token}" \
        --data "{
            \"content\": \"${src_ip}\",
            \"name\": \"${subdomain_name}\",
            \"proxied\": true,
            \"type\": \"A\",
            \"ttl\": 300
        }" --silent)
    result=$(echo $s | jq .success)
    log_info "add DNS record result ${result}";
}

# remove previous DNS record, usage remove_dns zone_id token server_url
function remove_dns() {
    zoneid=$1
    cloudflare_api_token=$2
    server_url=$3

    # get fastscp record ip
    s=$(curl --request GET \
        --url https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer ${cloudflare_api_token}" \
        --silent)
    log_debug "get DNS records ${s}";

    result=$(echo $s | jq .success)
    if [[ ${result} != "true" ]]; then
        log_warn "get DNS records failed ${s}";
    fi

    record_id=$(echo $s | jq -r ".result[] | select(.name==\"${server_url}\") .id")
    log_debug "record id ${record_id}";

    # remove previous DNS record
    if [[ -z ${record_id} ]]; then
        log_warn "there's no previous record";
    else
        result=$(curl --request DELETE \
            --url https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records/${record_id} \
            --header 'Content-Type: application/json' \
            --header "Authorization: Bearer ${cloudflare_api_token}" \
            --silent | jq .success)
        log_info "removed the added record ${result}";
    fi
}

# get a fastscp url pointing to the ip address
function get_shared_dns() {
    r=$(curl --request GET --url https://api2.fastscp.com/register?ip=${src_ip} --silent)
    if [[ "$r" == *".fastscp.com" ]]; then
        server_url="${r}:${server_port}"
        log_info "shared server url ${server_url}";
    else
        log_error "failed to get shared server url ${r}";
    fi
}


if [[ -n ${ZONE_ID:-} && -n ${ZONE:-} && -n ${CLOUDFLARE_API_TOKEN:-} ]]; then
    # TODO: this may become a problem if two people try it at the same time
    subdomain_name=fastscp-$(date +%s)
    server_url=${subdomain_name}.${ZONE}:${server_port}

    add_dns ${ZONE_ID} ${CLOUDFLARE_API_TOKEN} ${subdomain_name} ${src_ip};
else
    get_shared_dns;
fi


echo '#########################################'
echo "source ip ${src_ip}, dest ${dest}, dest path ${dest_path}, dest user ${dest_user}"
echo "server ip ${server_ip}, server url ${server_url}, python web server pid ${server_pid}"
echo '#########################################'


filename="task_$(date +%s)"
for f in $(find . -type f); do
    echo wget -q http://${server_url}/${f:2} -O ${f:2} >> /tmp/${filename}.wget;
    echo "mkdir -p $(dirname ${f:2})" >> /tmp/${filename}.mkdir;
done
echo '#!/bin/bash' > /tmp/${filename};
echo 'set -eux' >> /tmp/${filename};
sort /tmp/${filename}.mkdir | uniq >> /tmp/${filename};
sort /tmp/${filename}.wget | uniq >> /tmp/${filename};

scp /tmp/${filename} ${dest_user}@${dest}:/tmp/${filename} >> /tmp/fastscp.log;
rm /tmp/${filename} /tmp/${filename}.*;

# download files on dest
# TODO: change to wait till DNS is ready
log_info "wait 2 seconds for DNS to be ready..."
sleep 2;
if [[ ${parallel_download} -le 1 ]]; then
    ssh ${dest_user}@${dest} """
        mkdir -p ${dest_path} 2>/dev/null; 
        mv /tmp/${filename} ${dest_path}; 
        cd ${dest_path}; 
        bash ${filename};
        rm ${filename};
    """;
else
    ssh ${dest_user}@${dest} """
        mkdir -p ${dest_path} 2>/dev/null; 
        mv /tmp/${filename} ${dest_path}; 
        cd ${dest_path}; 
        parallel -j${parallel_download} < ${filename}; 
        rm ${filename};
    """;
fi

# sleep 1200;
cleanup;

echo '######################################'
echo "all transfers have finished successfully, files and bytes are transferred"
echo '######################################'


