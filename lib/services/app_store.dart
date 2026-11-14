// AppStore: cross-platform storage facade.
// IO (Android/desktop) -> sqflite via the original AppDatabase.
// Web -> shared_preferences JSON (browsers have no SQLite).
export 'io/app_store_io.dart'
    if (dart.library.html) 'web/app_store_web.dart';
