#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[1/15] Verifying git repo..."
if [ ! -d ".git" ]; then
  echo "ERROR: Not inside a git repository"
  exit 1
fi

echo "[2/15] Ensuring main branch..."
git branch -M main
git push -u origin main || true

echo "[3/15] Creating project structure..."
mkdir -p ChronoFlow
mkdir -p Certified
mkdir -p .github/workflows

echo "[4/15] Writing lakefile.lean..."
cat << 'EOL' > lakefile.lean
import Lake
open Lake DSL

package «chronoflow» where

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git"
EOL

echo "[5/15] Writing lean-toolchain placeholder..."
# initial placeholder; CI will auto-sync
echo "leanprover/lean4:stable" > lean-toolchain

echo "[6/15] Writing GitHub Actions workflow for deterministic certified proofs..."
cat << 'EOL' > .github/workflows/lean.yml
name: Lean Certified Proof Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Lean via elan
        run: |
          curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y
          echo "$HOME/.elan/bin" >> $GITHUB_PATH

      - name: Sync Mathlib Toolchain
        run: |
          cp .lake/packages/mathlib/lean-toolchain ./lean-toolchain || true
          cat lean-toolchain
          source $HOME/.elan/env || true
          elan install $(cat lean-toolchain)
          elan default $(cat lean-toolchain)

      - name: Fetch Mathlib Cache
        run: lake exe cache get

      - name: Build all proofs
        run: |
          for file in ChronoFlow/*.lean; do
            echo "Building proof $file..."
            if lake build --file "$file"; then
              echo "$file fully type-checked, moving to Certified..."
              cp "$file" Certified/
            else
              echo "ERROR: $file failed type-check"
              exit 1
            fi
          done

      - name: Final list of certified proofs
        run: ls -1 Certified
EOL

echo "[7/15] Adding initial proof template..."
# Add a minimal example proof file if none exists
if [ ! -f ChronoFlow/Basic.lean ]; then
cat << 'EOL' > ChronoFlow/Basic.lean
import Mathlib.Analysis.NormedSpace.Basic
import Mathlib.Analysis.InnerProductSpace.Basic

namespace ExampleProof

theorem zero_plus_zero : 0 + 0 = (0 : Nat) := by
  rfl

end ExampleProof
EOL
fi

echo "[8/15] Git add and commit initial setup..."
git add .
git commit -m "Setup deterministic Lean certified proof pipeline" || true

echo "[9/15] Pushing initial setup to main..."
git push origin main || true

echo "[10/15] Fixing Mathlib toolchain locally..."
if [ -f ".lake/packages/mathlib/lean-toolchain" ]; then
    cp .lake/packages/mathlib/lean-toolchain ./lean-toolchain
    cat lean-toolchain
    source $HOME/.elan/env || true
    elan install $(cat lean-toolchain)
    elan default $(cat lean-toolchain)
fi

echo "[11/15] Fetching Mathlib cache..."
lake exe cache get || true

echo "[12/15] Building proofs locally for deterministic check..."
for file in ChronoFlow/*.lean; do
  echo "Building proof $file..."
  if lake build --file "$file"; then
    echo "$file fully type-checked, moving to Certified..."
    cp "$file" Certified/
  else
    echo "ERROR: $file failed type-check"
  fi
done

echo "[13/15] Listing all certified proofs..."
ls -1 Certified

echo "[14/15] Final commit of certified proofs..."
git add Certified
git commit -m "Add certified proofs" || true
git push origin main || true

echo "[15/15] Pipeline setup complete! You can add new proofs to ChronoFlow/ and push; fully verified proofs will go to Certified/ automatically."
