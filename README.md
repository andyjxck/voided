# Pier Pressure

A Lucky Defense-style merge tower defence on a seaside pier, in Flutter, playable Solo or in Co-op with an AI partner. See DESIGN.md for the design, numbers and balance results.

- Play while developing: `flutter run -d chrome`
- Release web build: `flutter build web`, then `python3 -m http.server 8080 -d build/web` and open http://localhost:8080
- Tests: `flutter test`
- Balance sims: `dart run tool/balance.dart`
