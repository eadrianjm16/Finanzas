# Estado de Finanzas — resumen para retomar el trabajo

Última actualización: commit `b817340` en `claude/xdode-instalado-tsfu95`.

App iOS (SwiftUI + SwiftData, iOS 17 mínimo, generada con XcodeGen desde
`project.yml`) que conecta con bancos reales vía Enable Banking (PSD2/Open
Banking) y replica funcionalidades de Fintonic. Uso estrictamente personal.

## Arquitectura de datos

`BankConnection` (una entidad bancaria, p. ej. "Banco Santander") tiene N
`LinkedAccount` (cada cuenta/producto individual dentro de ese banco).
Cada `LinkedAccount` tiene N `Transaction`. Cada `Transaction` apunta
opcionalmente a una `Category`. `Budget` guarda un límite mensual por
`categoryName` (unión por string, no por relación).

- `Sources/Persistence/Models.swift` — los 5 `@Model`: `BankConnection`,
  `LinkedAccount`, `Transaction`, `Category`, `Budget`.
- `Sources/App/PersistenceController.swift` — arma el `ModelContainer`.
- `Sources/Networking/` — cliente de Enable Banking (`EnableBankingClient`,
  `JWTSigner`, `DERReader` para firmar peticiones con la clave privada).
- `Sources/Persistence/AccountsStore.swift` / `TransactionsStore.swift` —
  sincronizan datos reales del banco hacia SwiftData.
- `Sources/Categorization/CategorizationEngine.swift` — categoriza
  automáticamente por código MCC + palabras clave en el texto del movimiento.
- `Sources/Alerts/AlertsEngine.swift` — genera alertas en vivo (sin backend).
- `Sources/Analysis/InternalTransferDetector.swift` — detecta traspasos
  entre cuentas propias.

## Pestañas de la app

### Cuentas
Lista plana con saldo total agregado arriba, agrupada por banco (cabecera =
banco + saldo, filas = cuentas individuales con últimos dígitos del IBAN
para diferenciarlas). Tocar una entidad abre el detalle con toggles
"Ver mi cuenta" / "Ver saldo" por cuenta, botón actualizar, y "Eliminar
entidad" (borra todo el historial). Botón "+" abre el buscador de bancos
(2.700+ vía Enable Banking) para conectar uno nuevo.

### Movimientos
Agrupado por día (cabeceras "VIERNES 31 DE JULIO 2026"), orden
descendente. Cada fila muestra categoría asignada y botón "Recategorizar"
visible (además del menú contextual de siempre). Excluye movimientos de
cuentas marcadas como ocultas.

