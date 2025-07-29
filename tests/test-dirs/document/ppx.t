  $ test_merlin_document () {
  > local position="$1"
  > local file="$2"
  > 
  > $MERLIN single document -position "$position" -filename "$file" < "$file" | jq -r .value
  > }

  $ cat >basic.ml <<EOF
  > let f a b c d = a - b + c - d
  > let _ = [%swap f 1 2] 3 4
  > let _ = (0 [@add_one]) + 2
  > 
  > [@@@do_nothing]
  > [@@@merlin.document
  >   [{
  >      location =
  >        {
  >          loc_start =
  >            { pos_fname = "test.ml"; pos_lnum = 3; pos_bol = 56; pos_cnum = 69
  >            };
  >          loc_end =
  >            { pos_fname = "test.ml"; pos_lnum = 3; pos_bol = 56; pos_cnum = 76
  >            };
  >          loc_ghost = false
  >        };
  >      document = "@add_one expands expressions with a '+ 1'"
  >    };
  >   {
  >     location =
  >       {
  >         loc_start =
  >           { pos_fname = "test.ml"; pos_lnum = 5; pos_bol = 84; pos_cnum = 88
  >           };
  >         loc_end =
  >           { pos_fname = "test.ml"; pos_lnum = 5; pos_bol = 84; pos_cnum = 98
  >           };
  >         loc_ghost = false
  >       };
  >     document = "@@@do_nothing expands into nothing"
  >   };
  >   {
  >     location =
  >       {
  >         loc_start =
  >           { pos_fname = "test.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 40
  >           };
  >         loc_end =
  >           { pos_fname = "test.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 44
  >           };
  >         loc_ghost = false
  >       };
  >     document = "%swap swaps the first two arguments of a function call"
  >   }]]
  > [@@@merlin.locate
  >   [{
  >      location =
  >        {
  >          loc_start =
  >            { pos_fname = "test.ml"; pos_lnum = 3; pos_bol = 56; pos_cnum = 69
  >            };
  >          loc_end =
  >            { pos_fname = "test.ml"; pos_lnum = 3; pos_bol = 56; pos_cnum = 76
  >            };
  >          loc_ghost = false
  >        };
  >      locate =
  >        {
  >          pos_fname =
  >            "external/ppxlib/test/document/ppx/ppxlib_ppx_for_testing_merlin_document.ml";
  >          pos_lnum = 45;
  >          pos_bol = 1440;
  >          pos_cnum = 1442
  >        }
  >    };
  >   {
  >     location =
  >       {
  >         loc_start =
  >           { pos_fname = "test.ml"; pos_lnum = 5; pos_bol = 84; pos_cnum = 88
  >           };
  >         loc_end =
  >           { pos_fname = "test.ml"; pos_lnum = 5; pos_bol = 84; pos_cnum = 98
  >           };
  >         loc_ghost = false
  >       };
  >     locate =
  >       {
  >         pos_fname =
  >           "external/ppxlib/test/document/ppx/ppxlib_ppx_for_testing_merlin_document.ml";
  >         pos_lnum = 86;
  >         pos_bol = 2568;
  >         pos_cnum = 2570
  >       }
  >   };
  >   {
  >     location =
  >       {
  >         loc_start =
  >           { pos_fname = "test.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 40
  >           };
  >         loc_end =
  >           { pos_fname = "test.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 44
  >           };
  >         loc_ghost = false
  >       };
  >     locate =
  >       {
  >         pos_fname =
  >           "external/ppxlib/test/document/ppx/ppxlib_ppx_for_testing_merlin_document.ml";
  >         pos_lnum = 10;
  >         pos_bol = 291;
  >         pos_cnum = 296
  >       }
  >   }]]
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

  $ test_merlin_document "2:10" "./basic.ml"
  %swap swaps the first two arguments of a function call

Document @add_one

  $ test_merlin_document "3:13" "./basic.ml"
  @add_one expands expressions with a '+ 1'

Document @@@do_nothing

  $ test_merlin_document "5:4" "./basic.ml"
  @@@do_nothing expands into nothing

Document @@identity

  $ test_merlin_document "1:45" "./basic.mli"
  @identity does not expand into anything

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

  $ test_merlin_document "2:10" "./multiple-attribute.ml"
  %swap swaps the first two arguments of a function call

  $ test_merlin_document "3:13" "./multiple-attribute.ml"
  @add_one expands expressions with a '+ 1'

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

  $ test_merlin_document "11:13" "./attribute-at-top.ml"
  @add_one expands expressions with a '+ 1'

