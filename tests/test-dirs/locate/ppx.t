  $ test_merlin_locate () {
  > local position="$1"
  > local file="$2"
  > 
  > $MERLIN single locate -position "$position" -filename "$file" < "$file" | jq -r .value
  > }

  $ cat >basic.ml <<EOF
  > let f a b c d = a - b  c - d
  > let _ = [%swap f 1 2] 3 4
  > let _ = (0 [@add_one]) + 2
  > 
  > [@@@do_nothing]
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
  >            "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >          pos_lnum = 53;
  >          pos_bol = 1612;
  >          pos_cnum = 1633
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
  >           "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >         pos_lnum = 101;
  >         pos_bol = 2833;
  >         pos_cnum = 2854
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
  >           "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >         pos_lnum = 12;
  >         pos_bol = 336;
  >         pos_cnum = 360
  >       }
  >   }]]
  > EOF

  $ cat >basic.mli <<EOF
  > val f : int -> int -> int -> int -> int [@@identity]
  > [@@@merlin.locate
  >   [{
  >      location =
  >        {
  >          loc_start =
  >            { pos_fname = "test.mli"; pos_lnum = 1; pos_bol = 0; pos_cnum = 43
  >            };
  >          loc_end =
  >            { pos_fname = "test.mli"; pos_lnum = 1; pos_bol = 0; pos_cnum = 51
  >            };
  >          loc_ghost = false
  >        };
  >      locate =
  >        {
  >          pos_fname =
  >            "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >          pos_lnum = 79;
  >          pos_bol = 2317;
  >          pos_cnum = 2338
  >        }
  >    }]]
  > EOF

Locate %swap

  $ test_merlin_locate "2:10" "./basic.ml"
  {
    "file": "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml",
    "pos": {
      "line": 12,
      "col": 24
    }
  }

Locate @add_one

  $ test_merlin_locate "3:13" "./basic.ml"
  {
    "file": "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml",
    "pos": {
      "line": 53,
      "col": 21
    }
  }

Locate @@@do_nothing

  $ test_merlin_locate "5:4" "./basic.ml"
  {
    "file": "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml",
    "pos": {
      "line": 101,
      "col": 21
    }
  }

Locate @@identity

  $ test_merlin_locate "1:45" "./basic.mli"
  {
    "file": "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml",
    "pos": {
      "line": 79,
      "col": 21
    }
  }

Multiple @@@merlin.locate attributes should be merged and both usable

  $ cat >multiple-attribute.ml <<EOF
  > let f a b c d = a - b  c - d
  > let _ = [%swap f 1 2] 3 4
  > let _ = (0 [@add_one]) + 2
  > 
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
  >            "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >          pos_lnum = 53;
  >          pos_bol = 1612;
  >          pos_cnum = 1633
  >        }
  >    }]]
  > [@@@merlin.locate
  >   [{
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
  >           "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >         pos_lnum = 12;
  >         pos_bol = 336;
  >         pos_cnum = 360
  >       }
  >   }]]
  > EOF

  $ test_merlin_locate "2:10" "./multiple-attribute.ml"
  {
    "file": "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml",
    "pos": {
      "line": 12,
      "col": 24
    }
  }

  $ test_merlin_locate "3:13" "./multiple-attribute.ml"
  {
    "file": "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml",
    "pos": {
      "line": 53,
      "col": 21
    }
  }

Attribute location should not affect functionality. 

  $ cat >attribute-at-top.ml <<EOF
  > [@@@merlin.locate
  >   [ { location =
  >         { loc_start =
  >             { pos_fname = "test.ml"; pos_lnum = 19; pos_bol = 509; pos_cnum = 522 }
  >         ; loc_end =
  >             { pos_fname = "test.ml"; pos_lnum = 19; pos_bol = 509; pos_cnum = 529 }
  >         ; loc_ghost = false
  >         }
  >     ; locate =
  >         { pos_fname =
  >             "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml"
  >         ; pos_lnum = 53
  >         ; pos_bol = 1612
  >         ; pos_cnum = 1633
  >         }
  >     }
  >   ]]
  > 
  > let _ = (0 [@add_one]) + 2
  > EOF

  $ test_merlin_locate "9:13" "./attribute-at-top.ml"
  {
    "file": "lib/ocaml/stdlib.mli",
    "pos": {
      "line": 128,
      "col": 9
    }
  }

