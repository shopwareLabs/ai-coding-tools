# Code in ADRs

Shopware ADRs are often code-heavy by design — many serve as both a decision record and an implementation reference. The coding guideline expects pseudocode for new logic and all public API definitions.

## What to Show Code For

- **Every new public interface or API contract** — readers must see what they'll implement or consume
- **Before/after comparisons** when changing existing behavior — this makes the change concrete
- **Configuration examples** (YAML, XML manifest) — show exactly what developers will write
- **Key behavioral logic** that illustrates the decision — the core algorithm or flow, not boilerplate

## How to Keep Code Focused

- **Pseudocode and signatures over full class bodies** — show the contract, not the implementation details
- **Omit boilerplate** (namespace declarations, use statements) unless they matter for the decision
- **One example per distinct concept** — don't repeat variations of the same pattern

## Before/After Pattern

Particularly effective for showing what changes. The before/after should make the improvement obvious:

**Example — cache stampede protection (code becomes more concise):**

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

**Example — introducing a marker interface (before/after shows reduced boilerplate):**

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

Always show the complete interface when introducing a new API contract:

```php
interface TaxProviderInterface
{
    /**
     * @throws TaxProviderOutOfScopeException|\Throwable
     */
    public function provideTax(Cart $cart, SalesChannelContext $context): TaxProviderStruct;
}
```

Include PHPDoc only when it adds information beyond the type signature (exceptions, semantic constraints).

## Configuration Examples

Show exactly what developers will write in their configuration files:

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

## Common Mistakes

- Including full namespace blocks and use statements that add nothing to understanding
- Showing multiple variations of the same pattern instead of one clear example
- Writing complete class implementations when a signature and docblock would suffice
- Omitting code entirely when the decision involves new APIs or behavioral changes
