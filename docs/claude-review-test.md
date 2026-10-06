# Claude PR Review Integration Test

This file exists only to validate the automatic Claude Code pull-request review workflow.

Expected behavior:

- Opening this PR triggers the Claude PR Review workflow.
- Claude reviews the change and may publish a review/comment.
- Claude must not modify files, create commits, push changes, or merge the PR.
- No application behavior is changed by this test.

After the integration is confirmed, this test PR can be closed without merging.
