  $ cat >basic.ml <<EOF
  > let f a b c d = a - b + c - d
  > let _ = [%swap f 1 2] 3 4
  > let _ = (0 [@add_one]) + 2
  > 
  > [@@@do_nothing]
  > [@@@merlin.document
  >   [({
  >       loc_start =
  >         { pos_fname = "basic.ml"; pos_lnum = 3; pos_bol = 56; pos_cnum = 69 };
  >       loc_end =
  >         { pos_fname = "basic.ml"; pos_lnum = 3; pos_bol = 56; pos_cnum = 76 };
  >       loc_ghost = false
  >     }, "@add_one expands expressions with a '+ 1'");
  >   ({
  >      loc_start =
  >        { pos_fname = "basic.ml"; pos_lnum = 5; pos_bol = 84; pos_cnum = 88 };
  >      loc_end =
  >        { pos_fname = "basic.ml"; pos_lnum = 5; pos_bol = 84; pos_cnum = 98 };
  >      loc_ghost = false
  >    }, "@@@do_nothing expands into nothing");
  >   ({
  >      loc_start =
  >        { pos_fname = "basic.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 40 };
  >      loc_end =
  >        { pos_fname = "basic.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 44 };
  >      loc_ghost = false
  >    }, "%swap swaps the first two arguments of a function call")]]
  > EOF

  $ cat >basic.mli <<EOF
  > val f : int -> int -> int -> int -> int [@@identity]
  > [@@@merlin.document
  >   [({
  >       loc_start =
  >         { pos_fname = "basic.mli"; pos_lnum = 1; pos_bol = 0; pos_cnum = 43 };
  >       loc_end =
  >         { pos_fname = "basic.mli"; pos_lnum = 1; pos_bol = 0; pos_cnum = 51 };
  >       loc_ghost = false
  >     }, "@identity does not expand into anything")]]
  > EOF

Document %swap

  $ $MERLIN single document -position 2:10 -filename ./basic.ml < ./basic.ml | jq .value
  "%swap swaps the first two arguments of a function call"

Document @add_one

  $ $MERLIN single document -position 3:13 -filename ./basic.ml < ./basic.ml | jq .value
  "@add_one expands expressions with a '+ 1'"

Document @@@do_nothing

  $ $MERLIN single document -position 5:4 -filename ./basic.ml < ./basic.ml | jq .value
  "@@@do_nothing expands into nothing"

Document @@identity

  $ $MERLIN single document -position 1:45 -filename ./basic.mli < ./basic.mli | jq .value
  "@identity does not expand into anything"

Multiple @@@merlin.document attributes should be merged and both usable

  $ cat >multiple-attribute.ml <<EOF
  > let f a b c d = a - b + c - d
  > let _ = [%swap f 1 2] 3 4
  > let _ = (0 [@add_one]) + 2
  > 
  > [@@@merlin.document
  >   [({
  >       loc_start =
  >         { pos_fname = "basic.ml"; pos_lnum = 3; pos_bol = 56; pos_cnum = 69 };
  >       loc_end =
  >         { pos_fname = "basic.ml"; pos_lnum = 3; pos_bol = 56; pos_cnum = 76 };
  >       loc_ghost = false
  >     }, "@add_one expands expressions with a '+ 1'")]]
  > [@@@merlin.document
  >   [({
  >      loc_start =
  >        { pos_fname = "basic.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 40 };
  >      loc_end =
  >        { pos_fname = "basic.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 44 };
  >      loc_ghost = false
  >    }, "%swap swaps the first two arguments of a function call")]]
  > EOF

  $ $MERLIN single document -position 2:10 -filename ./multiple-attribute.ml < ./multiple-attribute.ml | jq .value
  "%swap swaps the first two arguments of a function call"

  $ $MERLIN single document -position 3:13 -filename ./multiple-attribute.ml < ./multiple-attribute.ml | jq .value
  "@add_one expands expressions with a '+ 1'"

Attribute location should not affect functionality. 

  $ cat >attribute-at-top.ml <<EOF
  > [@@@merlin.document
  > [({
  >     loc_start =
  >       { pos_fname = "test.ml"; pos_lnum = 11; pos_bol = 314; pos_cnum = 327
  >       };
  >     loc_end =
  >       { pos_fname = "test.ml"; pos_lnum = 11; pos_bol = 314; pos_cnum = 334
  >       };
  >     loc_ghost = false
  >   }, "@add_one expands expressions with a '+ 1'")]]
  > let _ = (0 [@add_one]) + 2
  > EOF

  $ $MERLIN single document -position 11:13 -filename ./attribute-at-top.ml < ./attribute-at-top.ml | jq .value
  "@add_one expands expressions with a '+ 1'"

Existing document behavior of non-PPXsshould not be affected. 

  $ cat >non-ppx.ml <<EOF
  > (** [x] is a variable *)
  > let x = 0
  > 
  > let _ = (x [@add_one]) + 2
  > [@@@merlin.document
  >   [({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 4; pos_bol = 36; pos_cnum = 49 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 4; pos_bol = 36; pos_cnum = 56 };
  >       loc_ghost = false
  >     }, "@add_one expands expressions with a '+ 1'")]]
  > EOF

  $ $MERLIN single document -position 2:4 -filename ./non-ppx.ml < ./non-ppx.ml | jq .value
  "[x] is a variable"

FIXME: Document the payload of an attribute. We expect "f is a test function"

  $ cat >ppx-payload.ml <<EOF
  > (** f is a test function *)
  > let f a b c d = a - b + c - d
  > 
  > let _ = [%swap f 1 2] 3 4
  > [@@@merlin.document
  >   [({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 4; pos_bol = 59; pos_cnum = 69 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 4; pos_bol = 59; pos_cnum = 73 };
  >       loc_ghost = false
  >     }, "%swap swaps the first two arguments of a function call")]]
  > EOF

  $ $MERLIN single document -position 4:15 -filename ./ppx-payload.ml < ./ppx-payload.ml | jq .value
  "Not in environment 'f'"

merlin.document attribute's payload has invalid structure. below, the payload is missing

  $ cat >invalid-payload.ml <<EOF
  > let _ = (0 [@add_one]) + 2
  > [@@@merlin.document]
  > EOF

  $ $MERLIN single document -position 1:13 -filename ./invalid-payload.ml < ./invalid-payload.ml | jq .value
  "Not in environment 'add_one'"

merlin.document attribute's payload contains two target overrides. the first target should be returned

  $ cat >invalid-payload.ml <<EOF
  > let _ = (0 [@add_one]) + 2
  > [@@@merlin.document
  >   [({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 13 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 20 };
  >       loc_ghost = false
  >     }, "first target document override");
  >   ({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 13 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 20 };
  >      loc_ghost = false
  >    }, "second target document override")]]
  > EOF

  $ $MERLIN single document -position 1:13 -filename ./invalid-payload.ml < ./invalid-payload.ml | jq .value
  "first target document override"
