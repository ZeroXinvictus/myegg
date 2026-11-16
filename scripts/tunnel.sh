#!/bin/bash

start_cf_tunnel() {
  [ "$ENABLE_CF_TUNNEL" != "true" ] && return 0
  [ -z "$CF_TOKEN" ] && return 0

  cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN" >/tmp/cloudflared.log 2>&1 &
  CF_TUNNEL_PID=$!
  export CF_TUNNEL_PID
}