### Análisis (nueva, estilo Fintonic)
Gráfico de barras Ingresos/Gastos de los últimos 6 meses (Swift Charts),
navegación mes a mes con flechas, totales + Neto, "% de presupuesto
previsto" (suma de todos los `Budget` fijados), segmentado
Ingresos/Gastos/**No computable**, gráfico de dona por categoría, y al
tocar una categoría se abre su propio historial mensual + movimientos.

### Presupuestos
Límite mensual por categoría con barra de progreso contra el gasto real
del mes. Tocar una categoría abre un sheet para fijar/editar el límite.

### Alertas
Calculadas en vivo cada vez que se abre la pestaña (sin backend/push
real): umbral de presupuesto (≥80%), posibles cargos duplicados (mismo
importe+comercio en ≤3 días, excluyendo Suscripciones), y comisiones
bancarias detectadas.

### Ajustes → Categorías
CRUD completo: crear categoría propia (nombre + ícono de una paleta de
~25 SF Symbols), editar nombre/ícono de cualquiera (incluidas las 12 por
defecto), borrar (reasigna sus movimientos a "Otros" y borra el
`Budget` asociado si tenía), reordenar (pantalla dedicada con
drag-handles).

Con 6 pestañas totales, iOS solo muestra 4 directas (Cuentas,
Movimientos, Análisis, Presupuestos) — Alertas y Ajustes viven bajo el
ítem "Más" que genera el sistema automáticamente.

## Integración bancaria — detalles que importan

- **Enable Banking en modo "Restricted Production"**: solo se puede
  acceder a las cuentas específicamente whitelisteadas en su Control
  Panel. Ahora mismo: 3 cuentas de Santander + 1 de ING.
- **Tarjetas de crédito y "Cuenta naranja" de ING no son accesibles**:
  confirmado que ni Santander ni ING las exponen vía su propia pantalla
  de consentimiento PSD2 — no es arreglable desde nuestro lado ni desde
  Enable Banking, es decisión de cada banco.
- Redirect de autorización: HTTPS puente en GitHub Pages
  (`docs/callback.html`, servido en
  `https://eadrianjm16.github.io/Finanzas/callback.html`) que rebota a
  `finanzasapp://callback` para que `ASWebAuthenticationSession` lo
  capture.
- Credenciales en `Sources/Secrets/Secrets.plist` (gitignored, nunca se
  sube). `session_id` por cuenta en Keychain
  (`Sources/Session/BankSessionStore.swift`).

## Bugs reales encontrados y arreglados esta sesión

1. `ASWebAuthenticationSession` no se retenía → se colgaba de forma
   intermitente (arreglado reteniéndola en una propiedad).
2. Al fallar la conexión de un banco nuevo, la app volvía a onboarding
   aunque ya hubiera otras cuentas conectadas — parecía "reiniciarse".
3. `refreshBalance` pisaba `lastSyncedAt` (el checkpoint de sincronización
   de movimientos), causando que el primer sync de transacciones
   siempre trajera una ventana vacía.
4. Reautorizar un banco ya conectado duplicaba la cuenta en vez de
   actualizarla.
5. Faltaba pedir explícitamente el scope `transactions: true` en el
   consentimiento — por eso Movimientos salía vacío la primera vez.
6. `PersistenceController` omitía `BankConnection.self` del `Schema`
   (funcionaba de casualidad por descubrimiento transitivo de SwiftData;
   ya corregido explícitamente).
7. Los botones de navegación de mes en Análisis tenían un área táctil
   minúscula (solo el glyph, sin padding) — imposible de tocar en un
   dispositivo real. Corregido con `.frame(44, 44)`.

## Limitaciones conocidas (documentadas a propósito, no arregladas)

- **"No computable"** es heurístico (empareja cargo+abono de igual
  importe entre cuentas propias en ≤3 días) — puede dar falsos
  positivos/negativos con pagos externos coincidentes.
- **Renombrar o borrar una categoría por defecto** rompe silenciosamente
  las reglas de `CategorizationEngine`/`AlertsEngine` que la referencian
  por nombre literal (p. ej. si renombras "Comisiones bancarias", esa
  regla deja de encontrar coincidencia). No hay UI para remapear reglas.
- **Sin pestaña "Productos"** (agrupar cuentas por tipo en vez de por
  banco) ni **carrusel de tarjetas del home** — vistos en las capturas
  de Fintonic pero descartados explícitamente por alcance.
- **Sin notificaciones push reales** — todo se recalcula al abrir la
  app, no hay `BGAppRefreshTask` ni servidor.
- **Sin tests automatizados** en todo el proyecto.
- Varios `try?` silenciosos en las capas de sync (fallos de red no
  siempre se muestran al usuario, solo se registran como "no se pudo
  refrescar esta vez").

## Qué mejorar / hacer después (sugerencias, sin priorizar)

- Ampliar la tabla de palabras clave de `CategorizationEngine` con más
  comercios reales a medida que aparezcan en "Otros".
- Botón de "recalcular categorías" para volver a pasar el motor sobre
  movimientos ya existentes tras mejorar las reglas (hoy solo categoriza
  al insertar, nunca retroactivamente).
- Mejorar la fiabilidad de "No computable" comparando también el nombre
  de la contraparte, no solo importe+fecha.
- `BGAppRefreshTask` + notificaciones locales para que Alertas avise sin
  tener que abrir la app.
- Tests unitarios de los motores puros (`CategorizationEngine`,
  `AlertsEngine`, `InternalTransferDetector`, `MonthRange`) — son
  funciones sin estado, fáciles de testear sin UI.
- Revisar si vale la pena la pestaña "Productos"/carrusel del home.
- Whitelistear más cuentas en Enable Banking si se conectan más bancos.

## Nota sobre verificación en este proyecto

Este entorno de automatización del simulador tiene dificultades
consistentes para interactuar con: contenido dentro de `.sheet()`,
`Menu`, y controles pequeños dentro de `List`/toolbars — los taps
sintéticos no siempre registran aunque el código sea correcto y estándar.
Varias veces esto resultó ser puntería de la herramienta, pero **una vez
fue un bug real** (botones sin área táctil mínima). Conclusión práctica:
cuando algo "no responde al toque", vale la pena que el usuario lo
confirme en persona antes de asumir que es solo la herramienta.
