# Honeycomb Card Suite :honeybee: :honey_pot:

Seis juegos de cartas, cuatro plataformas, un motor de reglas compartido y un sistema de personalización profundo. Incluye un juego de batalla de cartas al estilo Triple Triad (Honeycomb) más Klondike, Freecell, Spider, Video Poker y Blackjack.

**▶ [Juega en itch.io](https://playhoneycomb.itch.io/honeycomb-card-suite)** · [English](README.md)

---

## 🛠️ Tecnología

| Plataforma | Lenguaje | Interfaz | Notas |
|---|---|---|---|
| macOS | Swift 6 | SwiftUI | macOS 14+, con pruebas unitarias, versiones publicadas con CI |
| iOS | Swift 6 | SwiftUI | iOS 17+, comparte la lógica de juego con macOS, compilación y prueba rápida con CI |
| Windows | C# (.NET 10) | Avalonia | Versiones firmadas con CI |
| Android | Kotlin | Jetpack Compose | minSdk 26 |

* **Núcleo compartido**: macOS e iOS usan la misma lógica de juego en Swift (`shared/`). Las versiones de Windows y Android la replican a mano.
* **Localización**: las cadenas en inglés y español viven en una sola hoja de cálculo (`tools/`) que genera los archivos de cadenas de cada plataforma.
* **Pruebas y CI**: los flujos de GitHub Actions compilan macOS, Windows e iOS, con pruebas unitarias del estado de juego, la puntuación, la lógica de casino y la base de datos de cartas de Honeycomb.
* **Cómo se hizo**: desarrollo guiado por especificaciones con SpecKit y Claude Code. No se usa arte generado por IA. Todo el arte se usa con permiso, con agradecimiento especial a los amigos que contribuyeron y desean permanecer sin acreditar.
* **Licencia**: [PolyForm Noncommercial 1.0.0](LICENSE). Libre para usar, copiar y modificar con fines no comerciales.

---

## 🎨 Haz que el juego sea tuyo

Cambia los mazos y el arte de las cartas por tus propias imágenes. Combina el color del fieltro y de las cartas, y guárdalo como un tema personalizado completo. Crea tu propio modo oscuro. **Haz que el juego sea tuyo.**

---

## ♠️ Modos de juego

> **Nota sobre plataformas:** En iOS y Android, Video Poker y Blackjack son solo de juego libre (sin apuestas ni créditos), y Klondike no tiene el modo de puntuación Vegas.

Las descripciones completas de cada juego y las capturas de pantalla están en el [README en inglés](README.md).

---

## ♦️ Primeros pasos

* [README de macOS](mac/README.md)
* [README de Windows](windows/README.md)
* **iOS**: `cd ios && xcodegen generate`, y luego abre `Honeycomb.xcodeproj` en Xcode (iOS 17+).
* **Android**: `cd android && ./gradlew assembleDebug` (minSdk 26).
