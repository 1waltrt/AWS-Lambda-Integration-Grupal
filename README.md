## Uso del código (DEV, QA y PROD)

### 1. Requisitos
`git`, `gh`, `terraform >= 1.10`, `aws` CLI v2, `node 20` + `npm`, `make`, `curl`.

### 2. Clonar el repositorio
```bash
gh auth login
gh repo clone 1waltrt/AWS-Lambda-Integration-Grupal
cd AWS-Lambda-Integration-Grupal
git switch develop && git pull
```

### 3. Configurar acceso a AWS
Solo la primera vez:
```bash
aws configure sso --profile imgproc
```

### 4. Iniciar cada sesión de terminal
```bash
aws sso login --profile imgproc
export AWS_PROFILE=imgproc
export TF_STATE_BUCKET=<nombre-del-bucket-tfstate>
aws sts get-caller-identity
```

### 5. Configurar el correo de alarmas
Editar `alarm_email` (entre comillas) en cada entorno a desplegar:
```bash
nano envs/dev/dev.tfvars
nano envs/qa/qa.tfvars
nano envs/prod/prod.tfvars
```
```hcl
alarm_email = "correo@ejemplo.com"
```

### 6. Desplegar un entorno
Reemplazar `ENV` por `dev`, `qa` o `prod`:
```bash
make init  ENV=dev
make plan  ENV=dev
make apply ENV=dev
make test  ENV=dev
```

Para los otros entornos:
```bash
make init ENV=qa   && make apply ENV=qa   && make test ENV=qa
make init ENV=prod && make apply ENV=prod && make test ENV=prod
```

Confirmar la suscripción SNS desde el correo recibido.

### 7. Destruir los recursos (terraform destroy)
Al terminar las pruebas y capturas de evidencia:
```bash
make destroy ENV=dev
make destroy ENV=qa
make destroy ENV=prod
```
Debe aparecer `Destroy complete!` en cada entorno.
