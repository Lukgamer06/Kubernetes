# Informe — Laboratorio 6: IoT, Cloud y Sistemas Distribuidos

**Estudiantes:** Lucas Ardila y Sofia Oyola  
**Fecha de ejecución:** 5 de noviembre de 2026  
**Región:** `centralus` · **Entorno `azd`:** `lab6-lucas-sofia-20261105`  
**Resource group:** `rg-lab6-lucas-sofia-20261105`  
**AKS:** `aks-ovpeu5n5emvl4` · Kubernetes `1.36.3` · 3 nodos `Standard_B2ps_v2`

## Arquitectura y despliegue

Se provisionó desde cero una suscripción Azure distinta de la utilizada en el intento anterior, mediante `azd provision` y el Bicep del template `sabbour/aks-app-template`. El mismo clúster AKS aloja dos portales aislados por namespace: `wordpress` y `prestashop`. Cada namespace contiene su aplicación, su propio MariaDB, un Secret independiente y dos PVC `managed-csi` de 8 GiB (uno para archivos del portal y otro para la base). Las bases tienen Services `ClusterIP` y no se exponen a Internet. Los portales usan Services `LoadBalancer` y comparten la IP pública `172.168.157.10` en puertos separados: WordPress `:80` y PrestaShop `:8080`.

El template también creó Azure Managed Grafana, Azure Monitor managed Prometheus, Log Analytics y ACR. Grafana está fuera del clúster y consulta las métricas de AKS mediante el datasource administrado. El dashboard **Kubernetes / Compute Resources / Namespace (Pods)**, en la carpeta **Azure Managed Prometheus**, permite elegir el cluster y cada namespace. Presenta CPU usada y cuotas, memoria usada y cuotas, y métricas de red. Se asignó a la identidad Azure activa el rol de solo lectura `Grafana Viewer`.

## Validación y persistencia

Los tres nodos aparecen `Ready`; WordPress, PrestaShop y las dos MariaDB completaron sus rollouts. Los cuatro PVC están `Bound`. Los servicios `wordpress/mariadb` y `prestashop/mariadb` son `ClusterIP`; los servicios de los portales son `LoadBalancer`.

Se instaló WordPress y se publicó la página **Lab 6 - Persistencia WordPress**. En PrestaShop se creó el producto **Producto Lab 6 Persistente** (EUR 19,99; stock 5). Se reiniciaron secuencialmente las dos bases de datos y los dos portales con `kubectl rollout restart deployment`; los cuatro rollouts finalizaron correctamente. Después del reinicio, la página y la ficha del producto respondieron HTTP 200 y continuaron visibles; sus registros y cantidades se mantuvieron en MariaDB. La consulta en Azure Monitor managed Prometheus devolvió los cuatro pods de ambos namespaces. Las capturas de Grafana muestran los paneles de cada namespace y las métricas observadas tras el reinicio. La evidencia textual completa y sin valores de Secrets está en `nueva-cuenta-20261105/verificacion-20261105.txt`.

## Seguridad, costos y decisión de apagado

Cada base de datos permanece privada como `ClusterIP`; los accesos y contraseñas se guardan en Secrets de Kubernetes y no se incluyen en el repositorio. Los portales son públicos por requisito del laboratorio y usan HTTP sin TLS; no deben considerarse una configuración de producción. Los namespaces organizan los recursos, pero no son una política de red. Para producción se requieren TLS, control de origen, NetworkPolicies, respaldos, alta disponibilidad y gestión de secretos apropiada.

El costo estimado del entorno encendido durante un mes completo es **USD 150–420**, como orden de magnitud para AKS, nodos, discos, Azure Managed Grafana y monitoreo. No es una cotización: depende de uso, retención, región y precios vigentes; revisar Azure Cost Management. **Decisión:** conservar el clúster activo para la revisión académica y ejecutar `azd down` al terminar. No se ejecutó el apagado en esta entrega porque borraría AKS, Grafana y los PVC con los datos del laboratorio. El consumo continúa mientras los recursos sigan activos.

> Las evidencias de la cuenta anterior, presentes en la raíz de `evidencias/`, son históricas. Las capturas y verificaciones de este nuevo despliegue están separadas en `nueva-cuenta-20261105/`.
