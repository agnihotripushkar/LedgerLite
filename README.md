# LedgerLite 💼

LedgerLite is a premium, cross-platform personal finance and expense tracker built with **Flutter**. Secure, private, and fully local, it helps you monitor your net balance, visualize cash flows, and manage daily transactions across **Mobile, Tablet, and Desktop** devices.

---

## ✨ Features

*   **📊 Interactive Data Visualizations**: Beautiful, interactive pie charts for category-wise spending and dual-bar charts for monthly income vs. expense trends (powered by `fl_chart`).
*   **🔒 Biometric Security**: Secure app access on startup with biometrics (Face ID, Fingerprint) or device passcodes using `local_auth`.
*   **📂 Data Portability**: Export your transaction ledger to portable CSV spreadsheets with one click.
*   **🔍 Power Filtering & Search**: Instant, reactive search through transaction descriptions or categories with granular type (Income vs. Expense) and category filters.
*   **🖥️ Responsive & Adaptive Layout**: Fluid transition between bottom navigation for mobile screens and a custom navigation rail/drawer for tablets and desktop displays.
*   **🎨 Premium Material 3 Design**: Fully automated system-synced Dark/Light modes, elegant glassmorphic card borders, custom HSL-tailored colors, and the modern **Outfit** font by Google Fonts.
*   **💾 Offline-First SQLite Storage**: Ultra-fast, reactive query performance utilizing the type-safe Drift SQLite database engine.

---

## 🛠️ Tech Stack & Architecture

LedgerLite uses a robust and scalable architecture to ensure high performance and code maintainability:

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Core Framework** | [Flutter SDK](https://flutter.dev) (Dart 3.x) | Cross-platform UI compilation for iOS, Android, macOS, Windows, Linux, and Web. |
| **State Management** | [flutter_bloc](https://pub.dev/packages/flutter_bloc) | Predictable, event-driven state flow separating UI components from business logic. |
| **Local Database** | [Drift](https://drift.simonbinder.eu/) (SQLite) | Reactive database queries, automatic migrations, type-safe schema, and table joins. |
| **Routing & Navigation** | [go_router](https://pub.dev/packages/go_router) | Declarative, URL-driven routing system supporting nested navigation (ShellRoute) and auth-redirect guards. |
| **Data Visualization** | [fl_chart](https://pub.dev/packages/fl_chart) | Responsive line, bar, and pie charts. |
| **Biometric Auth** | [local_auth](https://pub.dev/packages/local_auth) | Local platform-native security integration. |
| **Data Export** | [csv](https://pub.dev/packages/csv) & [path_provider](https://pub.dev/packages/path_provider) | Compiling text files into standard formatting and saving to device storage. |
| **Typography** | [google_fonts](https://pub.dev/packages/google_fonts) | Modern styling. |
| **Testing Suite** | `flutter_test`, `bloc_test`, `mocktail` | Comprehensive unit, bloc, and database verification testing. |

### Directory Structure

```text
lib/
├── blocs/                # State Management (BLoCs)
│   ├── analytics/        # Business logic for graph computation & filtering
│   ├── auth/             # App locking & biometric verification logic
│   ├── category/         # Available income/expense category streams
│   └── transaction/      # CRUD transaction commands
├── data/
│   └── database/         # Drift SQLite schema definition & data access layers
├── features/             # Feature-specific screens & local widgets
│   ├── analytics/        # Analytics & trend graphs screen
│   ├── dashboard/        # Main overview card, balance cards, & transaction creator
│   ├── lock/             # Biometric lock shield page
│   ├── settings/         # App configs, CSV exporter, and DB controls
│   └── transactions/     # Advanced searchable ledger list
├── routing/              # Declared paths and router guards
└── widgets/              # Shared cross-feature custom widgets
```

---

## 🚀 Getting Started

Follow these steps to set up and run LedgerLite locally on your system.

### Prerequisites

*   Install the **Flutter SDK** (Version 3.11.0 or higher recommended). Verify installation using:
    ```bash
    flutter doctor
    ```

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/yourusername/LedgerLite.git
    cd LedgerLite
    ```

2.  **Fetch Flutter packages**:
    ```bash
    flutter pub get
    ```

3.  **Generate SQLite Database Classes**:
    Drift uses source-code generation to compile database schemas. Run the build runner utility:
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

### Run the App

Launch the application on your connected mobile device or desktop simulator:
```bash
flutter run
```

---

## 🧪 Testing

LedgerLite comes with a comprehensive suite of unit and BLoC verification tests. Tests cover in-memory SQLite schema operations, category loading, CSV exporting, transaction database resets, and biometric locking logic.

To run the test suite:
```bash
flutter test
```
