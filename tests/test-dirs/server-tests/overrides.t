  $ $MERLIN server stop-server

  $ mkdir test

  $ test_merlin_overrides () {
  > local position="$1"
  > local file="$2"
  > 
  > local locate_output=$(ocamlmerlin server locate -position "$position" -filename "$file" < "$file" -ocamllib-path "$MERLIN_TEST_OCAMLLIB_PATH" \
  >    | jq 'del(.timing)' \
  >    | jq 'del(.heap_mbytes)' \
  >    | jq 'del(.query_num)' \
  >    | sed -e 's:"[^"]*lib/ocaml:"lib/ocaml:g' \
  >    | sed -e 's:\\n:\n:g')
  > 
  > local document_output=$(ocamlmerlin server document -position "$position" -filename "$file" < "$file" -ocamllib-path "$MERLIN_TEST_OCAMLLIB_PATH" \
  >    | jq 'del(.timing)' \
  >    | jq 'del(.heap_mbytes)' \
  >    | jq 'del(.query_num)' \
  >    | sed -e 's:"[^"]*lib/ocaml:"lib/ocaml:g' \
  >    | sed -e 's:\\n:\n:g')
  > 
  > echo "[merlin locate] output: $locate_output" 
  > echo "[merlin document] output: $document_output" 
  > }

All following tests are performed in /test and merlin has access to /test/.merlin

  $ cd test
  $ cat >.merlin <<EOF
  > SOURCE_ROOT ../
  > EOF

Test no .merlin, relative path

  $ cat >./simple.ml <<EOF
  > [@@@do_nothing]
  > [@@@merlin.document
  >   [{
  >      location =
  >        {
  >          loc_start =
  >            { pos_fname = "simple.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 4 };
  >          loc_end =
  >            { pos_fname = "simple.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 14
  >            };
  >          loc_ghost = false
  >        };
  >      payload = "@@@do_nothing expands into nothing"
  >    }]]
  > [@@@merlin.locate
  >   [{
  >      location =
  >        {
  >          loc_start =
  >            { pos_fname = "simple.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 4 };
  >          loc_end =
  >            { pos_fname = "simple.ml"; pos_lnum = 1; pos_bol = 0; pos_cnum = 14
  >            };
  >          loc_ghost = false
  >        };
  >      payload =
  >        {
  >          pos_fname =
  >            "test/ppx.ml";
  >          pos_lnum = 101;
  >          pos_bol = 2833;
  >          pos_cnum = 2854
  >        }
  >    }]]
  > EOF

  $ test_merlin_overrides "1:4" "./simple.ml"
  [merlin locate] output: {
    "class": "return",
    "value": {
      "file": "$TESTCASE_ROOT/test/ppx.ml",
      "pos": {
        "line": 101,
        "col": 21
      }
    },
    "notifications": [],
    "cache": {
      "reader_phase": "miss",
      "ppx_phase": "miss",
      "typer": "miss",
      "cmt": {
        "hit": 0,
        "miss": 0
      },
      "cms": {
        "hit": 0,
        "miss": 0
      },
      "cmi": {
        "hit": 0,
        "miss": 0
      },
      "document_overrides_forced": "false",
      "locate_overrides_forced": "true"
    }
  }
  [merlin document] output: {
    "class": "return",
    "value": "@@@do_nothing expands into nothing",
    "notifications": [],
    "cache": {
      "reader_phase": "miss",
      "ppx_phase": "miss",
      "typer": "miss",
      "cmt": {
        "hit": 0,
        "miss": 0
      },
      "cms": {
        "hit": 0,
        "miss": 0
      },
      "cmi": {
        "hit": 0,
        "miss": 0
      },
      "document_overrides_forced": "true",
      "locate_overrides_forced": "false"
    }
  }

  $ test_merlin_overrides "1:4" "./simple.ml"
  [merlin locate] output: {
    "class": "return",
    "value": {
      "file": "$TESTCASE_ROOT/test/ppx.ml",
      "pos": {
        "line": 101,
        "col": 21
      }
    },
    "notifications": [],
    "cache": {
      "reader_phase": "miss",
      "ppx_phase": "miss",
      "typer": "miss",
      "cmt": {
        "hit": 0,
        "miss": 0
      },
      "cms": {
        "hit": 0,
        "miss": 0
      },
      "cmi": {
        "hit": 0,
        "miss": 0
      },
      "document_overrides_forced": "false",
      "locate_overrides_forced": "true"
    }
  }
  [merlin document] output: {
    "class": "return",
    "value": "@@@do_nothing expands into nothing",
    "notifications": [],
    "cache": {
      "reader_phase": "miss",
      "ppx_phase": "miss",
      "typer": "miss",
      "cmt": {
        "hit": 0,
        "miss": 0
      },
      "cms": {
        "hit": 0,
        "miss": 0
      },
      "cmi": {
        "hit": 0,
        "miss": 0
      },
      "document_overrides_forced": "true",
      "locate_overrides_forced": "false"
    }
  }

  $ $MERLIN server stop-server
