# Política de privacidad de T-Box

*Última actualización: 15-11-2026 · [English version](PRIVACY.md)*

T-Box es un cliente no oficial y de código abierto de TorBox para iPhone. **No tiene servidores, ni cuentas propias, ni analítica, ni publicidad, ni rastreo.** Esta política explica exactamente qué datos maneja la app, a dónde van y quién puede verlos.

## Datos que maneja T-Box

| Dato | Para qué | Dónde se guarda | Quién lo recibe |
|---|---|---|---|
| **Tu API key de TorBox** | Para hablar con la API de TorBox en tu nombre | Solo en tu iPhone, en el **llavero de iOS** (también en un grupo del llavero compartido con la propia extensión de Compartir de T-Box) | Solo **TorBox** (`api.torbox.app`), en la cabecera `Authorization` o como el parámetro `token` que TorBox exige para crear enlaces de descarga |
| Tu correo, plan y vencimiento de TorBox | Se muestran en la pestaña Cuenta | Solo en memoria, mientras la app está abierta | Se leen de TorBox; no se envían a ningún otro lado |
| Tus ítems de TorBox (nombres, tamaños, progreso) y tu código de referido | Para mostrar tu biblioteca y tu enlace de referido | Solo en memoria | Se leen de TorBox; no se envían a ningún otro lado |
| Archivos que descargas | Porque pediste descargarlos | En tu iPhone: Archivos › En mi iPhone › T-Box, o Fotos si lo eliges | Nadie, salvo que los compartas |
| Ajustes de la app (notificaciones, descomprimir al terminar, tu tema de ntfy si lo activas), los IDs de los ítems en curso y un contador de descargas completadas | Para recordar tus preferencias, avisarte cuando algo queda listo y mostrar una sola vez la tarjeta de apoyo | En tu iPhone (ajustes de la app) | Nadie |
| Registro de diagnóstico (errores de red, rutas de la API, versión de la app, versión de iOS, modelo de equipo) | Para corregir errores | En tu iPhone. **Tu API key va censurada** | Nadie, salvo que **tú** lo exportes y lo envíes (por ejemplo, en un issue de GitHub) |

T-Box **no** recopila ni guarda contraseñas, datos de pago, contactos, ubicación ni datos de otras apps.

## Terceros

- **TorBox** recibe cada llamada a la API, como con cualquier cliente de TorBox. Ver la [política de privacidad de TorBox](https://torbox.app/privacy).
- **ntfy.sh** (opcional, desactivado por defecto): si activas *Avisos instantáneos con ntfy*, T-Box configura el webhook de tu cuenta de TorBox hacia un tema aleatorio de ntfy. Desde ahí TorBox envía los avisos (incluidos los nombres de los ítems) a `ntfy.sh`. Lo puedes desactivar cuando quieras en Cuenta.
- **Infuse, VLC y otras apps:** solo si eliges *Abrir en…*, *Copiar enlace* o *Compartir enlace*, T-Box le entrega a esa app un **enlace temporal de descarga de TorBox**. Esos enlaces no contienen tu API key.
- **GitHub (aviso de versión nueva):** como máximo cada 12 horas, T-Box le pregunta a la API pública de GitHub cuál es la última versión, para mostrar el aviso de actualización. Es una consulta anónima, sin cuenta, API key ni datos personales; GitHub ve tu dirección IP como cualquier sitio web.
- **GitHub y Ko-fi:** los enlaces de Opina y Apoyar solo abren esos sitios en tu navegador. T-Box no les envía nada; la versión de la app y de iOS solo aparecen completadas en el formulario de error que ves antes de enviarlo.

T-Box no vende, arrienda ni comparte tus datos con nadie más.

## Tu control

- **Cerrar sesión** (Cuenta) borra tu API key del llavero.
- Borrar la app elimina todos sus datos locales, incluidos los archivos descargados en su carpeta.
- *Copiar API key* deja la key en el portapapeles solo 2 minutos, y solo si lo confirmas.

## Cambios y contacto

Esta política puede cambiar a medida que T-Box evoluciona; los cambios se anotan en el [CHANGELOG](CHANGELOG.md). Consultas: [abre un issue](https://github.com/maniac75/t-box-for-torbox/issues) o una [discusión](https://github.com/maniac75/t-box-for-torbox/discussions). El código es público, así que puedes verificar todo lo que dice aquí.
