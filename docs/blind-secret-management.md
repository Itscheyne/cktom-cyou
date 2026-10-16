# Blind Secret Management for Agents and IaC

## 1. Overview

This document specifies an architecture in which autonomous agents can
**provision and reference secrets they never see in plaintext**. Agents
request secret *creation*; a trusted backend generates the value, stores
it in a secret store, and returns only an opaque **reference** (an ARN, a
Vault path, an Azure Key Vault secret URI, or — for this repo's native
stack — a SOPS-encrypted key handle). IaC and running workloads resolve
the reference to the live value at deploy/run time. The plaintext exists
only inside the secret store and the final consumer.

The threat model is deliberately narrow and blunt: **treat the agent as
hostile-by-default toward secret material.** Every design choice assumes
the agent's context window, logs, commit history, PR comments, and tool
return payloads are all readable by an attacker. If the plaintext never
enters any of those surfaces, a compromised or careless agent cannot leak
what it never held.

This design fits the existing `cktom-cyou` stack (OpenTofu, S3 state
backend, SOPS+age, GitHub PR review gate documented in
`docs/agent-iac-workflow.md`) and generalizes to AWS Secrets Manager,
HashiCorp Vault, and Azure Key Vault.

## 2. Threat Model

| # | Threat | Control |
|---|--------|---------|
| T1 | Agent logs / echoes the secret | Backend never returns plaintext; only a reference. Nothing to echo. |
| T2 | Secret lands in git (`.tf`, `.tfvars`, PR diff) | Agent only ever writes the *reference*. References are non-sensitive by design. |
| T3 | Secret leaks into `tofu plan`/`apply` console output | Consumer marks the resolved value `sensitive = true`; data-source lookups are ephemeral. |
| T4 | Secret leaks into Terraform/OpenTofu **state** | State backend (S3) is the highest-risk surface. See §7 — resolve at runtime via workload identity, not at plan time, wherever possible. |
| T5 | Agent requests a secret it has no business creating | Broker enforces per-agent authz on `name` prefix + `environment` (§5). |
| T6 | Agent tricks broker into *reading* an existing secret | Broker exposes **no read/get-value verb** to agents. Write-and-reference only. |
| T7 | Replay / duplicate creation | Idempotency key + name collision policy (§4.3). |
| T8 | Backend credentials leak through the agent | Agent holds a token for the **broker only** — never for the secret store. Broker holds the store credentials, in a separate trust zone. |

**Trust-zone boundary (the core idea):**

```
  UNTRUSTED                    | TRUSTED
  ---------------------------- | ----------------------------------
  Agent  --create(name,spec)-->| Secret Broker --generate+store--> Secret Store
         <--reference (ARN)-----|   (holds store creds)             (AWS SM / Vault /
                               |                                     Azure KV / SOPS)
  ---------------------------- | ----------------------------------
        agent-scoped token           store credentials never
        (broker audience only)       cross this line toward the agent
```

The agent authenticates to the **broker**, not to the secret store. The
broker is the only component holding store write-credentials. Plaintext
never crosses the boundary back toward the agent.

## 3. Components

1. **Agent tool** (`secret.create`) — thin client the agent invokes.
   Sends a *request to generate*, receives a reference. Implemented in
   task `t_6dab0bd7`.
2. **Secret Broker** — trusted service (or CI-side privileged step) that
   owns secret-store credentials, generates entropy, writes to the store,
   emits audit records, and returns the reference. The security boundary.
3. **Secret Store** — pluggable backend: AWS Secrets Manager, HashiCorp
   Vault (KV v2), Azure Key Vault, or repo-native SOPS+age.
4. **IaC consumer module** — OpenTofu module that takes a reference as an
   input variable and resolves it at deploy time. Implemented in task
   `t_ab3515d6`.
5. **Audit log** — append-only record of every create request. Never
   contains the plaintext (T1).

## 4. API Contract — `secret.create`

The agent tool is **write-and-reference only**. There is deliberately no
`get`, `read`, or `reveal` verb exposed to agents (T6).

### 4.1 Request

```json
{
  "action": "secret.create",
  "name": "rds/prod/app-db-password",
  "environment": "prod",
  "type": "password",
  "spec": {
    "length": 32,
    "charset": "alnum-symbol",
    "exclude_ambiguous": true
  },
  "rotation": { "enabled": true, "interval_days": 90 },
  "metadata": { "owner_task": "t_6dab0bd7", "purpose": "app db credential" },
  "idempotency_key": "t_6dab0bd7:rds-app-db:v1"
}
```

Field rules:

