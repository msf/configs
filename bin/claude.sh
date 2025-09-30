#!/usr/bin/env zsh

# unset AWS_ACCESS_KEY_ID
# unset AWS_SECRET_ACCESS_KEY
# unset AWS_SESSION_TOKEN
# aws sts get-caller-identity --no-cli-pager >&2
# 
# creds_path="$HOME/.cache/gsts/credentials"
# if [[ ! -f "$creds_path" ]]; then
#    echo "❌ gsts credentials file not found at $creds_path"
#    return 1
# fi
# 
# ini_get() {
#    grep -E "^$1\s*=" "$creds_path" | head -n 1 | sed -E "s/^$1\s*=\s*//"
# }
# 
# 
# export AWS_ACCESS_KEY_ID=$(ini_get aws_access_key_id)
# export AWS_SECRET_ACCESS_KEY=$(ini_get aws_secret_access_key)
# export AWS_SESSION_TOKEN=$(ini_get aws_session_token)

export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-east-1
export ANTHROPIC_MODEL='arn:aws:bedrock:us-east-1:118330671040:inference-profile/anthropic.claude-sonnet-4-5-20250929-v1:0'
export ANTHROPIC_SMALL_FAST_MODEL='arn:aws:bedrock:eu-west-1:118330671040:inference-profile/eu.anthropic.claude-3-5-haiku-20241022-v1:0'

claude $*
