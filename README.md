# Meli Nails · Sitio público + administración

Paquete completo para publicar la web de reservas y el panel administrativo en GitHub Pages o en un hosting estático.

## Archivos

- `index.html`: sitio público. Consulta servicios y diseños publicados en Supabase, muestra disponibilidad real y registra las solicitudes antes de abrir WhatsApp.
- `admin.html`: panel privado con autenticación Supabase, resumen, gestión de solicitudes, cambios de estado, bloqueo de horarios y administración del catálogo de servicios y diseños.
- `supabase-config.js`: URL del proyecto y clave publishable. No contiene una clave `service_role`.

## Cómo publicar

1. Hacé una copia de seguridad de los archivos actuales del repositorio.
2. Subí estos tres archivos (`index.html`, `admin.html` y `supabase-config.js`) al directorio raíz del mismo repositorio, reemplazando los anteriores.
3. Conservá los nombres exactos y la misma ruta para los tres archivos.
4. Esperá a que GitHub Pages publique los cambios.
5. Probá la web pública desde una ventana privada y el panel en `.../admin.html`.

## Flujo de reserva

1. El catálogo público se carga desde las tablas `services` y `designs`.
2. La disponibilidad se consulta con `get_available_slots_v2` y no se genera con horarios ficticios en el navegador.
3. Al pulsar **Reservar mi turno**, la web llama a `create_booking_request_v3`.
4. La función de PostgreSQL valida la opción, el precio, la duración, los extras, el horario y las reglas de reserva. La solicitud se guarda con estado `pending`.
5. Solo cuando Supabase devuelve el código de reserva, se abre WhatsApp para notificar a Meli.
6. `admin.html` lee `bookings` y muestra las solicitudes recibidas.

Si el registro en Supabase falla, la página muestra el error y no abre WhatsApp como si la solicitud se hubiera guardado.

## Supabase

Este paquete apunta al proyecto existente `vfkalbukfiyprugqepcy`. Las funciones requeridas ya están creadas y se verificó que los roles `anon` y `authenticated` pueden ejecutar las RPC públicas:

- `get_available_slots_v2(uuid[], uuid, date)`
- `get_available_days_v2(uuid[], uuid, date, date)`
- `create_booking_request_v3(uuid[], uuid, timestamptz, text, text, text, jsonb, text)`

**No ejecutes migraciones SQL de nuevo en el proyecto existente.** El paquete no modifica el esquema ni los datos de Supabase. La clave publishable/anon es pública por diseño; nunca reemplazarla por `service_role`.

## Acceso al panel

El usuario debe existir en Supabase Authentication y estar autorizado en la tabla `admins` mediante su `user_id`. La autenticación no se limita a un dispositivo: podés iniciar sesión desde el teléfono y desde una computadora.

## Imágenes del catálogo

El panel permite subir JPG, PNG y WebP de hasta 5 MB al bucket público `media`. Para crear o actualizar diseños se requieren permisos administrativos sobre `designs` y `storage.objects` según las políticas actuales del proyecto.

## Validaciones realizadas

- Sintaxis JavaScript de todos los scripts inline de `index.html` y `admin.html` (`node --check`).
- Existencia y firma de las tres RPC utilizadas.
- Permisos `EXECUTE` para `anon` y `authenticated` en las RPC públicas.
- Consulta real de disponibilidad mediante `get_available_slots_v2` para un servicio activo.
- Revisión de las políticas RLS de servicios, diseños, reservas, clientes y bloqueos.
- No se creó ninguna reserva de prueba ni se cambió la base de datos durante esta corrección.

La prueba final de una reserva real debe hacerse desde la web publicada con una reserva que quieras registrar; el envío genera una fila real en `bookings`.
