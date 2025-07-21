open Std

let error_failed_to_parse_position = Error "failed to parse position"

let error_unexpected_merlin_document_attribute_structure =
  Error "unexpected merlin.document attribute structure"

module Entry = struct
  module Location = struct
    type t =
      { loc_start : Lexing.position;
        loc_end : Lexing.position;
        loc_ghost : bool
      }
  end

  type t = Location.t * string

  let expr_to_pos ({ pexp_desc; _ } : Parsetree.expression) =
    match pexp_desc with
    | Pexp_record
        ( [ ( _,
              { pexp_desc = Pexp_constant (Pconst_string (pos_fname, _, _)); _ }
            );
            (_, { pexp_desc = Pexp_constant (Pconst_integer (lnum, _)); _ });
            (_, { pexp_desc = Pexp_constant (Pconst_integer (bol, _)); _ });
            (_, { pexp_desc = Pexp_constant (Pconst_integer (cnum, _)); _ })
          ],
          _ ) -> (
      match
        (int_of_string_opt lnum, int_of_string_opt bol, int_of_string_opt cnum)
      with
      | Some pos_lnum, Some pos_bol, Some pos_cnum ->
        Ok { Lexing.pos_fname; pos_lnum; pos_bol; pos_cnum }
      | _ -> error_failed_to_parse_position)
    | _ -> error_failed_to_parse_position

  let of_expression (expr : Parsetree.expression) =
    match expr.pexp_desc with
    | Pexp_tuple
        [ ( _,
            { pexp_desc =
                Pexp_record
                  ( [ ({ txt = Lident "loc_start"; _ }, loc_start_expr);
                      ({ txt = Lident "loc_end"; _ }, loc_end_expr);
                      ({ txt = Lident "loc_ghost"; _ }, loc_ghost_expr)
                    ],
                    None );
              _
            } );
          ( _,
            { pexp_desc = Pexp_constant (Pconst_string (documentation, _, _));
              _
            } )
        ] -> (
      let loc_start = expr_to_pos loc_start_expr in
      let loc_end = expr_to_pos loc_end_expr in
      let loc_ghost =
        match loc_ghost_expr.pexp_desc with
        | Pexp_construct ({ txt = Lident "false"; _ }, None) -> Ok false
        | Pexp_construct ({ txt = Lident "true"; _ }, None) -> Ok true
        | _ -> error_failed_to_parse_position
      in
      match (loc_start, loc_end, loc_ghost) with
      | Ok loc_start, Ok loc_end, Ok loc_ghost ->
        Ok ({ Location.loc_start; loc_end; loc_ghost }, documentation)
      | _ -> error_failed_to_parse_position)
    | _ -> error_unexpected_merlin_document_attribute_structure

  let is_target_entry ((loc, _) : t) ~cursor =
    Lexing.compare_pos cursor loc.loc_start >= 0
    && Lexing.compare_pos cursor loc.loc_end <= 0

  let documentation (t : t) =
    let _, doc = t in
    doc
end

type t = Entry.t list

let rec of_payload (payload : Parsetree.expression) =
  match payload.pexp_desc with
  | Pexp_construct
      ( { txt = Lident "::"; _ },
        Some { pexp_desc = Pexp_tuple [ (None, entry); (None, rest) ]; _ } )
    -> (
    match Entry.of_expression entry with
    | Ok entry -> entry :: of_payload rest
    | Error _ -> of_payload rest)
  | _ -> []

let of_attribute (attribute : Parsetree.attribute) =
  match attribute with
  | { attr_payload = PStr ({ pstr_desc = Pstr_eval (expr, _); _ } :: []); _ } ->
    Ok (of_payload expr)
  | _ -> error_unexpected_merlin_document_attribute_structure

let find t ~cursor = List.find_opt ~f:(Entry.is_target_entry ~cursor) t
