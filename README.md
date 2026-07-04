# AI Translate — klawiatura AI do tłumaczenia (iOS, Swift/SwiftUI)

Natywna aplikacja iOS z **własną klawiaturą systemową (Custom Keyboard
Extension)**, która tłumaczy wiadomości bezpośrednio w WhatsAppie, Messengerze,
Mailu i innych aplikacjach — przez **Anthropic API (Claude Haiku)**.

Główny scenariusz: kopiujesz wiadomość rozmówcy w WhatsApp → przełączasz się na
klawiaturę „AI Translate" → tłumaczenie po polsku pojawia się **od razu** (klawiatura
wykrywa nowo skopiowany tekst, gdy jest aktywna — bez dodatkowego dotknięcia).
Odpowiadasz: wracasz globusem 🌐 do zwykłej klawiatury, piszesz albo **dyktujesz**
(wbudowany mikrofon Apple) odpowiedź po polsku wprost w WhatsAppie → wracasz na
„AI Translate" → **„Odbierz z WhatsApp"** czyta ten szkic, poprawia go i tłumaczy,
po czym podmienia w polu wiadomości. Wysyłasz sam.

> Zgodnie z ograniczeniami iOS **nie** ma pływającej nakładki nad WhatsAppem —
> App Store na to nie pozwala. Zamiast tego działa systemowa klawiatura, którą
> włączasz raz w Ustawieniach. Nie używamy żadnych prywatnych API Apple.
>
> **Dlaczego nie ma mikrofonu w samej klawiaturze:** to twardy sandbox iOS —
> żadna klawiatura systemowa (nawet Gboard) nie ma dostępu do mikrofonu. Dlatego
> dyktowanie idzie przez wbudowaną dyktafon-klawiaturę Apple w polu WhatsAppa, a
> nasza klawiatura tylko odczytuje i poprawia to, co tam wylądowało.

---

## 1. Które pliki powstały

```
AITranslate.xcodeproj/            ← projekt Xcode (2 targety), gotowy do otwarcia
project.yml                       ← alternatywny sposób generowania projektu (XcodeGen)

Shared/                           ← kod współdzielony przez appkę i klawiaturę
  AppGroup.swift                  ← identyfikatory + wspólne UserDefaults (App Group)
  AppGroupSettings.swift          ← konfiguracja (klucz API, model, kierunek, historia)
  TranslationModels.swift         ← enumy: kierunek, model Claude, błędy, rekord historii
  TranslationService.swift        ← ⭐ warstwa tłumaczenia: Anthropic API + mock deweloperski
  Theme.swift                     ← wspólny ciemny motyw

AITranslate/                      ← target: aplikacja główna (SwiftUI)
  AITranslateApp.swift            ← punkt wejścia
  RootView.swift                  ← zakładki: Start / Test / Ustawienia
  OnboardingView.swift            ← instrukcja włączenia klawiatury i użycia w WhatsApp
  SettingsView.swift              ← klucz API, Backend URL, wybór modelu, kierunek, historia, mock
  TestTranslateView.swift         ← ekran testowy — tłumaczenie bez WhatsAppa
  PrivacyView.swift               ← polityka prywatności w aplikacji
  HistoryView.swift               ← historia tłumaczeń (domyślnie wyłączona)
  Info.plist, AITranslate.entitlements, Assets.xcassets

KeyboardExtension/                ← target: klawiatura systemowa
  KeyboardViewController.swift    ← UIInputViewController: hostuje SwiftUI, globus, schowek, insert
  KeyboardViewModel.swift         ← logika panelu (paste / tłumacz / wstaw), obsługa błędów
  KeyboardView.swift              ← kompaktowy panel UI dopasowany do wysokości klawiatury
  Info.plist                      ← konfiguracja NSExtension + RequestsOpenAccess (pełny dostęp)
  KeyboardExtension.entitlements
```

Podział odpowiedzialności jest czysty: **UI** (SwiftUI views), **TranslationService**
(warstwa API), **AppGroupSettings** (konfiguracja), **KeyboardViewController**
(most UIKit ↔ SwiftUI).

---

