#!/bin/bash
# Configure DNS records for tv.mfilipe.eu via Gandi API

TOKEN="1543b819a61d06789ece8df99c3a42f8587dc0d9"
DOMAIN="mfilipe.eu"
IPV4="93.108.195.82"
IPV6="2001:818:e3da:f300:63f8:2c40:e3df:65c1"

# Delete old CNAME for tail.mfilipe.eu if exists
curl -X DELETE "https://api.gandi.net/v5/livedns/domains/${DOMAIN}/records/tail/CNAME" \
  -H "Authorization: Bearer ${TOKEN}"

# Add A record for tv.mfilipe.eu
curl -X PUT "https://api.gandi.net/v5/livedns/domains/${DOMAIN}/records/tv/A" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"rrset_values\": [\"${IPV4}\"], \"rrset_ttl\": 300}"

# Add AAAA record for tv.mfilipe.eu
curl -X PUT "https://api.gandi.net/v5/livedns/domains/${DOMAIN}/records/tv/AAAA" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"rrset_values\": [\"${IPV6}\"], \"rrset_ttl\": 300}"

echo ""
echo "DNS records configured:"
echo "tv.mfilipe.eu  A     ${IPV4}"
echo "tv.mfilipe.eu  AAAA  ${IPV6}"
