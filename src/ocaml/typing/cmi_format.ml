(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                   Fabrice Le Fessant, INRIA Saclay                     *)
(*                                                                        *)
(*   Copyright 2012 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open Misc

type pers_flags =
  | Rectypes
  | Alerts of alerts
  | Opaque

type kind =
  | Normal of {
      cmi_impl : Compilation_unit.t;
      cmi_arg_for : Global_module.Parameter_name.t option;
    }
  | Parameter

(* A serialized cmi file has the following format.contents

  - magic number
  - size of data block
  - data block (serialized bits of signature)
  - compilation unit name
  - serialized signature with offsets into data block in wrapped positions
  - crcs
  - flags

  The serialized signature contains only the top level, with wrapped (cf. Types)
  values represented as offsets into the data block where their serialized
  (again, shallowly) representation can be found. When deserializing, we read
  the entire data block into memory as one blob and then deserialize from it as
  needed when values are forced.

  Note that we are deliberately using int for offsets here because int64 is more
  expensive. On 32 bits architectures, this imposes a constraint on the size of
  .cmi files. *)
module Serialized = Types.Make_wrapped(struct type 'a t = int end)

(* these type abbreviations are not exported;
   they are used to provide consistency across
   input_value and output_value usage. *)
type crcs = Import_info.t array  (* smaller on disk than using a list *)
type flags = pers_flags list
type header = {
    header_name : Compilation_unit.Name.t;
    header_kind : kind;
    header_globals : Global_module.With_precision.t array;
    header_sign : Serialized.signature;
    header_params : Global_module.Parameter_name.t list;
}

type 'sg cmi_infos_generic = {
    cmi_name : Compilation_unit.Name.t;
    cmi_kind : kind;
    cmi_globals : Global_module.With_precision.t array;
    cmi_sign : 'sg;
    cmi_params : Global_module.Parameter_name.t list;
    cmi_crcs : crcs;
    cmi_flags : flags;
}

type cmi_infos_lazy = Subst.Lazy.signature cmi_infos_generic
type cmi_infos = Types.signature cmi_infos_generic

let force_cmi_infos cmi =
  { cmi with cmi_sign = Subst.Lazy.force_signature cmi.cmi_sign }

module Deserialize = Types.Map_wrapped(Serialized)(Subst.Lazy)

let deserialize data =
  (* Values are offsets into `data` *)
  let map_signature fn n =
    lazy(Marshal.from_bytes data n |> List.map (Deserialize.signature_item fn))
    |> Subst.Lazy.of_lazy
  in
  let map_type_expr _ n =
    lazy(Marshal.from_bytes data n : Types.type_expr) |> Subst.Lazy.of_lazy
  in
  Deserialize.signature {map_signature; map_type_expr}

(* Serialization is unused by merlin.

module Serialize = Types.Map_wrapped(Subst.Lazy)(Serialized)

let serialize oc base =
  (* Serialize values into the stream and produce their offsets within the data
    block (which starts at `base`). *)
  let marshal x =
    let pos = Out_channel.pos oc in
    Marshal.to_channel oc x [];
    Int64.to_int (Int64.sub pos base)
  in
  let map_signature fn sg =
    Subst.Lazy.force_signature_once sg
    |> List.map (Serialize.signature_item fn)
    |> marshal
  in
  let map_type_expr _ ty = Subst.Lazy.force_type_expr ty |> marshal in
  Serialize.signature {map_signature; map_type_expr}
*)

let input_cmi_lazy ic =
  let read_bytes n =
    let buf = Bytes.create n in
    match In_channel.really_input ic buf 0 n with
    | Some () -> buf
    | None -> assert false
  in
  let data_len = Bytes.get_int64_ne (read_bytes 8) 0 |> Int64.to_int in
  let data = read_bytes data_len in
  let {
      header_name = name;
      header_kind = kind;
      header_globals = globals;
      header_sign = sign;
      header_params = params;
    } = (input_value ic : header) in
  let crcs = (input_value ic : crcs) in
  let flags = (input_value ic : flags) in
  (* CR ocaml 5 compressed-marshal mshinwell: upstream uses [Compression] *)
  {
      cmi_name = name;
      cmi_kind = kind;
      cmi_globals = globals;
      cmi_sign = deserialize data sign;
      cmi_params = params;
      cmi_crcs = crcs;
      cmi_flags = flags;
    }

let read_cmi_lazy filename =
  let open Magic_numbers.Cmi in
  let ic = open_in_bin filename in
  try
    let buffer =
      really_input_string ic (String.length Config.cmi_magic_number)
    in
    if buffer <> Config.cmi_magic_number then begin
      close_in ic;
      let pre_len = String.length Config.cmi_magic_number - 3 in
      if String.sub buffer 0 pre_len
          = String.sub Config.cmi_magic_number 0 pre_len then
      begin
        raise (Error (Wrong_version_interface (filename, buffer)))
      end else begin
        raise(Error(Not_an_interface filename))
      end
    end;
    let cmi = input_cmi_lazy ic in
    close_in ic;
    cmi
  with End_of_file | Failure _ ->
      close_in ic;
      raise(Error(Corrupted_interface(filename)))
    | Error e ->
      close_in ic;
      raise (Error e)

let output_cmi filename oc cmi =
  ignore (filename, oc, cmi); ""
(*
(* beware: the provided signature must have been substituted for saving *)
  output_string oc Config.cmi_magic_number;
  let output_int64 oc n =
    let buf = Bytes.create 8 in
    Bytes.set_int64_ne buf 0 n;
    output_bytes oc buf
  in
  (* Reserve space for length of data block, produce the block and then write
     the length. *)
  let len_pos = Out_channel.pos oc in
  output_int64 oc Int64.zero;
  let data_pos = Int64.add len_pos (Int64.of_int 8) in
  let sign = serialize oc data_pos cmi.cmi_sign in
  let val_pos = Out_channel.pos oc in
  Out_channel.seek oc len_pos;
  let len = Int64.sub val_pos data_pos in
  output_int64 oc len;
  Out_channel.seek oc val_pos;
  output_value oc
    {
      header_name = cmi.cmi_name;
      header_kind = cmi.cmi_kind;
      header_globals = cmi.cmi_globals;
      header_sign = sign;
      header_params = cmi.cmi_params;
    };
  flush oc;
  let crc = Digest.file filename in
  let my_info =
    match cmi.cmi_kind with
    | Normal { cmi_impl } ->
      Import_info.Intf.create_normal cmi.cmi_name cmi_impl ~crc
    | Parameter ->
      Import_info.Intf.create_parameter cmi.cmi_name ~crc
  in
  let crcs = Array.append [| my_info |] cmi.cmi_crcs in
  output_value oc (crcs : crcs);
  output_value oc (cmi.cmi_flags : flags);
  crc
*)

let input_cmi ic = input_cmi_lazy ic |> force_cmi_infos
let read_cmi filename = read_cmi_lazy filename |> force_cmi_infos

(* Error report moved to src/ocaml/typing/magic_numbers.ml *)
