(** This [Interval_tree] is an immutable data structure that stores mappings from integer
    intervals to values ['a] and allows efficient queries for intervals that contain a
    given point.

    [Interval_tree] assumes that input intervals have a total ordering, such as AST node
    locations.

    This is the minimal interface to support querying [[@@@merlin]] overrides by cursor
    position. Common functions, such as [insert] and [delete], are left unimplemented since
    they are not necessary, but are possibly easy to include. *)

module Interval : sig
  type 'a t

  (** [low] is included in the range. [high] is excluded from the range. *)
  val create : low:int -> high:int -> payload:'a -> 'a t
end

type 'a t

(** Find the tightest interval that contains a given integer point. Runs with logarithmic
    asymptotic time complexity.

    [Interval_tree] assumes a total ordering. Ties imply equivalence, and we return the
    first. *)
val find : 'a t -> int -> 'a option

(** Constructs a ['a t] given a list of ['a Interval.t]. Raises on empty lists. *)
val of_alist_exn : 'a Interval.t list -> 'a t
