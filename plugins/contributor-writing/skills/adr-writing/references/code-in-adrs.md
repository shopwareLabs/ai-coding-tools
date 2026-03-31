# Code in ADRs

Show pseudocode for new logic and all public API definitions (per coding guideline).

## What to Show

- **New public interfaces / API contracts**
- **Before/after comparisons** when changing existing behavior
- **Configuration examples** (YAML, XML manifest)
- **Key behavioral logic** — core algorithm or flow, not boilerplate

Prefer signatures over full class bodies. Omit boilerplate (namespaces, use statements) unless relevant to the decision. One example per concept.

## Before/After Pattern

**Cache stampede protection (code becomes more concise):**

```markdown
## `CachedRuleLoader` before

\`\`\`php
class CachedRuleLoader extends AbstractRuleLoader
{
    public const CACHE_KEY = 'cart_rules';

    private AbstractRuleLoader $decorated;
    private TagAwareAdapterInterface $cache;
    private LoggerInterface $logger;

    public function load(Context $context): RuleCollection
    {
        $item = $this->cache->getItem(self::CACHE_KEY);

        try {
            if ($item->isHit() && $item->get()) {
                $this->logger->info('cache-hit: ' . self::CACHE_KEY);
                return $item->get();
            }
        } catch (\Throwable $e) {
            $this->logger->error($e->getMessage());
        }

        $this->logger->info('cache-miss: ' . self::CACHE_KEY);
        $rules = $this->getDecorated()->load($context);
        $item->set($rules);
        $this->cache->save($item);

        return $rules;
    }
}
\`\`\`

## `CachedRuleLoader` after

\`\`\`php
class CachedRuleLoader extends AbstractRuleLoader
{
    public const CACHE_KEY = 'cart_rules';

    private AbstractRuleLoader $decorated;
    private CacheInterface $cache;

    public function load(Context $context): RuleCollection
    {
        return $this->cache->get(self::CACHE_KEY, function () use ($context): RuleCollection {
            return $this->decorated->load($context);
        });
    }
}
\`\`\`
```

**Marker interface (before/after shows reduced boilerplate):**

```markdown
Before:

\`\`\`php
class SetOrderStateAction extends FlowAction implements DelayableAction
{
    public function handleFlow(StorableFlow $flow): void
    {
        $this->connection->beginTransaction();
        //do stuff
        try {
            $this->connection->commit();
        } catch (\Throwable $e) {
        }
    }
}
\`\`\`

After:

\`\`\`php
class SetOrderStateAction extends FlowAction implements DelayableAction, TransactionalAction
{
    public function handleFlow(StorableFlow $flow): void
    {
        //do stuff - will be wrapped in a transaction
    }
}
\`\`\`
```

## Interface Definitions

Show complete interfaces for new API contracts. Include PHPDoc only when it adds information beyond the type signature (exceptions, semantic constraints):

```php
interface TaxProviderInterface
{
    /**
     * @throws TaxProviderOutOfScopeException|\Throwable
     */
    public function provideTax(Cart $cart, SalesChannelContext $context): TaxProviderStruct;
}
```

## Configuration Examples

```xml
<flow-extensions>
    <flow-events>
        <flow-event>
            <name>swag.before.open.the.doors</name>
            <aware>customerAware</aware>
        </flow-event>
    </flow-events>
</flow-extensions>
```
