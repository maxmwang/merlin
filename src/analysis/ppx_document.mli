(** Decodes the [@@@merlin.document] attribute into a list. The expected structure is
    reflected in [t]:

    {|
      type t = (Location.t * string) list
    |} *)
module Entry : sig
  module Location : sig
    type t =
      { loc_start : Lexing.position;
        loc_end : Lexing.position;
        loc_ghost : bool
      }
  end

  type t

  val documentation : t -> string
end

type t = Entry.t list

(** Constructs a [t] from a [Parsetree.attribute]. An error is returned when an
    unexpected structure is encountered or if there is an error parsing position data. *)
val of_attribute : Parsetree.attribute -> (t, string) result

(** Finds the first [Entry.t] that [cursor] is enclosed in. *)
val find : t -> cursor:Lexing.position -> Entry.t option
