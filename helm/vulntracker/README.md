# vulntracker (Helm chart)

Deploys the VulnTracker API to Kubernetes. This chart is the Helm equivalent
of the `terraform/` module it replaces on this branch — same namespace,
Deployment, Service, NetworkPolicy, and secrets-sourcing shape, just expressed
as a Helm chart instead of Terraform resources.

## Prerequisites

- A Kubernetes cluster and `kubectl`/`helm` (v3+) configured against it.
- [External Secrets Operator](https://external-secrets.io) installed in the
  cluster, with a `ClusterSecretStore` pointed at AWS Secrets Manager. The
  store's name must match `secretsManager.clusterSecretStoreName` in
  `values.yaml` (default: `aws-secrets-manager`). This chart only *consumes*
  an existing secret at `secretsManager.secretName` (default:
  `vulntracker/app-secrets`) — it does not create the secret or the operator.
- An `ingress-nginx` namespace (or whatever namespace label you set via
  `networkPolicy.ingressNamespaceLabel`) fronting the cluster, since the
  installed `NetworkPolicy` only allows inbound traffic from pods in that
  namespace. Without a matching ingress controller namespace, nothing outside
  the pod's own namespace can reach the Service.

## Install

```bash
helm install vulntracker ./helm/vulntracker --namespace vulntracker --create-namespace
```

The chart also manages the Namespace resource itself (`namespace.create: true`
in `values.yaml`), so `--create-namespace`/`--namespace` on the Helm command
line is only there to tell Helm where to put its own release metadata — the
actual Namespace object comes from `templates/namespace.yaml`, matching how
`terraform/namespace.tf` explicitly created it (rather than relying on
`kubectl create namespace` out of band).

## Configuration

See `values.yaml` for the full list. Key settings:

| Value | Purpose |
|---|---|
| `namespace.name` | Namespace the chart's resources are deployed into |
| `image.repository` / `image.tag` | Container image to run |
| `replicaCount` | Deployment replica count |
| `secretsManager.*` | AWS Secrets Manager secret name + ClusterSecretStore to sync from |
| `networkPolicy.*` | Ingress-namespace allowlist + notify-service egress port |
| `podSecurityContext` / `securityContext` | Non-root, no-privilege-escalation pod/container hardening |

## What this chart does not do

- Provision AWS Secrets Manager, the ExternalSecrets Operator, or the
  `ingress-nginx` controller — those are cluster-level prerequisites assumed
  to already exist, mirroring the `data` (read-only) vs `resource`
  (provisioning) distinction in the original `terraform/secrets.tf`.
- Expose the API outside the cluster. Only a ClusterIP Service is created;
  wiring up an Ingress/Gateway is left to the cluster operator.
