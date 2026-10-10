# HTTPS móvil: guía / Mobile HTTPS guide

Corresponde a las mejoras del siguiente paquete, aún no incluidas en el instalador público 1.7.0. / Applies to upcoming changes, not yet included in the public 1.7.0 installer.

## Español — paso a paso

1. Laptop y celular deben conectarse al mismo router. Ethernet en la laptop y Wi-Fi en el celular funcionan. No uses una red de invitados aislada ni abras el puerto del router a Internet.
2. PC: **Pantallas y distribución → Celular o tablet → Activar monitor web en mi red local**. Espera al QR. No es necesario desactivar y activar de nuevo.
3. Pulsa **Configurar HTTPS · pantalla encendida…**. Lee el permiso y prepara el certificado. La laptop conserva las claves privadas; al celular sólo se descarga un certificado público.
4. Escanea el QR de preparación. Compara la huella SHA-256 completa con la de la PC antes de descargar o instalar. Si no coincide, detente.
5. Samsung/Android: **Ajustes → Seguridad y privacidad → Más ajustes de seguridad → Instalar desde almacenamiento del dispositivo**. Instala como **certificado de CA**, no como certificado Wi-Fi. Los nombres pueden variar. Se necesita el bloqueo/PIN del dispositivo. Revisa después **Ver certificados de seguridad → Usuario**. Ruta confirmada por el usuario en Samsung S26 Ultra / One UI 9.
6. Regresa al asistente de la PC, confirma que comparaste la huella e instalaste el certificado y pulsa **Activar HTTPS**.
7. Abre el QR del monitor HTTPS. En la información de sitio de Chrome debe decir **«La conexión es segura»**. Si ves HTTPS tachado o `NET::ERR_CERT_AUTHORITY_INVALID`, la confianza no está bien instalada: revisa CA, huella y dispositivo. **No uses «Continuar (no seguro)» como solución.** Cifrado y confianza de identidad son cosas distintas, incluso en una LAN.
8. En el celular: **Editar → Mantener pantalla encendida**. El navegador necesita una conexión confiable, compatibilidad y permiso. Ahorro de batería o pasar a segundo plano pueden liberar ese permiso.
9. Opcional: PC → ventana móvil → **Permitir controlar el temporizador… → Aplicar módulos**. Recarga la página. Los iconos permiten iniciar/pausar, añadir tiempo, restablecer y configurar. Quien tenga el QR en esa LAN podrá cambiar el temporizador; desmarca el permiso para dejarlo sólo de lectura.

### ¿Hay que reinstalar el certificado?

No por cerrar/abrir el monitor, desactivar/reactivar el acceso, generar un nuevo QR ni actualizar conservando la misma instalación y autoridad. Un cambio de IP puede necesitar renovar el certificado del servidor, pero no instalar otra vez la misma CA. Sí cuando se sustituye la autoridad (otra laptop/instalación, pérdida de identidad o renovación de CA), se borra del celular, o se configura otro dispositivo. La CA dura tres años; el certificado del servidor dura 90 días y se renueva reutilizando esa CA. Comprueba la nueva huella cuando corresponda.

Confiar en una CA es un permiso sensible: puede abarcar otros certificados que firme. Guarda su clave privada en la laptop, no compartas el QR y elimina la CA del celular si dejas de usarla. Volver a HTTP no borra automáticamente la confianza instalada. En iPhone/iPad, sigue la guía de perfil del asistente y activa la confianza de la raíz; esa ruta no ha sido validada físicamente en este proyecto.

## English — setup

1. Use the same router: Ethernet PC and Wi-Fi phone are supported. Avoid isolated guest networks and Internet port forwarding.
2. PC: **Display layout → Phone or tablet → Enable web monitor on my local network**. Wait for the QR; no off/on cycle is required.
3. Select **Set up HTTPS**, review the permission and prepare the certificate. Private keys stay on the laptop; only the public certificate is downloaded.
4. Scan the setup QR and compare the full SHA-256 fingerprint against the PC before installation. Stop if they differ.
5. Samsung/Android: **Settings → Security and privacy → More security settings → Install from device storage**. Choose a **CA certificate**, not Wi-Fi. Labels vary. Verify it under **View security certificates → User**. The Spanish route above was user-confirmed on One UI 9.
6. On the PC, confirm fingerprint comparison and installation, then **Activate HTTPS**. Open the secure monitor QR.
7. Chrome site information must show **“Connection is secure.”** A struck-through HTTPS address or `NET::ERR_CERT_AUTHORITY_INVALID` means trust is unresolved. Check installation and fingerprint; **do not bypass the browser warning**. LAN encryption alone does not prove server identity.
8. Mobile: **Edit → Keep screen awake** if supported. Trusted HTTPS, browser support and permission are required; battery saving/backgrounding may release the wake lock.
9. Optional timer control: explicitly enable it in the PC mobile dialog and apply. Reload the mobile page. Anyone holding that QR on the LAN can operate the shared timer; disabling permission returns to read-only.

The same CA does not need reinstalling after toggling access, restarting, changing QR or an update that preserves installation identity. A new CA, another device/laptop or removal of trust requires setup again. Server certificates renew using the existing CA; a new IP does not itself require a new root. Trusting a CA is sensitive; remove it when no longer needed. Returning to HTTP does not remove phone trust. iOS physical-device validation remains pending.
