#!/usr/bin/env zsh

export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-east-1
export ANTHROPIC_MODEL='arn:aws:bedrock:us-east-1:118330671040:inference-profile/us.anthropic.claude-sonnet-4-5-20250929-v1:0'
export ANTHROPIC_SMALL_FAST_MODEL='arn:aws:bedrock:eu-west-1:118330671040:inference-profile/eu.anthropic.claude-3-5-haiku-20241022-v1:0'

claude $*
