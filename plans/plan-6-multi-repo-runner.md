# Plan 5: Multi-Repository Runner Setup

**Status:** 🔴 Not Started
**Priority:** Medium
**Estimated Duration:** 2-3 hours

## Overview

Investigate and document how to configure a single GitHub self-hosted runner to serve multiple repositories under a personal GitHub account (not organization). Determine the best approach and provide clear setup instructions.

## Current Situation

- Runner is currently configured for single repository (`andrelin/planechaser`)
- User has multiple repositories that need CI/CD (`planechaser`, `synology-github-runner`, possibly others)
- Running under personal GitHub account (not an organization)
- Want to avoid creating a GitHub Organization if possible

## Goals

1. **Investigate** how GitHub runners work with multiple repositories
2. **Test** different approaches for multi-repo access
3. **Document** the simplest working solution
4. **Update** configuration guides with clear instructions
5. **Provide** migration steps for existing single-repo setups

## Research Questions

### Question 1: Can a repository-level runner serve other repos?

**Hypothesis:** A runner registered to one repository can pick up jobs from other repositories in the same account if:
- Workflows in other repos use `runs-on: [self-hosted, ...]`
- The runner has appropriate labels

**Need to verify:**
- Does GitHub allow this for personal accounts?
- Are there permissions/settings required?
- How does job routing work?

### Question 2: What's the difference between repo-level and org-level runners for personal accounts?

**Need to clarify:**
- Personal accounts vs Organizations
- Whether "organization-level runners" apply to personal accounts
- GitHub's actual terminology and permissions model

### Question 3: What are the actual options for personal accounts?

**Possible approaches:**
1. Single runner registered to one repo, accessed by others via labels
2. Multiple runner containers (one per repo) - not ideal for NAS
3. Using GitHub's runner sharing features
4. Creating an organization (requires transferring repos)

### Question 4: How does organization-level runner registration work?

**Need to investigate:**
- Exact steps to register runner at organization level
- GitHub API endpoints for org-level runners
- Permissions model (who can access, how jobs are routed)
- Differences from repository-level registration
- Whether it's worth creating an org for this use case

## Implementation Steps

### Phase 1: Research & Investigation (1 hour)

#### Task 1: Review GitHub Documentation
- [ ] Read official GitHub docs on self-hosted runners
- [ ] Understand runner scopes (repo, org, enterprise)
- [ ] Clarify personal account vs organization capabilities
- [ ] Document findings in this plan

**Key resources:**
- https://docs.github.com/en/actions/hosting-your-own-runners
- https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners
- GitHub API documentation for runners

#### Task 2: Test Current Behavior
- [ ] Create a test workflow in `synology-github-runner` repo
- [ ] Try to use the runner from a different repo (`planechaser`)
- [ ] Document what happens (success/failure/error messages)
- [ ] Test with different `runs-on` labels

**Test cases:**
```yaml
# Test 1: Use runner from different repo
runs-on: [self-hosted, Linux, X64]

# Test 2: Use specific labels
runs-on: [self-hosted, synology, general]

# Test 3: Check runner visibility
# GitHub UI: Settings → Actions → Runners (in each repo)
```

#### Task 3: Analyze Runner Registration
- [ ] Check how runner is currently registered
- [ ] Examine GitHub API response for runner details
- [ ] Understand runner visibility/access model
- [ ] Document current registration details

**Commands:**
```bash
# Check runner registration in container
docker exec github-runner ls -la /runner/_diag/
docker exec github-runner cat /runner/.runner

# Check GitHub API (requires PAT)
curl -H "Authorization: token $GITHUB_PAT" \
  https://api.github.com/repos/andrelin/planechaser/actions/runners
```

#### Task 3.5: Investigate Organization-Level Runner Support
- [ ] Research GitHub Organization creation process
- [ ] Understand organization runner registration API
- [ ] Test creating a free organization (if acceptable)
- [ ] Compare org-level vs repo-level runner behavior
- [ ] Document pros/cons of org approach for this use case

**Investigation areas:**
```bash
# GitHub Organization API
curl -H "Authorization: token $GITHUB_PAT" \
  https://api.github.com/orgs/{org}/actions/runners

# Organization runner registration token
curl -X POST -H "Authorization: token $GITHUB_PAT" \
  https://api.github.com/orgs/{org}/actions/runners/registration-token
```

**Questions to answer:**
- Does creating an org make sense for 2-3 personal repos?
- What are the ongoing maintenance implications?
- Can repos be easily moved back to personal account if needed?
- Are there any limitations with free GitHub organizations?
- How does billing/limits work for org-level runners vs repo-level?

### Phase 2: Solution Design (30 minutes)

#### Task 4: Evaluate Options
Based on research, evaluate each option:

**Option A: Shared Runner via Labels**
- Feasibility: ?
- Complexity: Low
- Security: Good (no admin:org scope)
- Limitations: ?

