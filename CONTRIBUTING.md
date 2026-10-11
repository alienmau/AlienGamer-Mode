# Contribuir a AlienGamer Mode

Gracias por ayudar a mejorar el proyecto.

## Antes de comenzar

- Revisa las incidencias existentes para evitar duplicados.
- No adjuntes registros con datos personales sin revisarlos primero.
- Conserva la compatibilidad con sensores ausentes: nunca reemplaces un dato desconocido por un cero inventado.
- Mantén separadas las dependencias externas; no agregues instaladores de Rainmeter, HWiNFO ni fuentes sin autorización de redistribución.

## Reportar un problema

Incluye:

- versión de AlienGamer Mode, Windows, Rainmeter y HWiNFO;
- resolución, escala DPI y número de monitores;
- CPU, GPU y tipo de almacenamiento;
- pasos para reproducir el problema;
- captura de pantalla y fragmento de registro relevante, sin información privada.

## Proponer cambios

1. Crea una rama desde `main`.
2. Haz cambios pequeños y relacionados con un solo objetivo.
3. Ejecuta `tests/Test-AlienGamerMode.ps1`.
4. Describe qué cambió, cómo se validó y qué hardware se utilizó.

Las modificaciones visuales deben conservar el diseño a distintas resoluciones y escalas DPI.

## Documentación de cada publicación / Release documentation

- Mantén `README.md` y `README.en.md` como presentación del producto actual: sólo la versión vigente, funciones disponibles, capturas representativas, requisitos y guías. Actualiza ambos idiomas al publicar mejoras principales; no acumules apartados de versiones anteriores ni listas de fixes en la portada.
- Detalla cambios, correcciones, validaciones y limitaciones por versión en GitHub Releases, `CHANGELOG.md` y sus notas en `docs/`. Conserva allí el historial.
- Usa el enlace `releases/latest` para la descarga principal. No muestres funciones planificadas como disponibles ni capturas de prueba como validación en equipos reales.
- Keep both READMEs focused on the current product: current version, available features, representative screenshots, requirements and guides. Refresh them for major feature changes; place version-by-version fixes, validation and history in Releases, CHANGELOG and release notes instead.
