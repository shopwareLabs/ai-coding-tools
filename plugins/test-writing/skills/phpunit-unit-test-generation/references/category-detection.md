# Category Detection

Determine the appropriate test category (A-E) based on source class structure.

## Category Overview

| Category       | Indicators                                                |
|----------------|-----------------------------------------------------------|
| A (DTO)        | No dependencies, value object, entity, struct, collection |
| B (Service)    | Has constructor dependencies, business logic             |
| C (Flow/Event) | EventSubscriberInterface, FlowAction, FlowStorer         |
| D (DAL)        | Uses EntityRepository, Criteria, DAL operations          |
| E (Exception)  | Exception class, factory methods, error handling focus  |

## Decision Tree

Classify by the source class under test:

```
Source class has constructor dependencies?
├── No → Source class extends \Exception or \RuntimeException?
│   ├── Yes → Category E
│   └── No → Category A (DTO)
└── Yes → Source class injects EntityRepository?
    ├── Yes → Category D (DAL)
    └── No → Source class implements EventSubscriberInterface or extends FlowAction?
        ├── Yes → Category C (Flow/Event)
        └── No → Category B (Service)
```

## Category Indicators

### A (DTO)
- No constructor dependencies (or only primitive values)
- Value object, entity, struct, or collection class
- Factory methods (`fromArray()`, `create()`)
- Serialization methods (`toArray()`, `jsonSerialize()`)

### B (Service)
- Has constructor dependencies (injected services)
- Business logic methods
- No direct DAL repository usage
- No event subscriber or flow action interfaces

### C (Flow/Event)
- Implements `EventSubscriberInterface`
- Extends/implements `FlowAction` or `FlowStorer`
- Event dispatch handling

### D (DAL)
- Uses `EntityRepository` for data access
- Builds `Criteria` for searches
- Performs DAL operations (search, create, update, delete)

### E (Exception)
- Extends `\Exception` or Shopware exception base
- Factory methods for exception creation
- Error code definitions
- HTTP status handling
