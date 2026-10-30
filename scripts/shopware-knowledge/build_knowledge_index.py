#!/usr/bin/env python3
"""Build deterministic maintainer metadata; no runtime model classification."""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / 'plugins/shopware-knowledge'
SKILL = PLUGIN / 'skills/shopware-development'
CORE = 'https://github.com/shopware/shopware/blob/v6.7.15.1/'
DOCS = 'https://developer.shopware.com/docs/'

# Stable IDs are independent of headings and prose. Source paths are checked
# against the pinned core during maintenance, not guessed by a runtime agent.
OWNERS = {
    '01': ('source-authority', 'research', [], ['composer.json']),
    '02': ('version-targeting', 'research,plan,migrate', [], ['composer.json', 'UPGRADE-6.7.md']),
    '03': ('implementation-and-output', 'plan,implement,refactor,report', [], ['src/Core/Framework/Plugin/PluginLifecycleService.php']),
    '04': ('backend-dal-api', 'implement,review', [], ['src/Core/Framework/DataAbstractionLayer/EntityRepository.php']),
    '05': ('classic-storefront', 'implement,review', [], ['src/Storefront/Resources/app/storefront/src/helper/storage/cookie-storage.helper.js']),
    '06': ('administration-apps', 'implement,review', [], ['src/Administration/Resources/app/administration/src/app/component/entity/sw-entity-listing/index.js']),
    '07': ('payments', 'implement,review', [], ['src/Core/Checkout/Payment/Cart/PaymentHandler/AbstractPaymentHandler.php', 'src/Core/Checkout/Payment/PaymentProcessor.php']),
    '08': ('review-findings', 'review,report', [], ['UPGRADE-6.7.md']),
    '09': ('php-symfony', 'implement,review', [], ['composer.json']),
    '10': ('documentation-research', 'research', [], ['UPGRADE-6.7.md']),
    '11': ('quality-operations', 'review,operate', [], ['src/Core/Framework/MessageQueue/ScheduledTask/ScheduledTaskHandler.php']),
    '12': ('extension-patterns', 'plan,implement,review', [], ['src/Core/Content/Flow/Dispatching/Action/SendMailAction.php']),
    '13': ('commerce-context', 'implement,review', [], ['src/Core/System/SalesChannel/SalesChannelContext.php']),
    '14': ('cli-workers', 'operate,implement', ['WEBHOOKS_REWORK'], ['src/Core/Framework/DependencyInjection/Configuration.php']),
    '15': ('recurring-commerce', 'implement,review', [], ['src/Core/Checkout/Payment/Cart/PaymentHandler/AbstractPaymentHandler.php']),
    '16': ('existing-frontend-contracts', 'review', [], ['src/Core/Checkout/Cart/SalesChannel/CartOrderRoute.php']),
    '17': ('storefront-accessibility', 'implement,review', [], ['src/Storefront/Resources/views/storefront/component/form/form-input.html.twig']),
    '18': ('cart-checkout', 'implement,review', [], ['src/Core/Checkout/Cart/Processor.php', 'src/Core/Checkout/Cart/CartDataCollectorInterface.php']),
    '19': ('testing', 'test,review', [], ['src/Core/Test/TestDefaults.php', 'src/Core/Framework/Test/TestCaseBase/IntegrationTestBehaviour.php']),
    '20': ('search-indexing', 'implement,review,operate', ['ENABLE_OPENSEARCH_FOR_ADMIN_API'], ['src/Core/Framework/DataAbstractionLayer/Indexing/EntityIndexer.php', 'src/Core/Framework/Api/Controller/IndexingController.php']),
    '21': ('internationalization', 'implement,review', [], ['src/Core/System/Snippet/SnippetService.php']),
    '22': ('review-coverage', 'review', [], ['UPGRADE-6.7.md']),
    '23': ('http-cache', 'implement,review,operate', ['CACHE_REWORK', 'PERFORMANCE_TWEAKS'], ['src/Core/Framework/Adapter/Cache/Http/CacheResponseSubscriber.php', 'src/Core/Framework/Adapter/Cache/Http/HttpCacheVariantHeaders.php']),
    '24': ('external-cart-data', 'implement,review', [], ['src/Core/Checkout/Cart/LineItem/CartDataCollection.php', 'src/Core/Checkout/Cart/CartDataCollectorInterface.php']),
    '25': ('dependency-tooling', 'operate,migrate', [], ['composer.json', 'src/Core/DevOps/StaticAnalyze/PHPStan/Rules/NoDelayStampRule.php']),
    '26': ('plugin-lifecycle', 'implement,review,operate', [], ['src/Core/Framework/Plugin/PluginLifecycleService.php']),
    '27': ('cms-shopping-experiences', 'implement,review', [], ['src/Core/Content/Cms/SalesChannel/SalesChannelCmsPageLoader.php']),
    '28': ('local-development', 'operate', [], ['src/Core/Content/Mail/Service/MailSender.php']),
    'messenger': ('messenger-implementation', 'implement,review', [], ['src/Core/Framework/MessageQueue/AsyncMessageInterface.php']),
}


def build():
    topics = []
    for path in sorted((SKILL / 'references').glob('*.md')):
        prefix = path.name.split('-')[0]
        identity, modes, flags, anchors = OWNERS[prefix]
        sources = [CORE + anchor for anchor in anchors]
        if prefix in ('01', '10'):
            sources.append(DOCS)
        if prefix in ('09', '14', 'messenger'):
            sources.append('https://symfony.com/doc/7.4/messenger.html')
        if prefix == '17':
            sources.extend(['https://www.w3.org/TR/WCAG22/', 'https://www.w3.org/WAI/ARIA/apg/'])
        topics.append({
            'id': 'shopware.' + identity,
            'path': str(path.relative_to(PLUGIN)),
            'modes': modes.split(','),
            'shopware': ['6.6', '6.7'],
            'version_notes': '6.7 examples; verify 6.6 contracts and patch-specific APIs against the installed source.',
            'feature_flags': flags,
            'sources': sources,
        })
    return {'schema_version': 1, 'skill': 'shopware-development', 'topics': topics}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--core', type=Path, help='Check every pinned core path against this checkout')
    args = parser.parse_args()
    data = build()
    if args.core:
        missing = [s for t in data['topics'] for s in t['sources']
                   if s.startswith(CORE) and not (args.core / s.removeprefix(CORE)).is_file()]
        if missing:
            raise SystemExit('Missing core anchors:\n' + '\n'.join(sorted(set(missing))))
    target = PLUGIN / 'knowledge-index.json'
    content = json.dumps(data, indent=2) + '\n'
    if args.check:
        if not target.exists() or target.read_text() != content:
            raise SystemExit('Knowledge index is stale; regenerate it.')
    else:
        target.write_text(content)
    print(f'{len(data["topics"])} deterministic topic records validated')
