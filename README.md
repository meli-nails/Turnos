# Meli Nails · Versión 10 — Servicios o diseño independiente

## Archivos

- `index.html`: reserva pública, selección de hasta dos servicios o un diseño completo, disponibilidad, cálculo y registro de solicitud.
- `admin.html`: panel de administración; muestra el detalle de la opción elegida, la duración, el total y la seña. Permite editar precio completo y duración de cada diseño.
- `supabase-config.js`: URL del proyecto y clave publishable. No contiene `service_role`.
- `migration-booking-options-v3.sql`: agrega precio/duración a los diseños, snapshots de servicios en reservas y las nuevas funciones.
- `migration-booking-rpc-private-hardening.sql`: mueve la lógica `SECURITY DEFINER` a un esquema no expuesto y deja los endpoints de `public` como `SECURITY INVOKER`.
- `migration-booking-array-index-cleanup.sql`: elimina un índice auxiliar que no se usa en las consultas actuales.
- `migration-booking-client-name-snapshot.sql`: agrega el nombre capturado por reserva para que una actualización del cliente no renombre turnos anteriores.
- `migration-booking-v2.sql` y `migration-fix-pending-limit.sql`: migraciones anteriores que forman parte del historial de este proyecto.

## Regla de reserva

1. Se pueden elegir uno o dos servicios. Se suman los precios y las duraciones.
2. Como alternativa, se puede elegir un único diseño. No se combina con servicios; se cobra el precio completo del diseño y se usa su duración configurada.
3. Los extras se siguen sumando al total de cualquiera de las dos modalidades. No agregan tiempo.
4. La seña continúa calculándose con `business_settings.deposit_percent` (actualmente 30 %). La web no fija el porcentaje por su cuenta.

## Configuración de diseños

La migración inicializó `designs.price` copiando el importe que ya estaba en `extra_price` para los diseños con valor positivo. La duración inicial de los diseños existentes es de 60 minutos. Revisá cada diseño desde **Admin → Diseños → Editar** y corregí la duración real (y el precio, si corresponde). El campo `extra_price` antiguo se conserva por compatibilidad, pero la nueva reserva no lo utiliza.

## RPC nuevas

- `get_available_days_v2(p_service_ids, p_design_id, p_from, p_to)`
- `get_available_slots_v2(p_service_ids, p_design_id, p_date)`
- `create_booking_request_v3(p_service_ids, p_design_id, p_starts_at, p_name, p_phone, p_notes, p_extras, p_location)`

La validación de exclusividad, precios, duración y disponibilidad se realiza en PostgreSQL. `service_id` y `service_name` antiguos siguen presentes para compatibilidad; las nuevas reservas también guardan `service_ids` y `service_names`. Cada reserva captura además `client_name`, independiente del nombre actual de la ficha del cliente.

## Despliegue

Reemplazá los tres archivos de la web (`index.html`, `admin.html` y `supabase-config.js`) en la misma carpeta/ruta pública. Las migraciones y el hardening de las RPC ya se aplicaron al proyecto Supabase `vfkalbukfiyprugqepcy`; no hace falta volver a ejecutarlos en ese proyecto. También se aplicó el snapshot `bookings.client_name` y se actualizó `create_booking_request_v3` para guardar el nombre por reserva. Los archivos SQL se incluyen como respaldo/versionado y para reconstrucción de otro entorno.

La comprobación remota confirmó que el calendario devuelve horarios para la modalidad de dos servicios y para diseño independiente, que las nuevas RPC públicas son `SECURITY INVOKER`, y que la seña sigue en 30 %. No se declara una prueba visual de extremo a extremo en navegador.

## Correcciones de esta versión 10.1

- El nombre se guarda como snapshot en cada reserva. Si dos turnos comparten el mismo teléfono y el segundo se registra con otro nombre, el primero conserva su nombre original.
- Los favoritos ahora se identifican por el UUID del diseño, no por su nombre visible. Así, dos diseños con el mismo nombre no se marcan juntos. Los favoritos antiguos guardados por nombre se migran al primer diseño coincidente al cargar el catálogo.
