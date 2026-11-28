<div align="center">

<img src="TBox/Assets.xcassets/AppIcon.appiconset/icon.png" width="120" alt="T-Box" />

# T-Box

**Cliente no oficial de [TorBox](https://torbox.app) para iPhone.**
Nativo, rápido, en español e inglés. Pensado para instalar por sideload.

**[⬇️ Descargar T-Box.ipa](https://github.com/maniac75/t-box-for-torbox/releases/latest/download/T-Box.ipa)** · [Novedades (en inglés)](CHANGELOG.md) · [Sitios compatibles](docs/SITES.md) · **[🇬🇧 English](README.md)**

</div>

> T-Box no está afiliado a TorBox. "TorBox" es marca de sus respectivos dueños.

---

## ¿Qué es?

TorBox es un servicio en la nube que descarga torrents, archivos de sitios como Mega o Mediafire y videos de YouTube, Instagram o X, y te los entrega por un enlace rápido. Su web funciona en el iPhone, pero es incómoda. **T-Box** es una app nativa que habla directo con la API de TorBox: sin servidores intermedios, sin publicidad y sin rastreo.

## Capturas

<p align="center">
  <img src="docs/screenshots/en-torrents.png" width="260" />
  <img src="docs/screenshots/en-web.png" width="260" />
  <img src="docs/screenshots/en-share-add.png" width="260" />
</p>
<p align="center">
  <img src="docs/screenshots/es-detail.png" width="260" />
  <img src="docs/screenshots/es-file-menu.png" width="260" />
  <img src="docs/screenshots/es-account.png" width="260" />
</p>

*Torrents y descargas web con AirLock, un enlace de YouTube compartido a T-Box, el detalle de un ítem, acciones sobre un archivo y la pestaña Cuenta. Todo el contenido que se ve es libre o de dominio público.*

## Funciones

### Agregar
- **Un solo lugar para todo**: pega magnets y enlaces web mezclados, uno por línea. Cada uno se reconoce solo y va a Torrents o a Web.
- **Archivos `.torrent`**, varios a la vez, desde Archivos o desde "Compartir".
- **Resultado en vivo** de cada enlace (agregado, en caché, en cola o error con su motivo) y su progreso en TorBox hasta que está listo.
- Tocar un **magnet en Safari** abre T-Box directamente.
- Opción **"solo si ya está en caché"** para no gastar cupos en descargas desde cero.
- Detección de **sitios compatibles** al pegar un enlace, con aviso si el sitio está caído. Corrige solo algunos enlaces problemáticos (Scribd).

### Biblioteca
- **Torrents** y **descargas web** con estado, progreso, velocidad y tiempo restante. Se refresca sola mientras hay algo en curso.
- **Barra de actividad** flotante con lo que está bajando en TorBox y al iPhone. Desde ahí puedes eliminar lo detenido o cancelar descargas.
- Buscar, filtrar (todos, en curso, listos), eliminar y buscar más peers.
- **AirLock** (planes pagados): evita que TorBox borre ítems en su limpieza de 30 días sin uso, con un 🔒 en los protegidos.

### Archivos
- **Reproducir** MP4/MOV con Picture in Picture y AirPlay. **Abrir en Infuse, VLC o VidHub** para MKV y otros formatos.
- **Ver** PDF, imágenes, documentos y audio sin guardarlos.
- **Descargar al iPhone** en segundo plano, aunque cierres la app, a **Archivos › En mi iPhone › T-Box**.
- **Guardar fotos y videos directo en Fotos**, por ejemplo de Instagram o X.
- **Descargar todo como .zip** y **descomprimir** automáticamente o a pedido.
- Copiar o compartir el enlace temporal (no expone tu API key).

### Compartir
- **T-Box en el menú Compartir** de cualquier app: envía magnets y enlaces a TorBox desde donde estés. [Detalles](#compartir-desde-otras-apps)
- **Extensión para Safari**: aparece un botón de T-Box junto a magnets, enlaces `.torrent` y archivos de sitios compatibles con TorBox. Con un toque los mandas a T-Box. Se activa en Ajustes › Apps › Safari › Extensiones.

### Avisos
- Aviso dentro de la app cuando algo termina.
- **Notificaciones** cuando termina una descarga al iPhone o algo queda listo en TorBox. Botón **Probar notificación** en Cuenta.
- Opcional: **avisos instantáneos con [ntfy](https://ntfy.sh)** (experimental), configurados con un toque.

## Qué funciona en cada plan de TorBox

| | Free | Essential / Standard | Pro |
|---|:-:|:-:|:-:|
| Torrents, biblioteca, descargas al iPhone, reproducir y ver | ✅ | ✅ | ✅ |
| Descargas web (YouTube, Instagram, Mega…) | — | ✅ | ✅ |
| Usenet, streaming de TorBox, RSS *(próximamente en T-Box)* | — | — | ✅ |

¿No tienes cuenta? **[Créala con el código de referido del autor](https://torbox.app/subscription?referral=7b4a584a-00a5-430e-aa31-809aa4934cb0)**. Según TorBox, al comprar un plan pagado ambos reciben 7 días extra por cada mes comprado.

## Instalar

1. Descarga **[T-Box.ipa](https://github.com/maniac75/t-box-for-torbox/releases/latest/download/T-Box.ipa)** desde el iPhone.
2. Fírmala e instálala con tu método de sideload:
   - **Con certificado propio**: Feather, ESign, KSign u otra app de firma.
   - **Con Apple ID gratuito**: SideStore o AltStore. La firma vence cada 7 días y se renueva sola.
   - **O agrega la fuente de T-Box** en Feather, ESign, SideStore o AltStore para instalarla y recibir los avisos de actualización ahí mismo:
     ```
     https://raw.githubusercontent.com/maniac75/t-box-for-torbox/main/docs/source.json
     ```
3. Abre T-Box y toca **Obtener código de acceso**: lo apruebas en torbox.app y la app recibe tu API key sola. También puedes pegar la key a mano.

Las versiones nuevas aparecen en [Releases](https://github.com/maniac75/t-box-for-torbox/releases). Cada una trae `T-Box-X.Y.Z.ipa` (con la versión en el nombre) y `T-Box.ipa` (el mismo archivo con nombre fijo, para el botón de descarga directa). Las marcadas **Pre-release** son versiones de prueba.

## Compartir desde otras apps

**T-Box aparece en el menú Compartir** de Safari, Instagram, YouTube, X, Scribd y cualquier app que comparta enlaces. Al tocarlo **se abre T-Box con la hoja Agregar ya completada**: revisas lo detectado y tocas **Agregar**, como al compartir a WhatsApp.

Si T-Box no aparece en Compartir, tu app de firma quitó la extensión: revisa que **"Eliminar extensiones / Remove PlugIns"** esté desactivado y vuelve a firmar, o usa el Atajo de abajo.

- La primera vez, T-Box puede no estar entre los íconos principales: desliza la fila hasta **Más** y actívalo.
- Con SideStore/AltStore y Apple ID gratuito, la extensión ocupa un identificador más de los 10 semanales que permite Apple.

### Alternativa: Atajo

Si la extensión no te funciona, un Atajo de iOS hace lo mismo:

1. Atajos › nuevo atajo › activa **Mostrar en hoja de compartir** y que reciba **URL** y **Texto**.
2. Acción **Codificar URL** sobre la entrada del atajo.
3. Acción **Abrir URL**: `tbox://add?text=` seguido del resultado codificado.

## ¿Encontraste un error o tienes una idea?

- 🐞 **[Reportar un error](https://github.com/maniac75/t-box-for-torbox/issues/new?template=bug_report.yml)**. Adjunta el diagnóstico de Cuenta › Exportar diagnóstico: la API key va censurada automáticamente.
- 💡 **[Sugerir una mejora](https://github.com/maniac75/t-box-for-torbox/issues/new?template=feature_request.yml)**
- 💬 **[Preguntas y conversación](https://github.com/maniac75/t-box-for-torbox/discussions)**

También desde la app: Cuenta › Opina. Puedes escribir en español o en inglés.

## Apoyar el proyecto

T-Box es gratis y siempre lo será. Si te sirve y quieres apoyarlo:

- ☕ [Invítame un café en Ko-fi](https://ko-fi.com/supermaniac) (tarjeta o PayPal, sin cuenta)
- ♥ [Patrocinar en GitHub](https://github.com/sponsors/maniac75)
- 🎁 [Crear o mejorar tu cuenta de TorBox con el código de referido](https://torbox.app/subscription?referral=7b4a584a-00a5-430e-aa31-809aa4934cb0): no te cuesta nada y ambos reciben días extra.

## Acerca de

T-Box es diseñada, probada y mantenida por [maniac75](https://github.com/maniac75). El código se escribe con ayuda de Claude (IA); cada función se decide, se revisa y se prueba en un iPhone real antes de publicarse.

## Privacidad

Todos los detalles en la **[Política de privacidad](PRIVACY.es.md)**.


- La API key se guarda en el **llavero del iPhone** y solo se envía a `api.torbox.app`.
- Sin analítica, sin anuncios, sin servidores propios.
- Los enlaces que compartes con otras apps son temporales y no contienen tu key.
- El diagnóstico exportable (Cuenta › Exportar diagnóstico) **censura la API key** automáticamente.

## Preguntas frecuentes

**¿Por qué no se reproduce un MKV dentro de la app?**
El reproductor de iOS no abre MKV. Usa **Abrir en Infuse**, **Abrir en VLC** o **Abrir en VidHub** con el reproductor correspondiente instalado. Un reproductor propio para MKV está en la hoja de ruta.

**¿Dónde quedan mis descargas?**
En la app Archivos › En mi iPhone › T-Box. Para llevar un archivo a iCloud u otra carpeta, deslízalo en "En el iPhone" › Guardar en… › Guardar en Archivos.

**Las notificaciones de TorBox llegan tarde con la app cerrada.**
iOS decide cuándo dejar que una app revise en segundo plano: a veces cada 15 minutos, a veces cada varias horas. Para avisos inmediatos activa **ntfy** en Cuenta.

**Volví a firmar la app y me pide iniciar sesión de nuevo.**
Es normal si cambiaste de certificado: el llavero queda asociado a quien firmó la app.

**¿Puedo usarla con otra cuenta o compilar mi propia versión?**
Sí. El código de referido y los enlaces están en [`TBox/Config.swift`](TBox/Config.swift).

## Hoja de ruta

- [x] Biblioteca unificada con cola, orden, filtros y selección múltiple (0.4.0)
- [x] Descarga rápida en varias partes, Live Activities, velocidad y tiempo restante (0.4.0)
- [x] Títulos limpios, pausar/reanudar y descargas solo con wifi (0.4.1)
- [ ] Usenet
- [ ] Etiqueta "iphone" con descarga automática y límite de velocidad
- [ ] Widget en la pantalla de inicio y atajos de Siri
- [ ] Ver: catálogo con fuentes de AIOStreams/Torrentio, reproductor MKV (también para ver mientras baja) y streaming de TorBox (Pro)
- [ ] Estado de TorBox, estadísticas de la cuenta y RSS (Pro)
