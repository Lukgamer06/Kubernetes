# Arquitectura — Laboratorio 6

```mermaid
flowchart TB
    Internet((Usuarios))
    subgraph Azure["Suscripción Azure"]
        subgraph AKS["Azure Kubernetes Service"]
            subgraph WP["Namespace: wordpress"]
                WPLB["Service wordpress<br/>LoadBalancer · HTTP :80"]
                WPApp["Deployment wordpress<br/>1 réplica"]
                WPMariaSvc["Service mariadb<br/>ClusterIP · :3306"]
                WPMaria["Deployment mariadb<br/>MariaDB 11.4 · 1 réplica"]
                WPPVC[("PVC wordpress-data<br/>8 GiB · managed-csi")]
                WPDBPVC[("PVC mariadb-data<br/>8 GiB · managed-csi")]
                WPSecret["Secret wordpress-credentials"]
                WPLB --> WPApp
                WPApp --> WPMariaSvc --> WPMaria
                WPApp --> WPPVC
                WPMaria --> WPDBPVC
                WPSecret -. credenciales .-> WPApp
                WPSecret -. credenciales .-> WPMaria
            end
            subgraph PS["Namespace: prestashop"]
                PSLB["Service prestashop<br/>LoadBalancer · HTTP :8080"]
                PSApp["Deployment prestashop<br/>1 réplica"]
                PSMariaSvc["Service mariadb<br/>ClusterIP · :3306"]
                PSMaria["Deployment mariadb<br/>MariaDB 11.4 · 1 réplica"]
                PSPVC[("PVC prestashop-data<br/>8 GiB · managed-csi")]
                PSDBPVC[("PVC mariadb-data<br/>8 GiB · managed-csi")]
                PSSecret["Secret prestashop-credentials"]
                PSLB --> PSApp
                PSApp --> PSMariaSvc --> PSMaria
                PSApp --> PSPVC
                PSMaria --> PSDBPVC
                PSSecret -. credenciales .-> PSApp
                PSSecret -. credenciales .-> PSMaria
            end
        end
        Prom["Azure Monitor managed Prometheus"]
        Grafana["Azure Managed Grafana<br/>fuera de AKS"]
        ACR["Azure Container Registry"]
        AKS -. métricas .-> Prom
        Prom --> Grafana
        ACR -. imagenes privadas opcionales .-> AKS
    end
    Internet -->|IP pública compartida · :80| WPLB
    Internet -->|IP pública compartida · :8080| PSLB
```

## Flujos y aislamiento

- Los usuarios acceden por HTTP a dos Services `LoadBalancer` que comparten la IP pública de WordPress en puertos diferentes: `:80` y `:8080`. La annotation `azure-pip-name` referencia el recurso existente de Azure, evitando crear otra IP pública; cada Service selecciona solo los pods de su namespace.
- Cada aplicación resuelve el host `mariadb` local a su propio namespace. Ambos namespaces pueden tener un Service llamado `mariadb` sin colisión: `wordpress/mariadb` y `prestashop/mariadb` son destinos distintos.
- Las dos DB son ClusterIP; no hay ruta entrante desde Internet. No se comparte PVC, usuario de DB, contraseña ni base entre los portales.
- Cada aplicación monta su PVC en `/var/www/html`; MariaDB monta su volumen independiente en `/var/lib/mysql`. `managed-csi` crea discos administrados de Azure mediante PVC `ReadWriteOnce`.
- Grafana es Azure Managed Grafana y está fuera de AKS. El workspace de Azure Monitor managed Prometheus recolecta métricas de AKS; Grafana consulta ese datasource administrado.
- ACR lo provisiona el template. Los workloads usan imágenes públicas versionadas de Docker Hub en este laboratorio, por lo que no requieren construir una imagen propia ni publicar secretos/imágenes.

## Disponibilidad y límites

Una réplica por portal y por base es apropiada para la práctica, pero no proporciona alta disponibilidad. MariaDB usa estrategia `Recreate` porque cada instancia monta un disco `ReadWriteOnce`; no escales sus réplicas sin migrar a StatefulSet y diseñar replicación/backup. La supervivencia a reinicios de pods está cubierta por PVC, no por backup ante borrado accidental o `azd down`.

Los Load Balancers exponen HTTP públicamente según la rúbrica. Para producción, delante de las apps se recomienda Ingress/Application Gateway con TLS, DNS, WAF y límites de origen; las bases deben seguir privadas. Las StorageClasses de AKS y las políticas de RBAC del clúster son dependencias de la suscripción y versión de AKS.