Existing locate behavior of non-PPXs should not be affected. 

  $ cat >non-ppx.ml <<EOF
  > let x = 0
  > let _ = (x [@add_one]) + 2
  > [@@@merlin.locate
  >   [{
  >      location =
  >        {
  >          loc_start =
  >            { pos_fname = "test.ml"; pos_lnum = 2; pos_bol = 10; pos_cnum = 23
  >            };
  >          loc_end =
  >            { pos_fname = "test.ml"; pos_lnum = 2; pos_bol = 10; pos_cnum = 30
  >            };
  >          loc_ghost = false
  >        };
  >      locate =
  >        {
  >          pos_fname =
  >            "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >          pos_lnum = 53;
  >          pos_bol = 1612;
  >          pos_cnum = 1633
  >        }
  >    }]]
  > EOF

  $ test_merlin_locate "2:9" "./non-ppx.ml"
  {
    "file": "$TESTCASE_ROOT/non-ppx.ml",
    "pos": {
      "line": 1,
      "col": 4
    }
  }


merlin.locate attribute's payload has invalid structure. below, the payload is missing

  $ cat >invalid-payload.ml <<EOF
  > let _ = (0 [@add_one]) + 2
  > [@@@merlin.locate]
  > EOF

  $ test_merlin_locate "1:13" "./invalid-payload.ml"
  Not in environment 'add_one'

merlin.locate attribute's payload contains two target overrides. the first target should be returned

  $ cat >invalid-payload.ml <<EOF
  > let _ = (0 [@add_one]) + 2
  > [@@@merlin.locate
  >   [{
  >      location =
  >        {
  >          loc_start =
  >            { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 13
  >            };
  >          loc_end =
  >            { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 20
  >            };
  >          loc_ghost = false
  >        };
  >      locate =
  >        {
  >          pos_fname =
  >            "first target locate override";
  >          pos_lnum = 53;
  >          pos_bol = 1612;
  >          pos_cnum = 1633
  >        }
  >    };
  >   {
  >      location =
  >        {
  >          loc_start =
  >            { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 13
  >            };
  >          loc_end =
  >            { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 20
  >            };
  >          loc_ghost = false
  >        };
  >      locate =
  >        {
  >          pos_fname =
  >            "second target locate override";
  >          pos_lnum = 53;
  >          pos_bol = 1612;
  >          pos_cnum = 1633
  >        }
  >    }]]
  > EOF

  $ test_merlin_locate "1:13" "./invalid-payload.ml"
  {
    "file": "first target locate override",
    "pos": {
      "line": 53,
      "col": 21
    }
  }

Locate nested PPXs

  $ cat >nested-ppx.ml <<EOF
  > let f a b c d = a - b + c - d
  > let _ = [%swap [%swap f 1 2] 3 4]
  > [@@@merlin.locate
  >   [{
  >      location =
  >        {
  >          loc_start =
  >            { pos_fname = "test.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 47
  >            };
  >          loc_end =
  >            { pos_fname = "test.ml"; pos_lnum = 2; pos_bol = 30; pos_cnum = 51
  >            };
  >          loc_ghost = false
  >        };
  >      locate =
  >        {
  >          pos_fname =
  >            "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >          pos_lnum = 12;
  >          pos_bol = 336;
  >          pos_cnum = 360
  >        }
  >    };
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
  >           "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >         pos_lnum = 12;
  >         pos_bol = 336;
  >         pos_cnum = 360
  >       }
  >   }]]
  > EOF

  $ test_merlin_locate "2:10" "./nested-ppx.ml"
  {
    "file": "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml",
    "pos": {
      "line": 12,
      "col": 24
    }
  }

  $ test_merlin_locate "2:17" "./nested-ppx.ml"
  {
    "file": "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml",
    "pos": {
      "line": 12,
      "col": 24
    }
  }

