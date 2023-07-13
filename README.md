# fastscp: a tool for fast Internet transfer

fastscp uses the Internet routes from Cloudflare to quickly transfer data between two hosts. It requires at leazt one host having a public IP address.

![doc/screens0.gif](/doc/screens0.gif)

## Mechanism: 
1. set up a HTTP server on source or dest
2. use Cloudflare to proxy the HTTP traffic so that traffic goes from src -> cf_edge -> cf_internal -> cf_edge -> dest, this often maximizes bandwidth due to the Cloudflare inter-connections
3. download the files from the proxied HTTP server


![doc/d1.gif](/doc/d1.gif)

![doc/d2.gif](/doc/d2.gif)


## Dependency
fastscp uses `jq`, `parallel` and `python3`, on Ubuntu you can install using

```
sudo apt-get install -yqq jq parallel wget
```


## How to use
### Install

```
sudo curl -s https://raw.githubusercontent.com/1a1a11a/fastscp/main/fastscp.sh -o /usr/local/bin/fastscp && sudo chmod +x /usr/local/bin/fastscp
```

### Use
```
fastscp data ${USER}@${HOST}:/PATH/
```


## Note
fastscp is not designed for production. It is a tool that I use to speed up data transfer from CMU and Cloudlab. Most of my data are not private, so I privacy is not a design consideration. Moreover, when open-sourcing the tool, to make it easy to use, I created a shared account on Cloudflare, which means anyone is able to see your data during the tansfer. 

** Do the following if you need better privacy and security **
* use your own cloudflare account, put your zone information in `api.sh`
* use the `authHTTPServer.py` instead of open HTTP web server
* use HTTPS instead of HTTP at source for encryption
* use a white list of IPs in the Python web HTTP server



## Readmap
* make port selection automatically
* support compression
* support parallel downloads
* support machines behind NAT
* add stat reporting function


