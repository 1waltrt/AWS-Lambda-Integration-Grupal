# image-processor — AWS + Lambda (Terraform)

Pipeline: `POST /upload` → API Gateway → **upload-lambda** → S3 `uploads/` → SQS → **crop-lambda** → S3 `processed/` (PNG circular 40x40).
Se despliega en **dev**, **qa** y **prod** con los mismos módulos (`envs/<env>` solo cambia el `.tfvars`).

```
modules/  network · storage · compute · api · observability
envs/     dev · qa · prod        (main.tf idéntico, distinto backend key y .tfvars)
src/      upload-lambda · crop-lambda
scripts/  build-lambdas.sh · test-upload.sh · protect-branches.sh
bootstrap/ bucket del tfstate (una sola vez)
```

## Contrato entre módulos

| Módulo | Outputs |
|---|---|
| storage | `bucket_name, bucket_arn, queue_arn, queue_url, dlq_name, dlq_arn` |
| network (recibe `bucket_arn`) | `vpc_id, private_subnet_ids, sg_upload_id, sg_crop_id` |
| compute (recibe storage + network) | `upload_lambda_arn, upload_lambda_invoke_arn, upload_lambda_name` |
| api (recibe compute) | `api_endpoint_url` |
| observability (recibe `dlq_name`) | `sns_topic_arn` |

Orden de dependencias: **storage → network → compute → api → observability**.

## Diferencias por entorno

| Variable | DEV | QA | PROD |
|---|---|---|---|
| `nat_gateway_count` | 1 | 1 | 2 |
| `log_retention_days` | 7 | 14 | 14 |
| `lambda_reserved_concurrency` | -1 (sin límite) | -1 | -1 (opcional) |
| `alarm_email` | del equipo | del equipo | del equipo |
| CIDR VPC | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |

---

## Requisitos en la PC de cada integrante (Ubuntu)

`git`, `gh` (GitHub CLI), `terraform >= 1.10`, `aws` CLI v2, `node 20` + `npm`, `make`, `curl`.

Acceso a AWS con **IAM Identity Center** (sin access keys):
```bash
aws configure sso --profile imgproc      # una vez
aws sso login --profile imgproc          # cada sesión
export AWS_PROFILE=imgproc
aws sts get-caller-identity              # verificar
```
Cada quien necesita un permission set con permisos para crear VPC, S3, SQS, Lambda, IAM, API Gateway, CloudWatch y SNS (para el trabajo grupal sirve `AdministratorAccess` en una cuenta de práctica).

## Flujo de ramas (todos)

`main` = PROD (protegida) · `develop` = integración · trabajo en `feat/<modulo>` o `fix/<tema>` que salen de `develop`.

```bash
gh auth login
gh repo clone <owner>/image-processor && cd image-processor
git switch develop && git pull
git switch -c feat/<modulo>                 # ej. feat/network
# ...trabajar, probar...
terraform fmt -recursive
git add . && git commit -m "feat(<modulo>): <qué hiciste>"
git push -u origin feat/<modulo>
gh pr create --base develop --fill          # abre el PR
```
(Con gitflow: `git flow feature start <modulo>` + `git flow feature publish`, pero **no** `finish`: el merge se hace por PR.)

**Revisión cruzada:** otro compañero abre el PR en GitHub → *Files changed* → comenta líneas → *Review changes* → **Approve** (o *Request changes*). Cuando CI está en verde y hay 1 aprobación: **Squash and merge**. Nadie hace push directo a `develop` ni `main`.

Commits: `feat(network): add private subnets`, `fix(storage): filter notification by uploads/ prefix`, `docs: add deploy instructions`.

---

## Qué hace cada rol y en qué orden

### P1 — Base e integración (PRIMERO, hoy)
1. Subir este repo a GitHub (ver comandos abajo) e invitar a P2–P5 (*Settings → Collaborators*).
2. Crear `develop` y proteger ramas: `./scripts/protect-branches.sh <owner>/image-processor`.
3. Crear el bucket del tfstate (una sola vez):
   ```bash
   cd bootstrap && terraform init && terraform apply
   export TF_STATE_BUCKET=$(terraform output -raw tfstate_bucket)   # compartirlo con el equipo
   ```
