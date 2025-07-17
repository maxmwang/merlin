  $ cat >test.ml <<EOF
  > [@@@merlin.document
  >   [({
  >       loc_start =
  >         { pos_fname = "test.ml"; pos_lnum = 25; pos_bol = 906; pos_cnum = 917 };
  >       loc_end =
  >         { pos_fname = "test.ml"; pos_lnum = 25; pos_bol = 906; pos_cnum = 927 };
  >       loc_ghost = false
  >     }, "@add_one expands expressions with a '+ 1'");
  >   ({
  >      loc_start =
  >        { pos_fname = "test.ml"; pos_lnum = 27; pos_bol = 934; pos_cnum = 934 };
  >      loc_end =
  >        { pos_fname = "test.ml"; pos_lnum = 27; pos_bol = 934; pos_cnum = 949 };
  >      loc_ghost = false
  >    }, "@@@do_nothing expands into nothing");
  >   ({
  >      loc_start =
  >        { pos_fname = "test.ml"; pos_lnum = 24; pos_bol = 880; pos_cnum = 890 };
  >      loc_end =
  >        { pos_fname = "test.ml"; pos_lnum = 24; pos_bol = 880; pos_cnum = 894 };
  >      loc_ghost = false
  >    }, "%swap swaps the first two arguments of a function call")]]
  > let f a b c d = a - b + c - d
  > let _ = [%swap f 1 2] 3 4
  > let _ = (0 [@add_one]) + 2
  > 
  > [@@@do_nothing]
  > EOF

Document @add_one

  $ $MERLIN single document -position 25:13 -filename ./test.ml < ./test.ml | jq .value
  "@add_one expands expressions with a '+ 1'"

Document @@@do_nothing

  $ $MERLIN single document -position 27:4 -filename ./test.ml < ./test.ml | jq .value
  "@@@do_nothing expands into nothing"

Document %swap

  $ $MERLIN single document -position 24:10 -filename ./test.ml < ./test.ml | jq .value
  "%swap swaps the first two arguments of a function call"
