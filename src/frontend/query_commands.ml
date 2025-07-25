(* {{{ COPYING *(

     This file is part of Merlin, an helper for ocaml editors

     Copyright (C) 2013 - 2015  Frédéric Bour  <frederic.bour(_)lakaban.net>
                                Thomas Refis  <refis.thomas(_)gmail.com>
                                Simon Castellan  <simon.castellan(_)iuwt.fr>

     Permission is hereby granted, free of charge, to any person obtaining a
     copy of this software and associated documentation files (the "Software"),
     to deal in the Software without restriction, including without limitation the
     rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
     sell copies of the Software, and to permit persons to whom the Software is
     furnished to do so, subject to the following conditions:

     The above copyright notice and this permission notice shall be included in
     all copies or substantial portions of the Software.

     The Software is provided "as is", without warranty of any kind, express or
     implied, including but not limited to the warranties of merchantability,
     fitness for a particular purpose and noninfringement. In no event shall
     the authors or copyright holders be liable for any claim, damages or other
     liability, whether in an action of contract, tort or otherwise, arising
     from, out of or in connection with the software or the use or other dealings
     in the Software.

   )* }}} *)

open Misc
open Std
open Query_protocol
module Printtyp = Type_utils.Printtyp

exception No_nodes

let print_completion_entries ~with_types config source entries =
  if with_types then (
    let input_ref = ref [] and output_ref = ref [] in
    let preprocess entry =
      match Completion.raw_info_printer entry with
      | `String s -> `String s
      | `Print t ->
        let r = ref "" in
        input_ref := t :: !input_ref;
        output_ref := r :: !output_ref;
        `Print r
      | `Concat (s, t) ->
        let r = ref "" in
        input_ref := t :: !input_ref;
        output_ref := r :: !output_ref;
        `Concat (s, r)
    in
    let entries = List.rev_map ~f:(Completion.map_entry preprocess) entries in
    let entries = List.rev entries in
    let outcomes = Mreader.print_batch_outcome config source !input_ref in
    List.iter2 ~f:( := ) !output_ref outcomes;
    let postprocess = function
      | `String s -> s
      | `Print r -> !r
      | `Concat (s, r) -> s ^ !r
    in
    List.rev_map ~f:(Completion.map_entry postprocess) entries)
  else List.rev_map ~f:(Completion.map_entry (fun _ -> "")) entries

let for_completion pipeline position =
  let pipeline = Mpipeline.for_completion position pipeline in
  let typer = Mpipeline.typer_result pipeline in
  (pipeline, typer)

let verbosity pipeline =
  Mconfig.((Mpipeline.final_config pipeline).query.verbosity)

let dump pipeline = function
  | [ `String "ppxed-source" ] ->
    let ppf, to_string = Format.to_string () in
    begin
      match Mpipeline.ppx_parsetree pipeline with
      | `Interface s -> Pprintast.signature ppf s
      | `Implementation s -> Pprintast.structure ppf s
    end;
    Format.pp_print_newline ppf ();
    Format.pp_force_newline ppf ();
    `String (to_string ())
  | [ `String "source" ] ->
    let ppf, to_string = Format.to_string () in
    begin
      match Mpipeline.reader_parsetree pipeline with
      | `Interface s -> Pprintast.signature ppf s
      | `Implementation s -> Pprintast.structure ppf s
    end;
    Format.pp_print_newline ppf ();
    Format.pp_force_newline ppf ();
    `String (to_string ())
  | [ `String "parsetree" ] ->
    let ppf, to_string = Format.to_string () in
    begin
      match Mpipeline.reader_parsetree pipeline with
      | `Interface s -> Printast.interface ppf s
      | `Implementation s -> Printast.implementation ppf s
    end;
    Format.pp_print_newline ppf ();
    Format.pp_force_newline ppf ();
    `String (to_string ())
  | [ `String "ppxed-parsetree" ] ->
    let ppf, to_string = Format.to_string () in
    begin
      match Mpipeline.ppx_parsetree pipeline with
      | `Interface s -> Printast.interface ppf s
      | `Implementation s -> Printast.implementation ppf s
    end;
    Format.pp_print_newline ppf ();
    Format.pp_force_newline ppf ();
    `String (to_string ())
  | `String (("env" | "fullenv") as kind) :: opt_pos ->
    let typer = Mpipeline.typer_result pipeline in
    let kind = if kind = "env" then `Normal else `Full in
    let pos =
      match opt_pos with
      | [ `String "at"; jpos ] ->
        Some
          (match jpos with
          | `String "start" -> `Start
          | `String "end" -> `End
          | `Int offset -> `Offset offset
          | `Assoc props -> begin
            match (List.assoc "line" props, List.assoc "col" props) with
            | `Int line, `Int col -> `Logical (line, col)
            | _ -> failwith "Incorrect position"
            | exception Not_found -> failwith "Incorrect position"
          end
          | _ -> failwith "Incorrect position")
      | [] -> None
      | _ -> failwith "incorrect position"
    in
    let env =
      match pos with
      | None -> Mtyper.get_env typer
      | Some pos ->
        let pos = Mpipeline.get_lexing_pos pipeline pos in
        fst (Mbrowse.leaf_node (Mtyper.node_at typer pos))
    in
    let sg =
      Browse_misc.signature_of_env ~ignore_extensions:(kind = `Normal) env
    in
    let aux item =
      let ppf, to_string = Format.to_string () in
      Printtyp.signature ppf [ item ];
      `String (to_string ())
    in
    `List (List.map ~f:aux sg)
  | [ `String "browse" ] ->
    let typer = Mpipeline.typer_result pipeline in
    let structure = Mbrowse.of_typedtree (Mtyper.get_typedtree typer) in
    Browse_misc.dump_browse (snd (Mbrowse.leaf_node structure))
  | [ `String "current-level" ] ->
    let _typer = Mpipeline.typer_result pipeline in
    `Int (Ctype.get_current_level ())
  | [ `String "tokens" ] -> failwith "TODO"
  | [ `String "flags" ] ->
    let prepare_flags flags =
      Json.list Json.string (List.concat_map flags ~f:(fun f -> f.workval))
    in
    let user =
      prepare_flags
        Mconfig.((Mpipeline.input_config pipeline).merlin.flags_to_apply)
    in
    let applied =
      prepare_flags
        Mconfig.((Mpipeline.final_config pipeline).merlin.flags_applied)
    in
    `Assoc [ ("user", user); ("applied", applied) ]
  | [ `String "warnings" ] ->
    let _typer = Mpipeline.typer_result pipeline in
    Warnings.dump () (*TODO*)
  | [ `String "exn" ] ->
    let exns =
      Mpipeline.reader_lexer_errors pipeline
      @ Mpipeline.reader_parser_errors pipeline
      @ Mpipeline.typer_errors pipeline
    in
    `List (List.map ~f:(fun x -> `String (Printexc.to_string x)) exns)
  | [ `String "paths" ] ->
    let paths = Mconfig.build_path (Mpipeline.final_config pipeline) in
    `List (List.map paths ~f:(fun s -> `String s))
  | [ `String "hidden-paths" ] ->
    let paths = Mconfig.hidden_build_path (Mpipeline.final_config pipeline) in
    `List (List.map paths ~f:(fun s -> `String s))
  | [ `String "typedtree" ] ->
    let tree = Mpipeline.typer_result pipeline |> Mtyper.get_typedtree in
    let ppf, to_string = Format.to_string () in
    begin
      match tree with
      | `Interface s -> Printtyped.interface ppf s
      | `Implementation s -> Printtyped.implementation ppf s
    end;
    Format.pp_print_newline ppf ();
    Format.pp_force_newline ppf ();
    `String (to_string ())
  | _ ->
    failwith
      "known dump commands: paths, hidden-paths, exn, warnings, flags, tokens, \
       browse, source, parsetree, ppxed-source, ppxed-parsetree, typedtree, \
       env/fullenv (at {col:, line:})"

let dispatch pipeline (type a) : a Query_protocol.t -> a = function
  | Type_expr (source, pos) ->
    let typer = Mpipeline.typer_result pipeline in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let env, _ = Mbrowse.leaf_node (Mtyper.node_at typer pos) in
    let ppf, to_string = Format.to_string () in
    let verbosity = verbosity pipeline in
    let context = Context.Expr in
    ignore (Type_utils.type_in_env ~verbosity ~context env ppf source : bool);
    to_string ()
  | Stack_or_heap_enclosing (pos, lsp_compat, index) ->
    let typer = Mpipeline.typer_result pipeline in

    (* Optimise allocations only on programs that have type-checked. *)
    let errors =
      Mpipeline.reader_lexer_errors pipeline
      @ Mpipeline.reader_parser_errors pipeline
      @ Mpipeline.ppx_errors pipeline
      @ Mpipeline.typer_errors pipeline
    in
    if
      not
      @@ List.exists errors ~f:(function
           | Msupport.Warning _ -> false
           | _ -> true)
    then Typecore.optimise_allocations ();

    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let structures =
      Mbrowse.enclosing pos
        [ Mbrowse.of_typedtree (Mtyper.get_typedtree typer) ]
    in
    let path =
      match structures with
      | [] -> []
      | browse -> Browse_misc.annotate_tail_calls browse
    in

    let result = Stack_or_heap_enclosing.from_nodes ~lsp_compat ~pos ~path in

    let all_results =
      List.mapi result ~f:(fun i (loc, text) ->
          let print =
            match index with
            | None -> true
            | Some index -> index = i
          in
          let ret x = (loc, x) in
          match (text, print) with
          | Stack_or_heap_enclosing.No_alloc { reason }, true ->
            ret (`String ("not an allocation (" ^ reason ^ ")"))
          | Stack_or_heap_enclosing.Alloc_mode alloc_mode, true ->
            let locality =
              alloc_mode
              |> Mode.Alloc.proj (Comonadic Areality)
              |> Mode.Locality.Guts.check_const_conservative
            in
            let str =
              match locality with
              | Some Global -> "heap"
              | Some Local -> "stack"
              | None -> "could be stack or heap"
            in
            ret (`String str)
          | Stack_or_heap_enclosing.Unexpected_no_alloc, true ->
            ret (`String "unknown (does your code contain a type error?)")
          | _, false -> ret (`Index i))
    in

    let all_results =
      match all_results with
      | _ :: _ -> all_results
      | [] ->
        let pos' : Lexing.position = { pos with pos_cnum = pos.pos_cnum - 1 } in
        let loc : Location.t =
          { loc_start = pos'; loc_end = pos; loc_ghost = false }
        in
        [ (loc, `String "no relevant allocation to show") ]
    in

    all_results
  | Type_enclosing (expro, pos, index) ->
    (* This case shares some boilerplate with the one for [Stack_or_heap_enclosing]
       (above), since they both deal with querying increasingly widening enclosing
       expressions. Changes to this code that from upstream should also be reflected
       there. *)
    let typer = Mpipeline.typer_result pipeline in
    let verbosity = verbosity pipeline in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let structures =
      Mbrowse.enclosing pos
        [ Mbrowse.of_typedtree (Mtyper.get_typedtree typer) ]
    in
    let path =
      match structures with
      | [] -> []
      | browse -> Browse_misc.annotate_tail_calls browse
    in

    (* Type enclosing results come from two sources: 1. the typedtree nodes
       aroung the cursor's position and 2. the result of reconstructing the
       identifier around the cursor and typing the resulting paths.

       Having the results from 2 is useful because ot is finer-grained than the
       typedtree's nodes and can provide types for modules appearing in paths.

       This introduces two possible sources of duplicate results:
       - The last reconstructed enclosing usually overlaps with the first
         typedtree node but the printed types are not always the same (generic /
         specialized types). Because systematically printing these types to
         compare them can be very expensive in the presence of large modules, we
         defer this deduplication to the clients.
       - Sometimes the typedtree nodes in 1 overlaps. We choose not to dedpulicate because
         if the types are the same, the client is already responsible for deduplication.
         If they are different, then they are likely useful to display to the user.
       So, we choose to not duplicate results and delegate this to the client.
    *)
    let enclosing_nodes = Type_enclosing.from_nodes ~path in

    (* Enclosings of cursor in given expression *)
    let exprs = Misc_utils.reconstruct_identifier pipeline pos expro in
    let () =
      Logger.log ~section:Type_enclosing.log_section
        ~title:"reconstruct identifier" "%a" Logger.json (fun () ->
          let lst =
            List.map exprs ~f:(fun { Location.loc; txt } ->
                `Assoc
                  [ ("start", Lexing.json_of_position loc.Location.loc_start);
                    ("end", Lexing.json_of_position loc.Location.loc_end);
                    ("identifier", `String txt)
                  ])
          in
          `List lst)
    in
    let small_enclosings =
      Type_enclosing.from_reconstructed exprs ~nodes:structures ~cursor:pos
        ~verbosity
    in
    Logger.log ~section:Type_enclosing.log_section ~title:"small enclosing" "%a"
      Logger.fmt (fun fmt ->
        Format.fprintf fmt "result = [ %a ]"
          (Format.pp_print_list ~pp_sep:Format.pp_print_space
             (fun fmt (loc, _, _) -> Location.print_loc fmt loc))
          small_enclosings);
    let all_results = List.concat [ small_enclosings; enclosing_nodes ] in
    let index =
      (* Clamp the index to [0; number_of_results[ *)
      let number_of_results = List.length all_results in
      match index with
      | Some index when index < 0 -> Some 0
      | Some index when index >= number_of_results ->
        Some (number_of_results - 1)
      | index -> index
    in
    List.mapi all_results ~f:(fun i (loc, text, tail) ->
        let print =
          match index with
          | None -> true
          | Some index -> index = i
        in
        let ret x = (loc, x, tail) in
        match text with
        | Type_enclosing.String str -> ret (`String str)
        | type_info ->
          if print then
            let printed_type = Type_enclosing.print_type ~verbosity type_info in
            ret (`String printed_type)
          else ret (`Index i))
  | Enclosing pos ->
    let typer = Mpipeline.typer_result pipeline in
    let structures = Mbrowse.of_typedtree (Mtyper.get_typedtree typer) in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let mbrowse = Mbrowse.enclosing pos [ structures ] in
    (* We remove possible duplicates from the list*)
    List.fold_left mbrowse ~init:[] ~f:(fun acc node ->
        let loc = Mbrowse.node_loc (snd node) in
        match acc with
        | hd :: _ as acc when Location_aux.compare hd loc = 0 -> acc
        | _ -> loc :: acc)
    |> List.rev
  | Locate_type pos ->
    let typer = Mpipeline.typer_result pipeline in
    let local_defs = Mtyper.get_typedtree typer in
    let structures = Mbrowse.of_typedtree local_defs in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let node =
      match Mbrowse.enclosing pos [ structures ] with
      | path :: _ -> Some path
      | [] -> None
    in
    let path =
      Option.bind node ~f:(fun (env, node) ->
          Locate.log ~title:"query_commands Locate_type" "inspecting node: %s"
            (Browse_raw.string_of_node node);
          match node with
          | Browse_raw.Expression { exp_type = ty; _ }
          | Pattern { pat_type = ty; _ }
          | Core_type { ctyp_type = ty; _ }
          | Value_description { val_desc = { ctyp_type = ty; _ }; _ } -> begin
            match Types.get_desc ty with
            | Tconstr (path, _, _) -> Some (env, path)
            | _ -> None
          end
          | _ -> None)
    in
    begin
      match path with
      | None -> `Invalid_context
      | Some (env, path) -> (
        Locate.log ~title:"debug" "found type: %s" (Path.name path);
        let config =
          Locate.
            { mconfig = Mpipeline.final_config pipeline;
              ml_or_mli = `MLI;
              traverse_aliases = true
            }
        in
        match
          Locate.from_path ~config ~env ~local_defs ~namespace:Type path
        with
        | `Builtin (_, s) -> `Builtin s
        | `Not_in_env _ as s -> s
        | `Not_found _ as s -> s
        | `Found { file; location; _ } -> `Found (Some file, location.loc_start)
        | `File_not_found _ as s -> s)
    end
  | Complete_prefix (prefix, pos, kinds, with_doc, with_types) ->
    let pipeline, typer = for_completion pipeline pos in
    let config = Mpipeline.final_config pipeline in
    let verbosity = Mconfig.(config.query.verbosity) in
    let no_labels = Mpipeline.reader_no_labels_for_completion pipeline in
    let source = Mpipeline.input_source pipeline in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let branch = Mtyper.node_at ~skip_recovered:true typer pos in
    let env, _ = Mbrowse.leaf_node branch in
    let target_type, context = Completion.application_context ~prefix branch in
    let get_doc =
      if not with_doc then None
      else
        let local_defs = Mtyper.get_typedtree typer in
        Some
          (Locate.get_doc ~config ~env ~local_defs
             ~comments:(Mpipeline.reader_comments pipeline)
             ~pos)
    in
    let keywords = Mpipeline.reader_lexer_keywords pipeline in
    let entries =
      Printtyp.wrap_printing_env env ~verbosity @@ fun () ->
      Completion.branch_complete config ~kinds ?get_doc ?target_type ~keywords
        prefix branch
      |> print_completion_entries ~with_types config source
    and context =
      match context with
      | `Application context when no_labels ->
        `Application { context with Compl.labels = [] }
      | context -> context
    in
    { Compl.entries; context }
  | Expand_prefix (prefix, pos, kinds, with_types) ->
    let pipeline, typer = for_completion pipeline pos in
    let source = Mpipeline.input_source pipeline in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let env, _ = Mbrowse.leaf_node (Mtyper.node_at typer pos) in
    let config = Mpipeline.final_config pipeline in
    let global_modules = Mconfig.global_modules config in
    let entries =
      Completion.expand_prefix env ~global_modules ~kinds prefix
      |> print_completion_entries ~with_types config source
    in
    { Compl.entries; context = `Unknown }
  | Polarity_search (query, pos) ->
    let typer = Mpipeline.typer_result pipeline in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let env, _ = Mbrowse.leaf_node (Mtyper.node_at typer pos) in
    let query = Polarity_search.prepare_query env query in
    let config = Mpipeline.final_config pipeline in
    let global_modules = Mconfig.global_modules config in
    let dirs = Polarity_search.directories ~global_modules env in
    ignore (Format.flush_str_formatter ());
    let entries =
      Polarity_search.execute_query query env dirs
      |> List.sort ~cmp:compare
      |> Printtyp.wrap_printing_env env ~verbosity:(verbosity pipeline)
         @@ fun () ->
         List.map ~f:(fun (_, path, v) ->
             Printtyp.path Format.str_formatter path;
             let name = Format.flush_str_formatter () in
             Printtyp.type_scheme env Format.str_formatter v.Types.val_type;
             let desc = Format.flush_str_formatter () in
             { Compl.name; kind = `Value; desc; info = ""; deprecated = false })
    in
    { Compl.entries; context = `Unknown }
  | Type_search (query, pos, limit, with_doc) ->
    let typer = Mpipeline.typer_result pipeline in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let node = Mtyper.node_at typer pos in
    let env, _ = Mbrowse.leaf_node node in
    let config = Mpipeline.final_config pipeline in
    let modules = Mconfig.global_modules config in
    let verbosity = verbosity pipeline in
    let results =
      match Type_search.classify_query query with
      | `By_type query ->
        let query = Merlin_sherlodoc.Query.from_string query in
        Type_search.run ~limit ~env ~query ~modules ()
      | `Polarity query ->
        let query = Polarity_search.prepare_query env query in
        let modules = Polarity_search.directories ~global_modules:modules env in
        Polarity_search.execute_query_as_type_search ~limit ~env ~query ~modules
          ()
    in
    List.map results ~f:(fun ({ name; typ; doc; _ } as v) ->
        let typ =
          Printtyp.wrap_printing_env ~verbosity env @@ fun () ->
          Format.asprintf "%a" (Type_utils.Printtyp.type_scheme env) typ
        in
        let doc =
          if not with_doc then doc
          else
            let comments = Mpipeline.reader_comments pipeline in
            let local_defs = Mtyper.get_typedtree typer in
            Type_search.get_doc ~config ~env ~local_defs ~comments ~pos name
        in
        { v with typ; doc })
  | Refactor_open (mode, pos) ->
    let typer = Mpipeline.typer_result pipeline in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    Refactor_open.get_rewrites ~mode typer pos
  | Document (patho, pos) -> (
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let from_document_override_attribute =
      pipeline |> Override_document.get_overrides
      |> Override_document.find ~cursor:pos
      |> Option.map ~f:Override_document.Override.doc
    in
    match from_document_override_attribute with
    | Some doc_string -> `Found doc_string
    | None ->
      let typer = Mpipeline.typer_result pipeline in
      let local_defs = Mtyper.get_typedtree typer in
      let config = Mpipeline.final_config pipeline in
      let comments = Mpipeline.reader_comments pipeline in
      let env, _ = Mbrowse.leaf_node (Mtyper.node_at typer pos) in
      let path =
        match patho with
        | Some p -> p
        | None ->
          let path = Misc_utils.reconstruct_identifier pipeline pos None in
          let path = Mreader_lexer.identifier_suffix path in
          let path = List.map ~f:(fun { Location.txt; _ } -> txt) path in
          String.concat ~sep:"." path
      in
      if path = "" then `Invalid_context
      else
        Locate.get_doc ~config ~env ~local_defs ~comments ~pos
          (`User_input path))
  | Syntax_document pos -> (
    let typer = Mpipeline.typer_result pipeline in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let node = Mtyper.node_at typer pos in
    let res = Syntax_doc.get_syntax_doc pos node in
    match res with
    | Some res -> `Found res
    | None -> `No_documentation)
  | Expand_ppx pos -> (
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let parsetree = Mpipeline.reader_parsetree pipeline in
    let ppxed_parsetree = Mpipeline.ppx_parsetree pipeline in
    let ppx_kind_with_attr = Ppx_expand.check_extension ~parsetree ~pos in
    match ppx_kind_with_attr with
    | Some ppx_kind_with_attr ->
      `Found
        (Ppx_expand.get_ppxed_source ~ppxed_parsetree ~pos ppx_kind_with_attr)
    | None -> `No_ppx)
  | Locate (patho, ml_or_mli, pos, context) ->
    let typer = Mpipeline.typer_result pipeline in
    let local_defs = Mtyper.get_typedtree typer in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let let_pun_behavior = Mbrowse.Let_pun_behavior.Prefer_expression in
    let env, _ = Mbrowse.leaf_node (Mtyper.node_at typer pos) in
    let path =
      match patho with
      | Some p -> p
      | None ->
        let path = Misc_utils.reconstruct_identifier pipeline pos None in
        let path = Mreader_lexer.identifier_suffix path in
        let path = List.map ~f:(fun { Location.txt; _ } -> txt) path in
        let path = String.concat ~sep:"." path in
        Locate.log ~title:"reconstructed identifier" "%s" path;
        path
    in
    if path = "" then `Invalid_context
    else
      let config =
        Locate.
          { mconfig = Mpipeline.final_config pipeline;
            ml_or_mli;
            traverse_aliases = true
          }
      in
      begin
        let namespaces =
          Option.map context ~f:(fun ctx ->
              Locate.Namespace_resolution.From_context ctx)
        in
        match
          Locate.from_string ~config ~env ~local_defs ~pos ?namespaces
            ~let_pun_behavior path
        with
        | `Found { file; location; _ } ->
          Locate.log ~title:"result" "found: %s" file;
          `Found (Some file, location.loc_start)
        | `Missing_labels_namespace ->
          (* Can't happen because we haven't passed a namespace as input. *)
          assert false
        | `Builtin (_, s) ->
          Locate.log ~title:"result" "found builtin %s" s;
          `Builtin s
        | (`Not_found _ | `At_origin | `Not_in_env _ | `File_not_found _) as
          otherwise ->
          Locate.log ~title:"result" "not found";
          otherwise
      end
  | Jump (target, pos) ->
    let typer = Mpipeline.typer_result pipeline in
    let typedtree = Mtyper.get_typedtree typer in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    Jump.get typedtree pos target
  | Phrase (target, pos) ->
    let typer = Mpipeline.typer_result pipeline in
    let typedtree = Mtyper.get_typedtree typer in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    Mpipeline.get_lexing_pos pipeline (Jump.phrase typedtree pos target)
  | Case_analysis (pos_start, pos_end) ->
    let typer = Mpipeline.typer_result pipeline in
    let pos_start = Mpipeline.get_lexing_pos pipeline pos_start in
    let pos_end = Mpipeline.get_lexing_pos pipeline pos_end in
    let browse = Mbrowse.of_typedtree (Mtyper.get_typedtree typer) in
    let nodes = Mbrowse.enclosing pos_start [ browse ] in
    let dump_node (_, node) =
      let { Location.loc_start; loc_end; _ } = Mbrowse.node_loc node in
      let l1, c1 = Lexing.split_pos loc_start in
      let l2, c2 = Lexing.split_pos loc_end in
      `List
        [ `String (Browse_raw.string_of_node node);
          `Int l1;
          `Int c1;
          `Int l2;
          `Int c2
        ]
    in
    Destruct.log ~title:"nodes before" "%a" Logger.json (fun () ->
        `List (List.map nodes ~f:dump_node));
    let nodes =
      (* Drop nodes that:
         - start inside the user's selection
         - finish inside the user's selection
      *)
      List.drop_while nodes ~f:(fun (_, t) ->
          let { Location.loc_start; loc_end; _ } = Mbrowse.node_loc t in
          Lexing.compare_pos loc_start pos_start > 0
          || Lexing.compare_pos loc_end pos_end < 0)
    in
    Destruct.log ~title:"nodes after" "%a" Logger.json (fun () ->
        `List (List.map nodes ~f:dump_node));
    begin
      match nodes with
      | [] -> raise Destruct.Nothing_to_do
      | (env, node) :: parents ->
        let source = Mpipeline.input_source pipeline in
        let config = Mpipeline.final_config pipeline in
        let verbosity = verbosity pipeline in
        Printtyp.wrap_printing_env env ~verbosity @@ fun () ->
        Destruct.node config source node (List.map ~f:snd parents)
    end
  | Holes ->
    let typer = Mpipeline.typer_result pipeline in
    let verbosity = verbosity pipeline in
    let nodes = Mbrowse.of_typedtree (Mtyper.get_typedtree typer) in
    let ppf = Format.str_formatter in
    let print ~nodes loc env type_ () =
      match type_ with
      | `Exp type_expr ->
        Type_utils.print_type_with_decl ~verbosity env ppf type_expr
      | `Mod module_type -> (
        (* For module_expr holes we need the type of the next enclosing
           to get a useful result *)
        match Mbrowse.enclosing loc.Location.loc_start [ nodes ] with
        | _ :: (_, Browse_raw.Module_expr { mod_type; _ }) :: _ ->
          Printtyp.modtype env ppf mod_type
        | _ -> Printtyp.modtype env ppf module_type)
    in
    let loc_and_types_of_holes node =
      List.map (Browse_raw.all_holes node) ~f:(fun (loc, env, type_) ->
          Printtyp.wrap_printing_env env ~verbosity (print ~nodes loc env type_);
          (loc, Format.flush_str_formatter ()))
    in
    List.concat_map ~f:loc_and_types_of_holes nodes
  | Construct (pos, with_values, depth) ->
    let values_scope =
      match with_values with
      | Some `None | None -> Construct.Null
      | Some `Local -> Construct.Local
    in
    let config = Mpipeline.final_config pipeline in
    let keywords = Mpipeline.reader_lexer_keywords pipeline in
    let typer = Mpipeline.typer_result pipeline in
    let typedtree = Mtyper.get_typedtree typer in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let structures = Mbrowse.enclosing pos [ Mbrowse.of_typedtree typedtree ] in
    begin
      match structures with
      | ( _,
          (Browse_raw.Module_expr { mod_desc = Tmod_typed_hole; _ } as
           node_for_loc) )
        :: (_, node)
        :: _parents ->
        let loc = Mbrowse.node_loc node_for_loc in
        (loc, Construct.node ~config ~keywords ?depth ~values_scope node)
      | ( _,
          (Browse_raw.Expression { exp_desc = Texp_typed_hole | Texp_hole _; _ }
           as node) )
        :: _parents ->
        let loc = Mbrowse.node_loc node in
        (loc, Construct.node ~config ~keywords ?depth ~values_scope node)
      | _ :: _ -> raise Construct.Not_a_hole
      | [] -> raise No_nodes
    end
  | Outline ->
    let typer = Mpipeline.typer_result pipeline in
    let browse = Mbrowse.of_typedtree (Mtyper.get_typedtree typer) in
    Outline.get [ Browse_tree.of_browse browse ]
  | Shape pos ->
    let typer = Mpipeline.typer_result pipeline in
    let browse = Mbrowse.of_typedtree (Mtyper.get_typedtree typer) in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    Outline.shape pos [ Browse_tree.of_browse browse ]
  | Errors { lexing; parsing; typing } ->
    let typer = Mpipeline.typer_result pipeline in
    let verbosity = verbosity pipeline in
    let lexer_errors = Mpipeline.reader_lexer_errors pipeline in
    let parser_errors = Mpipeline.reader_parser_errors pipeline in
    let typer_errors = Mpipeline.typer_errors pipeline in
    Printtyp.wrap_printing_env (Mtyper.get_env typer) ~verbosity @@ fun () ->
    (* When there is a cmi error, we will have a lot of meaningless errors,
       there is no need to report them. *)
    let typer_errors =
      let cmi_error = function
        | Magic_numbers.Cmi.Error _ -> true
        | _ -> false
      in
      match List.find typer_errors ~f:cmi_error with
      | e -> [ e ]
      | exception Not_found -> typer_errors
    in
    let error_start e = (Location.loc_of_report e).Location.loc_start in
    let error_end e = (Location.loc_of_report e).Location.loc_end in
    (* Turn into Location.error, ignore ghost warnings *)
    let filter_error exn =
      match Location.error_of_exn exn with
      | None | Some `Already_displayed -> None
      | Some (`Ok (err : Location.error)) ->
        if
          (Location.loc_of_report err).loc_ghost
          &&
          match exn with
          | Msupport.Warning _ -> true
          | _ -> false
        then None
        else Some err
    in
    let lexer_errors = List.filter_map ~f:filter_error lexer_errors in
    (* Ast can contain syntax error *)
    let first_syntax_error = ref Lexing.dummy_pos in
    let filter_typer_error exn =
      let result = filter_error exn in
      begin
        match result with
        | Some ({ Location.source = Location.Parser; _ } as err)
          when !first_syntax_error = Lexing.dummy_pos
               || Lexing.compare_pos !first_syntax_error (error_start err) > 0
          -> first_syntax_error := error_start err
        | _ -> ()
      end;
      result
    in
    let typer_errors = List.filter_map ~f:filter_typer_error typer_errors in
    (* Track first parsing error *)
    let filter_parser_error = function
      | Msupport.Warning _ as exn -> filter_error exn
      | exn ->
        let result = filter_error exn in
        begin
          match result with
          | None -> ()
          | Some err ->
            if
              !first_syntax_error = Lexing.dummy_pos
              || Lexing.compare_pos !first_syntax_error (error_start err) > 0
            then first_syntax_error := error_start err
        end;
        result
    in
    let parser_errors = List.filter_map ~f:filter_parser_error parser_errors in
    (* Sort errors *)
    let cmp e1 e2 =
      let n = Lexing.compare_pos (error_start e1) (error_start e2) in
      if n <> 0 then n else Lexing.compare_pos (error_end e1) (error_end e2)
    in
    let errors =
      List.sort_uniq ~cmp
        ((if lexing then lexer_errors else [])
        @ (if parsing then parser_errors else [])
        @ if typing then typer_errors else [])
    in
    (* Add configuration errors *)
    let errors =
      let cfg = Mpipeline.final_config pipeline in
      let failures =
        List.map ~f:(Location.error ~source:Location.Config) cfg.merlin.failures
      in
      failures @ errors
    in
    (* Filter anything after first parse error *)
    let limit = !first_syntax_error in
    if limit = Lexing.dummy_pos then errors
    else
      List.take_while errors ~f:(fun err ->
          Lexing.compare_pos (error_start err) limit <= 0)
  | Dump args -> dump pipeline args
  | Path_of_source xs ->
    let config = Mpipeline.final_config pipeline in
    let rec aux = function
      | [] -> raise Not_found
      | x :: xs -> (
        (* Here there is drift between janestreet/merlin-jst and ocaml/merlin:
           In merlin-jst, we look in both visible and hidden paths. In upstream
           merlin, we look in only visible paths.

           We ought to be able to reduce drift here by either:
            - upstreaming the looking-in of hidden paths.
            - fixing merlin-jst to make it so it's not necessary to also look
              in hidden paths here.

           Nobody has closely investigated the source of the drift. Liam thinks
           that some -H functionality doesn't work upstream; this might be one
           such case, or it might not.
        *)
        try find_in_path_normalized (Mconfig.source_path config) x
        with Not_found -> (
          try
            find_in_path_normalized
              (Mconfig.build_path config @ Mconfig.hidden_build_path config)
              x
          with Not_found -> aux xs))
    in
    aux xs
  | List_modules exts ->
    let config = Mpipeline.final_config pipeline in
    let with_ext ext =
      modules_in_path ~ext Mconfig.(config.merlin.source_path)
    in
    List.concat_map ~f:with_ext exts
  | Findlib_list -> []
  | Extension_list kind ->
    let config = Mpipeline.final_config pipeline in
    let enabled = Mconfig.(config.merlin.extensions) in
    begin
      match kind with
      | `All -> Extension.all
      | `Enabled -> enabled
      | `Disabled ->
        List.fold_left
          ~f:(fun exts ext -> List.remove ext exts)
          ~init:Extension.all enabled
    end
  | Path_list `Build ->
    let config = Mpipeline.final_config pipeline in
    Mconfig.(config.merlin.build_path @ config.merlin.hidden_build_path)
  | Path_list `Source ->
    let config = Mpipeline.final_config pipeline in
    Mconfig.(config.merlin.source_path @ config.merlin.hidden_source_path)
  | Occurrences (`Ident_at pos, scope) ->
    let config = Mpipeline.final_config pipeline in
    let typer_result = Mpipeline.typer_result pipeline in
    let pos = Mpipeline.get_lexing_pos pipeline pos in
    let env, _node = Mbrowse.leaf_node (Mtyper.node_at typer_result pos) in
    let path =
      let path = Misc_utils.reconstruct_identifier pipeline pos None in
      let path = Mreader_lexer.identifier_suffix path in
      let path = List.map ~f:(fun { Location.txt; _ } -> txt) path in
      let path = String.concat ~sep:"." path in
      Locate.log ~title:"reconstructed identifier" "%s" path;
      path
    in
    let { Occurrences.occurrences; status } =
      Occurrences.locs_of ~config ~env ~typer_result ~pos ~scope path
    in
    (occurrences, status)
  | Inlay_hints
      (start, stop, hint_let_binding, hint_pattern_binding, avoid_ghost_location)
    ->
    let start = Mpipeline.get_lexing_pos pipeline start
    and stop = Mpipeline.get_lexing_pos pipeline stop in
    let typer_result = Mpipeline.typer_result pipeline in
    begin
      match Mtyper.get_typedtree typer_result with
      | `Interface _ -> []
      | `Implementation structure ->
        Inlay_hints.of_structure ~hint_let_binding ~hint_pattern_binding
          ~avoid_ghost_location ~start ~stop structure
    end
  | Signature_help { position; _ } -> (
    (* Todo: additionnal contextual information could help us provide better
       results.*)
    let typer = Mpipeline.typer_result pipeline in
    let pos = Mpipeline.get_lexing_pos pipeline position in
    let node = Mtyper.node_at typer pos in
    let source = Mpipeline.input_source pipeline in
    let prefix =
      Signature_help.prefix_of_position ~short_path:true source position
    in
    let application_signature =
      Signature_help.application_signature ~prefix ~cursor:pos node
    in
    let param offset (p : Signature_help.parameter_info) =
      { label_start = offset + p.param_start; label_end = offset + p.param_end }
    in
    match application_signature with
    | Some s ->
      let prefix =
        let fun_name = Option.value ~default:"_" s.function_name in
        sprintf "%s : " fun_name
      in
      Some
        { label = prefix ^ s.signature;
          parameters = List.map ~f:(param (String.length prefix)) s.parameters;
          active_param = Option.value ~default:0 s.active_param;
          active_signature = 0
        }
    | None -> None)
  | Version ->
    let version =
      Printf.sprintf "The Merlin toolkit version %s, for Ocaml %s\n"
        Merlin_config.version Sys.ocaml_version
    in
    let magic_numbers = Config.Magic_numbers.current in
    (version, magic_numbers)
