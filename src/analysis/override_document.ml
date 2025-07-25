open Std

let { Logger.log } = Logger.for_section "override_document"

let error_failed_to_parse_position_field_values =
  Error "failed to parse position field values"

let error_unexpected_position_expression_structure =
  Error "unexpected position expression structure"

let error_unexpected_merlin_document_attribute_structure =
  Error "unexpected merlin.document attribute structure"

module Override = struct
  type t = { loc : Location.t; doc : string }

  let expr_to_pos ({ pexp_desc; _ } : Parsetree.expression) =
    match pexp_desc with
    | Pexp_record
        ( [ ( { txt = Lident "pos_fname"; _ },
              { pexp_desc = Pexp_constant (Pconst_string (pos_fname, _, _)); _ }
            );
            ( { txt = Lident "pos_lnum"; _ },
              { pexp_desc = Pexp_constant (Pconst_integer (lnum, None)); _ } );
            ( { txt = Lident "pos_bol"; _ },
              { pexp_desc = Pexp_constant (Pconst_integer (bol, None)); _ } );
            ( { txt = Lident "pos_cnum"; _ },
              { pexp_desc = Pexp_constant (Pconst_integer (cnum, None)); _ } )
          ],
          None ) -> (
      match
        (int_of_string_opt lnum, int_of_string_opt bol, int_of_string_opt cnum)
      with
      | Some pos_lnum, Some pos_bol, Some pos_cnum ->
        Ok { Lexing.pos_fname; pos_lnum; pos_bol; pos_cnum }
      | _ -> error_failed_to_parse_position_field_values)
    | _ -> error_unexpected_position_expression_structure

  let of_expression ({ pexp_desc; _ } : Parsetree.expression) =
    match pexp_desc with
    | Pexp_tuple
        [ ( None,
            { pexp_desc =
                Pexp_record
                  ( [ ({ txt = Lident "loc_start"; _ }, loc_start_expr);
                      ({ txt = Lident "loc_end"; _ }, loc_end_expr);
                      ({ txt = Lident "loc_ghost"; _ }, loc_ghost_expr)
                    ],
                    None );
              _
            } );
          ( None,
            { pexp_desc = Pexp_constant (Pconst_string (documentation, _, _));
              _
            } )
        ] ->
      let open Misc_stdlib.Monad.Result.Syntax in
      let* loc_start = expr_to_pos loc_start_expr in
      let* loc_end = expr_to_pos loc_end_expr in
      let* loc_ghost =
        match loc_ghost_expr.pexp_desc with
        | Pexp_construct ({ txt = Lident "false"; _ }, None) -> Ok false
        | Pexp_construct ({ txt = Lident "true"; _ }, None) -> Ok true
        | _ -> error_failed_to_parse_position_field_values
      in
      Ok
        { loc = { Location.loc_start; loc_end; loc_ghost };
          doc = documentation
        }
    | _ -> error_unexpected_merlin_document_attribute_structure

  let is_target_override t ~cursor =
    Lexing.compare_pos cursor t.loc.loc_start >= 0
    && Lexing.compare_pos cursor t.loc.loc_end <= 0

  let doc t = t.doc
end

type t = Override.t list

let rec of_payload ({ pexp_desc; _ } : Parsetree.expression) =
  match pexp_desc with
  | Pexp_construct
      ( { txt = Lident "::"; _ },
        Some { pexp_desc = Pexp_tuple [ (None, override); (None, rest) ]; _ } )
    -> (
    match Override.of_expression override with
    | Ok override -> override :: of_payload rest
    | Error err ->
      log ~title:"of_payload" "%s" err;
      of_payload rest)
  | _ -> []

let of_attribute (attribute : Parsetree.attribute) =
  match attribute with
  | { attr_payload = PStr [ { pstr_desc = Pstr_eval (expr, _); _ } ]; _ } ->
    Ok (of_payload expr)
  | _ -> error_unexpected_merlin_document_attribute_structure

let get_overrides pipeline =
  let attributes =
    match Mpipeline.ppx_parsetree pipeline with
    | `Interface signature ->
      List.filter_map signature.psg_items
        ~f:(fun (signature_item : Parsetree.signature_item) ->
          match signature_item.psig_desc with
          | Psig_attribute
              ({ attr_name = { txt = "merlin.document"; _ }; _ } as attr) ->
            Some attr
          | _ -> None)
    | `Implementation structure ->
      List.filter_map structure
        ~f:(fun (structure_item : Parsetree.structure_item) ->
          match structure_item.pstr_desc with
          | Pstr_attribute
              ({ attr_name = { txt = "merlin.document"; _ }; _ } as attr) ->
            Some attr
          | _ -> None)
  in
  List.concat_map attributes ~f:(fun attribute ->
      match of_attribute attribute with
      | Ok overrides -> overrides
      | Error err ->
        log ~title:"get_overrides" "%s" err;
        [])

let find t ~cursor =
  match List.find_all ~f:(Override.is_target_override ~cursor) t with
  | [] -> None
  | override :: [] -> Some override
  | override :: _ :: _ ->
    log ~title:"find" "found multiple target overrides, using first target";
    Some override
