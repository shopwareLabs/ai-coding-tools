---
name: shopware-development
description: >-
  Plan, implement, debug, refactor, or review Shopware 6.7 plugins and projects,
  with explicit 6.6 compatibility. Covers backend/DAL, lifecycle and migrations,
  storefront Twig/JS/SCSS, administration, CMS, cart/checkout, payments and
  recurring commerce, HTTP cache/Varnish, queues, indexing, translations,
  accessibility, testing, and cross-plugin contracts. Use for Shopware-specific
  architecture, development, audits, and source research.
version: 0.10.0
license: MIT
---

# Shopware Development

Do not limit reasoning, investigation depth, or solution breadth to these references.

## Establish Context

1. Apply the request and repository instructions (`AGENTS.md` or `CLAUDE.md`, when present). Identify the requested mode and scope; do not turn a review into edits or a targeted fix into an unsolicited full audit.
2. Detect Shopware constraints from `composer.json`; confirm installed versions with package metadata or targeted lock-file queries when behavior matters. Default to 6.7 only when the project gives no version; apply 6.6 guidance when required. See [version targeting](references/02-version-targeting.md).
3. Select the relevant topic below, then inspect its actual extension point and callers. Follow evidence into adjacent code, configuration, repositories, and sources as needed. For uncertain behavior, use the [source rules](references/01-source-hierarchy.md) and [documentation/source anchors](references/10-official-docs-map.md).

## Select Mode

| Request | Guidance |
| --- | --- |
| Plan or architecture | Compare viable extension points, ownership, hot paths, compatibility, and validation. Ask only about unresolved choices that materially change persistence or UX. |
| Implement, debug, refactor, migrate | [Implementation workflow and PR/QA templates](references/03-implementation-workflow.md). Prefer the smallest coherent safe change; reuse shared seams rather than duplicate behavior. |
| Review or audit | [Evidence, severity, and findings](references/08-analysis-and-reviews.md); [coverage and prior-finding checks](references/22-code-review-protocol.md) for broad or repeated reviews. Depth and runtime checks follow the request and risk. |
| Research | [Source hierarchy](references/01-source-hierarchy.md) and [documentation map](references/10-official-docs-map.md). Verify behavior-sensitive documentation against matching source. Delegate focused research only when the runtime and instructions permit it; inline research remains sufficient. |
| Test, PR description, environment setup | Use installed `test-writing`, `contributor-writing`, or `shopware-env` workflows when applicable; otherwise use the standalone references below. Their absence must not block the task. |

## Select Topic

Read the smallest relevant set first. Combine rows when the flow crosses boundaries.

| Signals | Primary reference | Add when relevant |
| --- | --- | --- |
| Backend, DAL, API, entity, migration, service | [04 Backend](references/04-plugin-backend.md) | [09 PHP/Symfony](references/09-symfony-and-php.md), [12 Extension patterns](references/12-extension-patterns.md) |
| Twig, theme, storefront JS/SCSS | [05 Storefront](references/05-storefront-and-themes.md) | [21 Translations](references/21-internationalization-and-snippets.md) |
| Administration, app, ACL, Meteor, Pinia, Vite | [06 Administration/apps](references/06-administration-and-apps.md) | [02 Versions](references/02-version-targeting.md), [21 Translations](references/21-internationalization-and-snippets.md) |
| Payment, PSP, webhook, refund, vault | [07 Payments](references/07-payments.md) | [15 Recurring](references/15-subscriptions-and-recurring-payments.md), [18 Checkout](references/18-cart-and-checkout-pipeline.md) |
| Subscription, renewal, saved-method change | [15 Recurring](references/15-subscriptions-and-recurring-payments.md) | [07 Payments](references/07-payments.md), [13 Commerce context](references/13-context-and-commerce.md) |
| Cart, checkout, line item, delivery, promotion | [18 Cart pipeline](references/18-cart-and-checkout-pipeline.md) | [13 Commerce context](references/13-context-and-commerce.md), [24 External cart data](references/24-external-api-caching-in-cart.md) |
| Cache, Varnish, reverse proxy, invalidation | [23 HTTP cache](references/23-cache-and-http-cache.md) | [04 Backend](references/04-plugin-backend.md), [05 Storefront](references/05-storefront-and-themes.md), [11 Operations](references/11-quality-and-operations.md) |
| Queue, Messenger, RabbitMQ, worker, async | [04 Backend](references/04-plugin-backend.md), [11 Operations](references/11-quality-and-operations.md), [14 CLI/workers](references/14-cli-and-dev-tooling.md) | [18 Checkout](references/18-cart-and-checkout-pipeline.md), [20 Indexing](references/20-search-and-indexing.md) |
| Search, Elasticsearch/OpenSearch, indexer | [20 Search/indexing](references/20-search-and-indexing.md) | [11 Operations](references/11-quality-and-operations.md), [14 CLI/workers](references/14-cli-and-dev-tooling.md) |
| Accessibility, WCAG, EAA/ADA, keyboard, focus, forms, modal, storefront audit | [05 Storefront](references/05-storefront-and-themes.md), [17 Accessibility](references/17-accessibility-and-template-best-practices.md), [10 Sources](references/10-official-docs-map.md) | [08 Review output](references/08-analysis-and-reviews.md) |
| PHPUnit, fixture, integration, regression test | [19 Testing](references/19-testing-patterns.md) | Owning domain reference |
| Snippet, locale, translation, inheritance | [21 Translations](references/21-internationalization-and-snippets.md) | [13 Commerce context](references/13-context-and-commerce.md) |
| CMS, Shopping Experiences, slot config, resolver | [27 CMS](references/27-cms-elements-and-blocks.md) | [05 Storefront](references/05-storefront-and-themes.md), [06 Administration](references/06-administration-and-apps.md), [21 Translations](references/21-internationalization-and-snippets.md) |
| Plugin install/update, version bump, custom-field installer | [26 Lifecycle](references/26-plugin-lifecycle-and-activation.md) | [04 Migrations](references/04-plugin-backend.md) |
| Patch, Composer, PHPStan, Rector, dependency tool | [25 Dependency tooling](references/25-patching-and-dependency-tooling.md) | [02 Versions](references/02-version-targeting.md), [14 CLI](references/14-cli-and-dev-tooling.md) |
| Local Docker, shopware-cli project dev, dump, mail safety | [28 Local environment](references/28-local-dev-environment.md) | [14 CLI](references/14-cli-and-dev-tooling.md), [11 Operations](references/11-quality-and-operations.md) |
| Existing separate frontend / Store API integration | [16 Cross-frontend contracts](references/16-headless-and-composable-frontends.md) | Owning payment/cart/context reference; do not introduce a separate frontend unless requested |

For security, production rollout, sensitive logging, or performance work, add [11 Quality and operations](references/11-quality-and-operations.md).
