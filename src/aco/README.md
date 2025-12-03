# Assurance Case Outline (ACO) – Source Directory

This directory contains the **implementation of the Assurance Case Outline (ACO) processor**, which provides a lightweight front-end notation for creating assurance cases that are ultimately translated into **Argument Pattern Language (APL)** for use by O-ETB.

---

## 🎯 Purpose

The ACO processor is designed to:

- Accept assurance case outlines written in `.aco` format
- Provide immediate user feedback via:
  - syntax checking
  - statistics
  - ASCII tree visualization
- Translate ACO into **proper APL**, suitable for instantiation by O-ETB
- Support gradual refinement from informal outlines to fully executable assurance cases

ACO is intended to improve usability without weakening the rigor of O-ETB’s underlying assurance model.

---

## 🧠 Key Design Principles

- **Human-oriented input**, machine-oriented output
- **Hierarchical structure inferred from indentation**
- **Explicit node types** (Goals, Strategies, Contexts, Assumptions, Justifications, Evidence, Modules)
- **Evidence is executable**, not just descriptive
- ACO is *not* APL — translation is semantic, not syntactic

---

## 📂 Typical Contents

| File | Role |
|----|----|
| `aco_processor.pl` | Main coordination module |
| `aco_core.pl` | Parsing and internal representation |
| `aco_ascii_tree.pl` | ASCII tree rendering with options |
| `aco_apl.pl` | Translation from ACO to APL |
| `aco_cli.pl` | Command-line interface |
| `aco.sh` | Shell wrapper |
| `test_aco_*.sh` | Regression and feature tests |

(Exact file names may evolve as refactoring continues.)

---

## 🧪 Integration with O-ETB

The ACO processor may be used in two ways:

1. **Standalone CLI tool** for authors working on `.aco` files
2. **Integrated O-ETB command** for importing outlines into an assurance workflow

In both cases, the end result is **APL**, not an internal ACO structure.

---

## 🚧 Status

This directory is under active development.
Expect refactoring, new node types (e.g. Evidence), and tighter integration with O-ETB internals.

---

## 📌 Related Documentation

- ACO Specification: `docs/ACO_spec/`
- O-ETB User Manual: `docs/User-Manual/`
- APL Reference Patterns: `KB/PATTERNS/`, `References/`

---