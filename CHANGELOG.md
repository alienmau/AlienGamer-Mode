# Historial de cambios

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
