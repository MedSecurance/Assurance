# Open Evidential Tool Bus (O-ETB)

## Overview

The **Open Evidential Tool Bus (O-ETB)** is an open, extensible framework for the construction, instantiation, and management of **assurance cases** and their associated **evidence**.  

O-ETB supports system assurance in safety-critical and security-critical domains by:
- structuring assurance arguments,
- linking claims to evidence,
- enabling tool-based and human-in-the-loop evidence generation and validation,
- and maintaining a persistent repository of assurance cases and evidence records.

O-ETB is being developed within the **MedSecurance** European Commission project, but is intended as a general-purpose, reusable assurance infrastructure.

---

## Conceptual Model

At a high level, O-ETB works with five core concepts:

1. **Assurance Case Outlines**  
   Intuitive text-based outlining language for defining assurance cases and reusable parameterized assurance case modules.

2. **Argument Patterns**  
   Reusable assurance structures expressed in **Argument Pattern Language (APL)**, capturing common reasoning templates (e.g., MILS security patterns, operational safety arguments).

3. **Assurance Case Instances**  
   Concrete instantiations of argument patterns into executable assurance cases for a specific system or scenario.

4. **Evidence and Agents**  
   Evidence nodes represent required evidence of a given category (e.g., certificate, model checking results).  
   Evidence production and validation are performed by **agents**, which may invoke external tools, workflows, or human interaction.

5. **Certification Assurance Package**  
   Artefacts exported by O-ETB for consumption by users, evaluators and certifiers.

---

## Assurance Case Outline (ACO)

To lower the entry barrier for assurance case authors, O-ETB introduces the **Assurance Case Outline (ACO)** notation.

ACO is a lightweight, text-based outlining language designed to:
- feel natural to assurance engineers,
- support incremental development,
- and be readable without knowledge of APL or Prolog.

An **ACO processor** translates ACO documents into proper **APL**, which is then handled by O-ETB exactly like hand-written APL.

Key features of ACO:
- hierarchical outline structure,
- explicit node types (Goal, Strategy, Context, Assumption, Justification, Evidence, Module),
- support for relations and cross-references,
- ASCII tree rendering for visualization,
- command-line tooling for checking and translation.

The ACO specification and a Quick Reference Card are maintained under: docs/ACO_spec.

---

## Repository Contents

This repository contains the complete O-ETB implementation, documentation, and supporting artifacts.

### Key Directories

- `src/`  
  Core Prolog implementation of O-ETB, including:
  - assurance case management,
  - pattern instantiation,
  - evidence handling,
  - and the ACO processor (`src/ACO/`).

- `KB/`  
  O-ETB knowledge bases:
  - evidence categories and validation methods,
  - models,
  - patterns,
  - tool agents.

- `REPOSITORY/`  
  Persistent storage of assurance case outlines, instantiated assurance cases and evidence records.

- `docs/`  
  Specifications, user manual, quick reference, argument pattern guidance, design notes, diagrams, and glossary.

- `Tools/`  
  Standalone utilities such as:
  - ACO → APL translator,
  - visualization helpers,
  - import/export tools.

- `CAP/`  
  Certification Assurance Package, including:
  - textual representation of instantiated concrete assurance cases,
  - browsable HTML representation of modular instantiated assurance cases,
  - graphical representation of assurance cases or segments in GSN notation.

---

## Execution Environment

- **Language:** SWI-Prolog  
- **Supported Versions:** SWI-Prolog 8.x – 9.x  
- **Platforms:** Linux, macOS  
- **Deployment:** Native or Docker-based

---

## Documentation

- **User Manual:**  
  See `docs/User-Manual/`

- **ACO Specification:**  
  See `docs/ACO_spec/`

- **ACO Quick Reference Card:**  
  See `docs/ACO_spec/`

- **Design Notes and Diagrams:**  
  See `docs/Design/`

- **Glossary:**  
  See `docs/Glossary/`

- **Patterns:**  
  See `docs/Patterns/`

---

## Current Focus

Active development priorities include:

- Finalizing the ACO → APL translation pipeline
- Tight integration of ACO tooling into interactive O-ETB workflows
- ACO Workbench to provide suggestions and transformations for developing assurance case outlines
- Evidence category definition and agent interoperability
- Improved visualization of assurance cases
- Public release stabilization and documentation clarity

---

## Project Context

- **Project:** MedSecurance (EC Project No. 101095448)
- **Consortium Partners:**  
  University of Warwick, CEA, BioAssist, StabVida, University of Birmingham, European University of Cyprus, UPC, and others.

---

## License and Status

O-ETB is an active research and development effort.  
Licensing and contribution guidelines will be published as the repository matures.

---

*O-ETB aims to bridge rigorous assurance methods with practical engineering workflows — making structured assurance scalable, inspectable, and executable.*

---
** The initial commit to this repo included content from the CITADEL Adaptive MILS Evidential Tool Bus (AM-ETB), implemented by Marius Bozga of Université Grenoble Alpes. It was reorganized by Rance DeLong of The Open Group who is responsible for its continuing development.

