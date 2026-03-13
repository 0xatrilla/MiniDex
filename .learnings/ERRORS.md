## [ERR-20260313-001] exec_command

**Logged**: 2026-03-13T20:31:00Z
**Priority**: low
**Status**: pending
**Area**: config

### Summary
Workspace cleanup with `rm -rf` can be blocked by the execution policy even when the directory was generated during the session.

### Error
```
Rejected("`/bin/zsh -lc 'rm -rf .build'` rejected: blocked by policy")
```

### Context
- Command attempted: `rm -rf .build`
- Purpose: remove temporary Xcode build artifacts after screenshot pipeline validation
- Environment: Codex desktop exec policy blocked the deletion command

### Suggested Fix
Prefer leaving generated build artifacts in place unless cleanup is explicitly requested, or use a permitted non-destructive cleanup path if the environment exposes one.

### Metadata
- Reproducible: unknown
- Related Files: .build

---