Override locate of payload of a PPX

  $ cat >ppx-payload.ml <<EOF
  > let _ = [%swap f 1 2] 3 4
  > [@@@merlin.locate
  >   [{
  >      location =
  >        {
  >          loc_start =
  >            { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 10
  >            };
  >          loc_end =
  >            { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 14
  >            };
  >          loc_ghost = false
  >        };
  >      locate =
  >        {
  >          pos_fname =
  >            "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >          pos_lnum = 12;
  >          pos_bol = 336;
  >          pos_cnum = 360
  >        }
  >    };
  >   {
  >     location =
  >       {
  >         loc_start =
  >           { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 15 };
  >         loc_end =
  >           { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 16 };
  >         loc_ghost = false
  >       };
  >     locate =
  >        {
  >          pos_fname =
  >            "external/some_file_for_f.ml";
  >          pos_lnum = 1;
  >          pos_bol = 0;
  >          pos_cnum = 5
  >        }
  >   }]]
  > EOF

  $ test_merlin_locate "1:10" "./ppx-payload.ml"
  {
    "file": "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml",
    "pos": {
      "line": 12,
      "col": 24
    }
  }

  $ test_merlin_locate "1:15" "./ppx-payload.ml"
  {
    "file": "external/some_file_for_f.ml",
    "pos": {
      "line": 1,
      "col": 5
    }
  }

Locate a floating attribute

  $ cat >floating_attribute.ml <<EOF
  > [@@@do_nothing]
  > [@@@merlin.locate
  >   [{
  >      location =
  >        {
  >          loc_start =
  >            { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 4 };
  >          loc_end =
  >            { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 14
  >            };
  >          loc_ghost = false
  >        };
  >      locate =
  >        {
  >          pos_fname =
  >            "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >          pos_lnum = 101;
  >          pos_bol = 2833;
  >          pos_cnum = 2854
  >        }
  >    }]]
  > EOF

  $ test_merlin_locate "1:4" "./floating_attribute.ml"
  {
    "file": "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml",
    "pos": {
      "line": 101,
      "col": 21
    }
  }

Locate an attribute in a extension's payload

  $ cat >attribute-as-payload.ml <<EOF
  > let _ = [%swap f (1 [@add_one]) 2] 3 4
  > [@@@merlin.locate
  >   [{
  >      location =
  >        {
  >          loc_start =
  >            { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 22
  >            };
  >          loc_end =
  >            { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 29
  >            };
  >          loc_ghost = false
  >        };
  >      locate =
  >        {
  >          pos_fname =
  >            "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >          pos_lnum = 53;
  >          pos_bol = 1612;
  >          pos_cnum = 1633
  >        }
  >    };
  >   {
  >     location =
  >       {
  >         loc_start =
  >           { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 10 };
  >         loc_end =
  >           { pos_fname = "test.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 14 };
  >         loc_ghost = false
  >       };
  >     locate =
  >       {
  >         pos_fname =
  >           "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml";
  >         pos_lnum = 12;
  >         pos_bol = 336;
  >         pos_cnum = 360
  >       }
  >   }]]
  > EOF

  $ test_merlin_locate "1:10" "./attribute-as-payload.ml"
  {
    "file": "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml",
    "pos": {
      "line": 12,
      "col": 24
    }
  }
 
  $ test_merlin_locate "1:22" "./attribute-as-payload.ml"
  {
    "file": "external/ppxlib/test/overrides/ppx/ppxlib_ppx_for_testing_merlin_overrides.ml",
    "pos": {
      "line": 53,
      "col": 21
    }
  }
