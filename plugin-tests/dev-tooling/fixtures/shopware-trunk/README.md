# Shopware Trunk Fixtures

## 🔖 Source

The `scripts` blocks of two `package.json` files from [shopware/shopware](https://github.com/shopware/shopware), commit `c59a7d3484c`:

| Fixture                               | Mirrors                                                        |
|---------------------------------------|----------------------------------------------------------------|
| `administration-package-scripts.json` | `src/Administration/Resources/app/administration/package.json` |
| `storefront-package-scripts.json`     | `src/Storefront/Resources/app/storefront/package.json`         |

Only the `scripts` block is kept, in the key order of the source. The JS tool suites answer `npm pkg get "scripts.<name>"` probes from these files through `shopware_trunk_script_body` in `test_helper/common_setup.bash`, so a route naming a script trunk does not define fails as it would on a real checkout.

## ♻️ Regeneration

```bash
./regenerate.sh /path/to/shopware [output-dir]
```

The script reads the checkout and writes both files into `output-dir`, by default this directory. Check out the commit named above first to reproduce the committed files; a newer trunk can change the scripts.
