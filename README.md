# Argo CD Bootstrap

Opinionated, app-of-apps GitOps bootstrap for a homelab Kubernetes cluster using Argo CD and Helm. This repo defines three stages: cluster bootstrap, system apps, and user apps.

## Repo layout

- `01-bootstrap/` Helm chart that creates Argo CD Applications for core platform components (Argo CD itself, cert-manager, external-secrets, storage, ingress, etc.).
- `02-system/` Helm chart that defines the Argo CD AppProject `system` and system-level Applications (e.g., Prometheus).
- `03-applications/` Helm chart that defines the Argo CD AppProject `applications` and user-level Applications (e.g., gitea, minecraft, teslamate, db3000, whoami).
- Component directories at the repo root (e.g., `argocd/`, `traefik/`, `longhorn/`, `network/`, etc.) contain the manifests/Helm for those Applications.
- `ROADMAP.md` documents the remediation and refactor plan.

## Prerequisites

- A Kubernetes cluster with access via `kubectl`.
- Argo CD CRDs installed (usually by installing Argo CD). The bootstrap will then manage Argo CD itself via the `argocd` Application.
- Cluster DNS and outbound egress for charts and images.

## Quick start (bootstrap)

1) Install Argo CD (minimal) so the Application CRD exists. You can uninstall or let this repo take over management afterward.

2) Create a root Application that points at `01-bootstrap` in this repo.

Example root Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
	name: cluster-bootstrap
	namespace: argocd
spec:
	project: default
	destination:
		server: https://kubernetes.default.svc
	source:
		repoURL: https://github.com/msnelling/argocd-bootstrap.git
		targetRevision: main
		path: 01-bootstrap
		helm:
			valueFiles: []
	syncPolicy:
		automated:
			prune: true
			selfHeal: true
		syncOptions:
			- CreateNamespace=true
```

Apply it and watch sync in the Argo CD UI/CLI.

## Configuration

- `01-bootstrap/values.yaml` controls shared repo and destination settings:
	- `spec.destination.server`: target cluster server (defaults to in-cluster API).
	- `spec.source.repoURL`: this repo URL.
	- `spec.source.targetRevision`: branch/revision to track (recommend `main`).
- Per-Application settings live in each template or component directory. Prefer values over hardcoding environment-specific URLs (see ROADMAP).

## Operations tips

- First sync order matters (CRDs/operators before dependents). If you see race conditions, add Argo CD sync waves via `metadata.annotations["argocd.argoproj.io/sync-wave"]`. See ROADMAP for planned standardization.
- Namespace creation: Most apps set `syncOptions: CreateNamespace=true`. Ensure this is present or create namespaces out-of-band.
- Finalizers: Use `resources-finalizer.argocd.argoproj.io` for consistent cleanup on Application deletion.

## Troubleshooting

- AppProject not found: Some Applications use the project `bootstrap`. If you hit `project 'bootstrap' not found`, create it first. Minimal example:

	```yaml
	apiVersion: argoproj.io/v1alpha1
	kind: AppProject
	metadata:
		name: bootstrap
		namespace: argocd
	spec:
		sourceRepos:
			- https://github.com/msnelling/argocd-bootstrap.git
			- https://charts.jetstack.io
			- https://charts.external-secrets.io
		destinations:
			- namespace: '*'
				server: https://kubernetes.default.svc
		clusterResourceWhitelist:
			- group: '*'
				kind: '*'
	```

- Cert-manager DNS resolvers: If ACME fails, verify the resolver settings in `01-bootstrap/templates/cert-manager.yaml` are valid for your version. You may need standard UDP resolvers like `1.1.1.1:53,1.0.0.1:53`.

## Roadmap

See `ROADMAP.md` for the phased remediation plan (correctness, consistency, DRY with Helm/ApplicationSet, security, and CI).

## License

Personal homelab; no license specified.
