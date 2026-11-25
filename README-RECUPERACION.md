# Meli Nails — paquete de recuperación

## Contenido
- `index.html`: web pública.
- `admin.html`: panel de administración.
- `supabase-config.js`: URL y clave publishable del proyecto.
- `supabase/migrations/`: archivos SQL recuperados del historial de GitHub.
- `.nojekyll`: configuración para GitHub Pages.

## Publicación
1. Descargá y descomprimí este ZIP.
2. Subí el contenido de la carpeta `Meli-Nails-Recuperado` a la raíz de la rama `main` del repositorio `meli-nails/Turnos`, conservando la carpeta `supabase/migrations/`.
3. En GitHub, verificá Settings → Pages y que publique desde `main` / raíz.
4. Esperá el despliegue y probá primero la web pública; después el panel en `/Turnos/admin.html`.

## Supabase: MUY IMPORTANTE
La base de datos productiva ya contiene tablas y funciones. Los SQL se incluyen como respaldo/historial, **no para ejecutarlos todos otra vez**. No ejecutes migraciones a ciegas: algunas alteran funciones, columnas y permisos. Antes de ejecutar cualquiera, comparar su contenido con el esquema y funciones actuales de Supabase.

## Acceso admin
El panel no tiene una contraseña predeterminada. Requiere:
- usuario creado en Supabase Authentication;
- fila correspondiente en `public.admins` con el mismo `user_id`;
- políticas RLS que permitan al usuario consultar su propia autorización.

No se incluye ni se debe subir una `service_role` key. La clave de `supabase-config.js` es publishable.

## Estado de verificación y límites
- Se preservan los HTML y configuración del paquete local de recuperación que ya existía en esta sesión.
- No se realizaron escrituras en GitHub ni cambios en Supabase.
- No se creó una reserva de prueba.
- Este ZIP no demuestra por sí solo que GitHub Pages haya desplegado correctamente ni que el flujo completo de reserva haya sido probado en navegador. Después de subirlo, comprobar errores de consola y realizar una prueba controlada con autorización.