## 2. Jak uruchomić projekt

> Budowa klawiatury systemowej iOS **wymaga komputera Mac z Xcode** — nie da się
> tego zbudować na Windowsie/Linuxie ani w chmurze. To ograniczenie Apple, nie
> tego projektu.

1. Skopiuj repozytorium na Maca z zainstalowanym **Xcode 15+**.
2. Otwórz `AITranslate.xcodeproj` (podwójne kliknięcie).
3. Zaznacz projekt **AITranslate** → target **AITranslate** → zakładka
   *Signing & Capabilities* → wybierz swój **Team** (darmowe Apple ID
   wystarczy do uruchomienia na własnym telefonie). To samo dla targetu
   **KeyboardExtension**.
4. Jeśli Xcode poprosi, zmień prefiks bundle id z `com.redmal` na własny
   (musi być unikalny). Zmień go w obu targetach oraz w App Group
   `group.com.redmal.aitranslate` (w plikach `*.entitlements` i w
   `Shared/AppGroup.swift`).
5. Wybierz swój iPhone jako urządzenie docelowe i naciśnij **Run (⌘R)**.

**Alternatywa — XcodeGen** (gdyby `.xcodeproj` sprawiał problemy): projekt jest
też opisany deklaratywnie w `project.yml`. Zainstaluj `brew install xcodegen`,
usuń `AITranslate.xcodeproj`, uruchom `xcodegen generate` i otwórz świeżo
wygenerowany projekt.

### „Bez kabli" — instalacja bezprzewodowa na telefon

Nie da się zbudować i podpisać aplikacji iOS bez Maca z Xcode — z tego środowiska
nie mogę wygenerować gotowego, podpisanego pliku do zainstalowania. Gdy masz już
Maca z Xcode, są dwie drogi bezkablowe:

- **Xcode Wireless:** raz podłącz iPhone kablem, w *Window → Devices and
  Simulators* zaznacz „Connect via network". Od tej chwili budujesz i wgrywasz
  na telefon po Wi‑Fi, bez kabla.
- **TestFlight (w pełni zdalnie):** wymaga płatnego konta Apple Developer
  (99 USD/rok). Wysyłasz build do App Store Connect, a na telefonie instalujesz
  z aplikacji TestFlight — bez żadnego kabla.

---

## 3. Jak dodać klawiaturę w Ustawieniach iPhone

