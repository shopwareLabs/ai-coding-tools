# Category Detection

Determine the appropriate test category (A-E) based on source class structure.

## Category Overview

| Category | Indicators | Template |
|----------|------------|----------|
| A (DTO) | No dependencies, value object, entity, struct, collection | [category-a-dto.md](../templates/category-a-dto.md) |
| B (Service) | Has constructor dependencies, business logic | [category-b-service.md](../templates/category-b-service.md) |
| C (Flow/Event) | EventSubscriberInterface, FlowAction, FlowStorer | [category-c-flow.md](../templates/category-c-flow.md) |
| D (DAL) | Uses EntityRepository, Criteria, DAL operations | [category-d-dal.md](../templates/category-d-dal.md) |
| E (Exception) | Exception class, factory methods, error handling focus | [category-e-exception.md](../templates/category-e-exception.md) |

## Decision Tree

```
Has constructor dependencies?
├── No → Is it an Exception class?
│   ├── Yes → Category E
│   └── No → Category A (DTO)
└── Yes → Uses EntityRepository?
    ├── Yes → Category D (DAL)
    └── No → Implements EventSubscriberInterface or FlowAction?
        ├── Yes → Category C (Flow/Event)
        └── No → Category B (Service)
```

## Category A: DTO/Entity/Value Object

**Indicators:**
- No constructor dependencies (or only primitive values)
- Value object, entity, struct, or collection class
- Factory methods (`fromArray()`, `create()`)
- Serialization methods (`toArray()`, `jsonSerialize()`)

**Examples:**
- `ProductEntity`
- `PriceStruct`
- `CartItemCollection`
- `ConfigurationValue`

## Category B: Service

**Indicators:**
- Has constructor dependencies (injected services)
- Business logic methods
- No direct DAL repository usage
- No event subscriber or flow action interfaces

**Examples:**
- `ProductService`
- `CartCalculator`
- `PriceCalculator`
- `ValidationService`

## Category C: Flow/Event

**Indicators:**
- Implements `EventSubscriberInterface`
- Extends/implements `FlowAction` or `FlowStorer`
- Event dispatch handling
- Context passing patterns

**Examples:**
- `OrderPlacedSubscriber`
- `SendMailAction`
- `CustomerStorer`
- `CartEventSubscriber`

## Category D: DAL/Repository

**Indicators:**
- Uses `EntityRepository` for data access
- Builds `Criteria` for searches
- Performs DAL operations (search, create, update, delete)
- Works with entity collections

**Examples:**
- `ProductRepository` (wrapper)
- `OrderService` with repository operations
- `EntityWriter` operations
- `SearchHandler`

## Category E: Exception

**Indicators:**
- Extends `\Exception` or Shopware exception base
- Factory methods for exception creation
- Error code definitions
- HTTP status handling

**Examples:**
- `CartException`
- `ProductNotFoundException`
- `ValidationException`
- `OrderException`
