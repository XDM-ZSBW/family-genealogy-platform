# Rollback Guide - Multi-Family Foundation Migration

**Version**: v0.7.x Multi-family foundation migration  
**Created**: October 2025  
**Purpose**: Emergency rollback procedures for the multi-family platform migration

## Overview

This guide provides step-by-step rollback procedures for the multi-family foundation migration completed in batches on October 15, 2025. Each batch commit can be individually reverted if issues arise.

## Quick Reference - Rollback Points

### Tagged Versions
- `v0.6.0-gladys-migration` (1f50c96) - **SAFE ROLLBACK POINT** - Last stable pre-migration state
- `v0.7.0-alpha.1` (0209dec) - Infrastructure updates applied

### Batch Commits (Latest → Oldest)
1. **79f0c40** - `chore(config): sync misc configs, backups, and test files`
2. **47f7994** - `docs(marketing): initial collateral and live deployment tracker`  
3. **b92999b** - `feat(ci): add PowerShell deployment automation for Oracle VMs`
4. **dd506ce** - `feat(family-sites): add bull683912 and north570525 starter trees`
5. **0209dec** - `feat(infra): upgrade backend Docker and add shared components` 
6. **851864f** - `chore(legacy): remove obsolete single-family bull site`

---

## Emergency Rollback (Complete)

### Option 1: Reset to Pre-Migration State
**⚠️ WARNING: This discards ALL migration work**

```bash
# Reset to last stable state before migration
git reset --hard v0.6.0-gladys-migration
git push --force-with-lease origin feature/multi-family-foundation
```

### Option 2: Revert Entire Branch
```bash
# Create new branch from main and cherry-pick specific changes
git checkout main
git checkout -b rollback/emergency-$(date +%Y%m%d)
# Manually apply only needed changes from feature branch
```

---

## Selective Batch Rollback

### Batch 6: Configuration Files Rollback
```bash
# Revert configs and test files
git revert 79f0c40
```
**Impact**: Removes family site configs, removes emergency backup, removes test files  
**Risk**: Low - No functional impact on core platform

### Batch 5: Marketing Assets Rollback  
```bash
# Revert marketing and documentation
git revert 47f7994
```
**Impact**: Removes marketing page and deployment status docs  
**Risk**: Low - Only affects marketing presence

### Batch 4: Deployment Scripts Rollback
```bash  
# Revert PowerShell automation
git revert b92999b
```
**Impact**: Removes all deployment automation (13 .ps1 files)  
**Risk**: Medium - Must deploy manually, but sites still function

### Batch 3: Family Sites Rollback
```bash
# Revert new family site directories 
git revert dd506ce
```
**Impact**: Removes bull683912/ and north570525/ directories (1,194 files)  
**Risk**: High - Removes all new family content, breaks subdomain routing

### Batch 2: Infrastructure Rollback
```bash
# Revert Docker and shared component changes
git revert 0209dec
```  
**Impact**: Reverts Dockerfile and shared components  
**Risk**: Medium - May break multi-tenant backend functionality

### Batch 1: Legacy Content Rollback  
```bash
# Restore deleted legacy bull family site
git revert 851864f
```
**Impact**: Restores deleted 2-family-sites/bull/ (1,160 files, 177k deletions)  
**Risk**: Low risk to rollback, but creates path conflicts with new bull683912/

---

## Partial Rollback Scenarios

### Scenario 1: Keep Infrastructure, Remove Content
```bash
# Keep Docker/infra changes, remove family sites and automation
git revert 79f0c40 47f7994 b92999b dd506ce
# Keeps: Infrastructure updates (Batch 2) + Legacy deletion (Batch 1)
```

### Scenario 2: Keep Everything Except Automation
```bash  
# Remove only deployment scripts
git revert b92999b
```

### Scenario 3: Emergency Content Recovery
```bash
# Restore original bull family content for emergency access
git revert 851864f
# Then manually resolve conflicts with bull683912/ if needed
```

---

## Rollback Verification Steps

After any rollback operation:

1. **Verify Git State**:
   ```bash
   git status
   git log --oneline -5
   ```

2. **Check File Structure**:
   ```bash
   ls -la 2-family-sites/
   ls -la *.ps1 2>/dev/null || echo "No PS1 files (expected if automation reverted)"
   ```

3. **Test Backend Docker Build**:
   ```bash
   cd 1-backend
   docker build -t test-build .
   ```

4. **Verify Family Site Access**:
   ```bash
   # Check content exists in expected directories
   [ -d "2-family-sites/bull" ] && echo "Legacy bull/ exists" || echo "Legacy bull/ removed"
   [ -d "2-family-sites/bull683912" ] && echo "New bull683912/ exists" || echo "New bull683912/ removed"
   ```

---

## Recovery from Failed Rollback

If a rollback operation fails or creates conflicts:

### Step 1: Abort Current Operation
```bash  
git revert --abort  # or git reset --abort
```

### Step 2: Create Recovery Branch
```bash
git checkout -b recovery/rollback-$(date +%Y%m%d-%H%M)
```

### Step 3: Manual File Recovery
```bash
# Extract specific files from known good commit
git checkout v0.6.0-gladys-migration -- path/to/specific/file
```

### Step 4: Reset Branch to Known State
```bash
# Nuclear option: Reset branch to specific commit
git reset --hard <commit-sha>
git push --force-with-lease origin feature/multi-family-foundation
```

---

## Tags for Recovery

### Delete Migration Tags (if reverting completely)
```bash
git tag -d v0.7.0-alpha.1
git push origin :refs/tags/v0.7.0-alpha.1
```

### Create Rollback Tags
```bash
git tag -a "rollback-$(date +%Y%m%d)" -m "Emergency rollback from multi-family migration"
git push origin --tags
```

---

## Contact and Escalation

1. **Check Git Status**: Always run `git status` before and after rollback operations
2. **Document Changes**: Record what was reverted and why in commit messages  
3. **Test Immediately**: Verify core functionality after any rollback
4. **Backup First**: Consider creating a backup branch before major rollbacks

### Emergency Commands Reference
```bash
# Quick status check
git log --oneline -10
git status

# Safe exploration (read-only)
git show <commit-sha>
git diff <commit-sha>^..<commit-sha>

# Create safety branch before changes
git checkout -b backup/before-rollback-$(date +%Y%m%d)
git checkout feature/multi-family-foundation
```

---

**Last Updated**: October 15, 2025  
**Migration Completion**: 6 batches committed successfully  
**Total Changes**: 2,375+ files changed, 360,000+ lines added/removed  
**Safe Rollback Point**: `v0.6.0-gladys-migration` (commit 1f50c96)