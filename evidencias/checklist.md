# Checklist de entrega — cuenta Azure nueva

## Infraestructura

- [x] `azd provision` completó en la suscripción nueva y región `centralus`.
- [x] AKS `aks-ovpeu5n5emvl4`, Kubernetes `1.36.3`; tres nodos en estado `Ready`.
- [x] Azure Managed Grafana y Azure Monitor managed Prometheus provisionados.
- [x] Namespace `wordpress` y namespace `prestashop` creados.

## Aplicaciones y almacenamiento

- [x] WordPress y su MariaDB desplegados en `wordpress`.
- [x] PrestaShop y su MariaDB desplegados en `prestashop`.
- [x] Cada aplicación y base tiene PVC independiente; los cuatro PVC están `Bound` (8 GiB cada uno).
- [x] Servicios MariaDB `ClusterIP`; servicios de portal `LoadBalancer` en HTTP 80/8080.
- [x] Página WordPress y producto PrestaShop accesibles por HTTP 200.
- [x] Credenciales generadas/guardadas en Secrets; no se publicaron valores en el repo ni evidencias.

## Persistencia y Grafana

- [x] Reinicios secuenciales de ambas MariaDB y ambos portales completados.
- [x] Página WordPress sigue visible tras reiniciar.
- [x] Producto PrestaShop sigue visible y con stock 5 tras reiniciar.
- [x] Dashboard `Kubernetes / Compute Resources / Namespace (Pods)` verificado en Azure Managed Grafana.
- [x] Capturas autenticadas del dashboard para `wordpress` y `prestashop`.
- [x] Consulta de Azure Monitor managed Prometheus devuelve los pods de ambos namespaces.

## Informe y apagado

- [x] Informe, costos estimados, arquitectura y decisión de apagado actualizados para la cuenta nueva.
- [x] PDF `Lucas Ardila & Sofia Oyola.pdf` regenerado con capturas actuales y anexos.
- [x] Entorno se conserva para revisión académica; `azd down` está documentado pero no ejecutado para no borrar evidencias/datos.
