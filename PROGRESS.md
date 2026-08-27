# PROGRESS.md — Avance Tablet (Flutter)

Registro de avance del componente Tablet. Actualizar tras cada sesión/tarea completada. Ver `CLAUDE.md` para contexto general del proyecto.

## Estado actual

**Fase:** Esqueleto funcional completo — sin minijuegos reales aún (placeholders).
**Última actualización:** 2026-08-27

Proyecto Flutter creado en `flutter/` (paquete `fn_attention_defense_tablet`). Flujo completo Splash → Game → GameOver funciona end-to-end contra `MockServerService` (sin backend real todavía). Verificado corriendo en Linux desktop: conecta, recibe tareas simuladas, recibe ataques simulados, vida baja, transiciona a Game Over al llegar a 0, pantalla de reintento se renderiza correctamente.

## Checklist (según cronograma de 3 semanas de la especificación)

### Semana 1: Setup + Mini-juegos básicos
- [x] Instalar Flutter SDK (ya estaba instalado: 3.44.5)
- [x] Crear proyecto Flutter base (`flutter create`)
- [x] Estructurar carpetas (lib/models, screens, widgets, services, providers, utils, config)
- [x] Agregar dependencias en pubspec.yaml (web_socket_channel, provider, flutter_local_notifications, vibration, flutter_svg, lottie, logger, shared_preferences)
- [x] Commit inicial
- [x] Modelos: Task, Attack, GameSession
- [x] Pantalla splash/inicio
- [x] ConnectionProvider
- [x] WebSocketService + testing de conexión (contra mock; backend real pendiente)
- [x] GameProvider
- [ ] Mini-juego 1: Conectar Cables (placeholder genérico implementado, minijuego real pendiente)
- [ ] Mini-juego 2: Girar Perillas (placeholder genérico implementado, minijuego real pendiente)

### Semana 2: Más mini-juegos + feedback
- [ ] Mini-juego 3: Resolver Secuencias
- [ ] Mini-juego 4: Ritmo Crítico
- [ ] Feedback háptico (vibración)
- [ ] Sonidos (alarma, acierto, error)
- [ ] NotificationService
- [x] StatusBar widget (estado conexión, vida, timer)
- [x] GameScreen principal integrando mini-juegos (usa placeholders por ahora)
- [x] GameOverScreen

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

- Esqueleto implementado vía Subagent-Driven Development (8 tareas, plan en `docs/superpowers/plans/2026-08-27-flutter-tablet-skeleton.md`), en rama `flutter-tablet-skeleton`.
- Paquete Flutter: `fn_attention_defense_tablet`, org `com.ucsp.fnaf`.
- `ServerConfig.useMock = true` por defecto — no hay backend Python real todavía. `MockServerService` simula `new_task`/`attack` con timers.
- `PlaceholderGameWidget` genérico reemplaza a los 4 minijuegos reales por ahora (botones "Completar (simulado)" / "Fallar (simulado)").
- Fix aplicado tras revisión: `GameProvider.reset()` se llama en "Reintentar" (GameOverScreen) — sin esto, el estado del juego persistía entre reintentos y causaba un bucle de vuelta a Game Over.

## Bloqueos / dependencias del equipo

- Necesito del compañero de Backend (Python): IP:puerto real del servidor WebSocket, confirmación del formato JSON exacto (ya especificado en `docs/FLUTTER_TABLET_ESPECIFICACION.md`, pero pendiente validar en la práctica).
- Mientras no haya backend real, usar mock server (`test_server.py` de referencia en la especificación) o `MockGameProvider` en Dart.

## Próximos pasos inmediatos

1. Fusionar rama `flutter-tablet-skeleton` a `main` (pendiente revisión final de rama completa).
2. Implementar Mini-juego 1 (Cables) reemplazando `PlaceholderGameWidget` en ese caso.
3. Implementar Mini-juego 2 (Perillas).
4. Feedback háptico/sonido real vía `NotificationService`.

## Log de sesiones

### 2026-08-27
- Leído README.md y docs/FLUTTER_TABLET_ESPECIFICACION.md para contexto completo.
- Creados CLAUDE.md y PROGRESS.md para persistir contexto entre conversaciones.
- Confirmado: carpeta real del proyecto Flutter es `flutter/` (vacía), no `tablet/` como dice el README raíz.
- Diseño y plan de esqueleto Flutter escritos y aprobados (brainstorming + writing-plans skills).
- Esqueleto Flutter implementado con Subagent-Driven Development: proyecto creado, modelos, config/utils, WebSocketService + MockServerService, ConnectionProvider + GameProvider, widgets compartidos (HealthBar, StatusBar, PlaceholderGameWidget), pantallas (Splash, Game, GameOver) y main.dart. 7 tareas de implementación, todas revisadas y aprobadas; 1 fix aplicado (retry-loop bug en GameProvider) y re-verificado.
- Verificación manual (Task 8): app compilada y corrida en Linux desktop (`flutter run -d linux`). Confirmado por logs + captura de pantalla: conecta vía mock, ciclo de tareas simuladas, ataques bajan la vida, transición automática a pantalla "JUEGO TERMINADO" con estadísticas y botón "Reintentar" — todo el flujo funciona sin excepciones no manejadas.
