## ¿Qué cambia?
<!-- Módulo / funcionalidad. Un PR por módulo, máx. ~400 líneas -->

## Rol y módulo
- [ ] P2 network · [ ] P3 storage · [ ] P4 compute · [ ] P5 api/observability · [ ] P1 base/envs

## Checklist
- [ ] `terraform fmt -recursive` sin cambios
- [ ] `terraform validate` OK
- [ ] Respeta el contrato de outputs/variables (README, sección 4)
- [ ] Nombres con `${project}-${env}-...` y sin valores hardcodeados por entorno
- [ ] Commit en formato Conventional Commits (`feat(network): ...`)

## Cómo se probó
<!-- plan / apply en dev, capturas, salida de comandos -->
