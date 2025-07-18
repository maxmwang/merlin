(*************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*              Damien Doligez, projet Para, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1999 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open Asttypes
open Format
open Lexing
open Location
open Parsetree

let fmt_position with_name f l =
  let fname = if with_name then l.pos_fname else "" in
  if l.pos_lnum = -1
  then fprintf f "%s[%d]" fname l.pos_cnum
  else fprintf f "%s[%d,%d+%d]" fname l.pos_lnum l.pos_bol
               (l.pos_cnum - l.pos_bol)


let fmt_location f loc =
  if not !Clflags.locations then ()
  else begin
    let p_2nd_name = loc.loc_start.pos_fname <> loc.loc_end.pos_fname in
    fprintf f "(%a..%a)" (fmt_position true) loc.loc_start
                         (fmt_position p_2nd_name) loc.loc_end;
    if loc.loc_ghost then fprintf f " ghost";
  end


let rec fmt_longident_aux f x =
  match x with
  | Longident.Lident (s) -> fprintf f "%s" s
  | Longident.Ldot (y, s) -> fprintf f "%a.%s" fmt_longident_aux y s
  | Longident.Lapply (y, z) ->
      fprintf f "%a(%a)" fmt_longident_aux y fmt_longident_aux z

let fmt_longident f x = fprintf f "\"%a\"" fmt_longident_aux x

let fmt_longident_loc f (x : Longident.t loc) =
  fprintf f "\"%a\" %a" fmt_longident_aux x.txt fmt_location x.loc

let fmt_string_loc f (x : string loc) =
  fprintf f "\"%s\" %a" x.txt fmt_location x.loc

let fmt_str_opt_loc f (x : string option loc) =
  fprintf f "\"%s\" %a" (Option.value x.txt ~default:"_") fmt_location x.loc

let fmt_char_option f = function
  | None -> fprintf f "None"
  | Some c -> fprintf f "Some %c" c

let fmt_constant f x =
  match x with
  | Pconst_integer (i,m) -> fprintf f "PConst_int (%s,%a)" i fmt_char_option m
  | Pconst_unboxed_integer (i,m) -> fprintf f "PConst_unboxed_int (%s,%c)" i m
  | Pconst_char (c) -> fprintf f "PConst_char %02x" (Char.code c)
  | Pconst_string (s, strloc, None) ->
      fprintf f "PConst_string(%S,%a,None)" s fmt_location strloc
  | Pconst_string (s, strloc, Some delim) ->
      fprintf f "PConst_string (%S,%a,Some %S)" s fmt_location strloc delim
  | Pconst_float (s,m) -> fprintf f "PConst_float (%s,%a)" s fmt_char_option m
  | Pconst_unboxed_float (s,m) ->
      fprintf f "PConst_unboxed_float (%s,%a)" s fmt_char_option m

let fmt_mutable_flag f x =
  match x with
  | Immutable -> fprintf f "Immutable"
  | Mutable -> fprintf f "Mutable"

let fmt_virtual_flag f x =
  match x with
  | Virtual -> fprintf f "Virtual"
  | Concrete -> fprintf f "Concrete"

let fmt_override_flag f x =
  match x with
  | Override -> fprintf f "Override"
  | Fresh -> fprintf f "Fresh"

let fmt_closed_flag f x =
  match x with
  | Closed -> fprintf f "Closed"
  | Open -> fprintf f "Open"

let fmt_rec_flag f x =
  match x with
  | Nonrecursive -> fprintf f "Nonrec"
  | Recursive -> fprintf f "Rec"

let fmt_direction_flag f x =
  match x with
  | Upto -> fprintf f "Up"
  | Downto -> fprintf f "Down"

let fmt_private_flag f x =
  match x with
  | Public -> fprintf f "Public"
  | Private -> fprintf f "Private"

let line i f s (*...*) =
  fprintf f "%s" (String.make ((2*i) mod 72) ' ');
  fprintf f s (*...*)

let list i f ppf l =
  match l with
  | [] -> line i ppf "[]\n"
  | _ :: _ ->
     line i ppf "[\n";
     List.iter (f (i+1) ppf) l;
     line i ppf "]\n"

let option i f ppf x =
  match x with
  | None -> line i ppf "None\n"
  | Some x ->
      line i ppf "Some\n";
      f (i+1) ppf x

let longident_loc i ppf li = line i ppf "%a\n" fmt_longident_loc li
let string i ppf s = line i ppf "\"%s\"\n" s
let string_loc i ppf s = line i ppf "%a\n" fmt_string_loc s
let str_opt_loc i ppf s = line i ppf "%a\n" fmt_str_opt_loc s
let arg_label i ppf = function
  | Nolabel -> line i ppf "Nolabel\n"
  | Optional s -> line i ppf "Optional \"%s\"\n" s
  | Labelled s -> line i ppf "Labelled \"%s\"\n" s


let modality i ppf modality =
  line i ppf "modality %a\n" fmt_string_loc
    (Location.map (fun (Modality x) -> x) modality)

let modalities i ppf modalities =
  List.iter (fun m -> modality i ppf m) modalities

let mode i ppf mode =
  line i ppf "mode %a\n" fmt_string_loc
    (Location.map (fun (Mode x) -> x) mode)

let modes i ppf modes =
  List.iter (fun m -> mode i ppf m) modes

let include_kind i ppf = function
  | Structure -> line i ppf "Structure\n"
  | Functor -> line i ppf "Functor\n"

let labeled_tuple_element f i ppf (l, ct) =
  option i string ppf l;
  f i ppf ct

let rec core_type i ppf x =
  line i ppf "core_type %a\n" fmt_location x.ptyp_loc;
  attributes i ppf x.ptyp_attributes;
  let i = i+1 in
  match x.ptyp_desc with
  | Ptyp_any jkind ->
      line i ppf "Ptyp_any\n";
      jkind_annotation_opt (i+1) ppf jkind
  | Ptyp_var (s, jkind) ->
      line i ppf "Ptyp_var %s\n" s;
      jkind_annotation_opt (i+1) ppf jkind
  | Ptyp_arrow (l, ct1, ct2, m1, m2) ->
      line i ppf "Ptyp_arrow\n";
      arg_label i ppf l;
      core_type i ppf ct1;
      modes i ppf m1;
      core_type i ppf ct2;
      modes i ppf m2;
  | Ptyp_tuple l ->
      line i ppf "Ptyp_tuple\n";
      list i (labeled_tuple_element core_type) ppf l;
  | Ptyp_unboxed_tuple l ->
      line i ppf "Ptyp_unboxed_tuple\n";
      list i (labeled_tuple_element core_type) ppf l
  | Ptyp_constr (li, l) ->
      line i ppf "Ptyp_constr %a\n" fmt_longident_loc li;
      list i core_type ppf l;
  | Ptyp_variant (l, closed, low) ->
      line i ppf "Ptyp_variant closed=%a\n" fmt_closed_flag closed;
      list i label_x_bool_x_core_type_list ppf l;
      option i (fun i -> list i string) ppf low
  | Ptyp_object (l, c) ->
      line i ppf "Ptyp_object %a\n" fmt_closed_flag c;
      let i = i + 1 in
      List.iter (fun field ->
        match field.pof_desc with
          | Otag (l, t) ->
            line i ppf "method %s\n" l.txt;
            attributes i ppf field.pof_attributes;
            core_type (i + 1) ppf t
          | Oinherit ct ->
              line i ppf "Oinherit\n";
              core_type (i + 1) ppf ct
      ) l
  | Ptyp_class (li, l) ->
      line i ppf "Ptyp_class %a\n" fmt_longident_loc li;
      list i core_type ppf l
  | Ptyp_alias (ct, s, jkind) ->
      line i ppf "Ptyp_alias %a\n"
        (fun ppf -> function
           | None -> fprintf ppf "_"
           | Some name -> fprintf ppf "\"%s\"" name.txt)
        s;
      core_type i ppf ct;
      jkind_annotation_opt i ppf jkind
  | Ptyp_poly (sl, ct) ->
      line i ppf "Ptyp_poly\n";
      list i typevar ppf sl;
      core_type i ppf ct;
  | Ptyp_package (s, l) ->
      line i ppf "Ptyp_package %a\n" fmt_longident_loc s;
      list i package_with ppf l;
  | Ptyp_open (mod_ident, t) ->
      line i ppf "Ptyp_open \"%a\"\n" fmt_longident_loc mod_ident;
      core_type i ppf t
  | Ptyp_of_kind jkind ->
    line i ppf "Ptyp_of_kind %a\n" (jkind_annotation (i + 1)) jkind
  | Ptyp_extension (s, arg) ->
      line i ppf "Ptyp_extension \"%s\"\n" s.txt;
      payload i ppf arg

and typevar i ppf (s, jkind) =
  line i ppf "var: %s\n" s.txt;
  jkind_annotation_opt (i+1) ppf jkind

and package_with i ppf (s, t) =
  line i ppf "with type %a\n" fmt_longident_loc s;
  core_type i ppf t

and pattern i ppf x =
  line i ppf "pattern %a\n" fmt_location x.ppat_loc;
  attributes i ppf x.ppat_attributes;
  let i = i+1 in
  match x.ppat_desc with
  | Ppat_any -> line i ppf "Ppat_any\n";
  | Ppat_var (s) -> line i ppf "Ppat_var %a\n" fmt_string_loc s;
  | Ppat_alias (p, s) ->
      line i ppf "Ppat_alias %a\n" fmt_string_loc s;
      pattern i ppf p;
  | Ppat_constant (c) -> line i ppf "Ppat_constant %a\n" fmt_constant c;
  | Ppat_interval (c1, c2) ->
      line i ppf "Ppat_interval %a..%a\n" fmt_constant c1 fmt_constant c2;
  | Ppat_tuple (l, c) ->
      line i ppf "Ppat_tuple\n %a\n" fmt_closed_flag c;
      list i (labeled_tuple_element pattern) ppf l
  | Ppat_unboxed_tuple (l, c) ->
      line i ppf "Ppat_unboxed_tuple %a\n" fmt_closed_flag c;
      list i (labeled_tuple_element pattern) ppf l
  | Ppat_construct (li, po) ->
      line i ppf "Ppat_construct %a\n" fmt_longident_loc li;
      option i
        (fun i ppf (vl, p) ->
          list i
            (fun i ppf (v, jk) ->
               string_loc i ppf v;
               jkind_annotation_opt i ppf jk)
            ppf vl;
          pattern i ppf p)
        ppf po
  | Ppat_variant (l, po) ->
      line i ppf "Ppat_variant \"%s\"\n" l;
      option i pattern ppf po;
  | Ppat_record (l, c) ->
      line i ppf "Ppat_record %a\n" fmt_closed_flag c;
      list i longident_x_pattern ppf l;
  | Ppat_record_unboxed_product (l, c) ->
      line i ppf "Ppat_record_unboxed_product %a\n" fmt_closed_flag c;
      list i longident_x_pattern ppf l;
  | Ppat_array (mut, l) ->
      line i ppf "Ppat_array %a\n" fmt_mutable_flag mut;
      list i pattern ppf l;
  | Ppat_or (p1, p2) ->
      line i ppf "Ppat_or\n";
      pattern i ppf p1;
      pattern i ppf p2;
  | Ppat_lazy p ->
      line i ppf "Ppat_lazy\n";
      pattern i ppf p;
  | Ppat_constraint (p, ct, m) ->
      line i ppf "Ppat_constraint\n";
      pattern i ppf p;
      Option.iter (core_type i ppf) ct;
      modes i ppf m;
  | Ppat_type (li) ->
      line i ppf "Ppat_type\n";
      longident_loc i ppf li
  | Ppat_unpack s ->
      line i ppf "Ppat_unpack %a\n" fmt_str_opt_loc s;
  | Ppat_exception p ->
      line i ppf "Ppat_exception\n";
      pattern i ppf p
  | Ppat_open (m,p) ->
      line i ppf "Ppat_open \"%a\"\n" fmt_longident_loc m;
      pattern i ppf p
  | Ppat_extension (s, arg) ->
      line i ppf "Ppat_extension \"%s\"\n" s.txt;
      payload i ppf arg

and expression i ppf x =
  line i ppf "expression %a\n" fmt_location x.pexp_loc;
  attributes i ppf x.pexp_attributes;
  let i = i+1 in
  match x.pexp_desc with
  | Pexp_ident (li) -> line i ppf "Pexp_ident %a\n" fmt_longident_loc li;
  | Pexp_constant (c) -> line i ppf "Pexp_constant %a\n" fmt_constant c;
  | Pexp_let (rf, l, e) ->
      line i ppf "Pexp_let %a\n" fmt_rec_flag rf;
      list i value_binding ppf l;
      expression i ppf e;
  | Pexp_function (params, c, body) ->
      line i ppf "Pexp_function\n";
      list i function_param ppf params;
      function_constraint i ppf c;
      function_body i ppf body
  | Pexp_apply (e, l) ->
      line i ppf "Pexp_apply\n";
      expression i ppf e;
      list i label_x_expression ppf l;
  | Pexp_match (e, l) ->
      line i ppf "Pexp_match\n";
      expression i ppf e;
      list i case ppf l;
  | Pexp_try (e, l) ->
      line i ppf "Pexp_try\n";
      expression i ppf e;
      list i case ppf l;
  | Pexp_tuple (l) ->
      line i ppf "Pexp_tuple\n";
      list i (labeled_tuple_element expression) ppf l;
  | Pexp_unboxed_tuple (l) ->
      line i ppf "Pexp_unboxed_tuple\n";
      list i (labeled_tuple_element expression) ppf l;
  | Pexp_construct (li, eo) ->
      line i ppf "Pexp_construct %a\n" fmt_longident_loc li;
      option i expression ppf eo;
  | Pexp_variant (l, eo) ->
      line i ppf "Pexp_variant \"%s\"\n" l;
      option i expression ppf eo;
  | Pexp_record (l, eo) ->
      line i ppf "Pexp_record\n";
      list i longident_x_expression ppf l;
      option i expression ppf eo;
  | Pexp_record_unboxed_product (l, eo) ->
      line i ppf "Pexp_record_unboxed_product\n";
      list i longident_x_expression ppf l;
      option i expression ppf eo;
  | Pexp_field (e, li) ->
      line i ppf "Pexp_field\n";
      expression i ppf e;
      longident_loc i ppf li;
  | Pexp_unboxed_field (e, li) ->
      line i ppf "Pexp_unboxed_field\n";
      expression i ppf e;
      longident_loc i ppf li;
  | Pexp_setfield (e1, li, e2) ->
      line i ppf "Pexp_setfield\n";
      expression i ppf e1;
      longident_loc i ppf li;
      expression i ppf e2;
  | Pexp_array (mut, l) ->
      line i ppf "Pexp_array %a\n" fmt_mutable_flag mut;
      list i expression ppf l;
  | Pexp_ifthenelse (e1, e2, eo) ->
      line i ppf "Pexp_ifthenelse\n";
      expression i ppf e1;
      expression i ppf e2;
      option i expression ppf eo;
  | Pexp_sequence (e1, e2) ->
      line i ppf "Pexp_sequence\n";
      expression i ppf e1;
      expression i ppf e2;
  | Pexp_while (e1, e2) ->
      line i ppf "Pexp_while\n";
      expression i ppf e1;
      expression i ppf e2;
  | Pexp_for (p, e1, e2, df, e3) ->
      line i ppf "Pexp_for %a\n" fmt_direction_flag df;
      pattern i ppf p;
      expression i ppf e1;
      expression i ppf e2;
      expression i ppf e3;
  | Pexp_constraint (e, ct, m) ->
      line i ppf "Pexp_constraint\n";
      expression i ppf e;
      Option.iter (core_type i ppf) ct;
      modes i ppf m;
  | Pexp_coerce (e, cto1, cto2) ->
      line i ppf "Pexp_coerce\n";
      expression i ppf e;
      option i core_type ppf cto1;
      core_type i ppf cto2;
  | Pexp_send (e, s) ->
      line i ppf "Pexp_send \"%s\"\n" s.txt;
      expression i ppf e;
  | Pexp_new (li) -> line i ppf "Pexp_new %a\n" fmt_longident_loc li;
  | Pexp_setinstvar (s, e) ->
      line i ppf "Pexp_setinstvar %a\n" fmt_string_loc s;
      expression i ppf e;
  | Pexp_override (l) ->
      line i ppf "Pexp_override\n";
      list i string_x_expression ppf l;
  | Pexp_letmodule (s, me, e) ->
      line i ppf "Pexp_letmodule %a\n" fmt_str_opt_loc s;
      module_expr i ppf me;
      expression i ppf e;
  | Pexp_letexception (cd, e) ->
      line i ppf "Pexp_letexception\n";
      extension_constructor i ppf cd;
      expression i ppf e;
  | Pexp_assert (e) ->
      line i ppf "Pexp_assert\n";
      expression i ppf e;
  | Pexp_lazy (e) ->
      line i ppf "Pexp_lazy\n";
      expression i ppf e;
  | Pexp_poly (e, cto) ->
      line i ppf "Pexp_poly\n";
      expression i ppf e;
      option i core_type ppf cto;
  | Pexp_object s ->
      line i ppf "Pexp_object\n";
      class_structure i ppf s
  | Pexp_newtype (s, jkind, e) ->
      line i ppf "Pexp_newtype \"%s\"\n" s.txt;
      jkind_annotation_opt i ppf jkind;
      expression i ppf e
  | Pexp_pack me ->
      line i ppf "Pexp_pack\n";
      module_expr i ppf me
  | Pexp_open (o, e) ->
      line i ppf "Pexp_open %a\n" fmt_override_flag o.popen_override;
      module_expr i ppf o.popen_expr;
      expression i ppf e
  | Pexp_letop {let_; ands; body} ->
      line i ppf "Pexp_letop\n";
      binding_op i ppf let_;
      list i binding_op ppf ands;
      expression i ppf body
  | Pexp_extension (s, arg) ->
      line i ppf "Pexp_extension \"%s\"\n" s.txt;
      payload i ppf arg
  | Pexp_unreachable ->
      line i ppf "Pexp_unreachable"
  | Pexp_stack e ->
      line i ppf "Pexp_stack\n";
      expression i ppf e
  | Pexp_comprehension c ->
      line i ppf "Pexp_comprehension\n";
      comprehension_expression i ppf c
  | Pexp_overwrite (e1, e2) ->
      line i ppf "Pexp_overwrite\n";
      expression i ppf e1;
      expression i ppf e2;
  | Pexp_hole ->
    line i ppf "Pexp_hole"

and comprehension_expression i ppf = function
  | Pcomp_array_comprehension (m, c) ->
      line i ppf "Pcomp_array_comprehension %a\n" fmt_mutable_flag m;
      comprehension i ppf c
  | Pcomp_list_comprehension c ->
      line i ppf "Pcomp_list_comprehension\n";
      comprehension i ppf c

and comprehension i ppf ({ pcomp_body; pcomp_clauses } : comprehension) =
  list i comprehension_clause ppf pcomp_clauses;
  expression i ppf pcomp_body

and comprehension_clause i ppf = function
  | Pcomp_for cbs ->
      line i ppf "Pcomp_for\n";
      list i comprehension_clause_binding ppf cbs
  | Pcomp_when exp ->
      line i ppf "Pcomp_when\n";
      expression i ppf exp

and comprehension_clause_binding i ppf
    { pcomp_cb_pattern; pcomp_cb_iterator; pcomp_cb_attributes }
  =
  pattern i ppf pcomp_cb_pattern;
  comprehension_iterator (i+1) ppf pcomp_cb_iterator;
  attributes i ppf pcomp_cb_attributes

and comprehension_iterator i ppf = function
  | Pcomp_range { start; stop; direction } ->
      line i ppf "Pcomp_range %a\n" fmt_direction_flag direction;
      expression i ppf start;
      expression i ppf stop;
  | Pcomp_in exp ->
      line i ppf "Pcomp_in\n";
      expression i ppf exp

and jkind_annotation_opt i ppf jkind =
  match jkind with
  | None -> ()
  | Some jkind -> jkind_annotation (i+1) ppf jkind

and jkind_annotation i ppf (jkind : jkind_annotation) =
  line i ppf "jkind %a\n" fmt_location jkind.pjkind_loc;
  match jkind.pjkind_desc with
  | Default -> line i ppf "Default\n"
  | Abbreviation jkind ->
      line i ppf "Abbreviation \"%s\"\n" jkind
  | Mod (jkind, m) ->
      line i ppf "Mod\n";
      jkind_annotation (i+1) ppf jkind;
      modes (i+1) ppf m
  | With (jkind, type_, modalities_) ->
      line i ppf "With\n";
      jkind_annotation (i+1) ppf jkind;
      core_type (i+1) ppf type_;
      modalities (i+1) ppf modalities_
  | Kind_of type_ ->
      line i ppf "Kind_of\n";
      core_type (i+1) ppf type_
  | Product jkinds ->
      line i ppf "Product\n";
      list i jkind_annotation ppf jkinds

and function_param i ppf { pparam_desc = desc; pparam_loc = loc } =
  match desc with
  | Pparam_val (l, eo, p) ->
      line i ppf "Pparam_val %a\n" fmt_location loc;
      arg_label (i+1) ppf l;
      option (i+1) expression ppf eo;
      pattern (i+1) ppf p
  | Pparam_newtype (ty, jkind) ->
      line i ppf "Pparam_newtype \"%s\" %a\n" ty.txt fmt_location loc;
      jkind_annotation_opt (i+1) ppf jkind

and function_body i ppf body =
  match body with
  | Pfunction_body e ->
      line i ppf "Pfunction_body\n";
      expression (i+1) ppf e
  | Pfunction_cases (cases, loc, attrs) ->
      line i ppf "Pfunction_cases %a\n" fmt_location loc;
      attributes (i+1) ppf attrs;
      list (i+1) case ppf cases

and type_constraint i ppf type_constraint =
  match type_constraint with
  | Pconstraint ty ->
      line i ppf "Pconstraint\n";
      core_type (i+1) ppf ty
  | Pcoerce (ty1, ty2) ->
      line i ppf "Pcoerce\n";
      option (i+1) core_type ppf ty1;
      core_type (i+1) ppf ty2

and function_constraint i ppf { ret_type_constraint; ret_mode_annotations; mode_annotations = _ } =
  option i type_constraint ppf ret_type_constraint;
  modes i ppf ret_mode_annotations

and value_description i ppf x =
  line i ppf "value_description %a %a\n" fmt_string_loc
       x.pval_name fmt_location x.pval_loc;
  attributes i ppf x.pval_attributes;
  core_type (i+1) ppf x.pval_type;
  modalities (i+1) ppf x.pval_modalities;
  list (i+1) string ppf x.pval_prim

and type_parameter i ppf (x, _variance) = core_type i ppf x

and type_declaration i ppf x =
  line i ppf "type_declaration %a %a\n" fmt_string_loc x.ptype_name
       fmt_location x.ptype_loc;
  attributes i ppf x.ptype_attributes;
  let i = i+1 in
  line i ppf "ptype_params =\n";
  list (i+1) type_parameter ppf x.ptype_params;
  line i ppf "ptype_cstrs =\n";
  list (i+1) core_type_x_core_type_x_location ppf x.ptype_cstrs;
  line i ppf "ptype_kind =\n";
  type_kind (i+1) ppf x.ptype_kind;
  line i ppf "ptype_private = %a\n" fmt_private_flag x.ptype_private;
  line i ppf "ptype_manifest =\n";
  option (i+1) core_type ppf x.ptype_manifest;
  line i ppf "ptype_jkind_annotation =\n";
  option (i+1) jkind_annotation ppf x.ptype_jkind_annotation

and attribute i ppf k a =
  line i ppf "%s \"%s\"\n" k a.attr_name.txt;
  payload i ppf a.attr_payload;

and attributes i ppf l =
  let i = i + 1 in
  List.iter (fun a ->
    line i ppf "attribute \"%s\"\n" a.attr_name.txt;
    payload (i + 1) ppf a.attr_payload;
  ) l;

and payload i ppf = function
  | PStr x -> structure i ppf x
  | PSig x -> signature i ppf x
  | PTyp x -> core_type i ppf x
  | PPat (x, None) -> pattern i ppf x
  | PPat (x, Some g) ->
    pattern i ppf x;
    line i ppf "<when>\n";
    expression (i + 1) ppf g


and type_kind i ppf x =
  match x with
  | Ptype_abstract ->
      line i ppf "Ptype_abstract\n"
  | Ptype_variant l ->
      line i ppf "Ptype_variant\n";
      list (i+1) constructor_decl ppf l;
  | Ptype_record l ->
      line i ppf "Ptype_record\n";
      list (i+1) label_decl ppf l;
  | Ptype_record_unboxed_product l ->
      line i ppf "Ptype_record_unboxed_product\n";
      list (i+1) label_decl ppf l;
  | Ptype_open ->
      line i ppf "Ptype_open\n";

and type_extension i ppf x =
  line i ppf "type_extension\n";
  attributes i ppf x.ptyext_attributes;
  let i = i+1 in
  line i ppf "ptyext_path = %a\n" fmt_longident_loc x.ptyext_path;
  line i ppf "ptyext_params =\n";
  list (i+1) type_parameter ppf x.ptyext_params;
  line i ppf "ptyext_constructors =\n";
  list (i+1) extension_constructor ppf x.ptyext_constructors;
  line i ppf "ptyext_private = %a\n" fmt_private_flag x.ptyext_private;

and type_exception i ppf x =
  line i ppf "type_exception\n";
  attributes i ppf x.ptyexn_attributes;
  let i = i+1 in
  line i ppf "ptyext_constructor =\n";
  let i = i+1 in
  extension_constructor i ppf x.ptyexn_constructor

and extension_constructor i ppf x =
  line i ppf "extension_constructor %a\n" fmt_location x.pext_loc;
  attributes i ppf x.pext_attributes;
  let i = i + 1 in
  line i ppf "pext_name = \"%s\"\n" x.pext_name.txt;
  line i ppf "pext_kind =\n";
  extension_constructor_kind (i + 1) ppf x.pext_kind;

and extension_constructor_kind i ppf x =
  match x with
      Pext_decl(v, a, r) ->
        line i ppf "Pext_decl\n";
        list (i+1) typevar ppf v;
        constructor_arguments (i+1) ppf a;
        option (i+1) core_type ppf r;
    | Pext_rebind li ->
        line i ppf "Pext_rebind\n";
        line (i+1) ppf "%a\n" fmt_longident_loc li;

and class_type i ppf x =
  line i ppf "class_type %a\n" fmt_location x.pcty_loc;
  attributes i ppf x.pcty_attributes;
  let i = i+1 in
  match x.pcty_desc with
  | Pcty_constr (li, l) ->
      line i ppf "Pcty_constr %a\n" fmt_longident_loc li;
      list i core_type ppf l;
  | Pcty_signature (cs) ->
      line i ppf "Pcty_signature\n";
      class_signature i ppf cs;
  | Pcty_arrow (l, co, cl) ->
      line i ppf "Pcty_arrow\n";
      arg_label i ppf l;
      core_type i ppf co;
      class_type i ppf cl;
  | Pcty_extension (s, arg) ->
      line i ppf "Pcty_extension \"%s\"\n" s.txt;
      payload i ppf arg
  | Pcty_open (o, e) ->
      line i ppf "Pcty_open %a %a\n" fmt_override_flag o.popen_override
        fmt_longident_loc o.popen_expr;
      class_type i ppf e

and class_signature i ppf cs =
  line i ppf "class_signature\n";
  core_type (i+1) ppf cs.pcsig_self;
  list (i+1) class_type_field ppf cs.pcsig_fields;

and class_type_field i ppf x =
  line i ppf "class_type_field %a\n" fmt_location x.pctf_loc;
  let i = i+1 in
  attributes i ppf x.pctf_attributes;
  match x.pctf_desc with
  | Pctf_inherit (ct) ->
      line i ppf "Pctf_inherit\n";
      class_type i ppf ct;
  | Pctf_val (s, mf, vf, ct) ->
      line i ppf "Pctf_val \"%s\" %a %a\n" s.txt fmt_mutable_flag mf
           fmt_virtual_flag vf;
      core_type (i+1) ppf ct;
  | Pctf_method (s, pf, vf, ct) ->
      line i ppf "Pctf_method \"%s\" %a %a\n" s.txt fmt_private_flag pf
           fmt_virtual_flag vf;
      core_type (i+1) ppf ct;
  | Pctf_constraint (ct1, ct2) ->
      line i ppf "Pctf_constraint\n";
      core_type (i+1) ppf ct1;
      core_type (i+1) ppf ct2;
  | Pctf_attribute a ->
      attribute i ppf "Pctf_attribute" a
  | Pctf_extension (s, arg) ->
      line i ppf "Pctf_extension \"%s\"\n" s.txt;
     payload i ppf arg

and class_description i ppf x =
  line i ppf "class_description %a\n" fmt_location x.pci_loc;
  attributes i ppf x.pci_attributes;
  let i = i+1 in
  line i ppf "pci_virt = %a\n" fmt_virtual_flag x.pci_virt;
  line i ppf "pci_params =\n";
  list (i+1) type_parameter ppf x.pci_params;
  line i ppf "pci_name = %a\n" fmt_string_loc x.pci_name;
  line i ppf "pci_expr =\n";
  class_type (i+1) ppf x.pci_expr;

and class_type_declaration i ppf x =
  line i ppf "class_type_declaration %a\n" fmt_location x.pci_loc;
  attributes i ppf x.pci_attributes;
  let i = i+1 in
  line i ppf "pci_virt = %a\n" fmt_virtual_flag x.pci_virt;
  line i ppf "pci_params =\n";
  list (i+1) type_parameter ppf x.pci_params;
  line i ppf "pci_name = %a\n" fmt_string_loc x.pci_name;
  line i ppf "pci_expr =\n";
  class_type (i+1) ppf x.pci_expr;

and class_expr i ppf x =
  line i ppf "class_expr %a\n" fmt_location x.pcl_loc;
  attributes i ppf x.pcl_attributes;
  let i = i+1 in
  match x.pcl_desc with
  | Pcl_constr (li, l) ->
      line i ppf "Pcl_constr %a\n" fmt_longident_loc li;
      list i core_type ppf l;
  | Pcl_structure (cs) ->
      line i ppf "Pcl_structure\n";
      class_structure i ppf cs;
  | Pcl_fun (l, eo, p, e) ->
      line i ppf "Pcl_fun\n";
      arg_label i ppf l;
      option i expression ppf eo;
      pattern i ppf p;
      class_expr i ppf e;
  | Pcl_apply (ce, l) ->
      line i ppf "Pcl_apply\n";
      class_expr i ppf ce;
      list i label_x_expression ppf l;
  | Pcl_let (rf, l, ce) ->
      line i ppf "Pcl_let %a\n" fmt_rec_flag rf;
      list i value_binding ppf l;
      class_expr i ppf ce;
  | Pcl_constraint (ce, ct) ->
      line i ppf "Pcl_constraint\n";
      class_expr i ppf ce;
      class_type i ppf ct;
  | Pcl_extension (s, arg) ->
      line i ppf "Pcl_extension \"%s\"\n" s.txt;
      payload i ppf arg
  | Pcl_open (o, e) ->
      line i ppf "Pcl_open %a %a\n" fmt_override_flag o.popen_override
        fmt_longident_loc o.popen_expr;
      class_expr i ppf e

and class_structure i ppf { pcstr_self = p; pcstr_fields = l } =
  line i ppf "class_structure\n";
  pattern (i+1) ppf p;
  list (i+1) class_field ppf l;

and class_field i ppf x =
  line i ppf "class_field %a\n" fmt_location x.pcf_loc;
  let i = i + 1 in
  attributes i ppf x.pcf_attributes;
  match x.pcf_desc with
  | Pcf_inherit (ovf, ce, so) ->
      line i ppf "Pcf_inherit %a\n" fmt_override_flag ovf;
      class_expr (i+1) ppf ce;
      option (i+1) string_loc ppf so;
  | Pcf_val (s, mf, k) ->
      line i ppf "Pcf_val %a\n" fmt_mutable_flag mf;
      line (i+1) ppf "%a\n" fmt_string_loc s;
      class_field_kind (i+1) ppf k
  | Pcf_method (s, pf, k) ->
      line i ppf "Pcf_method %a\n" fmt_private_flag pf;
      line (i+1) ppf "%a\n" fmt_string_loc s;
      class_field_kind (i+1) ppf k
  | Pcf_constraint (ct1, ct2) ->
      line i ppf "Pcf_constraint\n";
      core_type (i+1) ppf ct1;
      core_type (i+1) ppf ct2;
  | Pcf_initializer (e) ->
      line i ppf "Pcf_initializer\n";
      expression (i+1) ppf e;
  | Pcf_attribute a ->
      attribute i ppf "Pcf_attribute" a
  | Pcf_extension (s, arg) ->
      line i ppf "Pcf_extension \"%s\"\n" s.txt;
      payload i ppf arg

and class_field_kind i ppf = function
  | Cfk_concrete (o, e) ->
      line i ppf "Concrete %a\n" fmt_override_flag o;
      expression i ppf e
  | Cfk_virtual t ->
      line i ppf "Virtual\n";
      core_type i ppf t

and class_declaration i ppf x =
  line i ppf "class_declaration %a\n" fmt_location x.pci_loc;
  attributes i ppf x.pci_attributes;
  let i = i+1 in
  line i ppf "pci_virt = %a\n" fmt_virtual_flag x.pci_virt;
  line i ppf "pci_params =\n";
  list (i+1) type_parameter ppf x.pci_params;
  line i ppf "pci_name = %a\n" fmt_string_loc x.pci_name;
  line i ppf "pci_expr =\n";
  class_expr (i+1) ppf x.pci_expr;

and module_type i ppf x =
  line i ppf "module_type %a\n" fmt_location x.pmty_loc;
  attributes i ppf x.pmty_attributes;
  let i = i+1 in
  (* Print raw AST, without interpreting extensions *)
  match x.pmty_desc with
  | Pmty_ident li -> line i ppf "Pmty_ident %a\n" fmt_longident_loc li;
  | Pmty_alias li -> line i ppf "Pmty_alias %a\n" fmt_longident_loc li;
  | Pmty_signature (s) ->
      line i ppf "Pmty_signature\n";
      signature i ppf s;
  | Pmty_functor (Unit, mt2, mm2) ->
      line i ppf "Pmty_functor ()\n";
      module_type i ppf mt2;
      modes i ppf mm2
  | Pmty_functor (Named (s, mt1, mm1), mt2, mm2) ->
      line i ppf "Pmty_functor %a\n" fmt_str_opt_loc s;
      module_type i ppf mt1;
      modes i ppf mm1;
      module_type i ppf mt2;
      modes i ppf mm2
  | Pmty_with (mt, l) ->
      line i ppf "Pmty_with\n";
      module_type i ppf mt;
      list i with_constraint ppf l;
  | Pmty_typeof m ->
      line i ppf "Pmty_typeof\n";
      module_expr i ppf m;
  | Pmty_extension (s, arg) ->
      line i ppf "Pmod_extension \"%s\"\n" s.txt;
      payload i ppf arg
  | Pmty_strengthen (m, lid) ->
      line i ppf "Pmty_strengthen %a\n" fmt_longident lid.txt;
      module_type i ppf m

and signature i ppf {psg_items; psg_modalities} =
  modalities i ppf psg_modalities;
  list i signature_item ppf psg_items

and signature_item i ppf x =
  line i ppf "signature_item %a\n" fmt_location x.psig_loc;
  let i = i+1 in
  match x.psig_desc with
  | Psig_value vd ->
      line i ppf "Psig_value\n";
      value_description i ppf vd;
  | Psig_type (rf, l) ->
      line i ppf "Psig_type %a\n" fmt_rec_flag rf;
      list i type_declaration ppf l;
  | Psig_typesubst l ->
      line i ppf "Psig_typesubst\n";
      list i type_declaration ppf l;
  | Psig_typext te ->
      line i ppf "Psig_typext\n";
      type_extension i ppf te
  | Psig_exception te ->
      line i ppf "Psig_exception\n";
      type_exception i ppf te
  | Psig_module pmd ->
      line i ppf "Psig_module %a\n" fmt_str_opt_loc pmd.pmd_name;
      attributes i ppf pmd.pmd_attributes;
      module_type i ppf pmd.pmd_type;
      modalities i ppf pmd.pmd_modalities
  | Psig_modsubst pms ->
      line i ppf "Psig_modsubst %a = %a\n"
        fmt_string_loc pms.pms_name
        fmt_longident_loc pms.pms_manifest;
      attributes i ppf pms.pms_attributes;
  | Psig_recmodule decls ->
      line i ppf "Psig_recmodule\n";
      list i module_declaration ppf decls;
  | Psig_modtype x ->
      line i ppf "Psig_modtype %a\n" fmt_string_loc x.pmtd_name;
      attributes i ppf x.pmtd_attributes;
      modtype_declaration i ppf x.pmtd_type
  | Psig_modtypesubst x ->
      line i ppf "Psig_modtypesubst %a\n" fmt_string_loc x.pmtd_name;
      attributes i ppf x.pmtd_attributes;
      modtype_declaration i ppf x.pmtd_type
  | Psig_open od ->
      line i ppf "Psig_open %a %a\n" fmt_override_flag od.popen_override
        fmt_longident_loc od.popen_expr;
      attributes i ppf od.popen_attributes
  | Psig_include (incl, m) ->
      line i ppf "Psig_include\n";
      include_kind i ppf incl.pincl_kind;
      module_type i ppf incl.pincl_mod;
      modalities i ppf m;
      attributes i ppf incl.pincl_attributes
  | Psig_class (l) ->
      line i ppf "Psig_class\n";
      list i class_description ppf l;
  | Psig_class_type (l) ->
      line i ppf "Psig_class_type\n";
      list i class_type_declaration ppf l;
  | Psig_extension ((s, arg), attrs) ->
      line i ppf "Psig_extension \"%s\"\n" s.txt;
      attributes i ppf attrs;
      payload i ppf arg
  | Psig_attribute a ->
      attribute i ppf "Psig_attribute" a
  | Psig_kind_abbrev (name, jkind) ->
      line i ppf "Psig_kind_abbrev \"%s\"\n" name.txt;
      jkind_annotation i ppf jkind

and modtype_declaration i ppf = function
  | None -> line i ppf "#abstract"
  | Some mt -> module_type (i+1) ppf mt

and with_constraint i ppf x =
  match x with
  | Pwith_type (lid, td) ->
      line i ppf "Pwith_type %a\n" fmt_longident_loc lid;
      type_declaration (i+1) ppf td;
  | Pwith_typesubst (lid, td) ->
      line i ppf "Pwith_typesubst %a\n" fmt_longident_loc lid;
      type_declaration (i+1) ppf td;
  | Pwith_module (lid1, lid2) ->
      line i ppf "Pwith_module %a = %a\n"
        fmt_longident_loc lid1
        fmt_longident_loc lid2;
  | Pwith_modsubst (lid1, lid2) ->
      line i ppf "Pwith_modsubst %a = %a\n"
        fmt_longident_loc lid1
        fmt_longident_loc lid2;
  | Pwith_modtype (lid1, mty) ->
      line i ppf "Pwith_modtype %a\n"
        fmt_longident_loc lid1;
      module_type (i+1) ppf mty
  | Pwith_modtypesubst (lid1, mty) ->
     line i ppf "Pwith_modtypesubst %a\n"
        fmt_longident_loc lid1;
      module_type (i+1) ppf mty

and module_expr i ppf x =
  line i ppf "module_expr %a\n" fmt_location x.pmod_loc;
  attributes i ppf x.pmod_attributes;
  let i = i+1 in
  match x.pmod_desc with
  | Pmod_ident (li) -> line i ppf "Pmod_ident %a\n" fmt_longident_loc li;
  | Pmod_structure (s) ->
      line i ppf "Pmod_structure\n";
      structure i ppf s;
  | Pmod_functor (Unit, me) ->
      line i ppf "Pmod_functor ()\n";
      module_expr i ppf me;
  | Pmod_functor (Named (s, mt, mm), me) ->
      line i ppf "Pmod_functor %a\n" fmt_str_opt_loc s;
      module_type i ppf mt;
      modes i ppf mm;
      module_expr i ppf me;
  | Pmod_apply (me1, me2) ->
      line i ppf "Pmod_apply\n";
      module_expr i ppf me1;
      module_expr i ppf me2;
  | Pmod_apply_unit me1 ->
      line i ppf "Pmod_apply_unit\n";
      module_expr i ppf me1
  | Pmod_constraint (me, mt, mm) ->
      line i ppf "Pmod_constraint\n";
      module_expr i ppf me;
      Option.iter (module_type i ppf) mt;
      modes i ppf mm
  | Pmod_unpack (e) ->
      line i ppf "Pmod_unpack\n";
      expression i ppf e;
  | Pmod_extension (s, arg) ->
      line i ppf "Pmod_extension \"%s\"\n" s.txt;
      payload i ppf arg
  | Pmod_instance instance ->
      line i ppf "Pmod_instance\n";
      module_instance i ppf instance

and module_instance i ppf { pmod_instance_head; pmod_instance_args } =
  line i ppf "head=%s\n" pmod_instance_head;
  list i (fun i ppf (name, arg) ->
    line i ppf "name=%s\n" name;
    module_instance i ppf arg)
    ppf
    pmod_instance_args

and structure i ppf x = list i structure_item ppf x

and structure_item i ppf x =
  line i ppf "structure_item %a\n" fmt_location x.pstr_loc;
  let i = i+1 in
  match x.pstr_desc with
  | Pstr_eval (e, attrs) ->
      line i ppf "Pstr_eval\n";
      attributes i ppf attrs;
      expression i ppf e;
  | Pstr_value (rf, l) ->
      line i ppf "Pstr_value %a\n" fmt_rec_flag rf;
      list i value_binding ppf l;
  | Pstr_primitive vd ->
      line i ppf "Pstr_primitive\n";
      value_description i ppf vd;
  | Pstr_type (rf, l) ->
      line i ppf "Pstr_type %a\n" fmt_rec_flag rf;
      list i type_declaration ppf l;
  | Pstr_typext te ->
      line i ppf "Pstr_typext\n";
      type_extension i ppf te
  | Pstr_exception te ->
      line i ppf "Pstr_exception\n";
      type_exception i ppf te
  | Pstr_module x ->
      line i ppf "Pstr_module\n";
      module_binding i ppf x
  | Pstr_recmodule bindings ->
      line i ppf "Pstr_recmodule\n";
      list i module_binding ppf bindings;
  | Pstr_modtype x ->
      line i ppf "Pstr_modtype %a\n" fmt_string_loc x.pmtd_name;
      attributes i ppf x.pmtd_attributes;
      modtype_declaration i ppf x.pmtd_type
  | Pstr_open od ->
      line i ppf "Pstr_open %a\n" fmt_override_flag od.popen_override;
      module_expr i ppf od.popen_expr;
      attributes i ppf od.popen_attributes
  | Pstr_class (l) ->
      line i ppf "Pstr_class\n";
      list i class_declaration ppf l;
  | Pstr_class_type (l) ->
      line i ppf "Pstr_class_type\n";
      list i class_type_declaration ppf l;
  | Pstr_include incl ->
      line i ppf "Pstr_include";
      include_kind i ppf incl.pincl_kind;
      attributes i ppf incl.pincl_attributes;
      module_expr i ppf incl.pincl_mod
  | Pstr_extension ((s, arg), attrs) ->
      line i ppf "Pstr_extension \"%s\"\n" s.txt;
      attributes i ppf attrs;
      payload i ppf arg
  | Pstr_attribute a ->
      attribute i ppf "Pstr_attribute" a
  | Pstr_kind_abbrev (name, jkind) ->
      line i ppf "Pstr_kind_abbrev \"%s\"\n" name.txt;
      jkind_annotation i ppf jkind

and module_declaration i ppf pmd =
  str_opt_loc i ppf pmd.pmd_name;
  attributes i ppf pmd.pmd_attributes;
  module_type (i+1) ppf pmd.pmd_type;
  modalities (i+1) ppf pmd.pmd_modalities

and module_binding i ppf x =
  str_opt_loc i ppf x.pmb_name;
  attributes i ppf x.pmb_attributes;
  module_expr (i+1) ppf x.pmb_expr

and core_type_x_core_type_x_location i ppf (ct1, ct2, l) =
  line i ppf "<constraint> %a\n" fmt_location l;
  core_type (i+1) ppf ct1;
  core_type (i+1) ppf ct2;

and constructor_decl i ppf
     {pcd_name; pcd_vars; pcd_args; pcd_res; pcd_loc; pcd_attributes} =
  line i ppf "%a\n" fmt_location pcd_loc;
  line (i+1) ppf "%a\n" fmt_string_loc pcd_name;
  if pcd_vars <> [] then (
    line (i+1) ppf "pcd_vars\n";
    list (i+1) typevar ppf pcd_vars);
  attributes i ppf pcd_attributes;
  constructor_arguments (i+1) ppf pcd_args;
  option (i+1) core_type ppf pcd_res

and constructor_argument i ppf {pca_modalities; pca_type; pca_loc} =
  line i ppf "%a\n" fmt_location pca_loc;
  modalities (i+1) ppf pca_modalities;
  core_type (i+1) ppf pca_type

and constructor_arguments i ppf = function
  | Pcstr_tuple l -> list i constructor_argument ppf l
  | Pcstr_record l -> list i label_decl ppf l

and label_decl i ppf {pld_name; pld_mutable; pld_modalities; pld_type; pld_loc; pld_attributes}=
  line i ppf "%a\n" fmt_location pld_loc;
  attributes i ppf pld_attributes;
  line (i+1) ppf "%a\n" fmt_mutable_flag pld_mutable;
  modalities (i+1) ppf pld_modalities;
  line (i+1) ppf "%a" fmt_string_loc pld_name;
  core_type (i+1) ppf pld_type

and longident_x_pattern i ppf (li, p) =
  line i ppf "%a\n" fmt_longident_loc li;
  pattern (i+1) ppf p;

and case i ppf {pc_lhs; pc_guard; pc_rhs} =
  line i ppf "<case>\n";
  pattern (i+1) ppf pc_lhs;
  begin match pc_guard with
  | None -> ()
  | Some g -> line (i+1) ppf "<when>\n"; expression (i + 2) ppf g
  end;
  expression (i+1) ppf pc_rhs;

and value_binding i ppf x =
  line i ppf "<def>\n";
  attributes (i+1) ppf x.pvb_attributes;
  pattern (i+1) ppf x.pvb_pat;
  Option.iter (value_constraint (i+1) ppf) x.pvb_constraint;
  expression (i+1) ppf x.pvb_expr;
  modes (i+1) ppf x.pvb_modes

and value_constraint i ppf x =
  let pp_sep ppf () = Format.fprintf ppf "@ "; in
  let pp_newtypes = Format.pp_print_list fmt_string_loc ~pp_sep in
  match x with
  | Pvc_constraint { locally_abstract_univars = []; typ } ->
      core_type i ppf typ
  | Pvc_constraint { locally_abstract_univars=newtypes; typ} ->
      line i ppf "<type> %a.\n" pp_newtypes newtypes;
      core_type i ppf  typ
  | Pvc_coercion { ground; coercion} ->
      line i ppf "<coercion>\n";
      option i core_type ppf ground;
      core_type i ppf coercion;

and binding_op i ppf x =
  line i ppf "<binding_op> %a %a"
    fmt_string_loc x.pbop_op fmt_location x.pbop_loc;
  pattern (i+1) ppf x.pbop_pat;
  expression (i+1) ppf x.pbop_exp;

and string_x_expression i ppf (s, e) =
  line i ppf "<override> %a\n" fmt_string_loc s;
  expression (i+1) ppf e;

and longident_x_expression i ppf (li, e) =
  line i ppf "%a\n" fmt_longident_loc li;
  expression (i+1) ppf e;

and label_x_expression i ppf (l,e) =
  line i ppf "<arg>\n";
  arg_label i ppf l;
  expression (i+1) ppf e;

and label_x_bool_x_core_type_list i ppf x =
  match x.prf_desc with
    Rtag (l, b, ctl) ->
      line i ppf "Rtag \"%s\" %s\n" l.txt (string_of_bool b);
      attributes (i+1) ppf x.prf_attributes;
      list (i+1) core_type ppf ctl
  | Rinherit (ct) ->
      line i ppf "Rinherit\n";
      core_type (i+1) ppf ct


let rec toplevel_phrase i ppf x =
  match x with
  | Ptop_def (s) ->
      line i ppf "Ptop_def\n";
      structure (i+1) ppf s;
  | Ptop_dir {pdir_name; pdir_arg; _} ->
      line i ppf "Ptop_dir \"%s\"\n" pdir_name.txt;
      match pdir_arg with
      | None -> ()
      | Some da -> directive_argument i ppf da;

and directive_argument i ppf x =
  match x.pdira_desc with
  | Pdir_string (s) -> line i ppf "Pdir_string \"%s\"\n" s
  | Pdir_int (n, None) -> line i ppf "Pdir_int %s\n" n
  | Pdir_int (n, Some m) -> line i ppf "Pdir_int %s%c\n" n m
  | Pdir_ident (li) -> line i ppf "Pdir_ident %a\n" fmt_longident li
  | Pdir_bool (b) -> line i ppf "Pdir_bool %s\n" (string_of_bool b)

let interface ppf {psg_items; psg_modalities} =
  modalities 0 ppf psg_modalities;
  list 0 signature_item ppf psg_items

let implementation ppf x = list 0 structure_item ppf x

let top_phrase ppf x = toplevel_phrase 0 ppf x

let constant = fmt_constant
