# SwiftData

## Core Rules

### Autosaving
Autosaving timing is unpredictable. Add explicit `save()` calls when correctness matters. No need to check `modelContext.hasChanges` first.

### Actor Boundaries
`ModelContext` and model instances must **never** cross actor boundaries. Containers and persistent identifiers **are** sendable — send the ID and re-fetch in destination context.

### Persistent Identifiers
Temporary before first save (start with lowercase "t"). Save before relying on ID.

### Relationships
- Use `@Relationship` on **one side only** (circular reference otherwise).
- Always specify explicit **delete rule** (default `.nullify` can orphan or crash on non-optional).
- Most common: `@Relationship(deleteRule: .cascade, inverse: \Sight.destination)`.
- SwiftData frequently gets inverse relationships wrong — be explicit.

### Property Restrictions
- Do not use property name `description` in `@Model` classes.
- Do not add property observers to `@Model` classes (silently ignored).
- `@Attribute(.externalStorage)` is a suggestion, only for `Data` type.
- `@Transient` properties must have a default value. Consider computed properties instead.

### Uniqueness
- One `#Unique` per model. Multiple constraints: `#Unique<Foo>([\.email], [\.username])`.

### Enum Properties
Must conform to `Codable`. Enums with associated values **do** work.

### @Query
- **Only** works inside SwiftUI views. Will not function elsewhere.
- For counts: use `ModelContext.fetchCount()` (won't live update without @Query trigger).

### FetchDescriptor Optimization
- Set `relationshipKeyPathsForPrefetching` for known-needed relationships.
- Set `propertiesToFetch` to limit fetched properties.

### Migration
Nearly always use an explicit migration schema, even for lightweight migrations.

## Predicates

### String Matching
Always use `localizedStandardContains()`:

```swift
@Query(filter: #Predicate<Movie> {
    $0.name.localizedStandardContains("titanic")
}) private var movies: [Movie]
```

### Unsupported Operations
These **won't compile**: `hasSuffix()`, `lowercased()`, `map()`, `reduce()`, `count(where:)`, `first`. Custom operators are not allowed.

Use `starts(with:)` instead of `hasPrefix()`.

### Dangerous Predicates (Runtime Crashes)

```swift
// CRASHES at runtime
#Predicate<Movie> { $0.cast.isEmpty == false }

// WORKS
#Predicate<Movie> { !$0.cast.isEmpty }
```

**Never** use in predicates:
- Computed properties
- `@Transient` properties
- Custom `Codable` struct data
- Regular expressions

All predicates must rely on data stored as `@Model` classes.

## CloudKit Constraints

**Only when using SwiftData with CloudKit:**
- Never use `@Attribute(.unique)` or `#Unique`.
- All properties must have default values or be optional.
- All relationships must be optional.
- Indexes and subclasses are supported (with correct OS).
- Design for **eventual consistency**.

## Indexing (iOS 18+)

Small write cost, speeds up queries. Bad for write-heavy/read-rare data (e.g., logging).

```swift
@Model class Article {
    #Index<Article>([\.type], [\.type, \.author])
    var type: String
    var author: String
}
```

## Class Inheritance (iOS 26+)

Child classes must have `@available(iOS 26, *)` even if deployment target is iOS 26:

```swift
@Model class Article {
    var type: String
    init(type: String) { self.type = type }
}

@available(iOS 26, *)
@Model class Tutorial: Article {
    var difficulty: Int
    init(difficulty: Int) {
        self.difficulty = difficulty
        super.init(type: "Tutorial")
    }
}
```

Both parent and child must use `@Model`. List all in schema for model container.

### Filtering with Subclasses

```swift
@Query private var tutorials: [Tutorial]     // Only tutorials
@Query private var articles: [Article]        // All including subclasses

// Specific subclasses
@Query(filter: #Predicate<Article> {
    $0 is Tutorial || $0 is News
}) private var tutorialsAndNews: [Article]

// Filter by child properties
@Query(filter: #Predicate<Article> { article in
    if let tutorial = article as? Tutorial {
        tutorial.difficulty < 3
    } else {
        false
    }
}) private var easyTutorials: [Article]
```

**Note:** Use model subclassing only when it provides clear benefit. Protocols are often simpler.
