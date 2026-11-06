# Evidencias del Laboratorio 6

El [informe](./informe-laboratorio-6.md) y el PDF [Lucas Ardila & Sofia Oyola](./Lucas%20Ardila%20%26%20Sofia%20Oyola.pdf) describen el despliegue de la nueva cuenta Azure del 5 de noviembre de 2026. Las capturas y salidas de validación actuales se guardan en [nueva-cuenta-20261105/](./nueva-cuenta-20261105/).

## Capturas nuevas

- `03-wordpress-pagina-publicada.png`: página pública de prueba WordPress.
- `02-prestashop-nueva-cuenta.png` y `04-prestashop-producto-publicado.png`: tienda y producto de prueba PrestaShop.
- `05-grafana-wordpress-dashboard.png` y `05b-grafana-prestashop-dashboard.png`: dashboard real de Azure Managed Grafana, filtrado por namespace, con CPU, memoria y cuotas.
- `06-wordpress-persistencia-tras-reinicio.png` y `07-prestashop-persistencia-tras-reinicio.png`: contenido público después de reiniciar ambos portales y sus bases.
- `verificacion-20261105.txt`: nodos, pods, deployments, Services, PVC, respuesta HTTP, dashboard provisionado y consulta de Prometheus. No contiene valores de Secrets.

Los archivos de evidencia sueltos en la raíz de esta carpeta pertenecen al despliegue anterior y se conservan como histórico; no representan la suscripción nueva.

## Seguridad

No se deben capturar ni compartir los valores de Secrets, contraseñas de administración, tokens de acceso ni códigos efímeros. Las direcciones IP y URLs públicas se incluyeron porque forman parte de la verificación académica; restringe su difusión si no son necesarias.
