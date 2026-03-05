#!/usr/bin/env zsh

# https://code.claude.com/docs/en/amazon-bedrock
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=eu-west-1

export ANTHROPIC_MODEL='arn:aws:bedrock:eu-west-1:118330671040:inference-profile/global.anthropic.claude-sonnet-4-6'
export ANTHROPIC_SMALL_FAST_MODEL='arn:aws:bedrock:eu-west-1:118330671040:inference-profile/global.anthropic.claude-haiku-4-5-20251001-v1:0'

if [[ "$1" == "opus" ]]; then
    export ANTHROPIC_MODEL='arn:aws:bedrock:eu-west-1:118330671040:inference-profile/global.anthropic.claude-opus-4-6-v1'
    shift
fi

claude $*
