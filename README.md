# Safe to Spend

A privacy-first expense tracker built with Flutter — every rupee is calculated on-device, and an on-device Naive Bayes classifier learns your spending categories from your own history.

**No account. No cloud. No cost. No API keys.**

## What it does

- **Safe to Spend** — one number that matters: your balance minus all upcoming recurring obligations (configurable look-ahead horizon: 1 week → 2 months)
- **Plain-English logging** — type "spent 250 on biryani" or "biryani order 300" and it's logged with the right category, instantly, offline
- **Sage, the AI assistant** — full natural-language control: budgets ("set food budget to 3000"), goals ("start a 25000 phone goal"), warnings ("warn me when I spend over 1500 on shopping"), affordability checks, undo, insights
- **AI Insights** — trends, category breakdowns, anomaly detection (spending spikes vs your category average), month-end forecast
- **CSV export/restore** — clipboard-based, duplicate-safe, works on every platform
- **Budget guard** — warns at 80% of any budget and again when you cross it

## The AI/ML inside

### 1. On-device Naive Bayes category classifier
The centerpiece. A multinomial Naive Bayes text classifier (Laplace add-one smoothing) trains **on your own transaction history** — it counts word probabilities per category and improves with every entry.

- Unseen words are handled honestly: when the model has no evidence (zero vocabulary coverage), it abstains to "other" instead of guessing
- Confidence = blend of category-margin (log-probability gap between best and second-best) and vocabulary coverage, dampened on out-of-vocabulary input
- **Teach it**: say "kebab was food" and the model learns — corrections persist across restarts and are weighted 3×
- Hybrid design: a deterministic keyword map handles known words instantly; the ML model handles everything the keywords don't know

### 2. Hybrid LLM architecture (anti-hallucination by design)
Sage uses a free, keyless LLM endpoint for *phrasing only*. **Every number is computed locally** by `SafeToSpendEngine` and injected into the prompt as facts — the LLM physically cannot invent a balance, because it's told the balance and the reply template enforces it. If the LLM is unreachable, the app keeps working: local parsers, phrase templates, and the classifier cover the common cases offline.

## Architecture

```
lib/
├── calculations/       SafeToSpendEngine (core money math)
├── models/             Transaction, RecurringPayment, Budget, Goal, Settings
├── services/
│   ├── app_store.dart           Platform facade (io ⇄ web)
│   ├── category_classifier.dart Naive Bayes classifier
│   ├── chat_assistant.dart      Sage: NL parsing, intent routing, LLM
│   ├── sage_phrases.dart        Instant offline response templates
│   ├── budget_guard.dart        Budget threshold alerts
│   └── insights_engine.dart     Trends, anomalies, forecasts
└── screens/            5-tab shell: Home / Payments / Budgets / Goals / More
```

- **Storage**: sqflite (Android/desktop) with a shared_preferences fallback for web — same API, chosen at compile time
- **The LLM never does math.** Grounded facts go in; only phrasing comes out.

## Security & privacy

- `allowBackup=false` — financial data never auto-syncs to Google cloud backup
- All money math is local; the LLM sees your transaction notes only to phrase a reply, and the endpoint is keyless and free
- Erase-all-data requires typing "ERASE" (two-step confirm)
- CSV export goes to your clipboard, not to any server

## Tests

```bash
flutter test        # 15 tests: classifier (incl. correction loop, vocab poisoning,
                    # confidence gating), Safe-to-Spend math, recurring logic, boot
flutter analyze     # 0 errors, 0 warnings
```

## Build

```bash
flutter build apk --release     # ~52 MB, minSdk 24
flutter build web --release
```

## Stack

Flutter 3 / Dart · sqflite · intl · fl_chart · http (LLM phrasing only) · shared_preferences
