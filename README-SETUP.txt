MELI NAILS · INTEGRACIÓN CON SUPABASE EXISTENTE
================================================

ARCHIVOS
- index.html: web pública integrada con catálogo, agenda y solicitudes.
- admin.html: panel de administración con Supabase Auth y flujo completo de estados/WhatsApp.
- supabase-config.js: URL y clave publishable del proyecto conectado.
- migration-booking-v2.sql: migración aplicada para modalidad y extras.
- migration-authenticated-rpcs.sql: migración aplicada para que las RPC públicas también funcionen con una sesión Auth activa.
- migration-fix-pending-limit.sql: corrección del límite antiabuso para que solicitudes pendientes antiguas no bloqueen nuevos turnos.

PROYECTO CONECTADO
- Project ref: vfkalbukfiyprugqepcy
- URL: https://vfkalbukfiyprugqepcy.supabase.co
- Auth: inicio de sesión por email y contraseña; el usuario debe existir en public.admins.
- Catálogo: public.services y public.designs.
- Reservas: public.bookings y public.clients.
- Disponibilidad: RPC get_available_days (marca únicamente días con al menos un horario libre) y get_available_slots (horas exactas libres).
- Las RPC públicas de catálogo/agenda/solicitud están autorizadas para anon y authenticated; las tablas administrativas siguen protegidas por RLS y public.admins.
- Imágenes: Storage bucket público media (JPG/PNG/WebP hasta 5 MB), con políticas de escritura para usuarios autenticados que pertenezcan a public.admins.
- Crear solicitud: RPC create_booking_request_v2.

SEGURIDAD
Se incluye únicamente la clave publishable pública. No agregar service_role ni secret keys al frontend.
RLS y la membresía admins siguen siendo la autoridad de acceso.

PUBLICACIÓN
Subí index.html, admin.html y supabase-config.js en la misma carpeta/origen. Abrí admin.html e iniciá sesión con el usuario ya autorizado en public.admins.

NOTAS
- Los diseños de muestra (is_sample=true) no aparecen en el catálogo público hasta que se publiquen desde el panel.
- Al editar/publicar un registro de muestra desde el panel, se marca is_sample=false.
- La reserva requiere servicio; diseño es opcional y suma su extra_price.
- Los importes de servicio, diseño y extras se calculan en PostgreSQL.
- La solicitud se registra antes de abrir WhatsApp; si falla el guardado, no se envía un mensaje que aparente una reserva registrada.
- En el calendario público solo se pueden seleccionar días con horarios libres para el servicio elegido; las reservas pendientes, confirmadas y completadas bloquean el horario.
- La carga de diseños permite arrastrar/seleccionar una imagen, ver una vista previa y subir JPG/PNG/WebP de hasta 5 MB a Storage → media. El administrador debe estar autenticado y autorizado en public.admins.
- Desde Turnos, el administrador puede confirmar o rechazar solicitudes pendientes. En los turnos confirmados puede marcar el servicio como completado, cancelar el turno o registrar una ausencia.
- Cada cambio de estado solicita confirmación, se guarda en public.bookings y actualiza el panel. Transiciones permitidas: pendiente → confirmado/rechazado; confirmado → completado/cancelado/ausente. Los estados finales no se reabren desde el selector para evitar reactivar accidentalmente horarios ya liberados.
- El botón de WhatsApp normaliza el número al formato internacional argentino y cambia según el estado: consulta de solicitud pendiente, confirmación, rechazo, cancelación, agradecimiento por el servicio o seguimiento de ausencia. Abre WhatsApp con el texto preparado; nunca envía mensajes automáticamente. Meli revisa y pulsa Enviar.
- La confirmación mantiene el horario reservado. El rechazo y la cancelación liberan el horario (salvo que exista otro bloqueo); completar y ausente conservan el registro histórico.
- Desde Turnos también puede bloquear o liberar horarios manuales en public.time_blocks para compromisos coordinados fuera de la web.
- La disponibilidad se consulta en tiempo real según working_hours, time_blocks, min_notice y reservas existentes.

Corrección adicional (25/11/2026)
- La función create_booking_request_v2 ahora solo cuenta solicitudes pendientes con fecha futura para el límite antiabuso de 3 por teléfono. Las solicitudes viejas/pasadas ya no bloquean nuevas reservas.
- En el panel, la URL de imagen se valida antes de guardar y la vista previa informa si el enlace no entrega una imagen directa. Se normalizan enlaces públicos de Google Drive y Dropbox cuando es posible.
- Para enlaces externos, usar URL pública directa a un archivo de imagen; no sirve el enlace a una página de publicación/álbum privado.