**Option B: Runner Groups (Org-level)**
- Feasibility: ? (requires organization)
- Complexity: High (create org, transfer repos)
- Security: Moderate (admin:org scope required)
- Limitations: Must create organization
- **INVESTIGATE:** Is this worth it for 2-3 repos? What are the real benefits?

**Option C: Multiple Runner Instances**
- Feasibility: Yes (but resource-intensive)
- Complexity: Medium
- Security: Good (isolation)
- Limitations: 2x-3x memory usage on NAS

#### Task 5: Choose Recommended Approach
- [ ] Select best option based on findings
- [ ] Document why this is the best choice
- [ ] List trade-offs and limitations
- [ ] Plan migration steps

### Phase 3: Documentation & Implementation (1-1.5 hours)

#### Task 6: Create Multi-Repo Setup Guide
- [ ] Create new documentation: `docs/09-MULTI-REPO-SETUP.md`

**Sections:**
- Overview (why you'd want multi-repo access)
- Personal Account vs Organization
- Recommended approach with step-by-step instructions
- Alternative approaches with pros/cons
- Troubleshooting multi-repo access
- Migration from single-repo to multi-repo

#### Task 7: Update Existing Documentation
- [ ] Update `docs/03-CONFIGURATION.md` with multi-repo info
- [ ] Update `docs/00-QUICK-START.md` if needed
- [ ] Update `README.md` features section
- [ ] Add FAQ entries for multi-repo questions

#### Task 8: Update Configuration Files
- [ ] Ensure `.env.example` has clear multi-repo examples
- [ ] Update `docker-compose.yml` comments if needed
- [ ] Add configuration example for multi-repo setup

#### Task 9: Create Migration Guide
- [ ] Document step-by-step migration from single to multi-repo
- [ ] Include rollback instructions
- [ ] Test migration steps
- [ ] Add to troubleshooting guide

### Phase 4: Testing & Validation (30 minutes)

#### Task 10: Test Multi-Repo Setup
- [ ] Set up runner for multi-repo access
- [ ] Create test workflows in both repos
- [ ] Trigger workflows and verify they run
- [ ] Test concurrent workflow queueing
- [ ] Verify concurrency controls work correctly

#### Task 11: Document Test Results
- [ ] Record what works
- [ ] Note any limitations discovered
- [ ] Document workarounds for issues
- [ ] Update troubleshooting guide

## Deliverables

### Documentation
- [ ] `docs/09-MULTI-REPO-SETUP.md` - Complete multi-repo guide
  - Personal account multi-repo setup
  - Organization-level setup (if investigated and viable)
  - Comparison table: Personal vs Organization approach
  - When to use each approach
- [ ] Updated `docs/03-CONFIGURATION.md` - Multi-repo configuration
- [ ] Updated `docs/05-TROUBLESHOOTING.md` - Multi-repo issues
- [ ] Updated `docs/FAQ.md` - Multi-repo questions
  - "Should I create a GitHub Organization?"
  - "Personal account vs Organization for runners?"

### Configuration
- [ ] Updated `.env.example` with multi-repo examples
- [ ] Configuration templates for different scenarios

### Knowledge Base
- [ ] Clear answer: Can personal account runners serve multiple repos?
- [ ] Documented: Best practices for multi-repo setups
- [ ] Tested: Migration path from single to multi-repo

## Success Criteria

- [ ] Clear documentation on how to set up multi-repo access
- [ ] Tested and verified working solution
- [ ] Migration steps documented and tested
- [ ] User can set up runner for both planechaser and synology-github-runner repos
- [ ] No need to create GitHub Organization (if possible)

## Open Questions

1. **Does GitHub allow a repository-level runner to serve multiple repos in a personal account?**
   - Answer: TBD (Task 1-2)

2. **What's the difference between "organization" and "personal account" for runner purposes?**
   - Answer: TBD (Task 1)

3. **Can we avoid creating a GitHub Organization?**
   - Answer: TBD (Task 4-5)

4. **What's the security impact of different approaches?**
   - Answer: TBD (Task 4)

5. **How do concurrent jobs from different repos interact?**
   - Answer: TBD (Task 10)

## Notes

- User has personal GitHub account (andrelin)
- Repositories: planechaser, synology-github-runner (possibly more)
- Resource-constrained environment (Synology NAS)
- Prefer simple solution over complex org setup
- Security is important (avoid admin:org scope if possible)

## Related Files

- `docs/03-CONFIGURATION.md` - Configuration guide
- `docs/00-QUICK-START.md` - Quick start
- `.env.example` - Configuration template
- `docker-compose.yml` - Runner configuration

## References

- GitHub Docs: Self-hosted runners
- GitHub API: Runners endpoints
- Personal experience from testing (to be documented)

---

**Next Steps After Plan Completion:**
1. Share findings with community
2. Update README with multi-repo badge/feature
3. Consider adding automated multi-repo testing to CI/CD
4. Create video walkthrough (future enhancement)
