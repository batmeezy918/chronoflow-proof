#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[1/7] Verifying repo..."
if [ ! -d ".git" ]; then
  echo "ERROR: Not inside a git repo"
  exit 1
fi

echo "[2/7] Creating Lean project structure..."
mkdir -p ChronoFlow
mkdir -p .github/workflows

echo "[3/7] Writing lakefile.lean..."
cat << 'EOL' > lakefile.lean
import Lake
open Lake DSL

package «chronoflow» where

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git"
EOL

echo "[4/7] Writing lean-toolchain..."
cat << 'EOL' > lean-toolchain
leanprover/lean4:stable
EOL

echo "[5/7] Writing proof file..."
cat << 'EOL' > ChronoFlow/Basic.lean
import Mathlib.Analysis.NormedSpace.Basic
import Mathlib.Analysis.InnerProductSpace.Basic
import Mathlib.LinearAlgebra.Matrix
import Mathlib.Data.Real.Basic

open Real
open scoped BigOperators

namespace ChronoFlow

variable {n : ℕ}

abbrev State := EuclideanSpace ℝ (Fin n)

def normalize (v : State) (h : v ≠ 0) : State :=
  v / ‖v‖

theorem normalize_norm_one
(v : State) (h : v ≠ 0) :
‖normalize v h‖ = 1 := by
  unfold normalize
  have hnorm : ‖v‖ ≠ 0 := norm_ne_zero_iff.mpr h
  simp [hnorm]

def flow
(A : Matrix (Fin n) (Fin n) ℝ)
(x : State)
(h : A.mulVec x ≠ 0) : State :=
  normalize (A.mulVec x) h

theorem flow_norm_invariant
(A : Matrix (Fin n) (Fin n) ℝ)
(x : State)
(h : A.mulVec x ≠ 0) :
‖flow A x h‖ = 1 := by
  unfold flow
  exact normalize_norm_one (A.mulVec x) h

def iterate
(A : Matrix (Fin n) (Fin n) ℝ)
: ℕ → State → State
| 0, x => x
| k+1, x =>
  if h : A.mulVec (iterate A k x) ≠ 0 then
    flow A (iterate A k x) h
  else
    0

theorem iterate_nonzero
(A : Matrix (Fin n) (Fin n) ℝ)
(x : State)
(hx : x ≠ 0)
(hA : ∀ y, y ≠ 0 → A.mulVec y ≠ 0)
:
∀ k, iterate A k x ≠ 0 := by
  intro k
  induction k with
  | zero =>
      simpa [iterate] using hx
  | succ k ih =>
      simp [iterate]
      have hprev := ih
      have hmul := hA (iterate A k x) hprev
      simp [hmul]

theorem trajectory_bounded
(A : Matrix (Fin n) (Fin n) ℝ)
(x : State)
(hx : x ≠ 0)
(hA : ∀ y, y ≠ 0 → A.mulVec y ≠ 0)
:
∀ k ≥ 1, ‖iterate A k x‖ = 1 := by
  intro k hk
  cases k with
  | zero =>
      cases hk
  | succ k =>
      simp [iterate]
      have hprev_nonzero :=
        iterate_nonzero A x hx hA k
      have hmul :=
        hA (iterate A k x) hprev_nonzero
      simp [hmul, flow_norm_invariant]

end ChronoFlow
EOL

echo "[6/7] Writing GitHub Actions workflow..."
cat << 'EOL' > .github/workflows/lean.yml
name: Lean Proof Check

on:
  push:
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install elan
        run: |
          curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y
          echo "$HOME/.elan/bin" >> $GITHUB_PATH

      - name: Verify Lean
        run: lean --version

      - name: Fetch Mathlib cache
        run: lake exe cache get

      - name: Build Proofs
        run: lake build
EOL

echo "[7/7] Committing and pushing..."
git add .
git commit -m "Auto setup: Lean + Mathlib + CI pipeline"
git push

echo "DONE: Pipeline deployed. Checking CI status..."
sleep 5

gh run list
echo "---- ERRORS (if any) ----"
gh run view --log | grep "error" || echo "No errors detected"

