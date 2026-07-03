# Research Report: Windows Desktop Port Architecture

This report evaluates and details the architectural decisions for porting the SoliBee Solitaire suite to the Windows desktop platform.

## 1. UI Presentation Framework

- **Decision**: WinUI 3 (Windows App SDK)
- **Rationale**: 
  - Native performance with fluent UI controls matching the modern Windows 11 desktop theme.
  - Full support for hardware-accelerated Vector rendering (`Canvas` / Win2D integration) needed to programmatic UI card drawing.
  - Better integration with the Windows Composition layer for high-performance animations (like the victory bouncing cascade).
- **Alternatives Considered**:
  - **WPF (.NET 8)**: Mature and very stable, but uses legacy rendering and styling defaults. Discarded in favor of the modern WinUI 3 presentation layer.
  - **MAUI**: Good for cross-platform, but adds overhead that is unnecessary for a Windows-only desktop target.

## 2. MVVM Framework

- **Decision**: `CommunityToolkit.Mvvm` (.NET Community Toolkit)
- **Rationale**: 
  - Industry-standard MVVM framework officially supported by Microsoft.
  - Source generators simplify boilerplate code (`[ObservableProperty]`, `[RelayCommand]`), making it compile-time safe and highly performant.
  - Decoupled from the UI, matching our core model logic architecture.
- **Alternatives Considered**:
  - **Prism**: Heavy and opinionated, better suited for massive enterprise applications.
  - **ReactiveUI**: Powerfully reactive but introduces a steeper learning curve and runtime overhead compared to simple Source Generator commands.

## 3. Audio & Sound Playback

- **Decision**: Native `MediaElement` or `MediaPlayer` APIs
- **Rationale**: 
  - Low latency execution with volume controls integrated directly into Windows.
  - Supports asynchronous triggering without locking the VM/main rendering thread.
- **Alternatives Considered**:
  - **DirectX XAudio2**: Provides absolute minimum latency, but requires complex C++ interop. The standard WinRT `MediaPlayer` is sufficient for simple WAV assets.

## 4. Victory Cascade Animation

- **Decision**: Win2D Canvas / Composition API
- **Rationale**:
  - Direct access to hardware-accelerated rendering.
  - Can calculate hundreds of card coordinates and draw vector geometries at 60 FPS without overloading the CPU.
- **Alternatives Considered**:
  - **XAML Canvas UI elements**: Spawning hundreds of UI shapes as separate visual elements in the XAML tree degrades layout and render pass speed.