- `name` — logical path, **not** the value. Namespaced; the broker
  prefixes/validates it against the agent's allowed scope (§5).
- `type` — one of `password`, `api_key`, `rsa_keypair`, `ed25519_keypair`,
  `token`, `random_bytes`. Determines the generator, not the value.
- `spec` — generation parameters only. The agent describes *shape*, never
  content. Rejected if it contains any field that could smuggle a value
  (e.g. a literal `value`).
- `rotation` — optional; wires up store-native rotation where supported.
- `idempotency_key` — required. Makes retries safe (T7).

### 4.2 Response (success)

```json
{
  "status": "created",
  "reference": {
    "backend": "aws_secrets_manager",
    "uri": "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds/prod/app-db-password-AbCdEf",
    "name": "rds/prod/app-db-password",
    "version_id": "9f2c...",
    "created_at": "2026-09-11T12:00:00Z"
  },
  "fingerprint": "sha256:3a7bd3e2...   (HMAC of value under a broker key; NOT the value)"
}
```

- `reference.uri` is backend-shaped: an ARN (AWS), `secret/data/...`
  (Vault KV v2), an Azure KV `https://<vault>.vault.azure.net/secrets/...`
  URI, or a SOPS key handle (`sops://k8s/app.secrets.yaml#db_password`).
- `fingerprint` is an **HMAC** of the value under a broker-held key — it
  lets the agent verify "same secret across two references" or "rotation
  changed it" **without** the value, and is not reversible to plaintext.
- **The response schema has no field that can hold the plaintext.** This
  is enforced by the broker's output serializer, not by convention (T1).

### 4.3 Response (idempotent hit / collision)

```json
{ "status": "exists", "reference": { "...": "existing reference" } }
```

Same `idempotency_key` → returns the prior reference (no new value).
Same `name`, different key → `409 name_conflict` unless the request sets
`on_conflict: "new_version"`, in which case a new *version* is minted and
its reference returned.

### 4.4 Errors

| Code | Meaning |
|------|---------|
| `403 forbidden_scope` | `name`/`environment` outside the agent's grant (T5) |
| `400 invalid_spec` | spec malformed or contains a value-bearing field |
| `409 name_conflict` | name exists, no `on_conflict` directive |
| `502 store_unavailable` | backend write failed; nothing persisted, safe to retry |

Errors **never** echo request/response secret material. A `502` guarantees
the store write was atomic — either a value exists and a reference is
returned, or nothing was written (T7).

### 4.5 Invariants (must hold for every implementation)

1. No agent-facing verb returns plaintext or accepts a caller-supplied value.
2. Entropy is generated **inside the broker** using a CSPRNG
   (`secrets`/`os.urandom`, AWS `get-random-password`, or Vault transit).
3. Plaintext is zeroized after the store write; never logged, never
   returned, never held longer than the write call.
4. Every request produces one audit record keyed by `name` + `version_id`
   + `owner_task`, containing no secret material.

## 5. Authorization

The broker authorizes each request; the agent's identity is bound to a
grant:

- **Scope by name prefix + environment.** e.g. task `t_6dab0bd7`'s agent
  token may create `rds/*` and `app/*` in `prod`/`staging`, nothing else.
- **Least privilege at the store.** The broker's own store credential is
  `PutSecretValue`/`CreateSecret` scoped by resource tag or path prefix —
  crucially **not** `GetSecretValue`. The broker cannot read back the
  values it writes; it doesn't need to, and this shrinks blast radius (T6).
- **Human review gate reused.** Because the agent only ever commits
  *references*, the existing PR review gate
  (`docs/agent-iac-workflow.md` §7) is sufficient — a reviewer approving a
  `tofu plan` sees `arn:...` / `sops://...`, never a value.

## 6. Per-backend mapping

| Concern | AWS Secrets Manager | HashiCorp Vault (KV v2) | Azure Key Vault | Repo-native SOPS+age |
|---|---|---|---|---|
| Generate | `get-random-password` or broker CSPRNG | `sys/tools/random` / transit | broker CSPRNG | broker CSPRNG |
| Store | `CreateSecret` / `PutSecretValue` | `kv/data/<path>` write | `SetSecret` | write value into `*.secrets.yaml`, `sops -e -i` under existing age recipient |
| Reference returned | ARN + `VersionId` | `secret/data/<path>` + version | secret URI + version | `sops://<file>#<key>` handle |
| IaC resolves via | `aws_secretsmanager_secret_version` data source | `vault_kv_secret_v2` data source | `azurerm_key_vault_secret` data source | `data.external`/`sops_file` decrypt at plan, or CI-side decrypt |
| Runtime resolution (preferred) | ECS/Lambda secret injection by ARN | Vault Agent / CSI | Key Vault CSI / managed identity | K8s SOPS operator / sealed at deploy |

