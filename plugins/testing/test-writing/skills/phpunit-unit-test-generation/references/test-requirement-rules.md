# Test Requirement Rules

Decision tree and patterns for determining if a class/method requires a unit test.

## Decision Tree

```
Method body is ONLY `return <literal|constant|property|passthrough-new>`?
├── Yes → NO TEST NEEDED (no logic)
└── No (has conditionals/loops/transformations) → Continue to Category Detection
```

## NO Test Required

| Pattern | Example | Reason |
|---------|---------|--------|
| Pure accessor | `getId()`, `getName()`, `setName()` | No logic |
| Constant return | `return 'literal'` / `return CONSTANT` | Hardcoded value |
| Logic-free constructor | `new Entity($a, $b)` assigns only | No logic |
| Passthrough factory | `return new Foo($this->a, $this->b)` | Direct property forwarding |
| Simple Collection | `AppCollection` with only `getExpectedClass()` | No custom logic |
| EntityDefinition | `WebhookDefinition` | Integration tested |
| Pure readonly DTO | Constructor + public props + `getApiAlias()` | No logic methods |
| Interface | `DistributionConfig` | Test implementations |
| Abstract method | `abstract function getStatus()` | Test implementations |
| Message class | `FooMessage implements AsyncMessageInterface` | Data carrier |

## Test IS Required

| Indicator | Why |
|-----------|-----|
| Contains `if`/`switch`/`match` | Logic branches need coverage |
| Factory method (`fromArray()`, `create()`) | Construction paths |
| Transforms/computes data | Correctness verification |
| Throws exceptions conditionally | Error path coverage |
| Custom `toArray()`/`jsonSerialize()` | Output format validation |

## Logic Detection Patterns

### NOT Logic (skip test)

- `return 'string_literal';` - hardcoded string
- `return self::CONSTANT;` - class/static constant
- `return $this->property;` - pure accessor
- `return new Foo($this->a, $this->b);` - passthrough factory (direct property forwarding)

### IS Logic (needs test)

- `return $condition ? 'a' : 'b';` - conditional
- `return sprintf('prefix_%s', $this->id);` - string transformation
- `return new Foo($this->transform($a));` - factory with transformation
- Any `if`/`switch`/`match`/`foreach`/computation
