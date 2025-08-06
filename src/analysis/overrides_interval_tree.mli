(** This interval tree is an immutable data structure that stores mappings from integer
    intervals to values ['a] and allows efficient queries for intervals that contain a
    given point.

    Interval tree assumes that input intervals have a total ordering, such as AST node
    locations.

    This is the minimal interface to support querying [[@@@merlin]] overrides by cursor
    position. Common functions, such as [insert] and [delete], are left unimplemented since
    they are not necessary, but are possibly easy to include.

    The general design of the data structure is on
    {{:https://en.wikipedia.org/wiki/Interval_tree#Centered_interval_tree}this wiki page}. *)

module Interval : sig
  type 'a t

  (** [low] is included in the range. [high] is excluded from the range. Raises if input
      [low] > [high]. *)
  val create : low:int -> high:int -> payload:'a -> 'a t
end

type 'a t

(** Find the tightest interval that contains a given integer point.

    [find] assumes a total ordering. Ties imply equivalence, and we return the
    first. Without total ordering, the interval with the lowest [low] is chosen. *)
val find : 'a t -> int -> 'a option

(** Constructs a ['a t] given a list of ['a Interval.t]. Raises on empty lists. *)
val of_alist_exn : 'a Interval.t list -> 'a t