SOPS is the **native fit** for this repo (`.sops.yaml` already defines the
age recipient `age1hn93q...`). The broker's SOPS driver appends the
generated value to the matching `*.secrets.yaml` and encrypts in place;
the age private key lives with the broker/CI, never with the agent.

## 7. IaC integration pattern (the state-leak problem)

**The Terraform/OpenTofu state file is the primary leak surface (T4).**
This repo uses an S3 backend (`providers.tf`). Any secret value that flows
through a resource attribute or a data source is written to state in
plaintext. Two patterns, in order of preference:

### 7.1 Preferred — never resolve in IaC; inject at runtime

IaC passes the **reference** to the workload and lets the platform resolve
it out-of-band. The value never enters `tofu plan`, `apply`, or state.

```hcl
variable "db_password_ref" {
  description = "Secret reference (ARN / Vault path / KV URI). NOT the value."
  type        = string
}

resource "aws_ecs_task_definition" "app" {
  # ...
  container_definitions = jsonencode([{
    name = "app"
    # ECS resolves the ARN at container start via task-execution-role.
    # The plaintext never touches Terraform state.
    secrets = [{ name = "DB_PASSWORD", valueFrom = var.db_password_ref }]
  }])
}
```

Analogues: Lambda + Secrets Manager extension, Vault Agent sidecar, Azure
Key Vault CSI driver, K8s SOPS/sealed-secrets operator.

### 7.2 Fallback — resolve in IaC, contain the blast radius

When a resource genuinely needs the value at apply time (e.g. setting an
RDS master password), accept that it lands in state and harden the state:

```hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = var.db_password_ref
}

resource "aws_db_instance" "app" {
  # ...
  manage_master_user_password = true   # AWS-native: value never leaves AWS
  # OR, if you must set it explicitly:
  # password = data.aws_secretsmanager_secret_version.db.secret_string
}

output "db_password" {
  value     = data.aws_secretsmanager_secret_version.db.secret_string
  sensitive = true   # mandatory: keeps it out of console output (T3)
}
```

Required hardening when 7.2 is unavoidable:
- S3 state backend: SSE-KMS encryption, bucket policy denying public/read,
  versioning + access logging.
- `manage_master_user_password` (AWS) / equivalent so the DB engine owns
  rotation and the value never round-trips through IaC at all.
- `sensitive = true` on every variable, output, and local touching the value.
- Never `terraform output` the value in CI logs.

**Rule for the IaC module task (`t_ab3515d6`): default to 7.1. Only use
7.2 for resources with no runtime-injection path, and always with the
hardening above.**

## 8. End-to-end flow

```
1. Agent (task t_6dab0bd7) calls secret.create{name:"rds/prod/app-db-password", type:"password"}
2. Broker authorizes name+env against agent grant
3. Broker generates 32-byte CSPRNG value
4. Broker writes value to store (CreateSecret / vault write / sops -e)
5. Broker records audit entry (no plaintext) and zeroizes the value
6. Broker returns { reference.uri: "arn:...", fingerprint: "sha256:..." }
7. Agent writes var value = "arn:..." into tfvars / module input (a reference)
8. Agent opens PR -> CI tofu plan shows the ARN, never the value
9. Human approves PR (existing review gate)
10. tofu apply: consumer resolves ARN at runtime (7.1) or reads sensitive (7.2)
```

At no step does the agent hold, log, commit, or return the plaintext.

## 9. Handoff to child tasks

- **`t_6dab0bd7` (coding — build the tool):** implement `secret.create`
  per §4. Enforce §4.5 invariants in code (output serializer with no
  value field; CSPRNG; zeroize; audit). Start with the AWS Secrets Manager
  and SOPS drivers (SOPS is the repo-native path). Return payload must be
  the §4.2 schema exactly.
- **`t_ab3515d6` (ops-infrastructure — IaC modules):** build a module that
  takes `*_ref` string inputs per §7. Ship a 7.1 example (ECS/CSI runtime
  injection) as the default and a hardened 7.2 example (RDS
  `manage_master_user_password`) as the fallback. Nothing in the module
  may produce a non-`sensitive` output carrying a value.
- **Cross-cutting decision (owned here, not by children):** the agent-facing
  API has **no read verb**; the reference format is backend-shaped as in
  §4.2; SOPS is the default backend for this repo. Both children inherit
  these decisions — do not re-litigate them.
