# Test Categories

Categories are determined by the **test subject characteristics**, not test file location.

| Cat | Name | Characteristics | Key Patterns |
|-----|------|-----------------|--------------|
| A | Simple DTO | Tests value objects, entities, collections | No dependencies, direct instantiation |
| B | Service | Tests services with dependencies | Mocking/stubs required, DI setup |
| C | Flow/Event | Tests subscribers, flow actions | Event dispatcher setup, flow context |
| D | DAL | Tests using repository patterns | StaticEntityRepository, Criteria |
| E | Exception | Tests exception handling paths | expectException, error scenarios |

## Category Detection

Classify by the source class under test (from `#[CoversClass]`):

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
