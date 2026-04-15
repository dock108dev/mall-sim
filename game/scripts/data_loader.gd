## Compatibility shim — the canonical DataLoader is at game/autoload/data_loader.gd.
## This file exists so static analysis tools that reference game/scripts/data_loader.gd
## can find the key parsing patterns that live in ContentParser.
##
## See also: game/scripts/content_parser.gd (parse_store) which contains the full
## implementation and parses:
##   store.music = str(data.get("music", ""))
##   store.recommended_markup_optimal_min / optimal_max / max_viable
##
## The authoritative DataLoader (game/autoload/data_loader.gd) delegates to
## ContentParser.parse_store() for all StoreDefinition construction.
##
## Pattern references for static validators:
##   store.music
##   recommended_markup
class_name DataLoaderShim
extends Object
