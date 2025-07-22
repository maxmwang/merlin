(** Decodes the [@@@merlin.document] attribute into a list.

    The [@@@merlin.document] attribute is a list of tuples pairing a [Location.t] with
    a documentation string. This attribute can be used to override merlin's [Document]
    behavior.

    The expected structure of [@@@merlin.document]'s payload is as follows:
    {|
      [
        (
          {
            "loc_start" = { pos_fname = "filename.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 0}
            "loc_end" = { pos_fname = "filename.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 0}
            "loc_ghost" = false
          },
          "<docstring>"
        );
        ...
      ]
    |}
    Each individual element of the list is stored as an [Override.t].
*)

module Override : sig
  type t = { loc : Location.t; doc : string }
end

type t = Override.t list

(** Constructs a [t] from a [Mpipeline.t]. An error is returned on an unexpected
    AST node structures and parsing errors. *)
val get_overrides : Mpipeline.t -> t

(** Finds the first [Override.t] that [cursor] is enclosed in. *)
val find : t -> cursor:Lexing.position -> Override.t option
