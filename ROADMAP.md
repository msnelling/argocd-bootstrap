# Argo CD Bootstrap – Remediation Roadmap

This roadmap tracks the cleanup and refactor plan for the `argocd-bootstrap` repo to make first-time cluster bootstraps reliable, predictable, and easy to maintain.

Scope: Only this repository. Adjacent repos (db3000, teslamate, minecraft) are referenced where relevant.

## Goals
- Deterministic bootstrap order (no race conditions)
- Consistent Argo CD Application behavior across the stack
- Reduced boilerplate and easier onboarding (DRY)
- Better safety (principle of least privilege in AppProjects)
- CI guardrails to catch errors before merge

## Quick summary of issues to address
- Missing AppProject `bootstrap` (many apps reference it)
- Duplicate `syncPolicy` keys in a few Application manifests
- Inconsistent `project`, finalizers, and `syncOptions`
- Some namespaces not consistently created (CreateNamespace)
- Ordering dependencies not encoded (issuers after cert-manager, etc.)
- Unpinned internal revisions (`targetRevision: HEAD`) and mixed options
- Hardcoded env-specific values (e.g., Vault address) in templates

## Phase 1 – Correctness & Reliability (priority)
Target outcome: All Applications reconcile predictably from a clean cluster.

- [ ] Add AppProject for bootstrap
  - File: `01-bootstrap/templates/project.yaml`
  - Name: `bootstrap`; Namespace: `argocd`
  - `sourceRepos` minimal set required by 01-bootstrap:
    - `{{ .Values.spec.source.repoURL }}`
    - `https://charts.jetstack.io`
    - `https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts`
    - `https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts`
    - `https://charts.external-secrets.io`
    - `https://stakater.github.io/stakater-charts`
    - `https://helm.releases.hashicorp.com`
  - `destinations`: cluster wide or restricted if known
  - Keep cilium blacklist if relevant (mirroring other projects)

- [ ] Fix duplicate syncPolicy keys
  - Files: `01-bootstrap/templates/stakater-reloader.yaml`, `01-bootstrap/templates/vault.yaml`
  - Action: Merge to a single `spec.syncPolicy` block per Application

- [ ] Unify project usage in 01-bootstrap
  - Files: all under `01-bootstrap/templates/*.yaml`
  - Action: Set `spec.project: bootstrap` for all, including `traefik.yaml`

- [ ] Normalize namespace creation
  - Files: all namespace-scoped apps in 01-bootstrap
  - Action: Add `syncOptions: [CreateNamespace=true]` unless the app’s chart/path creates it explicitly
  - Verify `longhorn.yaml` path content or add CreateNamespace=true

- [ ] Parameterize environment-specific values
  - File: `01-bootstrap/templates/vault.yaml`
  - Action: Move `server.injector.externalVaultAddr` to `values.yaml` as `spec.values.vault.externalVaultAddr`
  - Update template to reference `{{ .Values.spec.values.vault.externalVaultAddr }}`

- [ ] Encode ordering with sync waves
  - Add `metadata.annotations["argocd.argoproj.io/sync-wave"]`:
    - `-2`: Argo CD itself (if managed here)
    - `-1`: CRDs/operators: `cert-manager`, `external-secrets`, `vault`, `secrets-store-csi-driver`, `csi-smb`
    - `0`: Issuers/configs: `cert-manager-issuers`, SecretStores (if applicable)
    - `1`: Ingress/network/system like `traefik`, `tailscale`, `network`
    - `2`: Platform storage like `longhorn` (if not earlier)
    - `3+`: User apps (via 02/03 stages)

- [ ] Standardize finalizer usage
  - Files: all Applications
  - Action: Add `resources-finalizer.argocd.argoproj.io` for consistent teardown

- [ ] Validate cert-manager resolver config
  - File: `01-bootstrap/templates/cert-manager.yaml`
  - Action: Confirm DoH-style `dns01RecursiveNameservers` is supported for your cert-manager version; otherwise use UDP resolvers (e.g., `1.1.1.1:53,1.0.0.1:53`)

Acceptance criteria
- Fresh cluster bootstraps to healthy with a single `argocd app sync` at the root app-of-apps level
- No Application fails due to missing AppProject or namespace
- Order-dependent resources converge without manual retries

## Phase 2 – Consistency & Developer Experience
Target outcome: Predictable behavior and defaults across all Applications.

- [ ] Standardize syncPolicy
  - `automated: { prune: true, selfHeal: true }` for long-lived apps
  - Use `ServerSideApply=true` for CRD-heavy charts (optionally all apps)
  - Use `ApplyOutOfSyncOnly=true` selectively (e.g., controllers) if desired

- [ ] Standardize syncOptions
  - Always include `CreateNamespace=true` for namespace-scoped apps unless explicitly managed elsewhere

- [ ] Pin internal targetRevision
  - Replace `HEAD` with `refs/heads/main` (or a tag) across internal paths

- [ ] Centralize and document shared values
  - Keep `spec.destination.server` and `spec.source.repoURL` in `values.yaml`
  - Add comments for how these flow down to nested charts (02/03)

Acceptance criteria
- New Applications follow a documented pattern with minimal copy-paste
- No unexplained differences in sync behavior between apps

## Phase 3 – DRY the Applications
Target outcome: Less boilerplate, easier to add/update apps.

Option A – Helm range loop
- [ ] Add a template that renders Applications from `.Values.apps` entries
- [ ] Support both `chart` and `path` sources, per-app options (waves, syncOptions, finalizers)
- [ ] Migrate repetitive Applications into the list gradually

Option B – ApplicationSet
- [ ] Introduce ApplicationSet for known groups (e.g., user apps in 03)
- [ ] Configure List or Git generator

Decision point
- [ ] Choose A or B and document rationale (simplicity vs. controller dependency)

Acceptance criteria
- Adding a new Application requires adding a values entry (or ApplicationSet item) only
- No functionality loss compared to current explicit manifests

## Phase 4 – Security & CI
Target outcome: Safer defaults and automated checks.

- [ ] Harden AppProjects
  - Trim `sourceRepos` to only what’s used
  - Restrict `destinations` and `clusterResourceWhitelist` where feasible

- [ ] Add CI workflow
  - `helm lint` for 01/02/03 charts
  - `helm template` + `kubeconform` (or `kubeval`) against a target K8s version
  - `yamllint` and duplicate key detection

- [ ] Add `ignoreDifferences` where noisy drift is normal (CRDs, webhook certs, etc.)

Acceptance criteria
- PRs are blocked on lint/template/validate success
- Projects remain usable with least privilege

## Phase 5 – Docs & Ops Quality
Target outcome: Clear guidance and smoother ops.

- [ ] Update repo `README.md`
  - App-of-apps overview, sync-wave diagram, and bootstrap steps
  - Pre-reqs, how to change branches/revisions safely, rollback hints

- [ ] Add per-component notes (optional)
  - e.g., PSS labels for `tailscale`, storage for `longhorn`, `renovate` allowEmpty rationale

## References
- Argo CD Sync Waves: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/
- Argo CD AppProjects: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/
- Cert-Manager Install/Config: https://cert-manager.io/docs/
- ApplicationSet: https://argocd-applicationset.readthedocs.io/

## Tracking
Use the checkboxes above to track progress. Prefer small PRs per bullet in Phase 1. After Phase 1 is done, reassess priorities for Phases 2–5.
