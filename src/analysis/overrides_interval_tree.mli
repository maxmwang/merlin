(** This [Interval_tree] is an immutable data structure that stores mappings from integer
    intervals to values ['a] and allows efficient queries for intervals that contain a
    given point.

    This is the minimal interface to support querying [[@@@merlin]] overrides by cursor
    position. Common functions, such as [insert], are left unimplemented since
    they are not necessary, but are possibly easy to include. *)
module Inteval_tree : sig
  type 'a t

  (** Find the first interval that contains a given integer point. Runs with logarithmic
      asymptotic time complexity.  *)
  val find : 'a t -> int -> 'a

  (** Constructs a [t] given a list of intervals and payloads. *)
  val of_alist : ((int * int) * 'a) list -> 'a t
end
