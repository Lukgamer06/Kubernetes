# Capturas requeridas — cuenta Azure nueva

Todas las capturas siguientes se tomaron el 5 de noviembre de 2026 durante la ejecución nueva. Ver también [verificacion-20261105.txt](./nueva-cuenta-20261105/verificacion-20261105.txt).

1. **WordPress público — completado:** `03-wordpress-pagina-publicada.png`.
3. **PrestaShop público — completado:** `02-prestashop-nueva-cuenta.png`.
4. **Producto público — completado:** `04-prestashop-producto-publicado.png`.
5. **Grafana y namespaces — completado:** `05-grafana-wordpress-dashboard.png` y `05b-grafana-prestashop-dashboard.png`; dashboard real con el filtro `namespace` en cada portal.
6. **Reinicio WordPress y MariaDB — completado:** `06-wordpress-persistencia-tras-reinicio.png`; HTTP 200 y contenido visible después del rollout.
7. **Reinicio PrestaShop y MariaDB — completado:** `07-prestashop-persistencia-tras-reinicio.png`; HTTP 200 y producto visible después del rollout.
8. **Apagado — documentado, no ejecutado:** el entorno se conserva para la revisión académica. Ejecutar `azd down` después de la evaluación; elimina los datos persistidos del resource group.

Verifica fecha, sitio y contenido antes de compartir. No incluyas salidas de Secrets, contraseñas ni tokens.
