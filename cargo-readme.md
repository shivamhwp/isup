# isup

checks whether a particular site/service/route is up or not.

## features

- check if a website or service is up, also can check if a particular route is up or not.
- check multiple websites/services at once,
- configurable timeout

## installation

### using cargo

```bash
cargo install isup
```

## usage

```bash
# basic usage
isup example.com

# with explicit https
isup https://example.com

# check multiple sites
isup example.com google.com github.com

# with custom timeout (in seconds)
isup example.com --timeout 5
isup example.com -t 5

```

## examples

```bash
# check if google is up
isup google.com

# check if multiple services are up
isup google.com github.com api.example.com

# check if a specific api endpoint is up
isup api.example.com/health

# check with a longer timeout for slow services
isup slow-service.example.com --timeout 30
```
