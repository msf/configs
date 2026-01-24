#!/usr/bin/env zsh

# https://code.claude.com/docs/en/amazon-bedrock
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=eu-west-1

# Recommended output token settings for Bedrock
#export CLAUDE_CODE_MAX_OUTPUT_TOKENS=4096
#export MAX_THINKING_TOKENS=1024

export ANTHROPIC_MODEL='arn:aws:bedrock:eu-west-1:118330671040:inference-profile/global.anthropic.claude-sonnet-4-5-20250929-v1:0'
export ANTHROPIC_SMALL_FAST_MODEL='arn:aws:bedrock:eu-west-1:118330671040:inference-profile/global.anthropic.claude-haiku-4-5-20251001-v1:0'

if [[ "$1" == "opus" ]]; then
    export ANTHROPIC_MODEL='arn:aws:bedrock:eu-west-1:118330671040:inference-profile/global.anthropic.claude-opus-4-5-20251101-v1:0'
    shift
fi

claude $*
