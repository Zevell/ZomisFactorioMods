# Factorio Mods — Zevell's fork

This is a personal fork of **[Zomis/FactorioMods](https://github.com/Zomis/FactorioMods)**, the
Factorio mod collection created and maintained by **Zomis**. All mods, their code and their
copyright are his original work; this fork exists so I can develop, test and package changes
locally — mainly to `copy-paste-recipe-signals` — and offer them back as pull requests.

| | |
|---|---|
| **Upstream (original author)** | [Zomis/FactorioMods](https://github.com/Zomis/FactorioMods) — by [Zomis](https://github.com/Zomis) |
| **This fork** | [Zevell/ZomisFactorioMods](https://github.com/Zevell/ZomisFactorioMods) |
| **License** | MIT — see [LICENSE](LICENSE). Unchanged from upstream; copyright remains with the original author. |

The fork contains the upstream mod collection unchanged, plus the changes listed below.

## Differences from upstream

Changes present in this fork that are **not** in
[Zomis/FactorioMods](https://github.com/Zomis/FactorioMods). This list is kept up to date as the
fork evolves; each mod's own `changelog.txt` holds the full release notes.

### `copy-paste-recipe-signals` — 1.9.0 (2026-09-27)

**Features**

- **Paste picker.** When two or more item signals are copied and pasted onto a requester or buffer
  chest, a small GUI appears with an **ALL** button (the *Everything* wildcard signal) and one
  button per item, using the in-game item icons. Choosing a single item requests only that item;
  **ALL** pastes every copied item signal. Pasting a single signal is unchanged, and the picker can
  be turned off with the new per-player setting *"Ask which items to paste"*.
- **Ghost support.** Signals can be copied from, and pasted onto, ghost (not-yet-built) entities
  such as combinators. A ghost requester chest cannot accept item requests in Factorio 2.0 — that
  case degrades to a normal "nothing was pasted" message instead of failing.

**Bug fixes**

- Pasting item signals to requester chests crashed in Factorio 2.0; the requester point and manual
  logistic section are now handled defensively.
- Modded requester chests (e.g. *Bots Bots Bots*' Simple Requester Chest) are valid paste targets,
  not just the vanilla chest.
- Buffer chests accept pasted item requests; provider and storage chests show a helpful popup
  instead of crashing.
- Decider combinator paste fixed for Factorio 2.0 (per-index conditions/outputs API).
- Circuit-condition paste no longer writes the enable flag to control behaviors that lack it.
- Informational popups no longer crash (`LuaEntity` has `localised_name`, and Factorio 2.0 has no
  `localization` global).
- Unexpected copy/paste errors are logged and shown as flying text instead of crashing the game.
- Requester chests always request one full stack of each item.

### `foofle`

- `mytable.lua` was missing its Flib module wrapper (`local flib_table = {}` + `return
  flib_table`); the same fix already applied to `copy-paste-recipe-signals` is applied here.

## Contributing upstream

- Pull requests are welcome — to [Zomis/FactorioMods](https://github.com/Zomis/FactorioMods).
- There is no need to bump the version number in a pull request; upstream's `Jenkinsfile` takes
  care of that when a mod is released.
- When opening a pull request from this fork, branch from `upstream/main` (rather than this fork's
  `main`) so the fork-specific changes to this README are not dragged into the pull request.
