# PROGRESS.md — Avance Tablet (Flutter)

Registro de avance del componente Tablet. Actualizar tras cada sesión/tarea completada. Ver `CLAUDE.md` para contexto general del proyecto.

## Estado actual

**Fase:** No iniciado — setup pendiente.
**Última actualización:** 2026-08-27

Carpeta `flutter/` existe pero está vacía. Proyecto Flutter aún no creado (`flutter create` pendiente).

## Checklist (según cronograma de 3 semanas de la especificación)

### Semana 1: Setup + Mini-juegos básicos
- [ ] Instalar Flutter SDK
- [ ] Crear proyecto Flutter base (`flutter create`)
- [ ] Estructurar carpetas (lib/models, screens, widgets, services, providers, utils, config)
- [ ] Agregar dependencias en pubspec.yaml (web_socket_channel, provider, flutter_local_notifications, vibration, flutter_svg, lottie, logger, shared_preferences)
- [ ] Commit inicial
- [ ] Modelos: Task, Attack, GameSession
- [ ] Pantalla splash/inicio
- [ ] ConnectionProvider
- [ ] WebSocketService + testing de conexión
- [ ] GameProvider
- [ ] Mini-juego 1: Conectar Cables
- [ ] Mini-juego 2: Girar Perillas

### Semana 2: Más mini-juegos + feedback
- [ ] Mini-juego 3: Resolver Secuencias
- [ ] Mini-juego 4: Ritmo Crítico
- [ ] Feedback háptico (vibración)
- [ ] Sonidos (alarma, acierto, error)
- [ ] NotificationService
- [ ] StatusBar widget (estado conexión, vida, timer)
- [ ] GameScreen principal integrando mini-juegos
- [ ] GameOverScreen

### Semana 3: Pulido + integración + testing
- [ ] Reconexión automática (max 5 intentos, cada 3s)
- [ ] Manejo de errores robusto
- [ ] Efectos visuales / animaciones
- [ ] Testing con servidor Python real
- [ ] Logging completo
- [ ] Testing en tablet real / distintos tamaños de pantalla
- [ ] Documentación
- [ ] APK build
- [ ] Demo final

## Decisiones tomadas

- Ninguna aún (proyecto sin iniciar).

## Bloqueos / dependencias del equipo

- Necesito del compañero de Backend (Python): IP:puerto real del servidor WebSocket, confirmación del formato JSON exacto (ya especificado en `docs/FLUTTER_TABLET_ESPECIFICACION.md`, pero pendiente validar en la práctica).
- Mientras no haya backend real, usar mock server (`test_server.py` de referencia en la especificación) o `MockGameProvider` en Dart.

## Próximos pasos inmediatos

1. `flutter create` dentro de `flutter/` (o renombrar según se acuerde con el equipo).
2. Agregar dependencias a pubspec.yaml.
3. Crear estructura de carpetas lib/.
4. Implementar modelos base (Task, Attack, GameSession).

## Log de sesiones

### 2026-08-27
- Leído README.md y docs/FLUTTER_TABLET_ESPECIFICACION.md para contexto completo.
- Creados CLAUDE.md y PROGRESS.md para persistir contexto entre conversaciones.
- Confirmado: carpeta real del proyecto Flutter es `flutter/` (vacía), no `tablet/` como dice el README raíz.
