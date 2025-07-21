module Entry : sig
  type t =
    { loc_start : Lexing.position;
      loc_end : Lexing.position;
      documentation : string
    }
end

type t = Entry.t list

val of_attribute : Parsetree.attribute -> (t, string) result

val find : t -> cursor:Lexing.position -> Entry.t option
