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
