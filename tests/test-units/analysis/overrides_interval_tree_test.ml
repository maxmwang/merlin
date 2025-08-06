open Merlin_analysis

let create_tree intervals =
  intervals
  |> List.map (fun ((low, high), payload) ->
         Overrides_interval_tree.Interval.create_exn ~low ~high ~payload)
  |> Overrides_interval_tree.of_alist_exn

let test_of_alist_exn =
  let open Alcotest in
  test_case "test basic list construction" `Quick (fun () ->
      let _ : string Overrides_interval_tree.t =
        create_tree
          [ ((0, 1), "1");
            ((0, 3), "2");
            ((2, 3), "3");
            ((0, 4), "4");
            ((0, 10), "5");
            ((5, 10), "6");
            ((5, 7), "7");
            ((8, 10), "8");
            ((0, 2), "9");
            ((2, 2), "10")
          ]
      in
      ())

let test_empty_list =
  let open Alcotest in
  test_case "test basic list construction" `Quick (fun () ->
      check_raises "should raise exn" (Invalid_argument "input list is empty")
        (fun () ->
          let _ : string Overrides_interval_tree.t = create_tree [] in
          ()))

let test_invalid_interval =
  let open Alcotest in
  test_case "test creating invalid interval" `Quick (fun () ->
      check_raises "should raise exn"
        (Invalid_argument "input low greater than high") (fun () ->
          let _ =
            Overrides_interval_tree.Interval.create_exn ~low:5 ~high:0
              ~payload:"invalid"
          in
          ()))

let test_find ~input ~expected =
  (*
    0 1 2 3 4 5 6 7 8 9 10
    ----------e---------
    ----d---  -----f----
    ---b--    --g-  --h-
    -a  -c            -i
        j
   *)
  let tree =
    create_tree
      [ ((0, 1), "a");
        ((0, 3), "b");
        ((2, 3), "c");
        ((0, 4), "d");
        ((0, 10), "e");
        ((5, 10), "f");
        ((5, 7), "g");
        ((8, 10), "h");
        ((9, 10), "i");
        ((2, 2), "j")
      ]
  in
  let open Alcotest in
  test_case
    ("test find on input " ^ Int.to_string input)
    `Quick
    (fun () ->
      let payload = Overrides_interval_tree.find tree input in
      check (option string) "should be equal" expected payload)

let test_find_first =
  let tree = create_tree [ ((0, 4), "0"); ((2, 2), "1"); ((2, 2), "2") ] in
  let open Alcotest in
  test_case "test find on input with duplicate intervals" `Quick (fun () ->
      let expected = Some "1" in
      let payload = Overrides_interval_tree.find tree 2 in
      check (option string) "should be equal" expected payload)

let cases =
  ( "overrides-interval-tree",
    [ test_of_alist_exn;
      test_empty_list;
      test_invalid_interval;
      test_find ~input:0 ~expected:(Some "a");
      test_find ~input:1 ~expected:(Some "b");
      test_find ~input:2 ~expected:(Some "j");
      test_find ~input:3 ~expected:(Some "d");
      test_find ~input:4 ~expected:(Some "e");
      test_find ~input:5 ~expected:(Some "g");
      test_find ~input:6 ~expected:(Some "g");
      test_find ~input:7 ~expected:(Some "f");
      test_find ~input:8 ~expected:(Some "h");
      test_find ~input:9 ~expected:(Some "i");
      test_find ~input:10 ~expected:None;
      test_find_first
    ] )