Existing document behavior of non-PPXs should not be affected. 

  $ cat >non-ppx.ml <<EOF
  > (** [x] is a variable *)
  > let x = 0
  > 
  > let _ = (x [@add_one]) + 2
  > let x = x + 1
  > [@@@merlin.document
  >   [({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 4; pos_bol = 36; pos_cnum = 49 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 4; pos_bol = 36; pos_cnum = 56 };
  >       loc_ghost = false
  >     }, "@add_one expands expressions with a '+ 1'")]]
  > EOF

  $ test_merlin_document "2:4" "./non-ppx.ml"
  [x] is a variable

  $ test_merlin_document "5:8" "./non-ppx.ml"
  [x] is a variable

merlin.document attribute's payload has invalid structure. below, the payload is missing

  $ cat >invalid-payload.ml <<EOF
  > let _ = (0 [@add_one]) + 2
  > [@@@merlin.document]
  > EOF

  $ test_merlin_document "1:13" "./invalid-payload.ml"
  Not in environment 'add_one'

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

  $ test_merlin_document "1:13" "./invalid-payload.ml"
  first target document override

Document nested PPXs

  $ cat >nested-ppx.ml <<EOF
  > let f a b c d = a - b + c - d
  > let _ = [%swap [%swap f 1 2] 3 4]
  > 
  > [@@@merlin.document
  >   [({
  >      loc_start =
  >        { pos_fname = "basic.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 40 };
  >      loc_end =
  >        { pos_fname = "basic.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 44 };
  >      loc_ghost = false
  >    }, "%swap swaps the first two arguments of a function call");
  >  ({
  >      loc_start =
  >        { pos_fname = "basic.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 47 };
  >      loc_end =
  >        { pos_fname = "basic.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 51 };
  >      loc_ghost = false
  >    }, "%swap swaps the first two arguments of a function call")]]
  > EOF

  $ test_merlin_document "2:10" "./nested-ppx.ml"
  %swap swaps the first two arguments of a function call

  $ test_merlin_document "2:17" "./nested-ppx.ml"
  %swap swaps the first two arguments of a function call

Document payload of a PPX

  $ cat >ppx-payload.ml <<EOF
  > let _ = [%swap f 1 2] 3 4
  > let _ = [%swap (*!*)]
  > [@@@merlin.document
  >   [({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 10 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 14 };
  >       loc_ghost = false
  >     }, "%swap swaps the first two arguments of a function call");
  >   ({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 15 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 16 };
  >       loc_ghost = false
  >     }, "f can be a %swap-specific argument");
  >   ({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 2; pos_bol = 26; pos_cnum = 43 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 2; pos_bol = 26; pos_cnum = 44 };
  >       loc_ghost = false
  >     }, "weird garbage can also be documented")]]
  > EOF

  $ test_merlin_document "1:10" "./ppx-payload.ml"
  %swap swaps the first two arguments of a function call

  $ test_merlin_document "1:15" "./ppx-payload.ml"
  f can be a %swap-specific argument

  $ test_merlin_document "2:18" "./ppx-payload.ml"
  weird garbage can also be documented

Document an invalid position

  $ cat >invalid-position.ml <<EOF
  > let _ = [%swap f 1 2] 3 4
  > [@@@merlin.document
  >   [({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 70 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 74 };
  >       loc_ghost = false
  >     }, "this is a document override at an invalid position")]]
  > EOF

  $ test_merlin_document "1:70" "./invalid-position.ml"
  this is a document override at an invalid position

Document a floating attribute

  $ cat >floating_attribute.ml <<EOF
  > [@@@test_floating_attribute]
  > [@@@merlin.document
  >   [({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 4 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 27 };
  >       loc_ghost = false
  >     }, "@@@test_floating_attribute is a test floating attribute")]]
  > EOF

  $ test_merlin_document "1:4" "./floating_attribute.ml"
  @@@test_floating_attribute is a test floating attribute

Document an attribute in a extension's payload

  $ cat >attribute-as-payload.ml <<EOF
  > let _ = [%swap f (1 [@add_one]) 2] 3 4
  > [@@@merlin.document
  >   [({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 10 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 14 };
  >       loc_ghost = false
  >     }, "%swap swaps the first two arguments of a function call");
  >   ({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 22 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 29 };
  >       loc_ghost = false
  >     }, "@add_one expands expressions with a '+ 1'")]]
  > EOF

  $ test_merlin_document "1:10" "./attribute-as-payload.ml"
  %swap swaps the first two arguments of a function call
 
  $ test_merlin_document "1:22" "./attribute-as-payload.ml"
  @add_one expands expressions with a '+ 1'

