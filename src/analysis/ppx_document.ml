open Std

type t = (Lexing.position * string) list Lazy.t

let is_between_positions pos ~left ~right =
  Lexing.compare_pos pos left >= 0 && Lexing.compare_pos pos right <= 0

let pos_record_expr_to_pos ({ pexp_desc; _ } : Parsetree.expression) =
  match pexp_desc with
  | Pexp_record
      ( (_, { pexp_desc = Pexp_constant (Pconst_string (fname, _)); _ })
        :: (_, { pexp_desc = Pexp_constant (Pconst_integer (pos_lnum, _)); _ })
        :: (_, { pexp_desc = Pexp_constant (Pconst_integer (pos_bol, _)); _ })
        :: (_, { pexp_desc = Pexp_constant (Pconst_integer (pos_cnum, _)); _ })
        :: _,
        _ ) -> int_of_string_opt i
  | _ -> None
