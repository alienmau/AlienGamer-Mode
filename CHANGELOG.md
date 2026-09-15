# Historial de cambios

## 1.2.0 — 15 de septiembre de 2026

- Añade español (`es-MX`) e inglés (`en-US`) mediante recursos de traducción centralizados.
- Permite elegir el idioma desde el diálogo inicial de Inno Setup y conserva la selección en la configuración del usuario.
- Incorpora **Idioma / Language** en el menú de bandeja para cambiar la skin y el agente sin reiniciar HWiNFO ni el puente de sensores.
- Traduce los textos del monitor, estados de frame time, ayudas, botones, menús, configurador de luciérnagas, avisos principales y diálogos de grabación.
- Mantiene español como idioma predeterminado y permite agregar idiomas futuros sin duplicar la lógica del monitor.
- Añade documentación principal en inglés.

## 1.1.1 — 15 de septiembre de 2026

- Corrige el botón **OFF** de la skin para que ejecute el mismo cierre coordinado que **Detener monitor** en el icono de bandeja.
- Añade un canal local persistente como respaldo cuando Rainmeter y el agente se ejecutan con niveles de permisos distintos.
- El apagado desde la skin detiene el puente, finaliza HWiNFO y Rainmeter cuando fueron iniciados por AlienGamer Mode, actualiza el estado y sincroniza el menú de bandeja.
- Mantiene el evento rápido existente y agrega confirmación de que el agente procesó la solicitud.

## 1.1.0 — 11 de septiembre de 2026

- Añade el submenú persistente **Módulos visibles** para mostrar u ocultar procesadores, el bloque flotante de FPS y alertas, y el reloj.
- Los tres módulos permanecen activos por defecto en instalaciones nuevas; ocultarlos no excluye sus datos de las grabaciones técnicas.
- Evita que una solicitud cancelada durante el refresco de Rainmeter cierre el puente y deje sensores en cero o `N/D`.
- Muestra progreso al aplicar módulos, oculta inmediatamente y reutiliza el perfil validado para reducir la espera.
- Incorpora el reloj a **Módulos visibles** y conserva su selección entre sesiones.
- Cambia las alarmas críticas de uso y temperatura a un pulso sólido entre rojo base y rojo intenso, incluyendo la temperatura del almacenamiento.

- Sustituye ondas, malla y trazadores por partículas radiales ascendentes.
- Cada luciérnaga varía en tamaño, profundidad, velocidad, deriva, pulso y altura de desaparición.
- Elimina por completo el análisis y la reacción al audio.
- Agrega a la bandeja activación independiente y un panel con controles de cantidad, velocidad, tamaño y color.
- Distribuye el recorrido: 70% puede cubrir hasta el 75% de la altura y 30% completa el 100% hasta el borde superior.
- Convierte el tamaño máximo anterior en la nueva referencia base de 100%, ajustable entre 70% y 160%.
- Aumenta la transparencia de los contenedores para integrar visualmente el fondo.
- Define límites seguros de 8 a 48 partículas y conserva el escalado responsivo y la protección OLED.

- Contenedores de cristal ahumado semitransparente y contraste controlado.
- Parámetros nuevos incorporados automáticamente a configuraciones anteriores.

## 1.0.9 — Primera versión pública

- Detección adaptable de hardware, monitor, GPU y almacenamiento.
- Skin responsiva para diferentes resoluciones y escalas DPI.
- RAM, VRAM, CPU, GPU, temperaturas, FPS, *frame time* y carga por núcleo.
- Procesadores dinámicos: sensores ausentes se ocultan sin crear valores falsos.
- Validación de identidad, fuente, unidad, rango y coherencia de sensores.
- Indicadores de límite térmico y de potencia.
- Reloj digital tipo matriz.
- Transiciones suavizadas, pulsos críticos y protección para pantallas OLED.
- Grabación de eventos con reporte técnico en Excel.
- Agente de bandeja con controles sincronizados.
- Instalador gráfico y reparación automatizada de HWiNFO Shared Memory.