4. Avisar al equipo: *"develop listo, ya pueden crear sus ramas"*.
5. Cuando los otros 4 PR estén mergeados: probar `make init apply ENV=dev`, luego QA y al final PROD (PR `develop → main`).
6. Completar el README final y revisar los PR de los demás.

```bash
git init -b main && git add . && git commit -m "chore: initial repo structure"
gh repo create <owner>/image-processor --private --source=. --push
git switch -c develop && git push -u origin develop
```

### P2 — Redes (`feat/network`)
Módulo `modules/network`: VPC con DNS, subnets públicas/privadas, IGW, NAT (`count = nat_gateway_count`), rutas, SGs (`sg-upload-lambda`, `sg-crop-lambda`, `sg-vpce-sqs`), S3 Gateway Endpoint con policy limitada al bucket e Interface Endpoint de SQS.
Revisar el código existente, ajustarlo/mejorarlo, `terraform validate` y abrir PR a `develop`.

### P3 — Datos y mensajería (`feat/storage`)
Módulo `modules/storage`: bucket (SSE, versioning, bloqueo público, lifecycle 30/90 días), cola + DLQ (visibility 360 s, retención 1 día, long polling 20 s, maxReceiveCount 3), queue policy y notificación filtrada por `uploads/`.

### P4 — Cómputo (`feat/compute`)
Módulo `modules/compute` + código en `src/upload-lambda` y `src/crop-lambda`: Lambdas, roles IAM de mínimo privilegio, event source mapping con `ReportBatchItemFailures`.
Probar localmente: `./scripts/build-lambdas.sh`.

### P5 — API, observabilidad y evidencias (`feat/api-observability`)
Módulos `modules/api` y `modules/observability` + `scripts/test-upload.sh`.
Al final (con el entorno desplegado): ejecutar `make test ENV=dev`, tomar capturas (API Gateway, Lambda, S3 `processed/`, alarma, SQS), guardarlas en `docs/evidencias/`, armar el PDF y documentar el `terraform destroy`.

> **Orden de merge a `develop`:** storage → network → compute → api/observability (cada PR rebasa/actualiza contra `develop` antes de mergear).

---

## Despliegue (P1, o quien despliegue)

```bash
export AWS_PROFILE=imgproc
export TF_STATE_BUCKET=<output de bootstrap>
# editar envs/<env>/<env>.tfvars → alarm_email real

make init  ENV=dev
make apply ENV=dev          # corre build-lambdas.sh y luego terraform apply
make test  ENV=dev          # sube imágenes de prueba y lista processed/
```
Repetir con `ENV=qa` y `ENV=prod`. Confirmar la suscripción SNS desde el correo.

**Destroy (evidencia):** `make destroy ENV=dev` (idem qa/prod). `force_destroy = true` permite borrar el bucket con objetos.

## CI (GitHub Actions)

Cada PR corre `fmt`, `validate` (dev/qa/prod) y, **opcionalmente**, `plan` si defines las variables del repo `AWS_ROLE_ARN` (rol OIDC de GitHub en AWS) y `TF_STATE_BUCKET`. Sin ellas, el job `plan` se omite y el plan lo corre cada quien localmente (`make plan ENV=dev`) y lo pega en el PR.

## Límites y decisiones a tener en cuenta

- **Tamaño máximo real ≈ 4.5 MB, no 10 MB.** API Gateway acepta 10 MB, pero la invocación síncrona de Lambda admite solo 6 MB de payload (y el body llega en base64, ~33 % más grande). Por eso `max_upload_bytes = 4500000`. Para 10 MB reales haría falta subir con URL prefirmada de S3 (cambio de arquitectura).
- **Costo:** los NAT Gateways y el Interface Endpoint cobran por hora; destruyan el entorno al terminar.
- **Estado remoto:** usa `use_lockfile` (Terraform ≥ 1.10), sin tabla DynamoDB.
- `sharp` se instala para `linux/x64`; las Lambdas usan arquitectura `x86_64`.
- Branch protection en repos privados requiere plan de pago de GitHub; si no lo tienen, hagan el repo público.