1. **Ustawienia** → **Ogólne** → **Klawiatura** → **Klawiatury**.
2. **Dodaj nową klawiaturę…** → wybierz **AI Translate**.
3. Dotknij ponownie **AI Translate** na liście i włącz **Zezwól na pełny dostęp**.
   Jest wymagany, bo tłumaczenie AI łączy się z internetem (bez niego klawiatura
   pokaże komunikat „Włącz Pełny dostęp…").

Aplikacja główna ma zakładkę **Start** z tą samą instrukcją krok po kroku.

---

## 4. Jak przetestować w WhatsApp

1. Otwórz **WhatsApp**, wejdź w dowolną rozmowę.
2. Dotknij pola pisania wiadomości.
3. Przytrzymaj **globus 🌐** na klawiaturze i wybierz **AI Translate**.
4. **Odbieranie:** w WhatsApp przytrzymaj wiadomość rozmówcy → *Kopiuj*. Przełącz się
   na naszą klawiaturę (albo, jeśli już jest otwarta, poczekaj chwilę) — tłumaczenie
   po polsku pojawi się **automatycznie**, bez dodatkowego dotknięcia „Wklej".
5. **Odpowiadanie:** dotknij globusa, żeby wrócić do zwykłej klawiatury, napisz albo
   **podyktuj** (mikrofon Apple) odpowiedź po polsku wprost w polu WhatsAppa. Wróć na
   **AI Translate** → dotknij **„Odbierz z WhatsApp"**. Klawiatura poprawi styl,
   przetłumaczy i podmieni szkic na gotowy tekst w języku rozmówcy. **Wyślij sam.**

Możesz też przetestować całość bez WhatsAppa — zakładka **Test** w aplikacji
głównej używa dokładnie tej samej warstwy tłumaczenia.

> Klawiatura nie czyta całej rozmowy, nie klika „wyślij" i czyta schowek dopiero
> po dotknięciu przycisku — nigdy automatycznie.

---

## 5. Gdzie podpiąć prawdziwe API tłumaczenia

Całość jest już przygotowana pod **Anthropic API** i model **Claude Haiku**
(szybki i tani — idealny do klawiatury). Wystarczy podać klucz:

1. Uruchom aplikację → zakładka **Ustawienia** → wklej **Anthropic API Key**
   (`sk-ant-…`). Zapisuje się w App Group, więc klawiatura go odczyta.
2. (Opcjonalnie) **Model:** domyślnie Claude Haiku (`claude-haiku-4-5`); można
   przełączyć na Sonnet (`claude-sonnet-5`) lub Opus (`claude-opus-4-8`).
3. (Opcjonalnie) **Backend URL** — jeśli podasz własny adres, zapytania pójdą
   tam zamiast bezpośrednio do `api.anthropic.com` (przydatne, gdy nie chcesz
   trzymać klucza na urządzeniu i wolisz własny serwer‑proxy).

Kod, który to robi, jest w **`Shared/TranslationService.swift`**:

- `AnthropicTranslationService` woła `POST https://api.anthropic.com/v1/messages`
  z nagłówkami `x-api-key` i `anthropic-version: 2023-06-01`,
  `temperature: 0.2`, krótkim `max_tokens` (800) i timeoutem ~12 s.
- Prompty modelu są w `TranslationPrompt` (tłumaczenie wiadomości na polski,
  tłumaczenie odpowiedzi na naturalny angielski, tryb Auto z wykrywaniem języka).
- `MockTranslationService` to **tryb deweloperski** (sztuczne tłumaczenie, bez
  sieci) — włączany przełącznikiem w Ustawieniach, nie jest ścieżką produkcyjną.

Aby wpiąć własny backend, zaimplementuj protokół `TranslationService` (cztery
metody) i zwróć swoją instancję w `TranslationServiceFactory.make(settings:)`.

### Obsługa błędów (komunikaty po polsku)
- brak internetu → „Brak połączenia"
- brak pełnego dostępu klawiatury → „Włącz Pełny dostęp w ustawieniach iPhone…"
- pusty schowek → „Najpierw skopiuj wiadomość z WhatsAppa"
- błąd API → krótki komunikat z możliwością ponowienia

### Prywatność
- Teksty idą do API tylko wtedy, gdy klawiatura AI Translate jest aktywna i Ty (lub
  automatyczne wykrycie skopiowanej wiadomości, działające tylko przy otwartej
  klawiaturze) inicjujecie tłumaczenie. Nic nie dzieje się, gdy klawiatura jest schowana.
- Schowek jest sprawdzany tylko wtedy, gdy nasza klawiatura jest widoczna na ekranie.
- Klawiatura nie odczytuje całej rozmowy z WhatsAppa — tylko to, co skopiujesz, oraz
  (przez „Odbierz z WhatsApp") aktualny szkic w polu wiadomości.
- Klawiatura nie ma dostępu do mikrofonu (twarde ograniczenie iOS) — dyktowanie idzie
  przez systemową klawiaturę Apple wprost w polu WhatsAppa.
- Historia tłumaczeń **domyślnie wyłączona**; po włączeniu zapisywana tylko lokalnie.
- Pełne treści wiadomości nie są logowane w konsoli.

---

## Konfiguracja tożsamości (do zmiany na własną)

| Element | Wartość domyślna |
|---|---|
| Bundle ID aplikacji | `com.redmal.aitranslate` |
| Bundle ID klawiatury | `com.redmal.aitranslate.keyboard` |
| App Group | `group.com.redmal.aitranslate` |
| Minimalny iOS | 16.0 |

Zmieniając prefiks, zaktualizuj: oba targety w Xcode (*Signing & Capabilities*),
pliki `AITranslate/AITranslate.entitlements`,
`KeyboardExtension/KeyboardExtension.entitlements` oraz stałą `AppGroup.identifier`
w `Shared/AppGroup.swift`.
