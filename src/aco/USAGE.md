## Using the `aco` Tool

The `aco` tool is a lightweight command-line utility for working with **Assurance Case Outlines (ACO)**. It parses `.aco` files, checks structure, renders ASCII-tree visualizations, produces statistics, and translates ACO into **Argument Pattern Language (APL)** for use with O-ETB.

The tool is implemented in SWI-Prolog and invoked via a small shell-script wrapper.

---

### Installation

The `aco` tool consists of the following files:

- `aco_processor.pl`
- `aco_core.pl`
- `aco_ascii_tree.pl`
- `aco_cli.pl`
- `aco` (shell wrapper script)

These files may be copied to any directory. The wrapper script assumes that SWI-Prolog (`swipl`) is installed and available on the `PATH`.

The provided script `aco` contains:

	swipl -q -s aco_cli.pl -g main -- "$@"

If you copy the files elsewhere, keep these four Prolog modules and the aco
script together, or put them on your PATH.

### Basic Invocation

	./aco <command> [options] <file(s)>

Or, if aco is on your PATH:

	aco <command> [options] <file(s)>

The command selects the operation (tree, canon, apl, or stats); the
remaining arguments are options and input/output files.

### Commands

#### tree — ASCII Tree View

Render an assurance case outline as an ASCII tree.

	aco tree [OPTIONS] FILE.aco

Tree rendering options:

--full
Full tree with complete node bodies (default).

--structure
Show headers plus a shortened form of bodies where space permits.

--skeleton
Show only headers (no body text).

Alias display options

--aliases
Show user-provided IDs as aliases of canonical IDs (default).

--no-aliases
Suppress alias display; only canonical hierarchical IDs are shown.

Examples

	aco tree min_test.aco
	aco tree --structure min_test.aco
	aco tree --skeleton --no-aliases min_test.aco

#### canon — Canonicalize IDs

Rewrite an ACO file with canonical hierarchical IDs derived from its
indentation-based structure.

	aco canon INPUT.aco OUTPUT.aco

Preserves the textual content of nodes.
Normalizes IDs to a canonical dotted form (e.g., G1.2.3).
Useful for cleaning up early drafts or outlines with ad hoc IDs.

#### apl — Translate to APL

Translate an ACO file into Argument Pattern Language (APL) suitable for
consumption by O-ETB.

	aco apl INPUT.aco OUTPUT.pl

Produces nested APL terms (goals, strategies, evidence, etc.) rather than a
flat internal representation.
Intended as the bridge from .aco outlines to the O-ETB instantiation
pipeline (instantiate.pl).

#### aplc — Translate to APL with Canonicalization

Translate an ACO file into Argument Pattern Language (APL) with canonicalization
suitable for consumption by O-ETB.

	aco aplc INPUT.aco OUTPUT.pl

Produces output as in apl command but with ID canonicalization.

#### stats — Structural Statistics

Report structural statistics and diagnostics about an ACO file.

	aco stats INPUT.aco

Typical output includes:

Counts of goals, strategies, contexts, assumptions, evidence, modules

Counts of undeveloped goals and modules

Numbers of tree-based vs. explicit relation edges

Cross-branch relations (relations that jump across subtrees)

Useful for quick sanity checks and outline quality assessment.

### Notes
Indentation in ACO is semantically significant for hierarchy, even though
O-ETB’s APL parser itself ignores whitespace beyond token separation.

Evidence nodes are treated as leaf nodes in the tree and, once translated
and instantiated by O-ETB, correspond to executable evidence categories
(e.g., certificate, ichecker, axiom, etc.).The aco tool can be used:

Standalone during authoring and review of .aco files, and

As a front-end step in workflows that import ACO into O-ETB.

For detailed language semantics and examples, see the ACO specification and the
O-ETB User Manual.

### Example Workflow

#### 1. Inspect structure
	aco tree --structure min_test.aco

#### 2. Normalize IDs
	aco canon min_test.aco min_test_canon.aco

#### 3. Generate APL
	aco apl min_test_canon.aco min_test.apl

#### 4. Get structural statistics
	aco stats min_test.aco

### See Also
docs/ACO_spec/ — ACO language specification

docs/User-Manual/ — O-ETB User Manual

KB/EVIDENCE/ — Evidence categories and validation agents
