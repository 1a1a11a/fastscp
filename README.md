# fastscp: a tool for fast Internet transfer

fastscp uses the Internet routes from Cloudflare to quickly transfer data between two hosts. 
Mechanism: 

WARN: the tool is not _SECURE_ because we use a _shared_ cloudflare zone, **use your own cloudflare account if you need privacy and security**.


### Dependency
fastscp uses `jq`, `parallel` and `python3`, on Ubuntu you can install using

```
sudo apt-get install -yqq jq parallel wget
```


## Readmap
* support password
* support DNS registry 
* make port selection automatically
* support compression
* support parallel downloads
* support machines behind NAT
* add stat reporting function


