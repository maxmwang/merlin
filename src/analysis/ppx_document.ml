open Std

let to_position ~pos_fname ~pos_lnum ~pos_bol ~pos_cnum =
  match (pos_lnum, pos_bol, pos_cnum) with
  | Some pos_lnum, Some pos_bol, Some pos_cnum ->
    Ok { Lexing.pos_fname; pos_lnum; pos_bol; pos_cnum }
  | _ -> Error "failed to parse position"

let pos_record_expr_to_pos ({ pexp_desc; _ } : Parsetree.expression) =
  match pexp_desc with
  | Pexp_record
      ( (_, { pexp_desc = Pexp_constant (Pconst_string (pos_fname, _, _)); _ })
        :: (_, { pexp_desc = Pexp_constant (Pconst_integer (pos_lnum, _)); _ })
        :: (_, { pexp_desc = Pexp_constant (Pconst_integer (pos_bol, _)); _ })
        :: (_, { pexp_desc = Pexp_constant (Pconst_integer (pos_cnum, _)); _ })
        :: _,
        _ ) ->
    to_position ~pos_fname
      ~pos_lnum:(int_of_string_opt pos_lnum)
      ~pos_bol:(int_of_string_opt pos_bol)
      ~pos_cnum:(int_of_string_opt pos_cnum)
  | _ -> Error "failed to parse position"

module Entry = struct
  type t =
    { loc_start : Lexing.position;
      loc_end : Lexing.position;
      documentation : string
    }

  let of_expression (expr : Parsetree.expression) =
    match expr.pexp_desc with
    | Pexp_tuple
        (( _,
           { pexp_desc =
               Pexp_record ((_, loc_start_record) :: (_, loc_end_record) :: _, _);
             _
           } )
        :: ( _,
             { pexp_desc = Pexp_constant (Pconst_string (documentation, _, _));
               _
             } )
        :: _) -> (
      let loc_start = pos_record_expr_to_pos loc_start_record in
      let loc_end = pos_record_expr_to_pos loc_end_record in
      match (loc_start, loc_end) with
      | Ok loc_start, Ok loc_end -> Ok { loc_start; loc_end; documentation }
      | _ -> Error "failed to parse position of merlin.document attribute entry"
      )
    | _ -> Error "unexpected merlin.document attribute structure"

  let is_target_entry t ~cursor =
    Lexing.compare_pos cursor t.loc_start >= 0
    && Lexing.compare_pos cursor t.loc_end <= 0
end

type t = Entry.t list

let rec of_payload (payload : Parsetree.expression) =
  match payload.pexp_desc with
  | Pexp_construct
      ( { txt = Lident "::"; _ },
        Some { pexp_desc = Pexp_tuple ((_, entry) :: (_, rest) :: _); _ } ) -> (
    match Entry.of_expression entry with
    | Ok entry -> entry :: of_payload rest
    | Error _ -> of_payload rest)
  | _ -> []

let of_attribute (attribute : Parsetree.attribute) =
  match attribute with
  | { attr_payload = PStr ({ pstr_desc = Pstr_eval (expr, _); _ } :: _); _ } ->
    Ok (of_payload expr)
  | _ -> Error "unexpected merlin.document attribute structure"

let find t ~cursor = List.find_opt ~f:(Entry.is_target_entry ~cursor) t
