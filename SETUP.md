# Finanzas — configuración local

App iOS (SwiftUI) de uso personal que conecta con Banco Santander vía
[Enable Banking](https://enablebanking.com) (PSD2/open banking) y muestra el
saldo de la cuenta. Sin presupuestos, categorías ni gráficos todavía — solo
login → autorización bancaria → saldo.

## 1. Requisitos

- Xcode (instalado vía App Store) con un simulador de iOS 16+.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Cuenta de desarrollador en Enable Banking, con:
  - Un `application_id` (UUID).
  - Una clave privada (PEM) generada al registrar la app.
  - El **redirect URL `https://eadrianjm16.github.io/Finanzas/callback.html`**
    dado de alta en el panel de Enable Banking para tu aplicación. Enable
    Banking exige un redirect HTTPS (no acepta esquemas custom directamente),
    así que esa página estática en GitHub Pages actúa de puente: recibe la
    respuesta del banco y rebota inmediatamente a `finanzasapp://callback`,
    que sí abre la app. El HTML de esa página vive en `docs/callback.html`
    en esta misma rama (GitHub Pages debe estar configurado para servir la
    carpeta `/docs`).

## 2. Credenciales (nunca se suben a git)

```bash
cp Sources/Secrets/Secrets.example.plist Sources/Secrets/Secrets.plist
```

Edita `Sources/Secrets/Secrets.plist` y rellena:

- `EnableBankingApplicationID`: tu application_id.
- `EnableBankingPrivateKeyPEM`: el contenido completo del `.pem` que te dio
  Enable Banking (con las líneas `-----BEGIN...-----`/`-----END...-----`
  incluidas).

`Secrets.plist` está en `.gitignore` — no se versiona. `Secrets.example.plist`
sí, como plantilla.

## 3. Generar y abrir el proyecto

```bash
xcodegen generate
open Finanzas.xcodeproj
```

(`xcodegen generate` hay que volver a ejecutarlo cada vez que añadas/quites
archivos fuente o cambies `project.yml` — el `.xcodeproj` no se versiona,
se regenera siempre desde `project.yml`.)

## 4. Probar en el simulador

1. En Xcode, selecciona el esquema **Finanzas** y un simulador (p. ej. iPhone 15).
2. Cmd+R para compilar y ejecutar.
3. En la app, toca **"Conectar con Banco Santander"**.
4. Se abre una hoja de navegador del sistema con el flujo de autorización
   del banco (SCA). Inicia sesión con tus credenciales reales de Santander
   (o las de sandbox si Enable Banking te las ofrece para pruebas).
5. Tras autorizar, Enable Banking redirige a
   `https://eadrianjm16.github.io/Finanzas/callback.html?code=...`, esa
   página rebota a `finanzasapp://callback?code=...`, y la app captura el
   código automáticamente, crea la sesión con Enable Banking y pide el
   saldo de la primera cuenta devuelta.
6. Deberías ver el saldo en pantalla. "Desconectar" borra la sesión guardada
   (Keychain) y vuelve a la pantalla inicial.

## 5. Solución de problemas

- **Crash al arrancar con mensaje sobre `Secrets.plist`**: falta el paso 2,
  o falta volver a correr `xcodegen generate` después de crear el archivo.
- **"No se pudo importar la clave privada"**: revisa que pegaste el PEM
  completo tal cual, sin editar saltos de línea.
- **El banco no encuentra el redirect / da error de redirect_url inválida**:
  confirma en el panel de Enable Banking que
  `https://eadrianjm16.github.io/Finanzas/callback.html` está dado de alta
  exactamente así para tu aplicación, y que GitHub Pages está sirviendo
  `docs/callback.html` en esa URL (puede tardar unos minutos tras el primer
  push en activarse).
- **"No se encontró ningún banco que coincida con santander"**: el mensaje
  de error ahora lista los bancos disponibles que devolvió Enable Banking;
  ajusta el término de búsqueda en `AppState.connectBank()`
  (`client.findASPSP(matching: "santander", ...)`) según ese listado.
