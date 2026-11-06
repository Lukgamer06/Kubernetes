# Laboratorio 6 — Multiplataforma en AKS

Despliegue reproducible de WordPress y PrestaShop en un clúster AKS, con una instancia MariaDB, credenciales y almacenamiento independientes para cada portal. El template [`sabbour/aks-app-template`](https://github.com/sabbour/aks-app-template) aprovisiona AKS, Azure Container Registry, Azure Managed Grafana, Azure Monitor managed Prometheus, Log Analytics y las identidades/roles requeridos por esos servicios.

## Objetivos y arquitectura

- AKS es aprovisionado mediante Azure Developer CLI (`azd`) y Bicep del template.
- `wordpress` y `prestashop` son namespaces separados para organizar y acotar recursos; el namespace por sí solo no es una política de red.
- Cada portal tiene un Deployment, un Service `LoadBalancer`, un Secret y dos PVC: uno para los archivos de la aplicación y otro para MariaDB.
- Cada base de datos es un Deployment de una réplica y un Service `ClusterIP`; no tiene IP pública.
- Grafana es Azure Managed Grafana, fuera del clúster, y consulta las métricas administradas del clúster mediante Azure Monitor.
- Los Deployments tienen recursos y sondas de salud explícitos. Las imágenes usan tags de versión y la persistencia usa `managed-csi`.

Consulta [architecture.md](./architecture.md) para el diagrama, límites de red y explicación de los volúmenes.
El informe resumido para la entrega y las capturas a recopilar están en [evidencias/informe-laboratorio-6.md](./evidencias/informe-laboratorio-6.md) y [evidencias/](./evidencias/).

## Estado del despliegue en Azure

El despliegue actual se aprovisionó desde cero en una suscripción nueva el **5 de noviembre de 2026**:

| Recurso / portal | Resultado |
|---|---|
| Resource group | `rg-lab6-lucas-sofia-20261105` |
| Entorno `azd` | `lab6-lucas-sofia-20261105` |
| AKS | `aks-ovpeu5n5emvl4`, `centralus`, Kubernetes `1.36.3`, tres nodos `Standard_B2ps_v2` |
| Namespaces | `wordpress` y `prestashop` |
| MariaDB y PVC | Dos MariaDB `Running`; cuatro PVC `Bound` de 8 GiB |
| WordPress | [http://172.168.157.10/](http://172.168.157.10/) |
| PrestaShop | [http://172.168.157.10:8080/](http://172.168.157.10:8080/) |
| Azure Managed Grafana | [Abrir workspace](https://gpd-ovpeu5n5emvl4-dzaxc4bea5gqg3fs.cus.grafana.azure.com) |

Los Services de las aplicaciones son `LoadBalancer` y comparten la IP `172.168.157.10` en los puertos 80 y 8080. El Service de PrestaShop referencia el recurso de IP de WordPress mediante la annotation `azure-pip-name`; las dos bases siguen como `ClusterIP`. La página `Lab 6 - Persistencia WordPress` y el producto `Producto Lab 6 Persistente` (EUR 19,99; stock 5) devolvieron HTTP 200 después de reiniciar secuencialmente las dos MariaDB y ambos portales. Los cuatro PVC permanecieron `Bound`.

El template provisionó Azure Managed Grafana y Azure Monitor managed Prometheus. Está asignado el rol `Grafana Viewer` a la identidad activa. El dashboard **Kubernetes / Compute Resources / Namespace (Pods)** muestra uso de CPU y memoria, cuotas y métricas de red para `wordpress` y `prestashop`. Las capturas actuales y la salida de verificación están en [evidencias/nueva-cuenta-20261105/](./evidencias/nueva-cuenta-20261105/). El PDF para entrega está en [evidencias/Lucas Ardila & Sofia Oyola.pdf](./evidencias/Lucas%20Ardila%20%26%20Sofia%20Oyola.pdf).

Las evidencias sueltas en la raíz de `evidencias/` pertenecen al intento anterior y no se deben confundir con esta cuenta. Se conservan como histórico; el informe y el PDF actuales describen el despliegue nuevo.

## Supuestos

1. La suscripción Azure for Students usada para esta ejecución limita las regiones y las SKU; se utiliza `centralus` (permitida) y `Standard_B2ps_v2` (cuota asignada a la familia Bpsv2). Confirma políticas regionales y cuota de la suscripción antes de reutilizar el proyecto.
2. El clúster aprovisionado para esta ejecución usa Kubernetes `1.36.3`. Comprueba las versiones disponibles antes de provisionar con `az aks get-versions --location centralus -o table` y ajusta `infra/main.parameters.json` si Azure la retiró.
3. AKS usa un pool de sistema con `Standard_B2ps_v2`, disco de sistema administrado y autoscaling de 1 a 3 nodos. Tres nodos pueden ser necesarios para mantener los cuatro workloads junto al stack de monitoreo; la cuenta permite seis vCPU de esta familia en total. No es una topología de alta disponibilidad para producción.
4. Las contraseñas de DB y la contraseña de administración inicial de PrestaShop se generan aleatoriamente en `scripts/deploy.sh`; el script las conserva en Secrets de Kubernetes durante re-ejecuciones. `secret.yaml` contiene marcadores de plantilla y no se debe aplicar directamente.
5. Se usa HTTP para la práctica. Los Load Balancers son públicos; agrega TLS, DNS y restricción de IP de origen antes de cualquier uso real.
6. Cuatro PVC independientes de 8 GiB (32 GiB solicitados en total) usan la StorageClass `managed-csi` de AKS.

## Requisitos

- Suscripción Azure con permisos para crear AKS, redes, Managed Grafana, Log Analytics, Azure Monitor workspace, identidades y asignaciones de roles.
- Azure CLI (`az`), Azure Developer CLI (`azd`), `kubectl`, `envsubst` (paquete `gettext-base` en Debian/Ubuntu), `openssl` y `base64`.
- Permiso para asignar roles RBAC en la suscripción o grupo de recursos. La implementación del template requiere asignaciones de roles para las identidades administradas.
- Conectividad a Docker Hub para descargar `wordpress`, `prestashop/prestashop` y `mariadb`.

En Ubuntu/Debian instala las herramientas auxiliares que suelen faltar:

```bash
sudo apt-get update
sudo apt-get install -y gettext-base openssl
```

## Fase 1: template y aprovisionamiento de Azure

Para iniciar un proyecto nuevo con el template upstream, desde un directorio vacío:

```bash
azd init -t https://github.com/sabbour/aks-app-template
```

Este repositorio ya contiene el template inicializado y sus archivos Bicep. No vuelvas a ejecutar `azd init` encima de este directorio. Inicia sesión, crea un entorno `azd` y aprovisiona:

```bash
az login
azd auth login
az account set --subscription "<ID-o-nombre-de-suscripcion>"

azd env new lab6-lucas-sofia
azd env set AZURE_LOCATION centralus
azd env set AZURE_SUBSCRIPTION_ID "$(az account show --query id --output tsv)"
azd provision
```

Al ejecutar `azd provision`, el hook `preprovision` del template registra las características de Azure necesarias. Anota el entorno, la suscripción, región, versión AKS y el nombre del resource group. El template crea el resource group con prefijo `rg-` y recursos etiquetados con `azd-env-name`.

Validación del clúster y sus nodos:

```bash
azd env get-value AZURE_AKS_CLUSTER_NAME
azd env get-value AZURE_RESOURCE_GROUP
az aks get-versions --location centralus --output table

az aks get-credentials \
  --resource-group "$(azd env get-value AZURE_RESOURCE_GROUP)" \
  --name "$(azd env get-value AZURE_AKS_CLUSTER_NAME)" \
  --overwrite-existing
kubectl get nodes -o wide
kubectl wait --for=condition=Ready nodes --all --timeout=10m
```

La infraestructura contiene AKS, ACR, Azure Managed Grafana, Azure Monitor managed Prometheus, Log Analytics, configuraciones/reglas de monitoreo e identidades administradas con permisos de integración. El pool de laboratorio se redujo frente a los valores upstream del template para evitar los cuatro nodos `DS4_v2` predeterminados; `Standard_B2ps_v2` usa la familia Bpsv2 con cuota disponible en esta suscripción. El máximo se ajusta a tres nodos porque AKS y Prometheus/monitoring requieren recursos considerables además de las aplicaciones.

Para reducir privilegios y recursos que el laboratorio no necesita, se excluyeron del template los módulos opcionales de KEDA/Azure Service Operator y la asignación `Contributor` a nivel de suscripción. Solo quedan los permisos de integración necesarios para ACR y Azure Monitor/Grafana. KEDA y ASO no son parte de esta práctica.

## Fases 2–4: despliegue de namespaces, bases y portales

Los manifiestos completos están en [kubernetes/](./kubernetes/). Despliega el laboratorio desde la raíz del repositorio:

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

El script:

1. Obtiene la configuración de AKS desde el entorno `azd` y espera nodos `Ready`.
2. Crea los namespaces, Secrets y cuatro PVC.
3. Despliega las dos MariaDB y espera que estén disponibles.
4. Crea el Service `LoadBalancer` de WordPress, descubre el recurso de IP pública creado por AKS y lo comparte con el Service `LoadBalancer` de PrestaShop en el puerto 8080. Esto evita exceder el límite de tres IP públicas regionales de esta suscripción; el script inyecta el nombre real del recurso y su resource group al aplicar el manifiesto.
5. Despliega ambos portales y espera sus rollouts.

El script requiere `azd provision` exitoso. Los Secrets se crean desde las plantillas por `envsubst`; los valores no se escriben en archivos locales. No ejecutes `kubectl apply -f kubernetes/*/secret.yaml` directamente. El Service de PrestaShop también se renderiza durante el despliegue para inyectar el nombre del recurso Azure de IP pública que comparte con WordPress; no apliques ese manifiesto de plantilla directamente.

Las credenciales de DB y de las cuentas administrativas iniciales persisten en sus Secrets de Kubernetes durante reinicios y re-ejecuciones del script. Para recuperar deliberadamente las credenciales:

```bash
kubectl get secret wordpress-credentials -n wordpress \
  -o 'go-template={{index .data "wordpress-admin-password"}}' | base64 --decode
printf '\n'
kubectl get secret wordpress-credentials -n wordpress \
  -o 'go-template={{index .data "wordpress-admin-email"}}' | base64 --decode
printf '\n'
kubectl get secret prestashop-credentials -n prestashop \
  -o 'go-template={{index .data "prestashop-admin-password"}}' | base64 --decode
printf '\n'
kubectl get secret prestashop-credentials -n prestashop \
  -o 'go-template={{index .data "prestashop-admin-email"}}' | base64 --decode
printf '\n'
```

Los emails iniciales predeterminados son `admin@example.invalid`. Para usar otro email antes del primer despliegue:

```bash
export WORDPRESS_ADMIN_EMAIL="tu-correo@example.com"
export PRESTASHOP_ADMIN_EMAIL="tu-correo@example.com"
./scripts/deploy.sh
```

La contraseña inicial la genera el script; no uses una contraseña real reutilizada en otros servicios.
No borres ni reemplaces un Secret mientras conserves el PVC de su MariaDB: las variables de inicialización solo establecen las contraseñas cuando la base se crea por primera vez. Para reiniciar desde cero, elimina el namespace correspondiente (lo cual borra sus PVC y datos) y vuelve a desplegar.

## Fase 5: validaciones

```bash
./scripts/verify.sh
```

Comandos de inspección solicitados en la rúbrica:

```bash
kubectl get pods -A
kubectl get svc -A
kubectl get pvc -A
kubectl get deployments -A

kubectl describe pvc -n wordpress
kubectl describe pvc -n prestashop

kubectl logs deployment/mariadb -n wordpress --tail=100
kubectl logs deployment/wordpress -n wordpress --tail=100
kubectl logs deployment/mariadb -n prestashop --tail=100
kubectl logs deployment/prestashop -n prestashop --tail=100
```

Confirma que:

- Los cuatro PVC están `Bound`.
- Los Deployments `wordpress/wordpress`, `wordpress/mariadb`, `prestashop/prestashop` y `prestashop/mariadb` están disponibles.
- `wordpress/mariadb` y `prestashop/mariadb` son `ClusterIP`; `wordpress/wordpress` y `prestashop/prestashop` son `LoadBalancer`.
- Ambos Services de portal son `LoadBalancer` y comparten una IP pública con puertos distintos (WordPress HTTP 80 y PrestaShop HTTP 8080):

```bash
kubectl get services -n wordpress
kubectl get services -n prestashop
```

Abre la URL de WordPress en el puerto 80 y la de PrestaShop en el puerto 8080. Para esta ejecución ambas usan la misma dirección: `http://<IP-WORDPRESS>/` y `http://<IP-WORDPRESS>:8080/`. Termina el asistente inicial de WordPress usando el usuario `wpadmin` y la contraseña/email del Secret `wordpress-credentials`. PrestaShop usa la instalación automática de su imagen y puede tardar varios minutos en arrancar por primera vez; el path del back-office puede variar. No marques la instalación lista hasta que la página frontal y el panel de administración carguen.

## Fase 6: prueba de persistencia

1. En WordPress, inicia sesión, crea y publica una página identificable (por ejemplo, `Lab 6 - Persistencia WordPress`) y confirma que aparece en el sitio.
2. En PrestaShop, entra al back-office, crea y guarda un producto identificable (por ejemplo, `Producto Lab 6 Persistente`) y confirma que aparece en el catálogo.
3. Guarda la URL pública, captura las dos páginas antes del reinicio y anota la hora.
4. Reinicia las aplicaciones y las bases de datos (se reinicia el pod de cada Deployment, no se borra el volumen):

```bash
kubectl rollout restart deployment/wordpress -n wordpress
kubectl rollout restart deployment/mariadb -n wordpress
kubectl rollout status deployment/wordpress -n wordpress --timeout=20m
kubectl rollout status deployment/mariadb -n wordpress --timeout=10m

kubectl rollout restart deployment/prestashop -n prestashop
kubectl rollout restart deployment/mariadb -n prestashop
kubectl rollout status deployment/prestashop -n prestashop --timeout=20m
kubectl rollout status deployment/mariadb -n prestashop --timeout=10m
```

5. Abre otra vez ambos sitios y verifica que la página y el producto siguen guardados. Comprueba que los PVC continúan `Bound` y captura pods nuevos, contenido persistente y tiempos.

Los datos se guardan tanto en la base de datos como en el PVC de archivos de cada portal. La supervivencia a un reinicio del pod no sustituye copias de seguridad. Una réplica única de DB y el `Recreate` son intencionales para que un único PVC `ReadWriteOnce` se adjunte de forma segura.

## Fase 7: Azure Managed Grafana

Obtén la URL del endpoint creado por el template:

```bash
azd env get-value AZURE_MANAGED_GRAFANA_ENDPOINT
```

Ábrela en el navegador e inicia sesión con Microsoft Entra ID. Si la identidad no tiene acceso, un administrador con permisos de asignación RBAC debe conceder `Grafana Admin` (para crear dashboards) o `Grafana Viewer` (solo lectura) sobre el recurso de Grafana. Obtén el resource ID:

```bash
azd env get-value AZURE_MANAGED_GRAFANA_RESOURCE_ID
az ad signed-in-user show --query id --output tsv
```

El administrador puede asignar el rol apropiado desde **Azure Portal → Managed Grafana → Access control (IAM) → Add role assignment**. El template configura la integración de Grafana con el workspace de Prometheus administrado; usa ese origen de datos para crear un dashboard y dos paneles:

```promql
kube_pod_info{namespace=~"wordpress|prestashop"}
```

```promql
kube_pod_status_ready{namespace=~"wordpress|prestashop", condition="true"}
```

El template ya aprovisiona el dashboard **Kubernetes / Compute Resources / Namespace (Pods)** en la carpeta **Azure Managed Prometheus**. Sus filtros `cluster` y `namespace` permiten escoger `aks-ovpeu5n5emvl4`, `wordpress` y `prestashop`; los paneles muestran CPU, memoria, red e I/O. Para esta ejecución, la consulta `kube_pod_info{namespace=~"wordpress|prestashop"}` devolvió los cuatro pods (portal y MariaDB de cada namespace). Si no hay resultados en la UI, confirma que el origen de datos sea Azure Managed Prometheus y que las variables `cluster` y `namespace` estén seleccionadas.

## Limpieza y costos

Eliminar solo las aplicaciones (incluye sus PVC y datos):

```bash
./scripts/cleanup.sh --namespaces
```

Decisión de apagado para esta entrega: **mantener el entorno activo hasta que la docente revise el PDF y las evidencias**. Los recursos generan costo mientras permanecen desplegados. Después de la revisión, elimina el entorno completo con `azd down`:

```bash
azd down
```

`azd down` **no se ha ejecutado** para conservar el laboratorio disponible para revisión. Al ejecutarlo, elimina los recursos vinculados al entorno, incluido el resource group y sus recursos: AKS, ACR, Managed Grafana, Prometheus workspace, Log Analytics, identidades y asignaciones de roles. También se eliminan los Load Balancers y volúmenes del clúster; verifica en Azure Portal que el resource group ya no exista. Este comando elimina los datos persistentemente guardados en los PVC.

Estimación de orden de magnitud para una región de EE. UU. y un entorno encendido todo el mes (730 h), sin contar impuestos, transferencias de salida ni variación de precios:

| Componente | Estimación mensual orientativa |
|---|---:|
| AKS control plane Standard y 1 nodo `Standard_B2ps_v2` | USD 100–200 |
| Segundo o tercer nodo si escala | +USD 40–100 por nodo |
| Azure Managed Grafana, ACR, discos administrados, IP/LB | USD 20–100 |
| Azure Monitor/Prometheus/Log Analytics | USD 10–100+ según ingesta/retención |
| **Total de laboratorio** | **aprox. USD 150–420/mes** |

Es una aproximación, no una cotización; consulta Azure Pricing Calculator para la región y SKU elegidas. Los cargos de cómputo, discos, direcciones públicas y monitoreo pueden continuar aunque no se acceda a los sitios. Ejecuta `azd down` después de capturar las evidencias.

## Seguridad y buenas prácticas incorporadas

- MariaDB escucha solo mediante `ClusterIP` en su namespace; no hay Service público para puerto 3306.
- Secrets de aplicación y base independientes por namespace; contraseñas aleatorias de 256 bits y nunca incluidas como valores reales en Git.
- `automountServiceAccountToken: false`, seccomp `RuntimeDefault`, requests/limits, probes, versiones de imágenes explícitas y almacenamiento RWO dedicado.
- Los dos portales sí son públicos por requisito del laboratorio y usan HTTP sin TLS. Para producción agrega dominio/TLS, filtrado de `loadBalancerSourceRanges`, política de red, backups, alta disponibilidad y gestión de credenciales con Azure Key Vault/Workload Identity.
- `ClusterIP` impide publicar MariaDB mediante un Load Balancer, pero no bloquea por sí solo el acceso desde otros pods del clúster. Para un entorno compartido/producción, habilita NetworkPolicy compatible con el dataplane AKS elegido y permite únicamente el tráfico desde cada aplicación a su DB.
- Los objetos Kubernetes Secret se codifican en base64 y no equivalen por sí solos a cifrado de extremo a extremo. Restringe RBAC y habilita cifrado/Key Vault de acuerdo con las políticas de la suscripción.

## Archivos del laboratorio y dependencias

| Ruta | Propósito | Dependencias principales |
|---|---|---|
| `azure.yaml`, `infra/` | Bicep y configuración azd del template | `azd`, Azure CLI, permisos Azure |
| `kubernetes/namespaces/` | Namespaces con política Pod Security baseline | Kubernetes |
| `kubernetes/wordpress/` | Secret plantilla, PVC, MariaDB y WordPress | AKS, StorageClass `managed-csi`, imágenes Docker Hub |
| `kubernetes/prestashop/` | Secret plantilla, PVC, MariaDB y PrestaShop | AKS, StorageClass `managed-csi`, imágenes Docker Hub |
| `scripts/deploy.sh` | Obtiene kubeconfig, genera Secrets y aplica recursos en orden | `az`, `azd`, `kubectl`, `envsubst`, `openssl`, `base64` |
| `scripts/verify.sh` | Inspecciona nodos, workloads, PVC y logs | `kubectl` |
| `scripts/cleanup.sh` | Elimina namespaces o ejecuta `azd down` | `kubectl` y/o `azd` |
| `evidencias/` | Checklist y guía de capturas, sin imágenes inventadas | Navegador, Azure Portal, Grafana |
| `architecture.md` | Diagrama y decisiones de diseño | Mermaid para renderizar el diagrama |
